# J10.5 / G069 — Ready to install

Implemented in the existing worktree on `bug/G069-j105-ready-to-install`; no commit or new worktree. Cumulative edits retained.

Fresh MCP retrieval on 2026-09-23 is pinned in `fresh-figma/context-2026-09-23.md`, `fresh-figma/reference-2026-09-23.png` and `fresh-figma/live-ax-2026-09-23.log` (SHA-256 `a95f45ab4ed2a7b994aee2274921453abe61c69c23acfbabce68aea15e92e107`).

## Source and implementation
Fresh Figma MCP context, metadata, screenshot and variables are retained as `figma-*.json`; `reference.png` and `reference.sha256` record the 1000×720 reference. Bare footnote node lookup failed; the qualified instance lookup succeeded. Exact text is **“Watt? quits, updates and comes back to the menu bar. About 5 seconds.”** The layer name is stale.

- `App/RootSceneView.swift`: native ready UI, full ProgressView, semantic typography, native bordered actions; DEBUG fixture.
- `App/AppRouter.swift`: exact staged readiness and typed, one-shot version/generation/receipt/presentation-scoped intents. No install/relaunch/helper calls.
- `Services/PowerReadingStore.swift`: staged checkpoint before handoff; persistence failure retains receipt and allows retry. Restored state never grants consent.
- `App/WattApp.swift`, fixture registry and Xcode project: J10.5/base launch, real window, DEBUG isolation, test membership. Duplicate existing J103/J104 test project objects merged, retaining both.
- `Tests/WattTests/J105ReadyTests.swift`: seven readiness, native layout, scoped-action, stale/closed/foreign receipt, persistence/retry/restoration and fixture tests.
- `DESIGN.md`, `SCREEN-BACKLOG.md`: exact nodes, navigation, native ownership, acceptance and dependencies.

Later dismisses and retains staging; reopening requires fresh presentation/generation-bound intent. Install and Relaunch only hands off an intent. The five-second design copy does not mean a fabricated timer or performed installation.

## Verification
Run `bash docs/evidence/J10.5/verify.sh`. Commands use `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer`. Every command has a log and exit file; full details are in `verification.json`.

| Check | Result |
|---|---|
| Focused J101–J105, NativeStyling, P04 | 76 tests, zero failures |
| Full Swift suite | 614 tests, five skipped, zero failures |
| Debug build / analyze / build-for-testing | Passed |
| Release build / analyze | Passed |
| Release build-for-testing | Exit 65: WattTests cannot import compatible Watt module |
| Static native-style, checksum, Release nm/strings isolation, project lint, git diff --check | Passed |
| Native capture | Captured; exact PID 88744 terminated and reaped |

Five skips are four pre-existing J6.2–J6.5 AX-label checks and the opt-in P01 physical-host probe. Initial project-registration build failures are preserved separately and superseded by final logs.

## Visual evidence and honest gaps
`capture.sh` launches only J10.5/base, captures its PID-owned real window and terminates/reaps that exact PID. `capture/window.json`, `capture/native-window.png` and `capture/process-cleanup.log` contain evidence. Window measures 420×178 points versus Figma 420×177; native OS metrics are retained. No wallpaper, traffic lights or titlebar is custom drawn.

The captured image was qualitatively inspected: exact ready title/copy, full progress and both buttons are visible. Screen Recording is preauthorized; Accessibility is not. AX comparison/live interaction acceptance remains blocked. `visual-review.json` deliberately records **score: null**, **pixel_diff: null**, **visualPass: false**. No fabricated score or pixel comparison.

Release test-build import failure is not a Release app build failure; Release app build/analyze and fixture-symbol exclusion pass. Production updater composition, explicit adapter recovery, real install/relaunch and post-relaunch helper work belong to later integration/stories.

Fresh live AX evidence confirms the native ready-to-install semantics and exact copy; install/relaunch effects and visual comparison remain explicitly unclaimed.
