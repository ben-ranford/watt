# C03 / G014 — implementation and native capture evidence

No checkpoint and **no visual pass**. This directory is not a completed visual gate.

## Changes and hierarchy
C03 modifies the existing NSMenu factory and single status-item adapter, not other
screens. Main menu order is Show in Menu Bar / separator / Open Watt? / Settings…
(⌘,) / separator / About Watt? / Check for Updates… / separator / Quit Watt? (⌘Q).
Submenu is Delta / Charger / Draw / Components / separator / Icon, with exactly
one preference-driven checkmark. Main/submenu minimum widths remain the reference 230/190pt. Both request the
public NSMenu 13pt regular system font and state column. Transparent native image
slots (14pt main / 1pt submenu) bring titles to approximately x36 / x37.
AppKit owns text, material, separators, shortcut columns and keyboard/hover states.
The images draw no pixels and have no accessibility description; no menu row is
replaced by an image or custom view. On macOS 27, preferredImageVisibility is
explicitly visible so the system retains the spacing slot.

Open, Settings and Updates call the existing router; About opens the standard panel;
Quit terminates. Tests inject About/Quit handlers without OS side effects.
Incomplete production setup still exposes Finish Setup; base C03 completes setup
in fresh in-memory storage before scene composition so that row is absent.

The native DEBUG launch gate accepts C03 and C03/base before stores, reuses pinned
sampleCharging (+42.1 W) and rejects unknown/malformed/unimplemented selectors.
C01/C02 remain supported. Package executable rejects all fixture launches. Release
has neither selector handling nor capture/fixture types.

## Reference and tokens
Exact file: 9DKDgUfEqidZdZQEVlQgLS; frame 22:1095 (900×460).
Source export: .omx/plans/f00-reference-evidence/exports/22-1095.png.
SHA256: ff92427c65d511524783f5f6f92ef3b39f2f2de5e736c8637c30f9263d451011.
MCP design context retained as figma-context.json (not generated app code).
Frame-relative integral 1x crops, with no masks/resampling:
- 22:1345 main menu: x561 y38 width230 height187.
- 22:1811 submenu: x375 y38 width190 height141.
- Combined reference crop: x375 y38 width416 height187.
Figma typography hint: SF Pro emphasized, 13pt/16pt. Native menu metrics are
system-owned rather than reproducing material using literal RGBA fills.

## Capture method and limitations
Run capture.sh from the worktree after native Debug build. A DEBUG-only app-owned
anchor window invokes the production menu factory with isolated fixture preferences.
An app-local NSApplication.postEvent mouse-move hovers the parent and opens the
real native submenu. The anchor is near the screen right edge so AppKit opens left. Timers
run in the native menu tracking loop. New visible app-owned windows are cached via
NSView.cacheDisplay; capture-attempt.json records actual window classes and geometry.
No AX traversal, TCC prompt, Screen Recording access, global input injection, desktop
screenshot or fake bitmap is used. No second NSStatusItem is allocated.

Both real NSPopupMenuWindow surfaces were captured, at 2x:
native-menu-0.png (460×374), native-menu-1.png (380×282).
The cache is native drawing, not a WindowServer composite: translucent background,
shadow and material may differ. Raw pixels are retained. Explicit sips 1x derivatives
are compared separately against exact crops; overlays/diffs are diagnostic only.
The submenu now opens left with idle checked Delta; the parent is highlighted.
Metadata records parentHighlighted=true, submenuHighlighted=none, deltaChecked=true;
capture.sh asserts this state and requires both native surfaces. Observed main frame
is {{1564,843},{230,187}}, submenu {{1379,889},{190,141}}: top-aligned,
5pt overlap versus the reference 4pt. This is OS edge-aware placement, not a
production placement guarantee. Main titles now start around x36 in both; submenu titles start around x37 native
versus x36 reference. No private inset API/custom row was introduced. The actual selected +42.1 W
status-button pixels and global placement are **not captured**; production selection
highlight is code-wired, not visually verified. Initial direct status-anchor attempt
yielded no capture, so the bounded anchor harness was used instead.

No VoiceOver/AX role audit, physical pointer test or external application shortcut
audit has been performed. Native NSMenu target/action tests are not these audits.
Strict per-menu pixel comparison fails (~99.89% main / ~99.92% submenu changed pixels); see JSON rather
than treating equal bounds or test success as fidelity proof.

## Reproduction / verification
Run bash docs/evidence/C03/verification.sh, then bash docs/evidence/C03/compare.sh
from the worktree root. See corresponding logs and launch-rejection.json. Focused checks include C01/C02 regression,
C03 order, separators, native widths, shortcuts, callbacks, all display selections,
checkmark rebuilding, setup-row conditioning and fail-closed fixture selectors.
Focused package/native suites each pass 29 tests (latest experimental pass).
Full package/native suites each include 203 tests; one physical telemetry opt-in test is skipped.
Build/analyze is run in Debug and Release; fixture strings are checked absent from
Release. SwiftLint is not configured; compiler diagnostics, Xcode analyzer, shell
syntax and git diff --check are the applicable static checks.

