#!/usr/bin/env python3
"""Unit tests for the coverage floor comparison."""

from __future__ import annotations

import json
import os
import stat
import subprocess
import sys
import tempfile
import textwrap
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'scripts'))
import check_coverage_floor


def run(arguments: list[str], *, env: dict[str, str] | None = None) -> subprocess.CompletedProcess[str]:
    merged = os.environ.copy()
    merged.pop('GITHUB_STEP_SUMMARY', None)
    if env:
        merged.update(env)
    return subprocess.run(arguments, cwd=ROOT, env=merged, text=True, capture_output=True)


def file_entry(path: str, covered: int, executable: int, functions: list[dict] | None = None) -> dict:
    entry = {
        'path': path,
        'name': Path(path).name,
        'coveredLines': covered,
        'executableLines': executable,
    }
    if functions is not None:
        entry['functions'] = functions
    return entry


def target_entry(name: str, files: list[dict], *, product_path: str = '') -> dict:
    covered = sum(item['coveredLines'] for item in files)
    executable = sum(item['executableLines'] for item in files)
    entry = {
        'name': name,
        'coveredLines': covered,
        'executableLines': executable,
        'files': files,
    }
    if product_path:
        entry['buildProductPath'] = product_path
    return entry


def write_floor(path: Path, overall: int, *, enforce: bool = True, **targets: int) -> None:
    document = {'enforce': enforce, 'overall': overall, 'targets': targets}
    path.write_text(json.dumps(document, indent=2) + '\n', encoding='utf-8')


class FilterTests(unittest.TestCase):
    def test_counts_app_and_helpers_and_drops_tests_generated_code_and_previews(self) -> None:
        report = {
            'targets': [
                target_entry(
                    'Watt.app',
                    [
                        file_entry(
                            '/repo/App/WattApp.swift',
                            50,
                            80,
                            [
                                {'name': 'PowerReadingStore.preview.getter', 'coveredLines': 10, 'executableLines': 10},
                                {'name': 'ComponentPreviewView.body.getter', 'coveredLines': 8, 'executableLines': 12},
                                {
                                    'name': 'WattComponentGallery_Previews.previews.getter',
                                    'coveredLines': 0,
                                    'executableLines': 5,
                                },
                            ],
                        ),
                        file_entry(
                            '/repo/DerivedData/Build/Intermediates.noindex/DerivedSources/GeneratedAssetSymbols.swift',
                            40,
                            40,
                        ),
                        file_entry('/repo/DesignSystem/FeaturePreviews.swift', 0, 60),
                        file_entry('/repo/DesignSystem/Verification/WattComponentGallery.swift', 20, 30),
                    ],
                    product_path='/repo/DerivedData/Build/Products/Debug/Watt.app/Contents/MacOS/Watt',
                ),
                target_entry(
                    'WattTests.xctest',
                    [file_entry('/repo/Tests/WattTests/AppRouterTests.swift', 1000, 1000)],
                    product_path='/repo/DerivedData/Build/Products/Debug/WattTests.xctest/Contents/MacOS/WattTests',
                ),
                target_entry(
                    'WattUITests.xctest',
                    [file_entry('/repo/Tests/WattUITests/NativeHostTests.swift', 10, 10)],
                ),
                target_entry(
                    'WattHelper',
                    [file_entry('/repo/Helper/FixedPowerSampler.swift', 3, 10)],
                    product_path='/repo/DerivedData/Build/Products/Debug/WattHelper',
                ),
                target_entry('SomeDependency', [file_entry('/repo/.build/checkouts/Dep/Lib.swift', 1, 1)]),
            ]
        }
        measurement = check_coverage_floor.measure(report)
        self.assertEqual(set(measurement.targets), {'Watt', 'WattHelper'})
        # App.swift keeps both product `preview` members and drops the 5-line
        # SwiftUI preview getter (50/75). The gallery file stays (20/30).
        # Generated, preview-only, and test files do not.
        self.assertEqual(measurement.targets['Watt'], check_coverage_floor.LineCount(70, 105))
        self.assertEqual(measurement.targets['WattHelper'], check_coverage_floor.LineCount(3, 10))
        self.assertIn('WattTests', measurement.skipped_targets)
        self.assertIn('WattUITests', measurement.skipped_targets)
        self.assertIn('SomeDependency', measurement.skipped_targets)
        self.assertEqual(measurement.excluded_generated_files, 1)
        self.assertEqual(measurement.excluded_preview_files, 1)
        self.assertEqual(measurement.excluded_preview_functions, 1)

    def test_preview_macros_are_excluded_and_product_preview_members_stay(self) -> None:
        self.assertTrue(check_coverage_floor.is_preview_function('#Preview macro expansion'))
        self.assertTrue(check_coverage_floor.is_preview_function('GalleryPreviewProvider.previews.getter'))
        self.assertFalse(check_coverage_floor.is_preview_function('PowerReadingStore.preview.getter'))
        self.assertFalse(check_coverage_floor.is_preview_function('ComponentPreviewView.body.getter'))
        self.assertTrue(check_coverage_floor.is_generated('DerivedData/Build/GeneratedAssetSymbols.swift'))
        self.assertTrue(check_coverage_floor.is_generated('/repo/.build/debug/resource_bundle_accessor.swift'))
        self.assertFalse(check_coverage_floor.is_generated('/repo/App/WattApp.swift'))
        self.assertTrue(check_coverage_floor.is_preview_file('/repo/DesignSystem/FeaturePreviews.swift'))
        self.assertTrue(check_coverage_floor.is_preview_file('/repo/Preview Content/Preview.swift'))
        self.assertFalse(check_coverage_floor.is_preview_file('/repo/Features/Onboarding/Views/OnboardingFlowView.swift'))

    def test_duplicate_product_slices_do_not_double_count_lines(self) -> None:
        report = {
            'targets': [
                target_entry('Watt.app', [file_entry('/repo/App/WattApp.swift', 1, 4)]),
                target_entry('Watt.app', [file_entry('/repo/App/WattApp.swift', 3, 4)]),
            ]
        }
        measurement = check_coverage_floor.measure(report)
        self.assertEqual(measurement.targets['Watt'], check_coverage_floor.LineCount(3, 4))

    def test_suggested_floor_rounds_down_then_subtracts_one_point(self) -> None:
        self.assertEqual(check_coverage_floor.suggested_floor(459, 1000), 44)
        self.assertEqual(check_coverage_floor.suggested_floor(450, 1000), 44)
        self.assertEqual(check_coverage_floor.suggested_floor(4, 1000), 0)
        self.assertEqual(check_coverage_floor.suggested_floor(0, 1000), 0)
        self.assertEqual(check_coverage_floor.suggested_floor(1000, 1000), 99)


