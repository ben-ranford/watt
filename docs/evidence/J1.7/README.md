# J1.7 evidence — blocked visual review

- Exact reference: `docs/evidence/J1.7/figma-reference.png`, Figma node `28:2621`.
- Implementation: native `NSPopover` anchored to the status-item button, with native chrome and arrow geometry.
- Exact copy: **Watt? lives here** / **Click for the detail. Right-click to change the number.** / **Got It**.
- Existing evidence: six focused tests passed (`focused-tests.log`); full package 289 tests, 1 skipped, 0 failures (`package-tests.log`); hosted 277 tests, 1 skipped, 0 failures (`native-tests.log`). Debug and Release build/analyze passed (`debug-build-analyze.log`, `release-build-analyze.log`). These checks were not rerun for this documentation-only task.
- Capture failed: exit 1 (`capture-run.exit`), `invalidData` (`fixture-launch.log`), no app-owned compositor window (`window-capture.log`). Screen capture preauthorized; AX trusted false (`window.json`).
- Visual Ralph fails closed: actual and score null, verdict blocked, category match unknown, secondary diff null, visualPass false, storyDone false. No pixel comparison or visual parity claim is possible. Retry app-owned capture before visual review; see `visual-review.json`.