## Correction outcome (independent review follow-up)
Historical review score was 74/100; the user supplied 79/100 immediately before
this final focused pass. See the explicitly self-assessed final score below; no
independent replacement review or visual pass is claimed. The native capture now matches the requested interaction state and opening
direction. OS menu material, font rendering, inset and compositor differences remain.

MenuBarStatusLabel now observes the same PreferencesStore passed to the native menu:
Delta uses battery delta; Charger uses the existing charger/fallback value; Draw uses
unsigned system watts; Components shows selected component IDs in preference order
with names and unsigned values; Icon shows only the symbol. Missing readings remain
an em dash, not fabricated zeros. showSymbol applies outside Icon mode; accessibility
values follow the selected mode. Three added tests cover live menu-action-to-label
changes, missing/component values and native font/state-column/no-custom-row contracts.
No P01 model/service or unrelated screen was edited for this correction.

Fresh Debug/Release build + analyze, focused/full package/native tests, Release
isolation, capture-state assertions, shell syntax and diff checks pass. One physical
telemetry test remains opt-in/skipped. The actual SwiftUI status-button repaint and
physical pointer/VoiceOver/TCC-dependent compositor capture are not verified by
these model/target-action tests. No checkpoint was made.

## Historical focused correction pass — 2026-09-21 (superseded below)

**83/100 self-assessed visual score**, compared with the user-provided prior 79/100.
This is a subjective side-by-side review, not an independent calibrated acceptance
score or a pixel similarity percentage. Rubric: structure 25/25, geometry 24/25,
typography 16/20, material 8/20, interaction state 10/10. `visual-review.json`
records the rubric and limitations. Exact reference-menu/reference-submenu and final
native-menu-1x/native-submenu-1x images were viewed directly with view_image.

Retained: transparent native image spacing and an explicit regular NSMenu.font
request. Main inset improves from ~16 to ~36pt; submenu from ~30 to ~37pt, versus
~36pt reference. Native bounds remain 230×187 / 190×141pt, left-opening submenu,
parent highlighted, idle Delta checked. Title/order/shortcuts/target-action/display
mode wiring are unchanged; native semantics remain, without claiming a runtime AX audit.

Experiments: 16/2pt image slots produced ~38pt titles; narrowed to 14/1pt. Explicit
regular-font attributedTitle was also tried and did not visibly resolve the heavier
OS font, so it was removed. Forcing NSMenu.appearance to vibrantDark also left the
cached surface near-black, not blue-gray; removed to retain system/light/dark and
accessibility appearance inheritance. Experimental PNGs/logs are under
`appearance-experiment/` (the initially copied 1x files use 16/2pt slots; the
vibrant-dark raw captures use 14/1pt slots and attributed titles).

