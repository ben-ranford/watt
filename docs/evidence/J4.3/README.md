# G046 / J4.3 — panel, system draw only

Native implementation present; **visual/AX/live acceptance blocked**, not story complete. No commit.

## Exact design and implementation
Figma file `9DKDgUfEqidZdZQEVlQgLS`, exact node **30:2786**, panel **30:2930**.
Loaded design-to-code and SwiftUI skills before MCP. Retrieved exact context, screenshot,
hierarchy, variables and header context. `reference.json` pins screenshot bytes, hierarchy,
variants, tokens, asset inspection and native mapping decisions.

The native shared panel shows Drawing, 38.2 W, “Mac Studio · no battery, so it’s all draw”,
CPU 14.6 W, GPU 11.2 W, SSD 1.9 W, Other 10.5 W. Values/model name are Debug
fixture data only. Production requires explicit noBattery + unsupported battery capabilities
and uses service-supplied system draw; no battery/charger rows are shown. Off/lost helper,
permission-required, stale and unavailable states retain truthful shared presentation.
Unknown telemetry does not imply desktop hardware. Battery AX label/summary remain intact;
desktop AX uses System draw status and system watts.

Entry uses native status-item panel presentation, also reached through setup/coach-mark.
J4.2 retains J1.3 helper offer before completion, as the exact frame name indicates;
historical direct-panel shorthand is not permission to fabricate approval. Settings/Turn On
reuse settings navigation; Quit uses the production termination callback. Native
MenuBarExtra owns dismissal/chrome; no custom painted controls or new dependencies.

## Native styling audit repair
See `native-repair-plan.md`. Removed negative margins and fixed row/form heights from
helper facts, preview and login Forms; native columns Form provides intrinsic sizing.
Removed fixed all-set/preview content heights. Title2/footnote use semantic styles.
Shared panel/coach-mark surface dimensions live in WattSpacing; duplicate root width is
deleted. DESIGN now distinguishes reference measurements from normative native behavior.
Existing copy/actions/persistence remain covered. Earlier visual evidence for affected
onboarding screens is historical and is not renewed by these unit tests.

## Verification and reproduction
Run from the repository root:
```sh
bash docs/evidence/J4.3/verify.sh
bash docs/evidence/J4.3/capture.sh
```
The verification script overwrites logs and exit files for focused/full package tests,
package build, Debug/Release host build+analyze, host unit tests and diff check.
Final results are recorded below and in `verification.json`; earlier failures are not
acceptance evidence. No independent lint tool is configured; compiler diagnostics and
Xcode analyze provide type/static checks. No live AX/UI interaction test is claimed.

## Capture / fail-closed acceptance
The capture helper records only PID-scoped live compositor windows, preauthorization and
AX trust. It does not request permissions, synthesize a desktop or replace native chrome.
The first attempt had no capturable window and AXTrusted=false. Retry after verification
rules out competing host tests. See `capture-final/window.json`, logs, `capture.exit`
and `visual-review.json` for the final result. Missing comparable live capture or AX
verification means null score and pixel diff, visualPass=false and storyDone=false.
Real desktop draw/helper telemetry remains an upstream production-service proof gap;
fixture values are not hardware evidence.

## Final post-fix result
- Focused: **53 tests, 0 failures**.
- Full package: **387 tests, 1 skipped, 0 failures**.
- Full host unit suite: **375 tests, 1 skipped, 0 failures**, TEST SUCCEEDED.
- Package build, Debug/Release host build + analyze, diff check: **exit 0**.
- Final isolated capture retry: **exit 1**, no app-owned compositor window; screen capture
  preauthorized but **AXTrusted=false**. No successful native PNG exists. This is the exact
  bounded blocker, not a visual pass. Both attempts left no fixture process running.
- Null score/pixel diff; visualPass=false, storyDone=false. No commit or goal-state changes.

## Exact files changed in this slice
- `App/WattApp.swift`
- `Features/MenuBar/Views/StatusPanelView.swift`
- `Features/MenuBar/Views/MenuBarRootView.swift`
- `Features/Onboarding/Views/OnboardingFlowView.swift`
- `DesignSystem/Theme/WattTypography.swift`
- `DesignSystem/Theme/WattSpacing.swift`
- `Tests/Fixtures/StoryFixtures.swift`
- `Tests/Fixtures/StoryFixtureData.swift`
- `Tests/Fixtures/FixtureLaunchSelection.swift`
- `Tests/WattTests/J43PanelSystemDrawTests.swift`
- `Tests/WattTests/F05FixtureTests.swift`
- `Tests/WattTests/AppRouterTests.swift`
- `Tests/WattTests/NativeStylingTests.swift`
- `Tests/WattTests/J13OfferTests.swift`
- `Tests/WattTests/J15PreviewTests.swift`
- `Tests/WattTests/J16AllSetTests.swift`
- `Watt.xcodeproj/project.pbxproj`
- `DESIGN.md`
- `SCREEN-BACKLOG.md`
- `docs/evidence/J4.3/`: README, repair plan, reference PNG/JSON, verify/capture scripts, capture metadata/logs, final test/build logs and exit files, verification.json, visual-review.json.
