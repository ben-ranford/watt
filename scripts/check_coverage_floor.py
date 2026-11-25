#!/usr/bin/env python3
"""Compare xccov line coverage with the checked-in floor.

The macOS job runs this after `xcodebuild test -enableCodeCoverage YES`.
Line coverage is the Watt app and the helper tools only. Test bundles,
generated files, and SwiftUI preview entry points are left out. Percentages
print with the floor beside them. When `enforce` is true, the process exits 1
if a target or the overall total is under the floor. When `enforce` is false,
a short total is a warning annotation and the process still exits 0. A total
two or more points above its floor prints a notice. This script does not edit
the floor file.
"""

from __future__ import annotations

import argparse
import json
import os
import subprocess
import sys
from dataclasses import dataclass
from pathlib import Path

PRODUCT_TARGETS = (
    'Watt',
    'WattHelper',
    'WattMaintenance',
    'WattHelperInstaller',
)

GENERATED_PATH_MARKERS = (
    '/DerivedData/',
    '/DerivedSources/',
    '/Intermediates.noindex/',
    '/Index.noindex/',
    '/.build/',
    '/SourcePackages/',
    '/checkouts/',
)

GENERATED_FILENAMES = {
    'GeneratedAssetSymbols.swift',
    'GeneratedStringSymbols.swift',
    'resource_bundle_accessor.swift',
}


class CoverageError(Exception):
    """The report or the floor file cannot be checked."""


@dataclass(frozen=True)
class LineCount:
    covered: int
    executable: int


@dataclass(frozen=True)
class Measurement:
    targets: dict[str, LineCount]
    skipped_targets: tuple[str, ...]
    report_targets: tuple[str, ...]
    excluded_generated_files: int
    excluded_preview_files: int
    excluded_preview_functions: int


@dataclass(frozen=True)
class Floor:
    overall: int
    targets: dict[str, int]
    enforce: bool = True


@dataclass(frozen=True)
class Row:
    name: str
    covered: int | None
    executable: int | None
    floor: int


@dataclass(frozen=True)
class Evaluation:
    rows: tuple[Row, ...]
    failures: tuple[str, ...]
    notices: tuple[str, ...]
    measurement: Measurement
    enforce: bool


def is_generated(path: str) -> bool:
    normalized = path.replace('\\', '/')
    if not normalized.startswith('/'):
        normalized = '/' + normalized
    if any(marker in normalized for marker in GENERATED_PATH_MARKERS):
        return True
    name = normalized.rsplit('/', 1)[-1]
    return name.endswith('.generated.swift') or name in GENERATED_FILENAMES


def is_preview_file(path: str) -> bool:
    normalized = path.replace('\\', '/')
    name = normalized.rsplit('/', 1)[-1]
    if name.endswith('Previews.swift') or name.endswith('PreviewProvider.swift'):
        return True
    return '/Preview Content/' in normalized


def is_preview_function(name: str) -> bool:
    """SwiftUI canvas entry points, not product members that contain "preview".

    `PowerReadingStore.preview` and `ComponentPreviewView` stay in the total.
    `WattComponentGallery_Previews.previews.getter` and `#Preview` do not.
    """
    if '_Previews' in name or 'PreviewProvider' in name or '#Preview' in name:
        return True
    lowered = name.lower()
    return '.previews' in lowered or lowered.endswith('previews')


def suggested_floor(covered: int, executable: int) -> int:
    """Whole percent, rounded down, then one point lower. Never negative."""
    if executable <= 0:
        raise CoverageError('cannot suggest a floor without executable lines')
    whole = (covered * 100) // executable
    return max(0, whole - 1)


