# G055 / J7.1 — Right-click → Show in Menu Bar

Fresh MCP retrieval on 2026-09-23 is pinned in `fresh-figma/context-2026-09-23.md` and `fresh-figma/reference-2026-09-23.png` (SHA-256 `cbb1d098466ed5c3b58b0ac8748bcd75a928550d38a9c4b2309c8d48e3fe5cd9`).

Fresh MCP retrieval on 2026-09-23 is pinned in `fresh-figma/context-2026-09-23.md` and `fresh-figma/reference-2026-09-23.png` (SHA-256 `cbb1d098466ed5c3b58b0ac8748bcd75a928550d38a9c4b2309c8d48e3fe5cd9`).

Implemented and automated checks passed. **Visual acceptance is blocked**: the actual
native app launch had no PID-owned compositor windows and AX trust was unavailable.
No screenshot, numeric visual score or pixel diff is claimed. The app PID was
terminated and reaped. No commit was created.

## Exact reference

- Figma file `9DKDgUfEqidZdZQEVlQgLS`, node `31:6173`; 1000×720, light native macOS.
- Supplied asset: <https://www.figma.com/api/mcp/asset/5a226808-f4c5-4972-ada6-17b9b182fe88.png>.
- Retained bytes: [reference.png](reference.png), SHA256
  `cbb1d098466ed5c3b58b0ac8748bcd75a928550d38a9c4b2309c8d48e3fe5cd9`.
- [reference.json](reference.json) records exact nodes, menu content, bounds and fixture
  state; [reference.sha256](reference.sha256) independently pins the file. The earlier
  F00 export digest remains historical registry metadata, not this PNG's digest.

The reference shows selected battery glyph `+42.1 W`; main Show in Menu Bar highlighted;
Delta checked and Components highlighted in the submenu. The main/submenu reference
bounds are 230×187 / 190×141 points. AppKit chooses live geometry, typography, material,
checkmarks, chevrons, shortcuts and hover/keyboard behavior. No custom chrome or forced
Figma dimensions were added.

## Implementation

- `App/WattApp.swift`: DEBUG-only `J71FixtureLaunch`, fresh in-memory preferences,
  frozen `.sampleCharging`, completed onboarding, delta/decimal/symbol, Components on,
  and an explicitly injected fake connected helper; light Aqua. Posts app-local
  secondary-click events to the actual status button window and native arrow keys.
- Existing `StatusItemContextMenu`, `AppRouter`, `PreferencesStore` and status-item
  monitor are reused. Open, Settings, About, Updates, Quit, Finish Setup and helper
  unavailability preserve existing behavior. Production menu factory is unchanged.
- Fixture registry and native Xcode test registration add only J7.1/base. The existing
  registry shorthand `J7.1` resolves to base; no additional variants are accepted.
- `Tests/WattTests/J71ShowInMenuBarTests.swift`: nine menu/state/navigation/isolation
  tests. `NativeStylingTests.swift` also rejects custom menu chrome tokens.
- `DESIGN.md` and `SCREEN-BACKLOG.md` record the native decision and honest acceptance state.
- [changed-files.json](changed-files.json) lists this slice; cumulative prior changes remain.

## Reproduce

From the worktree root:

```sh
bash docs/evidence/J7.1/verify.sh
bash docs/evidence/J7.1/capture.sh
python3 docs/evidence/J7.1/diff-check.py
bash docs/evidence/J7.1/static-check.sh
shasum -a 256 -c docs/evidence/J7.1/reference.sha256
```

The native Debug executable accepts `--watt-fixture J7.1/base`. The package executable
rejects fixture launches; Release excludes fixture types, selectors and registry files.
`capture.sh` deliberately refuses an existing `capture/` directory. Preserve/move that
directory before a subsequent run so old images cannot qualify as fresh evidence.

The app-owned observer writes identities and actual menu tracking state only. The
external capture helper requires preauthorized screen capture, existing AX trust,
PID-owned main/submenu/status windows and matching AX menu titles/checkmark/selection.
It never captures the desktop, foreign windows, cached views or synthetic images.
Process cleanup is bounded and recorded. No permission request is made.

## Verification results

| Check | Result |
| --- | --- |
| J7.1 tests | 9 passed in both package and native runtimes |
| Focused suites | 60 passed in each runtime |
| Full package suite | 496 executed, 491 passed, 5 existing skips, 0 failures |
| Full native unit suite | 484 executed, 479 passed, 5 existing skips, 0 failures |
| Package build | Passed |
| Native Debug + Release | Build and analyze passed for both |
| Malformed selectors | 9 subprocess rejections, exit 1 with launch-gate diagnostics |
| Release isolation | Fixture symbols and selector strings absent; Debug symbols present |
| Static/diff | Passed; shell/Python/Swift/JSON, native style, digest, `git diff --check` |
| Real capture | Blocked; AXTrusted=false, no owned windows; PID 13836 reaped |
| Visual verdict / pixel diff | null / null |

The five existing skips are four SwiftUI AX-row tests and the opt-in physical-hardware
probe. Full native results here refer to the WattTests unit target. Live XCUI interaction,
status selection, submenu highlight, screen-edge placement, keyboard dismissal and
VoiceOver remain unverified. Existing onboarding actor-isolation/AppIntents warnings
remain outside this story.

[verification.json](verification.json) records counts and evidence paths;
[visual-review.json](visual-review.json) records the blocked verdict;
[capture/window.json](capture/window.json) records the real launch's access/ownership
results; [capture/process-cleanup.log](capture/process-cleanup.log) proves cleanup.
Initial compiler/test-assumption failures are retained separately; final runs passed.
`diff-check.py` checks source whitespace, not pixels. Pixel comparison requires a fresh
comparable native capture and remains explicitly null.

A fresh native AX probe on 2026-09-23 is retained at `fresh-figma/live-ax-2026-09-23.log`: shell trust was `true`; the real fixture registered `Watt?, charging, plus 42.1 watts, menu extra.` at frame `x=-1, y=1157, width=96.5, height=24`. The host-owned menu-bar tree was present, but no accepted fixture-owned context-menu window was available; the fixture was terminated and reaped.

The installed visual-ralph skill was inspected. Its runtime is unavailable in this
non-tmux native session; the existing repository capture/verification process was used.
No OMX goal/runtime state was created or mutated. Native semantic presentation remains
the design constraint when a future live capture is available.
