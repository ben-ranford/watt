# G059 / J8.1 — No reading after wake

Implemented in the cumulative SwiftUI/macOS worktree on
`bug/G059-j81-no-reading-after-wake`. No commit was created; prior changes are
preserved against [pre-edit hashes](pre-edit-hashes.json).

## Exact reference

- Figma file `9DKDgUfEqidZdZQEVlQgLS`, [frame 32:3451](https://www.figma.com/design/9DKDgUfEqidZdZQEVlQgLS/Watt-?node-id=32-3451).
- [Exact supplied PNG](reference.png), 1000 × 720, SHA-256 `524141281b61d5cdb627ea8f4cf8cc12658e6f94a802f87d77231472568eb0da`.
- [Metadata](reference.json), [SHA manifest](reference.sha256), [context](figma-context.json), [header context](figma-header-context.json), [hierarchy](figma-hierarchy.xml), [screenshot response](figma-screenshot.json), [skill-load record](skill-loads.json). Fresh retrieval and supplied PNG are byte-identical.
- Dark desktop `32:3452`; status anchor `32:3700`; selected status item `32:3697`; native panel `32:3701`; FormRetry row slot `32:4362` / TryAgainNow.
- Copy: **No reading**, **− − W**, **Usually right after wake. Watt? tries again every few seconds.**, **Try now**, **Try Again**, **Settings…**, **Quit Watt?**.
- Native `bolt.fill` status symbol and `exclamationmark.triangle.fill` warning; semantic SF Pro body/headline/large-title/subheadline styles. All desktop/wallpaper/chrome belongs to the system template; no application bitmap asset was added.

## Shared implementation

`StatusPanelState.noReading` extends the existing reading model and panel. Native
Form/LabeledContent and bordered Button supply the retry row; the native borderless
footer keeps existing Settings and Quit callbacks. The warning uses `Image(systemName:)`.
The Form sizes its contents with shared panel width, without fixed child geometry,
new color tokens, custom fonts or custom window chrome.

`PowerReadingStore.refresh()` uses the existing telemetry service and acceptance
contract. Manual retry and three-second polling share validation, request coalescing
and generation checks. Wake first invalidates pre-sleep readings and requests;
failed, stale, invalid or permission-limited samples cannot claim watts. Status
expiry now also suppresses ordinary charging/desktop samples; diagnostics retain
the last sample. Valid component-only samples retain their existing component panel through recovery.
The production IOPS adapter returns source/battery status only,
so it cannot fabricate watts from adapter ratings or charge percentage.

Workspace wake is observed through the workspace notification center, as required
by [Apple's wake notification contract](https://developer.apple.com/documentation/appkit/nsworkspace/didwakenotification).
The panel uses the native [grouped Form style](https://developer.apple.com/documentation/swiftui/formstyle/grouped).
Retrieved official documentation is retained in `apple-wake.md` and `apple-grouped-form.md`.

`App/J81FixtureLaunch.swift` supplies native Debug with fresh memory-only preferences
and power store, a frozen clock, unavailable fake telemetry, completed livePanel
onboarding/helper opt-in, fake connected helper and dark Aqua. Retry uses the same
store and remains unavailable. The fixture opens the real MenuBarExtra through the
existing status bridge; its observer only records native identity. It has no custom
window, popover, renderer or bitmap capture. Release excludes fixture/harness symbols
and selectors while retaining production no-reading/retry behavior.

Existing regression tests retain their safety assertions. Expectations for the old
fallback title, absent subtitle and generic standard state now require the explicit
J8.1 no-reading presentation. Stale desktop/charger fallback assertions now forbid
stale watts. The pre-existing J7.4 backlog state phrase was repaired to match its
unchanged fixture registry. [Changed-file manifest](changed-files.json) lists every
source change and its hash; unrelated baseline sources are hash-checked.

## Reproduce and evidence boundaries

```sh
bash docs/evidence/J8.1/verify.sh
bash docs/evidence/J8.1/capture.sh
```

Both scripts use `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer`.
Verification retains command logs and exit statuses for focused/full package and
native tests, package build, native Debug/Release build+analyze, ten malformed
selector subprocesses, fixture isolation, static checks, SHA and whitespace checks.

Capture requires a fresh directory and a living fixture PID. It verifies AX content,
native dark appearance and selection, then matches AX geometry to PID-owned
compositor windows before calling `screencapture -l`. No desktop crop, borrowed
window, view cache or bitmap substitute qualifies. Every exit terminates and reaps
the fixture. Successful capture still requires visual review; `diff-check.py` checks
whitespace and evidence gating and never manufactures a pixel comparison.

On macOS 27, SwiftUI's bordered Form button is represented by native graphics nodes,
not an `NSButton`. Story unit tests verify its source/style/disabled binding, shared
retry callback and store effects; native footer buttons are exercised directly.
The retained `native-view-tree-probe.log` explains the host representation. Live AX
retry activation remains dependent on successful capture/interaction evidence.

Visual-ralph is unavailable outside tmux and is not invoked. No workflow or hidden
goal state is mutated. Unproven visual scores and pixel differences remain null.

## Verification result

Verified on macOS 27.0 / Xcode 27.0 / Apple Swift 6.4.

| Check | Result |
| --- | --- |
| J8.1 story tests | 19 package + 19 native, no skips or failures |
| Focused story/native styling/regressions | 161 package + 160 native, five existing skips each, zero failures |
| Full package suite | 550 executed, five existing skips, zero failures |
| Full native suite | 538 executed, five existing skips, zero failures |
| Builds | Package build + native Debug build + native Release build passed |
| Analysis | Native Debug + Release analyze passed |
| Malformed selectors | All ten subprocesses rejected with exit 1 before scene/store construction |
| Release isolation | Fixture/observer/registry/parser symbols and selectors absent; production no-reading copy/refresh/wake present |
| Static/SHA/diff | Passed; exact PNG matches fresh retrieval; cumulative tracked and declared untracked whitespace checks passed |

See [verification.json](verification.json) and per-command `.log`/`.exit` files.
The focused package regex also selects one P03 regression method, explaining its
one-test difference from the native class-filtered run. Five full-suite skips are
existing J6.2/J6.3/J6.4/J6.5 host AX-label checks and the opt-in P01 physical-host probe.
The pre-existing onboarding actor-isolation warning and AppIntents metadata warning
remain; no J8.1 source warnings were introduced.

Initial failed iterations remain available. The first `verify.sh` invocation passed
all tests/builds and fixture isolation, then failed an extra static assertion that
expected the constants-only `NoReadingPresentation` enum to have a Release symbol.
Release inlines that enum. The corrected check verifies the emitted production copy
and refresh/wake functions instead; final `static-check.log` and `static-check.exit`
pass. The final full `verify.sh` rerun, including the valid component-only panel regression,
exited 0 end to end. Production and test code did not change after that run.

**Visual acceptance is blocked.** Fixture PID **38757** launched, but `AXTrusted=false`
and no PID-owned on-screen compositor windows were exposed. Screen capture was
preauthorized; the native status-button observer could not produce identity evidence.
No screenshot, selected-status pass, live AX press, visual score or pixel comparison
is claimed. The fixture was terminated and reaped. [Capture gate](capture/window.json),
[cleanup](capture/process-cleanup.log), and [visual review](visual-review.json) retain
`visualPass: false`, `comparableCapture: false`, `score: null`, `pixel_diff: null`.
Visual-ralph is unavailable outside tmux.

Exact source paths and final hashes are in [changed-files.json](changed-files.json).
Core edits: `Models/PowerReading.swift`, `Services/PowerReadingStore.swift`,
`Features/MenuBar/Views/StatusPanelView.swift`, `Features/MenuBar/Views/MenuBarRootView.swift`,
`Features/MenuBar/Components/MenuBarStatusLabel.swift`, and `App/WattApp.swift`.
Added `App/J81FixtureLaunch.swift` and `Tests/WattTests/J81NoReadingTests.swift`;
updated native project entries, fixture registry/selector, affected regression
expectations, `DESIGN.md`, `SCREEN-BACKLOG.md` and this evidence directory.
