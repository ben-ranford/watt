#!/usr/bin/env python3
"""Check Watt's resolved marketing version and build in xcodebuild -showBuildSettings output."""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import release_lib


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('log', type=Path)
    parser.add_argument('--marketing', required=True)
    parser.add_argument('--build', required=True)
    args = parser.parse_args()
    try:
        release_lib.parse_version(args.marketing)
        expected_build = str(release_lib.validate_build(args.build))
        settings = release_lib.parse_show_build_settings(args.log.read_text(), 'Watt')
        marketing = settings.get('MARKETING_VERSION', '')
        build = settings.get('CURRENT_PROJECT_VERSION', '')
        if marketing != args.marketing or build != expected_build:
            raise release_lib.ReleaseError(
                'Watt build settings resolved MARKETING_VERSION='
                + marketing
                + ' CURRENT_PROJECT_VERSION='
                + build
            )
        # ENABLE_TESTABILITY injects com.apple.security.get-task-allow at code-sign time
        # even when the entitlements file is empty. Published archives pass NO.
        if settings.get('ENABLE_TESTABILITY') != 'NO' or settings.get('CODE_SIGN_INJECT_BASE_ENTITLEMENTS') != 'NO':
            raise release_lib.ReleaseError(
                'release archive must set ENABLE_TESTABILITY=NO and '
                'CODE_SIGN_INJECT_BASE_ENTITLEMENTS=NO so get-task-allow is not signed in'
            )
        print('PASS: xcodebuild settings match', args.marketing, expected_build)
    except (release_lib.ReleaseError, OSError) as error:
        print('BLOCKED: ' + str(error), file=sys.stderr)
        sys.exit(1)


if __name__ == '__main__':
    main()
