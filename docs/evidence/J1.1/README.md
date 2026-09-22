# G028 — J1.1 Welcome

Figma: file `9DKDgUfEqidZdZQEVlQgLS`, frame `27:987`, window `27:1302`, content `27:1319`.
The parent frame was retrieved from Figma; direct content-node retrieval was unavailable.

Native light titleless window, system application-icon placeholder (no new bitmap),
SF Pro macOS title/body styles (22 bold / 13 regular; native leading), native default
Continue. Continue persists the `.picker` checkpoint and routes to the existing
onboarding shell; J1.2 is not implemented here. Escape dismisses; window close is native.

## Reproduction
Use Xcode's toolchain (the default CommandLineTools toolchain lacks SwiftUIMacros):
```sh
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
xcrun swift test --scratch-path /tmp/watt-g028-xcode-swift --filter J11WelcomeTests
xcrun swift test --scratch-path /tmp/watt-g028-xcode-swift
xcodebuild -project Watt.xcodeproj -scheme Watt -configuration Debug -derivedDataPath /tmp/watt-g028-debug build analyze
xcodebuild -project Watt.xcodeproj -scheme Watt -configuration Release -derivedDataPath /tmp/watt-g028-release build analyze
/tmp/watt-g028-debug/Build/Products/Debug/Watt.app/Contents/MacOS/Watt --watt-fixture J1.1/base --watt-j11-capture-directory "$PWD/docs/evidence/J1.1"
```

## Evidence
- Focused: 3 tests passed.
- Full package suite: 259 tests, 1 skipped, no failures.
- Debug and Release: build and analyze succeeded.
- Static native-style contract and diff whitespace checks passed.
- `actual-content.png` and `capture.json`: deterministic fresh in-memory welcome,
  en_US, aqua; NSView capture has transparent background and excludes native chrome.
- `native-window.png` and `window.json`: PID-scoped native compositor capture,
  960×612 pixels at 2×; visually inspected native chrome, copy and default button.
- Native OS metrics/icon differ from the Figma template; no pixel-parity or
  VoiceOver audit claimed. No UI automation suite was run.
- No commits or checkpoints created.

## Independent visual-ralph verdict (2026-09-22)

**92/100 — PASS**, supplied by the independent reviewer result in the task.
The native-window normalized comparison accepts native macOS differences in
button metrics, window controls and background. Icon artwork and spacing remain
discrepant; this is not pixel parity or a calibrated pixel-diff score.
No new review, capture, tests, AX traversal or VoiceOver audit was performed for
this documentation-only update. Visual PASS is not accessibility sign-off.
