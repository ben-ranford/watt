# G075 / J12.3 — uninstalled, no Watt UI
Exact Figma file 9DKDgUfEqidZdZQEVlQgLS / node 35:5599. MCP context,
metadata, variables and screenshot responses are saved as figma-*.json.
reference.png is the exact user-provided export; screenshot.png is the fresh MCP
export. reference.sha256 checks both downloaded files. Neither is an app asset.

The inspected 1000×220 reference shows system wallpaper and trailing system menu
bar only. Desktop Template 35:5600 is offset -512; Finder/File/Edit/View/Menu
Item/Window/Help exist in metadata/context outside the left crop. No Watt-owned
pixels, window, status item or Dock should be fabricated.

Fresh MCP retrieval on 2026-09-23 is pinned in `fresh-figma/context-2026-09-23.md`, `fresh-figma/reference-2026-09-23.png` and `fresh-figma/live-ax-2026-09-23.log` (SHA-256 `dbb12c0ff5fdb072f77626740af6954b710d6f046cf2feb622ae660e7f506a84`).

## Implementation and boundary
AppRouter consumes exact J12.2 confirmation; configureUninstall binds a scoped
P05 adapter and requires all four ownership categories. P05 verifies inventory,
helper/app absence, and login/settings cleanup. Retries retain their receipt.
Only verifiedAbsent closes presentation and invokes the WattApp native termination
callback. Failure, unknown status, interrupted or cancelled removal cannot report
completion. Existing helper-removal behavior is preserved.

There is deliberately no default production filesystem/process removal driver.
Real installation removal is NOT verified on this host; no files outside evidence
and source were removed, no login registrations changed and no helper stopped.
The DEBUG-only J12.3/base launch exits before stores/scenes/status items are
constructed. This is the explicitly permitted controlled no-Watt verification,
not a simulated successful uninstall.

## Reproduction
Run bash docs/evidence/J12.3/verify.sh. All Swift commands use
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer. The first ad-hoc focused
test command used CommandLineTools and failed on missing SwiftUIMacros; that
toolchain failure is superseded by the Xcode-toolchain runs, not a final source
failure. See *.exit/*.log and verification.json for final results.

capture.sh runs only the controlled fixture, waits for its process exit, then
collects read-only compositor/AX/TCC evidence. It neither grants permission nor
activates Finder, changes wallpaper/Dock, hides unrelated apps, or synthesizes a
desktop. Capture requires a real visible compositor, authorized AX/screen capture,
Finder frontmost, and no observed Watt windows. A capture, if possible, still
requires inspection; null metrics are retained absent a valid comparison.

The downloaded reference and fresh MCP screenshot have identical SHA-256
dbb12c0ff5fdb072f77626740af6954b710d6f046cf2feb622ae660e7f506a84.
The historical F00 registry export hash differs; its archived provenance record
is intentionally not rewritten. Current exact bytes/checksum are in this folder.

## Changed source surfaces
- App/AppRouter.swift: scoped P05 composition, full-category gate, retained retry
  receipt, terminal completion state and one-shot termination callback.
- App/WattApp.swift and App/J123FixtureLaunch.swift: native termination wiring and
  DEBUG-only early no-Watt exit.
- Tests/Fixtures/{StoryFixtures,FixtureLaunchSelection}.swift: exact base registry.
- Tests/WattTests/{J123UninstalledTests,F05FixtureTests}.swift: behavior and registry.
- Watt.xcodeproj/project.pbxproj: source/test membership.
- DESIGN.md, SCREEN-BACKLOG.md: system ownership and explicit verification gaps.

No new dependencies, app visuals, broad removal primitives, commit or worktree.
Pre-existing dirty worktree content was retained.

## Final verification
- Focused J12/P05/NativeStyling: **57 tests, 0 failures**.
- Full suite: **651 tests, 5 skipped, 0 failures**. The intermediate F05 expected
  implemented-ID list failure was fixed by registering J12.3 in its assertion.
- Debug: build, analyze and build-for-testing passed.
- Release: app build/analyze passed; binary fixture-isolation checks passed.
- Release build-for-testing: attempted, exit 65; existing WattTests dependency
  cannot resolve a compatible Watt module (first error J108HelperUpdateTests.swift:5).
- Static: diff whitespace, Xcode plist, exact image checksums and Release
  nm/strings isolation passed. No separate lint configuration was introduced.
- Controlled launch: exit 0; no Watt windows in compositor inventory.
- Capture: exit 1; AX untrusted and Terminal frontmost. No native screenshot
  captured, no valid pixel comparison; visual score and pixel_diff are null.

Fresh controlled no-Watt launch exited cleanly; the normal Desktop app was deliberately left running, and no real removal or visual pass was claimed.
