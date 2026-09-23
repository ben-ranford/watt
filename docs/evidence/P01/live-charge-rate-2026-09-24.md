# P01 live charge-rate verification — 2026-09-24

## Host probe

Command:

```sh
WATT_P01_HOST_PROBE=1 \
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
xcrun swift test --scratch-path /tmp/watt-g084-p01-host \
  --filter P01TelemetryTests/testPhysicalHostPublicAPISmoke
```

Result: passed on the physical host at `2026-09-24 02:49:07 +1000`.

```text
battery=full
percentage=100
batteryWatts=0.0
chargerWatts=16.301
systemWatts=16.301
source=Power source: AC
```

This is a real full-battery sample, not fixture data. `batteryWatts = 0.0 W`
is correct because the battery is full and not accepting charge. `chargerWatts`
is the live input from the connected adapter; it is not the adapter's nominal
65 W rating. `systemWatts` is the measured system draw.

## Installed app

The running Release app at `/Users/benranford/Desktop/Watt.app` uses the same
`SystemPowerSourceTelemetryService` and native `NSStatusItem` sampling path.
The live capture is retained in `live-charge-rate-2026-09-24.png`: the menu bar
shows the current charger-mode reading and the native Watt? panel shows matching
`Charger input` and `System draw` rows, with `Battery` at `0.0 W`.

The evidence proves local battery/source/charger/system telemetry and the menu
bar refresh path on this host. It does not prove unplug/wake transitions,
component telemetry on every Mac, signed helper transport, or TCC-authorized
accessibility interaction; those remain separate P01/screen gates.
