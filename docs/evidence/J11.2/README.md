# G079 / J11.2 — Settings control labels and keyboard

Source of truth: Figma file `9DKDgUfEqidZdZQEVlQgLS`, node `36:5186`,
frame `1512 × 982`. Exact raw MCP responses are preserved alongside normalized
JSON evidence. `reference.png` is the user-supplied `1024 × 666` screenshot asset;
`screenshot.png` is the already-preserved MCP screenshot response downloaded
without re-querying Figma.

## Exact Figma evidence

- Native Settings window `36:5188`: x466 y56, 580 × 870; titlebar 31; content 580 × 839.
- Grouped Form `36:5197`: x20 y20, 540 × 799.
- Sections/rows are recorded in `figma-context.json` and the raw XML metadata.
- Menu Bar: Show Delta; Show symbol On; Precision 42.1 W; Components CPU, GPU.
- Readings: Update Every 2 seconds; Smooth readings On.
- Component Readings: Status On; Helper Remove….
- Notifications: Charger can’t keep up On; Fully charged Off.
- General: Open at login On; automatic updates On; Uninstall Watt?; Version 1.0 (1).
- Keyboard: Cmd-W closes; zoom disabled; not resizable; first control receives focus; reopening brings Settings forward.
- VoiceOver: grouped Form section headings and native Picker/Toggle/Button semantics;
  subtitles are help text; destructive confirmation is native and never default.

## Native implementation mapping

`SettingsRootView` reuses native SwiftUI `Form`, grouped `Section`, `Picker`,
`Toggle`, `LabeledContent`, `Button`, `.alert`, `.defaultFocus`, and native
Settings-scene `.windowResizability(.contentSize)`. No custom window painting,
rounded rectangles, gradients, traffic lights, forced tint, forced fonts, or
preferred color scheme are used.

## Verification

Recorded validation used **Xcode 27.0 (27A266a)** through
`DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer` (`toolchain.log`).
Existing logs and exit files are indexed in `verification.json`; no builds or
tests were rerun for this evidence-only update.

| Check | Existing result | Log |
|---|---|---|
| Static evidence/checksum/native-control/project checks | Exit 0 | `static-check.log` |
| Focused J111/J112/NativeStyling tests | Exit 0; 23 tests, zero failures | `focused-tests.log` |
| Package tests | Exit 0; 681 executed, five skipped, zero failures | `package-tests.log` |
| Debug build/analyze/build-for-testing | Exit 0; all passed | `debug-build-analyze.log` |
| Release build/analyze | Exit 0; both passed | `release-build-analyze.log` |
| Release build-for-testing | Exit 65 | `release-build-for-testing.log` |
| Verification aggregate | Exit 1 solely due to Release test-build exit 65 | `verify.exit`, `validation.log` |
| Native Settings capture (separate from aggregate) | Exit 1; AX/TCC blocked | `capture.log`, `capture/window.json` |

The Release test-build log reports `cannot find 'FixtureLaunchSelection' in scope`
in fixture launch sources and `App/WattApp.swift`. This is not a failed Release
app build; no Release test execution is claimed. Five package-suite skips are
four existing J6.2–J6.5 AX-label checks and the opt-in P01 physical-host probe.

Reproduction: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer bash docs/evidence/J11.2/verify.sh`.
Capture is separately invoked with `bash docs/evidence/J11.2/capture.sh`;
its failure does not contribute to `verify.sh`'s aggregate exit.

## Visual acceptance remains blocked

Reference node **36:5186** maps to Settings window `36:5188` and Form `36:5197`.
`capture/window.json` records Accessibility trust unavailable, Screen Recording
preauthorized, no verified window and no native image. No permission was requested.
Process cleanup evidence is retained in `capture/process-cleanup.log`.

`visual-review.json` therefore records **nativeCapture: null**, **comparableCapture:
false**, **score: null**, **pixel_diff: null**, **visualPass: false** and no verified
live interaction. Reference assets are not implementation captures. Neither a
pixel comparison nor native Settings visual acceptance is claimed.

## Fresh Figma and native evidence — 2026-09-23
- Figma MCP re-queried for exact frame `36:5186` with design context, metadata, variables and screenshot; screenshot pinned at `fresh-figma/reference-2026-09-23.png` with SHA-256 `cbb3f9b6b84c6051b937cec90968b5a5a6cfc0a6278862cf63c54860dabe15b1`.
- Exact hierarchy, control copy, accessibility annotations, keyboard behavior, tokens and native control boundary are recorded in `fresh-figma/context-2026-09-23.md`.
- `J11.2/base` was launched, `Settings…` was activated through AX, and a PID-owned native Settings window appeared. Its measured 580 × 831 geometry and live Off/Turn On state did not match the 580 × 870 On/Remove Figma reference; strict capture therefore failed closed.
- A diagnostic native PNG is retained but no visual-pass, pixel-parity, keyboard or VoiceOver claim is made. The mismatch is now a concrete follow-up rather than an implicit success.
- The fixture was reaped; the normal Desktop app remained running.
