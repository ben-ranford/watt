# J7.4 / G058 — Crowded menu bar — Icon Only

Implemented in the cumulative worktree on branch
`bug/G058-j74-crowded-menu-bar-icon-only`. No commit is made.

## Exact reference

- Figma file `9DKDgUfEqidZdZQEVlQgLS`, node [`31:7764`](https://www.figma.com/design/9DKDgUfEqidZdZQEVlQgLS/Watt-?node-id=31-7764).
- Exact supplied [PNG](reference.png), 1000 × 220, SHA-256 `43c40d136771931bcde6be9c589a0f76ec23271830ae02c52e809fa3adff311d`.
- [Metadata](reference.json), [hash manifest](reference.sha256), [raw context](figma-context.json), [hierarchy](figma-hierarchy.xml), [screenshot response](figma-screenshot.json), [skill-load record](skill-loads.json).
- Desktop Template `31:7765`; right-aligned Status Item Anchor `31:7913`; Watt? Status Item `31:7911`. Light, selected False, no text, `battery.100percent.bolt`. Icon-only status content is a template SF Symbol, never an image of the desktop.
- Figma anchor (0, 5, 741, 24), item (700, 5, 41, 24), SF Pro Body/Emphasized 13/16 semibold are inspection metadata. MenuBarExtra/AppKit owns production metrics and chrome.

## Implementation

`MenuBarStatusLabel` uses a single native template SF Symbol for the saved `.iconOnly`
mode. It has no font, padding, custom background, shadow or fixed frame in this branch.
The accessible label is `Watt? power reading`; its value is the qualified delta
(`+42.1 watts` for the fixture) or `No reading yet`. The symbol stays visible if Show
Symbol is off; restoring Components preserves J7.2 formatting and saved selection.
The DEBUG-only C04.8 symbol override is removed in favor of shared production behavior.

`App/J74FixtureLaunch.swift` accepts only `--watt-fixture J7.4/base` in the native Debug
target. It uses fresh InMemoryStorage and PowerReadingStore, a fixed sampleCharging
clock, iconOnly/decimal/showSymbol, completed livePanel/helperOptIn state and a connected
FakeHelperService. Native Aqua and the existing MenuBarExtra/NSStatusBarButton path are
used. Release excludes the fixture/observer; no live settings, helper, network or
permission prompts are used by this fixture.

J7.1 menus, MenuBarRootView, PreferencesStore, PowerReadingStore, J7.2 formatting/tests
and broad NativeStylingTests remain preserved. F05 changes are restricted to registry
status for the new story and the intentionally changed shared icon-only semantics.
All other baseline sources are hash-checked by static-check.sh.

## Reproduce

From the repository root, with Xcode installed at `/Applications/Xcode.app`:

```sh
bash docs/evidence/J7.4/verify.sh
bash docs/evidence/J7.4/capture.sh
```

`verify.sh` uses `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer` and retains
raw logs and exit codes for focused/full package and native unit tests, package build,
native Debug/Release build+analyze, malformed-selector subprocess rejection, static,
Release symbol/string isolation, reference SHA and git whitespace checks.
`diff-check.py` checks cumulative tracked and this slice's untracked source/evidence
whitespace; it does not fabricate an image comparison.

`capture.sh` requires a fresh capture directory and refuses to overwrite stale evidence.
It launches the exact native fixture and validates PID ownership, compositor window,
AX identity/reading and Aqua/unselected/icon-only state before any screenshot. Capture
uses `screencapture -l` only. There is no desktop crop or NSView/bitmap fallback.
The process is terminated and reaped on every exit. Archive the existing capture
directory before a new attempt. A captured image still requires explicit visual review.

The visual-ralph workflow is unavailable outside tmux; it is not invoked and no durable
workflow or goal state is changed. Unproven visual score and pixel diff remain null.

## Verification result

Implementation verification passed on macOS 27.0 / Xcode 27.0, Apple Swift 6.4.

| Check | Fresh result |
| --- | --- |
| J7.4 story tests | 12 package + 12 native, zero failures |
| Focused story/regression/native styling tests | 98 package + 98 native, zero failures |
| Full package unit suite | 531 executed, 5 skipped, zero failures |
| Full native unit suite | 519 executed, 5 skipped, zero failures |
| Builds | Package build + native Debug build + native Release build passed |
| Static analysis | Native Debug + Release analyze passed |
| Malformed-selector subprocesses | 10 rejected before scene/store construction; exit 1 with rejection diagnostic |
| Release isolation | Fixture/observer/registry/parser symbols and selector/capture strings absent; Debug counterparts present |
| Static/SHA/whitespace | Passed, including cumulative `git diff --check` and declared untracked files |

The five skips in each full suite are existing J6.2/J6.3/J6.4/J6.5 host AX-label tests
and the opt-in P01 physical-host telemetry probe. See [verification.json](verification.json)
and the per-command `.log`/`.exit` files. Initial failed test iterations are retained;
the final verification run passes without weakening existing safety or authority tests.

**Visual acceptance is blocked.** Debug fixture PID **29583** launched, but
`AXTrusted=false` and the compositor returned no visible PID-owned windows. Screen
capture was preauthorized. No comparable image was produced, and no live click/AX or
pixel pass is claimed. The fixture process was terminated and reaped. [Raw capture
result](capture/window.json), [cleanup](capture/process-cleanup.log) and
[visual review](visual-review.json) retain `score: null`, `pixel_diff: null`,
`visualPass: false`. Visual-ralph remains unavailable outside tmux.

## Exact changed files

Modified existing cumulative files:

- `Features/MenuBar/Components/MenuBarStatusLabel.swift`
- `App/WattApp.swift`
- `Tests/Fixtures/FixtureLaunchSelection.swift`
- `Tests/Fixtures/StoryFixtures.swift`
- `Tests/Fixtures/StoryFixtureData.swift`
- `Tests/WattTests/F05FixtureTests.swift`
- `Watt.xcodeproj/project.pbxproj`
- `DESIGN.md`
- `SCREEN-BACKLOG.md`

Added `App/J74FixtureLaunch.swift`, `Tests/WattTests/J74CrowdedMenuBarTests.swift` and
this evidence directory. [Changed-file manifest](changed-files.json) records hashes;
[pre-edit hashes](pre-edit-hashes.json) preserve the cumulative baseline. Other source
files, including J7.1/J7.2 tests, NativeStylingTests, menu routing and authority guards,
remain byte-identical to the slice baseline.
