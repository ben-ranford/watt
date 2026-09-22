# G022 / C04.8 — Icon-only status item

Implemented and verified 2026-09-22 in the shared worktree. No commit/checkpoint.
**Native fixture implemented; visual acceptance remains open.**

## Exact contract

Figma file `9DKDgUfEqidZdZQEVlQgLS`: frame `24:1353`, desktop `24:1354`,
anchor `24:1471`, component `24:1469`. Fresh MCP component context is retained
in `component-context.json`: native dark, unselected `battery.100percent.bolt`,
Body/Emphasized SF Pro Semibold 13/16. Existing native `bodyEmphasized` typography
is reused; no text, custom icon, bitmap UI, menu-bar chrome or TCC changes.
The original reference `.omx/plans/f00-reference-evidence/exports/24-1353.png`
is copied byte-for-byte to `reference-24-1353.png`.
Component geometry is **x260/y5, 41×24**, inside **560×44**, ending at x301.

DEBUG selectors `C04.8` and `C04.8/base` use available `sampleCharging`, its
fixed timestamp clock, isolated in-memory preferences and `.iconOnly` mode.
The label has nil text, a visible native SF Symbol, accessibility label
`Watt? power reading` and value `Icon only`. The explicit DEBUG-only
`usesIconOnlyFixture` switch requires fresh fixture-source charging data and
available battery/charger capabilities. Without it, ordinary icon-only behavior
is unchanged; unavailable and noncharging readings retain `bolt.fill` even
with the switch. The switch and launch selector are absent from Release.

## Fresh verification

| Check | Result | Log |
| --- | --- | --- |
| Focused package C041–C048 | 29 passed | `package-focused.log` |
| Focused native hosted C041–C048 | 29 passed | `native-focused.log` |
| Full package | 237 executed, 1 skipped, 0 failures | `package-full.log` |
| Full native hosted WattTests | 237 executed, 1 skipped, 0 failures | `native-full.log` |
| Debug build + analysis | Passed | `debug-build-analyze.log` |
| Release build + analysis | Passed | `release-build-analyze.log` |
| Release fixture isolation | Passed string inspection | `release-isolation.log` |
| Bash syntax, ShellCheck, diff whitespace | Passed | `static-checks.log` |

The skip is the opt-in physical-host metadata probe. Hosted results do not claim
UI automation or VoiceOver traversal. Xcode reports the nonblocking missing
AppIntents dependency metadata-extraction warning. Regression coverage checks
fixture determinism, no text, exact symbol/accessibility value, preserved default
and unavailable symbols, selector/capture isolation and geometry. C04.9–12
remain unavailable.

## Capture and comparison

`capture.sh` reuses the app-owned NSStatusBarButton harness; `capture.json`
records the real button moved to a bounded synthetic dark host, with MenuBarExtra
suppressed only for explicit DEBUG capture. AppKit y15 is top-origin y5.
`actual-status-item-1x.png` is directly drawn at **560×44 pixels and points**;
`actual-status-item.png` is the separate **1120×88** diagnostic. No resampling.
`compare.sh` retains original-size 41×24 item crops, diffs, overlays and hashes.

Strict unmasked tolerance-0.01 comparisons **fail**: frame **24,640/24,640**
changed pixels; item **984/984**. Both JSON reports preserve `pass: false` and
`storyDone: false`. The wrapper accepts diagnostic exit 2 only to retain evidence.
Visual inspection confirms an icon with no text; the synthetic backdrop omits
Figma wallpaper and system-owned menu items and does not prove compositor or
rasterization parity. Independent visual review, live placement, interaction,
AX/VoiceOver and physical telemetry remain unproven. No visual pass is claimed.