class ComparisonTests(unittest.TestCase):
    def test_failure_lists_actual_and_floor_for_every_target(self) -> None:
        measurement = check_coverage_floor.Measurement(
            targets={
                'Watt': check_coverage_floor.LineCount(10, 24),
                'WattHelper': check_coverage_floor.LineCount(5, 10),
                'WattMaintenance': check_coverage_floor.LineCount(0, 8),
                'WattHelperInstaller': check_coverage_floor.LineCount(9, 10),
            },
            skipped_targets=('WattTests',),
            report_targets=('Watt.app', 'WattHelper', 'WattMaintenance', 'WattHelperInstaller', 'WattTests.xctest'),
            excluded_generated_files=0,
            excluded_preview_files=0,
            excluded_preview_functions=0,
        )
        floor = check_coverage_floor.Floor(
            overall=90,
            targets={'Watt': 44, 'WattHelper': 11, 'WattMaintenance': 0, 'WattHelperInstaller': 95},
        )
        evaluation = check_coverage_floor.evaluate(measurement, floor)
        rendered = '\n'.join(check_coverage_floor.render_row(row) for row in evaluation.rows)
        self.assertIn('Watt: 41.7% (10/24 lines, floor 44%) below floor', rendered)
        self.assertIn('WattHelper: 50.0% (5/10 lines, floor 11%)', rendered)
        self.assertIn('WattMaintenance: 0.0% (0/8 lines, floor 0%)', rendered)
        self.assertNotIn('WattMaintenance: 0.0% (0/8 lines, floor 0%) below floor', rendered)
        self.assertIn('WattHelperInstaller: 90.0% (9/10 lines, floor 95%) below floor', rendered)
        self.assertTrue(any(item.startswith('Watt:') and 'below floor' in item for item in evaluation.failures))
        self.assertTrue(any(item.startswith('WattHelperInstaller:') for item in evaluation.failures))
        self.assertTrue(any('overall:' in item and 'below floor' in item for item in evaluation.failures))
        notices = ' '.join(evaluation.notices)
        self.assertIn('WattHelper', notices)
        self.assertIn('at least 2 points above the floor of 11%', notices)
        self.assertIn('.github/coverage-floor.json', notices)
        self.assertNotIn('Watt coverage is', notices)

    def test_two_point_notice_uses_the_same_boundary_as_the_floor(self) -> None:
        def evaluate(covered: int, floor_value: int) -> check_coverage_floor.Evaluation:
            measurement = check_coverage_floor.Measurement(
                targets={name: check_coverage_floor.LineCount(covered, 100) for name in check_coverage_floor.PRODUCT_TARGETS},
                skipped_targets=(),
                report_targets=check_coverage_floor.PRODUCT_TARGETS,
                excluded_generated_files=0,
                excluded_preview_files=0,
                excluded_preview_functions=0,
            )
            floor = check_coverage_floor.Floor(
                overall=floor_value,
                targets={name: floor_value for name in check_coverage_floor.PRODUCT_TARGETS},
            )
            return check_coverage_floor.evaluate(measurement, floor)

        self.assertEqual(evaluate(44, 44).failures, ())
        self.assertEqual(evaluate(44, 44).notices, ())
        self.assertTrue(evaluate(43, 44).failures)
        self.assertEqual(evaluate(45, 44).notices, ())
        self.assertEqual(len(evaluate(46, 44).notices), 5)
        self.assertEqual(evaluate(1, 0).failures, ())
        self.assertEqual(evaluate(1, 0).notices, ())
        self.assertEqual(len(evaluate(2, 0).notices), 5)

    def test_missing_target_names_the_report(self) -> None:
        measurement = check_coverage_floor.Measurement(
            targets={'Watt': check_coverage_floor.LineCount(10, 10)},
            skipped_targets=('WattTests',),
            report_targets=('Watt.app', 'WattTests.xctest'),
            excluded_generated_files=0,
            excluded_preview_files=0,
            excluded_preview_functions=0,
        )
        floor = check_coverage_floor.Floor(overall=0, targets={'Watt': 0, 'WattHelper': 0})
        evaluation = check_coverage_floor.evaluate(measurement, floor)
        self.assertTrue(any('WattHelper' in item and 'Watt.app' in item for item in evaluation.failures))

    def test_exact_fraction_below_an_integer_floor_fails(self) -> None:
        # 1/3 is 33.333%, which is under a floor of 34 and meets a floor of 33.
        measurement = check_coverage_floor.Measurement(
            targets={name: check_coverage_floor.LineCount(1, 3) for name in check_coverage_floor.PRODUCT_TARGETS},
            skipped_targets=(),
            report_targets=check_coverage_floor.PRODUCT_TARGETS,
            excluded_generated_files=0,
            excluded_preview_files=0,
            excluded_preview_functions=0,
        )
        low = check_coverage_floor.Floor(overall=33, targets={name: 33 for name in check_coverage_floor.PRODUCT_TARGETS})
        high = check_coverage_floor.Floor(overall=34, targets={name: 34 for name in check_coverage_floor.PRODUCT_TARGETS})
        self.assertEqual(check_coverage_floor.evaluate(measurement, low).failures, ())
        self.assertTrue(check_coverage_floor.evaluate(measurement, high).failures)


