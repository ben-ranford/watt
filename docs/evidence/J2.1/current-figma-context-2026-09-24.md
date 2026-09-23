# J2.1 Figma context — 2026-09-24

Retrieved with Figma MCP `get_design_context` using:

- file: `9DKDgUfEqidZdZQEVlQgLS`
- frame: `29:1549` — **2.1 Per Component unavailable in menu**
- client: Swift / SwiftUI
- skills: `figma-design-to-code,figma-swiftui`

The frame is a light macOS 27 desktop template with no dock. The relevant nodes are:

- `29:1550` — Desktop Template
- `29:1860` — Status Item Anchor (right-aligned)
- `29:1857` — selected Watt? Status Item (`􀢋 +42.1 W`)
- `29:1861` — main native Menu, 230 × 187 points
- `29:2197` — Show in Menu Bar readings submenu, 250 × 176 points

Main menu order: Show in Menu Bar (hovered submenu row), separator, Open Watt?, Settings… with Command-comma, separator, About Watt?, Check for Updates…, separator, Quit Watt? with Command-Q. The readings submenu is Delta (checked), Charger, Draw, Components (disabled), separator, Icon, separator, Turn On Helper… . Figma supplies SF Pro Body/Emphasized at 13/16 semibold; native AppKit owns the live font rendering, material, hit targets, checkmark, chevron, separators, keyboard navigation and accessibility semantics.

The returned context contains no app-authored raster assets or non-SF Symbols for this frame. The desktop wallpaper, menu bar and status-item compositor are system-owned. Watt therefore uses `NSMenu`, `NSMenuItem` and the native status-item bridge rather than reproducing those surfaces in SwiftUI.
