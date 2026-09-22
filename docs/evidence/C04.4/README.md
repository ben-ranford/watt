# G018 / C04.4 — Charger Input

Implementation and fresh verification, 2026-09-22. **Visual acceptance remains
open. No commit, checkpoint or story-completion claim.**

## Exact reference and implementation

- Figma frame **24:877**, desktop **24:878**, anchor **24:995**, native status
  component **24:993**; supplied macOS dark SF Pro Semibold 13/16 contract.
- `reference-24-877.png` is the unmodified **560×44** export from
  `.omx/plans/f00-reference-evidence/exports/24-877.png`.
  SHA-256: `5f0e7d03af3ecbdbeded1bea5a78ecaaa81dfd94c3969e177389ee3ce62d196c`.
- Component bounds: **x221,y5,80×24**, right edge x301.
- `Models/PowerReading.swift`: DEBUG `sampleChargerInput` supplies available
  **65.0 W** charger input, fixture provenance and a deterministic timestamp.
  This is not hardware telemetry or an adapter rating.
- `App/WattApp.swift`: DEBUG `C04.4` / `C04.4/base` launch in `.charger` mode
  with in-memory preferences and a pinned clock; selector rejection occurs
  before persistent stores. Capture reuses the C04.1–3 native harness.
- The production `MenuBarStatusLabel` renders unsigned **`65.0 W`**, native
  **`bolt.fill`**, accessibility value **`65.0 watts`**, and existing system
  semibold body typography. No shared formatter/style change, custom menu-bar
  chrome, reference bitmap UI, new dependency or TCC bypass was introduced.
- Registry availability is a render target, not visual acceptance. C04.5–12
  remain unimplemented.

## Native capture and comparison

From the repository root, after building Debug:

```sh
bash docs/evidence/C04.4/capture.sh
bash docs/evidence/C04.4/compare.sh
```

`capture-run.log` / `capture.json` identify C04.4/base and a real app-owned
`NSStatusBarButton`, hosted by a DEBUG NSStatusItem with MenuBarExtra suppressed.
The button is relocated into the existing deterministic dark capture host:
AppKit bottom-left **(221,15),80×24**, matching top-left **(221,5)**.

- `actual-status-item-1x.png`: direct AppKit subtree rendering into **560×44
  pixels / 560×44 points**, no resize/resampling.
- `actual-status-item.png`: separate **1120×88** screen-scale diagnostic.
- `reference-item.png` / `actual-item.png`: unresampled **80×24** crops.
- Frame and component comparisons both **FAIL**: changedFraction **1.0**,
  tolerance **0.01**, no mask, `storyDone: false`. Frame: **24,640** changed
  pixels; component: **1,920**. Diff/overlay PNGs, JSON results and
  `images.sha256` are retained. `compare.sh` accepts diagnostic exit 2 to
  retain failed comparisons; its shell success does not mean visual success.
- Direct image inspection confirms the bolt and `65.0 W` content. The native
  capture has a flat dark backdrop and differs from the reference wallpaper,
  neighboring system items and text rasterization. No visual similarity score
  or pixel-parity claim is assigned.

This bounded capture cannot prove live menu-bar compositor pixels/global
placement, AX/VoiceOver traversal, physical interaction, or TCC-authorized
screen capture. Destination bitmap dimensions do not prove internal layer
rasterization scale. Those acceptance gaps remain open; the harness is not a
substitute for live system chrome.

## Fresh verification

All commands used `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer`.

| Check | Result / retained log |
| --- | --- |
| `swift test --filter 'C04[1234]StatusItemTests'` | **16 passed**, `package-focused.log` |
| `swift test` | **224 executed, 1 skipped, 0 failures**, `package-full.log` |
| Hosted C041–C044 tests | **16 passed**, `native-focused.log` |
| Full hosted `WattTests` | **224 executed, 1 skipped, 0 failures**, `native-full.log` |
| Debug `build analyze` | **BUILD / ANALYZE SUCCEEDED**, `debug-build-analyze.log` |
| Release `build analyze` | **BUILD / ANALYZE SUCCEEDED**, `release-build-analyze.log` |
| Release binary fixture-selector scan | **PASS**, `release-isolation.log` |
| Capture/compare Bash syntax + ShellCheck | **PASS**, `static-checks.log` |

Hosted commands use `xcodebuild -project Watt.xcodeproj -scheme Watt
-configuration Debug -destination 'platform=macOS' -derivedDataPath
.build/c044-native`, with `test -only-testing:WattTests` for the full hosted
suite, or the four individual `-only-testing:WattTests/C04NStatusItemTests`
selectors (N=1–4) for focused tests. Debug build/analysis uses the same derived
data; Release uses `-configuration Release -derivedDataPath .build/c044-release`.

The skipped test is the opt-in physical-host telemetry probe. Hosted unit tests
are not the separately permission-gated `WattUITests` AX runner; that runner
was not invoked. Logged warnings include package unhandled files, AppIntents
metadata extraction and hosted UI-test linkage against newer macOS libraries.

The takeover's first test-isolation addition called nonexistent
`C041FixtureLaunch.matches`; that assertion was removed without altering
production behavior. C042/C043 use their existing `matches(arguments:)` APIs.
The fresh passing logs above supersede the initial compile failure. C044 tests
cover charger values/symbol/accessibility/pinned clock, exact selectors,
sibling/capture-flag rejection, package isolation and exact capture geometry.

Stop condition: source, regression tests, full package/hosted verification,
Debug/Release build/analysis and bounded native capture/comparison completed.
Visual acceptance remains open for the limitations and failed comparisons above.
