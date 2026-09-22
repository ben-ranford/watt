# F01 native window capture — 2026-09-20

`status-panel.png` is the real SwiftUI `StatusPanelView` rendered by the Debug
Watt app in an app-owned borderless NSWindow, not a mock image or desktop crop.
`window.json` retains CGWindowList ownership/bounds plus decoded PNG metadata;
`status-panel.sha256` identifies the exact image. Visually inspected: Charging,
+42.1 W, battery detail, Power and Components rows, Settings… and Quit Watt?.

- Xcode 27.0 (27A266a), macOS 27.0 (26A428), light/aqua, en_US, charging fixture.
- Window 6745, app PID 24969, 320 × 503 points; PNG 640 × 1006 pixels, 2×.
- Nonblank: 286 distinct sampled RGB colors. This is a sanity check, not a fidelity metric.
- `./scripts/capture-native-panel.sh .build/native-capture/f01-20260920-final`
  → Debug build, preflight, launch, window-only capture, metadata, termination passed.
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test`
  → 4 tests, 0 failures.
- Full-Xcode `xcodebuild -project Watt.xcodeproj -scheme Watt -configuration Debug
  -destination 'platform=macOS' -derivedDataPath .build/xcode test
  -only-testing:WattTests -parallel-testing-enabled NO`
  → 4 hosted unit tests, 0 failures. No UI test execution.
- Release `analyze build` with derived data `.build/f01-release` → both succeeded;
  binary string inspection found no capture argument, title or delegate.
- `bash -n`, `shellcheck` for capture shell script; `git diff --check` → passed.
- No NativePanelCaptureTests or experimental probe remains in Tests/App/scripts.
  The two added tests check opt-in parsing and unshown native window construction,
  not AX traversal. All launched jobs finished; no capture app/test runner remains.

Raw logs/result bundle are local under `.build/native-capture/f01-20260920-r2/`,
`.build/native-capture/f01-20260920-final/`, `.build/f01-package-tests.log` and
`.build/f01-release.log`. The r2 helper recorded early window bounds; the retained
final metadata re-queries ownership and settled bounds immediately before capture.

## Acceptance boundary

This satisfies F01's native screenshot requirement alongside the existing native
menu-bar host and executing XCTest. F01 host evidence is sufficient; no screen
story or F05 visual-comparison/calibration gate is closed. The capture-only
Settings callback is inert; navigation is not tested by this image.

Cross-process XCTest UI automation remains TCC-blocked by “Timed out while enabling
automation mode”; it was not retried and no permissions requested or bypassed.
Accessibility evidence is limited to source-native SwiftUI Text/Button roles and
the panel's explicit accessibility containment/label. No runtime AX hierarchy,
VoiceOver behavior, keyboard order, menu-bar click interaction, or Figma fidelity
is established. Production signing, artwork, entitlements and minimum-OS runtime
validation remain separate owner gates. No Ultragoal state was changed.
