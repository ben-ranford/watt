# J1.8 exact Figma context — 2026-09-24

- File: `9DKDgUfEqidZdZQEVlQgLS`
- Frame: `28:2802` — **1.8 First open — live panel**
- Desktop template: `28:2803` (Light; Finder menu bar; dock hidden)
- Status anchor: `28:2952` (right aligned)
- Selected Watt? status item: `28:2949` (native battery symbol, `+42.1 W`)
- Native panel: `29:9338` (`Watt? Panel (MenuBarExtra .window)`)
- Power group: `29:9465`
  - Charger input — `96 W USB-C charger` — `65.0 W`
  - System draw — `22.9 W`
  - Battery — `+42.1 W`
- Components group: `29:9469`
  - CPU `9.8 W`, GPU `4.1 W`, Display `5.2 W`, Other `3.8 W`
- Native actions: `Settings…`, `Quit Watt?` (borderless action rows)
- Typography: SF Pro Semibold/13/16 for emphasized body, SF Pro Bold/13/16 for headline, SF Pro Bold/26/32 for the large value, SF Pro Regular/11/14 for the subtitle.
- Surface: native light menu-extra window material; the panel chrome, arrow, shadow, focus and button treatment remain AppKit/SwiftUI owned.

The source implementation uses `StatusPanelView` with native grouped `Form`, `Section`, `LabeledContent`, and SwiftUI `Button`s. DEBUG capture starts the same native `NSStatusItem`/`NSPopover` selection bridge directly from the app lifecycle, then anchors that real popover to a temporary native AppKit view because this host exposes the status item but does not expose its attached popover compositor surface. The anchor is not product UI.
