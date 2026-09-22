# Native-control correction — fresh verification, 2026-09-22

> Historical pre-review run. [Review corrections and fresh evidence](review-corrections/README.md)
> supersede the duplicate-field/helper-group findings below. Original captures,
> logs, hashes and scores are retained unchanged for provenance.

**Native ownership verified; no visual-fidelity or accessibility acceptance.**
Only capture harness and evidence/docs changed in this verification. No product
behavior edits, checkpoint, TCC request, desktop screenshot or permission bypass.
The existing worktree/branch and its pre-existing changes were retained.

## Fresh images

Final `capture.log` contains eight captures, generated from current source after
fixing `Double\(bitmap.pixelsWide)` to `Double(bitmap.pixelsWide)`.
Per-image JSON records UTC capture time, macOS 27.0 (26A428), bounds and 2 px/point.
`images.sha256` and `sources.sha256` bind final images and source/harness inputs.
Old failed `../capture.log` is historical, not this run's result.

| Fixture | Light | Dark | Raw size |
|---|---|---|---|
| Gallery top | [light](controls-light.png) | [dark](controls-dark.png) | 1160×2000 |
| Gallery bottom | [light](controls-bottom-light.png) | [dark](controls-bottom-dark.png) | 1160×2000 |
| Reading + native window frame | [light](reading-light.png) | [dark](reading-dark.png) | 960×732 |
| Settings shared sections | [light](settings-light.png) | [dark](settings-dark.png) | 1160×1240 |

Native NSScrollView scrolling exposes gallery progress/status rows without changing
production layout. Reading captures the app-owned NSWindow frame through NSView
cacheDisplay: directly caching its transparent NSHostingView lost the backing
surface. Those preliminary images were replaced, not presented as fresh evidence.
Other PNGs are content-only. The standalone host has no WattApp service graph.

## Native audit

- `WattActionButton`: genuine Button, bordered/borderedProminent styles and
  destructive role; no foreground/tint/background/shape paint on actions.
- `ReadingPicker`: genuine radioGroup Picker with disabled unavailable modes;
  gallery menu pickers and toggles use native styles.
- `WattFormRow`: LabeledContent. Gallery/settings/status panel: Form/Section with
  grouped style; separators, rows and corners belong to SwiftUI.
- `WattWindowScaffold`: no background or clipShape. Production Window, Settings,
  MenuBarExtra and NSMenu remain system-owned. Captured reading titlebar is a real
  titled NSWindow, not a replica; this is not production-scene chrome parity proof.
- No gradients, custom rounded rectangles, stroke borders, tint overrides or
  painted control/window backgrounds remain in these corrected components.
  Semantic secondary labels and green/red status-copy colors intentionally remain.
  `App/WattApp.swift`'s background ScenePresentationBridge is an integration view,
  not paint. Its separate DEBUG C04.1 host still has a gray capture backdrop; that
  fixture is neither production styling nor used here. No repository-wide claim
  that all background modifiers have been removed is made.

## Visual comparison

Retained F02 Figma exports: `27:1354` reading and `25:787` settings, in
`docs/verification/f02-gallery/references/`; hashes in `references.sha256`.
Inspected against current reading/settings and both gallery appearances.
Semantic hierarchy and native control categories match. Native Form now changes
spacing, headings and helper-note grouping; the gallery needs scrolling and the
focus field displays a duplicate label. Inactive captures have gray action/radio/
switch chrome rather than reference blue. No forced paint was added to hide this.

`visual-ralph-verdict.json` contains the required score/verdict/category_match/
differences/suggestions/reasoning fields: **82/100 qualitative self-assessment,
PARTIAL, threshold not met**, not an independent review or pixel score.
Dark variants use the light Figma specimens for semantic comparison only.

Secondary diff uses the existing F05 image helper against the **historical native
F02 reading captures**, not Figma. A 64px titlebar crop yields 960×668, 2 px/point,
no resampling/masks. Changed pixels: light 2.636%, dark 2.645%; both fail 1% tolerance.
Raw crops, overlays, diffs and JSON are retained. Direct Figma pixel diff was not
performed because the retained full-frame exports differ in crop/scale. Historical
F02 scores do not transfer to this correction.

## Validation and reproduction

Run from worktree root with `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer`:

```sh
bash docs/evidence/native-styling/capture.sh <output-directory>
swift test --filter NativeStylingTests
xcodebuild -project Watt.xcodeproj -scheme Watt -configuration Debug \
  -destination 'platform=macOS' -derivedDataPath .build/native-styling-verification build analyze
xcodebuild -project Watt.xcodeproj -scheme Watt -configuration Debug \
  -destination 'platform=macOS' -derivedDataPath .build/native-styling-verification \
  test -only-testing:WattTests/NativeStylingTests -parallel-testing-enabled NO
```

- Package NativeStylingTests: **3 passed, zero failures** (`package-focused.log`).
- Hosted NativeStylingTests: **3 passed, zero failures** (`native-focused.log`);
  xcresult: `.build/native-styling-verification/NativeStylingTests.xcresult`.
- Debug build + analyze: **both succeeded**, exit 0 (`debug-build-analyze.log`).
- Capture compile/run succeeded, eight final images (`capture.log`).
- Bash syntax, ShellCheck, whitespace/hash checks: `static-checks.log`.
- Existing previewDisplayName deprecation and build warnings remain nonfatal.

The host reports `isKeyWindow=false` despite requesting activation. Active accent,
focus ring, pointer/keyboard behavior, alert presentation, VoiceOver and WindowServer
vibrancy are **not verified**. In-process AX records are incomplete (mostly scroll
containers), not evidence of complete control accessibility. Source contracts and
layout tests cover native intent, including high-contrast layout, not runtime AX.
No screen/story completion, independent reviewer sign-off or checkpoint is claimed.
