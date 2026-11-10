#!/usr/bin/env python3
"""Check that a pull request title is a Conventional Commit.

Release Please cuts the Watt version from that title. The workflow passes the
title in PR_TITLE. An optional argv title is for local checks.
"""

from __future__ import annotations

import os
import re
import sys

TYPES = (
    'build',
    'chore',
    'ci',
    'deps',
    'docs',
    'feat',
    'fix',
    'perf',
    'refactor',
    'revert',
    'style',
    'test',
)

PATTERN = re.compile(
    r'^(?:' + '|'.join(TYPES) + r')'
    r'(?:\([A-Za-z0-9._/-]+\))?!?: [^ ].+$'
)


def title_error(title: str) -> str | None:
    if title != title.strip() or '\n' in title or '\r' in title:
        return 'pull request title must be a single line with no surrounding whitespace'
    if PATTERN.fullmatch(title) is None:
        listed = ', '.join(TYPES)
        return (
            'pull request title must be a conventional commit such as '
            '"fix: show charger watts" or "feat(scope)!: change the reading". '
            f'Types: {listed}.'
        )
    return None


def main() -> None:
    if len(sys.argv) > 2:
        print('BLOCKED: pass one title, or set PR_TITLE', file=sys.stderr)
        sys.exit(2)
    title = sys.argv[1] if len(sys.argv) == 2 else os.environ.get('PR_TITLE')
    if title is None:
        print('BLOCKED: PR_TITLE is not set', file=sys.stderr)
        sys.exit(1)
    error = title_error(title)
    if error:
        print('BLOCKED: ' + error, file=sys.stderr)
        print('title: ' + ascii(title), file=sys.stderr)
        sys.exit(1)
    print('PASS: conventional commit title')


if __name__ == '__main__':
    main()
