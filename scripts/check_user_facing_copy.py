#!/usr/bin/env python3
"""Fail if user-facing copy contains an em dash (U+2014).

Watt copy uses commas, colons, periods, or parentheses instead of an em dash.
The typographic unavailable token in the menu bar and panel is a bare "—"
string literal; that token is allowed. Code comments are ignored unless they
are also a string literal. Developer-only docs such as AGENTS.md are out of
scope.
"""

from __future__ import annotations

import sys
from pathlib import Path

EM_DASH = '\u2014'
UNAVAILABLE_TOKEN = EM_DASH
SWIFT_ESCAPE = '\\u{2014}'

# Paths readers can see: the app, the site, README, changelog, templates,
# and the Homebrew cask description.
COPY_FILES = (
    'README.md',
    'CHANGELOG.md',
    '.github/pull_request_template.md',
    'scripts/render_homebrew_cask.py',
)
COPY_DIRECTORIES = (
    ('docs', ('.html', '.md', '.txt', '.xml')),
    ('.github/ISSUE_TEMPLATE', ('.yml', '.yaml', '.md')),
    ('App', ('.swift',)),
    ('Features', ('.swift',)),
    ('DesignSystem', ('.swift',)),
    ('Models', ('.swift',)),
)

ROOT = Path(__file__).resolve().parents[1]


def iter_copy_paths(root: Path) -> list[Path]:
    paths = [root / relative for relative in COPY_FILES]
    for directory, suffixes in COPY_DIRECTORIES:
        base = root / directory
        if not base.is_dir():
            continue
        for path in sorted(base.rglob('*')):
            if path.is_file() and path.suffix in suffixes:
                paths.append(path)
    return [path for path in paths if path.is_file()]


def _advance_line(char: str, line: int) -> int:
    return line + 1 if char == '\n' else line


def swift_string_literals(source: str) -> list[tuple[int, str]]:
    """Return (line number, unescaped-as-written content) for Swift strings."""
    literals: list[tuple[int, str]] = []
    index = 0
    length = len(source)
    line = 1
    while index < length:
        char = source[index]
        if char == '\n':
            line += 1
            index += 1
            continue
        if char == '/' and index + 1 < length and source[index + 1] == '/':
            index += 2
            while index < length and source[index] != '\n':
                index += 1
            continue
        if char == '/' and index + 1 < length and source[index + 1] == '*':
            index += 2
            while index + 1 < length and not (source[index] == '*' and source[index + 1] == '/'):
                line = _advance_line(source[index], line)
                index += 1
            index = min(index + 2, length)
            continue
        if char == '"':
            start_line = line
            delimiter = '"""' if source.startswith('"""', index) else '"'
            index += len(delimiter)
            chunks: list[str] = []
            while index < length and not source.startswith(delimiter, index):
                if source[index] == '\\' and index + 1 < length:
                    chunks.append(source[index:index + 2])
                    line = _advance_line(source[index + 1], line)
                    index += 2
                    continue
                line = _advance_line(source[index], line)
                chunks.append(source[index])
                index += 1
            literals.append((start_line, ''.join(chunks)))
            index += len(delimiter)
            continue
        index += 1
    return literals


def findings_in_text(relative: str, text: str) -> list[str]:
    """Return human-readable findings for one copy file."""
    found: list[str] = []
    if relative.endswith('.swift'):
        for line_number, content in swift_string_literals(text):
            escaped = SWIFT_ESCAPE.lower() in content.lower()
            has_em = EM_DASH in content
            if not has_em and not escaped:
                continue
            if content == UNAVAILABLE_TOKEN and not escaped:
                continue
            found.append(
                f'{relative}:{line_number}: em dash (U+2014) in a user-facing string'
            )
        return found

    for line_number, line in enumerate(text.splitlines(), 1):
        if EM_DASH in line:
            found.append(
                f'{relative}:{line_number}: em dash (U+2014) in user-facing copy'
            )
            continue
        lowered = line.lower()
        for entity in ('&mdash;', '&#8212;', '&#x2014;'):
            if entity in lowered:
                found.append(
                    f'{relative}:{line_number}: HTML entity {entity} in user-facing copy'
                )
                break
        else:
            # " -- " used as a dash, not a command flag such as `brew install --cask`.
            if ' -- ' in line:
                found.append(
                    f'{relative}:{line_number}: " -- " used as a dash in user-facing copy'
                )
    return found


def scan(root: Path) -> list[str]:
    found: list[str] = []
    for path in iter_copy_paths(root):
        relative = path.relative_to(root).as_posix()
        try:
            text = path.read_text(encoding='utf-8')
        except UnicodeDecodeError as error:
            found.append(f'{relative}: could not read as UTF-8 ({error})')
            continue
        found.extend(findings_in_text(relative, text))
    return found


def main(argv: list[str] | None = None) -> None:
    arguments = sys.argv[1:] if argv is None else argv
    if len(arguments) > 1:
        print('BLOCKED: pass zero or one repository root', file=sys.stderr)
        sys.exit(2)
    root = Path(arguments[0]).resolve() if arguments else ROOT
    if not root.is_dir():
        print('BLOCKED: repository root is not a directory', file=sys.stderr)
        sys.exit(2)
    found = scan(root)
    if found:
        label = 'problem' if len(found) == 1 else 'problems'
        print(
            'BLOCKED: user-facing copy has %d %s:' % (len(found), label),
            file=sys.stderr,
        )
        for item in found:
            print('- ' + item, file=sys.stderr)
        sys.exit(1)
    print('PASS: user-facing copy has no em dashes')


if __name__ == '__main__':
    main()
