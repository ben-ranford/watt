# J1.8 evidence — first-open live panel

- Exact Figma reference: node `28:2802`, `figma-reference.png`.
- Native hierarchy: selected `NSStatusItem` (`+42.1 W`) → real `NSPopover` panel `29:9338` with Charging, `+42.1 W`, `64% · full in about 38 min`, grouped Power and Components rows, and native Settings… / Quit Watt? actions.
- Exact node/typography/component details: `current-figma-context-2026-09-24.md`.
- Source implementation: `StatusPanelView` keeps native SwiftUI `Form`/`Section`/`LabeledContent` semantics and the production AppKit `C0410PanelSelection` owns the selected status-item state and `NSPopover` presentation. No custom menu-bar or panel chrome is painted.

## Fresh verification

- Package J1.8 tests: **5 passed / 0 failed** (`final-package-focused-xcode-2026-09-24.log`).
- Hosted J1.8 + NativeStyling tests: **16 passed / 0 failed** (`final-native-focused-2026-09-24.log`).
- Debug build/analyze: **passed** (`final-build-analyze-2026-09-24.log`).
- Release build/analyze: **passed** (`final-release-build-analyze-2026-09-24.log`).
- Capture: **exit 0**, two app-owned compositor windows, screen capture preauthorized (`window.json`, `final-capture-2026-09-24.log`).
- Stable native captures: `native-panel.png` (the real `NSPopover`, 692×1078 pixels including native shadow/arrow) and `native-anchor.png` (temporary DEBUG-only anchor window). SwiftUI content raster: `actual-content.png` (320×473 pixels).

## Visual review

The native panel capture contains the exact reference copy, values, row ordering, grouped sections, native arrow, material, rounded surface and native bottom actions. Manual app-owned visual review: **91/100**. No calibrated pixel-diff score is claimed because the Figma reference is a full desktop composition while the implementation capture is a native compositor window with OS-owned material/rasterization.

The whole story remains **blocked for final acceptance** until production first-open interaction is verified through the live status-item compositor and AX/VoiceOver on the target host. This evidence does not claim that temporary DEBUG anchoring proves live MenuBarExtra interaction. No TCC bypass, fake window, or fake status item was used.
