# G048 / J5.2 — panel Finish setup prompt

Exact source: [Figma node 30:4028](https://www.figma.com/design/9DKDgUfEqidZdZQEVlQgLS/Watt-?node-id=30-4028).
`reference.png` is the supplied `/tmp/watt-g048-reference.png`, inspected locally and
pinned with its SHA-256 in `reference.json`. No new Figma query was made. The supplied
1000 × 720 light reference contains a 320 × 319-point panel at (645, 38).

## Implementation

`StatusPanelView` and `MenuBarRootView` share the existing native panel. A native
GroupBox above the charging summary contains **Finish setup**, **2 steps left** and
a bordered-prominent **Continue…** button. Deferred setup shows only the existing
native grouped power rows: Charger input **65.0 W**, System draw **22.9 W**, Battery
**+42.1 W** in the fixture. The summary remains Charging / +42.1 W / 64% · full in
about 38 min. Settings… and Quit Watt? keep their production callbacks. The actual
MenuBarExtra owns the selected +42.1 W status item; no selection or desktop is painted.

SwiftUI/AppKit own controls, font metrics, material and accessibility. Application
surface dimensions live in WattSpacing; the save-error state allows extra height.
The DEBUG fixture requests light Aqua; production keeps native system appearance.
No custom controls, new dependencies, helper approval or live telemetry is invented.

The two-step prompt is eligible only for incomplete welcomeClosed/runningDefaults.
Continue captures the onboarding snapshot and panel presentation identifier. AppRouter
rejects closed/replaced panels, changed/completed state and repeated callbacks. The
shared atomic PreferencesStore transition saves J1.2's picker checkpoint before opening
onboarding, clears the deferred coach-mark identifier, and keeps setup incomplete.
Other preferences and helper state survive. Failed writes preserve memory and disk,
show “Couldn’t save. Try again.” and leave Continue available to retry. Explicit reopen
shares AppRouter's resume path. Opposing stale coach-mark actions cannot override it.

## Reproduction and verification

```sh
bash docs/evidence/J5.2/verify.sh
bash docs/evidence/J5.2/capture.sh
```

The first command runs fresh focused/full package tests, package build, Debug/Release
host build + analyze, focused/full host unit tests and tracked/untracked slice diff
checks. It stops on a failed prerequisite. The new behavior tests cover state gating,
write-before-route ordering, persisted restart, failed-write retry, stale/replaced
presentations, repeated/opposing actions, exact copy/values, footer callbacks and native
host size. Fixture tests cover registration, base-only launch, rejection and isolation.
In-process size/callback tests do not prove rendered row visibility or live interaction.

`--watt-fixture J5.2/base` uses the native Debug app, isolated memory preferences,
frozen preview telemetry, incomplete runningDefaults and the real status-anchor path.
Unsupported variants fail closed; the package executable rejects fixture launch.
Release excludes J52FixtureLaunch.

Capture runs after host tests, targets only the launched fixture PID's actual compositor
windows, and cleans up that process. It neither requests permissions nor synthesizes a
replacement window. Its output directory rejects reuse to prevent stale evidence.
`capture/window.json` records access preflight and window discovery. Missing comparable
pixels keep nativeCapture, score and pixel_diff null, visualPass=false and storyDone=false.
Keyboard, pointer and VoiceOver acceptance require separate live evidence.

## Changed files

- App/AppRouter.swift and App/WattApp.swift
- Features/MenuBar/Views/StatusPanelView.swift and MenuBarRootView.swift
- DesignSystem/Theme/WattSpacing.swift
- Tests/Fixtures/{StoryFixtures,StoryFixtureData,FixtureLaunchSelection}.swift
- Tests/WattTests/J52FinishSetupTests.swift and F05FixtureTests.swift
- Watt.xcodeproj/project.pbxproj, DESIGN.md and SCREEN-BACKLOG.md
- docs/evidence/J5.2: pinned reference, reproduction scripts, logs and JSON evidence

Pre-existing worktree changes were retained. No commit or OMX goal-state mutation.
Verification results and visual limitations are recorded below and in verification.json
and visual-review.json.


## Fresh results

- Focused package: **79 tests, 0 failures**; full package: **414 tests, 1 skipped, 0 failures**.
- Focused host: **45 tests, 0 failures**; full host: **402 tests, 1 skipped, 0 failures**.
- Package build, Debug/Release host build + analyze, tracked/untracked diff checks: **exit 0**.
- The existing physical-host public API smoke test is opt-in and skipped in both full suites.
- The first diff check caught a trailing blank line in verify.sh; it was removed and the
  check rerun successfully. No test or build failures occurred.
- Capture: **exit 1**, zero PID-owned on-screen compositor windows; Screen Recording
  preauthorized, **AXTrusted=false**. No native PNG exists.
- **nativeCapture=null; score=null; pixel_diff=null; visualPass=false; storyDone=false**.
  Rendered clipping/row visibility, selected status-item pixels and live interaction remain
  unverified. No visual acceptance is claimed.

Compiler diagnostics retain the pre-existing actor-isolation warning in
OnboardingFlowView.swift:200, AppIntents metadata notices, and package unhandled-file
warnings from the worktree build directory. No separate lint tool is configured; compiler
checks and Xcode analyze passed. Pre-existing changes are preserved; no commit.
