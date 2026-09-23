# P01 live sampling interval follow-up — 2026-09-24

This is a fresh capture from the verified Release build installed at
`/Users/benranford/Desktop/Watt.app` after the sampling-path correction.

## Native interaction

- App launched with `open /Users/benranford/Desktop/Watt.app`.
- A real Quartz left-click was posted to the native status-item screen point
  `(1220, 15)` by `/tmp/watt-live-click.swift`.
- WindowServer reported the Watt-owned native popover as window `22829`, layer
  `25`, bounds `346 × 291 pt` at `(1073, 31)`.
- The screenshot was captured with `screencapture -x -l 22829`.
- `native-panel.png` is `784 × 674` PNG (Retina capture), SHA-256
  `d5d83823feaa3b1679cf427b69b102990fabd5069d26086d60d15eede6509326`.

## Observed values

The native popover displayed:

- Battery: `0.0 W`
- Charger input: `11.2 W`
- System draw: `11.2 W`
- `Full`, `100% · running straight off the charger`

These values are from the live public-AppKit status-item/popup path, not a
fixture or a custom-rendered status-bar surface. The battery delta is correctly
zero at full charge; charger input and system draw remain independently visible.

## Related verification

- Physical host API probe: full battery `0.0 W`, charger input `11.231 W`, system
draw `11.231 W`.
- AX probe immediately after launch: native status item with a live Watt? value
  (`27.5 W` at that sample).
- Full SwiftPM suite: `713` tests, `5` skipped, `0` failures.
- Universal Release build: succeeded.
