# J2.2 current Figma context — 2026-09-24

Source: Figma MCP `get_design_context`, file `9DKDgUfEqidZdZQEVlQgLS`, node `29:2456`,
qualified with `figma-design-to-code,figma-swiftui`.

- Frame: `29:2456`, **2.2 Panel — component readings off**.
- Panel: `29:7572`, native MenuBarExtra `.window`, 320×347 points.
- Status anchor: `29:2606`; status item: `29:2603`.
- State: Charging / +42.1 W / 64% · full in about 38 min.
- Power rows: Charger input 65.0 W, System draw 22.9 W, Battery +42.1 W.
- Components: Off; helper explanation; native bordered Turn On… button.
- Footer: native borderless Settings… and Quit Watt? buttons.
- Typography: SF Pro semantic Body/Emphasized 13/16, Headline/Regular 13/16,
  Large Title/Emphasized 26/32, Subheadline/Regular 11/14.
- Native grouped Form/Section/LabeledContent and OS-owned popover material/chrome.

The current implementation uses the production `StatusPanelView` and `C0410PanelSelection`
NSPopover. A DEBUG-only native AppKit anchor starts the same popover directly because this
macOS 27 host does not expose a visible third-party status-bar compositor slot. The anchor
is not part of production UI and no replacement menu bar is drawn.