Platform limit: macOS 27.0 (26A428) owns standard NSMenu material and separator
geometry. Public NSMenu/NSMenuItem APIs offer no per-menu material tint or separator
inset setting. The native main separators remain about x16 vs reference x11;
submenu separators about x30 vs reference x11. No private window/view manipulation,
custom separators, fake desktop, bitmap menu or global appearance preference change
was used. In-process cacheDisplay is not a WindowServer vibrancy composite, so this
cannot prove what backdrop blending looks like on the desktop. Even regular font
requests still yield visibly heavier text here. These remain explicit visual gaps.
API basis: installed Xcode AppKit NSMenu.h/NSMenuItem.h and Apple's
[NSMenuItem documentation](https://developer.apple.com/documentation/appkit/nsmenuitem).

Final verification: 28 focused tests each for package/native; 202 full tests each
with one physical-host opt-in skip and zero failures. Debug and Release build/analyze,
Release fixture isolation, native capture-state assertions, shell syntax/ShellCheck
and diff whitespace pass. SwiftLint is not configured; compiler/analyzer checks
provide applicable static validation. Strict pixel diagnostics still fail with
99.886% main / 99.922% submenu changed pixels. No visual pass, checkpoint, commit or
further correction cycle is claimed. This requested bounded pass is finished.


## Latest bounded custom-view feasibility pass — 2026-09-21

**Incoming user-provided score: 84/100. No new score or visual pass claimed.**
That newer baseline supersedes the earlier 83/100 self-assessment. Production menu
rendering is unchanged in this pass: the experiment failed the native-behavior gate.
There is no justified safe visual improvement beyond the existing regular-font
request, transparent image insets and inherited appearance. No checkpoint or commit.

### Isolated experiment and rejection
`custom-view-experiment/run.sh` compiles a standalone AppKit probe with Swift 6 and
warnings-as-errors, outside all application targets. It opens a native menu in two
separate processes: standard rows, then NSMenuItem.view rows containing a regular
13pt NSTextField on an active NSVisualEffectView with `.menu` material and
`.withinWindow` blending. An NSMenuDelegate observes opening/highlighting; local
NSEvents send Down / Right / Down / Return. Neither experiment modifies a native
menu window or installs global events. Raw native caches and event JSON are retained.

Repeated runs on macOS 27.0 (26A428) observed:
- Both preserve titles, attached submenu, stored Delta check state, and dispatch
  the Settings Command-comma shortcut through the original target/action.
- Standard rows open the submenu, highlight Delta then Charger, and invoke Charger
  with Return. The custom-view trial opens the submenu, but does not invoke the
  selected action with that sequence and reaches the 1.5s fallback cancel.
- Custom caches show regular labels but no native checkmark, chevron, shortcut
  glyph or selected blue row. Those are drawing responsibilities transferred to
  the view, not evidence that model properties disappeared. `.menu` material is
  still dark gray, with row-local surfaces, not the reference's continuous blue-gray
  translucent surface and thin rounded border.

This is a **minimal rejected candidate**, not proof that all custom menu views are
inaccessible or that NSMenu stops navigating them. In particular, keyboard shortcut
and submenu opening work. But restoring the missing drawing, activation and AX
behavior would require additional custom implementation and verification beyond a
safe bounded correction. No such rows were applied to Watt; no runtime VoiceOver
or cross-process AX audit is claimed. Existing native rows remain the safer path.

### Public API boundary
Apple's [Views in Menu Items](https://developer.apple.com/library/archive/documentation/Cocoa/Conceptual/MenuList/Articles/ViewsInMenuItems.html)
explains that custom views own standard drawing, retain shortcut/type-select lookup,
do not receive keyboard events, and must not alter the containing menu window.
The installed SDK `NSMenu.h` delegate callbacks cover population, key equivalents,
tracking/highlighting and confinement, not a background/material view replacement.
Apple's [NSMenuDelegate](https://developer.apple.com/documentation/appkit/nsmenudelegate)
and [NSVisualEffectView](https://developer.apple.com/documentation/appkit/nsvisualeffectview)
do not provide a supported menu-wide tint/border installation hook. A visual-effect
view in a custom row only owns that row; reaching into AppKit's private window/view
hierarchy to recolor the full surface was rejected, not attempted. CacheDisplay
still cannot validate WindowServer vibrancy/backdrop composition.

### Verification and independent-comparison handoff
- Added production factory regression coverage for actual native Command-comma /
  Command-Q dispatch, rejection without Command, submenu ownership, nonempty titles,
  targets/actions and absence of custom rows. Quit is injected, not executed.
- Fresh package/native focused suites: **29 each, zero failures**.
- Fresh package/native full suites: **203 each, one physical telemetry opt-in skip,
  zero failures**. Debug/Release build + analyze and Release fixture isolation pass.
- Native capture again proves selected parent, idle checked Delta, two native popup
  windows and reference-sized 230×187 / 190×141pt surfaces. Comparison was regenerated;
  strict pixel diagnostics still fail (99.886% main / 99.922% submenu changed).
- Shell syntax, ShellCheck, diff whitespace and probe warnings-as-errors pass.
  SwiftLint is not configured. Xcode emits existing XCTest deployment-target and
  unused AppIntents metadata warnings; host service logs are not test failures.
- `independent-review-assets.json` hashes the refreshed raw caches, exact reference
  crops, explicit 1x derivatives, overlays/diffs and experiment outputs.
  `INDEPENDENT-REVIEW.md` is a side-by-side handoff for an independent reviewer.
  No independent reviewer was available in this leaf execution surface; asset
  preparation is **not** an independent verdict. No higher score is invented.

Remaining gaps: background hue/translucency/border, heavier production text,
separator insets, 1pt submenu inset/overlap, physical interaction, VoiceOver,
actual status-button repaint/position and compositor capture. Bounded pass complete;
C03 visual acceptance remains open.

## App-owned WindowServer capture probe — 2026-09-21

The requested public `CGWindowListCreateImage` candidate failed SDK availability
before integration: Swift reports it unavailable/obsoleted in macOS 15.0 under the
installed macOS 27 SDK. The compile-only probe scopes the proposed call to one
PID-verified app-owned `NSPopupMenuWindow`; no image capture or permission request
ran. [Probe source, diagnostics and disposition](windowserver-probe/README.md).
No resulting images exist for Figma comparison. Both production source and the
existing DEBUG cacheDisplay path are unchanged. This is not evidence of a blank
runtime surface or a TCC denial, and no visual pass or checkpoint is claimed.
