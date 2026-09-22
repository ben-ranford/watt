# F05 — scenario/evidence infrastructure, not story completion

2026-09-20, existing `feat/swiftui-implementation` worktree. The original infrastructure slice made no App, Features, Models,
Services or production screen edits. The bounded App-composition follow-up below
changes only WattApp, its F05 regression test and documentation; concurrent work is preserved.

## Registry and boundaries

- `Tests/Fixtures/StoryFixtureData.swift`: **69 ordered, unique story/node pairs**,
  **140 named base/variant selections**. Full F00 story records retained verbatim as
  JSON values (bounds, appearance including unknown/null, export hashes and crop caveats).
  Backlog frame/state/navigation and approved-plan acceptance text are retained.
  Seven approval scenarios have both originating scenes; notification outcomes have
  preference on/off × authorized/denied. Local maintenance failure variants remain
  attached to their existing story, never substitute frames.
- `StoryFixtures.swift`: fixed clock (1789862400 Unix seconds), stable component IDs,
  fresh value-based memory storage, scripted-outcome metadata, expected scene.
  Descriptors are not constructed production services. All 69 statuses are **not
  implemented**; `requireRenderTarget()` always fails. There is no mutable implemented
  flag or placeholder fallback. Registry membership is not implementation evidence.
- `FixtureLaunchSelection.swift`: DEBUG-only, exact `--watt-fixture ID[/variant]`
  parsing, reject unknown/malformed/duplicate selectors, separate F02 gallery IDs.
  Native app source membership is explicit; Release excludes all three fixture files
  and also has compile guards. Package test support is a separate pure target with
  no executable dependency. Scripts' entry points are not app/package members.
- **App composition handoff verified:** native Debug `WattApp.init` calls the
  selection parser before initializing any live `@StateObject`. All registered
  stories are rejected with their resolved story/variant; galleries explicitly
  require standalone GalleryHost. Invalid selectors also exit with status 1 and a
  stderr diagnostic, before scene evaluation. No placeholder or fixture store is
  constructed. Ordinary launch and legacy capture flags retain their existing path.
  The package executable has no fixture-target dependency: its DEBUG gate explicitly
  rejects fixture arguments (including their supplied IDs) instead of linking the
  native parser or starting stores. Release contains neither gate nor selection.


## Native smoke and evidence helpers

`bash scripts/F05/capture.sh NEW_OUTPUT_DIRECTORY` builds a standalone DEBUG-only
native gallery host from the existing F02 view. It bypasses WattApp entirely, so no
real preferences, telemetry, network, timers, helper, notification/login request or
TCC prompt starts. It does not create a second shipping app entry point. Existing
`scripts/capture-native-panel.swift` is reused unchanged: permission preflight,
exact PID/title/window identity and window-only capture; no desktop fallback.

`F02.gallery.light` and `F02.gallery.dark` each captured twice at **1160×1960, 2×**.
Both repeat comparisons have **0 changed pixels**, no masks. Translation by two
pixels is rejected in both appearances. Threshold **0** is calibrated for exact-repeat
smoke on this OS/host, not a Figma material-difference acceptance tolerance. Full
Figma comparisons still require approved content crops, matching scale, independent
visual review and accepted native divergence; no auto-resampling or masking defects.

`image-evidence.swift` supports bounded integer-pixel crop, same-scale/dimension
comparison, overlay/diff PNGs and JSON measurement records, plus deliberate geometry
perturbation. `check-image-helper.sh OUTPUT` checks crop/self-diff and rejects invalid
bounds, scale, dimensions and threshold. The UI scaffold provides window/status-item
only screenshot attachment; runtime AX/status-item capture is not verified. It
explicitly skips story rendering rather than passing a placeholder screenshot.

## Fresh verification

All commands used `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer` without
changing global xcode-select; native macOS destination, not iOS Simulator.

