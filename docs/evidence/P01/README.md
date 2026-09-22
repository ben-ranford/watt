# P01 — public power-source subset

Status: **supported metadata subset complete; full P01 blocked by DEC-05**.
No production composition/store wiring, screen, helper or update changes. Existing worktree changes outside this slice are not claimed.

## API authority

Official Apple documentation (consulted 2026-09-20), corroborated with the installed Xcode SDK's public `IOPowerSources.h` and `IOPSKeys.h`:

- [IOPowerSources.h overview](https://developer.apple.com/documentation/iokit/iopowersources_h)
- [IOPSCopyPowerSourcesInfo](https://developer.apple.com/documentation/iokit/1523839-iopscopypowersourcesinfo)
- [IOPSCopyPowerSourcesList](https://developer.apple.com/documentation/iokit/1523856-iopscopypowersourceslist)
- [IOPSGetPowerSourceDescription](https://developer.apple.com/documentation/iokit/1523867-iopsgetpowersourcedescription)
- [IOPSGetProvidingPowerSourceType](https://developer.apple.com/documentation/iokit/iopowersources_h/1810316-iopsgetprovidingpowersourcetype)
- [Optional adapter metadata API](https://developer.apple.com/documentation/iokit/1523866-iopscopyexternalpoweradapterdeta) (not used)

Copy results use `takeRetainedValue`; Get results use `takeUnretainedValue` while the snapshot remains alive. Descriptions can omit keys. Boolean parsing requires CFBoolean, not numeric/string coercion; capacity requires finite, nonnegative integral CFNumber values, positive maximum, current <= maximum. Percentage is rounded current/max × 100. No private keys or electrical measurement derivation.

## Physical-host limits

`WATT_P01_HOST_PROBE=1` enables a real on-demand API smoke test, not a fixture. The final recorded run observed a present **charging battery, 92%, AC source**, with `.system` provenance and nil watts. See `targeted-tests.log` for the latest observation timestamp and values; reruns can legitimately change percentage/state.

This host/API probe can prove battery presence, charging state, percentage, supplying source and (if separately queried) optional adapter metadata only. Adapter metadata was not queried in this implementation. It cannot prove live charger-input watts, total system draw or per-component power; ratings are not measured input. No powermetrics, SMC, IOReport guesses, root, helpers or credentials were used. Discharge/full/UPS/absent/invalid cases are parser-test evidence, **not physical-host transitions**. Snapshot acquisition time is not proof of underlying sensor refresh cadence.

## Contract and tests

Eight targeted tests cover metadata, state/source independence, percentage and zero-vs-missing, unsupported watts/capabilities, absent/UPS/malformed descriptions, cancellation before/after provider work, acquisition failure, F03 validation, future/nonfinite timestamps, cached timestamp preservation and stale/fresh store recovery. The host smoke skips unless explicitly enabled.

- `Services/SystemPowerSourceTelemetryService.swift`: public adapter, pure parser, injected clock/provider.
- `Tests/WattTests/P01TelemetryTests.swift`: focused regression/probe tests.
- `Watt.xcodeproj/project.pbxproj`: app/test source membership. Package source discovery already includes both files; no package edit needed.
- `DESIGN.md` and this evidence folder: supported scope, limitations and checks.

## Verification

Run from the assigned worktree with `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer`:

```sh
WATT_P01_HOST_PROBE=1 xcrun swift test --filter P01TelemetryTests
xcrun swift test
xcodebuild -project Watt.xcodeproj -scheme Watt -configuration Debug -destination 'platform=macOS' -derivedDataPath .build/p01-native build
xcodebuild -project Watt.xcodeproj -scheme Watt -configuration Debug -destination 'platform=macOS' -derivedDataPath .build/p01-native test -only-testing:WattTests -parallel-testing-enabled NO
xcodebuild -project Watt.xcodeproj -scheme Watt -configuration Release -destination 'platform=macOS' -derivedDataPath .build/p01-analyze analyze
git diff --check
```

Results: targeted **8 passed** (including physical probe); package and native hosted unit suites **102 tests, 1 intentional host-probe skip, 0 failures** each; Debug build and Release analyze succeeded; diff whitespace check passed. Logs alongside this file. Native unit tests are not UI/visual sign-off. Current SDK builds retain macOS 13 deployment target; macOS 13 runtime execution was not performed. Existing package unhandled-build-artifact and Xcode build warnings, if present in logs, are not telemetry failures. No dedicated repository Swift lint configuration is present; compiler diagnostics, analyzer and whitespace checks provide the scoped static checks.

Toolchain caveat: native test linking warns that the installed XCTest binaries were built for macOS 14 while the target is macOS 13. Tests pass on this host; this is not proof of macOS 13 test-runtime compatibility. Xcode also reports skipped AppIntents metadata extraction and host linkd diagnostics; these do not fail the build/test. `plutil -lint Watt.xcodeproj/project.pbxproj` passes.