class FloorFileTests(unittest.TestCase):
    def test_repository_floor_is_ninety_and_not_enforced(self) -> None:
        floor = check_coverage_floor.load_floor(ROOT / '.github/coverage-floor.json')
        self.assertFalse(floor.enforce)
        self.assertEqual(floor.overall, 90)
        self.assertEqual(
            floor.targets,
            {name: 90 for name in check_coverage_floor.PRODUCT_TARGETS},
        )

    def test_floor_file_rejects_partial_and_non_integer_values(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            path = Path(temporary) / 'floor.json'
            path.write_text('{"overall": 10}\n', encoding='utf-8')
            with self.assertRaises(check_coverage_floor.CoverageError):
                check_coverage_floor.load_floor(path)
            path.write_text('{"overall": 10.5, "targets": {"Watt": 10}}\n', encoding='utf-8')
            with self.assertRaises(check_coverage_floor.CoverageError):
                check_coverage_floor.load_floor(path)
            path.write_text('{"overall": true, "targets": {"Watt": 10}}\n', encoding='utf-8')
            with self.assertRaises(check_coverage_floor.CoverageError):
                check_coverage_floor.load_floor(path)
            path.write_text('{"overall": 1, "targets": {"Watt": 101}}\n', encoding='utf-8')
            with self.assertRaises(check_coverage_floor.CoverageError):
                check_coverage_floor.load_floor(path)
            path.write_text(
                '{"enforce": "false", "overall": 90, "targets": {"Watt": 90}}\n',
                encoding='utf-8',
            )
            with self.assertRaises(check_coverage_floor.CoverageError):
                check_coverage_floor.load_floor(path)


class CommandTests(unittest.TestCase):
    def report(self, covered: int, executable: int) -> dict:
        return {
            'targets': [
                target_entry(
                    name if name != 'Watt' else 'Watt.app',
                    [file_entry(f'/repo/{name}.swift', covered, executable)],
                )
                for name in check_coverage_floor.PRODUCT_TARGETS
            ]
        }

    def test_cli_fails_with_actual_and_floor_and_writes_the_summary(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            report = root / 'coverage.json'
            floor = root / 'floor.json'
            summary = root / 'summary.md'
            summary.write_text('existing\n', encoding='utf-8')
            report.write_text(json.dumps(self.report(10, 100)), encoding='utf-8')
            write_floor(floor, 50, **{name: 40 for name in check_coverage_floor.PRODUCT_TARGETS})
            floor_bytes = floor.read_bytes()
            result = run([
                sys.executable,
                'scripts/check_coverage_floor.py',
                '--report',
                str(report),
                '--floor',
                str(floor),
                '--summary',
                str(summary),
            ])
            self.assertEqual(result.returncode, 1, result.stdout + result.stderr)
            self.assertIn('error: coverage is below the floor', result.stderr)
            for name in (*check_coverage_floor.PRODUCT_TARGETS, 'overall'):
                self.assertIn(name, result.stderr)
                self.assertIn('floor', result.stderr)
            self.assertIn('10.0%', result.stderr)
            self.assertIn('40%', result.stderr)
            self.assertIn('50%', result.stderr)
            self.assertIn('::error::', result.stdout)
            self.assertTrue(summary.read_text(encoding='utf-8').startswith('existing\n'))
            self.assertIn('### Coverage floor', summary.read_text(encoding='utf-8'))
            self.assertIn('| Watt |', summary.read_text(encoding='utf-8'))
            self.assertEqual(floor.read_bytes(), floor_bytes)

    def test_cli_warns_without_failing_when_enforcement_is_off(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            report = root / 'coverage.json'
            floor = root / 'floor.json'
            summary = root / 'summary.md'
            report.write_text(json.dumps(self.report(66, 100)), encoding='utf-8')
            write_floor(
                floor,
                90,
                enforce=False,
                **{name: 90 for name in check_coverage_floor.PRODUCT_TARGETS},
            )
            floor_bytes = floor.read_bytes()
            result = run([
                sys.executable,
                'scripts/check_coverage_floor.py',
                '--report',
                str(report),
                '--floor',
                str(floor),
                '--summary',
                str(summary),
            ])
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertIn('warning: coverage is below the floor; enforcement is off', result.stdout)
            self.assertIn('::warning::Watt: 66.0% (66/100 lines, floor 90%) below floor', result.stdout)
            self.assertIn('::warning::overall:', result.stdout)
            self.assertNotIn('::error::', result.stdout)
            self.assertNotIn('error:', result.stderr)
            text = summary.read_text(encoding='utf-8')
            self.assertIn('Enforcement is off', text)
            self.assertIn('| Watt | 66/100 | 66.0% | 90% | warning |', text)
            self.assertEqual(floor.read_bytes(), floor_bytes)

    def test_cli_passes_and_notices_without_editing_the_floor(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            report = root / 'coverage.json'
            floor = root / 'floor.json'
            report.write_text(json.dumps(self.report(50, 100)), encoding='utf-8')
            write_floor(floor, 10, **{name: 10 for name in check_coverage_floor.PRODUCT_TARGETS})
            floor_bytes = floor.read_bytes()
            result = run([
                sys.executable,
                'scripts/check_coverage_floor.py',
                '--report',
                str(report),
                '--floor',
                str(floor),
            ])
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertIn('PASS: coverage meets the floor', result.stdout)
            self.assertIn('notice: Watt coverage is 50.0%', result.stdout)
            self.assertIn('::notice::', result.stdout)
            self.assertIn('measured Watt covered=50 executable=100 whole_percent=50 suggested_floor=49', result.stdout)
            self.assertEqual(floor.read_bytes(), floor_bytes)
            self.assertNotIn('error:', result.stderr)

    def test_summary_environment_is_appended(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            report = root / 'coverage.json'
            floor = root / 'floor.json'
            summary = root / 'github-step-summary.md'
            report.write_text(json.dumps(self.report(40, 100)), encoding='utf-8')
            write_floor(floor, 39, **{name: 39 for name in check_coverage_floor.PRODUCT_TARGETS})
            result = run(
                [
                    sys.executable,
                    'scripts/check_coverage_floor.py',
                    '--report',
                    str(report),
                    '--floor',
                    str(floor),
                ],
                env={'GITHUB_STEP_SUMMARY': str(summary)},
            )
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertIn('| overall |', summary.read_text(encoding='utf-8'))
            self.assertNotIn('notice:', result.stdout)

    def test_xcresult_invokes_xccov_report_json(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            bin_dir = root / 'bin'
            bin_dir.mkdir()
            xcresult = root / 'WattTests.xcresult'
            xcresult.mkdir()
            report = root / 'report.json'
            floor = root / 'floor.json'
            args_file = root / 'args.txt'
            report.write_text(json.dumps(self.report(80, 100)), encoding='utf-8')
            write_floor(floor, 70, **{name: 70 for name in check_coverage_floor.PRODUCT_TARGETS})
            stub = bin_dir / 'xcrun'
            stub.write_text(
                textwrap.dedent(
                    """\
                    #!/bin/sh
                    printf '%s\\n' "$@" > "$STUB_ARGS"
                    cat "$STUB_REPORT"
                    """
                ),
                encoding='utf-8',
            )
            stub.chmod(stub.stat().st_mode | stat.S_IEXEC)
            result = run(
                [
                    sys.executable,
                    'scripts/check_coverage_floor.py',
                    '--xcresult',
                    str(xcresult),
                    '--floor',
                    str(floor),
                ],
                env={
                    'PATH': str(bin_dir) + os.pathsep + os.environ.get('PATH', ''),
                    'STUB_ARGS': str(args_file),
                    'STUB_REPORT': str(report),
                },
            )
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual(
                args_file.read_text(encoding='utf-8').splitlines(),
                ['xccov', 'view', '--report', '--json', str(xcresult)],
            )

    def test_missing_inputs_fail_before_a_comparison(self) -> None:
        missing = run([sys.executable, 'scripts/check_coverage_floor.py'])
        self.assertEqual(missing.returncode, 2)
        both = run([
            sys.executable,
            'scripts/check_coverage_floor.py',
            '--report',
            'coverage.json',
            '--xcresult',
            'WattTests.xcresult',
        ])
        self.assertEqual(both.returncode, 2)
        absent = run([
            sys.executable,
            'scripts/check_coverage_floor.py',
            '--xcresult',
            '/tmp/watt-missing-coverage.xcresult',
            '--floor',
            str(ROOT / '.github/coverage-floor.json'),
        ])
        self.assertEqual(absent.returncode, 2, absent.stdout)
        self.assertIn('result bundle not found', absent.stderr)
        self.assertNotIn('below the floor', absent.stderr)


if __name__ == '__main__':
    unittest.main()
