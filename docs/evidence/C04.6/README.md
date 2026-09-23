# G020 / C04.6 — Desktop System Draw

Final-source verification, 2026-09-22. Implementation and deterministic native
capture verified; visual acceptance remains open. No commit or checkpoint.

## Exact contract and bounded changes

Figma file `9DKDgUfEqidZdZQEVlQgLS`: frame **24:1115**, desktop **24:1116**,
anchor **24:1233**, status component **24:1231**. Live MCP design context confirmed
`􀋦 38.2 W`, native dark item, SF Pro Semibold 13/16; anchor metadata confirmed
component bounds **x221,y5,80×24**, right edge x301. Existing native
`WattTypography.bodyEmphasized` and `MenuBarStatusLabel` are reused unchanged.
The reference is copied byte-for-byte from
`.omx/plans/f00-reference-evidence/exports/24-1115.png` (560×44), SHA-256
`26a6afb368236f903a764306fb73661fcb9d904dceb3a825924287a2997c97c8`.

- `Models/PowerReading.swift`: DEBUG `sampleDesktopSystemDraw`, `.systemDraw`,
  `.noBattery`, battery unsupported, systemDraw available, systemWatts 38.2;
  battery watts/percentage and charger watts absent; fixed timestamp and fixture source.
- `App/WattApp.swift`: isolated `C04.6` / `C04.6/base`, pinned store clock,
  in-memory preferences with `.draw`, completed onboarding and symbol enabled.
  Existing app-owned NSStatusItem capture path extended only for this fixture.
- `Tests/Fixtures/StoryFixtures.swift`: C04.6 render target enabled; C04.7–12
  remain unimplemented. Registry availability does not signify visual acceptance.
- `Tests/WattTests/F05FixtureTests.swift`: deterministic no-battery model,
  `bolt.fill`, unsigned `38.2 W`, accessibility value `38.2 watts`, symbol toggle,
  selector/capture isolation and exact capture geometry. Existing C04.1–5
  behavior assertions preserved; pending-story ranges now start at C04.7.
- `docs/evidence/C04.6/` and `DESIGN.md`: scoped evidence and decision record.

No production formatter/style changes, custom chrome, bitmap UI, TCC changes,
new dependencies, telemetry calls or modifications to other story evidence.

## Fresh checks

All Swift/Xcode commands use
`DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer`.

| Check | Result | Log |
| --- | --- | --- |
| `swift test --filter 'C04[123456]StatusItemTests'` | 23 passed | `package-focused.log` |
| `swift test` | 231 executed, 1 skipped, 0 failures | `package-full.log` |
| Hosted C041–C046 focused | 23 passed | `native-focused.log` |
| Hosted full WattTests | 231 executed, 1 skipped, 0 failures | `native-full.log` |
| Debug build + analyze | both succeeded | `debug-build-analyze.log` |
| Release build + analyze | both succeeded | `release-build-analyze.log` |
| Bash syntax, ShellCheck, diff whitespace | passed | `static-checks.log` |

Hosted command prefix: `xcodebuild -project Watt.xcodeproj -scheme Watt
-configuration Debug -destination 'platform=macOS' -derivedDataPath .build/c046-native`.
Append `test -only-testing:WattTests` for full tests, or `test` with individual
`-only-testing:WattTests/C04NStatusItemTests` for N=1–6. Builds append `build analyze`;
Release uses `-configuration Release -derivedDataPath .build/c046-release`.
The skipped test is the opt-in hardware probe. Build warnings note skipped
AppIntents metadata extraction because there is no AppIntents dependency.

## Final-source capture and truthful comparison

Reproduce after Debug build: `bash docs/evidence/C04.6/capture.sh`, then
`bash docs/evidence/C04.6/compare.sh`. Logs, capture metadata, raw PNGs, crops,
diff/overlay images and SHA-256 hashes are retained here. Capture uses an actual
app-owned **NSStatusBarButton**, hosting the existing SwiftUI label, relocated
into the existing synthetic dark bounded host. `actual-status-item-1x.png` is a
direct **560×44** AppKit draw (no resampling); `actual-status-item.png` is a
separate **1120×88** screen-scale diagnostic. Inspection shows bolt + `38.2 W`.
AppKit bottom-origin button y15 corresponds to reference top-origin y5.

Both strict unmasked comparisons **fail** at tolerance 0.01:
- Frame: **24,638 / 24,640** pixels changed (fraction 0.9999188312).
- App-owned item: **1,918 / 1,920** pixels changed (fraction 0.9989583333).
- Both reports retain `pass: false`, `storyDone: false`.

The bounded backdrop is not the Figma desktop/compositor, and native text/glyph
rasterization differs. This is not live system-chrome parity, real telemetry,
AX/VoiceOver traversal or physical interaction proof. Those acceptance gates
remain open; no visual-pass or completed-story claim is made.

## Fresh final-source capture — 2026-09-23

Figma MCP was re-queried for frame `24:1115`; the exact hierarchy and native
contract are recorded in `current-figma-context-2026-09-23.md`.

The final-source Debug binary was rebuilt and `capture.sh` was rerun. The
resulting metadata records C04.6/base, the native `NSStatusBarButton`, Dark Aqua,
reference IDs, 80×24 button geometry, and a direct 560×44 1× bitmap. The capture
visibly contains the native bolt and `38.2 W`. `compare.sh` returned diagnostic
exit 2 for both comparisons, so the evidence is refreshed but visual acceptance
is not granted.
