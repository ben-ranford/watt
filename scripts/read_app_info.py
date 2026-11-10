#!/usr/bin/env python3
"""Print identity fields from a built Watt Info.plist, one KEY=value per line."""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import release_lib


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('plist', type=Path)
    parser.add_argument('--expect-marketing', required=True)
    args = parser.parse_args()
    try:
        info = release_lib.read_app_info(args.plist)
        release_lib.parse_version(args.expect_marketing)
        if info['marketing'] != args.expect_marketing:
            raise release_lib.ReleaseError(
                'CFBundleShortVersionString ' + str(info['marketing']) + ' does not match ' + args.expect_marketing
            )
        print('IDENTITY=' + str(info['identity']))
        print('BUILD=' + str(info['build']))
        print('MARKETING=' + str(info['marketing']))
        print('MINIMUM=' + str(info['minimum']))
    except (release_lib.ReleaseError, OSError, ValueError) as error:
        print('BLOCKED: ' + str(error), file=sys.stderr)
        sys.exit(1)


if __name__ == '__main__':
    main()