- `swift test`: **93 tests passed**, including **8 F05 tests**, zero failures.
- `xcodebuild ... -configuration Debug -destination 'platform=macOS'
  -only-testing:WattTests -only-testing:WattUITests/F05StoryRenderTests test`:
  **93 hosted tests passed**, **1 UI scaffold explicitly skipped**, zero failures.
- `swift build`: passed. Native Release `build analyze`: passed.
- Release binary `strings` scan: no `FixtureLaunchSelection`, `F02.gallery.light`,
  or `--watt-fixture` strings. This proves omission, not production behavior.
- Two separate compiled RegistryProbe runs: byte-identical canonical JSON;
  SHA-256 `8b7b2a27ad1d56d18f2ecd15b48785b4f6fc15404cd652ea41ff5e72c81d8ad3`.
- All 69 embedded full reference objects equal the F00 manifest's `stories` array.
- Four native gallery captures; two identical-repeat passes; two deliberate drift
  rejections. Six image helper checks passed. Bash syntax, ShellCheck, project plist
  validation and `git diff --check` passed.

See logs here and `native-smoke-verified/evidence.json`, `window.json`, repeat/negative
JSON and image pairs. Evidence includes dirty-tree commit provenance, OS/build,
Xcode, architecture, scale, locale, fixture IDs and PNG hashes. Rebuild binaries
with the scripts; generated executables are not retained as repository deliverables.

## Remaining gates

F05 is **partial, not closed**: fail-closed App composition is verified; status-item
capture, live keyboard/VoiceOver and deterministic normal-shell fixture rendering
remain unverified. No implemented story target exists yet. No real service/production Gate
A–E proof, D3–D7 story sign-off, or screen completion is claimed. Unimplemented
fixtures intentionally cannot render. A future story owner must supply real target,
fixture-to-F03 mapping, interactions and independent evidence before enabling it.
The reused capture helper emits SDK deprecation warnings; no TCC bypass or new
capture dependency was introduced.

## App-composition follow-up verification

All commands ran from this worktree with
`DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer`.

```sh
swift test
xcodebuild -project Watt.xcodeproj -scheme Watt -configuration Debug \
  -destination 'platform=macOS' -derivedDataPath /tmp/watt-f05-handoff-debug \
  build test -parallel-testing-enabled NO -only-testing:WattTests \
  -only-testing:WattUITests/F05StoryRenderTests
xcodebuild -project Watt.xcodeproj -scheme Watt -configuration Release \
  -destination 'platform=macOS' -derivedDataPath /tmp/watt-f05-handoff-release \
  build analyze
binary=/tmp/watt-f05-handoff-release/Build/Products/Release/Watt.app/Contents/MacOS/Watt
{ strings "$binary"; nm "$binary"; } | grep -E \
  'FixtureLaunchSelection|WattFixtureLaunchGate|ScenarioRegistry|StoryFixture|GalleryFixture|F02\.gallery\.|--watt-fixture'
git diff --check
```

- **94 package + 94 hosted tests passed**, including nine F05 tests. The new
  composition regression covers all 140 selections, both galleries, malformed
  selectors, no-selector launch and preservation of the three legacy capture flags.
- Debug build, Release build and analysis passed; the Release scan returned no
  matches (grep status 1, expected). Diff check passed. No separate linter is configured.
- Direct subprocess launches of the Debug executable with `--watt-fixture` and
  `C01`, `C01/base`, `J1.1/base`, both gallery IDs and `C01/unknown` each exited 1
  with the selected ID in stderr. Missing, equals-form and duplicate selectors also
  exited 1: nine negative launches, no crash/placeholder. Source ordering verifies
  rejection precedes store initialization and scene evaluation.
- Logs: `/tmp/f05-handoff-{package,native,release}.log`; native result bundle is
  under `/tmp/watt-f05-handoff-debug/Logs/Test/` (local, not retained deliverables).
- One UI scaffold intentionally skipped; its historical skip message still refers
  to the composition handoff, but no story target is implemented. No new visual,
  status-item, AX, network/TCC or production-service proof is claimed. Existing
  package unhandled-file and AppIntents metadata warnings remain outside this scope.
