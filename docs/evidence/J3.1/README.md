# G041 / J3.1 — Approval not given

Exact Figma node `29:5253`, file `9DKDgUfEqidZdZQEVlQgLS`. `reference.json` pins the supplied 1000×720 asset and SHA-256; get_design_context was retrieved before implementation.

## Implementation
Native scene-attached SwiftUI alert, exact copy/buttons. Settings denied/cancelled/timeout and onboarding cancellation route explicitly. Cancellable 120-second local pending deadlines do not imply OS denial. Failure and Skip withdraw only the originating approval interest; other origins survive. Async onboarding failures require a live origin token. Settings attempt IDs reject close/cancel-late replies. Open System Settings uses the injected SMAppService callback without granting approval. Skip keeps components off; existing Delta/Charger/Draw and Settings remain available. No production helper is fabricated.

## Verification
- Focused J3.1/J2.4/J2.3/J1.4 tests: pass (37 tests).
- Full Swift package tests: pass (349 tests; 1 skipped).
- Swift package build: pass.
- Host Debug and Release `build analyze`: pass.
- Full host test attempt: unit tests pass; UI run fails because existing NativeHostTests.testMenuBarPanelCapture status item is not hittable. See host-tests.log; not waived as green.
- `git diff --check`: pass.
- No commit. Existing shared-worktree changes preserved.

## Native capture / visual-ralph
Reproduce with `bash docs/evidence/J3.1/capture.sh` from the repository root after a Debug host build (use a new capture output directory if capture-final exists). Launch is `Watt.app/Contents/MacOS/Watt --watt-fixture J3.1/base`. Capture is PID-scoped, uses preauthorized screen recording only, and requests no permissions or OS changes.

`capture-final/window.json` records native alert 260×204 points plus its 520×288 Settings scene. `native-window-10830.png` was visually inspected: exact title, message, and both buttons are visible in the native alert. Host uses dark appearance; Figma is light with an icon-bearing desktop alert. The OS chooses the native layout/icon; neither is custom-painted. AXTrusted is false. Live keyboard/VoiceOver/button activation and signed helper/OS approval remain unverified. Onboarding live service composition is still an integration boundary; adapter entry and local withdrawal are covered by tests, not real approval evidence.

`visual-review.json`: blocked, score null, storyDone false. `pixel-diff.json`: blocked/null because captured scene composite and reference desktop differ in appearance and geometry. No synthetic capture, invented score, or forced-appearance workaround. Do not mark J3.1 visually complete.
