# G026 / C04.12 — light menu bar, on battery

## Implementation
- `App/WattApp.swift`: isolated DEBUG `C04.12/base` selector, C04.2 fixed reading/clock and item geometry, fresh in-memory preferences, public Aqua appearance/light SwiftUI environment, unselected native status item.
- `Tests/Fixtures/StoryFixtures.swift`: registers C04.12 while preserving prior stories.
- `Tests/WattTests/F05FixtureTests.swift`: semantics, geometry, selector/capture isolation, independent stores/preferences and unselected native Aqua/no-tint tests. Removed obsolete assertions that C04.12 was unimplemented; generic fail-closed coverage remains.
- `DESIGN.md`: native contract and evidence limitations.
- Production `MenuBarStatusLabel` and semantic typography remain unchanged: battery.100percent, typographic `−18.4 W`, macOS body semibold (reference SF Pro Semibold 13/16).

## Reproduce
From the shared worktree, with `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer`:
```sh
xcodebuild -project Watt.xcodeproj -scheme Watt -configuration Debug -destination 'platform=macOS' -derivedDataPath .build/c0412-native build analyze
bash docs/evidence/C04.12/capture.sh
bash docs/evidence/C04.12/compare.sh
swift test --filter C0412StatusItemTests
swift test
xcodebuild -project Watt.xcodeproj -scheme Watt -configuration Debug -destination 'platform=macOS' -derivedDataPath .build/c0412-native test -only-testing:WattTests/C0412StatusItemTests -parallel-testing-enabled NO
xcodebuild -project Watt.xcodeproj -scheme Watt -configuration Release -destination 'platform=macOS' -derivedDataPath .build/c0412-release build analyze
```

## Reference / capture
Figma MCP context: `figma-context.json`; anchor metadata: `figma-anchor-metadata.json`.
Exact unmodified screenshot: `reference-24-1960.png`.
Frame **24:1960**, component **24:2076**, anchor **24:2078**. Geometry in
`reference-geometry.json`: frame 560×44, anchor (0,5,301,24), item (204,5,97,24).

`capture.json` records the actual NSStatusBarButton, Aqua, selected=false,
customBackdrop=false. Bottom-origin y=15 maps to reference y=5 (44−15−24).
`actual-status-item-1x.png` is a direct 560×44 bitmap, not resampled;
`actual-status-item.png` is a Retina diagnostic. Frame/item crops, diffs,
overlays and `images.sha256` preserve comparison evidence.

**No pixel-parity claim:** the public native material/subtree capture is not the
macOS desktop/menu-bar compositor. Comparisons retain pass=false/storyDone=false.
No wallpaper/system-item recreation, custom colors/chrome, bitmap UI, private
API, TCC changes or bypass. No commit/checkpoint; no full UI suite.

## Verification
See the adjacent focused/full package, focused hosted, Debug/Release build/analyze,
release-isolation and static-check logs. The first full package run exposed nine
obsolete C04.12-unimplemented assertions; these were removed before the passing rerun.

Final results:
- `package-focused.log`: 3 tests, zero failures.
- `package-full.log`: 250 tests, one skipped, zero failures.
- `debug-build-analyze.log`, `release-build-analyze.log`: BUILD and ANALYZE SUCCEEDED.
- `release-isolation.log`: C0412 fixture/capture symbols absent from Release.
- `static-checks.log`: whitespace, Bash syntax and ShellCheck pass.
- `capture-check.log`: exact frame/component/anchor IDs, Aqua, unselected,
  no custom backdrop, and direct 1x geometry pass. Run `python3 docs/evidence/C04.12/verify-capture.py`.
- `native-selector-smoke.log`: actual Debug executable rejects malformed,
  duplicate and unknown-variant selectors. Exact base selector is proven by capture.
- **Hosted-test gap:** `native-focused.log` records a focused Xcode run that
  built but did not begin tests within about two minutes; interrupted rather than
  waiting indefinitely. Package tests and native executable/capture checks passed;
  no hosted XCTest success is claimed and no full UI suite was run.

The capture's initial inherited C04.11 metadata was corrected in source;
Debug was rebuilt and capture/compare regenerated. Final `capture.json` reports
`24:1960` / `24:2076` / `24:2078`, with `customBackdrop=false`.