def format_percent(covered: int, executable: int) -> str:
    if executable <= 0:
        return 'n/a'
    tenths = (covered * 1000 + executable // 2) // executable
    return f'{tenths // 10}.{tenths % 10}%'


def _require_count(value: object, label: str) -> int:
    if isinstance(value, bool) or not isinstance(value, (int, float)):
        raise CoverageError(f'{label} is missing a line count')
    if isinstance(value, float) and not value.is_integer():
        raise CoverageError(f'{label} is not a whole line count')
    number = int(value)
    if number < 0:
        raise CoverageError(f'{label} has a negative line count')
    return number


def _require_percent(value: object, label: str) -> int:
    if isinstance(value, bool) or not isinstance(value, int):
        raise CoverageError(f'{label} must be a whole-number percent')
    if value < 0 or value > 100:
        raise CoverageError(f'{label} must be from 0 to 100')
    return value


def _candidate_names(value: str) -> list[str]:
    if not value:
        return []
    names: list[str] = []
    for part in Path(value).parts:
        base = part
        for suffix in ('.app', '.xctest', '.framework'):
            if base.endswith(suffix):
                base = base[: -len(suffix)]
                break
        if base and base not in names:
            names.append(base)
    return names


def classify_target(name: str, build_product_path: str) -> tuple[str, str]:
    """Return `(kind, key)` where kind is `product`, `test`, or `other`."""
    from_name = _candidate_names(name)
    from_path = _candidate_names(build_product_path)
    for candidate in from_name:
        if candidate in PRODUCT_TARGETS:
            return ('product', candidate)
    for candidate in from_name:
        if candidate.endswith('Tests'):
            return ('test', candidate)
    if '.xctest' in f'{name} {build_product_path}':
        label = from_name[0] if from_name else name or 'unknown'
        return ('test', label)
    for candidate in from_path:
        if candidate in PRODUCT_TARGETS:
            return ('product', candidate)
    for candidate in from_path:
        if candidate.endswith('Tests'):
            return ('test', candidate)
    label = from_name[0] if from_name else (name or 'unknown')
    return ('other', label)


def _file_count(file_obj: dict, stats: dict[str, int]) -> LineCount | None:
    path = file_obj.get('path') or file_obj.get('name') or ''
    if not isinstance(path, str) or not path:
        raise CoverageError('a coverage file is missing a path')
    if is_generated(path):
        stats['generated'] += 1
        return None
    if is_preview_file(path):
        stats['preview_files'] += 1
        return None
    label = path
    covered = _require_count(file_obj.get('coveredLines'), f'{label} coveredLines')
    executable = _require_count(file_obj.get('executableLines'), f'{label} executableLines')
    functions = file_obj.get('functions') or []
    if not isinstance(functions, list):
        raise CoverageError(f'{label} functions must be a list')
    for function in functions:
        if not isinstance(function, dict):
            raise CoverageError(f'{label} has a function that is not an object')
        function_name = function.get('name')
        if not isinstance(function_name, str) or not is_preview_function(function_name):
            continue
        preview_covered = _require_count(
            function.get('coveredLines'), f'{function_name} coveredLines')
        preview_executable = _require_count(
            function.get('executableLines'), f'{function_name} executableLines')
        drop_executable = min(preview_executable, executable)
        drop_covered = min(preview_covered, covered, drop_executable)
        if drop_executable == 0 and drop_covered == 0:
            continue
        executable -= drop_executable
        covered -= drop_covered
        stats['preview_functions'] += 1
    if executable <= 0:
        return None
    return LineCount(covered, executable)


def measure(report: dict) -> Measurement:
    if not isinstance(report, dict) or not isinstance(report.get('targets'), list):
        raise CoverageError('coverage report has no targets')
    totals: dict[str, LineCount] = {}
    skipped: list[str] = []
    report_names: list[str] = []
    stats = {'generated': 0, 'preview_files': 0, 'preview_functions': 0}
    for target in report['targets']:
        if not isinstance(target, dict):
            raise CoverageError('a coverage target is not an object')
        raw_name = target.get('name')
        if not isinstance(raw_name, str) or not raw_name:
            raise CoverageError('a coverage target is missing a name')
        report_names.append(raw_name)
        path = target.get('buildProductPath') or ''
        if not isinstance(path, str):
            raise CoverageError(f'{raw_name} buildProductPath is not a string')
        kind, key = classify_target(raw_name, path)
        if kind != 'product':
            if key not in skipped:
                skipped.append(key)
            continue
        files = target.get('files')
        if not isinstance(files, list):
            raise CoverageError(f'{key} coverage has no file list, so exclusions cannot be applied')
        covered = 0
        executable = 0
        seen_paths: dict[str, LineCount] = {}
        for file_obj in files:
            if not isinstance(file_obj, dict):
                raise CoverageError(f'{key} has a file that is not an object')
            count = _file_count(file_obj, stats)
            if count is None:
                continue
            file_path = str(file_obj.get('path') or file_obj.get('name'))
            previous = seen_paths.get(file_path)
            if previous is None or (count.executable, count.covered) > (previous.executable, previous.covered):
                seen_paths[file_path] = count
        for count in seen_paths.values():
            covered += count.covered
            executable += count.executable
        previous_target = totals.get(key)
        if previous_target is None:
            totals[key] = LineCount(covered, executable)
        else:
            # Two slices of one product: keep the slice with more instrumented lines.
            if (executable, covered) > (previous_target.executable, previous_target.covered):
                totals[key] = LineCount(covered, executable)
    ordered = {name: totals[name] for name in PRODUCT_TARGETS if name in totals}
    for name, count in totals.items():
        if name not in ordered:
            ordered[name] = count
    return Measurement(
        targets=ordered,
        skipped_targets=tuple(skipped),
        report_targets=tuple(report_names),
        excluded_generated_files=stats['generated'],
        excluded_preview_files=stats['preview_files'],
        excluded_preview_functions=stats['preview_functions'],
    )


def load_floor(path: Path) -> Floor:
    try:
        data = json.loads(path.read_text(encoding='utf-8'))
    except OSError as error:
        raise CoverageError(f'coverage floor not found: {path}') from error
    except json.JSONDecodeError as error:
        raise CoverageError(f'coverage floor is not JSON: {path}: {error}') from error
    if not isinstance(data, dict) or set(data) != {'enforce', 'overall', 'targets'}:
        raise CoverageError('coverage floor must contain only "enforce", "overall", and "targets"')
    enforce = data.get('enforce')
    if not isinstance(enforce, bool):
        raise CoverageError('coverage floor enforce must be true or false')
    overall = _require_percent(data.get('overall'), 'overall floor')
    raw_targets = data.get('targets')
    if not isinstance(raw_targets, dict) or not raw_targets:
        raise CoverageError('coverage floor targets must be a non-empty object')
    targets: dict[str, int] = {}
    for name, value in raw_targets.items():
        if not isinstance(name, str) or not name:
            raise CoverageError('coverage floor target names must be strings')
        targets[name] = _require_percent(value, f'{name} floor')
    return Floor(overall=overall, targets=targets, enforce=enforce)


def _row_failed(row: Row) -> bool:
    if row.covered is None or row.executable is None or row.executable <= 0:
        return True
    return row.covered * 100 < row.floor * row.executable


def _row_beats_floor(row: Row) -> bool:
    if row.covered is None or row.executable is None or row.executable <= 0:
        return False
    return row.covered * 100 >= (row.floor + 2) * row.executable


def render_row(row: Row) -> str:
    floor = f'floor {row.floor}%'
    if row.covered is None or row.executable is None:
        text = f'{row.name}: missing ({floor})'
    elif row.executable <= 0:
        text = f'{row.name}: no executable lines ({floor})'
    else:
        text = (
            f'{row.name}: {format_percent(row.covered, row.executable)} '
            f'({row.covered}/{row.executable} lines, {floor})'
        )
    if _row_failed(row):
        return text + ' below floor'
    return text


def measured_line(row: Row) -> str | None:
    if row.covered is None or row.executable is None or row.executable <= 0:
        return None
    whole = (row.covered * 100) // row.executable
    return (
        f'measured {row.name} covered={row.covered} executable={row.executable} '
        f'whole_percent={whole} suggested_floor={suggested_floor(row.covered, row.executable)}'
    )


def notice_for(row: Row) -> str | None:
    if not _row_beats_floor(row) or row.covered is None or row.executable is None:
        return None
    return (
        f'{row.name} coverage is {format_percent(row.covered, row.executable)}, '
        f'at least 2 points above the floor of {row.floor}%. '
        'Consider raising the floor in .github/coverage-floor.json.'
    )


def evaluate(measurement: Measurement, floor: Floor) -> Evaluation:
    rows: list[Row] = []
    failures: list[str] = []
    ordered = [name for name in PRODUCT_TARGETS if name in floor.targets or name in measurement.targets]
    for name in list(floor.targets) + list(measurement.targets):
        if name not in ordered:
            ordered.append(name)
    # Overall is the sum of the configured targets only when every one of
    # them has executable lines. A short target still counts toward that sum.
    comparable = True
    for name in ordered:
        count = measurement.targets.get(name)
        if name not in floor.targets:
            comparable = False
            rows.append(Row(
                name,
                None if count is None else count.covered,
                None if count is None else count.executable,
                0,
            ))
            failures.append(f'{name} is in the coverage report and has no floor')
            continue
        floor_value = floor.targets[name]
        if count is None:
            comparable = False
            row = Row(name, None, None, floor_value)
            rows.append(row)
            listed = ', '.join(measurement.report_targets) or '(none)'
            failures.append(f'{render_row(row)}. Report targets: {listed}')
            continue
        row = Row(name, count.covered, count.executable, floor_value)
        rows.append(row)
        if count.executable <= 0:
            comparable = False
            failures.append(render_row(row))
        elif _row_failed(row):
            failures.append(render_row(row))
    if comparable:
        covered = sum(measurement.targets[name].covered for name in floor.targets)
        executable = sum(measurement.targets[name].executable for name in floor.targets)
        overall = Row('overall', covered, executable, floor.overall)
        rows.append(overall)
        if _row_failed(overall):
            failures.append(render_row(overall))
    else:
        rows.append(Row('overall', None, None, floor.overall))
    notices = tuple(notice for row in rows if (notice := notice_for(row)) is not None)
    return Evaluation(tuple(rows), tuple(failures), notices, measurement, floor.enforce)


def format_text(evaluation: Evaluation) -> str:
    lines = [render_row(row) for row in evaluation.rows]
    for row in evaluation.rows:
        measured = measured_line(row)
        if measured:
            lines.append(measured)
    measurement = evaluation.measurement
    if measurement.skipped_targets:
        lines.append('skipped targets: ' + ', '.join(measurement.skipped_targets))
    excluded = []
    if measurement.excluded_generated_files:
        excluded.append(f'{measurement.excluded_generated_files} generated file(s)')
    if measurement.excluded_preview_files:
        excluded.append(f'{measurement.excluded_preview_files} preview file(s)')
    if measurement.excluded_preview_functions:
        excluded.append(f'{measurement.excluded_preview_functions} preview function(s)')
    if excluded:
        lines.append('excluded: ' + ', '.join(excluded))
    return '\n'.join(lines)


def _result_label(row: Row, *, enforce: bool) -> str:
    if not _row_failed(row):
        return 'pass'
    if enforce:
        return 'below floor'
    return 'warning'


def format_markdown(evaluation: Evaluation) -> str:
    if not evaluation.failures:
        status = 'Coverage meets the floor.'
    elif evaluation.enforce:
        status = 'Coverage is below the floor.'
    else:
        status = 'Coverage is below the floor. Enforcement is off, so this job warns and does not fail.'
    body = [
        '### Coverage floor',
        '',
        status,
        '',
        'Line coverage for the Watt app and helper tools. Test bundles, generated files, and SwiftUI previews are excluded.',
        '',
        '| Target | Lines | Coverage | Floor | Result |',
        '| --- | ---: | ---: | ---: | --- |',
    ]
    for row in evaluation.rows:
        if row.covered is None or row.executable is None:
            lines = 'missing'
            percent = 'missing'
        elif row.executable <= 0:
            lines = '0'
            percent = 'n/a'
        else:
            lines = f'{row.covered}/{row.executable}'
            percent = format_percent(row.covered, row.executable)
        result = _result_label(row, enforce=evaluation.enforce)
        body.append(f'| {row.name} | {lines} | {percent} | {row.floor}% | {result} |')
    notes = format_text(evaluation).splitlines()
    extra = [line for line in notes if line.startswith('skipped targets:') or line.startswith('excluded:')]
    if extra or evaluation.notices:
        body.append('')
    body.extend(extra)
    for notice in evaluation.notices:
        body.append('')
        body.append(notice)
    return '\n'.join(body) + '\n'


def append_summary(path: Path, markdown: str) -> None:
    preexisting = path.exists() and path.stat().st_size > 0
    with path.open('a', encoding='utf-8') as handle:
        if preexisting:
            handle.write('\n')
        handle.write(markdown)
        if not markdown.endswith('\n'):
            handle.write('\n')


def load_report_file(path: Path) -> dict:
    try:
        text = path.read_text(encoding='utf-8')
    except OSError as error:
        raise CoverageError(f'coverage report not found: {path}') from error
    return _parse_report(text, str(path))


def export_xccov(xcresult: Path) -> dict:
    if not xcresult.exists():
        raise CoverageError(f'result bundle not found: {xcresult}')
    result = subprocess.run(
        ['xcrun', 'xccov', 'view', '--report', '--json', str(xcresult)],
        check=False,
        capture_output=True,
        text=True,
    )
    if result.returncode != 0:
        detail = (result.stderr or result.stdout).strip() or f'xccov exited {result.returncode}'
        raise CoverageError(detail)
    return _parse_report(result.stdout, str(xcresult))


def _parse_report(text: str, label: str) -> dict:
    try:
        data = json.loads(text.lstrip('\ufeff'))
    except json.JSONDecodeError as error:
        raise CoverageError(f'coverage report is not JSON: {label}: {error}') from error
    if not isinstance(data, dict):
        raise CoverageError(f'coverage report is not an object: {label}')
    return data


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    source = parser.add_mutually_exclusive_group(required=True)
    source.add_argument('--xcresult', type=Path, help='xcodebuild result bundle to read with xccov')
    source.add_argument('--report', type=Path, help='JSON from xcrun xccov view --report --json')
    parser.add_argument(
        '--floor',
        type=Path,
        default=Path('.github/coverage-floor.json'),
        help='checked-in whole-percent floors (default: .github/coverage-floor.json)',
    )
    parser.add_argument(
        '--summary',
        type=Path,
        help='append the markdown summary to this file (default: $GITHUB_STEP_SUMMARY when set)',
    )
    args = parser.parse_args(argv)
    try:
        report = export_xccov(args.xcresult) if args.xcresult else load_report_file(args.report)
        floor = load_floor(args.floor)
        evaluation = evaluate(measure(report), floor)
    except CoverageError as error:
        print('error: ' + str(error), file=sys.stderr)
        return 2
    print(format_text(evaluation))
    summary_path = args.summary
    if summary_path is None:
        environment_summary = os.environ.get('GITHUB_STEP_SUMMARY')
        if environment_summary:
            summary_path = Path(environment_summary)
    if summary_path is not None:
        append_summary(summary_path, format_markdown(evaluation))
    for notice in evaluation.notices:
        print('notice: ' + notice)
        print('::notice::' + notice)
    if evaluation.failures and not evaluation.enforce:
        print('warning: coverage is below the floor; enforcement is off')
        for row in evaluation.rows:
            if not _row_failed(row):
                continue
            message = render_row(row)
            print('warning: ' + message)
            print('::warning::' + message)
        return 0
    if evaluation.failures:
        print('error: coverage is below the floor', file=sys.stderr)
        for row in evaluation.rows:
            print('error: ' + render_row(row), file=sys.stderr)
        print('::error::coverage is below the floor. ' + ' '.join(evaluation.failures))
        return 1
    print('PASS: coverage meets the floor')
    return 0


if __name__ == '__main__':
    sys.exit(main())
