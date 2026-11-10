#!/usr/bin/env python3
"""Decode one base64 secret from the environment into a mode-0600 file.

The secret name is the only argument. The secret value is never printed.
"""

from __future__ import annotations

import os
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import release_lib


def main() -> None:
    if len(sys.argv) != 3:
        print('usage: decode_secret.py ENV_NAME OUTPUT', file=sys.stderr)
        sys.exit(2)
    name, output = sys.argv[1], Path(sys.argv[2])
    if not name.isidentifier():
        print('BLOCKED: unexpected secret name', file=sys.stderr)
        sys.exit(1)
    value = os.environ.get(name, '')
    try:
        release_lib.decode_base64_env(value, output)
    except release_lib.ReleaseError as error:
        print('BLOCKED: ' + name + ' ' + str(error), file=sys.stderr)
        sys.exit(1)


if __name__ == '__main__':
    main()
