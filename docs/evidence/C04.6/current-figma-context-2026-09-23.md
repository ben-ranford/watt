# C04.6 exact Figma reinspection — 2026-09-23

Figma MCP was queried for file `9DKDgUfEqidZdZQEVlQgLS`, frame `24:1115`,
using the SwiftUI design-to-code and SwiftUI translation guidance.

The returned hierarchy is:

- `24:1115` — **System Draw (desktop Macs)**
- `24:1116` — Desktop Template, dark mode, dock hidden
- `24:1233` — right-aligned Status Item Anchor, top offset 5, width 301
- `24:1231` — Watt? Status Item, dark native menu-bar item
- Display contract — `􀋦 38.2 W`
- Typography — SF Pro Semibold, 13/16, weight 590, zero tracking

The implementation uses the native `.draw` mode with no-battery capability
semantics, native `bolt.fill`, unsigned `38.2 W`, shared
`WattTypography.bodyEmphasized`, and one accessible status-item element.

The final-source Debug binary was rebuilt and recaptured. The real native button
is 80×24 at reference x221,y5 inside a direct 560×44 1× bitmap; the captured
content visibly contains the native bolt and `38.2 W`. Strict diagnostics remain
open because the bounded capture is not the Figma compositor.
