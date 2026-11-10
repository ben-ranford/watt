#!/usr/bin/env python3
"""Fail when an archived Watt Info.plist is missing release settings.

scripts/release-archive.sh runs this after xcodebuild archive and before
distribution preflight. A missing or unexpanded key exits non-zero, so the
release job stops instead of uploading an app and skipping the Pages manifest.
"""

from __future__ import annotations

import argparse
import plistlib
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import release_readiness


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('plist', type=Path)
    parser.add_argument('--manifest-url', default='')
    parser.add_argument('--artifact-url', default='')
    parser.add_argument('--public-key', default='')
    args = parser.parse_args()
    try:
        with args.plist.open('rb') as handle:
            info = plistlib.load(handle)
        failures = release_readiness.compiled_release_plist_failures(
            info,
            manifest_url=args.manifest_url,
            artifact_url=args.artifact_url,
            public_key=args.public_key,
        )
        if failures:
            print('BLOCKED: compiled Info.plist is missing release settings passed to xcodebuild.', file=sys.stderr)
            for reason in failures:
                print('BLOCKED: ' + reason, file=sys.stderr)
            sys.exit(1)
        print('PASS: compiled Info.plist contains the release settings')
    except (OSError, plistlib.InvalidFileException, ValueError) as error:
        print('BLOCKED: ' + str(error), file=sys.stderr)
        sys.exit(1)


if __name__ == '__main__':
    main()
