# F04 — composition verification

2026-09-20; existing `feat/swiftui-implementation` worktree. Verification cleanup only: the local DEBUG gallery `focusField` helper is explicitly `@MainActor`. Its recursive traversal and all routing are unchanged. No dependencies or Tests edits.

## Acceptance matrix

| Acceptance | Evidence / status | Remaining boundary |
| --- | --- | --- |
| Shared graph; scene isolation | Source: `App/WattApp.swift` shares router/power/preferences across distinct panel, onboarding, Settings and update roots; `RootSceneView.swift` is update-only. Routing tests pass. | Simultaneously visible windows not exercised live. |
| One MenuBarExtra, no duplicate status item | Source inspection: one `MenuBarExtra` with `.window`; adapter finds the existing `NSStatusBarButton`, never calls `NSStatusBar.statusItem`. | Runtime item count/anchor inspection not established by panel capture. |
| First launch | `testLaunchPresentsOnlyIncompleteSetupAndIsIdempotent` passes for complete/incomplete setup. | Live cold-launch presentation not audited. |
| Incomplete setup close/resume | Progress preservation and Finish Setup → persisted `.picker` (J1.2), without completing setup, pass in tests. | Actual close/reopen window lifecycle unverified. |
| Already-running reopen | `testReopenUsesCurrentCompletionStateWithoutRepeatingLaunch` passes. Delegate routes reopen using current preferences. | Live LaunchServices reopen unverified. |
| Open Watt? | Context-menu invocation tests request panel for both completion states. | Live status-button dispatch unverified. |
| Settings/update independence | Repeated explicit intents and settings/update requests with panel visible/hidden pass; scene roots do not globally switch. | Concurrent native window behavior unverified. |
| Secondary menu/display selection | Menu structure, action destinations, selected checkmarks and all display-mode persistence combinations pass. | Physical secondary/control-click and primary-click behavior unverified. |
| Quit | Native menu action/target present; source calls `NSApplication.shared.terminate`. | Tests intentionally do not terminate their host; live Quit not proven. |
| Coach-mark/status anchor | Adapter remains attached to existing status button, not a new item. | Coach-mark positioning/rendering and anchor behavior not validated. |
| No tabs or panel navigation stack | Scene-specific source roots; panel directly hosts `StatusPanelView`. | Not full journey/screen implementation. |
| DEBUG/Release boundary | Debug build and Release analysis pass; capture classes/flags absent from Release binary. | Opt-in capture is not ordinary launch/navigation proof. |
| Native rendering | App-owned panel capture passes (PNG retained at path below), not desktop/UI automation. | No Figma comparison, pixel calibration, keyboard or VoiceOver sign-off. |

## Commands and artifacts

Run from `/Users/benranford/Projects/watt-worktrees/swiftui-implementation` with:

```sh
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
swift test > docs/evidence/f04/package-tests.log 2>&1
xcodebuild -project Watt.xcodeproj -scheme Watt -configuration Debug -destination 'platform=macOS' -derivedDataPath /tmp/watt-f04-cleanup-debug build > docs/evidence/f04/debug-build.log 2>&1
xcodebuild -project Watt.xcodeproj -scheme Watt -configuration Release -destination 'platform=macOS' -derivedDataPath /tmp/watt-f04-cleanup-release analyze > docs/evidence/f04/release-analyze.log 2>&1
xcodebuild -project Watt.xcodeproj -scheme Watt -configuration Debug -destination 'platform=macOS' -derivedDataPath /tmp/watt-f04-cleanup-debug test -only-testing:WattTests -parallel-testing-enabled NO -resultBundlePath /tmp/watt-f04-cleanup-tests.xcresult > docs/evidence/f04/native-tests.log 2>&1
git diff --check > docs/evidence/f04/diff-check.log 2>&1
```

Package and hosted suites each pass **85 tests, zero failures**; these are two executions of the suite, not 170 distinct cases. Hosted selection excludes execution of `WattUITests`. Build/analyze pass. `diff-check.log` is empty on success. `checks.txt` records explicit result summaries and Release symbol/flag inspection. Fresh build logs have no actor-isolation warnings; unrelated toolchain warnings (AppIntents metadata extraction, XCTest minimum-OS linking, package unhandled build files) are not presented as repaired.

Additional inspection commands (the grep checks must produce no matches; summaries are retained in `checks.txt`):

```sh
{ nm /tmp/watt-f04-cleanup-release/Build/Products/Release/Watt.app/Contents/MacOS/Watt; strings /tmp/watt-f04-cleanup-release/Build/Products/Release/Watt.app/Contents/MacOS/Watt; } | grep -E 'NativeCaptureDelegate|GalleryCaptureWindow|WattComponentGallery|watt-capture-'
grep -E 'warning:.*(actor-isolated|ActorIsolated)' docs/evidence/f04/{debug-build,release-analyze}.log
rg -n 'MenuBarExtra|statusItem\(' App Features
```

Native app-owned capture command (unique output directory; fail on reuse):

```sh
out=/tmp/watt-f04-cleanup-capture
mkdir "$out"
xcrun swiftc scripts/capture-native-panel.swift -o "$out/capture-window"
"$out/capture-window" --preflight
/tmp/watt-f04-cleanup-debug/Build/Products/Debug/Watt.app/Contents/MacOS/Watt --watt-capture-status-panel > "$out/app.log" 2>&1 &
pid=$!
trap 'kill -TERM "$pid" 2>/dev/null || true; wait "$pid" 2>/dev/null || true' EXIT
"$out/capture-window" "$pid" "$out" > docs/evidence/f04/capture.log 2>&1
cp "$out/window.json" docs/evidence/f04/capture-window.json
shasum -a 256 "$out/status-panel.png" > docs/evidence/f04/capture.sha256
```

`capture-window.json` identifies the launched PID/window, appearance, dimensions and fixture; `capture.sha256` identifies `/tmp/watt-f04-cleanup-capture/status-panel.png`. Capture uses already-authorized screen-recording access, filters to the app's titled window, and terminates/waits for its own process. The PNG and `/tmp/watt-f04-cleanup-tests.xcresult` are local, ephemeral artifacts, not committed evidence; preserve them separately for handoff. Only logs/metadata are retained here.

Historical pre-cleanup 85-test evidence is preserved in `package-tests-before-cleanup.log` and `native-tests-before-cleanup.log`, copied from `/tmp/watt-f04-verify.JPxCXn/{package,native-tests}.log`. That run's native result bundle is `/tmp/watt-f04-verify.JPxCXn/WattTests.xcresult`; old actor warnings there are superseded by fresh logs, not current failures.

## Known validation gaps

Cross-process XCTest UI automation previously timed out enabling automation mode. TCC permissions/automation remain an environment gate; this cleanup neither retries that runner nor bypasses TCC or requests access. App-owned capture and programmatic menu-action tests do **not** prove live primary/secondary/control clicks, coach-mark/status anchoring, visible window concurrency, actual close/resume/reopen or Quit. macOS 13 runtime compatibility, keyboard/VoiceOver, production services and screen visual sign-off remain open. F04 has passing composition/unit/build/capture evidence, **not completed live-interaction acceptance**.
