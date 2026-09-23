# C04.5 exact Figma reinspection — 2026-09-23

Figma MCP was queried for file `9DKDgUfEqidZdZQEVlQgLS`, frame `24:996`,
using the SwiftUI design-to-code and SwiftUI translation guidance.

The returned hierarchy is:

- `24:996` — **Charger Input · unplugged (falls back to System Draw)**
- `24:997` — Desktop Template, dark mode, dock hidden
- `24:1114` — right-aligned Status Item Anchor, top offset 5, width 301
- `24:1112` — Watt? Status Item, dark native menu-bar item
- Display contract — `􀛨 18.4 W`
- Typography — SF Pro Semibold, 13/16, weight 590, zero tracking

The implementation uses the explicit `.chargerInput` presentation state,
disconnected charger capability, fresh System Draw fallback, native
`battery.100percent`, unsigned `18.4 W`, and one accessible status-item element.

The final-source DEBUG capture was rebuilt and recaptured after the scoping fix:
the real `NSStatusBarButton` is 88×24 at reference x213,y5, with a direct 1×
560×44 bitmap. The strict unmasked diagnostics still exit 2 because the native
capture has a synthetic backdrop and native rasterization differences; this is
fresh evidence, not visual approval.
