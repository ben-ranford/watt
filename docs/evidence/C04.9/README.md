# G023 / C04.9 — No reading yet / sensor unavailable

Implemented 2026-09-22; no commit/checkpoint. **Visual acceptance remains open.**

## Contract and implementation

Exact task-supplied Figma MCP contract: frame `24:1472`, status component
`24:1588`, anchor `24:1590`. Native SF Symbol `bolt.fill`, text `− − W`,
shared `WattTypography.bodyEmphasized` (SF Pro Semibold 13/16 reference).
`reference-geometry.json` preserves exact retained metadata: 560×44 frame,
301×24 anchor at x0/y5, 71×24 component at x230/y5 (right edge x301).
`reference-24-1472.png` is the unmodified retained Figma export.

DEBUG selectors `C04.9` and `C04.9/base` construct `.unavailable` with its fixed
timestamp clock and fresh in-memory preferences. No hardware/network/polling.
The production no-reading Delta label now retains its unit with `− − W` and
accessibility value `No reading yet`; other display modes, available readings,
and icon-only behavior remain unchanged. Two legacy unavailable-Delta test
expectations were updated to this intentional contract. Existing stories remain
registered; C04.10–12 still fail closed. Release excludes fixture selectors.
No StatusItemContextMenu edits, bitmap UI, private APIs or TCC changes.

## Fresh verification

| Check | Result | Evidence |
| --- | --- | --- |
| Focused package C041–C049 | 32 passed | `package-focused.log` |
| Focused native hosted C049 | 3 passed | `native-focused.log` |
| Full package | 240 executed, 1 skipped, 0 failures | `package-full.log` |
| Full native hosted WattTests | 240 executed, 1 skipped, 0 failures | `native-full.log` |
| Debug build/analyze | Passed | `debug-build-analyze.log` |
| Release build/analyze | Passed | `release-build-analyze.log` |
| Release fixture string isolation | Passed | `release-isolation.log` |
| Bash syntax, ShellCheck, diff whitespace | Passed | `static-checks.log` |

The skip is the opt-in physical-host probe. Hosted tests are not UI automation
or VoiceOver verification. Tests cover deterministic unavailable stores,
independent preferences, label/symbol/accessibility, selector/capture isolation,
malformed selectors, future-story rejection and exact 1x capture geometry.

## Capture and comparison

Run `bash docs/evidence/C04.9/capture.sh`, then `bash docs/evidence/C04.9/compare.sh`
from the worktree after building Debug into `.build/c049-native`.
`capture.json` records a real NSStatusBarButton relocated into the existing
synthetic dark host. AppKit y15 corresponds to top-origin y5. The direct 1x
bitmap is 560×44 pixels/points; 1120×88 is diagnostic only. No resampling.

Visual inspection shows the bolt and two minus signs followed by W. Strict,
unmasked tolerance-0.01 comparisons **fail**: frame 24,640/24,640 changed pixels;
item 1,704/1,704. Both comparison JSONs retain `pass: false`, `storyDone: false`.
Diffs, overlays, crops and SHA-256 hashes are retained. The synthetic backdrop
omits Figma wallpaper/system content and does not establish compositor or font
rasterization parity. Independent visual approval, real menu-bar placement,
interaction/VoiceOver and physical telemetry remain unproven. No visual pass.

## Changed implementation paths

- `App/WattApp.swift`: fixture selection, isolated store and native capture routing.
- `Features/MenuBar/Components/MenuBarStatusLabel.swift`: no-reading Delta text/AX.
- `Tests/Fixtures/StoryFixtures.swift`: implemented-story registration.
- `Tests/WattTests/F05FixtureTests.swift`: C049/isolation and affected assertions.
- `DESIGN.md`, `docs/evidence/C04.9/`: design record and reproducible evidence.
