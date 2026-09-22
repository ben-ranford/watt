# C03 app-owned WindowServer capture availability probe — 2026-09-21

**Failed at compile-time; no runtime capture, visual pass or checkpoint.**

The proposed bounded capture would run during the existing native menu tracking
callback, replacing neither menu rows nor event handling. `probe.swift` isolates the
exact public API call before making any application change. Its candidate selector
requires a visible `NSPopupMenuWindow`, a positive window number, and a single
`CGWindowListCopyWindowInfo(.optionIncludingWindow, id)` entry whose ID and owner PID
match the current app. The image call specifies only that window ID, `.null` bounds,
and `.optionIncludingWindow`; it does not select the desktop or adjacent windows.

## Observed result

Run `bash docs/evidence/C03/windowserver-probe/run.sh` from the worktree. With the
installed Xcode/macOS 27 SDK, Swift 6 typechecking exits **1**:

> 'CGWindowListCreateImage' is unavailable in macOS: Please use ScreenCaptureKit instead.

The diagnostic identifies macOS 15.0 as the obsoletion version. See `typecheck.log`
and `environment.log`. The installed SDK's public `CoreGraphics/CGWindow.h`, lines
271–274, declares this API with `SCREEN_CAPTURE_OBSOLETE(10.5,14.0,15.0)`.
The same header documents transparent-black output for unreadable windows and NULL
outside a GUI session, but **neither runtime condition was tested**: compilation
failed before execution. PID matching is proposed source logic, not observed
runtime ownership evidence.

No deprecated-API availability bypass, dynamic symbol lookup, older SDK, alternate
capture API, permission request, AX access, global event injection or fake bitmap
was attempted. No screenshot was taken. The existing DEBUG NSView.cacheDisplay
path and all production application source remain unchanged by this probe.

## Figma comparison and disposition

There are **no resulting WindowServer images** to compare with `../reference-menu.png`
(230×187) or `../reference-submenu.png` (190×141). Existing cacheDisplay comparisons
remain the last evidence; they cannot prove compositor vibrancy fidelity. No new
pixel score or material-fidelity improvement is asserted. The candidate therefore
fails the availability gate and is not integrated. C03 visual acceptance remains open.

`probe.swift` lives under excluded `docs/`, outside application/test targets. Its
intentional compile failure is evidence, not a new application build failure.

## Verification of the unchanged application

- Focused `swift test --scratch-path .build/c03-package --filter 'C03ContextMenuTests|F05FixtureTests'`:
  **29 tests, zero failures** (`package-focused.log`).
- Xcode Debug `build analyze`: **both succeeded** (`debug-build-analyze.log`).
- Probe shell syntax, ShellCheck and `git diff --check`: passed.
- No Release rebuild was needed: application source and build configuration were
  not edited. No runtime WindowServer capture validation is claimed.
