# C04.7 current Figma context — 2026-09-23

Source: Figma file `9DKDgUfEqidZdZQEVlQgLS`, exact node `24:1234`, retrieved
through `figma_get_design_context` with the SwiftUI translation skills.

## Hierarchy

- `24:1234` — **Per Component (max 2)**, the 560 × 44 reference frame.
- `24:1235` — Desktop Template, dark macOS desktop, dock hidden.
- `24:1352` — Status Item Anchor (right-aligned), top 5, width 301.
- `24:1350` — Watt? Status Item, inside the anchor, displayed as
  **`CPU 9.8 · GPU 4.1 W`**.

The Figma context uses the native macOS 27 Desktop Template and a dark menu
bar. The anchor is an alignment container, not application-owned desktop
chrome; the implementation must keep the status item native.

## Tokens and component contract

- Typography: `SF Pro`, Semibold, weight 590, 13 pt, 16 pt line height, zero
  tracking (`Body/Emphasized`).
- Status item: native selected=false menu-bar item; no custom background,
  border, radius, shadow or bitmap icon.
- Content: two ordered component readings, one shared trailing `W` unit;
  maximum two distinct nonblank component identifiers.
- Native implementation: `MenuBarStatusLabel` plus the existing
  `NSStatusItem`/`NSStatusBarButton` host and `PowerReadingStore` formatting.

No image or non-SF asset is present in this frame. The status item text is the
only application-owned visual content; the desktop, menu bar and system
surface remain system-owned.

## Verification mapping

The final-source DEBUG fixture is `C04.7/base`. The captured native button is
an `NSStatusBarButton` at `{{153, 15}, {148, 24}}` inside a direct 560 × 44
1× AppKit bitmap. The current capture proves the native label and geometry, but
uses a bounded synthetic dark host rather than live compositor pixels.

The fresh image review compares `actual-item.png` with `reference-item.png`:
the native text, weight, spacing and content are visibly aligned. The strict
unmasked pixel diagnostics remain intentionally non-passing because the
synthetic host and native rasterization differ from the Figma desktop render.
This is retained as a visual-verification blocker, not converted into a
completion claim.
