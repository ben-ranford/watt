# G065 / J10.1 — Right-click → Check for Updates…

Fresh MCP retrieval on 2026-09-23 is pinned in `fresh-figma/context-2026-09-23.md`, `fresh-figma/reference-2026-09-23.png` and `fresh-figma/live-ax-2026-09-23.log` (SHA-256 `8357a137d6beec57fa659f0b008a311c585d7b8b09ae868eee39295266fa9723`).

Native menu admission/routing is implemented. **Story acceptance remains blocked:**
there is no configured production UpdateService (endpoint, trust and install driver).
The default native item is therefore disabled, not falsely usable. J10.2 presentation
is not implemented here. No update result, installation or helper update is fabricated.
No commit or additional worktree was created; prior cumulative edits were preserved.
Branch renamed to `bug/G065-j101-check-for-updates` per the standing branch convention.

## Exact reference

Fresh MCP design context and exact-node metadata are retained in
`figma-context.json` and `figma-metadata.json`. `reference.json` records file/node,
geometry, tokens and screenshot provenance. `reference.png` and
`supplied-reference.png` are identical 1000×720 PNGs, SHA256:
`8357a137d6beec57fa659f0b008a311c585d7b8b09ae868eee39295266fa9723`.
The old F00 registry hash remains historical; it is not asserted to match these bytes.

Figma node `34:3836`, menu `34:4148`: light desktop, Dock hidden, selected native
status item `+42.1 W`, Check for Updates… highlighted. Menu bounds 651,38,230,187.
The OS owns typography, row geometry, material, separators, selection and shortcuts.
No image from this evidence is shipped in the app. No wallpaper/status/menu drawing,
custom popup, manual colors or forced design dimensions were added.

## Changed files

- `App/AppRouter.swift`: accepts an optional existing UpdateService and UpdateStore;
  admits checks synchronously, consumes menu presentation tokens, coalesces in-flight
  requests, and applies only same-generation service results to UpdateStore.
- `Features/MenuBar/Views/StatusItemContextMenu.swift`: exact existing menu entry now
  uses native validation and guarded action routing, not `showUpdate()` (which is the
  unrelated J3.3 helper prompt). Existing order and Command-, / Command-Q are unchanged.
- `Tests/WattTests/J101CheckForUpdatesTests.swift`: native actions, exact order and
  shortcuts, unavailable/busy/retained transaction states, closed/replaced/consumed
  menus, persistence failure, stale async result and fail-closed fixture checks.
- `Tests/WattTests/J71ShowInMenuBarTests.swift`, `AppRouterTests.swift`,
  `F05FixtureTests.swift`, `J53FinishSetupTests.swift`: correct old assumptions that
  an unconfigured updater is enabled or opens/consumes the helper/setup flow.
- `Tests/Fixtures/FixtureLaunchSelection.swift`: J10.1 requires explicit `/base`.
- `Tests/Fixtures/StoryFixtures.swift`: records J10.1's unavailable production service
  policy. Render target remains unavailable rather than presenting a placeholder.
- `Watt.xcodeproj/project.pbxproj`: registers the focused native test source.
- `DESIGN.md`, `SCREEN-BACKLOG.md`: record implementation and acceptance blockers.
- `docs/evidence/J10.1/`: reference bytes/metadata, scripts, logs, verification and
  visual review artifacts. `changed-files.json` is the machine-readable slice list.

## Semantics and scope

Enabled only when a service is injected, no check is in flight, and UpdateStore is
idle, completed, or failed without a retained receipt. Offers, downloads, staged or
installing transactions and pending relaunch/recovery cannot be overwritten.
Admission sets `.checking` before scheduling work. Persistence failure performs no
service call. Closed, replaced and already-consumed menu actions cannot re-check.
Cancellation/renewal invalidates results; a still-running service blocks another check.
Only explicit service outcomes produce available, idle or failure states.

No new production endpoint, signing key, dependency, network source or fake service
was added. Existing UpdateAdapter remains available for future verified composition.
No new Debug fixture is needed for model/action tests. J10.1 render launch fails closed
in native Debug, SwiftPM and Release, so an enabled fixture cannot be mistaken for
production readiness. The helper-update prompt and later J10 screens are unchanged.

## Verification and native capture

See `verification.json` and exit/log pairs for exact results. The verification-only
pass ran these commands from the existing worktree root:

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun swift test --filter J101CheckForUpdatesTests
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun swift test
git diff --check
```

The test commands write `focused-tests.log` / `full-tests.log` and their `.exit`
files; the diff check writes `diff-check.log` / `diff-check.exit`.
Earlier native build/analyze and capture evidence is retained, not rerun in this pass.
Those earlier commands used `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer`:

```sh
xcodebuild -project Watt.xcodeproj -scheme Watt -configuration Debug -destination 'platform=macOS' -derivedDataPath build/J101-Debug build analyze build-for-testing
xcodebuild -project Watt.xcodeproj -scheme Watt -configuration Release -destination 'platform=macOS' -derivedDataPath build/J101-Release build analyze
bash docs/evidence/J10.1/capture.sh
bash docs/evidence/J10.1/static-check.sh
shasum -a 256 -c docs/evidence/J10.1/reference.sha256
```

Capture uses the **existing isolated J7.1 fixture as a diagnostic proxy** for the same
production native menu, not an exact J10.1 fixture. `capture-window.swift` probes
PID-owned compositor surfaces and AX without requesting permissions. Any captured
pixels are diagnostic only: the updater is unavailable and the reference's enabled
highlight cannot be asserted. `visual-review.json` records actual host blockers,
with score/pixel_diff null and no synthetic comparison. Cleanup is bounded to the
launched process. Fresh capture directory required to avoid stale evidence.

## Final recorded results (verification-only rerun)

- Focused run: **7 tests, 7 passed, 0 skipped, 0 failures**, exit 0.
- Full package run: **585 tests, 580 passed, 5 skipped, 0 failures**, exit 0.
  All 7 J10.1 tests and all 9 J5.3 tests passed. The previously corrected J5.3
  enabled-action loop is now reverified; no additional source or test edits were needed.
- Skips: four native SwiftUI AX-label checks (J6.2–J6.5) lack host accessibility
  evidence; the P01 physical-host public API smoke test is opt-in. These are not passes.
- `git diff --check`: passed, exit 0; no whitespace diagnostics.
- SwiftPM warned about 15089 unhandled files under existing `build/` artifacts.
  Package configuration was preserved; this warning did not fail either run.
- Earlier native Debug build/analyze/build-for-testing and Release build/analyze:
  passed, not rerun here. Native test execution and Release runtime fixture probe
  were not performed. Earlier static project/native ownership/hash evidence is retained.
- Earlier capture: existing isolated J7.1 proxy process 70618; AXTrusted=false,
  screen capture preauthorized=true, zero PID-owned compositor windows. No comparable
  PNG, live interaction, visual pass, score or pixel diff. Process terminated/reaped.
  `visual-review.json` is unchanged; score and pixel_diff remain null.
- Existing actor-isolation/AppIntents warnings from earlier native checks remain
  outside this story.
- Both test commands finished; no test process from this pass remains running.
  No product/source/test changes, commit, branch change, or worktree creation in this pass.
  Production updater, J10.2 presentation, and visual acceptance remain blocked;
  this green regression verification is not a completed Ultragoal story claim.

Fresh evidence confirms the native status item/menu semantics on the running Desktop app; the local build remains fail-closed because no production UpdateService is configured, so no enabled-hover visual pass is claimed.
