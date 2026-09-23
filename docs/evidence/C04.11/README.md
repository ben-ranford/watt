# G025 / C04.11 — light menu bar, charging

Fresh evidence, 2026-09-23: exact Figma node `24:1711` was re-inspected and
the final-source DEBUG app was rebuilt, focused-tested and captured again. See
[current Figma context](current-figma-context-2026-09-23.md),
[build/analyze log](debug-build-analyze-2026-09-23.log), [native focused test
log](native-focused-2026-09-23.log), [capture log](capture-run-2026-09-23.log)
and [comparison log](compare-run-2026-09-23.log). The fresh capture records a
real Aqua `NSStatusBarButton`, selected=false, at the expected 96×24 geometry.
Strict comparisons remain diagnostics with `storyDone: false`; no desktop
compositor visual pass is claimed.

## Changes
- `App/WattApp.swift`: DEBUG-only exact C04.11/base selector; fixed C04.1 charging sample, fresh in-memory preferences, unchanged production MenuBarStatusLabel. Public Aqua appearance and SwiftUI light environment. Unselected real NSStatusBarButton; no panel.
- Capture uses a native NSVisualEffectView menu material, not custom foreground/background paint. Existing dark captures and all other stories retain their behavior.
- `Tests/Fixtures/StoryFixtures.swift`: registration; C04.12 remains unavailable.
- `Tests/WattTests/F05FixtureTests.swift`: charging/glyph/geometry, selector/capture isolation, independent stores/preferences, native Aqua/unselected/no-tint tests.
- `DESIGN.md`: native contract and evidence limitations.

## Reproduce
Use `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer`.
Build Debug to `.build/c0411-native`, then run:
```sh
bash docs/evidence/C04.11/capture.sh
bash docs/evidence/C04.11/compare.sh
swift test --filter C0411StatusItemTests
swift test
```

## Reference and capture
Figma MCP design context confirms frame **24:1711**, component **24:1957**, anchor **24:1959**. Unmodified export: `reference-24-1711.png`; geometry: `reference-geometry.json`. Frame 560×44, anchor (0,5,301,24), component (205,5,96,24), inner label (9,4,78,16), SF Pro Semibold 13/16, battery charging +42.1 W. Reuses C04.1 typography without custom painting or bitmap UI.

`capture.json` records actual NSStatusBarButton, Aqua appearance, selected=false, customBackdrop=false, direct 560×44 1x bitmap (not resampled). AppKit bottom-origin button y=15 corresponds to Figma top-origin y=5 (44−15−24). Retina cache is diagnostic only. PNG hashes, frame/item crops, diffs and overlays are retained.

**No visual-parity claim:** native material/subtree capture is not the macOS desktop/menu-bar compositor. Pixel comparisons retain pass=false/storyDone=false. The Figma wallpaper/system items are not recreated. No custom pill, color, bitmap UI, private API, TCC modification or bypass.

## Validation
- `package-focused.log`: three focused tests pass. Initial hosted focused run passed; the later hosted rerun was stopped at the requested handoff (latest `native-focused.log` is partial).
- `package-full.log`: 247 tests, one skipped, zero failures.
- `debug-build-analyze.log`, `release-build-analyze.log`: build/analyze succeeded.
- `release-isolation.log`: fixture/capture symbols absent from Release.
- `static-checks.log`: whitespace, shell syntax and ShellCheck.
An initial test with Command Line Tools failed in unrelated gallery code;
rerunning with the Xcode toolchain passed. No full UI-automation wait is
claimed.

The fresh native focused rerun executed 3 tests with zero failures; the fresh
Debug build and analysis both succeeded. The retained full-suite results above
remain the only full-suite claim.
