#!/usr/bin/env python3
"""Check a pull request title and description.

Release Please cuts the Watt version from the title. The description has to
follow .github/pull_request_template.md, including a checkbox test plan.
The workflow passes the pull request fields in the environment so the body
never reaches the shell. An optional argv title is for a local title check.
"""

from __future__ import annotations

import os
import re
import sys
from typing import NamedTuple

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

# Same branch Release Please is allowed to push. See .github/workflows/release.yml.
RELEASE_BRANCH = re.compile(
    r'^release-please--branches--main(--components--[A-Za-z0-9._-]+)?$'
)

TITLE = re.compile(
    r'^(?P<type>[a-z]+)'
    r'(?:\((?P<scope>[^)]*)\))?'
    r'(?P<breaking>!)?: (?P<subject>\S.*)$'
)
KEBAB = re.compile(r'^[a-z0-9]+(?:-[a-z0-9]+)*$')

# Required H2s, in template order. Assumptions sits between Test plan and Docs.
REQUIRED_HEADINGS = (
    'Summary',
    'Linked issue',
    'Change type',
    'Validation',
    'Test plan',
    'Docs and changelog',
)
OPTIONAL_HEADING = 'Assumptions to confirm'
HEADING_ORDER = (
    'Summary',
    'Linked issue',
    'Change type',
    'Validation',
    'Test plan',
    OPTIONAL_HEADING,
    'Docs and changelog',
)

ATX = re.compile(r'^(#{1,6})[ \t]+(.+?)[ \t]*#*[ \t]*$')
CHECKBOX = re.compile(r'^[ \t]*-[ \t]+\[([ xX])\][ \t]*(.*)$')
HTML_COMMENT = re.compile(r'<!--.*?-->', re.DOTALL)

# 10–12 uppercase letters and digits. Commit SHAs are hex (or longer than 12).
# Apple's serial alphabet has no vowels, which also skips the 10-character team id.
SERIAL = re.compile(r'\b[A-Z0-9]{10,12}\b')
HEX_LETTERS = set('ABCDEF')
VOWELS = set('AEIOU')
UUID = re.compile(
    r'\b[0-9A-Fa-f]{8}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-'
    r'[0-9A-Fa-f]{4}-[0-9A-Fa-f]{12}\b'
)
URL = re.compile(r'https?://\S+')
PHRASES = (
    ('mac time', re.compile(r'\bmac time\b', re.IGNORECASE)),
    ('minutes of mac', re.compile(r'\bminutes of mac\b', re.IGNORECASE)),
    ('needs a Mac from', re.compile(r'\bneeds? a mac from\b', re.IGNORECASE)),
)
BREAKING_FOOTER = re.compile(r'BREAKING[ -]CHANGE')
PLACEHOLDER_SUMMARY = {'what changed, and why.', 'what changed, and why'}

BUMP_LABEL = {
    'patch': '`fix:` (patch)',
    'minor': '`feat:` (minor)',
    'major': '`feat!:` or `BREAKING CHANGE` (major)',
    'none': (
        '`build:`, `chore:`, `ci:`, `deps:`, `docs:`, `perf:`, '
        '`refactor:`, `revert:`, `style:`, or `test:` (no version bump)'
    ),
}

BOT_LOGINS = {
    'github-actions[bot]',
    'github-actions',
    'app/github-actions',
    'release-please[bot]',
}


class ParsedTitle(NamedTuple):
    type: str
    breaking: bool
    scope: str | None
    subject: str


def title_shape(title: str) -> ParsedTitle | None:
    """Return the Conventional Commit parts, ignoring subject and scope rules."""
    match = TITLE.fullmatch(title)
    if match is None or match.group('type') not in TYPES:
        return None
    return ParsedTitle(
        match.group('type'),
        match.group('breaking') is not None,
        match.group('scope'),
        match.group('subject'),
    )


