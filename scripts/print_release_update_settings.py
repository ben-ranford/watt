#!/usr/bin/env python3
"""Print Release update build settings for an ad-hoc CI app.

The URLs come from Resources/ReleaseIdentity.json. The public key is the
published Ed25519 key in Resources/UpdatePublicKey.txt. Neither value is a
secret. Debug builds leave the settings empty.
"""

from __future__ import annotations

import base64
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent


def settings(root: Path = ROOT) -> list[tuple[str, str]]:
    config = json.loads((root / 'Resources/ReleaseIdentity.json').read_text())
    key = (root / 'Resources/UpdatePublicKey.txt').read_text().strip()
    raw = base64.b64decode(key, validate=True)
    if len(raw) != 32:
        raise ValueError('update public key must be 32 bytes')
    values = [
        ('WATT_UPDATE_MANIFEST_URL', config['updateManifestURL']),
        ('WATT_UPDATE_ARTIFACT_URL', config['updateArtifactURL']),
        ('WATT_UPDATE_PUBLIC_KEY', key),
    ]
    for name, value in values:
        if not isinstance(value, str) or not value or any(character.isspace() for character in value):
            raise ValueError('refusing update setting ' + name)
    return values


def check_plist(path: Path, root: Path = ROOT) -> None:
    import plistlib
    info = plistlib.loads(path.read_bytes())
    expected = dict(settings(root))
    compiled = {
        'WATTUpdateManifestURL': expected['WATT_UPDATE_MANIFEST_URL'],
        'WATTUpdateArtifactURL': expected['WATT_UPDATE_ARTIFACT_URL'],
        'WATTUpdatePublicKey': expected['WATT_UPDATE_PUBLIC_KEY'],
    }
    for key, want in compiled.items():
        value = info.get(key) or ''
        if value != want or '$(' in value or '${' in value:
            raise ValueError('Release app is missing ' + key)


def main() -> None:
    try:
        if len(sys.argv) == 3 and sys.argv[1] == '--check-plist':
            check_plist(Path(sys.argv[2]))
            return
        if len(sys.argv) != 1:
            raise ValueError('usage: print_release_update_settings.py [--check-plist Info.plist]')
        for name, value in settings():
            print(name + '=' + value)
    except (OSError, ValueError, KeyError, json.JSONDecodeError) as error:
        print('BLOCKED: ' + str(error), file=sys.stderr)
        sys.exit(1)


if __name__ == '__main__':
    main()
