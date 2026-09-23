# G024 / C04.10 — panel open (selected)

Fresh evidence, 2026-09-23: exact Figma node `24:1591` was re-inspected and
the final-source DEBUG app was rebuilt, focused-tested and captured again. See
[current Figma context](current-figma-context-2026-09-23.md),
[build/analyze log](debug-build-analyze-2026-09-23.log), [native focused test
log](native-focused-2026-09-23.log), [capture log](capture-run-2026-09-23.log)
and [comparison log](compare-run-2026-09-23.log). The fresh capture again
proved the native popover/highlight lifecycle and exact 96×24 geometry. Strict
comparisons remain diagnostics with `storyDone: false`; no compositor visual
pass is claimed.

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

The fresh focused native run executed 3 tests with zero failures; the fresh
Debug build and analysis both succeeded. The retained full-suite warning above
is unchanged and is not presented as a pass.

## Capture and geometry
Run `bash docs/evidence/C04.10/capture.sh` after Debug build in `.build/c0410-native`; then `bash docs/evidence/C04.10/compare.sh`.
`capture.json` verifies native button performClick opens a real popover, router and native highlight become selected, second click closes and clears both. All six lifecycle booleans are true.
The unit test uses an internal lifecycle synchronization seam rather than opening transient popovers under XCTest's headless/timing-sensitive host. Capture independently exercises real actions.

`reference-geometry.json`: Figma MCP frame 24:1591, component 24:1707, anchor 24:1710; 560×44, item x205/y5/96×24, SF Pro Semibold 13/16, battery charging and +42.1 W.
`reference-24-1591.png` is the unmodified Figma MCP export.
`actual-status-item-1x.png` and `closed-status-item-1x.png` are direct AppKit 1x drawing; screen-scale PNG is diagnostic, not resampled.

**Visual acceptance remains blocked:** relocated native button reports highlighted but does not reproduce compositor-owned selected-pill chrome in subtree drawing. No custom pill was added to fake it. Strict frame/item comparisons fail (all pixels changed; synthetic backdrop also differs). `frame-comparison.json` and `item-comparison.json` retain pass=false/storyDone=false. Full native menu-bar/compositor visual approval and accessibility review remain open. Semantic fixture and public lifecycle capture are implemented; no claim of Figma visual parity.

## Fresh live compositor evidence — 2026-09-24

The verified Release app at `/Users/benranford/Desktop/Watt.app` was opened with
a real Quartz left-click at screen point `(1220, 15)`. WindowServer reported the
Watt-owned native popover as window `22829`, layer `25`, bounds `346 × 291 pt`
at `(1075, 31)` and the native Watt? fallback window as window `22824`, layer
`0`. A full-screen `screencapture -x` was taken while the selected status item
and popover were visible, then a diagnostic crop was made from Retina pixels
`x=2150,y=0,width=692,height=700` around the native popover and selected item.

- `live-compositor-2026-09-24-fullscreen.png`: 3600 × 2338 PNG,
  SHA-256 `8c7e1396e9f8f4518180ab6af1f671416f308e318cb9e024e0b581eba03b1c41`.
- `live-compositor-2026-09-24-crop.png`: 692 × 700 PNG,
  SHA-256 `d62e7537167deea8c925c72fb7c866c7f69ca901e787cfe2270f718cbe475b18`.

The live crop shows the actual menu-bar compositor selection pill, native
popover material and anchor, with `Full`, `0.0 W`, `Charger input 6.8 W`,
`System draw 6.8 W`, and `Battery 0.0 W`. The separate AX probe read a native
`AXMenuBarItem` and a live value (`19.6 W` at its sample). This is stronger
physical/compositor evidence than the previous app-owned subtree capture, but
it does not by itself close the Figma visual threshold or replace the required
AX/VoiceOver interaction audit; no custom chrome or private API was introduced.

The focused regression run `live-compositor-2026-09-24-focused-tests.log` executed
`C0410StatusItemTests` and `F05FixtureTests`: 25 tests, zero failures.
