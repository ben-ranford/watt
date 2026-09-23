# J10.2 — Checking

Fresh MCP retrieval on 2026-09-23 is pinned in `fresh-figma/context-2026-09-23.md`, `fresh-figma/reference-2026-09-23.png` and `fresh-figma/live-ax-2026-09-23.log` (SHA-256 `d8150ccf9231904f3d479dba54502186ab551edcc0ffd4b1f7b8e44a7bb29b02`).

Exact Figma file 9DKDgUfEqidZdZQEVlQgLS / frame 34:4482; window 34:4636.
Fresh MCP context, metadata and screenshot responses are retained as JSON; the
retrieved and user-supplied PNGs have identical SHA256 hashes in reference.sha256.
The older text responses are inherited retrieval artifacts, not new verification.

## Implementation
Native SwiftUI Software Update Window, existing app icon, exact checking text,
linear indeterminate ProgressView and Cancel/Escape. Native layout/chrome only.
AppRouter uses injected UpdateService and UpdateStore generation/persistence gates;
production without trusted updater composition stays disabled. Cancellation
invalidates first, cancels the task, suppresses late results and permits persistence
retry. J3.3 helper presentation stays separate. Debug J10.2/base fixture suspends
without network, disk, installation or a fabricated update result.

## Verification
See verification.json and corresponding logs/exit files:
- Focused J101/J102: 13 tests, zero failures.
- Full package: 591 tests, 5 skipped, zero failures. Updated the stale F05
  implemented-story expectation before the full run; J5.3 corrections also pass.
- Debug build, analyze, build-for-testing pass.
- Release build/analyze pass. Release build-for-testing additionally attempted,
  blocked by existing Release test-target Watt import incompatibility (first
  diagnostic J83OpeningSettingsTests:7); no fixture isolation was relaxed.
- Diff whitespace, project plist, reference hashes and native ownership checks pass.
- Native test execution is not claimed. Five skips are four existing AX-dependent
  power-row checks and opt-in physical telemetry. Build warnings include existing
  onboarding actor isolation/AppIntents and SwiftPM unhandled build artifacts.

## Visual / accessibility boundary
capture.sh launches only the exact Debug J10.2/base fixture and cleans up its PID.
Screen Recording is preauthorized but AXIsProcessTrusted is false. Capture refuses
to bypass that gate or prompt for authorization. PID-owned Software Update window
was visible at 420×178; native host chrome differs by one point from Figma 420×177.
There is no comparable captured image, verified live Cancel action or pixel score.
visual-review.json retains null score/pixel_diff and false visualPass.
No wallpaper or fabricated screenshot was introduced.

Existing worktree/branch bug/G066-j102-checking was reused. No commit created.
Unrelated pre-existing work is preserved. See changed-files.json for bounded slice.

Fresh live AX evidence confirms native Software Update/ProgressView/Cancel semantics for `J10.2/base`; the visual gate remains explicitly open because no comparable implementation PNG was captured.
