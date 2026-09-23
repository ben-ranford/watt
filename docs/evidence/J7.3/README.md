# G057 / J7.3 — Settings — choose components (max 2)

Fresh MCP retrieval on 2026-09-23 is pinned in `fresh-figma/context-2026-09-23.md` and `fresh-figma/reference-2026-09-23.png` (SHA-256 `d6ffb39f4c390876077c0fb584f1bd7692308be6068bc92004004813a5329a07`).

Implementation and automated verification are complete on
`bug/G057-j73-settings-choose-components`. **Visual acceptance is blocked.**
All prior cumulative changes remain; no commit was created.

## Exact reference and inspection

- Figma file `9DKDgUfEqidZdZQEVlQgLS`, exact frame [`31:7102`](https://www.figma.com/design/9DKDgUfEqidZdZQEVlQgLS/Watt-?node-id=31-7102), 1000 × 720, native Light macOS.
- Exact supplied asset: <https://www.figma.com/api/mcp/asset/b3c4703f-fb7f-4529-bd75-09578341b687.png>.
- Retained [reference.png](reference.png), SHA256 `d6ffb39f4c390876077c0fb584f1bd7692308be6068bc92004004813a5329a07`.
- [reference.json](reference.json) records download metadata, hierarchy, copy, appearance, variants and visual inspection; [reference.sha256](reference.sha256) independently pins the bytes.
- [figma-design-context.txt](figma-design-context.txt) and [figma-hierarchy.xml](figma-hierarchy.xml) retain exact MCP retrievals. The PNG was directly inspected with view_image. Its digest differs from the historical F00 export, which remains separate metadata.

The root contains the desktop template `31:7103`, Settings `31:7256` titled
**Watt? Settings**, and Components popup `31:7533`. Settings reference bounds are
x240/y256/520×229; popup bounds x570/y406/170×130. These are inspection records,
not prescribed native control or window dimensions. The app reuses the semantic
settings excerpt width and lets grouped Form determine height.

The native Menu Bar section orders Show (Components), Components (CPU, GPU) with
**Two fit. More crowd the menu bar.**, then Precision (42.1 W). The open native
popup has CPU/GPU checked and Display/SSD/Other disabled. Precision's value is
occluded by the popup in the PNG and confirmed in the design context.
Figma's Body/Emphasized 13/16 semibold and Headline/Regular 13/16 bold map to
native/semantic styles. No numeric font size, custom chrome or runtime asset is added.
The desktop and window/menu materials remain system-owned.

## Exact implementation files

- `DesignSystem/Components/ComponentSelectionMenu.swift`: reusable NSViewRepresentable with NSPopUpButton/NSMenu/NSMenuItem, native checked/disabled items, intrinsic metrics, target/action and accessibility label/value/help. The popup cell keeps the summary separate from independent item states.
- `Features/Settings/Views/SettingsRootView.swift`: replaces the combination Picker with the bridge inside LabeledContent; keeps native Form/Section/Show/Precision controls, exact copy and ordered excerpt. J2.5 retains its shorter subtitle.
- `Models/WattPreferences.swift`: shared max-two/order/identity validation and available-ID toggle; selected components commit to storage before publishing. Failed writes preserve the previous selection.
- `Services/PowerReadingStore.swift`: available IDs require validated, recent, available telemetry; invalid updates, duplicate identity aliases, stale or unavailable snapshots fail closed.
- `App/J73FixtureLaunch.swift`: DEBUG-only, exact base selector, fresh in-memory preferences/store, frozen sample, Aqua, completed livePanel and scripted connected helper. It locates and clicks the real native popup and records identities only.
- `App/WattApp.swift`: routes isolated state through the existing AppRouter/openSettings/Settings scene; injects the existing store into the J2.5 excerpt now using the same menu.
- `Tests/Fixtures/FixtureLaunchSelection.swift`, `StoryFixtures.swift`, `StoryFixtureData.swift`: exact J7.3/base selector, implemented registry and reference/acceptance metadata.
- `Tests/WattTests/J73ChooseComponentsTests.swift`: 12 story tests for native state/copy/layout, selection order/capacity/persistence, stale and helper-loss dispatch, identities, appearance, fixture isolation and J7.1 Settings navigation.
- `Tests/WattTests/NativeStylingTests.swift`: native popup contract and custom-chrome prohibitions.
- `Tests/WattTests/F05FixtureTests.swift`: implemented registry expectations include J7.3.
- `Tests/WattTests/J23SettingsTurnOnTests.swift`: scopes the old source-level telemetry ban to helper lifecycle code; existing runtime helper-authority checks remain intact.
- `Watt.xcodeproj/project.pbxproj`: app bridge/fixture and story-test wiring.
- `DESIGN.md`, `SCREEN-BACKLOG.md`: reusable picker decision, reference and acceptance evidence.

[changed-files.json](changed-files.json) lists this bounded slice.
ReadingPicker, the J7.1 context menu and J7.2 status-label source are unchanged
against the start-of-slice SHA records. The J7.2 text remains **CPU 9.8 · GPU 4.1 W**.
Saved unavailable choices remain checked but disabled; no state is silently substituted.
At capacity, an available third option is disabled and an already-dispatched action
is rejected. Removing an available selected item frees a slot; reselecting appends it.

## Verification

| Check | Result |
| --- | --- |
| J7.3 story tests | 12 passed in package and native runtimes |
| Focused story/style/registry/router suites | 83 passed in each runtime |
| Full package suite | 519 executed, 514 passed, 5 existing skips, zero failures |
| Full native WattTests suite | 507 executed, 502 passed, 5 existing skips, zero failures |
| Package build | Passed |
| Native Debug and Release | Build and analyze passed for both |
| Malformed fixture selectors | 10 subprocesses rejected with exit 1 before composition |
| Release isolation | Fixture/harness and registry symbols/selectors absent; Debug symbols present |
| Static, SHA256, scripts, git diff checks | Passed |
| Real native capture | Blocked: AX trust false, no PID-owned compositor windows |
| Visual score / pixel diff | null / null |

[verification.json](verification.json) maps results to raw logs and exit files.
The five existing skips are four SwiftUI AX-row probes and the opt-in physical-host
telemetry probe. Existing onboarding actor-isolation, SwiftPM cumulative unhandled-file
and AppIntents metadata warnings remain outside this slice. No new warning remains.
Initial failures are retained: default Command Line Tools missing SwiftUI macros,
a test-only enum case, unattached AX role reporting AXUnknown, and the old whole-file
telemetry assertion. Corrected final runs passed. Live AX roles are checked externally,
not inferred from unattached NSView tests.

## Reproduce

From the worktree root:

```sh
bash docs/evidence/J7.3/verify.sh
bash docs/evidence/J7.3/capture.sh
python3 docs/evidence/J7.3/diff-check.py
bash docs/evidence/J7.3/static-check.sh
shasum -a 256 -c docs/evidence/J7.3/reference.sha256
```

Verification selects `/Applications/Xcode.app/Contents/Developer` explicitly.
Only the native Debug executable supports `--watt-fixture J7.3/base`; the package
executable rejects fixtures. Release excludes the fixture/harness through DEBUG guards
and excludes the registry source files through the existing build configuration.
The fixture neither creates a separate NSWindow nor renders a desktop/background.
It opens the existing Settings scene and invokes the native Components popup.

`capture.sh` requires a fresh output directory. Preserve the existing `capture/`
directory under a different name before another attempt. The external helper requires
preauthorized screen capture and AX trust, exact fixture PID metadata, independently
PID-owned Settings and popup compositor windows, and matching AX copy/checkmarks/disabled
items. It never requests permissions or captures a foreign window, desktop crop,
cached view or synthetic bitmap. Even a successful capture awaits visual review.
`diff-check.py` checks whitespace in tracked and slice-local untracked files; it does
not calculate pixel similarity or produce a visual score.

## Actual capture limitation

The real Debug fixture launched as PID **24681**. Screen capture was preauthorized,
but **AXTrusted=false** and the compositor listed **zero windows owned by that PID**.
No settings/popup metadata or screenshot could be proven. Capture exited 1, the PID
was terminated and reaped, and no synthetic fallback was attempted. See
[capture/window.json](capture/window.json), [capture/process.txt](capture/process.txt)
and [capture/process-cleanup.log](capture/process-cleanup.log).

[visual-review.json](visual-review.json) records the blocked verdict with score and
pixel diff null. Native keyboard interaction, dismissal, popup placement and VoiceOver
remain unverified on a live graphical desktop; GUI WattUITests were not run without AX
trust. The installed visual-ralph instructions were inspected, but runtime is unavailable
in this non-tmux session. No OMX or Codex goal state was created or mutated.

Fresh native AX probe on 2026-09-23 is retained at `fresh-figma/live-ax-2026-09-23.log`; native settings/popup evidence remains subject to the host AX/compositor boundary, so visual acceptance is not claimed.
