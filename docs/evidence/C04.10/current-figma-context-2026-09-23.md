# C04.10 current Figma context — 2026-09-23

Source: Figma file `9DKDgUfEqidZdZQEVlQgLS`, exact node `24:1591`, retrieved
through `figma_get_design_context` with the SwiftUI translation skills.

## Hierarchy

- `24:1591` — **Panel open (selected)**, 560 × 44 frame.
- `24:1592` — Desktop Template, dark macOS desktop, dock hidden.
- `24:1710` — Status Item Anchor (right-aligned), top 5, width 301.
- `24:1707` — Watt? Status Item, selected=true, displayed as the native
  charging symbol plus **`+42.1 W`**.

The selected pill/highlight belongs to the macOS menu-bar compositor. The
Figma desktop and menu bar are also system-owned context; Watt? must use native
status-item and popover lifecycle rather than draw a replacement capsule.

## Tokens, assets and interaction state

- Typography: `SF Pro`, Semibold, weight 590, 13 pt, 16 pt line height, zero
  tracking (`Body/Emphasized`).
- Asset: the charging glyph is an SF Symbol from the existing native label
  contract; no custom image/vector asset is present.
- Selected state: native status item is highlighted while the panel/popover is
  open and returns to unselected after dismissal.
- Content: charging reading `+42.1 W`, with the existing `PowerReadingStore`
  and router providing the source of truth.

## Verification mapping

The final-source DEBUG fixture is `C04.10/base`. Fresh capture found a real
`NSStatusBarButton` at `{{205, 15}, {96, 24}}` inside a direct 560 × 44 1×
AppKit bitmap, corresponding to Figma x205/y5/96×24. Capture lifecycle fields
prove panel shown, router presented, selected while open, panel closed, router
dismissed and unselected after close.

The selected compositor pill is not present in the app-owned subtree capture;
the implementation intentionally does not paint a fake capsule. Strict
diagnostics therefore remain non-passing and the visual gate stays open.
