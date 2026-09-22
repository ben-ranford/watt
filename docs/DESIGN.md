# F04 — Scene composition and root routing

## Decisions

- `WattApp` owns one shared `AppRouter`, `PowerReadingStore`, and
  `PreferencesStore`. Preferences explicitly use the app's UserDefaults domain;
  telemetry remains the existing fixture (no production-service claim).
- There is exactly one SwiftUI `MenuBarExtra`, with `MenuBarRootView` as its fixed
  panel root. Onboarding `Window`, native `Settings`, and update `Window` each have
  independent fixed roots. Opening Settings and Update never replaces another
  scene's content. There are no tabs, navigation stacks, or additional status items.
- `AppRouter` accepts typed `AppDestination` presentation requests and tracks only
  presentation/launch state. It no longer owns a global content destination or
  onboarding progress. Onboarding reads the persisted feature checkpoint from
  `PreferencesStore`; `.picker` is the existing model's menuBarReading / J1.2.
- First/incomplete launch opens onboarding at its persisted checkpoint, once per
  app lifetime. A completed launch leaves only the status item. Reopening an
  already-running incomplete app presents onboarding; completed setup presents
  Settings (J8). Close dismisses onboarding without completing or resetting it.
- Primary status-item clicks retain SwiftUI's panel behavior. Secondary click or
  Control-click presents a native context menu on the same status-item window.
  Open Watt? requests the panel even while setup is incomplete. Finish Setup… is
  available only for incomplete setup and persists `.picker` before onboarding.
  Settings and Check for Updates… request their dedicated scenes. Reading choices
  write the shared preference; rendering each mode remains a separate story.
  Quit terminates the application; closing its last window does not.
- The narrow AppKit adapter locates the existing `NSStatusBarButton` through the
  label's native window, opens it via `performClick`, and intercepts only secondary
  clicks in that window. It does not create an NSStatusItem or replace primary
  click behavior. Native menu tracking finishes before panel opening. The adapter
  removes its event monitor when detached. This host-hierarchy dependency requires
  live verification on each supported macOS release.
- Settings uses SwiftUI `openSettings` on macOS 14+, and the existing AppKit
  Settings action on macOS 13. A single app delegate routes reopen and preserves
  the opt-in Debug capture harness. Capture launches suppress ordinary onboarding
  routing. UpdateRootView remains explanatory shell content only.

## Verification and boundaries

With `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer`:

- `swift build`: passed.
- Native `xcodebuild ... build`: passed.
- Temporary `/tmp/watt-f04-matrix.swift` compiled against the actual router,
  preferences and context-menu sources and passed: launch-once, completed launch,
  both reopen branches, Open Watt? during incomplete setup, Settings/Update
  requests, Finish Setup checkpoint persistence without completion, reading-mode
  action, and hiding Finish Setup after completion.
- `swift test` and hosted `xcodebuild ... test -only-testing:WattTests`: blocked at
  compilation by the existing router-progress test, which references removed
  `destination`, `onboardingStep`, `OnboardingStep`, and `advanceOnboarding` APIs.
  Tests are owned by another lane and were not edited. Replace that old test with
  presentation-request and feature-checkpoint assertions; do not restore global
  routing/progress solely to satisfy it.
- Live primary/secondary-click presentation, simultaneous native windows,
  completed-launch window suppression, reopen delivery, and Quit remain manual/UI
  verification gaps; the in-process matrix is not proof of those OS interactions.
  No screen-story, accessibility, production-update, or F04 completion claim.
