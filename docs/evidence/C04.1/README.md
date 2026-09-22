# G015 / C04.1 — Delta · charging

Implementation evidence only. **No visual pass, checkpoint, or acceptance claim.**

## Reference
Exact frame 24:390; item 24:636; anchor 24:638. Existing F00 export copied
unchanged (SHA256 22a43d638a7d52ff6a5169b63a5006da09196a2c13dede9029bc0b57ad5510ae).
Retained frame context was inspected before edits (figma-context.json). Fresh
2026-09-22 retrievals are current-component-context.json and current-symbol-context.json.
The request for I24:636;164:9706 resolved U+10088B to battery.100percent.bolt,
SF Pro Semibold 13/16, white, zero tracking. It is not bolt-in-circle.

The exact export is **560x44**, not 300x44. The resumed harness now uses the full
560x44 frame. The item is x205,y5,96x24; its anchor ends at x301 without clipping.
The old reference-300x44 files are retained historical derivatives, not current inputs. Other menu-bar content is backdrop, not implemented app UI. No dock.

## Changed files
- Features/MenuBar/Components/MenuBarStatusLabel.swift: exact symbol for available
  charging battery delta; existing formatter, observed preferences and typography
  reused. Other display/state combinations retain previous bolt behavior.
- App/WattApp.swift: DEBUG C04.1 gate, isolated preferences, existing deterministic
  sampleCharging/pinned preview clock, onboarding suppression and capture harness.
- Tests/Fixtures/StoryFixtures.swift: enables only C04.1 alongside C01/C02/C03.
- Tests/WattTests/F05FixtureTests.swift: selectors, sibling rejection, pinned data,
  exact text/icon/accessibility and display-switch tests; registry expectations.
- docs/evidence/C04.1: reference, capture, comparisons, scripts and verification logs.

The earlier implementation changed capture geometry and the symbol-visibility test
seam. The current bounded correction changes only DEBUG capture code, its focused
bitmap test, capture/compare scripts and evidence documentation. No changes to telemetry, sample values,
shared styling, C03 menu factory or backlog.

## Capture and limitations
The first attempt to capture the existing MenuBarExtra anchor produced no evidence:
its label bridge did not mount on this host. The bounded DEBUG capture path instead
suppresses MenuBarExtra and creates one actual app-owned NSStatusItem using the
production MenuBarStatusLabel, sample and preferences. Normal C04.1 fixture launch
continues to use MenuBarExtra. The harness relocates the real NSStatusBarButton into
a 560x44 owned window with fixed item constraints. NSView.cacheDisplay retains
a screen-scale diagnostic; NSView.displayIgnoringOpacity(_:in:) draws the owned
view subtree directly into an explicit 560x44-pixel NSBitmapImageRep whose point
size is also 560x44. No desktop screenshot, AX, screen recording or TCC bypass.

capture.json records class, geometry and both bitmap dimensions. Both app-written
PNGs remain untouched; compare.sh uses the direct actual-status-item-1x.png and
compares the requested frame and item crops against the exact export. No sips
resize or other post-capture resampling remains in this pipeline. The synthetic solid-dark background deliberately
does not recreate wallpaper or neighboring system items. Differences therefore
include backdrop and native font/symbol rasterization, baseline and spacing.

This proves a real native fixture status-item render, **not live MenuBarExtra
compositor pixels or global placement**. The independent verdict below is **87/100 FAIL**.

## Verification evidence
- package-tests.log and native-tests.log: full suites, including C03/C04.1.
- Debug/Release build-analyze logs: compiler/typechecking and static analysis.
- release-isolation.log: DEBUG fixture/capture selectors absent from Release.
- static-checks.log: diff whitespace, shell syntax and ShellCheck.
- capture-run.log, comparison PNGs/JSON, images.sha256: visual evidence.

Reproduce from worktree root after native Debug build in .build/c041-native:
`bash docs/evidence/C04.1/capture.sh && bash docs/evidence/C04.1/compare.sh`.

Remaining acceptance gaps: live MenuBarExtra pixels and foreground visual parity.
The independent review below fails; this slice does not complete visual acceptance.

## Earlier resumed verification — 2026-09-22 (superseded capture)

- Focused package and hosted C041StatusItemTests: 4 passed each.
- Full package and hosted WattTests: 212 executed each, 1 opt-in physical telemetry
  skip, 0 failures. This includes existing C03 and native-styling regressions.
- Xcode Debug and Release build/analyze succeeded. Release binary string check
  finds no C04.1 fixture/capture selectors. Whitespace, Bash syntax and ShellCheck pass.
- Fresh NSStatusBarButton capture: 560×44 points, 1120×88 raw pixels; full item
  96×24 points. AppKit bottom-left button origin (205,15) corresponds to the
  reference top-left origin (205,5).
- Comparison uses an explicitly resampled 1x derivative (sips); raw capture and
  exact export are retained. Frame and item diagnostic changedFraction are both
  1.0 at >1/255 per-channel difference, failing the 1% threshold. The synthetic
  solid backdrop differs throughout, so this metric cannot isolate text fidelity.
