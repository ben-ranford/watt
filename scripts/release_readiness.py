"""Distribution checks that do not need codesign or a Mac.

Release builds are ad-hoc signed. Distribution preflight does not ask for a
Developer ID, a Team ID, or a notarisation ticket. It still rejects the
placeholder bundle id, a non-HTTPS update endpoint, and a missing Ed25519 key.
"""

from __future__ import annotations

import base64
import re
from urllib.parse import urlsplit

PLACEHOLDER_PREFIX = 'dev.watt.verification'
PROTECTED_TRUST = 'protected-installation'


def distribution_plist_failures(info: dict, endpoints: tuple[str, str] | None = None) -> list[str]:
    """Extra Info.plist rules for a published release. Empty means pass.

    `endpoints` is `(manifest URL, artifact URL)` from ReleaseIdentity.json.
    When it is set, the compiled URLs must match those bytes.
    """
    failures: list[str] = []

    def require(value: bool, reason: str) -> None:
        if not value:
            failures.append(reason)

    identity = info.get('CFBundleIdentifier', '')
    require(
        isinstance(identity, str) and not identity.startswith(PLACEHOLDER_PREFIX),
        'owner production bundle IDs are unprovisioned',
    )
    mode = info.get('WATTHelperTrustMode', PROTECTED_TRUST)
    require(
        mode == PROTECTED_TRUST,
        'release helper trust must pin the installed app cdhash',
    )
    for key in ('WATTUpdateManifestURL', 'WATTUpdateArtifactURL'):
        value = info.get(key, '')
        url = urlsplit(value) if isinstance(value, str) else urlsplit('')
        require(
            isinstance(value, str)
            and url.scheme == 'https'
            and bool(url.hostname)
            and not url.username
            and not url.password
            and not url.fragment
            and not url.query
            and (url.port is None or url.port == 443)
            and '$' not in value,
            'configured HTTPS endpoint required: ' + key,
        )
    if endpoints is not None:
        expected = {'WATTUpdateManifestURL': endpoints[0], 'WATTUpdateArtifactURL': endpoints[1]}
        for key, want in expected.items():
            require(info.get(key) == want, 'compiled endpoint must match ReleaseIdentity.json: ' + key)
    try:
        key = base64.b64decode(info.get('WATTUpdatePublicKey', ''), validate=True)
    except (ValueError, TypeError):
        key = b''
    require(len(key) == 32, 'explicit 32-byte Ed25519 release public key required')
    return failures


def codesign_identity_failures(detail: str, requirement: str, name: str, *, distribution: bool) -> list[str]:
    """Identity rules from `codesign -dv` and `codesign -d -r-` text."""
    failures: list[str] = []

    def require(value: bool, reason: str) -> None:
        if not value:
            failures.append(reason)

    require('runtime' in detail, 'hardened runtime required: ' + name)
    if distribution:
        require('Signature=adhoc' in detail, 'release builds are ad-hoc signed: ' + name)
        require('Authority=' not in detail, 'Developer ID authority is not a release identity: ' + name)
        require('cdhash H"' in requirement, 'release code requirement must pin cdhash: ' + name)
        require('anchor apple generic' not in requirement or 'cdhash H"' in requirement,
                'release code requirement must pin cdhash: ' + name)
    else:
        require('Signature=adhoc' in detail or 'Authority=' in detail, 'missing code identity: ' + name)
        require('cdhash H"' in requirement or 'anchor apple' in requirement, 'missing code requirement: ' + name)
    return failures


def entitlement_failures(text: str, name: str, *, distribution: bool, main_app: bool) -> list[str]:
    failures: list[str] = []

    def require(value: bool, reason: str) -> None:
        if not value:
            failures.append(reason)

    require('com.apple.security.cs.disable-library-validation' not in text,
            'library validation must stay on: ' + name)
    require('com.apple.security.app-sandbox' not in text,
            'app sandbox stays off; /Library trust reads and sibling tools are outside a container: ' + name)
    if distribution or not main_app:
        require('com.apple.security.get-task-allow' not in text,
                'debugger entitlement must not ship: ' + name)
    return failures


BUNDLE_ID_RE = re.compile(r'^[A-Za-z0-9.-]+$')
