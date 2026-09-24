# G086 live measurement freshness — 2026-09-24

## Fix

`PowerReadingStore.runSampling` now caps a requested five-second sampling delay
at 4.5 seconds. The status item expires readings after five seconds, so polling
at the exact expiry boundary could briefly replace a valid live value with
`No reading` when the main run loop was delayed. Shorter preferences are
unchanged; invalid intervals still use the three-second retry interval.

The native menu-bar label also now applies the explicit Charger-mode fallback
to a fresh live unplugged sample: when charger input is disconnected, it shows
the measured system draw instead of the signed battery delta. Existing fixture
and legacy contracts remain unchanged.

## Verification

- Focused regression: `49` selected tests, `0` failures, `1` opt-in skip.
- Full SwiftPM suite after both fixes: **715 tests, 5 skipped, 0 failures**.
- Release `xcodebuild build analyze`: **BUILD SUCCEEDED**, **ANALYZE SUCCEEDED**.
- Rebuilt release installed at `/Users/benranford/Desktop/Watt.app`.
- With the installed app set to `Every 5 seconds`, a 14-sample live run kept a
  native AX status-item value present while raw `AppleSmartBattery`
  `SystemPowerIn` remained available (`17.541 W`, later `18.231 W`).
- Stored user preferences were restored after the live run.

This verifies the local refresh/freshness path. It does not claim battery charge
acceptance while the host is already full: on this host `BatteryPower = 0 mW`
is correct, while `SystemPowerIn` is the charger-input measurement.
