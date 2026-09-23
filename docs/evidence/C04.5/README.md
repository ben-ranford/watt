# G019 / C04.5 — Charger Input unplugged → System Draw

Verified 2026-09-22 after the chargerInput-scoping correction. No commit or
checkpoint. Implementation verified; visual acceptance remains open.

## Contract and scope

Exact reference: frame **24:996**, component **24:1112**, anchor **24:1114**.
The supplied export is `reference-24-996.png` (560×44); component bounds are
x213,y5,88×24, right edge x301.

- `Models/PowerReading.swift`: DEBUG `sampleUnpluggedCharger` explicitly uses
  physical/presentation mode `.chargerInput`, disconnected charger, fixture
  provenance, deterministic timestamp and available System Draw **18.4 W**.
- `App/WattApp.swift`: DEBUG selectors `C04.5` / `C04.5/base` use isolated
  preferences in `.charger` display mode and a pinned clock; existing native
  status-item capture harness is reused.
- `Features/MenuBar/Components/MenuBarStatusLabel.swift`: only readings whose
  mode is `.chargerInput` opt into `.systemDrawWhenDisconnected` and the native
  `battery.100percent` glyph for disconnected charger display. Text is unsigned
  **18.4 W**, accessibility value **18.4 watts**. No custom chrome or TCC changes.
- `PowerReading.value(for: .charger)` retains its default batteryDelta policy.
  `sampleOnBattery` remains legacy **-18.4 W / bolt.fill** in charger display;
  C04.2 delta remains **−18.4 W / battery.100percent**. C03/C04.1–4 assertions
  are preserved, not rewritten to accept the regression.
- `Tests/WattTests/F05FixtureTests.swift`: C045 matrix uses `.chargerInput` for
  explicit fallback, including missing/zero draw, capabilities, freshness,
  unavailable source, stale charger rejection, selector isolation and geometry.
  `Tests/Fixtures/StoryFixtures.swift` enables the C04.5 render target only;
  registry availability does not mean story acceptance.

## Fresh final-source verification

All commands use `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer`.

| Check | Result | Log |
| --- | --- | --- |
| `swift test --filter 'C04[12345]StatusItemTests'` | 20 passed | `package-focused.log` |
| `swift test` | 228 executed, 1 skipped, 0 failures | `package-full.log` |
| Hosted C041–C045 focused tests | 20 passed | `native-focused.log` |
| Hosted full WattTests | 228 executed, 1 skipped, 0 failures | `native-full.log` |
| Debug build + analyze | both succeeded | `debug-build-analyze.log` |
| Bash syntax, ShellCheck, diff whitespace | passed | `static-checks.log` |

Hosted commands: `xcodebuild -project Watt.xcodeproj -scheme Watt
-configuration Debug -destination 'platform=macOS' -derivedDataPath
.build/c045-native`, followed by `build analyze`, `test -only-testing:WattTests`,
or `test` with each `-only-testing:WattTests/C04NStatusItemTests` (N=1–5).
The skipped test is the opt-in hardware telemetry probe. Older Release logs
predate the scoping correction and are **not final-source verification**.

## Retained capture — predates final scoping fix

`capture-run.log`, `capture.json`, PNGs and comparisons were generated during
this takeover **before** changing sample mode and adding the `.chargerInput`
UI guard. They show the intended native battery glyph and 18.4 W, but were
**not recaptured after the fix** and do not prove the final binary's pixels.
Reproduce with `bash docs/evidence/C04.5/capture.sh` then
`bash docs/evidence/C04.5/compare.sh` after a Debug build.

Existing harness captures a real app-owned `NSStatusBarButton`, relocated to
its bounded dark host: direct 560×44 bitmap, separate 1120×88 diagnostic,
no resampling. Both strict unmasked comparisons **fail** (changedFraction 1.0;
frame 24,640 pixels, item 2,112 pixels; tolerance 0.01; storyDone false).
Hashes are in `images.sha256`. Backdrop/system neighbors and rasterization
are not the Figma compositor. Capture is not live system-chrome parity,
AX/VoiceOver, physical interaction or real telemetry proof. Those gates remain
open; no visual pass or completed-story claim is made.

## Fresh final-source capture — 2026-09-23

Figma MCP was re-queried for frame `24:996`; the exact hierarchy and native
contract are recorded in `current-figma-context-2026-09-23.md`.

The final-source Debug binary was rebuilt and `capture.sh` was rerun after the
`.chargerInput` scoping correction. `capture.json` now records the final
`C04.5/base` fixture, `NSStatusBarButton`, Dark Aqua appearance, reference
node/component/anchor IDs, 560×44 direct 1× pixels, and 88×24 button geometry.
The captured item visibly contains the native battery glyph and `18.4 W`.

`compare.sh` returned diagnostic exit 2 for both frame and item comparisons,
as expected for the synthetic backdrop/native-rasterization boundary. This
refreshes the implementation evidence but does not grant visual acceptance.
