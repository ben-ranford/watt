# P01 live native panel — 2026-09-24

This is a real Release-app capture from `/Users/benranford/Desktop/Watt.app`,
not a fixture or an app-owned test window.

## Interaction and window evidence

- The installed process was running from the Desktop bundle.
- A native Quartz left-click was posted to the AX-discovered status item at
  screen point `(1220, 15)`.
- `CGWindowListCopyWindowInfo(.optionOnScreenOnly, .excludeDesktopElements)`
  reported the Watt-owned popup as window `22673`, layer `25`, bounds
  `(1075,31,346,291)` points.
- `screencapture -x -o -l 22673` captured `native-panel.png` at 692×582 pixels
  (2× scale); SHA-256:
  `ebdb9cc0ee48ac04aacf58e728b0386015b29e97bc3820c3f4f494465faf6bc9`.

## Live values

The rendered native panel showed:

- Battery state: `Full`
- Battery delta: `0.0 W`
- Charger input: `8.0 W`
- System draw: `8.0 W`
- Battery: `0.0 W`

The value is expected to vary between samples. A preceding AX probe read the
same status item as `14.6 W`, proving the menu-bar value is a live sample rather
than a frozen fixture. At 100% battery, battery charge acceptance remains
correctly `0.0 W`; charger input is the separate adapter/system measurement.

The capture proves the native status item → native popover path and live
charger/system rows on this host. It does not prove unplug/wake transitions,
component telemetry on every Mac, signed helper transport, or accessibility
trust; those remain open P01/story gates.
