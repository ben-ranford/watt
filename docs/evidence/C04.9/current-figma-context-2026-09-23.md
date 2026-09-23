# C04.9 current Figma context — 2026-09-23

Source: Figma file `9DKDgUfEqidZdZQEVlQgLS`, exact node `24:1472`, retrieved
through `figma_get_design_context` with the SwiftUI translation skills.

## Hierarchy

- `24:1472` — **No reading yet / sensor unavailable**, 560 × 44 frame.
- `24:1473` — Desktop Template, dark macOS desktop, dock hidden.
- `24:1590` — Status Item Anchor (right-aligned), top 5, width 301.
- `24:1588` — Watt? Status Item, displayed as native `bolt.fill` followed by
  **`− − W`**.

The Desktop Template and menu bar are system-owned reference context. The
application-owned surface is only the native status item.

## Tokens, assets and state

- Typography: `SF Pro`, Semibold, weight 590, 13 pt, 16 pt line height, zero
  tracking (`Body/Emphasized`).
- Asset: `bolt.fill` is an SF Symbol; no custom image/vector asset is present.
- Unavailable state: preserve the unit and show a typographic minus pair,
  `− − W`; the accessibility value is `No reading yet`.
- Component: native unselected menu-bar item with no custom background, border,
  radius, shadow, bitmap UI or painted desktop chrome.

## Verification mapping

The final-source DEBUG fixture is `C04.9/base`. The fresh native capture is an
`NSStatusBarButton` at `{{230, 15}, {71, 24}}` inside a direct 560 × 44 1×
AppKit bitmap, corresponding to Figma x230/y5/71×24. Visual inspection confirms
the bolt, two minus signs and trailing W; the native foreground is slightly
softer/grayer than the Figma raster.

Strict unmasked diagnostics remain intentionally non-passing because the
capture is a relocated native button in a bounded synthetic host, not live
Figma desktop/compositor pixels. The visual gate remains open.
