#!/usr/bin/env python3
"""Re-sign the published update manifest after a rollout action.

The ustar bytes stay as they are. Only the rollout object inside the signed
payload changes. The existing signature is checked with WATT_UPDATE_SIGNING_KEY
before anything is written, and the payload sha256 must match the tar on disk.
A manifest this key cannot verify is left untouched.
"""

from __future__ import annotations

import argparse
import base64
import importlib.util
import json
import os
import sys
import tempfile
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import release_lib
import rollout_manifest


def _signer():
    path = Path(__file__).with_name('sign-update-manifest.py')
    spec = importlib.util.spec_from_file_location('sign_update_manifest', path)
    if spec is None or spec.loader is None:
        raise release_lib.ReleaseError('could not load the update signer')
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def _emit(name: str, value: str) -> None:
    print(f'{name}={value}')
    output = os.environ.get('GITHUB_OUTPUT', '')
    if output:
        with open(output, 'a', encoding='utf-8') as handle:
            handle.write(f'{name}={value}\n')


def _percent(value: str) -> int | None:
    value = value.strip()
    if value == '':
        return None
    if not value.isascii() or not value.isdecimal():
        raise release_lib.ReleaseError('rollout percent must be an integer from 0 through 100')
    number = int(value)
    if number > 100:
        raise release_lib.ReleaseError('rollout percent must be an integer from 0 through 100')
    return number


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--manifest', type=Path, required=True)
    parser.add_argument('--archive', type=Path, required=True)
    parser.add_argument('--action', required=True)
    parser.add_argument('--percent', default='')
    parser.add_argument('--now', type=int)
    args = parser.parse_args()
    action = args.action.strip()
    if action not in rollout_manifest.ACTIONS:
        raise release_lib.ReleaseError('unknown rollout action')
    now = args.now if args.now is not None else int(__import__('time').time())
    document = json.loads(args.manifest.read_text(encoding='utf-8'))
    if not isinstance(document, dict):
        raise release_lib.ReleaseError('manifest is not a signed update document')
    try:
        payload = base64.b64decode(document.get('payload', ''), validate=True)
        signature = base64.b64decode(document.get('signature', ''), validate=True)
    except Exception as error:
        raise release_lib.ReleaseError('manifest is not a signed update document') from error
    parsed = json.loads(payload)
    if not isinstance(parsed, dict):
        raise release_lib.ReleaseError('manifest payload is not an object')
    digest = release_lib.sha256_file(args.archive)
    encoded_digest = base64.b64encode(digest).decode('ascii')
    if parsed.get('sha256') != encoded_digest:
        raise release_lib.ReleaseError('manifest sha256 does not match Watt.tar')
    signer = _signer()
    with tempfile.TemporaryDirectory(prefix='watt-rollout-') as temporary:
        directory = Path(temporary)
        pem = signer._pem_from_env(directory)
        signer.sign_payload(pem, payload, directory)
        # sign_payload verifies a fresh signature. Confirm the published one matches this key.
        fresh = signer.sign_payload(pem, payload, directory)
        if fresh != signature:
            raise release_lib.ReleaseError('published manifest was not signed by WATT_UPDATE_SIGNING_KEY')
    rollout = parsed.get('rollout')
    tag = 'v' + release_lib.marketing_from_build(int(parsed['build']))
    if not isinstance(rollout, dict):
        if action != 'sync':
            raise release_lib.ReleaseError('published manifest has no rollout to change')
        _emit('changed', 'false')
        _emit('deploy', 'false')
        _emit('cask', 'true' if rollout_manifest.cask_ready(parsed, now) else 'false')
        _emit('tag', tag)
        return
    updated, changed = rollout_manifest.apply_action(rollout, action, now, _percent(args.percent))
    notes = parsed.get('notes')
    if notes is not None and not isinstance(notes, str):
        raise release_lib.ReleaseError('manifest notes are not text')
    new_payload = release_lib.manifest_payload(
        str(parsed['identity']),
        int(parsed['build']),
        digest,
        str(parsed['minimumSystemVersion']),
        notes,
        updated,
    )
    if not changed or new_payload == payload:
        _emit('changed', 'false')
        _emit('deploy', 'false')
        _emit('cask', 'true' if rollout_manifest.cask_ready(parsed, now) else 'false')
        _emit('tag', tag)
        return
    with tempfile.TemporaryDirectory(prefix='watt-rollout-sign-') as temporary:
        directory = Path(temporary)
        pem = signer._pem_from_env(directory)
        new_signature = signer.sign_payload(pem, new_payload, directory)
    args.manifest.write_bytes(release_lib.signed_update_document(new_payload, new_signature) + b'\n')
    ready = rollout_manifest.cask_ready(json.loads(new_payload), now)
    _emit('changed', 'true')
    _emit('deploy', 'true')
    _emit('cask', 'true' if ready else 'false')
    _emit('tag', tag)


if __name__ == '__main__':
    try:
        main()
    except (release_lib.ReleaseError, rollout_manifest.RolloutError, OSError, ValueError, KeyError, TypeError) as error:
        print('BLOCKED: ' + str(error), file=sys.stderr)
        sys.exit(1)
