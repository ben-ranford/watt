# G032 — J1.5 Component readings

Corrected against the supplied exact export `figma-frame.png` (frame 28:1598).
Worktree: swiftui-implementation; branch: bug/G032-j15-component-readings.
Unrelated cumulative changes were preserved.

## Correction
- Native green SF Symbol `checkmark.circle.fill`, not WattAppIcon or custom artwork.
- Exact title: **Helper’s on**
- Exact message: **Here’s where the power is going right now.**
- Native grouped Form/Section/LabeledContent: CPU 9.8 W, GPU 4.1 W,
  Display 5.2 W, followed by native borderedProminent Continue.
- Existing telemetry availability handling and preview-to-allSet navigation unchanged.
- Regression tests cover exact curly-apostrophe copy, native symbol/green styling,
  absence of the app icon/custom drawing, readings and navigation.

## Fresh verification — 2026-09-22
With DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer:
- `xcrun swift test --scratch-path /tmp/watt-g032-swift --filter J15PreviewTests`:
  **5 passed, 0 failures** (focused-tests.log/.exit).
- Debug app rebuilt solely for the fresh capture:
  `xcodebuild -project Watt.xcodeproj -scheme Watt -configuration Debug -derivedDataPath /tmp/watt-g032-debug build`:
  **BUILD SUCCEEDED** (debug-build.log/.exit).
- `bash docs/evidence/J1.5/capture.sh`: **passed** (capture-run.log/.exit).
  Refreshed actual-content.png, native-window.png, capture.json and window.json.
  Native window capture visually inspected: green success symbol, exact title/message,
  three exact readings and Continue are visible and unclipped in the 480×364-point window.

## Limits
Per the latest request, only focused J15 tests and capture were rerun (plus the
Debug build needed for capture). Full tests, Release, analyze and static-check
logs in this directory predate this correction and are not fresh validation.
No pixel-identical parity, independent visual score, AX/VoiceOver audit or live
helper connectivity is claimed. Native system chrome/metrics remain host-owned.

## Independent visual-ralph result — 2026-09-22

- **95/100 — PASS**, meeting the **>=90/100** threshold. This records the
  independent visual-ralph result supplied in the task, not a new review or
  implementation self-approval. See [visual-review.json](visual-review.json).
- Exact window geometry: `native-window.png` is **960×728 pixels at 2×**,
  normalized exactly to **480×364 points**, matching reference window
  `28:1752` at (260,188) in `figma-frame.png` (frame `28:1598`).
  `actual-content.png` is 480×364 pixels; the native-window capture records chrome.
- Matched: exact copy (**Helper’s on**; **Here’s where the power is going right now.**;
  **Continue**), green `checkmark.circle.fill` symbol, three rows and values
  (**CPU 9.8 W**, **GPU 4.1 W**, **Display 5.2 W**), and overall layout.
- Accepted native differences: macOS traffic lights, window background and
  font metrics. Minor residual differences: narrower Continue button and
  subtitle/table offsets.
- This later visual-only verdict supersedes only the earlier statement that no
  independent visual score is claimed. It does not claim pixel-identical parity
  or a calibrated pixel-diff score, AX interaction, a VoiceOver audit, TCC
  verification/bypass, or live-helper connectivity. Visual PASS is not
  accessibility sign-off or approval of an overall AX/TCC gate.
- `capture.json` and `window.json` remain unchanged capture-time metadata;
  `visualPass: false` and outstanding-review wording predate this independent
  verdict and do not close the separate AX/VoiceOver/TCC/live-helper gaps.

This documentation-only update adds no code examples or reproduction commands.
Existing commands, builds, tests and captures were not rerun. Image dimensions
were checked and `git diff --check` was run. Source and tests were not edited.
