# G044 / J4.1 — Welcome (desktop copy)

## Implemented, acceptance blocked
Exact Figma file `9DKDgUfEqidZdZQEVlQgLS`, node `30:2275`. Retrieved exact
`get_design_context` before implementation. The supplied 1000×720 reference is
pinned in `figma-reference.png`; provenance/hash/bounds are in `reference.json`.

`OnboardingFlowView(welcomeVariant: .desktop)` reuses the existing welcome view,
onboarding picker route and persisted checkpoint. Title: **Know your watts**.
Desktop body: **Watt? sits in your menu bar and shows what your Mac draws. Nothing more.**
J1.1 remains `.standard` by default and retains its extended charging copy and icon path.
Back returns to the same explicit welcome variant. J4.2 capability-specific picker
implementation is out of scope; Continue enters the existing picker, not a fabricated J4.2.

The existing supplied `WattAppIcon` asset, system typography/spacing, native
bordered-prominent Continue/default action, native titleless window and close/Escape
semantics are reused. No custom-painted chrome or production appearance override.
`J4.1/base` is a Debug-only launch fixture with fresh in-memory preferences,
preview reading store and no production service composition/UserDefaults mutation.

## Reproduce
From the implementation worktree:

```sh
bash docs/evidence/J4.1/verify.sh
bash docs/evidence/J4.1/capture.sh
```

Capture launches the Debug host with `--watt-fixture J4.1/base`, in en_US/dark,
captures only that PID's native window, and terminates only that launched process.
It does not request permissions or capture/synthesize the desktop.
The recorded compositor window is 480×306 points / 960×612 pixels.
Original capture: `capture-final/native-window-11407.png`; PID/window/permission
metadata: `capture-final/window.json`. Reference app-owned bounds: (260,216,480,308).

## Verification (post-F05 expected-list fix)
- Focused J4.1 + router tests: 18 tests, 0 failures.
- Full package: 375 tests, 1 skipped, 0 failures.
- Hosted unit suite: 363 tests, 1 skipped, 0 failures.
- Package build, host Debug/Release build + analyze, and `git diff --check`: exit 0.
- All final command output/exit statuses are adjacent `*.log` / `*.exit` files.
- Added tests cover exact variant copy/asset, default J1.1, registry/unknown variants,
  fresh fixture storage contract, persisted Continue/Back, stale actions,
  native window close preserving state and source-level default/Escape wiring.
- Added opt-in `F05StoryRenderTests/testJ41DesktopWelcomeNativeInteraction` covers
  click, Return, Back, Escape and native close. It was compiled by hosted testing,
  **not executed**: the capture process reports `AXTrusted=false`.
  Running it requires `WATT_J41_UI_TEST=1` in the authorized UI-test runner.
- No standalone lint configuration was added. Compiler and Xcode analyzer provide
  diagnostics; existing SwiftPM unhandled-file/AppIntents warnings are not fixed here.

## Visual Ralph verdict / remaining proof
`visual-review.json`: **blocked**, score **null**. The actual native window and
exact-node reference were visually inspected. Copy and structural category match;
the reused supplied icon is light while the reference icon is dark, native metrics
and control states differ, and there is no aligned comparable pixel-diff/overlay.
No numeric visual score or >=90 pass is claimed. Live AX interaction is unverified;
source/unit tests do not replace that proof. No wallpaper/chrome was recreated to
mask these differences.

Implementation and local verification are complete; visual/live acceptance is
explicitly blocked, not promoted to done. No commit was created.
