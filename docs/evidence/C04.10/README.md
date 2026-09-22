# G024 / C04.10 — panel open (selected)

## Implementation
- `App/WattApp.swift`: exact DEBUG C04.10/base selector, existing fixed C04.1 charging sample and in-memory preferences, existing router opens native MenuBarExtra. Production chrome unchanged.
- Bounded capture only: real NSStatusItem and NSPopover, public native highlight follows actual popover visibility; reapply after button tracking clears its pressed highlight. No custom capsule/background, bitmap UI, private API or TCC changes. Existing synthetic dark capture host is diagnostic only.
- `Tests/Fixtures/StoryFixtures.swift`: registration; other stories retained.
- `Tests/WattTests/F05FixtureTests.swift`: three deterministic tests cover charging semantics/geometry, selector isolation and native lifecycle state synchronization. Future-story rejection advances to C04.11–12.
- `DESIGN.md`: contract and limitations.

## Verification
- `package-focused.log`: C0410, 3 tests passed.
- `native-focused.log`: hosted C0410, 3 tests passed.
- `package-full.log`, `native-full.log`: 244 tests, 1 skipped, 26 failed assertions, all in C03ContextMenuTests appearance/order checks. Shared context-menu implementation was changed outside this task; not reverted or repaired here. Full-suite pass is NOT claimed.
- `debug-build-analyze.log`, `release-build-analyze.log`: build and analyze succeeded.
- `static-checks.log`: diff whitespace, bash syntax and ShellCheck passed.
- `release-isolation.log`: C04.10 fixture/capture symbols absent.

## Capture and geometry
Run `bash docs/evidence/C04.10/capture.sh` after Debug build in `.build/c0410-native`; then `bash docs/evidence/C04.10/compare.sh`.
`capture.json` verifies native button performClick opens a real popover, router and native highlight become selected, second click closes and clears both. All six lifecycle booleans are true.
The unit test uses an internal lifecycle synchronization seam rather than opening transient popovers under XCTest's headless/timing-sensitive host. Capture independently exercises real actions.

`reference-geometry.json`: Figma MCP frame 24:1591, component 24:1707, anchor 24:1710; 560×44, item x205/y5/96×24, SF Pro Semibold 13/16, battery charging and +42.1 W.
`reference-24-1591.png` is the unmodified Figma MCP export.
`actual-status-item-1x.png` and `closed-status-item-1x.png` are direct AppKit 1x drawing; screen-scale PNG is diagnostic, not resampled.

**Visual acceptance remains blocked:** relocated native button reports highlighted but does not reproduce compositor-owned selected-pill chrome in subtree drawing. No custom pill was added to fake it. Strict frame/item comparisons fail (all pixels changed; synthetic backdrop also differs). `frame-comparison.json` and `item-comparison.json` retain pass=false/storyDone=false. Full native menu-bar/compositor visual approval and accessibility review remain open. Semantic fixture and public lifecycle capture are implemented; no claim of Figma visual parity.
