# G033 / J1.6 — All set

Implementation is present; **story acceptance remains blocked**, not complete.
The final native correction is committed from this worktree before merging back
to main.

## Implementation

- Features/Onboarding/Views/OnboardingFlowView.swift presents AllSetView with
  exact “That’s it” copy and menu-bar guidance, the existing app-icon
  placeholder, native grouped Form/Section/switch Toggle, and prominent Done.
- The login row now uses .formStyle(.grouped). A fresh .columns capture was
  480×293 points with a compact, unrounded row; the exact Figma reference is
  480×328 points with a rounded native-looking row. .grouped produces the
  reference geometry while keeping all drawing and semantics native SwiftUI.
  No custom row spacing, background, corner, shadow, or chrome was added.
- Done persists completion and .coachMark, dismisses onboarding, then requests
  the existing status-panel route. Duplicate/wrong-checkpoint calls are ignored;
  failed persistence stays on All set with retry feedback. J1.7 owns the future
  coach-mark presentation.
- Open at login defaults on and binds to persisted preferences. This is desired
  preference state, not evidence of OS login-item registration.
- App/WattApp.swift contains the isolated DEBUG J16FixtureLaunch and app-owned
  capture. J16AllSetTests has six focused behavior/control tests.
  NativeStylingTests locks the grouped native Form choice.
- DESIGN.md records the reusable native Form decision and the remaining
  OS-owned verification limits.

## Exact Figma evidence

The exact Figma MCP context was re-inspected for file
9DKDgUfEqidZdZQEVlQgLS on 2026-09-24:

- Frame 28:2199, “1.6 All set”; Light desktop template 28:2200.
- Onboarding window 28:2353, content slot 28:2365, login row 28:2532; the
  content slot is included by the qualified parent response but is not
  independently selectable through MCP.
- The window is active, titleless, 480×328 points, with native traffic lights.
  The reference uses a centered app icon, semantic title/body typography, one
  FormLogin row (“Open at login”) with the switch on, and a native-prominent
  Done action.
- Figma styles resolve to SF Pro body regular/semibold at 13/16 and the
  semantic native title maps to the existing title style. No external font,
  private symbol, or painted macOS control is introduced.

The supplied export at figma-frame.png has SHA-256
7de9c607b695153a9ec739336b421a60f00af96f7228f44599ac3101760c299b.
bash docs/evidence/J1.6/capture.sh passed. The final PID-scoped native
compositor capture is native-window.png at 960×656 pixels / 480×328 points;
actual-content.png is a separate 480×328 app-owned cache-display diagnostic.
See the current capture/build logs, window.json, and
images-2026-09-24.sha256. No TCC bypass, fake window, or custom macOS chrome
was used.

## Visual comparison

The native grouped correction now matches the Figma reference’s 480×328-point
window geometry and rounded login-row treatment. The native switch, system
typography, titleless window, traffic lights, copy, wrapping, and button
placement remain OS-owned. The supplied independent Visual Ralph review records
94/100 and a visual pass for app-owned composition; it is retained as a
judgement record, not presented as a new calibrated pixel-diff result.

No pixel-identical parity is claimed. The independent review’s minor OS-owned
differences remain: native Done intrinsic width, small text/row baseline offsets,
rasterization, and system window/background treatment. visualPass and storyDone
remain false while AX/TCC/live interaction acceptance is blocked.

## Fresh verification — 2026-09-24

Commands ran from this worktree with
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer:

| Command | Result | Evidence |
| --- | --- | --- |
| xcrun swift test --scratch-path /tmp/watt-g033-j16-grouped-swift --filter J16AllSetTests | 6 passed, 0 failures | fresh-package-focused-2026-09-24.log |
| xcodebuild ... -only-testing:WattTests/J16AllSetTests -only-testing:WattTests/NativeStylingTests ... test | 17 passed, 0 failures; TEST SUCCEEDED | fresh-native-focused-2026-09-24.log |
| xcodebuild ... -derivedDataPath /tmp/watt-g033-j16-final build analyze | BUILD and ANALYZE SUCCEEDED | fresh-build-analyze-2026-09-24.log |
| WATT_J16_APP=/tmp/watt-g033-j16-final/Build/Products/Debug/Watt.app/Contents/MacOS/Watt bash docs/evidence/J1.6/capture.sh | exit 0; native 480×328-point window captured | fresh-capture-2026-09-24.log, window.json |
| git diff --check; bash -n docs/evidence/J1.6/capture.sh; plutil -lint Watt.xcodeproj/project.pbxproj | Passed | final verification |

Build output retains only known non-fatal AppIntents/linkd and existing
main-actor warnings. The fresh native capture is evidence of rendering and
geometry; it does not establish AX trust, VoiceOver traversal, or actual
login-item/helper effects.

## Remaining acceptance blockers

- Read-only permission probe: screen capture is preauthorized, AX trusted is
  false. Native compositor evidence succeeded, but live switch/keyboard/Done
  traversal, VoiceOver, and actual post-onboarding status-item interaction are
  unverified.
- Unit tests prove routing requests and persistence, not physical OS interaction.
  No live login-item registration or helper connectivity is claimed.
- Independent visual approval is recorded and the focused native suite is green.
  Neither closes AX/TCC/live interaction gaps.
- Fixture “implemented” means a render target exists, not story acceptance.

Independent visual approval recorded; story acceptance remains blocked.
