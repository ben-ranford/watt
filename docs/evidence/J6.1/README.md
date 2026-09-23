# G050 / J6.1 — dark charging panel

Exact source: [Figma node 31:2745](https://www.figma.com/design/9DKDgUfEqidZdZQEVlQgLS/Watt-?node-id=31-2745).
The supplied `reference.png` remains pinned by SHA-256 in `reference.json`; fresh
Figma context, variables and a replacement screenshot were retrieved on 2026-09-23
under `fresh-figma/`. The reference
shows a selected +42.1 W status item and a dark native panel, 320 × 265
points. Desktop wallpaper, menu bar neighbors and clock belong to the system.

## Native mapping

The existing StatusPanelView, StatusPanelModel, PowerReadingStore and MenuBarRootView
provide this screen. The native MenuBarExtra `.window` supplies dark Aqua material,
border, corner geometry and shadow. Shared design tokens define content dimensions,
spacing and typography. There is no custom background, painted window chrome,
rounded rectangle, gradient or duplicate panel implementation.

Exact content:

- Charging; +42.1 W; 64% · full in about 38 min.
- Charger input / 96 W USB-C charger / 65.0 W.
- System draw / 22.9 W.
- Battery / +42.1 W.
- Settings… and Quit Watt?.

Components are hidden for this presentation. Power rows remain native grouped
Form/LabeledContent. Footer buttons remain native `.borderless` controls using the
existing Settings and Quit callbacks. Unavailable/failure states reuse model/store
semantics and never fabricate zero measurements or a charger description.

## Reproduction

```sh
bash docs/evidence/J6.1/verify.sh
bash docs/evidence/J6.1/capture.sh
```

`verify.sh` uses the installed Xcode toolchain and runs focused/full package tests,
package build, Debug and Release host build + analyze, focused/full host unit tests,
then diff and static checks. Static checks include shell/Python syntax, Swift capture
script typecheck, JSON parsing, reference digest, native view contracts and whitespace
in tracked and newly created source files. Logs and exit files record actual results.
The host unit scope is WattTests; live UI/AX interaction is a separate verification gap.

`--watt-fixture J6.1/base` launches a deterministic sampleCharging snapshot using
isolated memory preferences and dark Aqua. The existing status bridge opens the actual
MenuBarExtra panel. Unsupported variants fail closed. Fixture launch registration is
Debug-only and the package executable cannot launch a native fixture. No live helper
service or persistent user preference change is required.

`capture.sh` requires a fresh capture directory, launches the Debug host fixture, then
collects only its PID-owned native panel. It terminates and reaps only the process it
launched. The script never requests permissions or creates a replacement window.
`capture-window.swift` records actual compositor windows and preauthorized Screen
Recording/AX state, then requires a unique AX window matching charging copy and hidden
Components and a unique PID-owned compositor window matching that AX frame. Ownership
and geometry are rechecked before and after `screencapture -l`. Missing trust, missing
panel identity, changed ownership or invalid output fails closed.

No app-owned panel or AX access means no comparable native capture and null visual
score/pixel diff, blocked status and visualPass=false. Captured pixels alone remain
`captured-awaiting-review`; they do not prove pixel parity, the selected status item,
Settings/Quit live callbacks, keyboard navigation, dismissal or VoiceOver acceptance.
A panel-only capture excludes the system-owned menu bar, so the selected status item's
appearance still needs direct native acceptance evidence. No desktop or cached-view
image is substituted for this evidence.

## Evidence status

Fresh verification passed: 91 focused package tests and 91 focused host tests,
including all 8 J6.1 tests in each; 433 full package tests and 421 full host tests,
each with the existing opt-in physical-host probe skipped once. Package build,
Debug/Release build + analyze, diff and static checks passed. Actual native footer
buttons were clicked in the hosted test, independently proving Settings and Quit
callbacks. Independent review found no concrete J6.1 defect. Existing unhandled-build-
file, onboarding actor-isolation and AppIntents metadata warnings remain in the logs.

Native capture exited 1: Screen Recording was preauthorized, AX trust was false, and
no app-owned on-screen compositor windows were listed. The fixture process was
terminated and reaped. `capture/window.json` records this result; `visual-review.json`
retains blocked status, null score/pixel diff and no native image. Live selected-item,
keyboard, dismissal and VoiceOver acceptance remain unverified. No visual or D1–D7
completion is claimed.

`verification.json` records counts, exits, the resolved initial registry/backlog wording
failure, review and verification limits. This evidence slice does not mutate the
OMX goal state or claim completion. No OMX runtime state was changed or checkpointed.
Cumulative changes and the exact
reference image are preserved; the fresh evidence below is committed without changing
the J6.1 goal status.

## Fresh live native AX probe (2026-09-23 UTC)

The rebuilt `J6.1/base` fixture was launched as PID `64469` with shell Accessibility
trust returning `true`. Its native `AXMenuExtra` reported the expected charging label
(`Watt?, charging, plus 42.1 watts, menu extra.`) but was placed at `x=-1, y=1157`
with size `96.5×24`. The fixture's AX tree exposed the status item and the app menu,
but no fixture-owned AXWindow/panel appeared after the native
`router.showStatusPanel()` path. The host therefore still clips the status item before
the selected panel can be interacted with. The exact transcript is retained in
`live-ax-2026-09-23.log`; this strengthens native registration evidence only and does
not close visual, selected-item, keyboard, dismissal or VoiceOver gates.
