# C04.4 exact Figma reinspection — 2026-09-23

Figma MCP was queried for file `9DKDgUfEqidZdZQEVlQgLS`, frame `24:877`,
using the SwiftUI design-to-code and SwiftUI translation guidance.

The returned hierarchy is:

- `24:877` — **Charger Input**
- `24:878` — Desktop Template, dark mode, dock hidden
- `24:995` — right-aligned Status Item Anchor, top offset 5, width 301
- `24:993` — Watt? Status Item, dark native menu-bar item
- Display contract — `􀋦 65.0 W`
- Typography — SF Pro Semibold, 13/16, weight 590, zero tracking

The existing implementation uses the native `.charger` display mode with the
available `chargerWatts` field, shared `WattTypography.bodyEmphasized`, native
`bolt.fill`, and one accessible status-item element. No custom menu-bar painting
or duplicated Figma desktop chrome is used.

Focused C04.4 verification was previously green (16 C04.1–C04.4 tests per
host); the exact C04.4 contract remains covered by its existing evidence. The
current hardware probe independently confirms that live charger input is a
separate value from battery delta; visual acceptance remains open.
