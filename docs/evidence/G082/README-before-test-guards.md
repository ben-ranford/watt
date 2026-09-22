# G082 — Release test membership and module compatibility

## Result

The original module-resolution error was **local and fixed**, not proven external.
The full Release test bundle **still fails** due to existing tests referencing
DEBUG-only fixture APIs. No fixture guards, test bodies, product code, styling,
or test exclusions were changed. Work stopped at the requested scope boundary.

Worktree: `/Users/benranford/Projects/watt-worktrees/g082-release-test-membership`
Branch: `bug/G082-release-test-membership`
Baseline: `8af81c96d77526ac7c16f1ac5f58e425fa136e49`
Toolchain: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer`,
Xcode 27.0 (27A266a), Swift 6.4; see `environment.txt`.

## Changes and diagnosis

- `Watt.xcodeproj/project.pbxproj:7-10,235,237`: add file references and
  WattTests Sources membership for `StatusPanelVoiceOverSummaryTests.swift`
  and `UpdateOfferInstallTests.swift`, exactly once, not in app/UI-test Sources.
  Existing SwiftPM/XCTest conditional code remains untouched.
- `Watt.xcodeproj/project.pbxproj:230`: set `ENABLE_TESTABILITY = YES` on
  the Release Watt app target. The original diagnostic at
  `Tests/WattTests/J13OfferTests.swift:7` explicitly reported
  `module built without '-enable-testing'` for each matching architecture.
  The project enabled testability only in Debug. Both targets otherwise use
  compatible macOS 13.0, Swift 6.0, and arm64/x86_64 settings.
- Fresh post-fix Release compilation has no module-resolution diagnostic.
  It now reports missing `ScenarioRegistry` at `J13OfferTests.swift:17`,
  missing `J13FixtureLaunch` at line 73, and missing `sampleOnBattery` at
  `StatusPanelVoiceOverSummaryTests.swift:12`, among other fixture references.
  Their definitions are guarded at `Tests/Fixtures/StoryFixtures.swift:1`,
  `App/WattApp.swift:1883-1885`, and `Models/PowerReading.swift:160-219`.
  Similar errors occur across existing J-series tests; this is not isolated
  to the two newly included files.
- Release retains `-O`, whole-module compilation, no DEBUG/SWIFT_PACKAGE
  condition, and the original app fixture-source exclusions. Symbol checks
  on both Release architectures found none of the representative guarded
  fixture symbols (see `release-boundary-check.log`).
- Enabling testability exposes internal declarations for `@testable` imports
  in this verification app, including ordinary Release builds; it does not
  define DEBUG. No attempt was made to disguise a Debug build as Release.

## Exact results

| Validation | Exit | Evidence |
|---|---:|---|
| Original Release build-for-testing | 65 | `release-build-for-testing-before.log` |
| Post-fix Release build-for-testing | 65 | `release-build-for-testing-after.log` |
| Debug build-for-testing | 0 | `debug-build-for-testing.log` |
| Release app build + analyze | 0 | `release-app-build-analyze.log` (both success markers) |
| plutil | 0 | `plutil.log` |
| Project membership/boundary assertions | 0 | `project-check.log`, `check-project.py` |
| Release diagnostic/symbol boundary check | 0 | `release-boundary-check.log` |
| Full package tests | 0 | `package-tests.log`: 703 tests, 5 skipped, 0 failures |
| Focused package tests | 0 | `focused-package-tests.log`: 11 tests, 0 failures |
| Focused native tests | 75 | `focused-xcode-tests.log`: interrupted, no test result claimed |
| Release all-target settings | 0 | `release-settings-after.log` |
| git diff --check | 0 | `diff-check.log` |

Each recorded validation also has a sibling `.exit` file. The before-settings
snapshot is `release-settings-before.log`.

## Commands

All commands ran from the worktree with the above DEVELOPER_DIR.
Common Xcode arguments:

```
-project Watt.xcodeproj -scheme Watt -destination platform=macOS CODE_SIGNING_ALLOWED=NO
```

Actions/configurations/isolated derived data:

```
-configuration Release -derivedDataPath /tmp/watt-g082-release-before build-for-testing
-configuration Release -derivedDataPath /tmp/watt-g082-release-after build-for-testing
-configuration Debug -derivedDataPath /tmp/watt-g082-debug build-for-testing
-configuration Release -derivedDataPath /tmp/watt-g082-release-app build analyze
-configuration Debug -derivedDataPath /tmp/watt-g082-debug test-without-building -only-testing:WattTests/StatusPanelVoiceOverSummaryTests -only-testing:WattTests/UpdateOfferInstallTests -parallel-testing-enabled NO
```

Other validation:

```
plutil -lint Watt.xcodeproj/project.pbxproj
python3 docs/evidence/G082/check-project.py
swift test --scratch-path /tmp/watt-g082-package
swift test --scratch-path /tmp/watt-g082-package --filter 'StatusPanelVoiceOverSummaryTests|UpdateOfferInstallTests'
xcodebuild -project Watt.xcodeproj -alltargets -configuration Release -showBuildSettings
git diff --check
```

The native runner stalled before executing tests, with an invalidated XPC
control connection during session setup. SIGINT was sent only to this run's
verified xcodebuild PID 74683; it exited 75 with TEST EXECUTE INTERRUPTED after
128 seconds. Its session log and interruption note are preserved. A final
process check found no remaining G082 xcodebuild/swift-test process. This
runtime gap does not establish an external cause for the Release compiler
failure. Existing product warnings remain out of scope.

No commit, reset, or revert was performed. Remaining remediation would require
fixture-independent Release tests or another explicitly approved test-source
strategy; enabling DEBUG fixtures or suppressing tests was not attempted.