def title_problems(title: str) -> list[str]:
    if '\n' in title or '\r' in title:
        return ['The title must be a single line, with no surrounding whitespace.']
    problems: list[str] = []
    if title != title.strip():
        problems.append('The title must be a single line, with no surrounding whitespace.')
    candidate = title.strip()
    if len(title) > 72:
        problems.append(
            'The title is %d characters. Keep the whole title to 72 characters or fewer.'
            % len(title)
        )
    parsed = title_shape(candidate)
    if parsed is None:
        listed = ', '.join(TYPES)
        problems.append(
            'The title must be a Conventional Commit such as '
            '"fix: show charger watts" or "feat(menu-bar)!: change the reading". '
            'Types: %s.' % listed
        )
        return problems
    if parsed.scope is not None and KEBAB.fullmatch(parsed.scope) is None:
        problems.append(
            'The scope must be lowercase kebab-case, such as `menu-bar`, or be left off.'
        )
    if not parsed.subject[:1].isascii() or not parsed.subject[:1].islower():
        problems.append('The subject must start with a lowercase letter.')
    if parsed.subject.endswith('.'):
        problems.append('The subject must not end with a period.')
    return problems


def title_error(title: str) -> str | None:
    found = title_problems(title)
    return found[0] if found else None


def looks_like_mac_serial(token: str) -> bool:
    letters = [character for character in token if character.isalpha()]
    if not letters or not any(character.isdigit() for character in token):
        return False
    if any(character in VOWELS for character in letters):
        return False
    if all(character in HEX_LETTERS for character in letters):
        return False
    return True


def _unique(tokens: list[str]) -> list[str]:
    seen: list[str] = []
    for token in tokens:
        if token not in seen:
            seen.append(token)
    return seen


def banned_problems(text: str, where: str) -> list[str]:
    problems: list[str] = []
    serials = _unique(
        match.group(0)
        for match in SERIAL.finditer(text)
        if looks_like_mac_serial(match.group(0))
    )
    if serials:
        problems.append(
            'Remove the Mac serial number %s from the %s.'
            % (', '.join('`%s`' % token for token in serials), where)
        )
    scrubbed = URL.sub(lambda match: ' ' * len(match.group(0)), text)
    uuids: list[str] = []
    for match in UUID.finditer(scrubbed):
        prefix = scrubbed[max(0, match.start() - 3):match.start()]
        if prefix.lower() == 'bc-':
            continue
        uuids.append(match.group(0))
    uuids = _unique(uuids)
    if uuids:
        problems.append(
            'Remove the hardware UUID %s from the %s.'
            % (', '.join('`%s`' % token for token in uuids), where)
        )
    for phrase, pattern in PHRASES:
        if pattern.search(text):
            problems.append('Remove the phrase "%s" from the %s.' % (phrase, where))
    return problems


def is_release_please(author: str, author_type: str, head_ref: str) -> bool:
    """Release Please's changelog body is exempt. The title is still checked."""
    if RELEASE_BRANCH.fullmatch(head_ref) is None:
        return False
    if author_type.casefold() == 'bot':
        return True
    login = author.casefold()
    return login.endswith('[bot]') or login in BOT_LOGINS


def _outside_fences(lines: list[str]) -> list[bool]:
    visible: list[bool] = []
    fenced = False
    for line in lines:
        if line.lstrip().startswith('```'):
            fenced = not fenced
            visible.append(False)
            continue
        visible.append(not fenced)
    return visible


def headings(body: str) -> list[tuple[int, int, str]]:
    lines = body.splitlines()
    visible = _outside_fences(lines)
    found: list[tuple[int, int, str]] = []
    for index, line in enumerate(lines):
        if not visible[index]:
            continue
        match = ATX.fullmatch(line)
        if match is None:
            continue
        found.append((index, len(match.group(1)), match.group(2).strip()))
    return found


def is_disallowed_heading(text: str) -> bool:
    lowered = text.casefold()
    has_mac = re.search(r'\bmac(?:os)?\b', lowered) is not None
    has_list = 'test plan' in lowered or 'checklist' in lowered
    return has_mac and has_list


def _section_text(body: str, start: int, level: int) -> str:
    lines = body.splitlines()
    end = len(lines)
    for index, heading_level, _text in headings(body):
        if index > start and heading_level <= level:
            end = index
            break
    return '\n'.join(lines[start + 1:end])


def section_bodies(body: str) -> dict[str, str]:
    lines = body.splitlines()
    found = [(index, text) for index, level, text in headings(body) if level == 2]
    sections: dict[str, str] = {}
    for position, (start, text) in enumerate(found):
        if text in sections:
            continue
        end = found[position + 1][0] if position + 1 < len(found) else len(lines)
        sections[text] = '\n'.join(lines[start + 1:end])
    return sections


