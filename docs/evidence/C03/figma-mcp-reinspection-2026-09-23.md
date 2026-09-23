# C03 exact Figma MCP reinspection — 2026-09-23

Source: file `9DKDgUfEqidZdZQEVlQgLS`, node `22:1095`, retrieved with
`figma_get_design_context` using `clientLanguages=swift`,
`clientFrameworks=swiftui`, and the required `figma-design-to-code` and
`figma-swiftui` guidance.

## Frame and hierarchy

- `22:1095` — **3 · Secondary-Click Menu (Dark)**, 900 × 460.
- `22:1344` — right-aligned status-item anchor, 641 × 24 at y=5.
- `22:1345` — status-item context menu, 230 × 187.
- `22:1811` — Show in Menu Bar submenu, 190 × 141.
- `22:1345` children: native menu background, Show in Menu Bar (hovered
  submenu row), separators, Open Watt?, Settings… with Command-comma,
  About Watt?, Check for Updates…, and Quit Watt? with Command-Q.
- `22:1811` children: Delta (checked), Charger, Draw, Components, separator,
  and Icon.

## Tokens and states

- Body/Emphasized is SF Pro Semibold, 13 pt, weight 590, 16 pt line height.
- Dark menu surfaces use the macOS 27 dark component variant; AppKit owns
  material, border, separator, hover, shortcut and checkmark drawing.
- The required state is parent hovered with submenu open, Delta checked and
  no submenu row hovered.
- The Code Connect data explicitly uses native menu components and does not
  provide an app-owned image asset or custom row implementation.

The implementation maps the two component bounds to public
`NSMenu.minimumWidth` values while retaining native `NSMenuItem` rows and
system interaction semantics. No Figma-generated web code was copied.
