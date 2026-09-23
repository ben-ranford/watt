# P01 menu-bar host evidence — 2026-09-24

The rebuilt Release app was installed at `/Users/benranford/Desktop/Watt.app`.
The telemetry probe on the same host reported:

- `BatteryPower = 0 mW`
- `SystemPowerIn = 9896 mW`
- `SystemLoad = 9896 mW`
- `CurrentCapacity = 100`
- `FullyCharged = Yes`

The live reading is therefore a valid full-battery delta of `0.0 W` and a valid
charger-input reading of `9.896 W` when the display mode is Charger.

## Native status-item compositor probe

A standalone AppKit probe using the public API
`NSStatusBar.system.statusItem(withLength:)` reproduced the app condition:

```text
NSStatusItem isVisible = true
button frame = (0, 0, 16, 22)
NSStatusBarWindow frame = (0, 0, 16, 0)
NSStatusBarWindow isVisible = true
```

The Watt Release process reported the same zero-height native status window.
`CGWindowListCopyWindowInfo` exposed only the native fallback Watt? window; no
menu-bar compositor window was exposed. The system accessibility tree likewise
contained no Watt status item. This is an OS/compositor limitation on this host,
not a telemetry read failure and not fixed by painting a replacement menu bar.

The app now schedules its public `NSStatusItem` after
`applicationDidFinishLaunching`, restores the `.accessory` activation policy,
and keeps the native full Watt? panel visible as a fallback. This is the safest
native behavior available until the host assigns a real status-bar slot.
