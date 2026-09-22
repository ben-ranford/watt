# G040 / J2.5 — implementation and bounded evidence

Exact Figma node **29:4590** in **9DKDgUfEqidZdZQEVlQgLS**.
`reference.json` pins the supplied asset URL, its actual downloaded SHA-256 and
1000×720 dimensions. The older fixture inventory export has different bytes;
this new reference is pinned independently rather than silently equating hashes.

## Implemented

- Connected Settings excerpt includes both native menu pickers, exact copy and
  neutral bordered Remove… → native destructive confirmation.
- Debug-only fixture uses injected `HelperLifecycleAdapter`, in-memory registration
  driver and authenticated identity/ping transport. No OS approval is granted.
- Shared preferences, status item, panel and context menu; safe settings/panel
  navigation; Remove→verified absence→Off and unavailable readings.
- Preference/source/freshness gates; pending, unknown, no-service, revoked,
  disconnected, late authenticated response and wrong-identity fail-closed tests.
- Existing J2.4 single-delivery/origin-isolation tests retained and passing.

## Verification (2026-09-22)

All commands used `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer`.

| Check | Result | Evidence |
|---|---|---|
| `swift test --filter 'J2[1345]\|F05Fixture'` | 61 passed | focused-tests.log |
| `swift test` | 340 executed, 1 skipped, 0 failures | full-tests.log |
| `swift build` / `swift build -c release` | passed | package-debug.log / package-release.log |
| Native Debug `build analyze` | both passed | host-debug.log |
| Native Release `build analyze` | both passed | host-release.log |
| Native `test -only-testing:WattTests -parallel-testing-enabled NO` | 328 executed, 1 skipped, 0 failures | host-tests.log |
| `git diff --check` | passed | diff-check.log |

Native commands use `xcodebuild -project Watt.xcodeproj -scheme Watt
-configuration Debug -destination 'platform=macOS' -derivedDataPath .build/j25-host`;
Release uses `.build/j25-release`. Builds typecheck Swift; Xcode analyze supplies
static analysis. No dedicated SwiftLint executable/configuration was available.
The skipped test is the opt-in physical-host public telemetry metadata probe; it is not fixture evidence.

## Capture / visual verdict

Reproduce after the Debug host build:

```sh
bash docs/evidence/J2.5/capture.sh
```

`capture.swift` verifies existing Screen Recording access, finds exactly one
app-owned Settings window by PID/title and uses window-only `screencapture`.
It never requests permissions, captures unrelated apps or changes global defaults.
`actual-settings.png` is an actual 1040×724-pixel native capture, not a recreated
mockup. `initial-dark-settings.png` records the initial too-short viewport;
final height allows native form content and bottom padding without clipping.
The launch-only Light argument was not effective; capture still follows dark
system appearance. No custom styling workaround was added.

**Blocked, no numeric score**: see `visual-ralph-verdict.json`. Native screenshot
confirms visible text, but differs in appearance/height/native titlebar metrics.
No calibrated pixel comparison or full scene/status-item capture is available.
AX trust is false (`capture.log`); native click/keyboard/VoiceOver interaction
was not audited. Unit tests prove deterministic callbacks, not live OS behavior.
Real helper registration, system approval and production composition remain
unverified. Backlog is intentionally blocked rather than visually complete.

No commit created; existing shared-worktree changes preserved.
