# C04.11 current Figma context — 2026-09-23

Source: Figma file `9DKDgUfEqidZdZQEVlQgLS`, exact node `24:1711`, retrieved
through `figma_get_design_context` with the SwiftUI translation skills.

## Hierarchy

- `24:1711` — **Light menu bar · charging**, 560 × 44 frame.
- `24:1712` — Desktop Template, light macOS desktop, dock hidden.
- `24:1959` — Status Item Anchor (right-aligned), top 5, width 301.
- `24:1957` — Watt? Status Item, selected=false, displayed as the charging
  SF Symbol plus **`+42.1 W`**.

The frame uses the light macOS 27 desktop/menu-bar variant. Desktop wallpaper,
menu bar material and global placement remain system-owned; the application
must adopt native Aqua appearance rather than paint light colors itself.

## Tokens and assets

- Typography: `SF Pro`, Semibold, weight 590, 13 pt, 16 pt line height, zero
  tracking (`Body/Emphasized`).
- Asset: the charging glyph is an SF Symbol from the shared native label; no
  custom image/vector asset is present.
- Component: native unselected menu-bar item, no custom background, border,
  radius, shadow, bitmap UI or custom foreground tint.
- Content: fixed reference charging sample `+42.1 W` for `C04.11/base`.

## Verification mapping

The fresh final-source DEBUG capture records a real `NSStatusBarButton` with
public `NSAppearanceNameAqua`, selected=false, at `{{205, 15}, {96, 24}}`
inside a direct 560 × 44 1× AppKit bitmap, corresponding to Figma x205/y5.
The native light label is visually compared to the reference; foreground
rasterization and the missing desktop/compositor surface remain differences.

Strict unmasked diagnostics remain intentionally non-passing because the
capture is a relocated native button without live desktop/compositor pixels.
No custom color or chrome was added to force parity.
