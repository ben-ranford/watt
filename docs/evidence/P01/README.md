# P01 — local power telemetry

Status: **local battery/charger/system telemetry and production menu-bar sampling verified**.
Component telemetry remains outside this slice; the implementation fails closed when
AppleSmartBattery does not expose the measured registry payload.

## API authority

Official Apple documentation (consulted 2026-09-20), corroborated with the installed Xcode SDK's public `IOPowerSources.h` and `IOPSKeys.h`:

- [IOPowerSources.h overview](https://developer.apple.com/documentation/iokit/iopowersources_h)
- [IOPSCopyPowerSourcesInfo](https://developer.apple.com/documentation/iokit/1523839-iopscopypowersourcesinfo)
- [IOPSCopyPowerSourcesList](https://developer.apple.com/documentation/iokit/1523856-iopscopypowersourceslist)
- [IOPSGetPowerSourceDescription](https://developer.apple.com/documentation/iokit/1523867-iopsgetpowersourcedescription)
- [IOPSGetProvidingPowerSourceType](https://developer.apple.com/documentation/iokit/iopowersources_h/1810316-iopsgetprovidingpowersourcetype)
- [Optional adapter metadata API](https://developer.apple.com/documentation/iokit/1523866-iopscopyexternalpoweradapterdeta) (not used)

Copy results use `takeRetainedValue`; Get results use `takeUnretainedValue` while the snapshot remains alive. Descriptions can omit keys. Boolean parsing requires CFBoolean, not numeric/string coercion; capacity requires finite, nonnegative integral CFNumber values, positive maximum, current <= maximum. Percentage is rounded current/max × 100. The live measurements use the host's `AppleSmartBattery` IORegistry `PowerTelemetryData` values: `BatteryPower`, `SystemPowerIn` and `SystemLoad` are converted from milliwatts to watts. Adapter rating metadata is not used as live input.

## Physical-host limits

`WATT_P01_HOST_PROBE=1` enables a real on-demand API smoke test, not a fixture.
The repeatable native-host wrapper is `scripts/probe-native-p01.sh`; it builds
with the full Xcode toolchain, stages the debug dylib required by standalone
`xctest`, and records the probe output here. The 2026-09-23 run observed a
present **full battery, 100%, AC source**, with `.system` provenance, battery rate
`0.0 W`, charger input `15.947 W` and system draw `15.947 W`. See
`physical-host-probe-2026-09-23.log`; reruns can legitimately change
percentage/state.

The host probe and installed app now prove battery presence, state, percentage,
charger input and total system draw on this Mac. Discharge/full/UPS/absent/invalid
cases remain parser-test evidence, **not physical-host transitions**. No powermetrics,
SMC, IOReport guesses, root, helpers or credentials were used. Snapshot acquisition
time is not proof of underlying sensor refresh cadence.

## Contract and tests

Twelve targeted tests cover metadata, measured charging/discharging/full rates,
state/source independence, percentage and zero-vs-missing, malformed registry
telemetry, absent/UPS/malformed descriptions, cancellation before/after provider
work, acquisition failure, validation, future/nonfinite timestamps, cached timestamp
preservation and stale/fresh store recovery. The host smoke skips unless explicitly enabled.

- `Services/SystemPowerSourceTelemetryService.swift`: public adapter, pure parser, injected clock/provider.
- `Tests/WattTests/P01TelemetryTests.swift`: focused regression/probe tests.
- `Watt.xcodeproj/project.pbxproj`: app/test source membership. Package source discovery already includes both files; no package edit needed.
- `DESIGN.md` and this evidence folder: supported scope, limitations and checks.

## Verification

Run from the repository with `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer`:

```sh
./scripts/probe-native-p01.sh
xcrun swift test --filter P01TelemetryTests
xcrun swift test
xcodebuild -project Watt.xcodeproj -scheme Watt -configuration Debug -destination 'platform=macOS' -derivedDataPath .build/p01-native build
xcodebuild -project Watt.xcodeproj -scheme Watt -configuration Debug -destination 'platform=macOS' -derivedDataPath .build/p01-native test -only-testing:WattTests -parallel-testing-enabled NO
xcodebuild -project Watt.xcodeproj -scheme Watt -configuration Release -destination 'platform=macOS' -derivedDataPath .build/p01-analyze analyze
git diff --check
```

Results on 2026-09-23: targeted **12 tests, 1 intentional host-probe skip, 0 failures**;
the opt-in physical host probe passed; the full SwiftPM suite passed with **708
executed, 5 skipped, 0 failures**; Release app build succeeded; `git diff --check`
passed. The rebuilt `/Users/benranford/Desktop/Watt.app` stayed running and its AX
status item announced `Watt?, fully charged, 0.0 watts, menu extra.` Native unit tests
are not UI/visual sign-off. Current SDK builds retain macOS 13 deployment target;
macOS 13 runtime execution was not performed. Existing compiler/AppIntents warnings
are not telemetry failures.

Toolchain caveat: native test linking warns that the installed XCTest binaries were built for macOS 14 while the target is macOS 13. Tests pass on this host; this is not proof of macOS 13 test-runtime compatibility. Xcode also reports skipped AppIntents metadata extraction and host linkd diagnostics; these do not fail the build/test. `plutil -lint Watt.xcodeproj/project.pbxproj` passes.

## 2026-09-24 live host follow-up

The current host sample reported `BatteryPower=0 mW`, `SystemPowerIn=9896 mW`,
`SystemLoad=9896 mW`, `CurrentCapacity=100`, `FullyCharged=Yes`. The merged
Release app is therefore reading valid live telemetry: Delta is `0.0 W`, while
Charger mode is `9.896 W`.

The host does not assign a visible compositor slot to public AppKit status items:
a standalone `NSStatusItem` probe and Watt both reported a visible native
`NSStatusBarWindow` with height `0`. No fake menu bar or custom status-item chrome
was added. Watt now installs after `applicationDidFinishLaunching`, explicitly
restores the native accessory policy, and leaves the native Watt? panel visible
as a fallback. See `menu-bar-host-2026-09-24.md`.

Fresh focused verification: package P01 **12 tests / 1 intentional skip / 0
failures**, hosted P01 + NativeStyling **23 tests / 1 skip / 0 failures**,
and Release build/analyze passed (`g036-release-build-analyze-2026-09-24.log`).

## 2026-09-24 live charge-rate follow-up

A fresh physical-host probe passed at 02:49:07 local time and measured a full
AC-connected battery: `batteryWatts = 0.0 W`, `chargerWatts = 16.301 W`, and
`systemWatts = 16.301 W`. The running Desktop Release app showed the same
charger/system values in its native panel and `16.3 W` in the menu bar. The
capture and exact command/output are retained in
[`live-charge-rate-2026-09-24.md`](live-charge-rate-2026-09-24.md) and
[`live-charge-rate-2026-09-24.png`](live-charge-rate-2026-09-24.png).

This strengthens local production sampling evidence but does not close the
remaining physical unplug/wake, component-capability, signed-helper, or
accessibility/compositor gates.
