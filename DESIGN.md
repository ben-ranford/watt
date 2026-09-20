# Design

## Source of truth

- **Status:** Draft — first-phase shell and backlog established; individual screen stories remain unimplemented.
- **Date:** 2026-09-20
- **Product surfaces:** Watt? native macOS menu-bar utility: status item, live power panel, secondary-click menu, onboarding window, settings window, system notifications/alerts, update and helper lifecycle flows.
- **Primary Figma file:** [Watt?](https://www.figma.com/design/9DKDgUfEqidZdZQEVlQgLS/Watt-)
  - [Core Screens, node `21:927`](https://www.figma.com/design/9DKDgUfEqidZdZQEVlQgLS/Watt-?node-id=21-927)
  - [Journeys, node `27:985`](https://www.figma.com/design/9DKDgUfEqidZdZQEVlQgLS/Watt-?node-id=27-985)
- **Evidence reviewed:** empty repository scaffold; Figma metadata for both canvases; design context/reference code for representative core and journey frames; screenshots for `21:928`, `25:787`, `27:987`, and `27:1354`; variable definitions for light/dark panels, onboarding, settings, menu and update/error states; subscribed Figma libraries including macOS 26/27.
- **Durable backlog:** [`SCREEN-BACKLOG.md`](SCREEN-BACKLOG.md). It contains one independently completable story for every identified Figma screen/frame. No story is complete because the shell compiles; visual verification is mandatory.
- **Implementation baseline:** native SwiftUI macOS app shell in this repository. The current Swift Package is a buildable development harness; final app-bundle signing, bundle identifier, activation policy, and helper packaging remain explicit follow-up work.

## Brand

Watt? is quiet, precise and useful: a small status utility that answers “what is my Mac doing right now?” without turning power telemetry into a dashboard.

- **Trust signals:** native macOS controls, clear units and signs, transparent helper permissions, local-only wording, explicit “no reading” states, and reversible settings.
- **Avoid:** gamification, charts before they are needed, unexplained energy scores, alarming colours for normal charging, web-app styling, and decorative UI that competes with the menu bar.

## Product goals

### Goals

1. Give users an immediate, glanceable power reading from the menu bar.
2. Explain the selected reading in a compact, readable panel.
3. Make component readings and helper permissions understandable and reversible.
4. Preserve native macOS interaction conventions, including settings, alerts, menus, keyboard navigation and VoiceOver order.
5. Make unavailable, stale and transitional telemetry explicit rather than presenting false precision.

### Non-goals for this phase

- Implementing every journey screen or real sensor/helper/update integration.
- Recreating the macOS desktop wallpaper or system UI as application-owned artwork.
- Introducing a tab-based navigation model; the design is a menu-bar utility with separate windows/scenes.
- Adding a third-party design system or icon package.

### Success signals

- The shell launches as a menu-bar app, opens the panel and settings scene, and owns one shared fixture/service graph.
- Every backlog story can be traced to a Figma node and has an explicit state, transition and visual-verification target.
- Native controls retain keyboard, accessibility and system appearance behaviour.

## Personas and jobs

- **Mac owner at a glance:** “Tell me whether the battery is charging, draining or full without opening a heavy utility.”
- **Power-conscious user:** “Show me which component is using power, and explain what permission enables that.”
- **Troubleshooter:** “Tell me when readings are unavailable, the helper is off, or an update is needed, and what I can do next.”
- **Accessible keyboard/VoiceOver user:** “Let me discover and operate the status item, panel, settings and destructive actions in a predictable order.”

## Information architecture

### Surface hierarchy

```text
Watt? menu-bar status item
├─ Primary click → MenuBarExtra .window → live status panel
├─ Secondary click → status-item context menu
│  ├─ Open Watt?
│  ├─ Settings…
│  ├─ Show in Menu Bar → Delta / Charger / Draw / Per Component / Icon Only
│  ├─ Check for Updates…
│  └─ Quit Watt?
├─ First launch → onboarding window
│  ├─ Welcome → choose menu-bar reading → optional component helper
│  ├─ helper approval → component preview → all set → coach mark
│  └─ close/skip → defaults applied; resume from context menu
└─ Settings scene
   ├─ Menu Bar
   ├─ Readings
   ├─ Component Readings
   ├─ Notifications
   └─ General
      ├─ Remove helper
      ├─ Check for updates
      └─ Uninstall
```

There are no tabs in the Figma design. A `Settings` scene and a dedicated onboarding window are the native SwiftUI equivalents of the designed windows; the menu-bar panel is not a navigation stack. `AppRouter` therefore owns presentation intent only, while feature-local state owns onboarding, helper, telemetry and update transitions.

### Journey relationships

- `J1` is the happy path: `1.1 → 1.2 → 1.3 → 1.4 → 1.5 → 1.6 → 1.7 → 1.8`.
- `J2` resumes from the panel/context menu: unavailable component mode → panel → settings → approval → available component mode.
- `J3` covers approval timeout/cancellation, helper disabled and helper update required.
- `J4` is the desktop/no-battery branch and reuses onboarding/panel primitives with battery options disabled.
- `J5` covers closing setup early and resuming via “Finish Setup…”.
- `J6` covers charging, charging hold, full, insufficient charger and on-battery panel states.
- `J7` covers menu-bar display customisation, including the max-two component rule and icon-only fallback.
- `J8` covers no-reading/recovery and reopening the app into Settings.
- `J9` covers remove-helper confirmation and post-quit behaviour.
- `J10` covers check, download, install, success, failure and post-relaunch helper update states.
- `J11` is an accessibility acceptance walkthrough over the status panel, settings and destructive confirmation.
- `J12` covers uninstall, leftover helper discovery and reconnecting to the happy path.

## Design principles

1. **Glance first:** the status item should answer the primary question before the panel is opened.
2. **Native over novel:** use SwiftUI/AppKit controls and scene semantics where they match the Figma intent.
3. **State is visible:** distinguish charging, on battery, charged, unavailable, stale, pending approval and failure.
4. **Permission is explained:** state what the helper reads, what it does not read, and how to remove it.
5. **One source of truth:** preferences, telemetry and feature lifecycle are separate models; views do not own services.
6. **Variants are data:** light/dark, power mode and menu-bar display mode are model inputs, not duplicated screens.
7. **Visual proof:** a compiled view is not complete until it has been rendered and compared with its Figma frame.

## Visual language

### Colour

Tokens are derived from Figma variable definitions and should be semantic in SwiftUI:

| Token | Light | Dark / use |
|---|---|---|
| Primary label | `#000000D9` | `#FFFFFFD9` |
| Secondary label | `#00000080` | `#FFFFFF8C` |
| Quinary label | `#0000000D` | `#FFFFFF0D` |
| Opaque quaternary fill | `#00000008` | `#FFFFFF08` |
| Accent blue | `#0088FF` | `#0091FF` |
| Success green | `#34C759` | helper/positive state accent |
| Destructive red | `#F52F32` | destructive actions only |
| Window background | `#FFFFFF` | system material / Liquid Glass treatment |

The shell uses `Color.accentColor` and system materials where possible. Hard-coded colours belong only in the token layer. Normal charging and positive watts must not use destructive red.

### Typography

Figma uses SF Pro throughout most surfaces:

- Body regular: 13 / 16
- Body emphasized: SF Pro Semibold 13 / 16, weight 590
- Headline: SF Pro Bold 13 / 16
- Large title: SF Pro Bold 26 / 32
- Subheadline: 11 / 14
- Footnote: 10 / 13
- Onboarding selection title: Figma specifies Inter Bold 17 / 22 for `Title 2`; validate whether the native implementation should use the system title2 equivalent or ship/use Inter.

Use `WattTypography` rather than scattering numeric font sizes through views.

### Spacing and geometry

- Global body size: 13; menu height: 24; button height: 24.
- Button horizontal padding: 16; button radius: 6.
- Settings rows and repeated form rows: 42 high with 10–12 point horizontal row insets.
- Onboarding content inset: 20; inner content width: 440; designed onboarding window width: 480.
- Settings window: 580 × 870 in the core frame.
- Core panel reference export: 900 × 640; onboarding reference frames: 1000 × 720 desktop captures.
- Radio control: 16 wide, 4.8 dot, 3 point internal spacing.
- Switch track: 36 × 16; knob: 21 × 13.
- Use continuous rounded corners and native material/window chrome; exact corner/elevation values not exposed as independent variables should be calibrated during visual verification.

### Motion, imagery and iconography

- Prefer native window/menu transitions and respect Reduce Motion.
- The Figma file uses a macOS desktop template/wallpaper and system menu-bar elements as context, not app-owned assets.
- The app icon is still a Figma “Watt? App Icon (placeholder)” and must be replaced by an approved asset before shipping.
- No custom image/SVG assets were returned by the inspected design contexts. Apple logo, Wi-Fi, Spotlight, Control Center, date/time and menu-bar controls are system context.
- The status reading uses a private SF Pro glyph in Figma (`􀢋` in the reference output). Do not persist that private character as an API; choose and document the matching SF Symbol during implementation.
- Use SF Symbols for semantic app-owned icons (`bolt.fill`, settings, update, helper and disclosure) only after visual comparison confirms the glyph matches.

## Components

### Current shell primitives

- `WattWindowScaffold`: shared material/rounded window content boundary.
- `WattFormSection` and `WattFormRow`: grouped settings/panel rows.
- `WattActionButton`: bordered, prominent and destructive action styles.
- `WattTypography`, `WattSpacing`, `WattColors`: semantic token ownership.
- `MenuBarStatusLabel`: status-item reading and accessibility value.

### Planned feature components

- Menu bar: `StatusPanelView`, `StatusItemContextMenu`, `PowerReadingRow`, `ComponentReadingRow`.
- Onboarding: `OnboardingFlowView`, `OnboardingWindow`, `ReadingPicker`, `HelperApprovalView`, `CoachMark`.
- Settings: `SettingsRootView`, `SettingsSection`, `SettingsRow`, `ReadingPicker`, `ComponentPicker`, `HelperStatusRow`.
- Feedback: `WattAlert`, `SystemNotificationBridge`, `UpdateWindow`, `ProgressIndicator`.

### Figma reusable component families and states

- macOS 27 `Desktop Template`, `Desktop Wallpaper`, `Menu Bar`, `Window Controls`.
- `Watt? Status Item`: light/dark, selected/unselected, delta/charger/draw/per-component/icon-only/no-reading.
- `Watt? Panel (MenuBarExtra .window)`: power form rows, component form rows, settings and quit actions.
- `Watt? Onboarding Window`: welcome, radio picker, helper facts, approval, component preview, all-set and coach mark.
- Settings form rows: pop-up, switch, label and button variants; sections for Menu Bar, Readings, Component Readings, Notifications and General.
- Menus: action/submenu, idle/hover+keyboard/disabled, selected submenu and max-two component constraint.
- Alerts/notifications: primary/secondary/destructive/stacked actions; indeterminate and determinate progress; helper/update/uninstall outcomes.

## Accessibility

- Target native macOS accessibility semantics and keyboard operation; verify against the dedicated `J11` frames.
- Every status reading exposes a concise label and value, not only a glyph or colour.
- Radio options announce title, description, selected state and disabled reason.
- Settings rows expose control label, current value and helper text as one predictable VoiceOver unit.
- Destructive actions require confirmation and have explicit Cancel/Uninstall or Remove semantics.
- Preserve keyboard focus order: status item → panel heading → reading rows → settings/quit; settings sections follow visual order.
- Respect system font sizing where compatible with the compact design, support high contrast and do not rely on colour alone.
- Respect Reduce Motion and avoid animated telemetry that creates sensory noise.

## Responsive behavior

This is a macOS desktop utility rather than a responsive phone/tablet surface.

- The status item must adapt to light/dark menu bars and crowded/notch layouts; `Icon Only` is an intentional fallback.
- The menu-bar panel is compact and should preserve row hierarchy at its designed width; longer labels must truncate or wrap without hiding values.
- Settings is a resizable native window with a scrollable form; preserve the 580-point reference width as the ideal layout.
- Onboarding keeps the 480-point content width but should remain usable when system text size increases.
- Hover, right-click, keyboard and VoiceOver are macOS interaction modes; there is no touch breakpoint.

## Interaction states

The implementation must model and render these states before claiming screen completion:

- **Loading:** initial telemetry, helper approval request, checking/downloading updates.
- **Empty/unavailable:** no reading yet, unsupported battery, desktop Mac without battery, component helper unavailable.
- **Error:** approval cancelled/timed out, helper switched off, helper update required, update check failed, reconnect required.
- **Success:** component helper enabled, all set, up to date, helper reconnected, uninstall complete.
- **Disabled:** unavailable power modes, disabled Per Component option, disabled menu actions, disabled controls during update.
- **Offline/slow:** telemetry stale after wake; resume automatically without an unnecessary alert.
- **Destructive confirmation:** remove helper and uninstall with keyboard-safe Cancel/default-action behaviour.

## Content voice

- Short, direct, calm and concrete. Prefer “No reading yet” over “Unknown error”.
- Use `Watt?` consistently, including the question mark.
- Always include units (`W`, `%`, time remaining) and preserve the sign convention: positive battery watts mean charging; negative means drawing from the battery.
- Explain permissions in plain language: what is read, what is not read, and how to remove it.
- Use ellipses for actions that open another window or require a follow-up (`Settings…`, `Enable…`, `Check for Updates…`).
- Do not promise a precise estimate when telemetry is stale or unavailable.

## Implementation constraints

- Native SwiftUI for macOS; use AppKit only at the boundary where menu-bar/system integration requires it.
- Keep feature-first folders and one executable target until a real module boundary appears. Do not add dependencies for icons, styling or routing.
- Keep `AppRouter` scene/presentation-oriented. Keep preferences, telemetry and helper/update lifecycle state in separate services/models.
- Use fixture-driven previews and tests; previews must never poll hardware, install a helper, request permissions or mutate real settings.
- Store assets under `Resources/Assets.xcassets`; the placeholder icon is intentionally incomplete until approved artwork is supplied.
- The current environment exposes Swift 6.4 and CommandLineTools but no `xcodebuild`/Simulator runtime. `swift build` is available locally; the authored XCTest target cannot run until full Xcode provides the XCTest module. Simulator rendering, XCTest execution and Figma comparison require a full Xcode/macOS verification environment.
- Each story in `SCREEN-BACKLOG.md` requires implementation, successful build, simulator rendering, visual comparison against its Figma frame, correction of material differences, no compiler errors and working navigation. Compilation alone does not close a story.

## Open questions

- [ ] **Product/owner:** What is the minimum supported macOS release and final bundle identifier? This controls `MenuBarExtra` availability, native material behaviour, signing and helper packaging.
- [ ] **Product/design:** What is the approved Watt? app icon asset? The current Figma node is explicitly a placeholder.
- [ ] **Engineering:** Which sensor/helper API provides charger input, system draw and component readings, and what are its unavailable/stale/error contracts?
- [ ] **Engineering:** Should the final deliverable use a thin Xcode macOS app host around this package harness, or an explicitly assembled package executable bundle?
- [ ] **Design/engineering:** What exact SF Symbol corresponds to Figma’s private status glyph `􀢋` in each display mode?
- [ ] **Product:** What should “Open Watt?” do when onboarding is incomplete, and how should closing the onboarding window persist/resume setup?
- [ ] **Product/security:** What are the real helper approval, remove-helper, reconnect and uninstall APIs/entitlements?
- [ ] **Product:** What update service, release-note source and install/relaunch mechanism should back `J10`?
- [ ] **QA:** Which full Xcode simulator/macOS versions and screenshot-diff process are required for visual sign-off?
