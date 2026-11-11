"""Signed staged-rollout schedule shared by the release signer and the app.

The bytes live inside the Ed25519 payload. Clients ignore a missing ``rollout``
object, so a manifest signed before this field still verifies. The schedule
below is the one ``UpdateRollout`` enforces. Keep the two together.

Default ramp, one step per 86400 seconds from ``basis``:

    1%, 2%, 5%, 10%, 20%, 50%, 100%

A running rollout uses the clock. ``paused`` freezes ``percent`` and still
lets a manual check through. ``halted`` offers the build to nobody, including
a manual check. ``critical`` skips the schedule. ``percent`` is the signed
snapshot: it is the gate while paused, and it records the schedule while running.
"""

from __future__ import annotations

DEFAULT_STEPS = [1, 2, 5, 10, 20, 50, 100]
DEFAULT_INTERVAL = 86400
MIN_INTERVAL = 3600
MAX_INTERVAL = 366 * 86400
MAX_BASIS = 4_102_444_800
ACTIONS = ('sync', 'pause', 'halt', 'resume', 'advance', 'finish', 'critical')


class RolloutError(ValueError):
    """The rollout object is not one the app will accept."""


def canonical(rollout: dict) -> dict:
    """Validate and return the object in the signed key order."""
    if not isinstance(rollout, dict):
        raise RolloutError('rollout must be an object')
    allowed = {'basis', 'interval', 'steps', 'paused', 'percent', 'critical', 'halted'}
    extra = set(rollout) - allowed
    if extra:
        raise RolloutError('rollout has an unknown field')
    missing = allowed - set(rollout)
    if missing:
        raise RolloutError('rollout is missing a field')
    basis = _whole(rollout['basis'], 'basis')
    interval = _whole(rollout['interval'], 'interval')
    if not 0 <= basis <= MAX_BASIS:
        raise RolloutError('rollout basis is out of range')
    if not MIN_INTERVAL <= interval <= MAX_INTERVAL:
        raise RolloutError('rollout interval must be from 1 hour through 366 days')
    steps = rollout['steps']
    if not isinstance(steps, list) or not 1 <= len(steps) <= 16:
        raise RolloutError('rollout steps must be a short list')
    previous = 0
    clean_steps: list[int] = []
    for step in steps:
        value = _whole(step, 'step')
        if not 1 <= value <= 100 or value <= previous:
            raise RolloutError('rollout steps must climb from 1 through 100')
        clean_steps.append(value)
        previous = value
    if clean_steps[-1] != 100:
        raise RolloutError('rollout steps must end at 100')
    percent = _whole(rollout['percent'], 'percent')
    if not 0 <= percent <= 100:
        raise RolloutError('rollout percent must be from 0 through 100')
    paused = _flag(rollout['paused'], 'paused')
    critical = _flag(rollout['critical'], 'critical')
    halted = _flag(rollout['halted'], 'halted')
    if critical and halted:
        raise RolloutError('a rollout cannot be both critical and halted')
    return {
        'basis': basis,
        'interval': interval,
        'steps': clean_steps,
        'paused': paused,
        'percent': percent,
        'critical': critical,
        'halted': halted,
    }


