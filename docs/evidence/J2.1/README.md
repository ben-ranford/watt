# J2.1 — Components unavailable in menu

- Figma node: `29:1549` ([source](https://www.figma.com/design/9DKDgUfEqidZdZQEVlQgLS/Watt-?node-id=29-1549)).
- Status: **Implemented and visually verified for the native menu surfaces**.
- Native implementation: `NSMenu`/submenu with **Delta** (checked), **Charger**, **Draw**, **Components** (disabled), **Icon**, and **Turn On Helper…**. The unavailable submenu uses the Figma-native 250pt variant; available readings retain the compact 190pt variant. No custom menu rows or painted chrome were added.
- The production selection re-evaluates component availability at action time, so a capability loss while a menu is open cannot persist an invalid Components selection. Turn On Helper… routes to Settings.

## Verification

| Check | Result |
| --- | --- |
| Focused package tests | 4 pass, 0 failures |
| Debug app build | Pass |
| Native fixture capture | Pass; two app-owned `NSPopupMenuWindow` surfaces |
| Main menu bounds | 230 × 187 points, matching Figma `29:1861` |
| Readings submenu bounds | 250 × 176 points, matching Figma `29:2197` |
| Native visual review | Pass; see `visual-review.json` |
| Figma context | `current-figma-context-2026-09-24.md` |

`actual-menu.png` and `actual-readings-menu.png` are direct AppKit `NSView.cacheDisplay` captures of the live native popup windows. They are retained at the host's 2× scale; Figma's desktop wallpaper and menu bar remain OS-owned and are not redrawn by Watt. `capture.json` records the PID-owned window classes, exact frames, checked state and enabled update row.

The fixture uses an app-owned transparent anchor only to make the native menu deterministic on hosts where SwiftUI's status-bar compositor slot is unavailable. It does not replace the production status item or render a custom menu.