def _without_comments(text: str) -> str:
    return HTML_COMMENT.sub('', text)


def _checkbox_mark(line: str) -> tuple[str, str] | None:
    match = CHECKBOX.match(line)
    if match is None:
        return None
    return match.group(1), match.group(2)


def classify_bump(label: str) -> str | None:
    lowered = label.casefold()
    if 'no version bump' in lowered or re.search(r'\bno bump\b', lowered):
        return 'none'
    if re.search(r'\bmajor\b', lowered) or 'breaking change' in lowered:
        return 'major'
    if re.search(r'\bminor\b', lowered):
        return 'minor'
    if re.search(r'\bpatch\b', lowered):
        return 'patch'
    return None


def body_declares_breaking(body: str) -> bool:
    for line in body.splitlines():
        if _checkbox_mark(line) is not None:
            continue
        if BREAKING_FOOTER.search(line):
            return True
    return False


def expected_bump(title: str, body: str) -> str | None:
    parsed = title_shape(title.strip())
    if parsed is None or '\n' in title or '\r' in title:
        return None
    if parsed.breaking or body_declares_breaking(body):
        return 'major'
    if parsed.type == 'fix':
        return 'patch'
    if parsed.type == 'feat':
        return 'minor'
    return 'none'


def _heading_problems(body: str) -> list[str]:
    problems: list[str] = []
    found = headings(body)
    disallowed: set[str] = set()
    for _index, level, text in found:
        if not is_disallowed_heading(text):
            continue
        disallowed.add(text)
        problems.append(
            'Heading "%s %s" is not allowed. Move that list under "## Test plan" '
            'as checkbox items (`- [ ]` or `- [x]`).' % ('#' * level, text)
        )
    h2s = [text for _index, level, text in found if level == 2 and text not in disallowed]
    wrong_level = {
        text: level
        for _index, level, text in found
        if level != 2 and text not in h2s and (text in REQUIRED_HEADINGS or text == OPTIONAL_HEADING)
    }
    for text in h2s:
        if text in REQUIRED_HEADINGS or text == OPTIONAL_HEADING:
            continue
        if text.casefold().startswith('assumptions to confirm'):
            problems.append(
                'Unexpected heading "## %s". Name that section exactly '
                '"## Assumptions to confirm".' % text
            )
        else:
            problems.append(
                'Unexpected heading "## %s". Keep the headings from the pull request template.'
                % text
            )
    allowed = [text for text in h2s if text in REQUIRED_HEADINGS or text == OPTIONAL_HEADING]
    if len(allowed) != len(set(allowed)):
        problems.append('A template heading is repeated. Keep each heading once.')
    for name in REQUIRED_HEADINGS:
        if name in allowed:
            continue
        if name in wrong_level:
            problems.append(
                'Heading "%s %s" must be the H2 "## %s".'
                % ('#' * wrong_level[name], name, name)
            )
        elif name == 'Test plan':
            problems.append(
                'Missing "## Test plan". Add that heading with at least one '
                'checkbox (`- [ ]` or `- [x]`).'
            )
        else:
            problems.append('Missing "## %s".' % name)
    canonical = [
        name for name in HEADING_ORDER
        if name != OPTIONAL_HEADING or OPTIONAL_HEADING in allowed
    ]
    present = [name for name in canonical if name in allowed]
    if allowed != present:
        listed = ', '.join('"## %s"' % name for name in canonical)
        problems.append('Headings are out of order. Use this order: %s.' % listed)
    return problems


def _summary_problems(section: str) -> list[str]:
    text = _without_comments(section).strip()
    normalized = re.sub(r'\s+', ' ', text).casefold()
    if normalized == '':
        return ['Summary is empty. Replace the template note with what changed and why.']
    if normalized in PLACEHOLDER_SUMMARY:
        return ['Summary is still the template placeholder. Say what changed and why.']
    return []


def _change_type_problems(section: str, expected: str | None) -> list[str]:
    checked: list[str] = []
    unrecognised = 0
    for line in section.splitlines():
        mark = _checkbox_mark(line)
        if mark is None or mark[0] == ' ':
            continue
        kind = classify_bump(mark[1])
        if kind is None:
            unrecognised += 1
        else:
            checked.append(kind)
    total = len(checked) + unrecognised
    if total != 1 or unrecognised:
        if expected is None:
            return ['Tick exactly one change type box from the template.']
        suffix = '' if total == 1 else ' %d boxes are ticked.' % total
        return ['Tick exactly one change type, %s.%s' % (BUMP_LABEL[expected], suffix)]
    if expected is not None and checked[0] != expected:
        return [
            'The ticked change type does not match this title. Tick %s.'
            % BUMP_LABEL[expected]
        ]
    return []


