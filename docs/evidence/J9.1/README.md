# J9.1 — Settings → Remove… (confirm)

Fresh MCP retrieval on 2026-09-23 is pinned in `fresh-figma/context-2026-09-23.md` and `fresh-figma/reference-2026-09-23.png` (SHA-256 `92852f996cfa3c25886d6bf1bc29bed9a5bca4c16d419ef264796be882003e80`).

G062, exact Figma `9DKDgUfEqidZdZQEVlQgLS / 32:5397`, 1000×720.
Fresh MCP context, metadata/hierarchy, screenshot response and downloaded bytes
are retained here. Both fresh screenshot sources hash to
`92852f996cfa3c25886d6bf1bc29bed9a5bca4c16d419ef264796be882003e80`.
The historic manifest export has a different hash; neither is represented as a
native capture. The reference screenshot was visually inspected.

## Implementation and interactions

- Existing native Settings scene, grouped Form, shared helper rows and SwiftUI
  alert; no desktop/window/alert chrome recreation.
- Exact title **Remove the helper?** and message **Components stop and the menu
  bar switches to Delta. Turn it back on any time.**
- Remove… only presents the alert. Native Cancel is a no-op. Destructive Remove
  calls the existing verified removal boundary. Only verified absence disables
  component readings and changes display mode to Delta; selected components
  are preserved. Failed/cancelled/unverified removal never claims success.
- Native alert supplies keyboard/default/cancel semantics; live keyboard and
  AX interaction remain unverified, not inferred from source or tests.
- Debug-only `J9.1/base` composes the existing Settings scene with J7.2's
  deterministic CPU/GPU values and an explicitly injected fake helper. The
  fixture removal adapter returns cancellation and never touches installed
  resources. Production still uses the existing safe removal adapter.
- The explicit requested section name is Component Readings; the retrieved
  screenshot visibly uses Helper. This difference is recorded, not concealed.

## Changed files

`Features/Settings/Views/SettingsRootView.swift`, `App/AppRouter.swift`,
`App/WattApp.swift`, new `App/J91FixtureLaunch.swift`,
`Tests/Fixtures/{StoryFixtures,FixtureLaunchSelection}.swift`,
new `Tests/WattTests/J91RemoveHelperTests.swift`, affected assertions in
`Tests/WattTests/{F05FixtureTests,J25SettingsConnectedTests,J73ChooseComponentsTests}.swift`,
`Watt.xcodeproj/project.pbxproj`, `DESIGN.md`, `SCREEN-BACKLOG.md`, and this directory.
Existing cumulative edits were preserved; no commit was made.

## Verification and reproduction

- `swift test --filter J91RemoveHelperTests`: six pass.
- `swift test`: 567 executed, five skipped, zero failures.
- Native Xcode Debug and Release builds and both configurations' analyzer pass.
- Release binary has no J91 fixture selector, capture flag, or fixture class.
- Project plist lint, shell syntax, image hash validation and `git diff --check`
  pass. Native XCTest compiled but host startup stalled; an isolated retry was
  terminated after 178 seconds without test results. Native execution remains
  blocked, not passed. Attempts/results are recorded in `verification.json`.

Run from this worktree with `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer`.
Build: `xcodebuild -project Watt.xcodeproj -scheme Watt -destination 'platform=macOS' -configuration Debug build`
(and `Release`; use `analyze` for static analysis).
Native tests use `-only-testing:WattTests test` with an isolated derived-data
path to avoid capture builds mutating their test host.
Capture: `bash docs/evidence/J9.1/capture.sh` (move the prior capture directory
aside first; the script deliberately refuses to overwrite prior evidence).

## Honest render boundary

Final capture launched PID 60337 (initial attempt PID 58671 retained separately) from the native Debug app. Screen capture was
preauthorized, but AX trust was false and the compositor returned no PID-owned
windows. No native Settings identity or live alert pixels could be proven.
The process was terminated and reaped. See `capture/window.json`, `capture.log`
and `capture/process-cleanup.log`. Score and pixel diff remain null.

The script verifies PID ownership and exact alert AX copy before attempting
capture. A Settings-only screenshot is not marked comparable to the full alert
reference. Visual acceptance and live Remove…/Cancel/Remove/keyboard traversal
remain blocked on an accessible native GUI session; this story is not claimed
visually accepted. Domain/navigation semantics are covered by tests.

Fresh native AX probe on 2026-09-23 is retained at `fresh-figma/live-ax-2026-09-23.log`; the native status item registered, but no accepted fixture-owned Settings/alert window was available, so visual and live alert acceptance remain open.
