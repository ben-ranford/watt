# G034 / J1.7 — First run — where Watt? lives

Implementation is present; **story acceptance remains blocked**, not complete.
The native popover capture path was repaired in the DEBUG fixture only; no
custom product chrome was added.

## Implementation

- Features/Onboarding/Views/OnboardingFlowView.swift provides CoachMarkView with
  exact title, message, and Got It copy.
- Production presentation is an AppKit NSPopover anchored to the existing
  NSStatusItem button. NSPopover owns the material, rounded surface, shadow and
  arrow; SwiftUI owns only semantic content and native button controls.
- Got It atomically advances coachMark to livePanel and routes to the existing
  status-panel destination. Duplicate, stale, wrong-checkpoint, and failed
  persistence paths do not navigate; retry remains possible.
- App/WattApp.swift contains the DEBUG J17 fixture. When the host does not
  materialise a third-party status-item window, the fixture anchors the real
  NSPopover to a temporary native AppKit view so its OS-owned popover surface can
  be captured. That anchor is not production UI and contributes no custom
  chrome.
- J17CoachMarkTests contains six behavior/native-contract tests. NativeStylingTests
  protects semantic typography, native controls and the existing columns Form
  contract.

## Exact Figma evidence

The exact Figma MCP context was freshly retrieved for file
9DKDgUfEqidZdZQEVlQgLS on 2026-09-24. Frame 28:2621 is the 1000×720 desktop
reference. The relevant nodes are 28:2622, 28:2770, 28:2768, 28:2771 and
28:2787. The nested coach mark is a Light Top (Trailing) native popover with
260×136 point content, SF Pro bold 13/16 headline, SF Pro regular 11/14 body,
and native bordered-prominent Got It. See
current-figma-context-2026-09-24.md.

The supplied full-frame reference at figma-reference.png has SHA-256
826e2663c1b97870f4bac0acae3e43a406c5dc84dc47846517decde8fc1eb867.
The stable fresh native popover capture is native-popover.png (640×404
pixels). It is an app-owned capture of the real NSPopover; its native window
metadata is in window.json. The temporary anchor is retained separately as
native-anchor.png. Hashes are in images-2026-09-24.sha256.

## Visual Ralph comparison

The fresh native popover now exists and was inspected against the exact nested
Figma reference. App-owned composition matches the title, body copy and
wrapping, Top (Trailing) arrow, rounded native surface, button placement and
native prominent action. Native macOS material is darker in this isolated
compositor capture than the Figma wallpaper/material reference; that is
OS-owned and was not replaced with a painted background. The capture includes
native shadow/arrow pixels around the 260×136 point content.

App-owned content review: visually acceptable for native semantics and
composition; no calibrated pixel diff is claimed. Overall story visualPass
and storyDone remain false because the capture uses native fixture anchoring,
does not prove the real MenuBarExtra/status-item route, and does not include
live AX/VoiceOver interaction. See visual-review.json for the fail-closed
whole-story verdict and the app-owned comparison record.

## Fresh verification — 2026-09-24

| Command | Result | Evidence |
| --- | --- | --- |
| xcrun swift test --scratch-path /tmp/watt-g034-j17-final-swift --filter J17CoachMarkTests | 6 passed, 0 failures | fresh-package-focused-2026-09-24.log |
| xcodebuild ... -only-testing:WattTests/J17CoachMarkTests -only-testing:WattTests/NativeStylingTests ... test | 17 passed, 0 failures; TEST SUCCEEDED | fresh-native-focused-2026-09-24.log |
| xcodebuild ... -derivedDataPath /tmp/watt-g034-j17-final-analyze build analyze | BUILD and ANALYZE SUCCEEDED | fresh-build-analyze-2026-09-24.log |
| WATT_J17_APP=/tmp/watt-g034-j17-final-analyze/Build/Products/Debug/Watt.app/Contents/MacOS/Watt bash docs/evidence/J1.7/capture.sh | exit 0; two app-owned windows captured | fresh-capture-2026-09-24.log, window.json |
| git diff --check; bash -n docs/evidence/J1.7/capture.sh; plutil -lint Watt.xcodeproj/project.pbxproj | Passed | final verification |

The screen-capture permission is preauthorized and the current read-only probe
reports AX trusted true, but this does not prove live interaction. The fixture
does not claim VoiceOver traversal, real status-item activation, or OS
login-item/helper effects.

## Remaining acceptance blockers

- The temporary anchor is required because the host does not reliably expose
  the production third-party status-item compositor window. Native NSPopover
  chrome is captured, but the exact production MenuBarExtra/status-item anchor
  and live click route remain unverified.
- No cross-process keyboard, Got It, VoiceOver, or status-panel interaction was
  performed by this evidence.
- No pixel-identical parity is claimed. AppKit owns material/rasterization and
  the nested reference includes a different wallpaper/material context.
- Fixture “implemented” means a render target exists; it does not by itself
  close story acceptance.

Story acceptance remains blocked; implementation/build/native rendering are
verified and durable evidence is retained.
