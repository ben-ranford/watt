# J11.3 — Destructive confirmation / keyboard (G080)

Exact Figma node: **36:5428**, file **9DKDgUfEqidZdZQEVlQgLS**.
Reference canvas: 1000×720; Settings 36:5432 at (230,277), 540×187;
31-point titlebar, 540×156 content; grouped Form 36:5442 at (20,20),
500×116. Alert 36:5433 at (370,223), 260×260. These are reference
measurements, not verified native implementation dimensions.

## Implementation

- Existing `Features/Settings/Views/SettingsRootView.swift` owns the native
  grouped Form, switch, bordered uninstall control and SwiftUI alert.
- Cancel retains its native cancel role and now explicitly uses
  `.keyboardShortcut(.cancelAction)`. Uninstall retains its destructive role
  and has **no default/Return shortcut**. SwiftUI/AppKit owns button layout and
  accessibility semantics; no custom alert, painted tokens, gradients or chrome.
- Confirmation-excerpt row and alert share the exact requested message:
  “Removes the helper, your settings and the login item, then moves Watt? to the
  Trash. Nothing is left behind.” The retrieved Figma row retains an older,
  shorter subtitle; the user's explicit full-copy requirement takes precedence.
  Other Settings excerpts retain their existing subtitle.
- `App/J113FixtureLaunch.swift` and `App/WattApp.swift` add the exact
  DEBUG-only `--watt-fixture J11.3/base` route using existing native Settings.
  Open at login is On, telemetry/storage are deterministic/in-memory and the
  removal adapter is injected to return cancelled without system removal.
- Fixture selection/registry, F05 expectation, Xcode app/test membership and
  the backlog are extended. DESIGN.md needed no change: native styling remains
  the existing contract. No dependencies or custom visual abstractions added.

## Retrieval and reference provenance

`figma-context-response.json`, `figma-metadata-response.json`,
`figma-screenshot-response.json`, and `figma-variable_defs-response.json`
are raw exact-node MCP responses. Text/XML extracts accompany them.
`reference.png` is the unmodified user-supplied asset;
`screenshot.png` is the fresh Figma screenshot retrieval, **not an implementation
screenshot**. Both are 1000×720; SHA-256 files and digest JSON describe the bytes.
The full reference geometry/source is in `reference.json`.

SF Pro, blue #0088ff, red #f52f32 and secondary #e6e6e6 are retrieval evidence,
not hard-coded native-control styling.

## Validation

Run from this worktree with
`DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer` (Xcode 27.0 / 27A266a).

`bash docs/evidence/J11.3/verify.sh` preserves per-command logs and exit codes:

| Check | Exit | Result |
|---|---:|---|
| Focused J113/J122/native-style package tests | 0 | 19 tests, zero failures |
| Full package tests | 0 | 684 tests, five skipped, zero failures |
| Debug app build + analyze + test-bundle build | 0 | All succeeded |
| Release app build + analyze | 0 | Both succeeded |
| Release test-bundle build | 65 | Xcode cannot resolve compatible Watt test module |
| Static checks | 0 | Evidence/PNG hashes, native tokens, project membership, shell syntax, Swift parse, diff whitespace and project plist |

The Release test-module failure is preserved, not “fixed” by changing product code.
The verification script exits 1 because this requested check is not green.
Initial failed registry/parser/static-script validation is preserved separately
under `initial-validation/`; the final logs contain the corrected passing checks.
Source-contract tests prove shortcut declarations and router cancellation/replay
safety; they do not prove actual VoiceOver or keystroke behavior.

## Native capture and visual review: BLOCKED

`bash docs/evidence/J11.3/capture.sh` launches only the exact native fixture,
uses a fresh evidence directory and terminates/reaps only its own fixture PID.
`capture-directory.txt` locates this run; `capture.log` and `capture.exit`
record **exit 1**.

Actual capture evidence reports:
- Screen Recording preauthorized: **true**.
- Accessibility trusted: **false**.
- No PID-owned on-screen compositor windows enumerated.
- No in-app `capture-attempt.json` observed during the capture interval.
- No accepted native implementation screenshot.

The capture flow fails closed before image comparison. `visual-review.json`
and `verification.json` therefore record **visualPass false**, **score null**,
**pixel_diff null**, and no implementation image. There is no fabricated visual
score, synthetic render or substitution of the Figma reference for native proof.

Still required in a permitted interactive host: native Settings/alert capture,
exact-geometry comparison, Return not invoking Uninstall, Escape cancelling,
keyboard focus traversal and VoiceOver title/message/button order. Neither
pixel parity nor runtime keyboard/accessibility acceptance is claimed.

## Additional native test-run attempt

Native Debug `test-without-building -only-testing:WattTests/J113DestructiveKeyboardTests`
produced no XCTest results within approximately 120 seconds. The exact owned
xcodebuild process was terminated (exit **143**); its identified test host was
also cleaned up. See `native-focused-tests.log`, `native-focused-tests.exit`,
`native-focused-tests-timeout.txt` and `native-focused-process-cleanup.log`.
Host logs include com.apple.linkd.autoShortcut connection errors, but their causal
role is unproven. This is not a native runtime pass; the 19 focused tests above
are the successfully executed package XCTest tests.

## Fresh Figma and native evidence — 2026-09-23
- Figma MCP re-queried for exact frame `36:5428` with design context, metadata, variables and screenshot; screenshot pinned at `fresh-figma/reference-2026-09-23.png` with SHA-256 `1466b6e3c198db2ab44c628c4a899604f8f600e9e489e74c52c82723ae3d383c`.
- Exact hierarchy, destructive copy, Return/Escape/VoiceOver annotations, tokens and native alert boundary are recorded in `fresh-figma/context-2026-09-23.md`.
- `J11.3/base` was launched, `Settings…` and `Uninstall…` were activated through AX, and the exact native `AXSheet` title/message/Cancel/Uninstall semantics were observed. The final destructive action was not pressed.
- A diagnostic PID-owned native capture is retained, but no visual-pass or pixel-parity claim is made because AppKit renders horizontal buttons/no custom icon versus the Figma stacked-button/icon reference.
- The fixture was reaped; the normal Desktop app remained running.
