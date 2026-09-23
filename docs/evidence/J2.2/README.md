# G037 / J2.2 — Panel, component readings off

Status: **implemented, natively rendered, and visually verified**.

## Exact source

Figma MCP source is frame `29:2456`, with panel `29:7572`. The panel content is
320×347 points and shows Charging, +42.1 W, 64% · full in about 38 min, power
rows for charger/system/battery, Components Off with helper copy and Turn On…,
plus native Settings… and Quit Watt? controls.

## Implementation

`StatusPanelView` accepts `componentReadingsEnabled`; `MenuBarRootView` passes the
production preference. Disabled readings hide cached components, show the Off
state and preserve the 320×347-point native panel geometry. Turn On… routes to
Settings without enabling a helper or fabricating approval. Existing enabled and
unavailable states remain unchanged.

The DEBUG fixture opens the same production `C0410PanelSelection` `NSPopover`
through a temporary native AppKit anchor. This is required on the current macOS
27 host because neither SwiftUI `MenuBarExtra` nor public `NSStatusItem` receives
a visible compositor slot. The anchor is test-only; production does not draw a
replacement menu bar or panel chrome.

## Verification

- Figma MCP context refreshed 2026-09-24: `current-figma-context-2026-09-24.md`.
- Focused package tests: 5 passed, 0 failures.
- Fresh verification logs: `package-tests-2026-09-24.log`,
  `native-tests-2026-09-24.log`, `debug-analyze-2026-09-24.log` and
  `release-analyze-2026-09-24.log` (all exit 0).
- Native capture: real `NSPopover` window, app-owned 320×347-point content,
  `actual-content.png` and `capture.json`.
- Full-screen native popover inspection confirmed hierarchy, values, native
  material, footer controls and disabled component state.
- Visual review: `visual-review.json`, score 96, pass.
- Debug Xcode build: pass; the same build launched the real native popover.

The separate J2.3 helper-enable flow remains a downstream story and is not
claimed complete here.
