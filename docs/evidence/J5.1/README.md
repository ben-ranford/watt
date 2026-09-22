# G047 / J5.1 — welcome closed, running with defaults

Implementation present; native visual/AX acceptance is a separate gate. No commit.

## Exact reference and native implementation

Exact node **30:3675**, [Figma frame](https://www.figma.com/design/9DKDgUfEqidZdZQEVlQgLS/Watt-?node-id=30-3675).
The user supplied `reference.png`; it was inspected locally. `reference.json` records its
actual SHA-256, dimensions, exact copy and provenance. No fresh Figma retrieval is claimed.

The existing `CoachMarkView` supplies a light, top-trailing native popover:

- **Watt? is on, showing Delta.**
- Setup can wait. Two steps, whenever you’re ready.
- **Not Now** → persisted incomplete running-defaults state and running panel.
- **Finish Setup** → persisted picker checkpoint and onboarding window.

SwiftUI owns semantic text and native bordered/default buttons. AppKit owns popover
chrome, material, arrow and screen-edge positioning. The anchor is the actual MenuBarExtra
button's trailing edge. No custom controls, dependencies, wallpaper or fake menu bar.
J1.7 retains its existing copy, size and inherited appearance.

## State and safety

Native welcome close and Escape persist Delta, `welcomeClosed` and a fresh prompt UUID.
Commit occurs before publishing state or navigating, without a fallible rollback write.
Both buttons require the matching UUID and incomplete pending checkpoint, clear the UUID
on success, and reject stale/repeated/opposing actions. Other preferences and helper opt-in
are retained; setup is never marked complete. Write failures retain memory/disk and expose
retry copy in the popover. Escape stays open on failure; native close preserves welcome for
reopen, without claiming a successful deferral.

Relaunch restores a pending prompt or quietly continues after Not Now. Explicit reopen
resumes deferred setup at the picker. The existing context-menu picker action now guards
its captured state and write success too; other journey acceptance is not claimed here.

## Tests and reproduction

From the repository root:

```sh
bash docs/evidence/J5.1/verify.sh
bash docs/evidence/J5.1/capture.sh
```

Verification records fresh focused/full Swift package tests, package build, Debug/Release
host builds plus analyze, focused/full host unit tests, and diff check. No independent lint
tool is configured; compiler diagnostics and Xcode analyze supply type/static checks.
The new J5.1 suite covers exact copy/fixture, persistence ordering, failed writes and retry,
wrong/completed/stale tokens, a newer prompt rejecting an old callback, relaunch/reopen,
legacy decoding, and the native light transient-popover contract. The J4.1 test now lays
out the native host before closing it and verifies actual close-notification wiring.

The fixture `--watt-fixture J5.1/base` is Debug-only, in-memory and fixed-telemetry; it uses
the production MenuBarExtra/StatusAnchorView path. Unknown variants fail closed. Package
executables reject fixture launches; run the built native Debug app for capture.

## Evidence gate

`verification.json` records final counts, exits and hashes. `visual-review.json` records
capture/AX status. `capture/window.json` records PID-owned compositor windows and access
preflight without prompting for permissions. Capture runs after host tests, with a scoped
process cleanup trap. Missing comparable native capture yields null score/pixel diff,
visualPass=false and storyDone=false; no offscreen substitute counts as visual acceptance.
Pointer/keyboard/VoiceOver interaction is not proven by unit tests.

## Files in this slice

- `App/AppRouter.swift`, `App/WattApp.swift`
- `Models/WattPreferences.swift`
- `Features/Onboarding/Views/OnboardingFlowView.swift`
- `Features/MenuBar/Views/StatusItemContextMenu.swift`
- `DesignSystem/Theme/WattSpacing.swift`
- `Tests/Fixtures/{StoryFixtures,StoryFixtureData,FixtureLaunchSelection}.swift`
- `Tests/WattTests/{J51WelcomeClosedTests,J41WelcomeDesktopTests,NativeStylingTests,F05FixtureTests,J13OfferTests,AppRouterTests}.swift`
- `Watt.xcodeproj/project.pbxproj`, `DESIGN.md`, `SCREEN-BACKLOG.md`
- `docs/evidence/J5.1/`: reference, reproduction scripts, fresh logs/exits, verification and visual review.

Pre-existing worktree changes were retained. No commit or OMX goal-state mutation.

## Final fresh verification

- Focused package: **70 tests, 0 failures**; full package: **403 tests, 1 skipped, 0 failures**.
- Focused host: **36 tests, 0 failures**; full host: **391 tests, 1 skipped, 0 failures**.
- Package build, Debug/Release host build + analyze, tracked/untracked slice diff checks: **exit 0**.
- The existing physical-host public API smoke test is opt-in and skipped in both full suites.
- Initial full-package failure exposed missing router injection in older fixture/test hosts;
  those hosts were repaired before the final fresh run. The logs here contain final results.
- Final capture: **exit 1**, no PID-owned on-screen compositor windows; screen capture
  preauthorized, **AXTrusted=false**. No comparable PNG exists.
- **visualPass=false; storyDone=false; score=null; pixel_diff=null**. Visual, keyboard and
  VoiceOver acceptance remain blocked. No commit.

The package still reports pre-existing unhandled files from the worktree's build directory;
this does not fail compilation. No independent lint tool is installed/configured for this slice.
