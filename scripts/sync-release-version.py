#!/usr/bin/env python3
"""Keep CFBundleVersion aligned with the Release Please marketing version.

Check mode allows the unreleased verification pair (1.0.0 / build 1).
Release mode and --write require MAJOR * 1000000 + MINOR * 1000 + PATCH.
--write updates ReleaseIdentity.json, HelperIdentity.build, the helper plist,
and CURRENT_PROJECT_VERSION. It does not change the bundle identifier.
On macOS it then runs scripts/configure-release-identity.py in check mode.
"""

from __future__ import annotations

import argparse
import subprocess
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import release_lib


def main() -> None:
    root_default = Path(__file__).resolve().parents[1]
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--root', type=Path, default=root_default)
    parser.add_argument('--write', action='store_true', help='rewrite compiled build numbers from the marketing version')
    parser.add_argument('--release', action='store_true', help='require the encoded build; reject the unreleased build 1')
    args = parser.parse_args()
    root = args.root.resolve()
    try:
        version = release_lib.marketing_version(root)
        identity, _build = release_lib.load_identity(root)
        compiled = release_lib.compiled_build(root)
        if args.write:
            expected = release_lib.build_number(version)
            if compiled == expected:
                print(f'CFBundleVersion {expected} already matches {version}')
            else:
                release_lib.write_identity_build(root, expected)
                print(f'CFBundleVersion set to {expected} for marketing version {version}')
            compiled = expected
        allowed = release_lib.acceptable_builds(version, release=args.release or args.write)
        if compiled not in allowed:
            raise release_lib.ReleaseError(
                f'CFBundleVersion {compiled} is not valid for {version}; expected {sorted(allowed)}'
            )
        if root == root_default and Path('/usr/bin/plutil').is_file():
            subprocess.run([sys.executable, str(root / 'scripts/configure-release-identity.py')], cwd=root, check=True)
        elif root == root_default:
            print('SKIP: configure-release-identity.py needs /usr/bin/plutil')
        print(f'PASS: {identity} marketing {version} build {compiled}')
    except (release_lib.ReleaseError, subprocess.CalledProcessError, OSError, ValueError) as error:
        print('BLOCKED: ' + str(error), file=sys.stderr)
        sys.exit(1)


if __name__ == '__main__':
    main()
