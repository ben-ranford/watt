# G049 / J5.3 — native right-click Finish Setup…

Exact source: [Figma node 30:4788](https://www.figma.com/design/9DKDgUfEqidZdZQEVlQgLS/Watt-?node-id=30-4788).
The user-supplied `reference.png` was inspected locally and pinned by SHA-256 in
`reference.json`. No new Figma retrieval or replacement reference was used.
The 1000 × 720 light reference shows Finish Setup… highlighted in a native menu.

## Native implementation

The existing status-item bridge opens the production NSMenu on secondary/control click.
Its exact content is:

1. Finish Setup… (only while setup is incomplete), followed by a native separator.
2. Show in Menu Bar submenu, followed by a native separator.
3. Open Watt? and Settings… (Command-,), followed by a native separator.
4. About Watt? and Check for Updates…, followed by a native separator.
5. Quit Watt? (Command-Q).

AppKit owns menu chrome, separators, checkmarks, submenu arrow, selected/hover states,
keyboard tracking/equivalents, material, font metrics and accessibility. No custom
item views or painted menu chrome are used. The submenu preserves Delta, Charger,
Draw, capability-gated Components, separator, Icon and the conditional Turn On Helper…
action. Production appearance stays system-owned.

The Finish Setup… callback captures the onboarding snapshot and a menu presentation
identifier. AppRouter checks that the menu is current and the state remains incomplete
and unchanged. Its shared persisted transition writes the J1.2 picker checkpoint and
clears the deferred prompt identifier before presenting onboarding. Setup remains
incomplete; all other preferences and helper state survive. Closed/replaced menus,
completed/changed state, callbacks after routing, and repeated callbacks cannot write
or navigate. Each menu allows one attempt, including persistence failure; reopening
provides a fresh retry. The native popup's synchronous return invalidates cancellation,
without incorrectly expiring the callback at menuDidClose before native action delivery.
J5.2's deferred-only prompt continues to use the shared transition and its existing retry.

## Fixture and reproduction

```sh
bash docs/evidence/J5.3/verify.sh
bash docs/evidence/J5.3/capture.sh
```

Verification selects the installed Xcode toolchain and runs fresh focused/full package
tests, package build, Debug/Release host build + analyze, focused/full host unit tests,
and static/diff checks. J53 tests are registered in both package and native host targets.
F05 tests validate registry content, base-only launch, rejection and isolated state;
J51/J52, menu/panel, router and native-styling tests cover affected regressions.
No separate lint configuration exists; compiler/typecheck, analyze, script syntax,
JSON/native-contract and tracked/untracked whitespace checks provide static validation.

`--watt-fixture J5.3/base` alone launches the native Debug fixture through the real
status-item bridge, using light Aqua, fresh in-memory preferences, incomplete
runningDefaults and frozen +42.1 W preview telemetry. Unsupported variants fail closed.
The package executable rejects fixture launches; Release excludes fixture registration.
No helper approval, live service, user preference, desktop art or replacement menu is
invented. The fixture's app-local hover asks AppKit to highlight the first row and records
the observed result; it does not establish live pointer/keyboard acceptance.

Capture requires a new output directory and cleans up only its launched process.
J5.3 records menu window identity during native tracking and leaves tracking active for
the external capture. The Swift script requires preauthorized screen capture and AX
trust, then matches the fixture PID and native menu window number to live compositor
ownership before using screencapture. Unknown native window classes fail closed.
It never requests permissions, captures a desktop substitute or scores cached view pixels.
`capture/window.json` records the actual access/window evidence. Missing verified pixels
or AX trust leaves nativeCapture, score and pixel_diff null, visualPass=false and
storyDone=false. Native hover, submenu navigation, Escape, keyboard shortcuts and
VoiceOver still need live acceptance evidence even when unit tests pass.

## Files and verification scope

- App/AppRouter.swift and App/WattApp.swift: shared guarded resume and native fixture bridge.
- Features/MenuBar/Views/StatusItemContextMenu.swift: native menu lifecycle and exact content.
- Tests/Fixtures/{StoryFixtures,StoryFixtureData,FixtureLaunchSelection}.swift: registration.
- Tests/WattTests/J53FinishSetupTests.swift, J51WelcomeClosedTests.swift, J21ComponentsUnavailableTests.swift and F05FixtureTests.swift.
- Watt.xcodeproj/project.pbxproj, SCREEN-BACKLOG.md and DESIGN.md.
- docs/evidence/J5.3: exact reference, reproducible scripts, logs and JSON evidence.

Existing cumulative changes were preserved. No commit and no OMX runtime state mutation.
Fresh results are recorded in verification.json and visual-review.json.


## Fresh results

- Focused package and focused host: **94 tests each, 0 failures**.
- Full package: **425 tests, 1 skipped, 0 failures**.
- Full host: **413 tests, 1 skipped, 0 failures**.
- Package build, Debug/Release build + analyze, static and diff checks: **exit 0**.
- The existing physical-host public API smoke test is opt-in and skipped in both full suites.
- Capture: **exit 1**, **0 app-owned on-screen compositor windows**, Screen Recording
  preauthorized, **AXTrusted=false**. No native PNG or menu identity metadata was produced.
  The fixture PID was terminated and reaped; no permission prompt was requested.
- **nativeCapture=null; score=null; pixel_diff=null; visualPass=false; storyDone=false**.

The first full package run exposed two J2.1 tests that assumed the submenu was row zero.
They now locate Show in Menu Bar by title so incomplete setup can insert its first row;
the failed log is retained as package-tests-initial.log and the fresh full suite passes.
An early compile check caught the new diagnostic timer capturing a non-Sendable NSMenu;
its menu reference is now main-actor isolated and all final builds pass. A separate early
probe using CommandLineTools lacked SwiftUI macro support; verify.sh selects full Xcode.
The scoped independent code review found no remaining actionable defects.

Existing diagnostics remain: OnboardingFlowView.swift:200 actor-isolation warning,
AppIntents metadata notices, and package unhandled-file warnings for worktree build
artifacts. They did not fail build/analyze. No visual or live accessibility acceptance
is claimed. All files remain in this worktree, uncommitted.
