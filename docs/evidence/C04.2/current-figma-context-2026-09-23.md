# C04.2 exact Figma reinspection — 2026-09-23

Figma MCP was queried for file `9DKDgUfEqidZdZQEVlQgLS`, frame `24:639`,
using the SwiftUI design-to-code and SwiftUI translation guidance.

The returned hierarchy is:

- `24:639` — **Delta · on battery**
- `24:640` — Desktop Template, dark mode, dock hidden
- `24:757` — right-aligned Status Item Anchor, top offset 5, width 301
- `24:755` — Watt? Status Item, dark native menu-bar item
- Display contract — `􀛨 −18.4 W`
- Typography — SF Pro Semibold, 13/16, weight 590, zero tracking

The existing native implementation maps that state to `battery.100percent`,
typographic minus `−18.4 W`, shared `WattTypography.bodyEmphasized`, and one
accessible status-item element. No custom menu-bar painting or duplicated
Figma chrome was introduced.

Focused package/native C04.1+C04.2 verification passed 9/9 and Release
build/analyze passed. The existing C04.2 independent visual review remains
FAIL because native rasterization/compositor evidence is not equivalent to the
Figma export; this reinspection does not close that visual gate.
