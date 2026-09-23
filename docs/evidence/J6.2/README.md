# G051 / J6.2 — on adapter, charging on hold

Exact source: [Figma node 31:3754](https://www.figma.com/design/9DKDgUfEqidZdZQEVlQgLS/Watt-?node-id=31-3754).
Fresh MCP retrieval on 2026-09-23 is pinned in `fresh-figma/context-2026-09-23.md` and `fresh-figma/reference-2026-09-23.png` (SHA-256 `3d61ebe2a14f409192352f4d3e52edd26cd07d0d5da6437496a438961ce87ce9`).
The exact user-specified PNG was downloaded before implementation, inspected locally,
and pinned by SHA-256 in `reference.json`. The image is 1000 × 720 pixels; the dark
native panel is approximately 320 × 279 points at x660/y38. Desktop wallpaper,
menu bar neighbors and clock are system/template chrome.

## Native mapping

The existing StatusPanelModel and StatusPanelView provide a semantic charging-hold
state using explicit Optimised Battery Charging provenance and fresh, valid, available
telemetry. Missing provenance, unavailable/failure readings and invalid values must
not fabricate this state. MenuBarExtra supplies native material, border, corner geometry
and shadow. Shared tokens provide typography and spacing; no custom panel background,
painted chrome, rounded rectangle or gradient is introduced.

Exact content:

- Holding at 80%; 0.0 W.
- Because Optimised Battery Charging is on. Charging resumes before you usually unplug.
- Charger input / 96 W USB-C charger / 21.4 W.
- System draw / 21.4 W.
- Battery / 0.0 W.
- Settings… and Quit Watt?.

The three power rows use the existing grouped Form/LabeledContent mapping. Components
are absent. Native borderless footer buttons retain the existing Settings and Quit
callbacks. The selected status item displays the battery glyph and 0.0 W.

## Reproduction

```sh
bash docs/evidence/J6.2/verify.sh
bash docs/evidence/J6.2/capture.sh
```

`verify.sh` runs focused/full package tests, package build, Debug/Release native host
build + analyze, focused/full host WattTests, diff checks and static checks using the
installed Xcode toolchain. Its logs and exit files record actual command outcomes.
Static checks include shell/Python syntax, Swift capture-script typecheck, JSON parsing,
reference digest and shared native view/fixture contracts. Live UI/AX interaction is a
separate verification gap and is not represented by hosted unit tests.

`--watt-fixture J6.2/base` launches the debug-only deterministic sampleChargingHold
snapshot with isolated memory preferences and dark Aqua. The existing native status
bridge opens the MenuBarExtra. Unsupported variants fail closed. Release builds exclude
the fixture harness; the package executable cannot launch native fixtures.

`capture.sh` requires a fresh capture directory and captures only the launched Debug
fixture's PID-owned native panel. The script terminates and reaps only that fixture
process. `capture-window.swift` records preauthorized Screen Recording and AX status,
requires unique AX content matching the hold copy with Components absent, then matches
that AX frame to one compositor window owned by the fixture PID. Ownership and geometry
are rechecked before and after `screencapture -l`. No permissions are requested or
modified. No replacement window, desktop image, cached view or synthetic screenshot
is substituted.

Absent trust, missing or ambiguous live content, missing ownership, or invalid capture
fails closed. Without comparable native pixels, visual score and pixel diff stay null,
visualPass remains false, and story visual acceptance is blocked. Captured panel pixels
alone remain `captured-awaiting-review`; a panel-only image excludes the system-owned
menu bar and does not prove selected status-item appearance, live keyboard/navigation,
dismissal or VoiceOver acceptance.

## Evidence status

Automated checks passed on 2026-09-22 UTC:

| Check | Executed | Passed | Skipped | Failures |
| --- | ---: | ---: | ---: | ---: |
| Focused package | 104 | 103 | 1 | 0 |
| Full package | 446 | 444 | 2 | 0 |
| Focused native host | 104 | 103 | 1 | 0 |
| Full native host | 434 | 432 | 2 | 0 |
| J6.2 in each runtime | 13 | 12 | 1 | 0 |

The J6.2 skip records empty in-process native AX labels; live row accessibility remains
unverified. The other full-suite skip is the opt-in P01 hardware probe. Native geometry,
dark appearance, selected-button lifecycle and real NSButton callbacks pass independently.
The initial AX assertion failure is retained in `focused-tests-initial.log`; the final
suite separates this unsupported AX inspection from the passing hosted control checks.

Package build, native Debug/Release build + analyze, static and diff checks pass. Binary
checks verify J6.2 fixture symbols are present in Debug and absent from Release.
Two actual native invalid/malformed fixture launches exit 1 as expected before composition
(`fixture-rejection.log`). Build logs retain existing onboarding actor-isolation and
AppIntents metadata warnings. The existing system telemetry parser still requires an
authoritative source for the optimised hold reason; no inference was added.

Real native fixture capture exits **1**: Screen Recording is preauthorized, **AXTrusted=false**,
and the compositor reports no fixture-owned on-screen windows. The launched PID was
terminated and reaped. See `capture/window.json`, `capture.exit` and capture logs.
No screenshot exists for comparison; visual score/pixel diff are **null**, visualPass is
false, and story visual acceptance remains **blocked**. No permissions were modified.
Selected status-item pixels and live keyboard/navigation, dismissal and VoiceOver remain
unverified.

A fresh native AX probe on 2026-09-23 is retained at
`fresh-figma/live-ax-2026-09-23.log`: shell trust was `true`; the real fixture
registered `Watt?, charging paused, 0.0 watts, menu extra.` at native frame
`x=-1, y=1157, width=82.5, height=24` on the 1800 × 1169 display. The existing
normal app window was the only Watt-owned compositor window observed; no fixture-owned
panel window was accepted. The fixture was terminated and reaped.

No commit was made before this refresh; prior cumulative changes remain in the worktree.

## Files changed for this story

- `App/WattApp.swift`
- `Models/PowerReading.swift`
- `Services/PowerReadingStore.swift`
- `Features/MenuBar/Views/StatusPanelView.swift`
- `Features/MenuBar/Views/MenuBarRootView.swift`
- `Features/MenuBar/Components/MenuBarStatusLabel.swift`
- `DesignSystem/Theme/WattSpacing.swift`
- `Tests/Fixtures/StoryFixtures.swift`
- `Tests/Fixtures/StoryFixtureData.swift`
- `Tests/Fixtures/FixtureLaunchSelection.swift`
- `Tests/WattTests/F05FixtureTests.swift`
- `Tests/WattTests/J62ChargingHoldTests.swift`
- `Watt.xcodeproj/project.pbxproj`
- `DESIGN.md`
- `SCREEN-BACKLOG.md`
- `docs/evidence/J6.2/`
