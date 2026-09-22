# G082 — Release test membership and fixture boundary

## Result

All requested builds pass. Continued in
/Users/benranford/Projects/watt-worktrees/g082-release-test-membership,
branch bug/G082-release-test-membership, baseline
8af81c96d77526ac7c16f1ac5f58e425fa136e49.

Added only conditional-compilation lines across 47 test files.
DEBUG || SWIFT_PACKAGE guards cover 209 fixture-dependent test/helper methods
plus J64's fixture timestamp; adjacent guarded methods share a block.
Release-safe methods remain compiled, including the charging VoiceOver summary,
update flow tests, and source-contract checks. Test bodies and imports are unchanged.

The original diagnostic file set from release-build-for-testing-after.log
matches the 47 changed test files. Compilation also exposed indirect dependencies
on J25FixtureSession, C0410PanelSelection, and J64's static timestamp; these are
guarded too. guarded-test-methods.txt records the method inventory.

F05, AppRouter, J111/J112/J113 already guard their fixture dependencies and were
left unchanged. J52 and P01 use Release-safe sampleCharging; they were not
blanket-guarded. StatusPanelVoiceOverSummaryTests and UpdateOfferInstallTests
remain in WattTests Xcode Sources exactly once. Their Debug/package coverage
is preserved.

No production source or project settings were changed in this continuation.
Earlier cumulative project edits (test membership and Release testability)
remain intact. Release still has no DEBUG/SWIFT_PACKAGE flags, retains fixture
source exclusions, and contains no checked fixture-only symbols on either
architecture. No commit, reset, or revert was performed.

## Fresh verification

Each log has a sibling .exit containing the actual command exit.

| Check | Exit | Log |
|---|---:|---|
| Full Swift package tests: 703 tests, 5 skipped, 0 failures | 0 | package-tests-final.log |
| Debug build-for-testing | 0 | debug-build-for-testing-final.log |
| Release app build + analyze | 0 | release-app-build-analyze-guarded.log |
| Release build-for-testing | 0 | release-build-for-testing-final.log |
| Project membership and Release settings | 0 | project-check.log |
| Test-source boundary and unchanged test bodies | 0 | test-boundary-check.log |
| Release fixture symbol absence, both apps and architectures | 0 | release-symbols-final.log |
| Project plist lint | 0 | plutil.log |
| Diff whitespace check | 0 | diff-check.log |

## Reproduction

Toolchain: DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer;
see environment.txt. From the worktree:

    export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
    swift test --scratch-path /tmp/watt-g082-package
    xcodebuild -project Watt.xcodeproj -scheme Watt -destination platform=macOS CODE_SIGNING_ALLOWED=NO -configuration Debug -derivedDataPath /tmp/watt-g082-debug build-for-testing
    xcodebuild -project Watt.xcodeproj -scheme Watt -destination platform=macOS CODE_SIGNING_ALLOWED=NO -configuration Release -derivedDataPath /tmp/watt-g082-release-app build analyze
    xcodebuild -project Watt.xcodeproj -scheme Watt -destination platform=macOS CODE_SIGNING_ALLOWED=NO -configuration Release -derivedDataPath /tmp/watt-g082-release-after build-for-testing
    python3 docs/evidence/G082/check-project.py
    python3 docs/evidence/G082/check-test-boundary.py
    python3 docs/evidence/G082/check-release-symbols.py
    plutil -lint Watt.xcodeproj/project.pbxproj
    git diff --check

## History and limits

Original failures and intermediate guard attempts are preserved:
release-build-for-testing-before, release-build-for-testing-after,
release-build-for-testing-guarded, and release-build-for-testing-guarded-2
each exited 65. Final results above supersede them.
README-before-test-guards.md preserves the previous diagnosis.

Native Xcode tests were compiled, not executed in this continuation. The earlier
focused native runner interruption (exit 75) remains documented; no runtime
success is claimed from it. Swift package tests execute in Debug; Release
package tests were not requested or run (some app fixture definitions are
DEBUG-only). Existing build warnings remain out of scope.
