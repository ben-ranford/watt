#!/usr/bin/env python3
"""Write an exportOptions plist for Developer ID or ad-hoc export."""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import release_lib


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('mode', choices=['developer-id', 'ad-hoc'])
    parser.add_argument('output', type=Path)
    parser.add_argument('--team-id', default='')
    args = parser.parse_args()
    try:
        release_lib.write_export_options(args.mode, args.team_id, args.output)
    except release_lib.ReleaseError as error:
        print('BLOCKED: ' + str(error), file=sys.stderr)
        sys.exit(1)


if __name__ == '__main__':
    main()
