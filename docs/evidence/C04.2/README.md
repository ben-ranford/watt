# G016 / C04.2 — Delta · on battery

Implementation and bounded native-render evidence, 2026-09-22.
**Visual acceptance remains open. No checkpoint, commit or story-completion claim.**

## Exact reference

- Frame 24:639, status item 24:755, anchor 24:757.
- Unmodified F00 export: reference-24-639.png, 560×44 pixels at 1×;
  SHA-256 32f76aff05a69231bc7f852139ea7cb131afc67ab8a2bbb8da77aba939eec6c8.
- Retained reference-metadata.xml: item x204,y5,97×24 in frame coordinates;
  anchor x0,y5,301×24. Do not reuse C04.1's 96-point width/x205.
- Fresh component-context.json confirms dark native menu item text
  `􀛨 −18.4 W`. Fresh symbol-context.json resolves I24:755;164:9706 to
  `battery.100percent`, SF Pro Semibold 13/16, white, zero tracking.
  The battery outline is the exact Figma glyph, not an inferred percentage glyph
  based on the sample's 64% charge.

## Implementation scope

- Features/MenuBar/Components/MenuBarStatusLabel.swift: available discharging
  battery delta uses the resolved symbol and typographic U+2212 minus.
  Accessibility value is `−18.4 watts`, with the existing
  `Watt? power reading` label. Shared PowerFormatter, other display modes,
  charging symbol/text, HStack spacing and native typography remain unchanged.
- App/WattApp.swift: DEBUG-only C042FixtureLaunch selects C04.2/base exactly,
  uses existing sampleOnBattery and a sample-timestamp-pinned FakeWattClock,
  isolated in-memory PreferencesStore with Delta/symbol enabled and onboarding
  suppressed. No polling, live telemetry, network or persistent defaults.
  Reuses C04.1's capture implementation and explicit 1× bitmap; selects only
  C04.2 geometry/metadata for C04.2. Each story requires its own capture flag.
- Tests/Fixtures/StoryFixtures.swift: enables C04.2 beside prior implemented
  fixtures; C04.3–12 remain unavailable.
- Tests/WattTests/F05FixtureTests.swift: four C042 tests cover model/clock,
  text/symbol/accessibility, preference isolation, unavailable readings, exact
  selector/variant/sibling rejection, capture-flag isolation and bitmap geometry.
  Existing registry/C041 sibling expectations updated for the newly enabled story.
- DESIGN.md: records this bounded implementation and outstanding visual gaps.
  No shared style, model fixture value, C04.1 evidence or backlog changes.

## Native capture and comparison

Run from the worktree root after the Debug build:
`bash docs/evidence/C04.2/capture.sh && bash docs/evidence/C04.2/compare.sh`.

The DEBUG harness creates a real app-owned NSStatusItem with the production
SwiftUI label, temporarily relocating its NSStatusBarButton into an owned
560×44-point window. The harness suppresses MenuBarExtra only for capture.
Normal fixture launch retains MenuBarExtra.

- capture.json records NSStatusBarButton, reference node IDs and geometry.
  AppKit bottom-left (204,15) corresponds to reference top-left (204,5).
- actual-status-item-1x.png is the direct 560×44-pixel AppKit view-subtree
  render into a 560×44-point bitmap, not a resampled screenshot.
- actual-status-item.png is the untouched 1120×88 screen-scale diagnostic.
- reference-item.png and actual-item.png are unresampled 97×24 crops.
- Frame and item comparisons both report changedFraction **1.0**, failing
  the 1% threshold (per-channel difference >1/255). No mask or background
  substitution. images.sha256 records all top-level PNGs.
- Inspected native render contains the expected battery outline and minus/value.
  Foreground weight, rasterization/softness, baseline and spacing differ from
  Figma. The solid synthetic dark backdrop omits wallpaper and neighboring
  system items, making the unmasked metric unsuitable for isolating text fidelity.

This is app-owned native-button render evidence, **not live MenuBarExtra
compositor pixels or global menu-bar placement proof**. AppKit/SwiftUI may use
internal layer caches; a direct 1× destination does not prove their internal
rasterization scale. No desktop screenshot, screen recording, AX automation,
TCC permission request or bypass. VoiceOver traversal and physical interaction
are not verified. There is no independent visual review/score for C04.2.
Implementation-owner self-review is **86/100 FAIL**, persisted in
[visual-review.json](visual-review.json); this subjective rubric score is not
independent approval or a pixel-similarity metric. Visual acceptance remains open.

The existing native system font is deliberately preserved; the Figma 13/16
contract is recorded, not claimed as pixel-matched. Visual acceptance stays open.

## Fresh verification

With DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer:

- `swift test --filter 'C04[12]StatusItemTests'`: **9 passed** (5 C041, 4 C042).
- Hosted same two suites: **9 passed**, native-focused.log.
- `swift test`: **217 executed, 1 opt-in physical telemetry skip, 0 failures**.
- Hosted full WattTests: **217 executed, same 1 skip, 0 failures**.
- Debug and Release `xcodebuild build analyze`: **BUILD/ANALYZE SUCCEEDED**.
  Only AppIntents metadata-extraction warning (no framework dependency).
- Release binary: no C04.2/C042Fixture/c042 capture selectors.
- `git diff --check`, Bash syntax and ShellCheck: pass.
- Fresh C04.1 capture using the updated binary: **byte-identical direct 1× PNG**
  to prior C04.1 evidence; original x205,y5,96×24 geometry retained.
  See c041-regression/capture.json and c041-regression-check.log.

Native commands use `-project Watt.xcodeproj -scheme Watt -destination
'platform=macOS'`, Debug derived data `.build/c042-native`, Release
`.build/c042-release`; tests use `-parallel-testing-enabled NO` and
`-only-testing:WattTests` (focused runs further select C041StatusItemTests and
C042StatusItemTests). Full logs are retained alongside these artifacts.

Stop condition: requested implementation and verification completed; visual
acceptance explicitly not granted. No checkpoint or commit.
