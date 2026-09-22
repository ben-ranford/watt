# G027 / C05 — native Settings, light

## Changes
- `Features/Settings/Views/SettingsRootView.swift`: full native Form/Section, Picker, Toggle, LabeledContent and bordered/destructive buttons, replacing the shell. All requested labels, subtitles and base values.
- `Models/WattPreferences.swift`: persistent precision with migration default for older stored data.
- `Models/PowerReading.swift`, `Features/MenuBar/Components/MenuBarStatusLabel.swift`: precision updates menu-bar readings; default decimal behavior preserved.
- `App/AppRouter.swift`: injectable removal action that fails conservatively without installed service composition; native confirmation/cancel.
- `App/WattApp.swift`: DEBUG C05/base in-memory fixture, fixed preview telemetry, titled Aqua window, deterministic content capture.
- `Tests/Fixtures/{StoryFixtures,FixtureLaunchSelection}.swift`: C05/base render target; non-base variants fail closed.
- `Tests/WattTests/{F05FixtureTests,NativeStylingTests}.swift`: six C05 tests and updated native-control/shell assertions.
- `scripts/C05/capture.sh`, `DESIGN.md`, this evidence directory.

## Exact reference and capture
Figma file **9DKDgUfEqidZdZQEVlQgLS**, frame **25:787**, settings **25:1102**, content **25:1129**, rows **25:1501 / 1751 / 1994 / 2243 / 2492**.
`figma-context.json` is retrieved context; `reference-25-787.png` is its unmodified screenshot. `reference-geometry.json` records component metadata: 580×870 window, 31-point titlebar, 580×839 content.

`actual-content.png` captures the app-owned native form at 580×1000, 1×. All five sections, Uninstall and Version are visible. Native Form spacing differs from Figma: **no pixel-parity claim**. A taller capture retains system spacing instead of painting compact rows. Runtime supports a shorter, scrolling viewport. No wallpaper, system menu bar or titlebar is painted; capture excludes native titlebar chrome.

## Reproduce
```sh
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
swift test --scratch-path .build/c05-package --filter C05SettingsTests
swift test --scratch-path .build/c05-package
xcodebuild -project Watt.xcodeproj -scheme Watt -configuration Debug -destination 'platform=macOS' -derivedDataPath .build/c05-native build analyze
scripts/C05/capture.sh /tmp/c05-fresh
xcodebuild -project Watt.xcodeproj -scheme Watt -configuration Release -destination 'platform=macOS' -derivedDataPath .build/c05-release build analyze
```

## Verification
- Focused C05: **6 passed**. Native styling: **6 passed**.
- Full package: **256 tests, 1 skipped, 0 failures**.
- Debug and Release: **BUILD SUCCEEDED; ANALYZE SUCCEEDED**.
- Static: native-only source contract, shell syntax and `git diff --check` passed.
- Two independent C05/base launches: byte-identical PNGs (`repeatability.json`).
- Hosted XCTest: **blocked** by failure to load test bundle into Watt; run interrupted and stalled process stopped. Not a passing test.
- Initial CommandLineTools invocation failed on missing SDK SwiftUI macro plugin. Explicit Xcode selection resolved compilation; no gallery code was changed.

## Remaining boundaries
Controls persist desired preferences. This work does not claim OS login registration, notification authorization/delivery, automatic update scheduling or real helper/uninstall effects. Existing service adapters are not connected to app composition; removal reports unverified outcome rather than fabricated success. Helper status derives from reading capabilities plus the component preference, not a new monitor. Non-base C05 journeys remain unimplemented. No AX/VoiceOver audit or Figma pixel-match approval. No commit/checkpoint.
