# J10.4 — Downloading (G068)

Implemented in the existing worktree on `bug/G068-j104-downloading`; no commit created. Cumulative edits were preserved.

## Source and native styling
Fresh MCP evidence is in `figma-context.json`, `figma-metadata.json`, `figma-screenshot.json`, and `figma-variables.json`. Exact source: file `9DKDgUfEqidZdZQEVlQgLS`, frame `34:5339`, window `34:5493`, content `34:5512`, determinate progress `34:5598`. `reference.png` is downloaded from the exact MCP URL recorded in `figma-screenshot.json` and both summary JSON files; `reference.sha256` verifies its bytes.

Uses native `ProgressView(value:)`, bordered Cancel, system window chrome, and the existing 64pt icon. Production forced light appearance/blue tint were removed; update typography uses semantic `WattTypography.bodyEmphasized` and `.footnote`. DEBUG fixture alone selects Aqua. Native OS metrics take precedence over the reference's fixed font/button/color values; no custom progress bar, wallpaper, traffic lights, or titlebar is drawn. Durable rationale and acceptance are in `DESIGN.md` and `SCREEN-BACKLOG.md`.

## Verified results
| Check | Result | Evidence |
| --- | --- | --- |
| Focused J101–J104, native styling, P04 | 69 tests; zero failures | `focused-tests.log`, `.exit` = 0 |
| Full Swift package | 607 tests; 5 skipped; 602 passed; zero failures | `full-tests.log`, `.exit` = 0 |
| Debug build/analyze/build-for-testing | All passed | `debug.log`, `.exit` = 0 |
| Release build/analyze | Both passed | `release.log`, `.exit` = 0 |
| Release build-for-testing | Blocked: compatible Watt module unavailable to WattTests; first diagnostic J83OpeningSettingsTests.swift:7:18 | `release-build-for-testing.log`, `.exit` = 65 |
| Static/whitespace/project/reference/Release fixture checks | Passed | `static-checks.log`, `.exit` = 0 |
| Native capture | PNG captured, exact PID cleaned up | `capture.log`, `.exit` = 0; `capture/window.json`; `capture/process-cleanup.log` |

Each `.exit` above uses the matching log basename. Exact commands and machine-readable outcomes are in `verification.json`. `verify.sh` reruns focused/full tests; `static-check.sh` checks native ownership, project syntax, checksum, whitespace, and Release fixture exclusion. The preserved `full-tests-before-registry-expectation-fix.log` records an intermediate stale F05 registry expectation; the final full-suite log supersedes it.

## Behavior and boundaries
Download admission persists receipt ownership before asynchronous service work. Progress validates byte ranges, fixed total, monotonicity, and generation; completion requires the exact receipt. Cancellation invalidates generation first, retains ownership on persistence/service failure, drains old work before discard, and permits retry only after exact cleanup acknowledgement. Failed acknowledgement persistence retries without cancelling an already-discarded receipt. Restart requires reconciliation rather than assuming a successful download. No production updater composition, install, or relaunch effect is fabricated.

## Capture and remaining gaps
`capture.sh` launches only DEBUG `J10.4/base`, records PID-owned windows using `capture-window.swift`, captures `capture/native-window.png`, and terminates/reaps the exact fixture PID (84205 in the saved capture). Screen Recording was preauthorized and capture succeeded; Accessibility was not trusted. AX comparison remains blocked by TCC. The screenshot was qualitatively reviewed, but **visual acceptance is not claimed**: `score` and `pixel_diff` are null in both summary JSON files. Native window bounds are 420×178 points versus the reference's 420×177; native OS chrome and semantic text/control metrics are intentional. No numerical comparison was performed.

Release build-for-testing retains the same compatible-module blocker documented for J10.3. Full-suite skipped checks are explicitly recorded in `full-tests.log`; they are not counted as passes. See `visual-review.json` for observations and limitations.
