# C05 / Settings Window (Light) — current Figma context

Source: Figma file `9DKDgUfEqidZdZQEVlQgLS`, retrieved through Figma MCP on
2026-09-23 with `nodeId=25:787`, `clientLanguages=swift`,
`clientFrameworks=swiftui`, and the `figma-design-to-code,figma-swiftui`
skills.

## Frame and hierarchy

- Frame `25:787`: **5 · Settings Window (Light)**.
- Desktop template `25:788`: Light appearance, dock hidden, Watt? in the menu
  bar.
- Settings window `25:1102`: **Watt? Settings**, native titlebar, 580 × 870.
- Content area `25:1129`: 580 × 839 below the 31-point titlebar.
- Menu Bar form `25:1501`: Show / Delta, Show symbol / On, Precision / 42.1 W,
  Components / CPU, GPU and its explanatory subtitle.
- Readings form `25:1751`: Update / Every 2 seconds and Smooth readings / On
  with explanatory subtitles.
- Component-readings form `25:1994`: Status / On and Helper / Remove… with the
  local-only subtitle.
- Notifications form `25:2243`: Charger can’t keep up / On and Fully charged /
  Off.
- General form `25:2492`: Open at login / On, Check for updates automatically /
  On, Uninstall Watt? / Uninstall…, and Version / 1.0 (1).

The retrieved hierarchy names the third section **Component Readings** while
the supplied frame screenshot visually labels that section **Helper**. The
implementation retains the hierarchy-backed section name and the Helper row;
this source discrepancy is recorded rather than silently changing copy based
on raster inspection.

## Native contract and tokens

- Use grouped native SwiftUI `Form` / `Section` with system `Picker`, `Toggle`,
  `LabeledContent`, and bordered/destructive `Button` controls.
- Light Aqua/system appearance owns the window material, row backgrounds,
  switch rendering, menu indicators, titlebar and typography.
- Body emphasized: SF Pro Semibold, 13/16, weight 590.
- Headline regular: SF Pro Bold, 13/16, weight 700.
- Footnote regular: SF Pro Regular, 10/13, weight 400.
- Reference form row height is 42; section heading/row gaps are compact Figma
  values. These are reference measurements, not permission to replace native
  system metrics with painted rows or custom controls.

## Verification mapping

The native implementation maps the five forms to `SettingsRootView` and
`SettingsHelperRows`. The DEBUG `C05/base` fixture uses fresh in-memory
preferences, fixed sample telemetry and Aqua. Fresh verification on macOS 27
(Build 26A428) produced a 580 × 1000 app-owned native-form capture. It is
byte-identical to a second independent capture. The Figma content reference is
580 × 839, so visual parity is intentionally **not** claimed: native grouped
Form spacing is taller and titlebar/compositor pixels are outside the app-owned
capture. No custom compact spacing or painted chrome was introduced.
