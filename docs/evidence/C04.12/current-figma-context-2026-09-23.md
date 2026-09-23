# C04.12 current Figma context — 2026-09-23

Source: Figma file `9DKDgUfEqidZdZQEVlQgLS`, exact node `24:1960`, retrieved
through `figma_get_design_context` with the SwiftUI translation skills.

## Hierarchy

- `24:1960` — **Light menu bar · on battery**, 560 × 44 frame.
- `24:1961` — Desktop Template, light macOS desktop, dock hidden.
- `24:2078` — Status Item Anchor (right-aligned), top 5, width 301.
- `24:2076` — Watt? Status Item, selected=false, displayed as the native
  outlined battery symbol plus **`−18.4 W`**.

The frame uses the light macOS 27 desktop/menu-bar variant. Desktop wallpaper,
menu bar material and global placement remain system-owned. The app must use
native Aqua/AppKit styling rather than custom light colors or chrome.

## Tokens and assets

- Typography: `SF Pro`, Semibold, weight 590, 13 pt, 16 pt line height, zero
  tracking (`Body/Emphasized`).
- Asset: outlined battery is the existing SF Symbol used by the native label;
  no custom image/vector asset is present.
- Component: native unselected status item, no custom background, border,
  radius, shadow, bitmap UI or custom foreground tint.
- Content: on-battery reference reading `−18.4 W` for `C04.12/base`.

## Verification mapping

The fresh final-source DEBUG capture records a real Aqua `NSStatusBarButton`,
selected=false, at `{{204, 15}, {97, 24}}` inside a direct 560 × 44 1× AppKit
bitmap, corresponding to Figma x204/y5/97×24. Visual inspection confirms the
outlined battery and typographic minus reading; native rasterization and the
missing desktop/compositor surface remain differences.

Strict unmasked diagnostics remain intentionally non-passing because the
capture is a relocated native button without live desktop/compositor pixels.
No custom light colors or glyph paint was added.
