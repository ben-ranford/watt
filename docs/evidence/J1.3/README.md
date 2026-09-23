# G030 — J1.3 Offer component readings

## Source and implementation
- Exact saved reference: `figma-frame.png`, frame `27:1584`, window `27:1738`,
  content `27:1750`, rows `27:2106`. Reference window is 480×412 points at
  (260, 164). The supplied Figma download_assets image 3 (`/tmp/j13-raw-3.png`,
  256×256 RGBA) is copied byte-for-byte into
  `Resources/Assets.xcassets/WattAppIcon.imageset/watt-app-icon.png` at 2x.
  SHA-256: `948a88b21b68fcf435b3ca2c4c5b8be2900ee3f585cf7befe6dc3e9f97ad9b67`.
  No generated or custom-drawn icon is used.
- `Features/Onboarding/Views/OnboardingFlowView.swift`: provided Figma icon rendered by native Image at 64×64, heading
  “See where the power goes”, helper explanation, and the exact three facts:
  “What it reads” / “Power sensors only”, “Network” / “Never”,
  “Remove it” / “Any time, in Settings”. Reuses native grouped Form and
  LabeledContent plus native bordered Not Now and
  borderedProminent/default Turn On… buttons. Native buttons use OS-owned
  intrinsic spacing; no extra Back button or painted controls. Grouped Form margins are
  compensated with token-based padding, and row minimum heights use existing
  spacing tokens. The native compositor capture now places the facts panel
  approximately at x32, y214, width416, height126 points, versus the previous
  x52, y228, width376, height110. System separators and chrome remain native.
- Not Now clears opt-in and routes to all-set; Turn On… persists opt-in intent
  and routes to approval. Neither marks onboarding complete nor grants helper
  approval. Subsequent screens remain the existing route shells.
- `App/WattApp.swift`: existing debug fixture uses fresh in-memory preferences,
  fixed preview telemetry, en_US, aqua and titleless native window. Capture
  metadata now includes the rows node. Release excludes capture launch code.
- `Tests/WattTests/J13OfferTests.swift`: exact copy/fixture, two actions,
  persisted intent, stale-route guards, native window close/resume and size,
  plus provided-asset/native-control regression coverage.
- `Tests/WattTests/F05FixtureTests.swift`: both registry expectation lists now
  include J1.3. Assertions remain intact; unimplemented stories still must
  reject rendering. `SCREEN-BACKLOG.md` uses the reference's Turn On… copy,
  matching the existing J1.3 fixture rather than the old Enable… wording.
- Cumulative worktree edits preserved. DESIGN.md needed no additional change.

## Fresh verification — 2026-09-22
- `focused-tests.log`: 5 J13OfferTests, **0 failures**.
- `full-tests.log`: 270 tests executed, 1 skipped, **0 failures**; includes
  F05 registry expectations and native styling source contracts.
- `debug-build-analyze.log`, `release-build-analyze.log`: both BUILD SUCCEEDED
  and ANALYZE SUCCEEDED. Swift compilation/typechecking included.
- `static-checks.log`: diff whitespace, shell syntax, native control contracts,
  no custom painting/extra Back, and Release fixture isolation passed.
- `capture.json`: actual content **480×412**. `window.json`: PID-scoped native
  compositor window **480×412** points; `native-window.png` is 960×824 pixels.
  `images.sha256` binds the final images. All saved `.exit` files are zero.
- This refinement preserves the original <=412 size regression assertion. Both
  final capture paths confirm 480×412; Debug and Release build/analyze, focused
  and full tests, and static checks were rerun after the asset/layout changes.

## Visual and accessibility limits
**Independent visual gate: 96/100 — PASS (threshold >=90).**
`visual-review.json` records the independent visual-ralph result supplied for
this update; this documentation change does not perform a new review. The
comparison uses the exact 480×412-point reference window at (260, 164), with
`native-window.png` at 960×824 pixels normalized at 2x (2 pixels per point).
`actual-content.png` separately confirms 480×412 content dimensions. The
independent result supersedes the earlier score of 86 for visual acceptance.

Accepted native macOS differences include traffic-light treatment, font
metrics, button rendering and window background. Minor button-width and
info-panel tone differences remain. PASS does not claim pixel parity or a
calibrated pixel-diff score.

`capture.json` and `window.json` remain unchanged capture-time metadata;
their `visualPass: false` values do not express this subsequent independent
visual-only verdict. The capture metadata has no established independent
visual-threshold contract; the separate review records visual PASS without
claiming an overall gate including AX has passed. The outstanding-review
wording in `window.json` describes capture time, not the later review.
No live AX interaction, VoiceOver audit or TCC verification is claimed.
No permission prompt or TCC bypass was attempted.

This is documentation-only persistence of the supplied result: no new capture,
build, test run or accessibility audit. Existing reproduction commands below
were not rerun for this update; image dimensions and saved hashes were checked,
and `git diff --check` was run.

Tests here are the full Swift package unit suite, not an Xcode UI automation
run. One existing test remains skipped; see the full log for its reason.

## Reproduce
```sh
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
xcrun swift test --scratch-path /tmp/watt-g030-swift --filter J13OfferTests
xcrun swift test --scratch-path /tmp/watt-g030-swift
xcodebuild -project Watt.xcodeproj -scheme Watt -configuration Debug -derivedDataPath /tmp/watt-g030-debug build analyze
xcodebuild -project Watt.xcodeproj -scheme Watt -configuration Release -derivedDataPath /tmp/watt-g030-release build analyze
bash docs/evidence/J1.3/capture.sh
bash docs/evidence/J1.3/static-checks.sh
```
