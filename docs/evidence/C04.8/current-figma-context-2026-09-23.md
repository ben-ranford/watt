# C04.8 current Figma context — 2026-09-23

Source: Figma file `9DKDgUfEqidZdZQEVlQgLS`, exact node `24:1353`, retrieved
through `figma_get_design_context` with the SwiftUI translation skills.

## Hierarchy

- `24:1353` — **Icon Only (notch / crowded menu bar)**, 560 × 44 frame.
- `24:1354` — Desktop Template, dark macOS desktop, dock hidden.
- `24:1471` — Status Item Anchor (right-aligned), top 5, width 301.
- `24:1469` — Watt? Status Item, displayed as the native SF Symbol name
  **`battery.100percent.bolt`**, with no text.

The frame uses the native dark macOS 27 desktop/menu-bar context. The desktop,
menu bar and notch/crowding are system-owned reference context; Watt? owns only
the status item.

## Tokens, assets and states

- Typography contract: `SF Pro`, Semibold, weight 590, 13 pt, 16 pt line
  height, zero tracking (`Body/Emphasized`). There is no text in this state.
- Asset: `battery.100percent.bolt` is an SF Symbol; no downloaded image or
  custom vector asset is present.
- Component: native unselected menu-bar item, no custom background, border,
  radius, shadow or painted chrome.
- DEBUG state: available charging sample, fixed timestamp, isolated preferences,
  `.iconOnly` display mode. Accessibility remains `Watt? power reading` /
  `Icon only`.

## Verification mapping

The final-source DEBUG fixture is `C04.8/base`. The captured native button is
an `NSStatusBarButton` at `{{260, 15}, {41, 24}}` inside a direct 560 × 44
1× AppKit bitmap, matching the reference crop x260/y5/41×24 after coordinate
translation. The fresh visual inspection confirms an icon-only native symbol;
the actual is slightly softer/grayer than the Figma raster.

Strict unmasked pixel diagnostics remain intentionally non-passing because the
capture uses a bounded synthetic host and native AppKit rasterization rather
than live Figma desktop/compositor pixels. This remains a visual-verification
blocker, not a completion claim.