- Direct inspection shows the expected battery/bolt symbol and +42.1 W label.
  The overlay shows native baseline/rasterization differences; semantic correctness
  and correct capture bounds do not establish pixel parity.
- No desktop screenshots, screen-recording API, AX automation or TCC bypass.
  No live MenuBarExtra compositor proof, physical interaction/VoiceOver verification
  or independent visual approval. No checkpoint or commit.

Commands (Xcode toolchain selected with DEVELOPER_DIR):
```sh
swift test --filter C041StatusItemTests
swift test
xcodebuild -project Watt.xcodeproj -scheme Watt -configuration Debug -destination 'platform=macOS' -derivedDataPath .build/c041-native build analyze
xcodebuild -project Watt.xcodeproj -scheme Watt -configuration Debug -destination 'platform=macOS' -derivedDataPath .build/c041-native test -only-testing:WattTests/C041StatusItemTests -parallel-testing-enabled NO
xcodebuild -project Watt.xcodeproj -scheme Watt -configuration Debug -destination 'platform=macOS' -derivedDataPath .build/c041-native test -only-testing:WattTests -parallel-testing-enabled NO
xcodebuild -project Watt.xcodeproj -scheme Watt -configuration Release -destination 'platform=macOS' -derivedDataPath .build/c041-release build analyze
bash docs/evidence/C04.1/capture.sh
bash docs/evidence/C04.1/compare.sh
```

## Direct 1× correction — 2026-09-22

The supplied independent score is **86 for the earlier downsampled capture**.
That historical score is superseded for the direct 1× capture by the **87/100 FAIL**
review below; neither result grants visual approval.

- Public API probe: the installed macOS SDK NSView.h declares
  displayRectIgnoringOpacity:inContext: for view-subtree drawing (also the
  recommended replacement for deprecated lockFocusIfCanDrawInContext:).
  This path successfully produced visible native battery/bolt and +42.1 W content
  at 560×44 pixels, directly from the existing app-owned button subtree.
- The capture bitmap has exactly one pixel per point, independent of this host's
  2× screen backing scale. The new regression test verifies dimensions, point
  size and unit context transform. No manual text/symbol drawing, positional
  correction, layer-scale override or production styling changes were introduced.
- AppKit/SwiftUI may use internal layer caches; this proves a direct 1× destination
  and removal of our downsampling step, not control over their internal
  rasterization. Native text still looks different from the reference. No
  assertion that all softness or baseline differences have been fixed.
- Focused package and hosted C041StatusItemTests: **5 passed each**.
  Debug and Release build/analyze succeeded (one-x-*.log). Release selector
  isolation, diff whitespace, Bash syntax and ShellCheck passed.
- Fresh frame changedFraction: **0.9999594156**; item: **0.9995659722**.
  Both fail the 1% threshold. These unmasked comparisons include the intentionally
  different backdrop and cannot isolate foreground fidelity. No background
  substitution or content synthesis was performed.
- Full suites were not rerun for this bounded correction; their earlier results
  above are historical. Current capture/compare logs and image hashes are fresh.
- Production MenuBarStatusLabel, NSStatusItem creation and MenuBarExtra code are
  unchanged by this correction. No desktop/TCC capture, checkpoint or commit.
  Independent visual acceptance, live compositor and accessibility gaps remain.

## Fresh independent visual review — 2026-09-22

**87/100 — FAIL.** [visual-review.json](visual-review.json) persists the fresh
independent verdict supplied by the task, not a new review performed by this
documentation update or implementation self-approval. The earlier **86/100**
concerned the downsampled capture; this verdict concerns the direct 1× capture.

- **Matches:** charging battery-delta semantics, `battery.100percent.bolt` and
  `+42.1 W` content; 560×44 frame and unclipped 96×24 item at top-left x205,y5.
  Matching capture geometry does not prove live menu-bar placement.
- **Mismatches:** foreground typography, native text/symbol rasterization and
  baseline alignment still differ. Semantic/content/geometry matches do not
  establish visual parity.
- **Filenames:** `actual-status-item-1x.png` is the current direct 560×44-pixel
  input, not a downsampled derivative. `actual-status-item.png` is the
  1120×88-pixel screen-scale diagnostic. `reference-24-390.png` is the exact
  560×44 export; `reference-300x44.png` is a historical derivative, not the
  current reference. `actual-item.png` and `reference-item.png` are the
  unresampled 96×24 crops of the current inputs.
- **Limits:** the synthetic solid-dark backdrop does not reproduce wallpaper or
  neighboring system items. Both unmasked pixel diagnostics still fail and
  cannot isolate foreground fidelity. This relocated app-owned NSStatusBarButton
  render is not live MenuBarExtra compositor evidence or global placement proof.
  No desktop screenshot, screen recording, AX automation or TCC bypass was used;
  physical interaction and VoiceOver/AX traversal remain unverified.
- **Persistence only:** image hashes remain consistent with `images.sha256` and
  the review JSON. Product source, images, comparisons and historical logs are
  unchanged; builds, tests and capture commands were not rerun for this update.
  No new commands or code examples were added.

**Visual acceptance remains open. No pass, checkpoint or story-completion claim.**
