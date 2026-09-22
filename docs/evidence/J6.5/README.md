# G054 / J6.5 — Unplugged — on battery

Exact Figma file `9DKDgUfEqidZdZQEVlQgLS`, node `31:5571`.
The exact user-specified PNG is retained as `reference.png` (1000 × 720), with SHA256
`2fc0d5e53483f6377d473195b64643f6b4316da85ea9c78e83af1a7c21ce1c47`.
`reference.json` records the source URL, copy, approximate panel bounds and provenance;
`reference.sha256` is independently checkable. Original F00 registry metadata is retained.

The implementation uses the shared native StatusPanelView/StatusPanelModel and
sampleOnBattery. It shows On battery / −18.4 W / 64% · about 4 h 10 min left, with
Charger input / Unplugged, System draw / 18.4 W, Battery / −18.4 W. Components are
hidden only for this compact fixture; C02 keeps its Components. Native Form/Section/
LabeledContent, borderless Settings… / Quit Watt? and existing MenuBarExtra/status-item
selection bridge remain in use. Desktop wallpaper and menu-bar chrome are OS-owned.
No visual assets are added to the app.

The Debug native fixture is `--watt-fixture J6.5/base`; the existing base shorthand
`J6.5` also resolves. It uses dark Aqua, Delta/decimal with battery symbol, a frozen
clock, independent in-memory preferences/store and completed onboarding. Unsupported
or malformed selectors fail before app composition. Release excludes the fixture
launch, sample and registry; symbol checks cover both Debug and Release binaries.

Discharging presentation fails closed for stale/unavailable/invalid samples and
capabilities. The store expires discharging snapshots after five seconds and suppresses
status after validation failure. A cancellable real-clock expiry notification refreshes
already-open views even without another sample; fake clocks remain frozen. Missing
battery watts suppress the subtitle. Estimates are supplied by telemetry, never inferred.
The existing legacy PowerReading.value(for:) contract is preserved; presentation applies
the stricter freshness boundary. This does not add telemetry polling.

Run from this implementation worktree:

```sh
bash docs/evidence/J6.5/verify.sh
bash docs/evidence/J6.5/capture.sh > docs/evidence/J6.5/capture-run.log 2>&1
```

`verify.sh` uses installed Xcode and runs focused/full package tests, package build,
native Debug/Release build and analysis, focused/full hosted tests, nine invalid-selector
subprocess checks, static checks and tracked/untracked whitespace checks. `capture.sh`
requires a fresh `capture` directory; archive a prior attempt before rerunning. Capture
launches the built Debug app and cleans up only its PID. It neither requests nor changes
OS permissions.

The capture script requires preauthorized Screen Recording, AX trust, exact live panel
content and PID-owned matching compositor geometry. It never uses cacheDisplay,
wallpaper/desktop grabs, or synthetic rendering. A blocked capture yields
`status: visual-blocked`, null score and pixel diff. A successful native panel capture
still requires visual review and selected status-item evidence before acceptance.
`diff-check.py` checks source whitespace; it is not a pixel comparator. Native hosting
and status-selection tests do not establish compositor similarity or live VoiceOver.

Final command results, test counts and limitations are recorded in `verification.json`
and `visual-review.json`. Logs and exit files retain the actual runs. The first focused
integration run caught a missing registry-state phrase in the backlog; the phrase was
restored without weakening the consistency assertion (`initial-backlog-regression.*`).
No commit was made, and cumulative work remains uncommitted.

Final validation: focused package/native each 145 tests (141 passed, four skips), full
package 487 (482 passed, five skips), full native 475 (470 passed, five skips); zero
failures. J6.5 adds 11 tests (10 passed, one AX skip) per runtime. Builds/analyzes,
isolation, static/diff and all nine invalid selectors pass. Real capture exits 1:
Screen Recording preauthorized, AXTrusted=false, zero fixture-owned compositor windows.
The process was terminated and reaped. Visual status is blocked; score/pixel diff null.