def share(rollout: dict, now: int) -> int:
    """Cohort percent at ``now``. Halted releases are not a share; callers check that first."""
    document = canonical(rollout)
    if document['critical']:
        return 100
    if document['paused']:
        return document['percent']
    if now < document['basis']:
        return 0
    elapsed = now - document['basis']
    index = min(len(document['steps']) - 1, elapsed // document['interval'])
    return document['steps'][index]


def cask_ready(payload: dict, now: int) -> bool:
    """Homebrew cannot stage. It moves only when every install may take the build."""
    if not isinstance(payload, dict):
        raise RolloutError('manifest payload must be an object')
    rollout = payload.get('rollout')
    if rollout is None:
        return True
    document = canonical(rollout)
    if document['halted']:
        return False
    if document['critical']:
        return True
    return share(document, now) == 100


def initial_rollout(spec: dict, now: int) -> dict:
    """Rollout embedded when a release is signed. ``spec`` is ReleaseRollout.json."""
    if not isinstance(spec, dict):
        raise RolloutError('release rollout file must be an object')
    allowed = {'critical', 'interval', 'steps'}
    if set(spec) != allowed:
        raise RolloutError('release rollout file must contain critical, interval, and steps')
    critical = _flag(spec['critical'], 'critical')
    interval = _whole(spec['interval'], 'interval')
    steps = spec['steps']
    if not isinstance(steps, list) or not steps:
        raise RolloutError('release rollout steps are empty')
    percent = 100 if critical else _whole(steps[0], 'step')
    basis = now
    if critical:
        basis = now - (len(steps) - 1) * interval
    return canonical({
        'basis': basis,
        'interval': interval,
        'steps': steps,
        'paused': False,
        'percent': percent,
        'critical': critical,
        'halted': False,
    })


def apply_action(rollout: dict, action: str, now: int, percent: int | None = None) -> tuple[dict, bool]:
    """Return the next signed rollout and whether the payload must be republished."""
    if action not in ACTIONS:
        raise RolloutError('unknown rollout action')
    if not isinstance(now, int) or isinstance(now, bool) or now < 0:
        raise RolloutError('rollout clock is invalid')
    current = canonical(rollout)
    if action == 'sync':
        if current['halted'] or current['paused'] or current['critical']:
            return current, False
        scheduled = share(current, now)
        if scheduled == current['percent']:
            return current, False
        updated = dict(current)
        updated['percent'] = scheduled
        return canonical(updated), True
    if action == 'pause':
        frozen = current['percent'] if percent is None else percent
        if percent is None and not current['halted']:
            frozen = share(current, now)
        updated = dict(current)
        updated['paused'] = True
        updated['halted'] = False
        updated['critical'] = False
        updated['percent'] = frozen
        updated = canonical(updated)
        return updated, updated != current
    if action == 'halt':
        updated = canonical({**current, 'paused': True, 'halted': True, 'critical': False, 'percent': 0})
        return updated, updated != current
    if action == 'resume':
        if not current['paused'] and not current['halted']:
            return current, False
        return _rebase(current, now, _resume_percent(current), clear_critical=True), True
    if action == 'advance':
        if not current['paused'] and not current['halted'] and share(current, now) == current['steps'][-1]:
            return current, False
        effective = current['percent'] if current['paused'] or current['halted'] else share(current, now)
        nxt = current['steps'][-1]
        for step in current['steps']:
            if step > effective:
                nxt = step
                break
        changed = _rebase(current, now, nxt, clear_critical=True)
        return changed, changed != current
    if action == 'finish':
        if not current['paused'] and not current['halted'] and share(current, now) == 100 and current['percent'] == 100:
            return current, False
        return _rebase(current, now, 100, clear_critical=True), True
    if current['critical'] and not current['paused'] and not current['halted'] and current['percent'] == 100:
        return current, False
    updated = _rebase(current, now, 100, clear_critical=True)
    updated['critical'] = True
    updated = canonical(updated)
    return updated, updated != current


def _resume_percent(rollout: dict) -> int:
    if rollout['percent'] <= 0:
        return rollout['steps'][0]
    for step in rollout['steps']:
        if step >= rollout['percent']:
            return step
    return rollout['steps'][-1]


def _rebase(rollout: dict, now: int, step_percent: int, clear_critical: bool) -> dict:
    index = 0
    for position, step in enumerate(rollout['steps']):
        if step <= step_percent:
            index = position
    basis = now - index * rollout['interval']
    if basis < 0:
        raise RolloutError('rollout basis would be negative')
    return canonical({
        **rollout,
        'basis': basis,
        'paused': False,
        'halted': False,
        'critical': False if clear_critical else rollout['critical'] and step_percent == 100,
        'percent': rollout['steps'][index],
    })


def _whole(value: object, name: str) -> int:
    if isinstance(value, bool) or not isinstance(value, int):
        raise RolloutError(f'rollout {name} must be an integer')
    return value


def _flag(value: object, name: str) -> bool:
    if not isinstance(value, bool):
        raise RolloutError(f'rollout {name} must be true or false')
    return value
