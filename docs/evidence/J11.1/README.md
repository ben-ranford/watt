# G078 / J11.1 — Status item + panel — VoiceOver order

Source of truth: Figma file `9DKDgUfEqidZdZQEVlQgLS`, node `36:5057`, frame
`900 × 640`. Exact MCP context, metadata, screenshot export, variables, and
reference digest are preserved in this directory.

## Exact Figma evidence

- Status anchor `36:5059`: `x0 y5 w641 h24`.
- Status item `36:5060`: `x545 y0 w96 h24`.
- Status item label: `Watt?, charging, plus 42.1 watts, menu extra.`
- Status item hint: `Click for details. VO-Shift-M for options.`
- Announcement policy: state changes or at most every 30 seconds.
- Native `MenuBarExtra .window` panel `36:5061`: `x551 y40 w320 h473`, dark
  system material.
- Panel summary: `Charging`, `+42.1 W`, `Into battery · 64% · full in 38 min`.
- Power: Charger input `65.0 W` / `96 W USB-C charger`; System draw `22.9 W`;
  Battery `+42.1 W`.
- Components: CPU `9.8 W`, GPU `4.1 W`, Display `5.2 W`, Other `3.8 W`.
- Actions: `Settings…`, `Quit Watt?`; keyboard: Tab, Shift-Tab, Cmd-, Cmd-Q, Esc.
- Tokens: SF Pro semantic 13/16 and 26/32 styles, 11/14 subheadline,
  dark labels `#ffffffd9`/`#ffffff8c`, blue `#0091ff`, height 24, radius 6,
  horizontal padding 16.

## Native implementation mapping

J11.1 uses the existing `MenuBarExtra`/status-item bridge, `MenuBarRootView`,
`StatusPanelView`, native `Form`/`Section`/`LabeledContent`, native `Button`
shortcuts, semantic `WattTypography`, and `.monospacedDigit()`. It does not
paint a panel, material, traffic lights, rows, buttons, status bar, or wallpaper.
The status item is one accessibility element; the AppKit bridge applies one
combined label and hint and omits a duplicate AX value. The announcement gate
only refreshes AX text for a state change or after 30 seconds.

## Verification status

Validation uses the available full Xcode 27.0 toolchain explicitly because the
shell's default `xcode-select` still points at CommandLineTools:
`DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer`. The evidence logs
record the actual exits from that toolchain. Package XCTest execution passed
675 tests (five skipped), including F05 ordering and all J11.1 contracts. The
scheme-level `xcodebuild test-without-building` runner stalled while creating
the local test worker after destination selection; its exit 65 and diagnostic
are preserved rather than presented as test results.

Native capture also fails closed if AX/TCC/compositor gates do not pass. This
run found Screen Recording preauthorized but Accessibility trust unavailable;
no TCC permission was requested, and no replacement/cached window was used.

Run when a full Xcode toolchain and permitted compositor/AX environment exist:

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer bash docs/evidence/J11.1/verify.sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer bash docs/evidence/J11.1/capture.sh
```

## Recorded validation

- `verify.sh`: exit `0`; Figma JSON/reference digest/project-registration and
  Swift capture-script parse checks passed (`verify.exit`, `static-check.log`).
- Debug build + analyze: exit `0` (`debug-build-analyze.exit`); build and
  analyze succeeded.
- Debug test build: exit `0` (`debug-test-build.exit`).
- Release build + analyze: exit `0` (`release-build-analyze.exit`); existing
  onboarding actor-isolation and AppIntents metadata warnings remain.
- Package XCTest: exit `0` (`package-tests.exit`); `675` executed, `5` skipped,
  `0` failures. `F05FixtureTests` and `J111VoiceOverOrderTests` both passed.
- Focused/full scheme tests: exit `65` after explicit
  `-parallel-testing-enabled NO`; no test case ran because Xcode's local test
  worker remained blocked at `waiting for workers to materialize` /
  `LaunchServicesLauncher` after destination selection. See
  `focused-tests-explicit.log` and `full-tests.log`.
- Native capture: exit `1` (`capture.exit`); `capture/window.json` records
  `screenCapturePreauthorized: true`, `AXTrusted: false`, no owned compositor
  window, and null visual metrics. `visual-review.json` makes no visual-pass
  claim.

## Fresh Figma and native evidence — 2026-09-23
- Figma MCP re-queried for exact frame `36:5057` with design context, metadata, variables and screenshot; screenshot pinned at `fresh-figma/reference-2026-09-23.png` with SHA-256 `505f0fa2334ae245ba6e4b8573eb5b27f564a3673abdaa99241bccf1f2bcde49`.
- Exact hierarchy, VoiceOver annotations, keyboard behavior, tokens and native `.window` boundary are recorded in `fresh-figma/context-2026-09-23.md`.
- `J11.1/base` was launched from the current Debug binary. Fresh AX evidence confirms the native status item label/hint boundary and `+42.1 W`; AXPress returned success, but no PID-owned panel window surfaced on this compositor host.
- No visual-pass, VoiceOver speech, keyboard traversal or pixel-parity claim is made. The panel capture limitation is recorded in `fresh-figma/live-ax-2026-09-23.log`.
- The fixture was reaped; the normal Desktop app remained running.
