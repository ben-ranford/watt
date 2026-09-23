# J11.2 native Settings capture — state and geometry fix — 2026-09-23

This is a second native compositor capture after fixing the DEBUG fixture
composition and the connected-helper privacy copy. It uses the production
SwiftUI `Settings` scene, native grouped `Form`, native Picker/Toggle/Button
controls, and the real PID-owned compositor window. No replacement window or
bitmap renderer was used.

- Fixture: `J11.2/base`
- Figma node: `36:5186` / Settings window `36:5188`
- AX menu action: `Settings…` returned success (`AXPress = 0`)
- Native window: `580 × 870`, matching the Figma window bounds
- Native content gate: exact visible/control strings and helper state verified;
  `Status: On`, `Helper: Remove…`, and the privacy copy are present
- `window.json`: `status = captured-awaiting-review`
- Capture: `native-settings-20698.png`, PID-owned via `screencapture -l`

The strict native capture gate now passes geometry and content. Visual Ralph
acceptance is intentionally still false: this artifact is diagnostic evidence,
not a claim of pixel parity, keyboard traversal, VoiceOver speech, or production
helper approval.

## Visual Ralph verdict

`visual-ralph-verdict.json` is deliberately `verdict: blocked` with no score.
The native window bounds and semantics are now verified, but the captured grouped
Form still has a materially taller vertical rhythm than the Figma content crop;
the lower General rows are not visible without scrolling. This is not repaired by
painting custom rows or forcing a tint, because those would violate the native
control boundary. No pixel score is fabricated.
