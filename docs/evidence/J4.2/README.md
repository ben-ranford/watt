# G045 / J4.2 — battery options unavailable

Implementation present; **visual acceptance remains blocked, not complete**. Live native AX interaction was additionally verified on the authorized local host; no compositor or visual-parity claim is made.

## Reference and implementation
- Exact Figma file `9DKDgUfEqidZdZQEVlQgLS`, node `30:2576`; `get_design_context` retrieved. Pinned original 1000×720 reference and SHA-256 are recorded in `reference.json`.
- Explicit no-battery capability variant uses the existing native `ReadingPicker` radio group. Draw selected: “What your Mac uses right now. 38.2 W”. Components helper-gated; Delta and Charger disabled with the exact no-battery explanation.
- Native titleless dark fixture, system semantic typography, bordered Back, bordered-prominent default Continue. Inter Title2 → system SF Pro substitution documented in DESIGN; no custom radios or forced Figma control geometry.
- Back persists welcome; Continue preserves existing helperOffer routing. It does not complete onboarding, enable a helper or fabricate battery telemetry. J4.3 panel navigation remains outside this slice despite historical backlog navigation shorthand.
- Debug `J4.2/base` uses fresh in-memory storage and explicit desktop fixture telemetry; normal launch/Release remains isolated. J4.1 Continue now reaches this variant using the same desktop fixture.

## Reproduce and verify
From repository root:

```sh
bash docs/evidence/J4.2/verify.sh
bash docs/evidence/J4.2/capture.sh
```

`verify.sh` records focused tests (J42/F05/router), full package tests, package build, Debug and Release host build+analyze, full host unit tests, and diff-check; each command has a `.log` and `.exit`. These are fresh reruns after updating registry expected lists, host launch-gate expectations, and positive/negative J4.2 selector tests. Initial stale failures were corrected, not accepted.

Focused coverage includes exact copy/order, disabled policy and binding guards, absent-option rejection, helper availability transitions, persisted Back/Continue with unrelated preferences preserved, fixture isolation, native window and styling contracts. UI test `F05StoryRenderTests.testJ42NoBatteryNativeInteraction` is opt-in with `WATT_J42_UI_TEST=1` on an authorized graphical host; **not executed here**. No standalone lint/typecheck configuration exists; compiler builds and Xcode analyze supply those checks.

## Capture and visual verdict
`capture-final/native-window-11619.png` is a real PID-scoped app-owned compositor capture. `capture-final/window.json` records 480×346 native points, screen-capture preauthorization, **AXTrusted=false**, and **liveInteractionVerified=false**. Screen capture required no permission request. Only the launched fixture process was terminated afterward.

`visual-review.json` records **blocked**, **score: null**, **pixel_diff: null**, **visualPass: false**, **storyDone: false**. Native typography/control metrics and disabled-label contrast differ; desktop pixels were not synthesized. Presentation capture and unit checks do not establish live AX interactions or comparable visual parity. No >=90 score or pixel-diff pass is claimed.

## Fresh live AX evidence

On 2026-09-23 UTC, the rebuilt `J4.2/base` fixture was launched as PID 56518 with the shell Accessibility trust probe returning `true`. The app-owned AX tree exposed four native `AXRadioButton` controls: Draw selected/enabled, Components disabled, Delta disabled and Charger disabled. An attempted `AXPress` on Components returned `press=0` and left Draw selected. Back returned to the desktop welcome copy; Continue returned to the no-battery picker; Continue then reached the existing helper-offer screen. The complete command transcript is pinned in `live-ax-2026-09-23.log`.

This strengthens the live interaction evidence but does not close the story: the required comparable visual/Figma threshold and compositor-backed status remain unresolved.

## Final fresh results
Final verification run completed 2026-09-23 00:28 AEST, after the selector test/import corrections:
- Focused J42/F05/router: **39 tests, 0 failures**.
- Full package: **380 tests, 1 skipped, 0 failures**.
- Full host unit suite: **368 tests, 1 skipped, 0 failures**, `TEST SUCCEEDED`.
- Package build, host Debug/Release build+analyze, and `git diff --check`: **exit 0**.
- Native capture: **exit 0**; AX/live/visual parity remains blocked as above.
- `verification.json` pins current implementation/test source hashes and final evidence exit codes. No success claim relies on earlier failing logs.
