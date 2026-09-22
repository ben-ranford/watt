# G029 — J1.2 Choose a menu bar reading

## Source and implementation
- Exact supplied Figma MCP context: file `9DKDgUfEqidZdZQEVlQgLS`, frame
  `27:1354`, window `27:1508`, content `27:1520` (see `figma-context.txt`).
- Reference: `figma-frame.png`; window bounds x=260, y=197, width=480,
  height=346. No additional context retrieval or asset generation was needed.
- `Features/Onboarding/Views/OnboardingFlowView.swift` reuses `ReadingPicker`
  with native radio-group semantics. Fresh preferences select Delta; Charger,
  Draw, Components are unselected but enabled. User selection persists.
- Native light titleless scene; bordered Back returns to Welcome; native
  borderedProminent/default Continue advances to `.helperOffer` shell.
  It does not approve the helper or complete onboarding.
- This continuation tightened existing layout spacing (16→12 and top 32→24)
  using existing native components, not custom paint. Cumulative shared-worktree
  work was retained. No dependency or abstraction added.
- Existing debug-only `J12FixtureLaunch` uses fresh in-memory preferences,
  fixed preview telemetry and en_US/aqua. The fixture catalog maps J1.2/base
  to exact node `27:1354`.

## Fresh verification — 2026-09-22
- `focused-tests.log`: 6 J12ReadingTests passed, including exact options/copy,
  initial Delta, persistence, Back/Continue, no helper approval/completion,
  unavailable readings, native window and reference-size layout. Added tests
  cover all non-picker checkpoint guards and fitting size.
- `full-tests.log`: 265 tests, 1 skipped, 0 failures. Includes native styling
  source contracts. No UI automation or VoiceOver audit claimed.
- Debug and Release build AND analyze succeeded (separate logs).
- `static-checks.log`: diff whitespace check, native source contracts and
  absence of J1.2 capture argument from Release binary passed.
- `native-window.png` / `window.json`: fresh PID-scoped compositor capture;
  actual window 480×346 points (960×692 pixels at 2×).
- `actual-content.png` / `capture.json`: fresh NSView capture, not a substitute
  for compositor evidence. `images.sha256` binds the captured/reference images.

## Independent visual-ralph verdict — 2026-09-22
**93/100 — PASS**, meeting the threshold **>=90**. This records the independent
reviewer result supplied in the task, not a new review or implementation
self-approval. See `visual-review.json` for the durable verdict.

- Normalization: `native-window.png` is 960×692 pixels = 480×346 points at 2×,
  matching the exact Figma window bounds of 480×346 (x=260, y=197).
- The comparison accepts native macOS traffic-light treatment, surface
  appearance, font metrics and button metrics rather than requiring custom
  drawing to match the template.
- Minor downward drift in the radio rows remains acceptable at this threshold.
  PASS does not mean pixel parity or a calibrated pixel-diff score.

`capture.json` retains `visualPass: false`: it is the original NSView content
capture metadata, excludes native titlebar assessment, and does not establish
that this field represents the independent visual threshold. `window.json`
also remains unchanged as capture-time metadata. The separate verdict above
records the subsequent native-window visual review, not an accessibility gate.

### Accessibility and authorization limits
`ax-preflight.log` reports `AX trusted: false`; live AX interaction verification
remains blocked by missing authorization. **No AX, VoiceOver or TCC claim** is
made by this visual PASS. No permission prompt or bypass was attempted.
Model/binding tests do not substitute for AX/keyboard/VoiceOver end-to-end
verification; AX requires an authorized host.

This documentation-only update performed no new visual review, capture, build,
test run or accessibility audit. Existing reproduction commands and verification
logs are retained; the commands were not rerun for this update except
`git diff --check`. No Swift source/tests, workflow state or goal ledger changed.

## Reproduce
```sh
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
xcrun swift test --scratch-path /tmp/watt-g029-swift --filter J12ReadingTests
xcrun swift test --scratch-path /tmp/watt-g029-swift
xcodebuild -project Watt.xcodeproj -scheme Watt -configuration Debug -derivedDataPath /tmp/watt-g029-debug build analyze
xcodebuild -project Watt.xcodeproj -scheme Watt -configuration Release -derivedDataPath /tmp/watt-g029-release build analyze
bash docs/evidence/J1.2/capture.sh
git diff --check
```
