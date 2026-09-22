# J10.7 / G071 — Couldn’t check for updates

Implemented in the existing worktree on `bug/G071-j107-couldnt-check`. No commit created; pre-existing work retained.

## Implementation and source
- `App/AppRouter.swift`: ephemeral generation/presentation identity, receipt-free failure guard, retry/OK routing, stale/closed/restored-result rejection. Checking is persisted before renewing generation so a failed retry write preserves the current error token.
- `App/RootSceneView.swift`: informational **NSAlert**, exact title/description, **Try Again** default and **OK** secondary; native presentation and DEBUG-only fixture. macOS owns icon, typography, material, buttons, chrome and layout.
- `App/WattApp.swift`, fixture registry/selector and Xcode project: `J10.7/base` launch and test membership. Release fixture symbols/selectors are absent.
- `J107CouldntCheckTests.swift`: eight tests. `F05FixtureTests.swift`: expected implemented-story list includes J10.7. DESIGN.md and SCREEN-BACKLOG.md record implementation and limitations.

Exact task-supplied Figma MCP evidence is preserved in `figma-source.json`: file **9DKDgUfEqidZdZQEVlQgLS**, frame **34:6003**, alert **34:6157**. The supplied asset was downloaded to `reference.png` with SHA-256 in `reference.sha256`. No fresh MCP context retrieval is claimed.

## Fresh verification

| Check | Result |
|---|---|
| Focused J10 + NativeStyling + P04 | 91 passed, zero failures |
| Full `swift test` | 629 tests, five skipped, zero failures (624 passed) |
| Debug build / analyze / build-for-testing | Passed |
| Release app build / analyze | Passed |
| Release build-for-testing attempt | Exit 65: existing incompatible Watt module for WattTests |
| Native style / Release isolation / project lint / checksum / diff checks | Passed |
| Native capture | Captured, inspected, fixture PID terminated and reaped |

Commands, logs and exits are in `verification.json`; `verify.sh` reproduces the sequence. Five skips are four existing J6.2–J6.5 AX-label checks and the opt-in P01 physical-host probe. The Release test-build failure is not a Release app build failure; no Release test execution is claimed.

## Native visual evidence and limitations
`capture/native-window.png` was inspected against the downloaded reference. The title and description match; the OS supplies the app icon, blue default Try Again and secondary OK. Native geometry is **260×218 points / 520×436 pixels**, with **OK left and Try Again right**, versus the reference’s 260×246-point vertical buttons. Material is darker against this host background. These OS-owned differences are not replaced with custom SwiftUI alert/chrome/glass or forced tint/appearance.

`capture/window.json` records the exact PID, timestamp, window and permissions; `capture/process-cleanup.log` confirms cleanup. Screen Recording is preauthorized; Accessibility is not. AX interaction acceptance is blocked by TCC. `visual-review.json` therefore records **score: null**, **pixel_diff: null**, **visualPass: false**—not a fabricated score or visual approval.

This story adds no automatic scheduler, production updater endpoint or installer effects. The requested description is exact; those dependencies are not claimed complete.
