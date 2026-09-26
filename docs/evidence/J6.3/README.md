# G052 / J6.3 — on adapter, fully charged

Exact source: [Figma node 31:4355](https://www.figma.com/design/9DKDgUfEqidZdZQEVlQgLS/Watt-?node-id=31-4355).
Fresh MCP retrieval on 2026-09-23 is pinned in `fresh-figma/context-2026-09-23.md` and `fresh-figma/reference-2026-09-23.png` (SHA-256 `13696607c0ea717fd3476b8355bcdbbd1cd77c8d2f7530648ac359632bd9d813`).
The exact user-specified PNG was downloaded and inspected locally. Its SHA-256 is
`13696607c0ea717fd3476b8355bcdbbd1cd77c8d2f7530648ac359632bd9d813`, retained in
`reference.json`. The image is 1000 × 720 pixels; the dark native panel is approximately
320 × 265 points at x660/y38. Wallpaper and menu bar are system/template chrome.

## Native mapping

The existing StatusPanelModel and StatusPanelView provide the semantic full-on-adapter
state. It requires validated fresh available battery/charger/system telemetry, explicit
full state, 100%, zero battery watts, and nonnil charger/system watts. Adapter presence
alone cannot establish it. Full status snapshots expire after five seconds on access
using the store clock. Invalid updates or aged snapshots expose unavailable status,
while keeping the last reading for diagnostics. Frozen fixture clocks remain independent.
The existing system parser supplies no charger/system watt measurements and therefore
cannot claim this explanatory state. Production polling composition remains outside this story. MenuBarExtra supplies native material, border, corner
geometry and shadow. Existing semantic typography and spacing tokens remain in use.
No custom panel background, painted chrome, rounded rectangle or gradient is introduced.

The Figma reference content is:

- Full; 0.0 W; 100% · running straight off the charger.
- Charger input / 96 W USB-C charger / 19.8 W.
- System draw / 19.8 W.
- Battery / 0.0 W.
- Settings… and Quit Watt?.

The power rows use the existing grouped Form/LabeledContent mapping. Components are
absent. Native borderless footer buttons retain Settings and Quit callbacks. The
current product presentation overrides the Figma headline to measured system
draw (19.8 W in this fixture); the Battery row remains 0.0 W and the selected
native status item remains 0.0 W because this fixture explicitly selects Delta.

## Reproduction

```sh
bash docs/evidence/J6.3/verify.sh
bash docs/evidence/J6.3/capture.sh
```

`verify.sh` runs focused/full package tests, package build, Debug/Release native host
build + analyze, focused/full host WattTests, invalid selector checks, diff checks and
static checks using the installed Xcode toolchain. Logs and exit files record actual
command outcomes. Static checks cover shell/Python syntax, Swift capture-script
typecheck, JSON, exact reference digest, shared native view contracts, and Debug/Release
fixture symbol isolation. Native hosted tests do not establish live visual equivalence.

`--watt-fixture J6.3/base` selects the DEBUG-only sampleFullOnAdapter snapshot with
independent in-memory preferences/store, Components off, completed live-panel onboarding,
dark Aqua and the existing MenuBarExtra bridge. Unsupported/malformed selectors fail
closed; Release excludes the registry and sample harness. The focused suite includes
J6.1/J6.2 and their ordinary C03/C04 regression coverage.

`capture.sh` requires a fresh capture directory and captures only the launched Debug
fixture's PID-owned native panel. It terminates and reaps only that fixture process.
`capture-window.swift` records preauthorized Screen Recording and AX status, requires
unique live AX content matching the exact copy with Components absent, then matches the
AX frame to one compositor window owned by the fixture PID. Ownership and geometry are
rechecked before and after `screencapture -l`. No permissions are requested or modified.
No replacement window, desktop image, cached view or synthetic screenshot is substituted.

Absent trust, missing or ambiguous content, missing ownership, or invalid capture fails
closed. Without comparable native pixels, score and pixel diff stay null, visualPass
remains false and visual acceptance is blocked. Captured panel pixels alone remain
`captured-awaiting-review`; a panel-only image excludes the system-owned menu bar and
does not establish selected status-item appearance, live keyboard/navigation, dismissal
or VoiceOver acceptance.

## Evidence status

Final checks passed on 2026-09-23 local time (2026-09-22 UTC):

| Check | Executed | Passed | Skipped | Failures |
| --- | ---: | ---: | ---: | ---: |
| Focused package | 119 | 117 | 2 | 0 |
| Full package | 461 | 458 | 3 | 0 |
| Focused native host | 119 | 117 | 2 | 0 |
| Full native host | 449 | 446 | 3 | 0 |
| J6.3 in each runtime | 15 | 14 | 1 | 0 |

J6.2/J6.3 AX traversal skips explicitly record empty native labels; they claim no
live row accessibility pass. The remaining full-suite skip is the opt-in P01 hardware
probe. Native 320×265 geometry, dark appearance, borderless button callbacks and status
selection lifecycle pass independently.

Package build, native Debug/Release build + analyze, static and diff checks pass.
Debug contains J63FixtureLaunch/sampleFullOnAdapter/registry symbols; Release excludes
them. Five actual invalid/malformed native selectors exit 1 before composition.
Build logs retain existing onboarding actor-isolation and AppIntents metadata warnings.
The initial default CommandLineTools invocation failed to load SwiftUIMacros; its log
is retained as toolchain-initial.log. The reproducible script selects the installed
Xcode toolchain and passes. The earlier passing run before the reviewed age guard is
retained under pre-age-guard/; final logs at this directory root include the expiry
and recovery regression.

Real fixture capture exited **1**: Screen Recording is preauthorized, **AXTrusted=false**,
and zero fixture-owned compositor windows were reported. PID 99207 was terminated and
reaped. See capture/window.json, capture/process-cleanup.log and capture.exit. No screenshot
was created; **score and pixel diff are null**, visualPass is false, and story visual
acceptance is **blocked**. No permissions were changed or substitute pixels produced.
Selected status-item pixels and live keyboard/navigation, dismissal and VoiceOver
remain unverified. No commit was made; cumulative worktree changes were preserved.

## Files changed for this story

- `App/WattApp.swift`
- `Models/PowerReading.swift`
- `Services/PowerReadingStore.swift`
- `Features/MenuBar/Views/StatusPanelView.swift`
- `Features/MenuBar/Views/MenuBarRootView.swift`
- `Tests/Fixtures/StoryFixtures.swift`
- `Tests/Fixtures/StoryFixtureData.swift`
- `Tests/Fixtures/FixtureLaunchSelection.swift`
- `Tests/WattTests/F05FixtureTests.swift`
- `Tests/WattTests/J63FullOnAdapterTests.swift`
- `Watt.xcodeproj/project.pbxproj`
- `DESIGN.md`
- `SCREEN-BACKLOG.md`
- `docs/evidence/J6.3/`

Fresh native AX probe: see `fresh-figma/live-ax-2026-09-23.log`; no accepted fixture-owned panel window was observed, so visual/live gates remain open.
