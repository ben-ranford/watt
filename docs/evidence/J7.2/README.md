# J7.2 — Result — Per Component in menu bar

Implementation verified for G056 on branch
`bug/G056-j72-result-per-component-in-menu-bar`. No commit was created;
all prior cumulative changes are preserved. Visual acceptance remains blocked.

Exact Figma file `9DKDgUfEqidZdZQEVlQgLS`, node `31:6952`:
[open reference](https://www.figma.com/design/9DKDgUfEqidZdZQEVlQgLS/Watt-?node-id=31-6952).
The supplied PNG is retained as `reference.png` (1000 × 220, 240241 bytes), SHA256
`5383443c3506f7d58834c6e20687a2564029fbbb288f3d22aedb2e086106fa75`.
See `reference.json`, `reference.sha256`, `figma-design-context.txt` and
`figma-hierarchy.xml` for exact retrieval, hierarchy, variants, assets and copy.
The historical F00 export in StoryFixtureData is preserved separately.

The frame contains a Light Desktop Template (Dock hidden) and the right-aligned
status anchor `31:7101` containing idle status item `31:7099`.
Its text is **CPU 9.8 · GPU 4.1 W**, with no battery/bolt symbol.
Body/Emphasized is SF Pro 13/16 semibold. Desktop wallpaper, other menu bar items,
material, typography, spacing and focus are macOS-owned. No app-owned raster/vector
asset is required. The reference is evidence only, never a runtime background.

## Implementation

`App/WattApp.swift` composes a DEBUG-only `J72FixtureLaunch` through the existing
MenuBarExtra, MenuBarStatusLabel and NSStatusBarButton bridge. Only
`--watt-fixture J7.2/base` is accepted. It creates fresh in-memory preferences and
PowerReadingStore, uses existing `.samplePerComponent` and a frozen FakeWattClock,
and sets `.components`, `["CPU", "GPU"]`, component readings on, decimal precision,
showSymbol false and completed livePanel onboarding. The result launches with no
menu or panel opened. No live telemetry, persisted user preferences, helper install
or network service is introduced.

Shared MenuBarStatusLabel already provided ordered compact component formatting;
this slice adds reading validation before formatting. PowerReadingStore now expires
explicit per-component status at five seconds and suppresses it following an invalid
update, reusing its existing publication task. No special J7.2 status string renderer
or custom chrome was added. Partial missing components keep their existing em-dash
format. StatusItemContextMenu, MenuBarRootView, PowerReading and PreferencesStore
are byte-identical to the start-of-slice hashes. Release excludes the fixture,
observation harness and registry. See `changed-files.json` for the exact source slice.

## Verification

- Ten J7.2 story tests passed in each runtime; 61 focused story/native-style/registry
  and router tests passed in each runtime.
- Full package: 506 tests, five existing skips, zero failures.
- Full native WattTests unit target: 494 tests, five existing skips, zero failures.
- Package build and native Debug/Release build + analyze passed.
- Ten malformed native selectors rejected with exit 1 before app composition.
- Debug fixture/harness/registry symbols present; Release symbols and selector strings absent.
- Native-style/static checks, exact PNG SHA256, script typecheck and git diff checks passed.

`initial-story-tests.log` records 19 failed assertions before the bounded shared fixes
(invalid data, expired status, invalid-update suppression and expiry publication).
The initial static probe failed because it searched a raw mangled Swift method name;
`swift-demangle` confirmed it, and the corrected check passed. The corrected lowercase
selector subprocess probe also passed. `verification.json` is the consolidated result;
`verification-run.log` preserves the original run and subsequent corrections.

Remaining build warnings are the existing OnboardingFlowView.swift:200 actor-isolation
warning, SwiftPM unhandled cumulative files and skipped AppIntents extraction. The five
full-suite skips cover four existing native AX row checks and one opt-in hardware probe.
GUI WattUITests were not run: Accessibility trust is absent. Unit/layout/style checks
are not compositor or VoiceOver acceptance.

Reproduce semantic checks with `bash docs/evidence/J7.2/verify.sh`.
`diff-check.py` checks whitespace in tracked and slice-local untracked files; it is
not an image comparison and does not produce a visual score.

## Actual capture attempt and limits

`capture.sh` launched the actual Debug Watt binary with J7.2/base, PID **18444**.
The external Swift probe reported screen capture preauthorized, **AXTrusted=false**
and **zero PID-owned compositor windows**. No status-button metadata or screenshot
was produced. The launched PID was terminated and reaped; see `capture/process.txt`,
`capture/window.json` and `capture/process-cleanup.log`. Capture exited 1 as intended.
There is no synthetic/cached view rendering, desktop crop or foreign-window fallback.

Visual pass is false, score and pixel diff are **null**. Exact no-symbol pixels,
Aqua appearance/placement, click/focus and VoiceOver remain unverified on a live desktop.
This session has no TMUX/TMUX_PANE, so visual-ralph runtime is unavailable; no goal or
workflow-state authority was inferred or mutated. `toolchain.log` and
`visual-review.json` retain these limitations.

For another attempt, preserve the existing `capture` directory under a distinct name
first; `capture.sh` deliberately refuses existing output. Run it on a graphical host
with preauthorized screen capture and Accessibility trust. It requires exact fixture
PID/window identity and independent AX text before real compositor capture, then reaps
the app. Even successful capture remains awaiting visual review; it never auto-claims
pixel similarity against OS-owned desktop chrome.
