# P01 live charge-rate verification — 2026-09-23

The rebuilt Release app was installed at `/Users/benranford/Desktop/Watt.app`
and remained running as PID `13446`.

## Host source

```text
pmset -g batt
Now drawing from 'AC Power'
 -InternalBattery-0 (id=36438115)  100%; charged; 0:00 remaining present: true

AppleSmartBattery PowerTelemetryData
SystemPowerIn = 12525 mW
SystemLoad = 12525 mW
BatteryPower = 0 mW
CurrentCapacity = 100
FullyCharged = Yes
```

The service maps that snapshot to a full battery with a real `0.0 W` battery
rate, `12.525 W` live charger input and `12.525 W` system draw. The earlier
opt-in XCTest host probe recorded `15.947 W` for the same fields; the values
change as the host load changes.

## Menu-bar result

The read-only Accessibility probe reported:

```text
trusted=true
role=AXMenuBarItem title="0.0 W"
desc="Watt?, fully charged, 0.0 watts, menu extra."
```

This confirms the visible fallback status item is reading the live store rather
than retaining the previous `—`/no-reading state. No Apple ID, helper approval,
VM login or external credentials were used.