def _is_checkbox_line(line: str) -> bool:
    return _checkbox_mark(line) is not None


def _test_plan_problems(section: str) -> list[str]:
    if any(_is_checkbox_line(line) for line in section.splitlines()):
        return []
    return ['"## Test plan" needs at least one checkbox item (`- [ ]` or `- [x]`).']


def _assumption_problems(section: str) -> list[str]:
    lines = [line for line in _without_comments(section).splitlines() if line.strip()]
    boxes = [line for line in lines if _is_checkbox_line(line)]
    if lines and len(boxes) == len(lines):
        return []
    return [
        '"## Assumptions to confirm" must be a checkbox list (`- [ ]` or `- [x]`), '
        'with no other text. Delete the section if there is nothing to confirm.'
    ]


def description_problems(title: str, body: str) -> list[str]:
    text = body.replace('\r\n', '\n').replace('\r', '\n')
    problems = _heading_problems(text)
    sections = section_bodies(text)
    if 'Summary' in sections:
        problems.extend(_summary_problems(sections['Summary']))
    if 'Change type' in sections:
        problems.extend(_change_type_problems(sections['Change type'], expected_bump(title, text)))
    if 'Test plan' in sections:
        problems.extend(_test_plan_problems(sections['Test plan']))
    if OPTIONAL_HEADING in sections:
        problems.extend(_assumption_problems(sections[OPTIONAL_HEADING]))
    h2_texts = set(sections)
    for index, level, heading in headings(text):
        if level == 2 or heading in h2_texts:
            continue
        section = _section_text(text, index, level)
        if heading == 'Test plan':
            problems.extend(_test_plan_problems(section))
        elif heading.casefold().startswith('assumptions to confirm'):
            problems.extend(_assumption_problems(section))
    for heading, section in sections.items():
        if heading == OPTIONAL_HEADING:
            continue
        if heading.casefold().startswith('assumptions to confirm'):
            problems.extend(_assumption_problems(section))
    return problems


def problems(
    title: str,
    body: str | None,
    *,
    author: str = '',
    author_type: str = '',
    head_ref: str = '',
) -> list[str]:
    found = title_problems(title)
    found.extend(banned_problems(title, 'title'))
    if is_release_please(author, author_type, head_ref):
        return found
    if body is None:
        found.append('The description is missing. Fill in the pull request template.')
        return found
    found.extend(description_problems(title, body))
    found.extend(banned_problems(body, 'description'))
    return found


def main() -> None:
    if len(sys.argv) > 2:
        print('BLOCKED: pass one title, or set PR_TITLE', file=sys.stderr)
        sys.exit(2)
    if len(sys.argv) == 2:
        title = sys.argv[1]
    elif 'PR_TITLE' not in os.environ:
        print('BLOCKED: PR_TITLE is not set', file=sys.stderr)
        sys.exit(1)
    else:
        title = os.environ['PR_TITLE']
    body = os.environ['PR_BODY'] if 'PR_BODY' in os.environ else None
    found = problems(
        title,
        body,
        author=os.environ.get('PR_AUTHOR', ''),
        author_type=os.environ.get('PR_AUTHOR_TYPE', ''),
        head_ref=os.environ.get('PR_HEAD_REF', ''),
    )
    if found:
        label = 'problem' if len(found) == 1 else 'problems'
        print('BLOCKED: this pull request has %d %s:' % (len(found), label), file=sys.stderr)
        for item in found:
            print('- ' + item, file=sys.stderr)
        if title_problems(title):
            print('title: ' + ascii(title), file=sys.stderr)
        sys.exit(1)
    if is_release_please(
        os.environ.get('PR_AUTHOR', ''),
        os.environ.get('PR_AUTHOR_TYPE', ''),
        os.environ.get('PR_HEAD_REF', ''),
    ):
        print('PASS: release pull request title')
        return
    print('PASS: pull request title and description')


if __name__ == '__main__':
    main()
