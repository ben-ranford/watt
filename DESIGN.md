# Design

## Source of truth

- **Status:** Draft — native host, shared contracts and F04 scene-isolated composition have build/unit-test evidence; live interaction validation and individual screen-story acceptance remain open.
- **Date:** 2026-09-20
- **Product surfaces:** Watt? native macOS menu-bar utility: status item, live power panel, secondary-click menu, onboarding window, settings window, system notifications/alerts, update and helper lifecycle flows.
- **Primary Figma file:** [Watt?](https://www.figma.com/design/9DKDgUfEqidZdZQEVlQgLS/Watt-)
  - [Core Screens, node `21:927`](https://www.figma.com/design/9DKDgUfEqidZdZQEVlQgLS/Watt-?node-id=21-927)
  - [Journeys, node `27:985`](https://www.figma.com/design/9DKDgUfEqidZdZQEVlQgLS/Watt-?node-id=27-985)
- **Evidence reviewed:** empty repository scaffold; Figma metadata for both canvases; design context/reference code for representative core and journey frames; screenshots for `21:928`, `25:787`, `27:987`, and `27:1354`; variable definitions for light/dark panels, onboarding, settings, menu and update/error states; subscribed Figma libraries including macOS 26/27.
- **Durable backlog:** [`SCREEN-BACKLOG.md`](SCREEN-BACKLOG.md). It contains one independently completable story for every identified Figma screen/frame. No story is complete because the shell compiles; visual verification is mandatory.
- **Implementation baseline:** native SwiftUI macOS app shell in this repository. The current Swift Package is a buildable development harness; final app-bundle signing, bundle identifier and helper packaging remain explicit follow-up work; accessory/menu-bar activation is the accepted implementation assumption below.
- **F00 reconciliation (2026-09-20):** [reference manifest and decision register](.omx/plans/f00-reference-evidence/README.md), with all 69 ordered story/node pairs in `manifest.json` and a reproducible `verify_inventory.py` check against the approved implementation plan, backlog and captured live Figma metadata. The two canvases contain exactly 16 core and 53 journey story frames. Fresh design contexts and reference PNGs were inspected for C01 `21:928`, J1.2 `27:1354` and C04.7 `24:1234`; this is design-source evidence, not native application rendering or story completion. All 69 exact frame PNG exports are now retained under `f00-reference-evidence/exports/`, with node mapping, SHA-256, byte sizes and matching frame dimensions recorded in the manifest. **F00 reference reconciliation and implementation-assumption register complete; owner-controlled production prerequisites remain blocked for the affected production gates.** DEC-01–05 implementation assumptions are documented below. Native app rendering, accessibility, service proof, final asset/font/SF Symbol approval and owner credentials remain incomplete and must block only the affected later goals, not F00. No native runtime or visual story completion is claimed. These local artifacts are ignored by Git and must accompany any handoff.
- **Verification target:** Watt? is a native macOS menu-bar utility. Native macOS Xcode/VM rendering is the valid target; **iOS Simulator is not**. Any earlier “simulator” wording in this brief, the backlog or approved plan means the native macOS verification host, not an iOS port or a macOS Simulator product. A VM cannot prove hardware sensor behavior it does not expose.

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
│  ├─ Open Watt? → panel (including incomplete setup)
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
- `J5` covers closing setup early and resuming via “Finish Setup…” → J1.2.
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

The following are Figma reference measurements, not runtime font-size requirements. Use semantic system styles; macOS owns metrics. Figma uses SF Pro throughout most surfaces:

- Body regular: 13 / 16
- Body emphasized: SF Pro Semibold 13 / 16, weight 590
- Headline: SF Pro Bold 13 / 16
- Large title: SF Pro Bold 26 / 32
- Subheadline: 11 / 14
- Footnote: 10 / 13
- Onboarding selection title: Figma specifies Inter Bold 17 / 22 for `Title 2`; use the system title2 equivalent provisionally unless product/design approves Inter.

Use `WattTypography` rather than scattering numeric font sizes through views.

### Spacing and geometry

**Normative native policy:** the measurements below describe Figma only. Do not enforce row/button/radio/switch dimensions, negative Form padding, font point sizes, or painted corners to match them. Use native control styles and intrinsic sizing. Application surface sizes belong in WattSpacing; native chrome remains OS-owned.

- Global body size: 13; menu height: 24; button height: 24.
- Button horizontal padding: 16; button radius: 6.
- Settings rows and repeated form rows: 42 high with 10–12 point horizontal row insets.
- Onboarding content inset: 20; inner content width: 440; designed onboarding window width: 480.
- Settings window: 580 × 870 in the core frame.
- Core panel reference export: 900 × 640; onboarding reference frames: 1000 × 720 desktop captures.
- Radio control: 16 wide, 4.8 dot, 3 point internal spacing.
- Switch track: 36 × 16; knob: 21 × 13.
- Use native material/window chrome; never calibrate painted corners/elevation to the reference.

### Motion, imagery and iconography

- Prefer native window/menu transitions and respect Reduce Motion.
- The Figma file uses a macOS desktop template/wallpaper and system menu-bar elements as context, not app-owned assets.
- The app icon is still a Figma “Watt? App Icon (placeholder)” and must be replaced by an approved asset before shipping.
- No custom image/SVG assets were returned by the inspected design contexts. Apple logo, Wi-Fi, Spotlight, Control Center, date/time and menu-bar controls are system context.
- The status reading uses a private SF Pro glyph in Figma (`􀢋` in the reference output). Do not persist that private character as an API; the matching public SF Symbol remains a product/design owner gate.
- Use SF Symbols for semantic app-owned icons (settings, update, helper and disclosure) only after visual comparison confirms the glyph matches. `bolt.fill` is only a comparison candidate, not an approved shipping status glyph.

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
- F00's fresh toolchain inspection supersedes the earlier “no full Xcode” claim: global `xcode-select -p` is `/Library/Developer/CommandLineTools`, so bare `xcodebuild -version` fails, but `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -version` returns **Xcode 27.0, build 27A266a**, and `-showsdks` lists macOS 27.0. No global toolchain setting was changed. F00 has not run XCTest or rendered the native app; installed Xcode is a prerequisite, not evidence that those checks pass. F01 owns the native host and runtime verification.
- Each story in `SCREEN-BACKLOG.md` requires implementation, successful build, native macOS rendering, visual comparison against its Figma frame, correction of material differences, no compiler errors and working navigation. Compilation alone does not close a story.

### Native verification host (F01)

- `Watt.xcodeproj` now provides the shared `Watt` scheme, native macOS app, hosted `WattTests` and `WattUITests`. It compiles the existing package source files directly (one `@main`), includes `Resources/Assets.xcassets`, and sets `LSUIElement=YES`. Package.swift remains a separate development harness with explicit shared source directories; new Swift files also need Xcode target membership.
- [Native host instructions](docs/NATIVE-HOST.md) and `scripts/verify-native-host.sh` provide full-Xcode build/launch/test and xcresult screenshot/accessibility-attachment export paths. Local ad-hoc signing and `dev.watt.verification` are verification-only; production identifiers, artwork, entitlements, signing/notarization and helper/login packaging remain owner gates.
- F01 validation on macOS 27.0 (26A428), Xcode 27.0 (27A266a): project listing, native Debug build, both hosted XCTest cases, both package tests, and Release analysis pass. LaunchServices starts the built `.app`; macOS 13 runtime compatibility is not yet exercised.
- **F01 native capture acceptance now has sufficient evidence (2026-09-20):** the Debug-only `--watt-capture-status-panel` delegate hosts the existing `StatusPanelView` in an app-owned NSWindow. `scripts/capture-native-panel.sh` preflights existing screen-capture access without requesting it, selects only the launched PID's titled window via CGWindowList, captures it with `screencapture -x -o -l`, records metadata and terminates/waits for its process. Normal launches are inert; Release excludes the delegate/flag. No production/menu-bar behavior is changed.
- Durable [F01 evidence](docs/evidence/f01/README.md), [PNG](docs/evidence/f01/status-panel.png) and [window metadata](docs/evidence/f01/window.json): window 6745 owned by PID 24969, 320 × 503 points, **640 × 1006 pixels at 2×**, light/aqua, en_US, charging fixture; 286 sampled RGB colors prove nonuniform output. Visual inspection confirms the real charging panel, rows and buttons; this is not a Figma comparison. Full-Xcode Debug build, **4 package + 4 hosted unit tests**, Release build/analysis, capture-script syntax/ShellCheck and diff whitespace checks pass. Release binary inspection confirms capture symbols/argument absent. Experimental `NativePanelCaptureTests` remains absent; the new tests cover opt-in and unshown native window construction only. Capture apps and test jobs were terminated/completed.
- **Remaining boundary:** cross-process XCTest UI automation still fails before execution with “Timed out while enabling automation mode” and is not retried by this path. No TCC bypass, credentials, permission requests, AX probe, or desktop fallback. Accessibility evidence is limited to native SwiftUI Text/Button semantics and the panel's source-declared containment/label; no runtime AX hierarchy, VoiceOver or keyboard audit is claimed. This is enough for F01's host/XCTest/native-capture acceptance, not any screen story, menu-bar click/navigation proof, F05 calibration or production readiness. The earlier private blocker artifacts remain historical evidence only; no Ultragoal state is changed.

### Accepted assumptions versus production prerequisites

The architect handoff accepts the implementation assumptions below, not production readiness. Owner-controlled prerequisites remain open; do not invent credentials, APIs, capabilities or production authorization to satisfy them. F00 reference reconciliation and the DEC-01–05 implementation-assumption register are complete. This documentation revision does not implement F01, services or screens. Native app rendering, accessibility, service proof, final asset/font/SF Symbol approval and owner credentials remain incomplete and must block only the affected later goals, not the accepted F00 scope. No native runtime or visual story completion is claimed; no Ultragoal state is changed.

| Record | Accepted implementation assumption | Owner-controlled production prerequisites |
|---|---|---|
| DEC-01 Distribution/packaging | macOS 13 minimum; thin Xcode host; accessory/menu-bar activation; assumed direct Developer ID distribution. | Product/distribution + platform, with architect review: approved app/helper identifiers, signing, notarization and reviewed entitlements. These remain environment prerequisites, not credentials or shipping authorization supplied by this assumption. |
| DEC-02 Helper security/cleanup | No root helper; user-scoped helper/login item; authenticated XPC identities; read-only operation allowlist; explicit rejection, compatibility, timeout and owned-cleanup contracts. | Platform/security + architect: approved identities, operation and owned-cleanup inventory, and isolated security evidence before production helper/removal acceptance. No invented privileged API or broader cleanup authority. |
| DEC-03 Update trust/lifecycle | Signed manifest and artifacts from an authenticated source; user-confirmed staging, install and relaunch; receipts and rollback; no unsigned or automatic destructive fallback. | Platform/security + distribution, with architect review: approved endpoint, trust material and isolated update/recovery evidence. No fabricated endpoint, key or production install authorization. |
| DEC-04 Approval authority | OS-owned approval/status; app explanation/navigation only; notification permission independent of helper consent. Preserve the approved per-origin cancellation/rejoin matrix. | Platform + architect/design: validated platform integration, authoritative status/identity checks and supported Settings navigation. The assumption supplies no undocumented approval/revocation API or proof of permission. |
| DEC-05 Telemetry topology | Protocol-backed telemetry; native fixtures/VM for presentation and unavailable states only. | Telemetry + verifier/architect: approved hardware, API and capability evidence for real sensors, including sampling/freshness and supported hardware/OS cases. Fixtures/VM cannot establish sensor capability they do not expose. |

DEC-04 retains the approved plan's **Shared approval cancellation acceptance matrix** unchanged: Cancel withdraws only its origin; closing a scene detaches presentation but retains interest; the last withdrawal ends only the app wait, not OS approval. Retry reconciles/rejoins the existing operation before any new registration; stale replies never reopen or advance withdrawn/closed scenes. Preserve all parameterized cases, persistence and origin-specific destinations in that matrix.

### Provisional visual and navigation defaults

- Use system fonts unless product/design approves Inter; the sampled Inter Bold 17/22 title remains a comparison reference, not permission to add a font dependency.
- `bolt.fill` is only a comparison candidate. The shipping app icon and public SF Symbol matching the private reference glyph remain product/design owner gates.
- Capture native macOS at reference **app-content size**, not desktop-export size; record scale and appearance. F05 calibrates crop alignment and comparison tolerance; no numeric tolerance or native visual pass is assumed.
- Preserve **Open Watt? → panel**, including incomplete setup, and **Finish Setup… → J1.2**. These defaults do not replace the approved cancellation/rejoin matrix or resolve unrelated stage-specific close/skip and selection-policy questions.

## Open questions

- [ ] **Product/owner:** What are the approved final app/helper identifiers, signing/notarization configuration and reviewed entitlements for the assumed direct Developer ID distribution? macOS 13 is the accepted implementation minimum; production environment prerequisites remain open.
- [ ] **Product/design:** What is the approved Watt? app icon asset? The current Figma node is explicitly a placeholder.
- [ ] **Engineering:** Which sensor/helper API provides charger input, system draw and component readings, and what are its unavailable/stale/error contracts?
- [x] **Approved implementation plan:** F01 uses a thin Xcode macOS app host around the package harness. macOS 13 and accessory/menu-bar activation are accepted assumptions; app identity, signing and reviewed entitlements remain prerequisites. This records host direction, not host implementation.
- [ ] **Design/engineering:** What exact SF Symbol corresponds to Figma’s private status glyph `􀢋` in each display mode?
- [ ] **Product:** Which remaining stage-specific close/skip persistence rules and J4.3 continuation apply beyond the approved routes? Preserve Open Watt? → panel, Finish Setup… → J1.2 and the cancellation/rejoin matrix; crowded-menu fallback, zero component selection and ordering remain explicit owner questions.
- [ ] **Product/security:** What are the real helper approval, remove-helper, reconnect and uninstall APIs/entitlements?
- [ ] **Product:** What update service, release-note source and install/relaunch mechanism should back `J10`?
- [ ] **QA:** Which native macOS versions/VM configuration and recorded scale/appearance complete visual sign-off? Use reference app-content size; exact crop alignment and tolerance require F05 calibration. iOS Simulator is not a valid Watt? target.

## F02 semantic component decisions

- macOS 13 remains the minimum. `WattColors` uses AppKit semantic label, disabled-label, window, separator, focus, success and destructive colors; `Color.accentColor` respects the user's accent. These resolve light/dark and system contrast preferences rather than freezing the Figma library's OS-specific hex swatches. Grouped rows use the adaptive quaternary label fill. The reference hex values above remain comparison evidence, not literal overrides of native controls.
- `WattActionButton` uses native bordered/bordered-prominent styles and a real destructive `ButtonRole`. Native controls own hit testing, keyboard focus, pressed/disabled treatment and accessible button roles. No custom focus-ring painting, fixed-height clipping or global Return shortcut is imposed. Callers own shortcuts and confirmation; a destructive role alone does not confirm an operation.
- Body, emphasized body, headline, large title and subheadline use system text styles/weights. Selection titles use Font.title2.weight(.bold); footnotes use Font.footnote. The Figma point sizes remain comparison metadata only. Inter and the final status glyph remain owner-approval gates; no font dependency or private glyph is introduced.
- `WattSpacing` owns application surface dimensions and layout gaps; historical row/button/radius constants are reference-only, not native-control constraints. Desktop export dimensions are not application-content sizes. Native button chrome/padding is OS-owned; reference button radius and padding are not reapplied outside the control.
- The full native Settings scene maps the Figma 580 × 870 window to an 838-point content area (`799`-point grouped form plus the native content inset); `WattSpacing.settingsContentHeight` owns that surface size. Connected helper rows retain the privacy subtitle so the native accessibility tree and the Figma helper state both expose what the helper reads.
- Form/window headings expose header traits. Form rows preserve their children's individual accessibility elements, especially interactive trailing controls. Success/failure feedback must also have text, never color alone.
- `ReadingPicker` is a native radio-group `Picker` over `WattDisplayMode`, with binding-owned selection and caller-supplied unavailable modes. It does not persist, auto-change selection or infer hardware capabilities. The normal all-enabled path uses SwiftUI's `.radioGroup`; capability-gated paths use AppKit `NSButton` radio controls because macOS SwiftUI does not expose nested custom option content's disabled state to Accessibility. Component limits/order/zero-selection policy remains deferred to its approved feature story; native `ProgressView` and native alert actions are sufficient without progress/confirmation wrapper types.
- `WattComponentGallery(colorScheme:)` is a DEBUG-only app-owned smoke target for the F01 host: instantiate separately with `.light` and `.dark`, set the matching host window appearance, and make the window key for real keyboard focus. It has deterministic local state, fixed 50% progress, selected/unselected/disabled radio/toggle controls, normal/prominent/destructive and disabled actions, a focused text field, textual success/failure samples and an interactive native confirmation. It has no services, storage, timers, fixture activation or Release declaration. Gallery rendering is not backlog-screen implementation or visual sign-off.

### F02 reference-backed specimen pass (2026-09-20)

- `WattReferenceSpecimen.reading`: J1.2 frame **27:1354**, window **27:1508**, content **27:1520**. Content-only width 480 points; exactly four enabled options with reference descriptions and watt values. `ReadingPicker.Option` supplies ordered visible modes/descriptions; the original initializer still defaults to all five modes. Disabled Components and Icon Only remain in the separate general gallery.
- `WattReferenceSpecimen.settings`: C05 frame **25:787**, window **25:1102**, content **25:1129**; sections **25:1501**, **25:1751**, **25:1994**. Content width 580 points including 20-point insets. Menu Bar, Readings and Helper use existing grouped rows/dividers, native pop-up pickers, on mini-switches and neutral Remove. Show symbol now matches the reference on state; a separate unselected mini-switch remains in the general gallery. C05 uses the 6-point `referenceSettingsSectionSpacing` token (10 points tighter) and zero `titleInset`; other form-section callers retain the 4-point default. Notifications/General and full window chrome are outside this component specimen, not implemented backlog screens.
- Fresh retrieved contexts are retained in `docs/verification/f02-gallery/final-checks/{27-1354,25-787}.context.txt`; full-frame reference PNGs are in `references/`. Six native captures, per-window metadata and SHA-256 records are in `docs/verification/f02-gallery/reference-pass-2/`: general gallery 1160×1960, reading 960×668, settings 1160×964 pixels, each light/dark at 2×.
- Accepted platform treatment: native radio/button/switch/picker geometry, system accent, semantic light/dark colors and system font substitute for Inter. Borderless capture intentionally excludes desktop/titlebar/traffic lights rather than painting fake controls. Dark captures are semantic adaptations of these light references, not exact dark-reference matches. The native alert has Cancel/cancel and Remove/destructive roles, mutates only local specimen state, and starts dismissed; metadata records that state, not proof of runtime alert interaction.
- Verification: 18 package tests passed using Xcode’s toolchain; native Debug and Release builds and analysis passed; capture, Bash syntax, ShellCheck and `git diff --check` passed. No capture/build processes remain running.
- **The documented F02 shared-component specimen gate meets the visual threshold (`visual_threshold_met=true`), not screen completion.** The fresh user-supplied independent verdict is retained in [visual-ralph-verdict.json](docs/verification/f02-gallery/visual-ralph-verdict.json), with pair details and reference hashes in the [gallery record](docs/verification/f02-gallery/README.md). At 2 px/point, excluding desktop/window chrome: reading-light vs 27:1354 **92 PASS**, reading-dark **91 PASS** (960×668 px each); settings-light vs 25:787 **90 PASS**, settings-dark **90 PASS** (1160×964 px each). No calibrated numeric pixel diff was performed or fabricated; scores are not pixel-diff measurements. Minor geometry differences remain in radio vertical rhythm, section spacing and native font/control widths, not solely OS chrome. Evidence covers source-native semantics only: no VoiceOver or keyboard sign-off, runtime confirmation audit, or backlog-screen completion is claimed. No `.omx` goal files were edited.

#### F02 remaining-fix evidence (2026-09-20)

- User-provided prior independent verdict: reading light/dark PASS 92/93; settings light/dark FAIL 87/86 on symbol state, section spacing and heading inset. Those three settings fixes are applied; these historical scores are superseded by the final independent specimen verdict above, not a screen-completion claim.
- Recaptured all four reading/settings images in `docs/verification/f02-gallery/reference-pass-2/{reading-light,reading-dark,settings-light,settings-dark}/`, with refreshed `window.json` and `gallery.sha256`; refreshed general captures retain explicit off-switch coverage. Direct inspection confirms on-state switches, flush headings and complete text.
- Native picker arrows, switch geometry, system font and OS control chrome are accepted platform differences, not replaced with painted controls. Logs: `docs/verification/f02-gallery/final-checks/{package-tests,debug,release,script-checks}.log`. Bash syntax, ShellCheck and diff whitespace checks passed. The historical default Command Line Tools failure was superseded by the Xcode-toolchain rerun (18 tests at F02); current F04 verification passes 85 package and 85 hosted tests. The final independent verdict above supersedes pending acceptance for the documented specimen gate only; no goal files edited.

## F03 contract layer (2026-09-20)

- Contracts stay in the three existing target-member files (`Models/PowerReading.swift`, `Models/WattPreferences.swift`, `Services/PowerReadingStore.swift`); there is one definition of each existing store/model. No screens, app composition, test files, project membership or goal artifacts are changed by this slice.
- `PowerReading` is an immutable timestamped snapshot. Physical `BatteryState` (including charging hold, full and no battery), capabilities, source, freshness and legacy presentation mode are independent. Component IDs are adapter-owned stable strings, with names used only as legacy fixture IDs. Missing component measurements are omitted, not zero-filled. Finite values, sign, percentage range, component identity uniqueness and nonnegative input/draw are validated at the store boundary. Initial snapshots are also checked against the injected clock: a future snapshot becomes unavailable with recoverable invalidData rather than poisoning timestamp ordering. A later valid current snapshot is accepted; valid stale snapshots remain usable for stale-to-fresh recovery. Explicit request generations reject late samples after disconnect/restart; clock-based age checks expose stale state without a timer. Sampling interval and maximum age require production telemetry evidence, not these fixtures.
- `PowerFormatter` preserves charge/discharge signs, normalizes rounded negative zero and distinguishes unavailable from zero. Charger selection falls back to battery delta when charger capability is unavailable; this fallback remains a provisional product policy. Existing shell screens still use their legacy formatter/title paths; consuming these richer contracts belongs to their feature slices and is not claimed here.
- Preferences and onboarding checkpoint/completion are persisted independently of effective helper state. Storage is injected; defaults and previews use separate in-memory stores. `UserDefaultsStorage` requires an explicitly supplied domain and cannot promise transactional/fsync durability. Selection validation happens before the backing @Published value changes: observers never receive an invalid intermediate selection. Direct selectedComponents assignments and SwiftUI bindings remain supported; Combine consumers use selectedComponentsPublisher instead of $selectedComponents. Store mutation rejects more than two component IDs, duplicates and empty IDs. Zero selection and caller ordering are retained provisionally pending the open product decision. Failed preference writes remain visible and retryable via `save()`; edited values remain in memory until retried, not falsely acknowledged as durable.
- Shared approval uses a persisted receipt, desired intent and per-origin interest/failure, separate from nonpersistent wait/presentation tokens and authoritative effective availability. Cancel/timeout withdraw only their origin; Close invalidates presentation only. Last withdrawal ends the app wait, never OS approval. Retry requires supplied fresh authoritative reconciliation: pending/connected reuse the receipt, unknown cannot register, absence/no-in-flight proof permits one new operation. Other active origins retain their generation. Failed origin writes revoke only that origin’s presentation authority and report persistence failure; they do not globally gate an unaffected origin’s token, eligibility or shared operation. Failed withdrawal does not acknowledge durable cancellation. Restart restores no presentation authority. Current callback delivery returns eligible open/interested tokens once, including the unaffected origin after another origin fails or withdraws. Successful completion retires the wait generation as well as delivered tokens, so old pending/failure/success callbacks cannot mutate effective state. A subsequent fresh absence/no-in-flight proof creates a new receipt and generation with registrationRequired=true; stale callbacks are ignored. A separate authoritative query may reconcile availability without navigating or rewriting withdrawn intent. F04 owns exact scene destinations, Continue Without's panel opening and onboarding checkpoint advancement; these stores never open windows or complete onboarding.
- `UpdateStore` enforces typed transition/progress and receipt continuity, persists transaction state, rejects old generation replies and marks interrupted install/staging/relaunch for reconciliation after restart. Cancellation is local only before installation; recovery must establish actual installed/launched identity before reporting completion. For a retained cancelled/interrupted pre-install receipt, call UpdateService.discard(receipt:), then pass its successful exact-receipt acknowledgement and current generation to UpdateStore.acknowledgeDiscard(_:generation:). Only a persisted acknowledgement clears the transaction to idle and rotates its generation; write failure retains the receipt and permits acknowledgement retry. Checking then starts a clean transaction with a fresh receipt. Receipt-free pre-install cancellation can retry checking directly. The fake makes discard idempotent, rejects mismatched/reused discarded receipts and post-install discard, and never fabricates completed installation. recover(receipt:) continues to reconcile retained transactions rather than inventing success. The six service protocols expose typed denial, timeout, disconnect, network, interrupted update/removal and cancellation outcomes. Their deterministic fakes perform no hardware, network, OS permission, login-item, registration or cleanup operations. Fake removal success is simulated, not absence proof on disk.
- **Production boundaries remain open (DEC-01–05):** approved app/helper identities, signing/notarization, reviewed entitlements, user-scoped authenticated XPC and read-only allowlist, authoritative approval/status/absence queries, owned cleanup inventory, signed update endpoint/trust material, rollback/relaunch proof, notification/login adapters and supported sensor hardware/APIs. No root helper, credential, endpoint, entitlement or undocumented OS approval/revocation API is invented. The receiving adapter must establish authenticity; a typed `.connected` value by itself is not security evidence.
- **Bounded verification (contract defect repair):** Xcode-toolchain package suite passed **61 XCTest tests, 0 failures**. The verifier edge probe was adapted only for the explicit selection publisher API and extended in `/tmp/watt-f03-fixes-probe.swift`; it passes assertions for both origin permutations under failed withdraw/rejoin, unaffected delivery, completed-generation retirement, fresh absence registration, valid-only selection publication, future-initial and stale telemetry recovery, and receipt/generation/persistence-checked update discard/retry. Direct checking from a retained cancelled transaction is intentionally rejected until discard acknowledgement. This temporary probe is not committed regression coverage; durable new edge cases remain a handoff to the Tests owner. Debug native build and Release static analysis are checked with the Xcode developer directory override. No production service or hardware proof, native journey routing, visual screen completion or goal completion is claimed.


## F04 composition and verification (2026-09-20)

- One shared router, power store and preferences store feed scene-specific roots: one `MenuBarExtra(.window)` status panel, dedicated onboarding/update windows and a `Settings` scene. The AppKit adapter attaches to the existing status button; it does not allocate a second status item. There is no global destination switch, tab model or panel navigation stack. Settings/update intents do not replace panel content.
- Routing regression coverage passes for first-launch idempotence, completion-aware reopen, explicit repeated destinations, preserved onboarding progress, independent settings/update intents, context-menu destinations, Finish Setup → persisted J1.2 picker, and display-mode persistence/checkmarks. Open Watt? requests the panel even with incomplete setup. Quit wiring is inspected without terminating the test host.
- **Current evidence supersedes earlier F04/test-failure notes:** **85 package tests and 85 native hosted tests pass (0 failures)**; native Debug build, Release analysis, diff whitespace check and native app-owned capture pass. See the [acceptance matrix, exact commands and artifact paths](docs/evidence/f04/README.md). Historical F01–F03 test counts describe those snapshots, not the current suite.
- The three actor-isolation warnings in the DEBUG gallery focus helper are repaired by declaring the local recursive function `@MainActor`; routing and focus traversal are unchanged, with no dependencies added. Capture delegate, flags and gallery remain DEBUG-only; Release binary checks are recorded with the evidence.
- **Validation gap, not completion:** TCC/UI-automation restrictions prevent cross-process UI-automation proof. A captured app-owned panel is not evidence of live primary/secondary/control click, menu-bar anchoring, coach-mark anchoring, simultaneous visible windows, close/resume, live reopen or process Quit. Runtime keyboard/VoiceOver audits and macOS 13 execution also remain unverified. No TCC bypass, permission request, desktop capture, production integration, visual screen acceptance or full F04 interaction sign-off is claimed.

## F05 fixture/evidence infrastructure (2026-09-20)

- [F05 evidence and handoff](docs/evidence/F05/README.md) registers all **69** exact
  story/node mappings with **140** deterministic base/variant selections, preserved
  F00 reference metadata, fixed clock, stable component IDs, fresh memory storage
  and explicit **not implemented** render status. Gallery IDs are separate from stories.
- Pure package test-support target and explicit native DEBUG fixture membership are
  added; Release excludes fixture sources. Native DEBUG App composition parses selection
  before live stores and rejects every unimplemented story with its ID/variant;
  gallery selectors require standalone GalleryHost. Package DEBUG rejects selectors
  without linking the fixture target; ordinary launch remains unchanged.
- Standalone native F02 gallery smoke avoids WattApp/real preferences and reuses the
  existing permission-preflighted app-owned window capture helper. Light/dark each
  repeat with zero pixel differences at 2×; deliberate two-pixel geometry drift is
  rejected. Crop/overlay/diff helpers never resample or mask defects.
- Validation: 94 package and 94 hosted tests pass, including nine F05 checks; one
  unimplemented-story UI scaffold explicitly skips. Native Release build/analysis,
  source-membership omission checks and six image-helper checks pass.
- **F05 remains partial:** pre-store fail-closed App composition is verified; isolated
  normal-shell fixture rendering, runtime status-item capture, keyboard/VoiceOver and story-specific native
  captures remain open. No backlog story or production gate is completed by F05.

## P01 local power telemetry (2026-09-23)

- `SystemPowerSourceTelemetryService` uses IOKit power-source descriptions for battery state/percentage and the local `AppleSmartBattery` IORegistry properties for measured `PowerTelemetryData`: `BatteryPower`, `SystemPowerIn` and `SystemLoad` are milliwatts and are converted to signed battery watts, charger input watts and system-draw watts. Adapter `Watts` is a capability/rating, not the live input measurement, and is intentionally not displayed as charge rate.
- Present internal battery metadata yields battery capability `.available`; explicit absence yields `.unsupported`; malformed/missing presence/type remains `.unknown`. UPS metadata is not misidentified as an internal battery. Charging, externally charged and discharging require explicit documented state/boolean evidence; percentage alone never implies charged and noncharging AC never proves charging hold. Overall AC/battery/UPS source is described separately from battery state in `detail`, preserving the F03 model.
- Battery state remains fail-closed and independent from measurements: public IOPS booleans/source establish charging, discharging or full; the registry payload supplies numbers only when finite and non-negative. Positive battery watts mean charging, negative means drawing from the battery, and a real zero is preserved for a full battery. Missing or malformed registry telemetry leaves only the affected capability unavailable rather than fabricating zero.
- The normal production store is initialized with `SystemPowerSourceTelemetryService`. Because normal launch suppresses `MenuBarExtra` on hosts where it does not materialize a status item, the visible AppKit fallback status item now owns the cancellable three-second sampling task; the hidden SwiftUI label remains the fixture/harness scheduler.
- Snapshot timestamps are app acquisition time, not hardware measurement timestamps. The service checks model validation and rejects future/nonfinite times; the store retains its existing generation, freshness and wake invalidation rules. Cancellation and acquisition failures remain `.cancelled`/`.unknownStatus`, not no-battery/zero. Reproducible checks and physical-host results are recorded in [P01 evidence](docs/evidence/P01/README.md). The 2026-09-23 host was full and on AC: battery rate `0.0 W`, live charger input `15.947 W`, system draw `15.947 W`; the installed status item announced `0.0 watts`. This is a local telemetry proof, not a claim that every Mac exposes the same registry keys or that component telemetry is available.

### C01 implementation — node 21:928

Historical implementation record: at this stage C01 alone was implemented in the
native Debug fixture composition (`--watt-fixture C01`, optionally `/base`);
later story sections extend the registry. The styling and visual scores below
predate and are superseded by the [native-control mapping decision](#native-control-mapping-decision--2026-09-22).
They do not describe current production chrome or approve its current appearance.
The shared status panel reads `PowerReading` capabilities and `PowerFormatter`; the
charger model description is fixture-only because P01 does not supply that metadata.
Unavailable values are em dashes (announced as “Unavailable”), not fabricated zeroes;
Settings and Quit remain active. Power is a semantic group without a visible heading,
matching the reference. Following the historical independent score-88/100 FAIL
review, C01 used local blue-violet gradient/card/perimeter tokens, optical spacing,
action blue #0091FF, layered violet/diagonal gradients and 1pt inset corrections.
Those custom treatments were subsequently removed, not retained as current design
requirements. Current StatusPanelView uses native grouped Form/Section and
LabeledContent; SwiftUI/AppKit owns control styling, materials and corners under
the mapping decision linked above. The historical panel capture was 320×473pt;
no desktop image was reproduced.
The correction has 17 passing native and 17 package focused tests, a passing native
Debug build/static analysis, and a fresh app-owned capture. These checks are not
visual approval; the subsequent independent review recorded **92/100 PASS**,
closing the C01 visual correction with residual material/typography differences.

The Debug app-owned capture uses the actual `StatusPanelView`, dark Aqua, en_US,
320×473pt content, pinned sample clock and isolated `InMemoryStorage`. Release excludes
fixture selection/capture code. Evidence and reproduction: `docs/evidence/C01/README.md`.
The independent **92/100 PASS** is recorded in
[the visual review](docs/evidence/C01/visual-review.json) and covers only the
deterministic C01/base panel fixture, not pixel identity, the desktop or the
system-owned selected status-item background/bolt anchor. The strict pixel
comparison remains FAIL; passing tests and pixel diagnostics are not visual approval.
AX/VoiceOver traversal and live interaction (MenuBarExtra opening/closing and
Settings/Quit behavior) still require authorized graphical-host testing.
Production telemetry/helper wiring and charger-description metadata remain
unverified; fixture evidence is not proof of live readings.

### P02 — isolated helper lifecycle contract/adapter story (2026-09-20)

`HelperLifecycleAdapter` implements the F03 `HelperService` contract with explicit injected registration and authenticated-transport boundaries. Registration checks the bundled candidate identity/version before effects; connected requires enabled status, peer authentication and a correlated handshake. The allowlisted IPC envelope binds request, generation, command and optional receipt. Reconnect reauthenticates; removal invalidates outstanding callbacks and proves absence; update requires receipt-specific installed-version proof plus authenticated reconnect. Ambiguous acknowledged registration/update receipts are reconciled rather than replayed blindly. F03 origin interest/presentation tokens remain authoritative for cancellation/rejoin and single navigation delivery; no AppRouter or scene changes were necessary.

This is an **isolated contract/adapter story with deterministic test evidence only**, not signed ServiceManagement/XPC integration or approval automation. No production driver, helper binary, signing identity, entitlement, installation path, privileged action, new power capability, root operation or TCC workaround was introduced. Concrete drivers must provide finite deadlines, authenticated actual-peer identity (not payload claims), client authorization, safe owned-resource operations and durable receipt/idempotence/recovery evidence. OS approval cannot be revoked by app cancellation. **Separate production prerequisite (DEC-01/02/04): signed helper installation, real OS approval, authenticated XPC and verified removal still require production integration and evidence.** The full P02 signed-install gate remains open; isolated contract/adapter completion does not satisfy it. See `docs/evidence/P02/README.md`; P01 and C01 evidence are unchanged.

## P03 — notification and login adapters (2026-09-20)

- Additive P03 sections in the existing service/test target members preserve F03 protocols and P01/P02 behavior. `SystemNotificationBridge` uses an injected `NotificationSystemDriver`; `NativeNotificationDriver` wraps public UserNotifications authorization/settings and local enqueue APIs. Only explicit `requestAuthorization()` may prompt. Delivery never requests permission. Denial and conservative provisional/unknown mapping lead to a Settings action, not helper authority or navigation.
- `PowerNotificationEffects` models J6.3/J6.4 preference × permission effects: off suppresses; undetermined offers permission; denied offers Notification Settings; authorized attempts enqueue. Preference changes are rechecked after status reads. Callers supply validated event episode IDs; acceptance/deduplication is not visible delivery proof. No threshold policy, telemetry mutation, production event wiring or notification-click route is introduced.
- `SystemLoginItemService` separates desired preference from freshly reconciled OS status. Its injected native driver wraps public macOS 13+ `SMAppService`; future composition must supply `.mainApp` for Watt login behavior, not a privileged helper. Enabled/pending/absent states avoid repeated register/remove effects; unknown/missing fail closed. Ambiguous effects are retained in memory and not blindly replayed. Requires-approval is not effective enabled. Persisted intent is never rewritten as effective success; failed preference writes block application.
- Evidence: [P03 report](docs/evidence/P03/README.md). **15 focused tests; 138 package and 138 native-hosted tests each, one intentional P01 skip and zero failures; Debug build and Release analysis pass.** No actual permission prompt, login registration, notification, System Settings navigation or real-session restart was exercised. This closes the isolated adapter verification, not the separately required signed production/permission/login integration gate.
- P03 read-only evidence follow-up: `scripts/P03/read-only-status.sh` compiles a separate native probe bundle and records two fresh process reads of public notification authorization and `SMAppService.mainApp.status`, with OS/toolchain, PID and UTC timestamps. On macOS 27.0 both reads returned `notDetermined` (0) / `notFound` (3), exit 0; see the [P03 follow-up](docs/evidence/P03/README.md#read-only-native-status-follow-up-2026-09-20). This is probe-identity process restart/reconciliation evidence only, not Watt/session restart, notification delivery, registration absence or approval mutation proof. No permission request, registration/removal, Settings, TCC/background-item configuration mutation or Accessibility is used; production gates remain open.

## P04 injected updater adapter (2026-09-20)

- `UpdateAdapter` implements the unchanged F03 update contract with injected source, pinned signing trust, transactional storage and installation driver. Detached Ed25519 signatures bind manifest identity/build, minimumSystemVersion and artifact SHA-256; confirmed install, separately requested relaunch, cancellation/late-reply retirement, durable receipt tombstones, interrupted replacement recovery and verified rollback are explicit. Completion requires installed/running artifact and exact receipt proof from the driver, not merely persisted success.
- Isolated evidence: **29 focused tests**, **167 package and 167 native hosted tests**, each full suite with **1 intentional skip and 0 failures**; Debug build/analysis, Release analysis and diff/project syntax checks pass. Signed non-executable fixture artifacts and a temporary atomic journal exercise success, corrupt/wrong-identity rejection, pre/during/post-replacement interruption, rollback/relaunch/write failures, restart reconciliation and unrelated-data preservation. [P04 evidence and exact boundaries](docs/evidence/P04/README.md).
- **Production DEC-01/03 remains open:** no production endpoint/key, Security code-signature driver, install/relaunch implementation, real signed old→new app execution or secure durable journal composition. Protocol/fake proof is not OS process or notarization proof; no real app was replaced or untrusted artifact launched. No J10 UI story closure, P01–P03/C01 edits, or Ultragoal checkpoint is claimed.

- P04 verifier correction: signed `minimumSystemVersion` is required with strict ASCII `MAJOR.MINOR[.PATCH]` grammar (no signs/leading zeros, positive major, nonnegative Int components). Check/download/install/relaunch compare it numerically against the explicitly injected host macOS version; missing/malformed or newer candidates fail closed before staging/replacement. Recovery and cleanup remain available after host downgrade. Four focused regression tests cover current/older/newer, malformed/missing values and install revalidation/cleanup. Older manifests without the field are rejected, not silently migrated. Actual bundle minimum-OS validation and production supported-version policy remain driver/integration obligations; no real app replacement or private APIs were added. See the [correction evidence](docs/evidence/P04/README.md#minimum-os-correction-2026-09-20); Ultragoal checkpoint remains leader-owned.

## P05 — isolated scoped removal and uninstall (2026-09-20)

`ScopedRemovalAdapter` preserves F03 `UninstallCoordinator` and uses P02 authenticated helper reconciliation. An installation-bound explicit manifest, fresh inventory and write-ahead receipt/scope binding govern ordered login → helper → configuration → application cleanup. Partial reports retain remaining paths, failed step/reason and process state; neither missing bytes nor an acknowledged effect alone proves success. Already-absent resources and second retries are safe. Helper-only removal preserves the initial app-running state even across retries. Explicit reverse-order rollback verifies the original inventory, preserves intervening/unrelated data and blocks deletion while recovery is active or retired.

This is **injected adapter/in-memory fixture evidence only**, with no production cleanup driver, OS registration mutation, real helper connection, filesystem deletion, process termination or app/scene wiring. Concrete authenticated, race-safe owned-resource operations, durable receipts/backups, actual process absence, rollback approval and final cleanup of recovery records remain production prerequisites. P04 update/recovery artifacts are not implicitly authorized for deletion. See `docs/evidence/P05/README.md` for tests, exact verification results and production limits. Gate E and production “nothing left behind” acceptance remain open; no Ultragoal checkpoint was written.

## C02 / G013 — On-battery light panel

Source: Figma file `9DKDgUfEqidZdZQEVlQgLS`, frame `22:130`, panel
`29:9158`. Exact retained frame export: `.omx/plans/f00-reference-evidence/exports/22-130.png`.
MCP panel context and hierarchy are retained in `docs/evidence/C02/`.
Node names are not literal copy: the rendered screenshot/user contract says
**On battery**, **−18.4 W**, **64% · about 4 h 10 min left**.

- Reuse C01's native `StatusPanelView`, MenuBarExtra window entry, row/group
  hierarchy and Settings/Quit callbacks; no new screen abstraction or dependencies.
- Panel 320×473pt; reference crop x551/y40 in the 900×640 frame.
  Items inset 12/5; nested content inset 9 gives 21pt horizontal / 14pt top.
  Header 278×66; title/headline/subtitle relative y0/18/52.
  Power group relative content x9/y87, 278×126; three 42pt rows.
  Components heading y225; group y253, 278×168, four 42pt rows.
  Footer x9/y433, 278×24; native borderless/link Settings… and Quit Watt?.
- Figma typography: SF Pro bold 13/16 title, bold 26/32 headline,
  regular 11/14 subtitle. Existing system body-emphasized, largeTitle-bold,
  subheadline and body tokens are reused (OS optical metrics remain a review gap).
- Existing C01 optical spacing remains unchanged: 21pt content inset, 10pt row
  inset, 41pt rows plus 1pt separators, 12pt group top gap, 13pt component
  heading gap, 16pt footer top gap. Shared section/window radii and semantics.
- **Historical/superseded styling:** C02 previously used warm beige/gray
  `StatusPanelStyle.lightSurface` gradients and a diagonal white/black overlay,
  alongside the former C01 dark gradients. These custom surfaces and the
  `StatusPanelStyle.lightSurface` implementation were removed. The optical
  spacing specifications above likewise describe the earlier capture, not current
  native-control metrics. Current C01/C02 share StatusPanelView's grouped
  Form/Section and LabeledContent with system-owned styling; see the
  [native-control mapping decision](#native-control-mapping-decision--2026-09-22).
  Historical captures/scores do not transfer approval to the current native UI.
- Power values: Unplugged / 18.4 W / −18.4 W. Components: CPU 6.2 W,
  GPU 1.9 W, Display 4.8 W, Other 5.5 W. Panel-local Unicode minus avoids
  changing the common formatter or other status-item strings.
- Unplugged requires usable source/freshness, discharging state and explicitly
  disconnected charger capability. Unknown/unsupported/permission-required or
  unavailable readings retain unavailable semantics; never fabricate zero watts.
- DEBUG native selectors C02 and C02/base use pinned `sampleOnBattery`,
  fake clock and fresh in-memory preferences before ordinary store composition.
  Only C01/C02 are renderable; all remaining stories fail closed.
  Package executable selectors reject; Release excludes C02 fixture and launch paths.

Evidence: app-owned light 320×473pt window at 2x, raw PNG, explicit normalized
1x derivative, exact reference crop, hashes, overlay/diff and logs in
`docs/evidence/C02/`. Strict pixel diagnostic fails; **independent visual verdict
pending, no visual pass claimed**. No desktop capture, AX automation, permission
request or TCC bypass. Production P01 telemetry/helper wiring, actual menu-opening/
Settings/Quit interaction and AX/VoiceOver traversal remain unverified separately.

## C03 / G014 — Native secondary-click menu (dark)

Source: Figma file `9DKDgUfEqidZdZQEVlQgLS`, frame `22:1095`,
context menu `22:1345`, submenu `22:1811`. Exact F00 export, MCP context,
unresampled crops, hashes and diagnostic overlays/diffs: `docs/evidence/C03/`.

- Hierarchy: existing single MenuBarExtra status item → native NSMenu.
  Show in Menu Bar → separator → Open Watt? → Settings… (⌘,) → separator →
  About Watt? → Check for Updates… → separator → Quit Watt? (⌘Q).
- Submenu: Delta (checked in base), Charger, Draw, Components → separator → Icon.
  No shortcut on the submenu parent or display modes. Selection persists through
  PreferencesStore and checkmarks are rebuilt on the next opening. The status label
  observes that same store: Delta/Charger/Draw use existing reading values, Components
  uses selected IDs in order, and Icon is symbol-only; unavailable values remain “—”.
- Current native-styling contract: NSMenu/AppKit owns image/state columns, native
  system font, widths, material, focus and selection. Keep native separators,
  checkmarks, chevrons and key equivalents; no fabricated spacer images, forced
  image visibility, explicit font/minimum-width overrides or custom row chrome.
- **Historical/superseded C03 styling:** earlier captures used NSMenu minimum widths
  230pt / 190pt, a public 13pt regular NSMenu.font request and transparent 14pt/1pt
  image slots to place main/submenu titles at ~36/~37pt (reference ~36pt).
  macOS 27 used preferredImageVisibility=visible; image accessibility descriptions
  were nil. Figma reports SF Pro emphasized 13/16 and menu heights 187pt / 141pt;
  the earlier native capture matched those bounds. These metrics and spacer-image
  experiments are historical evidence, not current styling requirements or proof
  of the current menu's geometry or visual acceptance.
- Variants: native hover/keyboard highlight, darkAqua fixture, Delta checked;
  ordinary production appearance remains system-managed. The actual status button
  is highlighted during right/control-click tracking and restored on dismissal.
  Open/Settings/Updates reuse AppRouter; About uses the standard AppKit panel;
  Quit uses application termination. Incomplete ordinary setup retains Finish Setup.
- C03/base (also C03) is a DEBUG-only pre-store-gated selector, with pinned charging
  +42.1 W reading, isolated in-memory preferences, setup completed and Delta selected.
  C01/C02 remain supported; every other story/unknown variant rejects. The package
  executable rejects fixture selection; Release excludes the fixture harness.
- Capture: same native menu factory on an app-owned DEBUG anchor window, local
  mouse-move hovers the parent and opens the real submenu, NSView.cacheDisplay records in-process
  native menu surfaces. No desktop capture, AX access or TCC request. This does not
  prove the actual status-item anchor placement, VoiceOver, vibrancy/compositor
  pixels or physical pointer interaction. The edge-positioned capture now opens left,
  with parentHighlighted=true, submenuHighlighted=none and deltaChecked=true.
  Native overlap is 5pt versus reference 4pt; material, heavier font rendering and
  separator insets remain OS differences. Capture state is asserted, not treated as visual fidelity.
  Focused package/native: 28 tests each; full: 202 each, one opt-in skip, zero failures.
  Debug/Release build+analyze pass. Actual status-button repaint remains unverified.
- Diagnostic diffs fail; no visual pass, accessibility sign-off or checkpoint.
  The C02 “only C01/C02” implementation inventory above is superseded by C01–C03.

- **Final bounded C03 correction (2026-09-21): 83/100 self-assessed**, versus the
  user-provided prior 79/100; not an independent calibrated score or acceptance.
  Exact reference and final native captures were inspected directly. Spacing is
  improved; transparent native image slots preserve native title/action/AX semantics.
  Regular attributed titles and vibrantDark appearance were tried, did not visibly
  fix font/material, and were removed. Standard NSMenu has no public material-tint
  or separator-inset setting; in-process caching does not capture WindowServer
  vibrancy. Production appearance remains inherited; no private APIs or bitmap menus.
  Final focused/full package/native tests, Debug/Release build+analyze, Release
  isolation and static checks pass (counts above unchanged). Pixel diagnostics
  still fail: 99.886% main / 99.922% submenu changed. Details, rubric and experiment
  artifacts: [C03 evidence](docs/evidence/C03/README.md). No checkpoint; stop after
  this pass. Runtime AX/physical interaction and actual status repaint remain unverified.


### C03 latest experimental pass — 2026-09-21

Latest supplied fidelity is **84/100**, superseding the historical 83/100
self-assessment above. No new score, independent visual verdict or checkpoint.
Reference intent remains dark translucent blue-gray, a thin rounded border, regular
SF text, selected blue parent and idle checked Delta.

A standalone NSMenuItem.view + NSVisualEffectView/menu-delegate probe was rejected:
its titles, shortcut dispatch and submenu attachment survived, but the tested
Down/Right/Down/Return sequence no longer invoked the selected action, and standard
checkmark/chevron/highlight drawing disappeared. This is an observed failure of the
minimal candidate, not a universal accessibility claim. No custom row, delegate
background hack, private window mutation or fake bitmap was applied to production.
Public delegates expose no menu-wide material/border hook; row-local visual effects
do not reproduce that surface. Retain existing safe native settings; no further
safe visual change was demonstrated. Full reasoning and reproducible probe:
[latest C03 evidence](docs/evidence/C03/README.md#latest-bounded-custom-view-feasibility-pass--2026-09-21).

Fresh focused package/native suites pass 29 tests each; full suites pass 203 each
with one opt-in physical telemetry skip and zero failures. Debug/Release build and
analyze pass. Capture state and reference-sized bounds pass; pixel comparisons
remain failing. Refreshed assets are prepared for independent comparison, but no
independent reviewer/AX audit/compositor evidence was available. Accessibility and
physical interaction sign-off remain unverified; C03 is not visually accepted.


### Native-control mapping decision — 2026-09-22

Figma controls specify semantic intent, not replacement macOS chrome. Map actions
to native bordered/borderedProminent Buttons (destructive roles where appropriate),
reading choices to a radio-group Picker, label/value rows to LabeledContent, and
grouped content to Form/Section. SwiftUI/AppKit owns accent, focus, disabled states,
materials and corners; no custom backgrounds, corner shapes or button chrome
unless an explicitly evidenced Figma semantic token requires them. This decision
supersedes historical pixel-matching prescriptions for these shared controls.

Keep the existing single-instance Window and Settings scenes, MenuBarExtra and
NSMenu semantics. Use List/NavigationStack for actual collections/navigation and
WindowGroup only for multi-instance windows; do not add fake navigation to shells.
The component gallery follows the same native controls without root paint overrides.

Evidence: shared component implementations, StatusPanelView's grouped Form,
onboarding's LabeledContent/cancel shortcut, and NativeStylingTests plus existing
SharedControlTests/ReadingPickerTests. Layout tests cover light/dark and increased
contrast appearances; source guards reject custom shared-control chrome. These
checks are not VoiceOver, physical keyboard/pointer, compositor or pixel-fidelity
acceptance. Historical screenshots predate this correction and need recapture;
existing DEBUG capture backdrops are fixture-only, not production styling.

Verification for this correction: Xcode toolchain (`DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer`),
11 focused package tests passed; full package and hosted `WattTests` each executed
208 tests, one opt-in physical telemetry skip, zero failures. Debug build, Release
analyze and `git diff --check` passed. Hosted evidence:
`.build/native-styling/StylingTests.xcresult`. UI automation was not run. The default
Command Line Tools attempt failed on missing SwiftUIMacros; selecting Xcode fixed
it without source workarounds. Existing unhandled build-artifact warnings and the
no-AppIntents metadata warning remain; neither failed validation.

Fresh bounded verification (2026-09-22): [current-source gallery and report](docs/evidence/native-styling/verification-2026-09-22/README.md)
supersede the recapture-pending statement above for F02 shared controls only.
Light/dark gallery top/bottom, reading (native window frame) and settings are freshly
captured in-process without TCC/desktop capture. NativeStylingTests pass 3 package
and 3 hosted tests; Debug build/analyze pass. Native ownership is verified, but
inactive-window captures do not prove active accent/focus or accessibility.
Reference fidelity remains partial (82/100 self-assessment, not independent approval);
legacy scores do not transfer. Product code unchanged in this verification; no checkpoint.


Remaining native-styling review corrections (2026-09-22):
[follow-up evidence](docs/evidence/native-styling/verification-2026-09-22/review-corrections/README.md).
The gallery TextField now owns its single label. The settings specimen menu-bar
note belongs to its Section footer, not a standalone rounded Form row. The actual
SettingsRootView shell now uses grouped Form/Section with existing explanation and
status in the footer, without extra stack padding/section-spacing overrides or
custom chrome. Shell content/routes remain placeholders; this does not implement C05.
Its unchanged 540×320 viewport scrolls natively to reveal the complete footer.

New source regressions fail before correction and pass afterward: NativeStylingTests
5 package + 5 hosted; full package and hosted WattTests each execute 210 tests,
1 opt-in physical telemetry skip, 0 failures. Debug build, Release analyze,
ShellCheck, Bash syntax, whitespace and evidence hash checks pass. Twelve fresh
light/dark captures include gallery top/bottom, settings specimen, actual settings
shell top/bottom and reading. Retained Figma exports were inspected; the two concrete
composition findings are resolved, but native spacing/metrics, inactive accent and
accessibility limitations remain. No new fidelity score, independent sign-off,
UI automation, story completion or checkpoint is claimed. Earlier evidence remains
historical; no custom paint was reintroduced to force Figma pixel parity.

### Native status-item fixture decision — G015/C04.1, 2026-09-22

For available charging delta, use native SF Symbol
`battery.100percent.bolt` plus the existing formatter's `+42.1 W`, as confirmed
by Figma component 24:636 inside frame 24:390 (anchor 24:638). Keep observed
display-mode/show-symbol preferences and existing system-semantic emphasized
typography; do not introduce painted menu-bar chrome or alter shared tokens.
Icon-only still forces symbol visibility; other display/state combinations retain
their existing symbol/formatting behavior.

DEBUG evidence hosts must match the exact exported frame (here 560×44 points),
not a cropped approximation. Record app-owned component bounds separately
(here x205,y5,96×24, top-left coordinates), retain raw pixels, and disclose any
scale normalization. An app-owned NSStatusBarButton cached in a bounded window
is valid native-component evidence, not live MenuBarExtra compositor or system
placement evidence. Never imitate wallpaper/system neighbors to claim a pass.

[Current evidence](docs/evidence/C04.1/README.md): four focused tests pass in
package and native hosts; both full suites execute 212 tests with one skip and no
failures; Debug/Release build/analyze pass. Full-frame/item pixel checks fail:
synthetic backdrop and native rasterization differ. Visual, interaction and
accessibility acceptance remain open; no story completion or checkpoint.

### C04.1 capture-scale correction — 2026-09-22

Capture-only correction: preserve the production native label/status-item/scene.
For exact-reference 1× evidence, allocate NSBitmapImageRep at 560×44 pixels and
560×44 points and invoke public NSView.displayIgnoringOpacity(_:in:) on the
app-owned host. Keep screen-scale cacheDisplay as a separate diagnostic; do not
downsample it into the reference input. Capture metadata records both scales.
A unit destination transform does not guarantee how AppKit/SwiftUI internally
cache layers; do not claim rasterization or baseline parity from dimensions alone.

Five focused tests pass in each package/native host; Debug/Release build/analyze
and Release isolation pass. Fresh unmasked frame/item comparisons still fail
(backdrop differs); no new independent score replaces the supplied earlier 86.
See [current evidence](docs/evidence/C04.1/README.md). No production style changes,
desktop capture, story acceptance, checkpoint or commit.


### G016 / C04.2 — Delta · on battery — 2026-09-22

Exact frame `24:639`, status item `24:755`, anchor `24:757` in Figma file
`9DKDgUfEqidZdZQEVlQgLS`. DEBUG `C04.2/base` selects `PowerReading.sampleOnBattery`
before normal stores, with pinned clock and fresh in-memory delta/symbol preferences.
The native SwiftUI status label displays `battery.100percent` plus `−18.4 W`;
accessibility value is `−18.4 watts`. Only available discharging delta changes;
other modes and C01–C04.1 remain covered. No shared formatter/style changes.

Reuse the real app-owned NSStatusBarButton capture harness, never a bitmap label or
custom desktop menu bar. Exact evidence destination is 560×44 pixels/points; item
97×24 at top-left (204,5), right edge 301. Direct 1× output is not resized. Normal
fixture launches retain MenuBarExtra; only explicit DEBUG capture substitutes the
native NSStatusItem harness. Release excludes fixture selection/capture.

Fresh focused package/hosted tests: 9 passed each. Full package/hosted suites:
217 tests each, one opt-in telemetry skip, zero failures. Debug and Release build/
analyze, release isolation, shell lint and whitespace checks pass. Evidence:
[docs/evidence/C04.2/README.md](docs/evidence/C04.2/README.md).

Visual self-review **86/100 FAIL**, not independent approval. Native foreground
weight/baseline/rasterization differ; the synthetic backdrop deliberately omits
system desktop content. Both unmasked pixel diagnostics fail (changedFraction 1.0).
No live compositor/global-position, physical interaction or VoiceOver proof.
Visual acceptance remains open; no ledger update, checkpoint or commit.

### Native on-battery status-item fixture — G016/C04.2, 2026-09-22

Exact reference: frame **24:639**, item **24:755**, anchor **24:757**.
The retained 560×44 export and metadata place the full **97×24** item at
**x204,y5**, ending at x301. Fresh Figma context resolves `􀛨 −18.4 W` to
`battery.100percent` plus U+2212 minus text, SF Pro Semibold **13/16**.
Do not infer a 64%-charge glyph from the sample; use the actual Figma symbol.

C04.2/base now has an isolated DEBUG fixture using existing
`PowerReading.sampleOnBattery`, its timestamp-pinned clock, and in-memory
`PreferencesStore`. Production `MenuBarStatusLabel` uses the new symbol/minus
only for available discharging Delta, including `−18.4 watts` accessibility.
Existing native font/spacing, shared formatter and C04.1 behavior are preserved.
C04.3–12 remain unimplemented. Fixture registry “implemented” denotes a render
target, **not visual acceptance**.

[Current C04.2 evidence](docs/evidence/C04.2/README.md) retains the exact export,
fresh contexts, real app-owned NSStatusBarButton render, unresampled direct
560×44 bitmap, crop/diff/overlay artifacts and test/build logs. It reuses C04.1's
DEBUG capture path with C04.2-specific bounds/selector. A fresh C04.1 capture is
byte-identical to its earlier direct 1× evidence.

Focused package/hosted tests: 9 each passed (C041+C042). Full package/hosted
suites: 217 each, one opt-in physical probe skipped, zero failures. Debug/Release
build and analysis, Release selector isolation, whitespace and shell checks pass.

**Visual acceptance remains open.** Both unmasked pixel comparisons fail
(changedFraction 1.0). Native foreground rasterization/weight, baseline and
spacing differ; the synthetic dark backdrop omits system neighbors/wallpaper.
This proves a relocated app-owned native button, not live MenuBarExtra
compositor pixels or global placement. The Figma 13/16 contract is not claimed
as pixel-matched by the unchanged native typography. No desktop/TCC capture,
independent visual approval, VoiceOver traversal or physical-interaction proof.
No checkpoint, commit or story-completion claim.

### Native fully charged status-item evidence — G017/C04.3, 2026-09-22

Exact reference: frame **24:758**, component **24:874**, anchor **24:876**.
The native label uses `battery.100percent.bolt` plus **`0.0 W`**. Retained
C04.3/base evidence captures a real app-owned NSStatusBarButton into an exact
**560×44-pixel / 560×44-point** direct 1× bitmap without resampling; the
**81×24** component is at top-left **x220,y5**. Screen-scale pixels remain a
separate diagnostic, not the comparison input.

[Existing C04.3 logs and artifacts](docs/evidence/C04.3/README.md) record
**13 focused tests passed** in each package/native host, **221 full-suite tests
executed in each host, 1 skipped, 0 failures**, and successful Debug/Release
build and analysis. Release selector isolation, Bash syntax and ShellCheck pass.
These are retained results, not reruns for this documentation update.

Both unmasked frame/component comparisons **fail** (changedFraction **1.0**).
The supplied independent visual review scores **88/100 component similarity**,
not pixel parity or acceptance. **Visual acceptance remains open:** a relocated
app-owned native capture with a synthetic backdrop cannot prove live compositor
pixels/global placement, AX/VoiceOver or physical interaction, or TCC-authorized
capture. No source inspection/change, story-completion claim, checkpoint or commit.

### Native charger-input status item — G018/C04.4, 2026-09-22

Frame 24:877 / desktop 24:878 / anchor 24:995 / component 24:993 uses the existing
native `MenuBarStatusLabel` in `.charger` mode: unsigned `65.0 W`, `bolt.fill`,
accessibility value `65.0 watts`, system semibold body typography (reference SF Pro
13/16). DEBUG fixture input is available 65.0 W with a deterministic clock;
selector rejection remains before stores. The C04.1–3 app-owned native status-item
harness is reused at 560×44 with component x221,y5,80×24. No custom desktop/menu-bar
chrome or bitmap UI. [Fresh evidence](docs/evidence/C04.4/README.md): focused
package/hosted tests each pass 16 tests; full package/hosted suites each execute
224 tests with one opt-in hardware probe skipped and zero failures. Debug and
Release build/analysis, Release fixture isolation, Bash syntax and ShellCheck
pass. The initial invalid C041 test-helper assertion was removed; fresh runs
supersede that compile failure without production behavior changes.

C04.4 now retains a real app-owned NSStatusBarButton capture, direct 560×44
pixel/point bitmap, unresampled 80×24 component crops and comparison artifacts.
Both unmasked strict comparisons fail (changedFraction 1.0): the relocated native
button uses the existing synthetic backdrop, not live desktop/menu-bar compositor
pixels. Native bolt/`65.0 W` content is present; pixel parity, live placement and
AX/VoiceOver remain unproven. **Visual acceptance remains open**; registry
render-target availability is not a pass. No TCC bypass, commit or checkpoint.

### Native unplugged charger fallback — G019/C04.5, 2026-09-22

Exact frame **24:996**, component **24:1112**, anchor **24:1114** specifies native
`battery.100percent` and unsigned **18.4 W**. DEBUG `sampleUnpluggedCharger`
uses `.chargerInput` mode, disconnected charger and available System Draw;
`C04.5/base` uses isolated charger-display preferences and a pinned clock.
The status label opts into System Draw fallback **only** for `.chargerInput`
readings; ordinary `.onBattery` readings retain legacy charger-display
`-18.4 W`/`bolt.fill`. Default `PowerReading.value(for: .charger)` remains
batteryDelta. C03 and C04.1–4 behavior and assertions are preserved.

[Evidence](docs/evidence/C04.5/README.md): final-source focused package/hosted
suites pass 20 tests each; full package/hosted suites execute 228 each, one
opt-in hardware probe skipped, zero failures. Debug build and analysis pass.
The native capture harness is reused without custom chrome/TCC changes.
Retained native battery/18.4 W captures **predate the final mode-scoping fix**;
no final-source recapture is claimed. Both strict pixel comparisons fail;
visual parity, live compositor, accessibility interaction and telemetry gates
remain open. Render-target availability is not story completion. No commit
or checkpoint.

### Native desktop System Draw — G020/C04.6, 2026-09-22

Exact Figma frame **24:1115**, desktop **24:1116**, anchor **24:1233**, component
**24:1231**. Live MCP context confirms dark `􀋦 38.2 W`, SF Pro Semibold 13/16;
metadata confirms x221,y5,80×24 within 560×44. DEBUG `C04.6/base` now selects a
fixed-clock `.systemDraw` fixture with `.noBattery`, unsupported battery,
available systemDraw and systemWatts **38.2**, with isolated `.draw` preferences.
Existing native label/style yields `bolt.fill`, unsigned **38.2 W** and
accessibility value **38.2 watts** without production presentation changes.
C04.1–5 assertions remain intact; C04.7–12 remain unavailable.

[Fresh C04.6 evidence](docs/evidence/C04.6/README.md): focused package/hosted
23 tests each; full package/hosted 231 executed each, one opt-in hardware probe
skipped, zero failures. Debug and Release build/analyze pass; Bash syntax,
ShellCheck and whitespace checks pass. Final-source app-owned NSStatusBarButton
capture retains direct 560×44 and separate 1120×88 diagnostic PNGs, no resampling.
No bitmap UI, custom production chrome, TCC changes, commit or checkpoint.

Strict unmasked pixel comparisons **fail**: frame 24,638/24,640 changed pixels,
item 1,918/1,920. Both reports retain `storyDone: false`. Synthetic capture
backdrop/native rasterization are not Figma desktop parity; visual acceptance,
live compositor, AX/VoiceOver, interaction and real telemetry proof remain open.

### Native component-selection status item — G021/C04.7, 2026-09-22

Exact Figma frame **24:1234**, component **24:1350**, anchor **24:1352**.
DEBUG `C04.7/base` uses a fixed-clock `.perComponent` fixture and isolated
in-memory `.components` preferences. The existing native label displays
**`CPU 9.8 · GPU 4.1 W`**, without a symbol. Ordered selection retains the
max-two distinct, nonblank IDs contract; invalid three-item assignments preserve
the prior selection. Shared trailing units apply only to available explicit
per-component values; legacy charging/C03 formatting remains unchanged.

[Retained C04.7 evidence](docs/evidence/C04.7/README.md): focused package/hosted
suites pass **26 each**; full package/hosted suites execute **234 each**, with
**one opt-in physical-host probe skipped and zero failures**. Debug and Release
build/analysis logs record success. These are existing results, not reruns for
this documentation update.

Capture retains an app-owned NSStatusBarButton in a direct **560×44** bitmap,
with **148×24** component at **x153,y5**, plus a separate screen-scale diagnostic;
no resampling. Strict unmasked frame/item comparisons **fail** (24,640/24,640
and 3,552/3,552 changed pixels; fraction 1.0). Both reports retain `storyDone: false`.
**Independent visual review is pending; visual acceptance remains open.** The
relocated button/synthetic backdrop cannot prove live MenuBarExtra compositor
pixels, global placement, AX/VoiceOver, physical interaction or real telemetry.
No source/test changes, story-completion claim, commit or checkpoint in this
 documentation update.

### Native icon-only status item — G022/C04.8, 2026-09-22

Exact Figma frame `24:1353`, desktop `24:1354`, anchor `24:1471`, status
component `24:1469`: dark native `battery.100percent.bolt`, no text, SF Pro
Semibold 13/16 contract via existing body-emphasized system typography.
DEBUG `C04.8/base` uses available `sampleCharging`, a fixed clock, isolated
in-memory preferences and `.iconOnly`. A DEBUG-only label switch preserves
ordinary/unavailable icon-only behavior outside this available fixture.
Accessibility retains `Watt? power reading` / `Icon only`.

[Fresh C04.8 evidence](docs/evidence/C04.8/README.md): focused package/hosted
29 tests each passed; full package/hosted 237 each, one skipped, zero failures;
Debug/Release build and analysis, release isolation and static checks passed.
The reused app-owned native capture uses x260/y5, 41×24 in a direct 560×44
bitmap, without resampling. Strict unmasked frame/item comparison fails
(24,640/24,640 and 984/984 changed pixels); visual acceptance remains open.
Synthetic-backdrop capture is not live compositor, interaction or AX proof.
No custom chrome, bitmap UI or TCC changes. C04.9–12 remain unavailable.

### Native unavailable status item — G023/C04.9, 2026-09-22

Frame `24:1472`, component `24:1588`, right-aligned anchor `24:1590`:
native `bolt.fill` followed by `− − W`, shared SF Pro Semibold body typography
(13/16 reference), dark appearance. The 71×24 component is x230/y5 in the
560×44 frame, ending at the 301×24 anchor's right edge. No custom chrome/assets.
DEBUG `C04.9/base` uses `.unavailable`, a fixed clock, isolated memory storage,
and the existing native status-button capture harness. No-reading Delta mode
uses the new placeholder; other modes and available readings are unchanged.
[Evidence](docs/evidence/C04.9/README.md) records passing focused/full tests,
Debug/Release build and analysis, and static checks. Strict frame/item pixel
comparisons fail; visual acceptance, live placement and VoiceOver remain open.
C04.10–12 remain unimplemented. No commit/checkpoint or TCC changes.

### G024 / C04.10 — selected status item while panel is open
Figma frame `24:1591`, component `24:1707`, anchor `24:1710`: dark,
charging battery and `+42.1 W`, shared SF Pro Semibold 13/16 token.
DEBUG `C04.10/base` reuses C04.1 fixed charging data and in-memory preferences.
The ordinary fixture opens via the existing app router and MenuBarExtra, whose
selection/dismissal remains system-owned. The opt-in bounded NSStatusItem capture
uses public NSPopover lifecycle and NSStatusBarButton.highlight, not custom chrome.
Selection is reapplied after native click tracking ends and cleared on dismissal.
Geometry is 560×44 with item x205/y5/96×24, right edge 301.
Evidence: `docs/evidence/C04.10/`. Relocated-button capture proves public lifecycle
semantics only; synthetic backdrop cannot prove desktop/compositor or selected-pill
visual parity. Strict image diagnostics remain non-passing; visual acceptance open.

### G025 / C04.11 — light menu bar charging

Exact Figma frame `24:1711`, component `24:1957`, anchor `24:1959`:
560×44 frame, right-aligned 96×24 item at (205,5), SF Pro Semibold 13/16,
battery charging +42.1 W, unselected. DEBUG C04.11/base reuses C04.1 fixed
charging semantics, independent in-memory preferences and MenuBarStatusLabel.
Public Aqua appearance supplies light contrast; production styling is unchanged.
Bounded capture uses a real NSStatusBarButton and native NSVisualEffectView menu
material, with no custom paint, pill, bitmap UI, private API or TCC change.
Other selectors retain their behavior; C04.12 remains unavailable.

[Evidence and validation](docs/evidence/C04.11/README.md) retain the exact Figma
export/geometry, direct 1x native capture, crops/diffs, focused/full tests and
Debug/Release build/analyze logs. Native app-owned subtree evidence is not desktop
compositor parity; visual acceptance remains open and comparisons do not claim
story completion. No commit/checkpoint.

### G026 / C04.12 — light menu bar, on battery

Exact Figma frame `24:1960`, component `24:2076`, anchor `24:2078`:
unselected native status item, battery outline and typographic `−18.4 W`,
SF Pro Semibold 13/16. DEBUG `C04.12/base` reuses C04.2's fixed on-battery
reading, clock, 97×24 item geometry at (204,5), and production
`MenuBarStatusLabel`/body-emphasized typography. Fresh in-memory preferences
retain Delta + symbol without affecting persisted preferences or prior stories.
Public Aqua `NSAppearance` and light SwiftUI environment reuse C04.11's native
menu-material capture path, with no custom colors, paint, selection chrome,
bitmap UI, private API, or TCC changes. Release excludes fixture routing.

[Evidence and reproduction](docs/evidence/C04.12/README.md) retain the exact
reference, native capture, geometry, hashes, comparisons and verification logs.
The app-owned capture does not reproduce desktop/compositor pixels; diagnostic
comparisons are not visual acceptance and do not mark the story visually done.

## G027 / C05 — native light Settings implementation

Exact reference: frame **25:787**, window **25:1102**, content **25:1129**,
row slots **25:1501 / 25:1751 / 25:1994 / 25:2243 / 25:2492**. The visible
third heading is **Helper**, not the internal “Component Readings” name.

`SettingsRootView` replaces the earlier shell with Menu Bar, Readings, Helper,
Notifications and General. Native grouped Form/Section, menu Picker, switch
Toggle, LabeledContent and bordered destructive/cancel buttons own layout and
semantics. No painted rows, gradients, backgrounds, capsules or window chrome.

Shared PreferencesStore bindings persist desired settings; precision migrates
compatibly and updates the status label. Removal uses an injectable router action
and fails conservatively without installation-owned service composition. Desired
login/notification/update preferences are not claims of OS service activation.

DEBUG C05/base uses fresh in-memory preferences, fixed preview telemetry and Aqua.
Non-base variants are rejected. Reference content is 580×839; native grouped
spacing requires a taller 580×1000 capture to expose every row without custom
metrics. Runtime supports a shorter scrolling viewport. Pixel parity is not
claimed. See `docs/evidence/C05/README.md` for exact metadata, capture hashes,
verification and the hosted XCTest bundle-load blocker.

### G028 / J1.1 — Welcome
Frame `27:987`, native titleless onboarding window `27:1302`, content `27:1319`.
Implemented with centered SwiftUI layout, native application-icon placeholder,
macOS SF Pro title (22 bold) and body (13 regular), semantic secondary copy,
and bordered-prominent default Continue. No custom chrome/background/button painting.
Continue persists `.picker` without marking setup complete; subsequent stories retain
the existing route shell. Native close and Escape dismiss without changing preferences.
DEBUG fixture `J1.1/base` isolates preferences in memory; release excludes capture logic.
Verification and limitations: `docs/evidence/J1.1/README.md`.

### Onboarding reading selection
Use the shared native radio-group Picker with four enum-tagged choices; Icon Only
belongs to Settings, not this onboarding choice. Components remains selectable as
an intent before helper approval, never proof of sensor availability. Persist the
selection independently from progress; Back preserves it, Continue advances only
the checkpoint. Use system bordered secondary and prominent default actions in
the existing native titleless window (system appearance). Telemetry descriptions use PowerFormatter
and unavailable values remain unknown rather than fabricated watts.


### G037 / J2.2 — Panel, component readings off
Exact Figma frame `29:2456`, panel `29:7572` at 320×347. Reuse StatusPanelView,
its grouped native Form/LabeledContent and SF Pro semantic typography. The persisted
component-readings preference gates the explicit Off state independently of telemetry
availability; stale available component samples cannot leak into Off. Enabled but
unavailable readings remain unavailable rather than Off or fictional zeroes.
Power rows retain 65.0 W / 22.9 W / +42.1 W in the deterministic fixture.
Native bordered Turn On… and borderless Settings… share Settings navigation only;
Quit Watt? is an ordinary native button, not a destructive action. J2.3 owns the
missing helper-enable Settings UI: this is a documented downstream setup dead end,
not an implicit installation/approval operation or a completed helper flow.

Production Settings, onboarding and coach mark inherit macOS appearance; forced
Aqua/light belongs only in DEBUG verification hosts. Reuse WattSpacing.settingsWidth,
onboardingWidth and xs rather than duplicated 580/480/4 literals in production layout.
No bespoke material, corner, shadow, button or status chrome is painted.

J2.2/base uses in-memory preferences, completed onboarding, fixed charging telemetry,
and component readings disabled. The actual MenuBarExtra capture hook is shared with
J1.8; it does not render a replacement window. Tests/builds pass, but capture found
zero app-owned compositor windows (screen recording preauthorized; AX untrusted).
Visual score remains null/blocked; no pixel diff or story-done claim.
Evidence and reproduction: `docs/evidence/J2.2/README.md`.


### G038 / J2.3 — Settings helper turn-on excerpt

Exact source: Figma `29:3270` / native window `29:3424`, 520×288 points.
`SettingsRootView(helperExcerpt: true)` is a verification slice of the same native
Form, Show menu Picker and `SettingsHelperRows` used by full production Settings.
Do not hide unrelated production settings to imitate an excerpt. Exact copy lives
in shared constants; spacing lives in WattSpacing. Native Form, LabeledContent,
bordered-prominent Button and system titlebar own their drawing and appearance.
The light reference override is DEBUG-fixture-only; production inherits appearance.

Turn On invokes `SettingsHelperSetup` over HelperService / HelperApprovalStore,
not an optimistic preference toggle. Unknown is not absence, denied is not approval,
requiresApproval stays Off, and a registration acknowledgement is not a connection.
Only freshly reconciled connected state with eligible settings token enables the
preference. Loading disables duplicate requests; cancellation retires presentation
callbacks and withdraws only settings interest; retry first reconciles. Open System
Settings delegates through AppRouter to the native ServiceManagement entry point.
No notification permission is requested or conflated with helper permission.
Missing signed-driver/transport composition fails closed with an explicit retryable
error. J2.4 owns the fuller approval experience and production integration handoff.

J2.3 supplies the Settings affordance formerly missing in J2.2; real helper activation
is still blocked on production composition. Actual app-owned capture succeeded on
macOS 27 with Screen Recording preauthorized and AX untrusted. The light fixture
matches native controls/copy but not Figma's compressed grouped-form metrics: footer
below excerpt viewport and titlebar/spacing differences remain. Visual verdict is
82/100, needs_iteration, NOT a visual pass or completed story. See
`docs/evidence/J2.3/README.md`; preserve native controls rather than paint the mock.

J2.3 P1 correction: Settings no longer derives helper availability from component
preferences or preview telemetry. One observed `SettingsHelperSetup.helperOn` gates
Status, Remove and the approval footer. Missing/replaced service composition clears
verified state and retires in-flight replies. The existing HelperLifecycleAdapter
publishes its state; disconnect, failed IPC or revocation immediately removes the
connected presentation. Query-only injected HelperService implementations have no
push-event contract, so read-only reconciliation runs on appearance/activation and
before removal confirmation. Reconciliation never installs or grants approval.
Persisted reading intent survives disconnect but cannot prove availability. J2.3's
no-service fixture stays Off/Turn On deterministically. Visual score remains 82,
needs_iteration/blocking; this correction does not establish visual acceptance.

## G039 / J2.4 — Waiting for approval from Settings
- Exact source: Figma file `9DKDgUfEqidZdZQEVlQgLS`, node `29:3926`.
  Pinned 1000×720 reference and verification: `docs/evidence/J2.4/`.
- Reuse SettingsRootView / SettingsHelperRows: native grouped Form, Section,
  LabeledContent, Show/Delta menu Picker; no custom chrome, spacing override,
  forced appearance or duplicate component styles.
- Pending Status value: “Waiting for approval…”; subtitle:
  “Turn on “Watt? Helper” in Login Items & Extensions.”
  Helper row: native bordered-prominent “Open System Settings”, without the off-state
  privacy subtitle, duplicate waiting message or approval footer.
- AppRouter retains SMAppService.openSystemSettingsLoginItems. Opening Settings
  grants no approval, changes no preferences and does not navigate to success.
  Appearance/activation reconciles real status and delivers only a still-active
  Settings token before enabling readings. Passive, cancelled and closed presentations
  do not opt in. Origin-scoped connected delivery preserves onboarding’s token and
  single-use semantics. Closing detaches presentation via approvals.close(.settings),
  retaining durable interest without granting callback authority on reopen.
- Escape cancels a pending Settings request through the existing origin-scoped
  coordinator. Loading retains its visible Cancel button. Withdrawal invalidates
  late replies, preserves another origin, and never unregisters the system helper.
  Failed/denied/cancelled states retain native Retry and truthful failure copy.
- J2.3 authority correction remains: no service, stored intent or preview telemetry
  can establish On. Production has no composed signed helper and fails closed.
- J2.4/base is DEBUG-only with isolated in-memory storage and a pending-only fake
  service; its Open Settings callback is inert. Native appearance is inherited.
- “Background Items Added” and ““Watt? Helper” can run in the background. You can
  manage this in Login Items & Extensions.” belong to macOS, not Watt's view tree.
  No notification imitation, synthetic OS approval or login-item success.
- Visual acceptance remains blocked until live signed-helper, system-notification,
  AX and native comparison evidence is available. See visual-review.json; no
  fabricated score or claim of completed G039.

## G040 / J2.5 — Turned on, Per Component available

- Exact Figma file `9DKDgUfEqidZdZQEVlQgLS`, node `29:4590`; fresh
  `get_design_context` and pinned 1000×720 bytes: `docs/evidence/J2.5/reference.json`.
- Native `Watt? Settings` window; grouped `Form`/`Section`, `LabeledContent`, menu
  `Picker`: Show **Components**, Components **CPU, GPU**, subtitle **Two fit.**
  Helper Status **On**, subtitle **Reading CPU, GPU, display and the rest.**;
  neutral bordered **Remove…** opens the native confirmation with destructive
  **Remove** and cancel-role **Cancel**. No fabricated window/control chrome.
- The connected excerpt includes Components rather than hiding it with the other
  omitted settings. Connected helper rows omit the off-state privacy/approval
  footer and redundant success message. All values bind to `PreferencesStore`.
- Debug-only `J25FixtureSession` injects `HelperLifecycleAdapter` with in-memory
  registration and IPC drivers and a pinned fixture peer. An authenticated ping
  plus Settings approval delivery enables fixture readings; preview telemetry or
  persisted intent alone never establishes On. This is **not real OS approval**.
- A shared session drives Settings, the existing native status-item/popover bridge,
  context-menu checkmarks and panel. Exact fixture label: **CPU 9.8 · GPU 4.1 W**.
  Any loss of verified connection withdraws fixture readings immediately;
  disabled preferences, stale/unavailable source/capabilities gate component
  label, menu and panel. Selection survives unavailability/removal.
- Settings removal re-verifies connection before invoking the injected removal
  boundary; only verified absence disables readings and resets presentation.
  Failures do not claim removal. J2.4 origin-scoped approval behavior is retained.
- `J2.5/base` is the only supported launch variant, isolated from persistent user
  storage and live service effects; Release excludes its composition.
- Native capture obtained, **visual gate blocked**: system dark appearance,
  520×362-point native window vs 520×311 reference (extra height avoids clipping),
  native titlebar differences; no calibrated status-item/full-scene comparison.
  No styling override added. AX permission false; no live AX/VoiceOver, real helper,
  system approval or end-to-end native interaction pass claimed. Verdict score is
  null, not fabricated. Evidence and reproduction: `docs/evidence/J2.5/`.


## G041 / J3.1 — Approval not given
- Exact Figma node `29:5253` in `9DKDgUfEqidZdZQEVlQgLS`; pinned 1000×720 reference and evidence in `docs/evidence/J3.1/`.
- Scene-attached SwiftUI `.alert`: **Helper not approved**; “Watt? can’t read components without it. Delta, Charger and Draw still work. Turn it on any time in Settings.” Native primary **Open System Settings** and cancel-role **Skip for Now**. No custom icon, geometry, wallpaper, notification or button drawing.
- Settings denied/cancelled/timed-out states present once per attempt; pending Settings approval uses a cancellable 120-second local deadline. Close invalidates outstanding replies; retry requests fresh authority. Failure and Skip withdraw only the originating interest, never shared failure delivery.
- Onboarding cancellation explicitly withdraws its origin; pending scene deadline only applies to existing onboarding interest. Async failure entry validates the original approval token; closing detaches it. Skip advances without helper to All Set, not approved/preview. Native Login Items callback never grants approval.
- J3.1/base is DEBUG-only with isolated memory preferences and disabled OS callback; unsupported variants remain launch-gated. Exact copy, callbacks, cross-origin survival and stale replies have focused coverage.
- Visual status **blocked**, score **null**: native alert captured, but dark scene-attached rendering differs from light icon-bearing desktop reference; AX false and no live signed helper approval evidence. No custom-paint workaround. Production onboarding service composition remains an integration boundary, not proof supplied by this fixture.


## J3.2 — helper switched off (G042)
Exact source: Figma file `9DKDgUfEqidZdZQEVlQgLS`, node `29:5439`; supplied 1000×720 dark reference and native capture evidence in `docs/evidence/J3.2`.
Reuse the existing 320×347 native MenuBarExtra window, grouped power rows and borderless Settings… / Quit Watt? controls. Runtime loss after a verified helper connection uses `exclamationmark.triangle.fill`, “Helper is off”, “Showing Delta until it’s back.” and a native bordered “Fix…” opening Settings (the existing approval path owns OS effects).
Delta is an effective display override, not a persisted preference rewrite; no component readings survive helper loss. Independent battery/charger/system values retain normal capability/freshness gating. Unknown initial setup is not evidence of revocation; only authenticated reconnect plus a validated fresh post-authentication helper component sample clears the loss presentation; runtime denial retains saved component intent. No custom material, status selection, warning glyph paths, or fake System Settings.
Visual completion remains blocked until a selected native status item and composited dark panel can be captured and compared; fixture authentication is not proof of real signed helper approval.

J3.2 production gates: P01 telemetry composition remains blocked (default startup is now unavailable, never preview watts). Real helper-loss monitoring remains uncomposed; injected fixture events are not production detection. External re-enable alone cannot exit Delta fallback.

### G043 / J3.3 — helper changed after app update
- Exact Figma `29:6181`, file `9DKDgUfEqidZdZQEVlQgLS`; pinned asset/hash: `docs/evidence/J3.3/reference.json`. Native scene-attached SwiftUI alert, title “The helper changed”, message “Watt? 1.1 comes with a new helper. macOS asks you to approve it once more.”; default “Update Helper”, cancel “Later”.
- Update scene owns native alert and visible pending/failure/retry states. Later dismisses to panel without helper or preference mutations. Explicit Update Helper calls injected signed UpdateAdapter recovery and HelperLifecycleAdapter update; no live defaults. Receipt survives retries.
- Updated installation proof + renewed approval + authenticated reconnect are required; pending is not connected. Old protocol mismatch is visibly unsupported, not an implicit migration. No synthetic notification, approval, signing, desktop, icon or button rendering, no forced Figma geometry.
- Two PID-scoped native alert captures exist, but show dark host-window chrome rather than comparable light parity. AX/live signing/approval and visual acceptance remain blocked; `docs/evidence/J3.3/visual-review.json` records null score, visualPass false and storyDone false.

### J4.1 / G044 — desktop welcome (30:2275)
- Explicit `WelcomeView.Variant.desktop`; standard/J1.1 remains the default with its existing extended copy. No inferred hardware variant or production appearance override.
- Exact title “Know your watts”; body “Watt? sits in your menu bar and shows what your Mac draws. Nothing more.” Reuse the supplied `WattAppIcon`, 96-point icon, existing 480-point onboarding width, SF system title/body and spacing tokens.
- Shared native bordered-prominent Continue/default action uses the existing persisted welcome → picker route. Back retains the explicit variant. Native close/Escape does not complete onboarding.
- Debug `J4.1/base` alone creates an in-memory dark native titleless window; production scene and appearance remain system-owned. J4.2 picker capability work is not included.
- Exact pinned reference, native capture, verification and blocked visual verdict: [J4.1 evidence](docs/evidence/J4.1/README.md). Existing light icon asset and host-native metrics differ from the dark Figma reference; do not paint replacements or claim visual parity.

### J4.2 / G045 — no-battery reading picker (30:2576)
- `ChooseMenuReadingView.Variant.noBattery` requires explicit `.noBattery` state and unsupported battery capability, never unknown telemetry. Order: Draw, Components, Delta, Charger. Exact subtitle: “No battery here, so it’s Draw or Components.” Battery rows say “Needs a battery. This Mac doesn’t have one.” Components remains unavailable until service capability is available; selecting or continuing never grants helper availability.
- Reuse native `ReadingPicker` / `Picker(.radioGroup)`, per-option disabled state and binding guard (including absent options). Normalize invalid no-battery onboarding selections to Draw; preserve a valid connected Components preference. Draw values remain telemetry-backed, not hard-coded production readings.
- Reusable typography decision: Figma Inter Title 2/Emphasized is substituted by `WattTypography.title` (semantic system SF Pro), per native styling policy. Keep native bordered Back, bordered-prominent/default Continue, titleless window chrome and existing spacing; do not impose reference pixel geometry or custom radios.
- Back persists welcome; Continue preserves existing `.helperOffer` onboarding routing, without completing setup or inventing helper approval. J4.3 panel routing is not implemented by this story despite the historical backlog shorthand. Debug J4.1 now uses the same explicit desktop telemetry so its Continue reaches this capability variant; its desktop welcome copy persists on Back.
- Debug-only `J4.2/base`: isolated in-memory preferences, picker checkpoint, Draw selected, 38.2 W fixture, battery/charger unsupported, components permission-required, dark native window. Production services/preferences and appearance are untouched.
- Pinned reference, native capture and honest visual-ralph verdict: [J4.2 evidence](docs/evidence/J4.2/README.md). Visual/AX/live acceptance remains blocked until comparable visual evidence and authorized interaction are available.


### J4.3 / G046 — desktop system-draw panel (30:2786)
- Exact context, screenshot, hierarchy and variables retrieved via Figma MCP. Panel 30:2930 uses dark native MenuBarExtra; header reads Drawing / 38.2 W / Mac Studio · no battery, so it’s all draw. Components CPU/GPU/SSD/Other show 14.6/11.2/1.9/10.5 W. These numbers/model name exist only in the isolated Debug fixture.
- Shared StatusPanelModel selects desktop only for explicit noBattery + unsupported battery. No battery/charger rows; headline and AX summary use system draw. Unknown, off, permission-required, stale and unavailable states never fabricate components. Native grouped Form, LabeledContent and borderless footer actions remain shared.
- Entry uses the existing status-item/coach-mark panel route. J4.2 continues through J1.3 helper offer before completion; the frame explicitly says “continues at 1.3 for components”. Historical direct-to-panel backlog shorthand does not authorize skipping helper/setup states. Settings and Quit retain native production callbacks; Escape/outside-click are native MenuBarExtra dismissal.
- Native styling audit repair: J1.3 facts use an intrinsic native grouped Form in a full-width sibling slot with a positive horizontal `WattSpacing.md` inset; the header and action row independently retain 32pt horizontal surface insets, rather than constraining the Form with a shared outer inset; onboarding preview/login Forms retain native columns style. Neither uses negative margins or forced row/form heights. Title2 and footnote are semantic. Panel/coach-mark surface dimensions are centralized; reference capture coordinates are not runtime control metrics.
- Earlier geometry-based evidence is historical, not current acceptance. See [J4.3 evidence](docs/evidence/J4.3/README.md). AX/comparable live capture gates fail closed with null score.

## J5.1 — welcome closed / deferred setup

G047 uses the supplied exact `30:3675` reference at `docs/evidence/J5.1/reference.png`.
`CoachMarkView` now has a welcome-closed variant with the exact title, message, Not Now,
and Finish Setup copy. Its 310 × 122 point application surface uses semantic system type,
native SwiftUI buttons, and a transient AppKit popover. J5.1 explicitly uses light Aqua;
J1.7 continues to inherit system appearance. The existing status anchor attaches the arrow
to the actual MenuBarExtra button's trailing edge; AppKit owns screen-edge adjustment,
material, corners, button metrics and arrow placement. No custom controls or desktop art.

Closing the welcome window or pressing Escape commits Delta plus an incomplete
`welcomeClosed` checkpoint and unique prompt identifier before presenting. Not Now commits
`runningDefaults` and opens the running panel; Finish Setup commits `picker` and opens
onboarding. Both clear the identifier, preserve other preferences, and reject stale,
repeated, opposing or completed-setup callbacks. Failed writes leave memory/disk state
unchanged and do not navigate; the coach mark exposes retry text. A failed native window
close leaves the welcome checkpoint available on reopen; Escape keeps the window open.
Cold launch re-presents an unresolved coach mark, but leaves `runningDefaults` quiet.
Explicit reopen resumes either deferred state at the picker. Neither path marks setup done.

The Debug-only `J5.1/base` fixture uses in-memory storage and fixed preview telemetry on
the production MenuBarExtra presentation path. Native capture and AX acceptance remain
separate from unit/build checks; see `docs/evidence/J5.1/visual-review.json` for the current
gate. No story completion follows solely from implemented fixture registration.


## J5.2 — panel Finish setup prompt (G048)

Exact supplied reference: node `30:4028`, pinned in `docs/evidence/J5.2/reference.png`.
Reuse StatusPanelView and MenuBarRootView: native GroupBox above the charging summary,
“Finish setup”, “2 steps left”, bordered-prominent “Continue…”, native grouped power
rows and borderless Settings… / Quit Watt?. Deferred setup omits the Components
section. Native surface dimensions are tokens; macOS owns controls, material,
selection highlight, typography and accessibility. No custom controls or desktop art.

Only incomplete welcomeClosed/runningDefaults states show this two-step prompt.
Continue validates the captured state and the current panel presentation identifier,
then atomically persists picker (J1.2), clears the deferred coach-mark identifier and
opens onboarding. Setup stays incomplete; other preferences and helper state survive.
Closed/replaced panels, changed/completed checkpoints and repeated actions cannot
write or navigate. Failed writes retain memory/disk state and allow the same native
Continue action to retry with truthful save-failure copy. Explicit reopen shares the
existing AppRouter resume path. Settings/Quit keep their original callbacks.

`--watt-fixture J5.2/base` alone is registered in the native Debug host. It opens the
real selected +42.1 W status item/panel in light Aqua with isolated memory defaults,
65.0 W charger, 22.9 W draw, +42.1 W battery and 64% / about 38 minutes. Production
readings remain telemetry-backed; the fixture does not grant helper availability.
Comparable capture, live keyboard and VoiceOver acceptance remain independent gates;
see `docs/evidence/J5.2/visual-review.json`. No story-done claim follows from test/build
success, and a missing capture retains null score and pixel diff.

## J5.3 — native context-menu Finish Setup… (G049)

Exact supplied reference: node `30:4788`, pinned in `docs/evidence/J5.3/reference.png`.
The existing status-item secondary-click/control-click bridge opens a real NSMenu.
Order: conditional Finish Setup…; separator; Show in Menu Bar submenu; separator;
Open Watt?; Settings… (Command-,); separator; About Watt?; Check for Updates…;
separator; Quit Watt? (Command-Q). Completed setup omits only Finish Setup… and its
separator. AppKit owns material, typography, separators, submenu arrow/checkmarks,
selection/hover, tracking, keyboard equivalents and accessibility. No custom menu
chrome or imposed reference dimensions. Show in Menu Bar preserves native display
choices and the existing capability-disabled Components/Turn On Helper… behavior.

Finish Setup… captures the incomplete onboarding snapshot and a menu presentation
identifier. A current, eligible action uses AppRouter's shared persisted transition
to J1.2 picker, clears the deferred prompt identifier and opens onboarding only after
a successful write. Setup remains incomplete; other preferences and helper state
survive. Completed/changed snapshots, repeated actions, replaced/dismissed menus and
callbacks after another route cannot write or navigate. Each menu permits one attempt,
including write failure; reopening gives a fresh retry. Synchronous native popup return
ends the presentation because menuDidClose may precede the selected item's action.
J5.2's deferred-only prompt keeps its existing retry semantics through the shared API.

`--watt-fixture J5.3/base` is the sole native Debug variant: isolated memory preferences,
incomplete runningDefaults, frozen +42.1 W preview status label, light Aqua, and the
actual status-item NSMenu path. Unsupported variants fail closed. A capture-only
app-local hover exercises native selection; observed highlight is evidence, never
painted. J5.3 records window identity during native tracking and leaves the menu open
for external PID-scoped compositor capture. No cached-view image is visual acceptance.

Fresh test/build/static evidence and the capture result live in `docs/evidence/J5.3`.
Comparable app-owned menu pixels and AX/live keyboard, hover, submenu and VoiceOver
acceptance remain separate gates. Missing compositor windows or AX trust keeps visual
score/pixel diff null and status blocked; implemented registration is not story completion.

### Native status-item host-placement boundary (2026-09-23)

An independent minimal AppKit probe is pinned in
`docs/evidence/host-status-item/`. It creates only
`NSStatusBar.system.statusItem(withLength: .variableLength)`, sets a native title and
Accessibility label, and uses no Watt code. On the current macOS 27.0 host with AX
trust enabled, the probe registers a native `AXMenuBarItem` but reports the frame
`x=-1, y=1157, width=65, height=24` on the `1800×1169` main display. Watt's J4.3,
J5.1 and J5.2 fixtures reproduce the same `x=-1` edge placement; the normal fallback
item reports `x=7`.

This is host menu-bar/compositor evidence, not a missing Watt status item. Do not
add fake menu-bar chrome, an overlay window, private APIs or bitmap replacement to
force visibility. Native compositor pixels and live status-item hit-testing remain
explicit acceptance gates until a host with correct placement is available.

The requested local UTM alternative was also checked: `/Applications/UTM.app` contains
`macOS.utm`, but the VM currently boots to a black guest display and `utmctl exec`
returns backend error `-2700`; no guest login or Apple ID was attempted. The VM is not
accepted as a visual verification host until it exposes a usable macOS desktop. See
`docs/evidence/host-status-item/utm-host-2026-09-23.log`.


## J6.1 — plugged in, charging (G050)

Exact supplied reference: node `31:2745`, `docs/evidence/J6.1/reference.png` (1000 × 720).
The reference panel at x=645, y=38 is a 320 × 265 point native MenuBarExtra window.
Dark Aqua supplies material, border, corners, shadow, text contrast and the selected
status item showing `+42.1 W`. The desktop and other menu-bar items remain OS-owned.
The reference was inspected locally; no new Figma request is needed.

The existing StatusPanelView/StatusPanelModel renders “Charging”, “+42.1 W”, and
“64% · full in about 38 min”. Its native grouped Form/LabeledContent rows are
“Charger input” / “96 W USB-C charger” / “65.0 W”, “System draw” / “22.9 W”, and
“Battery” / “+42.1 W”. The shared panel's includesComponents presentation option
omits the entire Components section for J6.1, with compactPanelHeight owned by
WattSpacing. This is separate from telemetry capability and the helper preference.
Native borderless “Settings…” and “Quit Watt?” retain their existing scene/termination
callbacks. SwiftUI/AppKit own control metrics and accessibility; there is no duplicate
panel, custom background, rounded rectangle, gradient or painted window chrome.

`--watt-fixture J6.1/base` uses the existing MenuBarExtra/status bridge and opens the
real panel. The Debug-only fixture explicitly sets dark Aqua, creates fresh in-memory
preferences (completed livePanel, Delta, decimal precision, symbol shown, helper
preference off) and a fresh PowerReadingStore with deterministic sampleCharging and
a clock fixed at that sample. Unsupported variants fail closed before composition;
ordinary launches retain their existing settings and telemetry paths. Capability loss,
disconnection, invalid samples and stale generations use the existing model/store
semantics, so unavailable values cannot become fabricated zeroes.

Fresh package/host tests, build/analyze, static checks and native capture are recorded
in `docs/evidence/J6.1`. Comparable PID-owned compositor pixels and live AX/keyboard/
VoiceOver verification are independent acceptance gates. If the native panel or AX
cannot be observed, visual score and pixel diff remain null and the story remains
blocked for visual acceptance. Fixture registration does not establish D1–D7 completion.

J6.1 verification on 2026-09-22 UTC: all 8 story tests pass in package and host;
91 focused tests per run, 433 package and 421 host tests pass (one opt-in hardware
probe skipped in each full suite). Package build, Debug/Release build + analyze and
static/diff checks pass. Native capture has Screen Recording access but AXTrusted=false
and no app-owned compositor windows. Visual acceptance is blocked with null score/diff;
selected status item appearance and live interaction remain unverified.


## J6.2 — on adapter, charging on hold (G051)

Exact file `9DKDgUfEqidZdZQEVlQgLS`, node `31:3754`: the supplied PNG is retained in
`docs/evidence/J6.2/reference.png`, SHA256
`3d61ebe2a14f409192352f4d3e52edd26cd07d0d5da6437496a438961ce87ce9`.
The inspected 1000 × 720 reference and registry node bounds place the native panel
at x=660, y=38, 320 × 279 points. Desktop wallpaper and menu-bar chrome are system
context, never app assets or layout overlays.

Reuse StatusPanelView with the semantic StatusPanelState.optimisedChargingHold.
An explicit BatteryChargingHoldReason.optimisedBatteryCharging, fresh available
source, chargingHold physical state, available battery/charger/system capabilities,
validated finite values, zero battery delta and a measured battery percentage are
required. Adapter presence, an 80% reading, a zero delta or a generic charging pause
alone cannot establish the reason. The existing system telemetry parser intentionally
does not infer it; production needs an authoritative adapter reporting this reason.
Unqualified readings retain generic existing presentation without the optimised copy.
PowerReadingStore retains rejected samples' last good snapshot for diagnostics;
statusReading suppresses a held snapshot after a failed update for both panel and
menu-bar label, and recovers only after a valid accepted reading.

For the qualified fixture the model supplies “Holding at 80%”, “0.0 W”, and
“Because Optimised Battery Charging is on. Charging resumes before you usually unplug.”
The same grouped Form/Section/LabeledContent renders exactly three power rows:
Charger input / 96 W USB-C charger / 21.4 W; System draw / 21.4 W; Battery / 0.0 W.
The semantic hold state omits Components independently of helper capability or preference.
WattSpacing owns only the panel surface size; existing SF Pro semantic typography,
subheadline copy, native material, row metrics and borderless Settings… / Quit Watt?
buttons remain shared. No duplicate panel or custom background, shape, gradient,
shadow, control or overlay is introduced. The existing native battery SF Symbol and
status-item selection bridge show 0.0 W and selected state in dark Aqua. Footer
callbacks still route Settings through AppRouter and Quit through app termination.

`--watt-fixture J6.2/base` is Debug native-host only. Each launch creates independent
in-memory preferences and PowerReadingStore with a frozen sample clock, completed
livePanel onboarding, Delta mode, decimal precision, symbol visible, and component
preference off. Unsupported or malformed selectors fail before composition. Release
excludes fixture registries and the J6.2 fixture/sample definitions. C01, J1.8 and
J6.1 retain their existing component and charging presentation contracts.

Evidence lives in `docs/evidence/J6.2`. Automated native layout/control tests do not
prove compositor appearance or live accessibility. Native panel capture must identify the fixture PID's panel through AX and the
compositor without permission changes. Selected status-item appearance and live
interaction require separate native evidence. Missing comparable native pixels keeps visual score/pixel diff
null and visual acceptance blocked; registration alone does not complete the story.

J6.2 verification on 2026-09-22 UTC: focused package/host runs each execute 104 tests
(103 pass, one AX skip); full package executes 446 (444 pass, two skips) and full host
executes 434 (432 pass, two skips), all with zero failures. J6.2 itself executes 13 tests
(12 pass, one AX skip) in each runtime. Package build, Debug/Release build + analyze,
static/diff and two native invalid-selector checks pass. Release binary symbol checks
exclude the Debug fixture. Existing onboarding concurrency warnings remain unrelated.
Real fixture capture exits 1 with Screen Recording preauthorized, AXTrusted=false and
zero PID-owned on-screen compositor windows; its process was terminated and reaped.
Visual score/diff remain null and story visual acceptance stays blocked.


## J6.3 — on adapter, fully charged (G052)

Exact file `9DKDgUfEqidZdZQEVlQgLS`, node `31:4355`: the supplied PNG is retained in
`docs/evidence/J6.3/reference.png`, SHA256
`13696607c0ea717fd3476b8355bcdbbd1cd77c8d2f7530648ac359632bd9d813`.
The inspected 1000 × 720 reference places the native panel at x=660, y=38,
320 × 265 points. Desktop wallpaper and the menu bar remain system chrome.

The shared StatusPanelModel adds the semantic StatusPanelState.fullOnAdapter.
It requires a fresh available source, explicit full battery state, measured 100%,
zero battery delta, available battery/charger/system capabilities, nonnil charger
and system readings, and successful finite/range validation. Adapter presence or
zero delta alone cannot establish full. The existing system parser remains unchanged:
it can report full only from explicit charged/not-charging/AC flags, and does not
supply measured charger/system watts. Consequently its limited data cannot claim
“running straight off the charger”. Existing generic C03/C04 presentation and
J6.1/J6.2 semantics remain intact. Failed full updates retain the last snapshot for
diagnostics but expose unavailable statusReading to the shared panel and status item.
Full status snapshots expire after five seconds using the existing store clock, even
when the input freshness flag still says fresh. A valid recent sample restores the
full presentation; frozen fixture clocks remain deterministic. The model consumes
the adapter freshness flag; the store enforces age when statusReading is evaluated.
This change does not add a production polling scheduler.

Qualified full telemetry supplies “Full”, “0.0 W”, and
“100% · running straight off the charger”. The fixture supplies the same grouped
Form/Section/LabeledContent rows: Charger input / 96 W USB-C charger / 19.8 W;
System draw / 19.8 W; Battery / 0.0 W. The full state suppresses Components and
reuses WattSpacing.compactPanelHeight. Settings… and Quit Watt? remain native
borderless Buttons with the existing router and termination callbacks. Existing
SF Pro semantic tokens remain: Body/Emphasized 13 semibold, Headline/Regular 13 bold,
Large Title/Emphasized 26 bold, Subheadline/Regular 11 regular. MenuBarExtra supplies
native material and geometry. No duplicate panel, custom background, shape, gradient,
shadow, hand-painted control, overlay chrome or app wallpaper is introduced.

`--watt-fixture J6.3/base` is Debug native-host only. It uses independent in-memory
preferences and PowerReadingStore with a frozen sample clock, completed livePanel
onboarding, Delta/decimal mode, visible battery symbol, and component preference off.
The existing NSStatusItem bridge opens and selects the MenuBarExtra in dark Aqua;
the status label is 0.0 W. Unsupported/malformed selectors reject before composition,
including the unimplemented notification variants. Release excludes the fixture
registry, J63FixtureLaunch and sampleFullOnAdapter. Notifications are outside this
panel story; no permission or delivery success is inferred.

Evidence and reproducible checks live in `docs/evidence/J6.3`. Native hosted geometry,
button and selection tests do not prove compositor pixels or live accessibility.
Capture must identify the fixture PID's native panel through AX and compositor
ownership; permissions must remain unchanged. Missing comparable native pixels keeps
visual score and pixel diff null, and visual acceptance blocked. Verification results
are recorded in verification.json and visual-review.json after running the checks.

J6.3 final verification: focused package/native suites each execute 119 tests (117 pass,
two AX skips), full package 461 (458 pass, three skips), and full native host 449
(446 pass, three skips), with zero failures. J6.3 itself executes 15 tests (14 pass,
one AX skip) per runtime. Package build, native Debug/Release build + analyze,
static/diff and five native invalid-selector checks pass. Exact Debug symbols are
absent from Release. Real capture exits 1 with Screen Recording preauthorized,
AXTrusted=false and zero fixture-owned compositor windows; the process was terminated
and reaped. Visual score/pixel diff remain null and visual acceptance is blocked.


## J6.4 — Charger can’t keep up (G053)

Exact file `9DKDgUfEqidZdZQEVlQgLS`, node `31:4956`, asset retained at
`docs/evidence/J6.4/reference.png`, SHA256
`7256ff7ac281ea2e2f26a22b6a70ccee4f874a6c72f3a70b222202328d54881b`.
The 1000 × 720 reference places the native dark panel at x645/y38, approximately
320 × 279 points. Its panel explanation is shorter than its notification; the user
explicitly requires the full message in both surfaces, which takes precedence.

Insufficient charger is a semantic state of the existing shared native status panel.
It requires validated threshold provenance with episode identity, observation time,
and a sustained duration of at least 300 seconds, plus fresh available finite measured
battery/charger/system telemetry. Store access expires eligible telemetry after five
seconds. Negative battery watts and adapter presence alone cannot establish it. No
production threshold inference is introduced, and existing charging/hold/full and
generic presentation remains intact.

The native warning SF Symbol accompanies “Charger can’t keep up”, headline “−13.0 W”,
and “Because your Mac draws 78 W and this charger gives 65 W. The battery covers the
rest.” Existing grouped Form/Section/LabeledContent rows read Charger input /
67 W USB-C charger / 65.0 W; System draw / 78.0 W; Battery / −13.0 W. Components
are hidden. Settings… and Quit Watt? reuse native borderless Buttons and callbacks.
The selected status item displays the battery glyph and −13.0 W. Semantic SF Pro
styles and native MenuBarExtra/AppKit material, geometry and selection remain the
source of presentation. No custom notification card, background, gradient, shape,
shadow, overlay or replacement window is introduced.

The notification is a semantic OS delivery request through existing P03
PowerNotificationEffects/SystemNotificationBridge contracts. macOS owns notification
chrome and AppIcon rendering. Preference off suppresses; denied does not deliver;
authorized/on is eligible for an attempt. Eligibility, attempt, acceptance and visible
OS delivery are distinct evidence levels. Deterministic J6.4 fixture effects record
intent and fail enqueue with unknownStatus instead of reporting delivery success.
The optional read-only native authorization probe neither requests permission nor
changes it. Fixture telemetry supplies no real live adapter threshold provenance;
therefore the fixture cannot establish actual OS notification delivery.

J6.4/base and the four notification-on/off-authorized/denied variants are DEBUG-only,
with isolated memory preferences and stores, a frozen sample clock, dark Aqua,
completed live-panel onboarding and Components off. Unsupported/malformed selectors
fail closed before composition. Release excludes registry, sample and launch harness.
Evidence scripts and exact metadata live in `docs/evidence/J6.4`. Capture is restricted
to the launched PID's AX-content/geometry-verified compositor-owned native panel;
Notification Center is never captured. Missing AX/TCC/compositor evidence keeps score
and pixel diff null and visual acceptance blocked. Native tests and panel pixels alone
do not establish live accessibility, selected status-item pixels or system delivery.

J6.4 verification (2026-09-23): 476 package and 464 native tests, each with four AX
skips and zero failures; Debug/Release build and analysis passed. The real fixture
capture found Screen Recording preauthorized, Accessibility trust unavailable and
zero Watt-owned compositor windows. The capture emitted no native notification
authorization-probe result. Visual acceptance and OS delivery remain blocked; score
and pixel diff are null. See `docs/evidence/J6.4/verification.json` and
`docs/evidence/J6.4/capture/window.json`. No OS permission or persistent user preference was changed.


## J6.5 — Unplugged — on battery (G054)

Exact file `9DKDgUfEqidZdZQEVlQgLS`, node `31:5571`, user-specified PNG retained at
`docs/evidence/J6.5/reference.png`, SHA256
`2fc0d5e53483f6377d473195b64643f6b4316da85ea9c78e83af1a7c21ce1c47`.
The inspected 1000 × 720 reference shows the native dark panel approximately at
x645/y38, 320 × 265 points. Original F00 metadata records x644 and is preserved;
actual window placement and desktop/menu-bar chrome belong to macOS.

Reuse the generic on-battery semantics and existing deterministic sampleOnBattery:
“On battery”, “−18.4 W”, “64% · about 4 h 10 min left”; grouped native rows
Charger input / Unplugged, System draw / 18.4 W, Battery / −18.4 W. A disconnected
charger capability supplies Unplugged; unavailable capabilities supply no number.
No estimate is derived from percentage or watts. Absent detail remains absent,
and missing battery watts suppress the remaining-time subtitle. Stale, unavailable
or invalid discharging snapshots suppress live panel/status values; PowerReadingStore
expires discharging status snapshots after five seconds and suppresses them after a
failed validation, retaining the diagnostic sample until a valid recent update.
The existing store clock enforces age when statusReading is evaluated. A cancellable
expiry task for the real system clock also notifies open panel/status views without
waiting for another sample. Frozen fixture clocks remain deterministic; this adds no
telemetry polling scheduler. Fresh C02 retains its Components section and
C04.2 retains its exact status label.

J6.5 hides Components using the existing includesComponents setting and compact
panel token. It reuses StatusPanelView/StatusPanelModel, Form/Section/LabeledContent,
native borderless Settings… / Quit Watt? callbacks, semantic typography/spacing,
and MenuBarExtra/AppKit material and selection. No new panel, background, shape,
gradient, shadow, hand-painted control, wallpaper, overlay chrome or asset is added.
The selected native status item displays the battery glyph and −18.4 W.

`--watt-fixture J6.5/base` (also the existing base shorthand J6.5) is Debug native-host
only. Each launch creates independent in-memory preferences and store, uses a frozen
sample clock, completed live-panel onboarding, Delta/decimal/symbol settings and
Components off. It reuses the native NSStatusItem bridge to open the dark Aqua
MenuBarExtra. Unsupported/malformed selectors reject before composition. Release
excludes the launch harness, sampleOnBattery and fixture registry.

Evidence and reproducible checks are in `docs/evidence/J6.5`. Real capture requires
PID-owned compositor and live AX panel identity; it never substitutes a cached view,
synthetic screenshot or desktop capture. Missing AX/TCC/compositor evidence keeps
visual score and pixel diff null with visual-blocked status. Native hosted geometry,
callbacks and selection tests do not establish selected status pixels, live keyboard
interaction or VoiceOver. Verification results follow in verification.json.

J6.5 verification (2026-09-23): 11 focused story tests in each runtime (10 passed,
one AX skip). The wider focused package/native runs each execute 145 tests (141 passed,
four AX skips); full package 487 (482 passed, five skips), full native 475 (470 passed,
five skips), zero failures. Package build, native Debug/Release build + analyze,
static/diff checks, Release fixture-symbol isolation and nine invalid-selector checks
pass. Real native capture exits 1: Screen Recording preauthorized, AXTrusted=false,
zero fixture-owned compositor windows. Capture PID terminated and reaped. Visual
acceptance remains blocked with null score/pixel diff; no permissions changed.


## J7.1 — Right-click → Show in Menu Bar (G055)

Exact supplied reference: Figma `9DKDgUfEqidZdZQEVlQgLS`, node `31:6173`,
`docs/evidence/J7.1/reference.png` (1000 × 720). SHA256
`cbb1d098466ed5c3b58b0ac8748bcd75a928550d38a9c4b2309c8d48e3fe5cd9`.
Status anchor `31:6484` shows the charging battery SF symbol and `+42.1 W` selected.
Main menu `31:6485` has reference bounds x651/y38/230×187; submenu `31:6717`
x465/y38/190×141. These are reference measurements, not imposed AppKit geometry.
The supplied PNG supersedes the historical F00 export for this story's visual evidence;
that earlier source record remains intact in the registry.

Reusable native menu decision: retain the existing single MenuBarExtra status item,
NSStatusBarButton bridge and `StatusItemContextMenu` NSMenu/NSMenuItem factory.
AppKit owns menu material, typography, separator spacing, checkmark columns,
submenu chevrons, screen-edge placement, selection/hover, keyboard navigation,
shortcuts and accessibility. Never reproduce native chrome with SwiftUI shapes,
backgrounds, shadows, gradients, tint, custom NSMenuItem views, fonts, widths or
spacer images. Production appearance follows macOS. Explicit light Aqua belongs
only to the Debug reference fixture; app-owned panel/settings views remain SwiftUI.

Completed main-menu order: Show in Menu Bar; separator; Open Watt?; Settings…
(Command-,); separator; About Watt?; Check for Updates…; separator; Quit Watt?
(Command-Q). Submenu: Delta; Charger; Draw; Components; separator; Icon. Delta
is checked; Components is highlighted by AppKit tracking, not selected in preferences.
Mode actions mutate the shared PreferencesStore and a fresh menu rebuild reads it.
Components rechecks enabled preferences, helper loss and current capability at action
time. Unavailable Components remains disabled and Turn On Helper… routes to settings.
Existing conditional Finish Setup… and guarded onboarding resume semantics remain.
Open/settings/update reuse AppRouter; About and Quit retain standard NSApplication
callbacks. This story introduces no production menu styling or alternate navigation.

`--watt-fixture J7.1/base` is the only variant (existing registry base shorthand is
retained). Debug composition creates a fresh InMemoryStorage-backed PreferencesStore,
frozen `.sampleCharging`, decimal delta plus symbol, component readings on, and
completed livePanel onboarding with helperOptIn true. An explicitly injected
FakeHelperService reconciles connected before the menu opens. That is deterministic
fixture state, never proof of real helper installation or approval. No live telemetry,
registration, network service or persisted user preferences are started by this fixture.
Native Release excludes the selector, fixture implementation and registry files.

The app-owned capture harness posts a local secondary click to the actual status
button window, reaching the production event monitor. Native arrow-key events open
the submenu and attempt Components highlight. It records actual highlighted/checkmark
state and window identities only; it never renders menu pixels or reparents the anchor.
The external capture script requires fresh output, PID-matched compositor windows for
both menus and status anchor, plus AX title/checkmark/selection evidence. It terminates
and reaps the launched app. Missing access or matching windows keeps visual score and
pixel diff null. Native semantic styling takes precedence over pixel-painted Figma chrome.

Implementation/test/capture results and reproducible scripts live in `docs/evidence/J7.1`.
Visual acceptance remains separate from implemented fixture registration and unit tests.

J7.1 verification (2026-09-23 local): nine story tests passed in package and native
runtimes; 60 focused tests per runtime; 496 full package tests and 484 full native
unit tests, each with five existing skips and zero failures. Package build and native
Debug/Release build+analyze passed. Nine malformed native selector subprocesses
rejected before scene/store creation. Release fixture symbols/selector strings are
absent; static/style/reference digest and diff checks passed. The real native app
capture was attempted and its PID terminated/reaped: screen capture preauthorized,
AXTrusted=false, no PID-owned compositor windows. No screenshot, score or pixel diff
is claimed; live menu highlight, appearance, placement, keyboard/dismissal and
VoiceOver acceptance remain blocked. Implementation is verified; visual story
acceptance remains open. No commit was created.

## J7.2 — Result — Per Component in menu bar (G056)

Exact source: Figma `9DKDgUfEqidZdZQEVlQgLS`, frame `31:6952`, 1000 × 220.
The supplied PNG is retained at `docs/evidence/J7.2/reference.png` with its SHA256
and retrieval metadata. Retrieved design context and hierarchy are retained alongside
it. Desktop Template `31:6953` is Light with Dock hidden and menu bar Over Light.
Status anchor `31:7101` contains idle/unselected status item `31:7099`, whose exact
copy is `CPU 9.8 · GPU 4.1 W`, with no visible icon. Its reference bounds are
x593/y5/148×24; the anchor is x0/y5/741×24. These measurements describe Figma,
not app-imposed screen coordinates. Body/Emphasized is SF Pro 13/16 semibold.
The historical F00 export metadata remains intact in the fixture registry; the
supplied PNG digest in `reference.json` is this story's visual evidence authority.

Reusable mapping: `.components` display mode reads the ordered, validated maximum
of two stable component IDs from PreferencesStore. MenuBarStatusLabel resolves
those IDs against PowerReading.components and uses PowerFormatter with the selected
precision. An explicit `.perComponent` reading with all selected values available
shares a single trailing W; reversing preferences reverses the displayed order.
An empty selection displays an em dash. Existing partially missing formatting remains
`CPU 9.8 W · GPU —`; unrelated legacy charging component formatting is preserved.
This story adds no special J7.2 text renderer. The production status label now validates
the reading before formatting component values, suppressing invalid timestamps,
nonfinite/negative component power and duplicate/empty IDs. Source, freshness,
capability and component-readings preference gates remain in the shared label.

PowerReadingStore qualifies explicit per-component status using the existing five-second
status-age policy and failed-update suppression. It retains rejected/expired samples
for diagnostics while statusReading becomes unavailable. The existing expiry task
also invalidates per-component views when no new sample arrives; fake clocks stay
frozen and schedule no wall-clock expiry. These changes are covered by failing-before,
passing-after regression tests. No telemetry service, new dependency or context-menu
change is introduced.

Native styling decision: reuse MenuBarExtra, MenuBarStatusLabel and the existing
NSStatusBarButton/ScenePresentationBridge. The shared semantic
`Font.body.weight(.semibold)` maps the design's emphasized text to the system font;
there is no fixed-size/custom font, painted status chrome, gradient, shadow, rounded
rectangle, custom glyph or absolute desktop recreation. `showSymbol = false` suppresses
the existing SF Symbol branch. macOS owns material, spacing, focus, placement and
wallpaper/system items. The exact reference PNG is evidence, never a runtime backdrop.
Production appearance follows the system; only the Debug fixture requests light Aqua.

Only `--watt-fixture J7.2/base` launches this fixture; shorthand and malformed selectors
reject before stores/scenes are constructed. Direct registry lookup remains available
for metadata tests. Each launch creates fresh InMemoryStorage preferences and a fresh
PowerReadingStore with the existing deterministic `.samplePerComponent`, source fixture,
CPU 9.8 W/GPU 4.1 W, available components and a clock frozen at its timestamp. Preferences
select `.components`, `["CPU", "GPU"]`, decimal precision, component readings on,
showSymbol false and completed livePanel onboarding. This result fixture opens no menu
or panel; ordinary native click behavior is retained. Release excludes its launch helper,
observation harness, selector and fixture registry sources.

The optional Debug observation records the actual status button/window identity and
shared label semantics without relocating or drawing it. `capture.sh` launches the
actual native app, requires fresh output, uses the external capture probe for PID-owned
compositor and AX evidence, then terminates and reaps that PID. No synthetic/cached
view image, desktop crop or foreign-process fallback can qualify. Native no-symbol
pixels, appearance/placement and live interaction remain unverified if access or windows
are absent. Visual score and pixel diff remain null until comparable live evidence is
reviewed. This non-tmux session has no visual-ralph runtime; ordinary local checks and
the real capture attempt are documented in `docs/evidence/J7.2`.

J7.2 verification (2026-09-23 local): 10 story tests per runtime, 61 focused tests
per runtime, 506 package and 494 native unit tests, with five existing skips in each
full suite and zero failures. Package build, native Debug/Release build+analyze,
10 malformed-selector subprocesses, Release isolation, reference SHA256 and static/diff
checks passed. The actual capture launched PID 18444 and terminated/reaped it;
screen capture was preauthorized, AXTrusted=false, and no PID-owned compositor
windows or screenshot were available. GUI interaction/VoiceOver and visual acceptance
remain blocked, with score and pixel diff null. No commit was created.

## J7.3 — Settings — choose components (max 2) (G057)

Exact file `9DKDgUfEqidZdZQEVlQgLS`, frame `31:7102`, native Light macOS,
1000 × 720. The supplied PNG is retained at `docs/evidence/J7.3/reference.png`;
SHA256 `d6ffb39f4c390876077c0fb584f1bd7692308be6068bc92004004813a5329a07`.
`reference.json`, `reference.sha256`, `figma-design-context.txt` and
`figma-hierarchy.xml` record the exact reference, inspection, copy and assets.
The historical F00 export digest is a separate provenance record.

Settings instance `31:7256` is titled **Watt? Settings**. Its reference bounds
(x240, y256, 520 × 229) describe the screenshot only. The native Settings scene
uses the existing semantic settings excerpt width and intrinsic grouped Form height;
no desktop position, row heights or Figma window height are imposed.
The Menu Bar section orders **Show → Components**, **Components → CPU, GPU** with
subtitle **Two fit. More crowd the menu bar.**, then **Precision → 42.1 W**.
The popup `31:7533` lists **CPU** and **GPU** checked, **Display**, **SSD**, **Other**
disabled. Its reference 170 × 130 bounds do not configure runtime geometry.
Body/Emphasized SF Pro 13/16 semibold and Headline/Regular SF Pro 13/16 bold are
reference styles; native controls and existing semantic typography own live metrics.
Desktop wallpaper, menu-bar symbols, titlebar traffic lights, materials and shadows
are OS-owned. No new runtime image assets are used.

Reusable component decision: `ComponentSelectionMenu` is an NSViewRepresentable
containing a real NSPopUpButton with NSMenu/NSMenuItem state. A single-choice Picker
of precomposed combinations could not express this interaction. The popup cell leaves
item states independent (`altersStateOfSelectedItem = false`) and uses a separate
native summary item (`usesItemFromMenu = false`). AppKit owns checkmarks, disabled
appearance, focus, accessibility role, keyboard navigation and dismissal. Each item
has a real target/action; there are no custom rows, views, icons, materials or chrome.
The SwiftUI container stays Form/Section/LabeledContent with native Show/Precision
Pickers. The J2.5 excerpt retains its exact shorter **Two fit.** subtitle.

Available choices come from validated, recent component identities in PowerReadingStore,
not component display names or a fixture-only enabled mask. The fixed five option names
are the semantic component vocabulary. Legacy lowercase IDs are matched without changing
persisted order. Unknown, stale, invalid or failed telemetry closes availability;
helper loss and disabled component readings close it too. Menu opening and every action
re-evaluate the current store. With two choices, other available items are disabled and
an already-dispatched third-choice action is rejected. Removing a selected available
item frees a slot; reselecting appends it. Empty selection displays **None** and the J7.2
status label keeps its existing em dash. Saved unavailable intent remains checked but
disabled, without silently replacing it or fabricating a reading.

PreferencesStore remains the shared max-two boundary, rejecting duplicate identities,
whitespace IDs and over-capacity selections before publication or persistence. Selection
writes now commit before publishing so a failed disk write preserves the last selection.
No dependency is added. ReadingPicker, the J7.1 context menu and the J7.2 status-label
implementation remain unchanged; regression tests exercise their shared preferences.

Only `--watt-fixture J7.3/base` selects the DEBUG fixture. Each launch creates fresh
in-memory preferences and a frozen PowerReadingStore using samplePerComponent, completed
livePanel onboarding, a scripted connected helper, components on, CPU/GPU in that order,
decimal precision and Aqua appearance. The existing AppRouter → openSettings path opens
the actual SwiftUI Settings scene. A bounded DEBUG task finds its native component popup,
gives it native focus and invokes performClick. The fixture does not construct an NSWindow,
render a desktop, generate a bitmap, register a helper, poll hardware or touch UserDefaults.
Release compilation removes the fixture and observation harness; the existing Release
configuration excludes registry sources.

Acceptance evidence is kept in `docs/evidence/J7.3`. Story tests cover exact menu state,
copy/order, capability identity, stale dispatch, capacity, persistence, fresh fixture
isolation, J7.1 Settings navigation, Aqua/native metrics and preservation of J7.2 text.
NativeStylingTests guard Form and popup semantics and forbid painted chrome. Unit tests
cannot establish a compositor or VoiceOver pass: live acceptance requires matching fixture
PID, independent compositor window ownership, AX Settings copy and popup checkmarks/disabled
states. Score/pixel diff stay null without that evidence. The visual-ralph runtime is
unavailable in this non-tmux session; no OMX state or goal authority is inferred or mutated.

J7.3 verification (2026-09-23 local): 12 story tests passed per runtime; 83 focused
tests passed per runtime. Full package 519 / native WattTests 507 executed, five
existing skips each, zero failures. Package build and native Debug/Release build +
analyze passed, as did ten malformed-selector subprocess rejections, Release fixture
isolation, static/SHA/script checks and source diff checks. Actual Debug fixture PID
24681 had AXTrusted=false and zero owned compositor windows; it was terminated and
reaped. No screenshot, visual pass, numerical score or pixel diff is claimed.

## J7.4 — Crowded menu bar — Icon Only (G058)

Exact Figma authority: file `9DKDgUfEqidZdZQEVlQgLS`, frame `31:7764`,
**7.4 Crowded menu bar — Icon Only**. The supplied 1000 × 220 PNG is retained at
`docs/evidence/J7.4/reference.png`; SHA-256
`43c40d136771931bcde6be9c589a0f76ec23271830ae02c52e809fa3adff311d`.
Both installed Figma skills were loaded before the design-context call. Raw context,
hierarchy and screenshot response are retained alongside the reference metadata.

The hierarchy is Desktop Template `31:7765` (Light; Dock hidden), Status Item Anchor
(right-aligned) `31:7913`, and Watt? Status Item `31:7911` (Light; selected False).
The status content is exactly the native SF Symbol **battery.100percent.bolt** with
no visible text. The anchor is 741 × 24 at (0, 5); its status item is 41 × 24 at
(700, 5) in the frame. These are reference inspection coordinates, never app layout
constraints. Figma reports Body/Emphasized, SF Pro semibold weight 590, 13-point type,
16-point line height and zero tracking; the icon-only branch inherits native system
metrics without applying a font. Desktop wallpaper, Wi-Fi, Spotlight, Control Center,
clock and menu-bar material belong to macOS. The PNG is evidence, not a shipped asset.

Reusable decision: **Icon Only is the existing persisted display mode**, selected by
the existing native J7.1 **Icon** action or Settings. It hides visual text while
retaining a single `Image(systemName:)` with `.renderingMode(.template)` in the real
`MenuBarExtra`. There is no separate status renderer or automatic crowding detector.
The existing NSStatusBarButton bridge owns click/context routing; the system owns
material, tint/contrast, alignment, spacing, typography, selection and hit target.
The C04.8-only symbol override has been removed: fresh valid battery/adapter readings
use the same symbol semantics for system, helper and fixture sources. On battery,
the icon becomes `battery.100percent`; stale/unavailable/invalid battery readings use
the generic `bolt.fill`. Charging/hold/full states require available charger capability
before using the battery-with-bolt symbol. Delta/charger/draw/component label paths
retain their previous formatting and J7.2 component typography.

The accessible element remains **Watt? power reading** and announces the qualified
battery delta using the saved precision, including **+42.1 watts** for the fixture.
Missing/stale/invalid/unsupported readings say **No reading yet**. Hiding visual text
must not hide the accessible reading. Icon Only still shows a symbol when the saved
Show Symbol preference is off. Leaving Icon Only restores that preference and the
saved component selection. Existing helper-loss effective-Delta behavior is preserved.

Only `--watt-fixture J7.4/base` selects the DEBUG fixture. It creates fresh in-memory
preferences and a fresh store using `sampleCharging` at frozen epoch 1700000000
(+42.1 W, 64% battery, charger 65 W, system draw 22.9 W, available component capability),
sets iconOnly/decimal/showSymbol, completes livePanel onboarding with helper opt-in,
and prepares a connected fake helper. It requests native Aqua and leaves the real
status item unselected. Its observer records native identity and semantics only.
No window, bitmap, desktop reconstruction or synthetic capture fallback is added.
The fixture and observer are absent from Release; production appearance is inherited.

Twelve focused story tests cover exact/malformed selectors, template symbol support,
production reading parity, accessibility and invalid states, physical-state symbols,
J7.1 persisted preference/menu routing, J7.2 restoration, helper-loss regression,
fresh frozen fixture state, simulated helper capability and intrinsic native metrics.
Existing broad safety/native styling tests are retained. Prior C03/C04 icon-only tests
now assert the accessible reading and shared production symbol; non-icon assertions
and safety/authority checks are preserved. Acceptance and raw results are recorded in
[the J7.4 evidence](docs/evidence/J7.4/README.md).

J7.4 verification (2026-09-23 local): 12 story tests per runtime; 98 focused tests
per runtime; full package 531 and native 519 tests, each with five existing skips and
zero failures. Package build, native Debug/Release build+analyze, ten malformed-selector
subprocess checks, Release fixture isolation, static/SHA/diff checks passed. The exact
live fixture PID 29583 was launched and reaped; Accessibility was not trusted and no
PID-owned compositor windows were visible. Visual acceptance and live interaction
remain blocked; score/pixel diff are null. No synthetic capture was attempted and
visual-ralph was not invoked outside tmux.
## J8.1 — No reading after wake (G059)

Exact source: Figma file `9DKDgUfEqidZdZQEVlQgLS`, frame `32:3451`,
**8.1 No reading (e.g. just after wake)**. The exact supplied PNG is
`docs/evidence/J8.1/reference.png`, SHA-256
`524141281b61d5cdb627ea8f4cf8cc12658e6f94a802f87d77231472568eb0da`.
The freshly retrieved screenshot is byte-identical. Raw context, header context,
hierarchy, screenshot response and skill-load hashes are retained alongside it.

The frame contains dark Desktop Template `32:3452`, right-aligned Status Item Anchor
`32:3700`, selected Watt? Status Item `32:3697`, and native MenuBarExtra window
`32:3701`. The panel reference is 320 × 195; its FormRetry slot `32:4362` contains
TryAgainNow, with **Try now** and an active, idle, bordered **Try Again** button.
Footer actions are native borderless **Settings…** and **Quit Watt?**.

Exact content: **No reading**, **− − W**, and **Usually right after wake. Watt?
tries again every few seconds.** The status item uses `bolt.fill` and **− − W**;
the warning uses `exclamationmark.triangle.fill`. The source screenshot and user
inspection establish these glyphs; Code Connect wraps the header and does not
export symbol names. Obsolete hierarchy layer names are not display copy.

SF Pro Body/Emphasized 13/16 semibold, Headline/Regular 13/16 bold, Large
Title/Emphasized 26/32 bold and Subheadline/Regular 11/14 regular map to the shared
semantic `WattTypography` styles. Native macOS owns font metrics, material, tint,
focus, row spacing, accessibility and window placement. Shared panel width is
retained; the no-reading Form determines its content height. Reference bounds are
inspection metadata, not absolute child layout. No app-owned wallpaper, glass,
gradient, shadow, drawn desktop/status bar or new bitmap asset is introduced.

Reusable state decision: extend existing `PowerMode.noReading` with explicit
`StatusPanelState.noReading` and `NoReadingPresentation`; keep one
`StatusPanelView` renderer. Valid component-only readings retain their existing
component panel even when no battery watts are available. Missing primary watts, unavailable/stale sources,
invalid samples and denied capabilities cannot become a displayed watt reading.
The summary accessibility value says no reading and omits the symbolic watt
placeholder. Icon Only keeps its native symbol and truthful accessible value.

`PowerReadingStore.refresh()` connects the existing `TelemetryService.sample()`
contract to generation-checked acceptance for both manual retry and three-second
sampling. The status item owns the cancellable sampling task. The production
adapter remains `SystemPowerSourceTelemetryService`: source/percentage status is
not a watt measurement. Five-second status expiry now applies to charging and
desktop readings as well as J6/J7 qualified states; the raw diagnostic sample is
retained. Workspace wake invalidates pre-sleep values and in-flight requests
before retry. Failures stay closed; a validated current sample restores ordinary
production presentation without changing preferences, helper authority or routes.

`--watt-fixture J8.1/base` is accepted only by native Debug. Its fresh memory stores,
frozen clock, deterministic unavailable telemetry, completed livePanel onboarding,
fake connected helper and dark Aqua supply state to the existing native panel
route. The fixture never polls the host or reacts to real wake events. Its optional
observer records native status-button identity only. Release excludes fixture,
registry, selectors and capture observer; production retry remains included.

Acceptance evidence is in `docs/evidence/J8.1/README.md`, `verification.json` and
raw logs. Native styling/symbol/control, retry/recovery/cancellation/generation,
unavailable/stale/invalid/permission, navigation and J6/J7 regression checks are
required. Historical fallback assertions now require the explicit no-reading
copy/state without removing safety or authority checks. Visual acceptance requires
live PID/AX/compositor proof for both panel and selected status item. Until that
proof exists, score and pixel diff remain null. Visual-ralph is unavailable outside
tmux and no workflow/goal state is changed.

J8.1 verification: 19 story tests per runtime; 550 package / 538 native total tests,
five existing skips each and zero failures; focused checks 161 package / 160 native.
Package build, native Debug/Release build+analyze, ten malformed-selector subprocesses,
Release fixture isolation, static/SHA and whitespace checks pass. Capture PID 38757
was terminated/reaped after AX trust was unavailable and no PID-owned compositor
windows were exposed. Native visual acceptance remains blocked, with score/pixel
diff null; no live AX retry press or selected-status verification is claimed.

## J8.2 — Readings resume automatically (no alert) (G060)

Exact source: Figma file `9DKDgUfEqidZdZQEVlQgLS`, frame `32:4456`,
**8.2 Readings resume automatically (no alert)**. The frame is 1000 × 220 and
contains dark Desktop Template `32:4457` with the Dock hidden, right-aligned
status anchor `32:4574`, and Watt? Status Item `32:4572`. The supplied reference
URL, fresh MCP screenshot response, metadata XML and context are retained in
[`docs/evidence/J8.2/`](docs/evidence/J8.2/). The intended status item copy is
the normal native SF Symbol plus **+42.1 W**, using SF Pro Body/Emphasized
13/16 semibold. There is no alert, custom panel, wallpaper renderer or
app-owned menu-bar chrome in this story.

J8.2 reuses the J8.1 recovery contract and has no separate presentation state:
the existing `PowerReadingStore` invalidates pre-wake state, refreshes through
the shared telemetry boundary, accepts only a validated current sample, and
publishes the normal `MenuBarStatusLabel`. Recovery does not navigate,
dispatch a notification, mutate preferences, or present an alert. The selected
`WattDisplayMode` remains the source of truth, while SF Symbols, typography,
material, hit targets and selection remain native `MenuBarExtra`/AppKit output.

The Debug-only `J82FixtureLaunch` starts from `.unavailable` and resumes through
the same `refresh()` path with deterministic fixture telemetry. It uses the
existing status-item bridge and records native identity/semantics only for the
external PID/AX/compositor capture gate. No replacement window, bitmap renderer,
custom status item or synthetic desktop is permitted. The production system
adapter remains fail-closed when it has source status without a measured watt
sample; the fixture supplies the exact `+42.1 W` reference value.

J8.2 acceptance is recorded in `docs/evidence/J8.2/README.md` and
`verification.json`. Visual score and pixel diff remain null unless a live
fixture-owned native compositor surface passes AX and TCC gates.

## J8.3 — Opening Watt? again from Finder or Spotlight shows Settings (G061)

Exact source: Figma file `9DKDgUfEqidZdZQEVlQgLS`, frame `32:4575`,
**8.3 Opening Watt? again from Finder or Spotlight shows Settings**. The frame
is 1000 × 720 and contains the light Desktop Template `32:4576`, the native
menu-bar status item `32:4890` with **+42.1 W**, and a centered native Settings
window `32:4893` measuring 520 × 311. The Menu Bar section uses Show = Delta
and Show symbol = On; General uses Open at login = On and Version = 1.0 (1).
Fresh Figma MCP context, hierarchy, screenshots and hashes are retained in
[`docs/evidence/J8.3/`](docs/evidence/J8.3/). The retrieved MCP screenshot and
the supplied URL are byte-identical at SHA-256
`95284e826372536b4105a03e4749ebf28412329359c01fe9168ced544a837242`.

Launch routing is state-aware and keeps the existing navigation contract:
the first completed launch still presents the coach mark, while a configured
`.livePanel` launch routes to the existing native Settings scene. Finder or
Spotlight reopen continues through `applicationShouldHandleReopen` and the
native bridge (`openSettings()` on macOS 14 and `showSettingsWindow:` on
macOS 13). Preferences remain owned by the shared `PreferencesStore`, so the
configured Delta, symbol, login and version values are not reset.

The Debug-only `J83FixtureLaunch` supplies deterministic telemetry/preferences
and observes the real Settings scene for capture evidence. Its fixture-only
`relaunchExcerpt` reuses `SettingsRootView` with native grouped `Form`,
`Section`, `Picker`, `Toggle` and `LabeledContent`; production Settings keeps
the complete shared preferences surface. No wallpaper, titlebar, traffic
lights, rounded background, gradient, custom chrome or replacement control is
drawn. The selector is absent from Release through conditional compilation and
the Release isolation check.

J8.3 acceptance is recorded in `docs/evidence/J8.3/README.md` and
`verification.json`. Native visual score and pixel diff remain null unless the
fixture-owned Settings window is exposed by AX and the compositor/TCC capture
gate; a failed gate is recorded as a blocker rather than a visual pass.


## J9.1 — Settings → Remove… (confirm) (G062)

Exact Figma node `32:5397`, 1000×720; native Settings `32:5551` (520×187)
with alert `32:5813` (260×260). Fresh context, hierarchy and byte-identical
user/MCP screenshots are preserved in `docs/evidence/J9.1/`.

The existing Settings scene and shared grouped Form/helper rows present the
system SwiftUI alert. Title: **Remove the helper?** Message: **Components stop
and the menu bar switches to Delta. Turn it back on any time.** Cancel has no
side effects. Only destructive Remove invokes `removeVerifiedHelper`; that
flow rechecks helper status and switches to Delta only after verified absence.
Component selection is retained. Cancelled/failed/unverified removal never
claims success. No custom window, traffic lights, desktop or alert chrome.

Debug-only `J91FixtureLaunch` supplies the existing J7.2 component values and
opens the shared Settings scene/alert; its removal adapter returns cancelled,
never touches installed resources and never fabricates verified absence.
Release omits the harness. Fixture selector is exact `J9.1/base`.

Unit/domain navigation and removal semantics are verified. The native capture
attempt is blocked by missing AX trust and PID-owned compositor windows; live
button/keyboard interaction and visual acceptance remain unverified. Score and
pixel diff stay null. See evidence verification and visual-review JSONs.

## J9.2 — Helper removed (G063)

Exact Figma node `32:5844`, 1000×720, Settings `32:6001` (520×269),
grouped content `32:6020` (480×198). Fresh MCP context/metadata/screenshot
and supplied screenshot bytes/hashes are recorded in `docs/evidence/J9.2`.
The screenshot says **Helper** in the section header; the explicit supplied
hierarchy says **Component Readings**, which this implementation follows.

Verified removal now presents Menu Bar → Show **Delta**, shared Status **Off**
with “Reading CPU, GPU, display and the rest.”, and a native bordered **Turn On…**.
`SettingsHelperSetup.resetAfterVerifiedRemoval` owns the transient success state.
No success state is published during a pending, failed or cancelled removal.
Selected components and unrelated preferences are retained; component readings
are unavailable, not fabricated zeroes. The status item remains inserted and
uses the shared formatter. Turn On uses the existing approval coordinator;
registration acknowledgement alone cannot enable readings. Verified reconnection
returns to the ordinary Settings surface.

The native grouped form owns layout and system materials; Figma desktop/window
coordinates are reference evidence, not absolute app positioning. No custom
wallpaper, window chrome, traffic lights, backgrounds or controls were added.
`J92FixtureLaunch` is Debug-only, exact `J9.2/base`, isolated in-memory and runs
the shared verified-removal route. SwiftPM rejects fixture launch; Release omits
the fixture implementation. No installed helper is removed by the fixture.

Focused/package tests and Debug/Release build/analyze evidence accompany the
implementation. Native capture is blocked by missing AX trust and compositor
windows; visual score/pixel diff remain null, not claimed accepted.


## J9.3 — After Quit: status item gone (G064)

Exact Figma file `9DKDgUfEqidZdZQEVlQgLS`, node `32:6494`, 1000×220.
Fresh context, metadata and screenshot are in `docs/evidence/J9.3`; retrieved and
supplied PNGs both hash to `dbb12c0ff5fdb072f77626740af6954b710d6f046cf2feb622ae660e7f506a84`.
The only child is the light Desktop Template, with Dock hidden and Finder active.
Apple/Finder/File/Edit/View/Menu Item/Window/Help, Wi-Fi, Spotlight, Control Center,
and date/time are native system chrome, not Watt UI. SF Pro Body/Emphasized 13/16
requires no app typography override. The exported frame crops the leading menus.
There is deliberately no app-owned crop, view, wallpaper, panel, or fake menu bar.

The existing native context-menu Quit (`⌘Q`) still calls `NSApplication.terminate`.
SwiftUI remains the sole production MenuBarExtra/NSStatusItem owner; the process
exit removes that item. Watt never removes a borrowed SwiftUI item manually.
`WattApplicationDelegate.applicationWillTerminate` is idempotent, clears reopen
and teardown callbacks, disables presentation, clears panel state, tears down the
anchor event monitor/popover/callbacks, and orders app windows out. A queued panel
click cannot reopen a detached/torn-down anchor. Representable dismantling also
tears down its own anchor. None of this changes persisted settings/helper state.
A fresh process constructs a fresh delegate/router and retains configured Settings,
onboarding, and deferred-setup launch routing; closing a window is not quitting.

`J93FixtureLaunch` is Debug-only, exact `J9.3/base`, with isolated in-memory stores.
It borrows the existing native status button and invokes the production NSMenu Quit
item, recording identity only before exit. It creates no replacement surface and
never claims that programmatic invocation is a user click. SwiftPM rejects fixture
launches, and Release has no J93 fixture symbols/selectors. The registry explicitly
identifies this fixture's real process-termination effect rather than fake success.

Verification: 6 J93 tests, 17 focused J9 regression tests, and 578 full package tests
(5 skipped) pass. Debug/Release build and analyze pass; see logs for native test-target
compile evidence. The initial package toolchain mismatch and the registry expectation
failure are retained in preflight/first-run logs; final runs use Xcode's toolchain.
Native acceptance remains blocked: two 20-second fixture attempts never reached the
status button/quit observation. AX trust is false, screen capture is preauthorized,
and LocalAuthentication is frontmost. A real Launch Services launch from a temporary
`~/Applications/.../Watt.app` succeeded without fixture arguments but its window route
could not be observed. PIDs 66509, 66681, and 66843 are no longer running, have no
owned compositor windows, and the temporary app bundle was removed. This cleanup is
not evidence of a successful context-menu Quit. No native test host was left waiting.
Visual score and pixel diff are null; no fabricated screenshot or similarity claim.

## J10.1 — Check for Updates menu admission (G065)

Exact Figma `34:3836` / native menu `34:4148`; fresh context, metadata and identical
supplied/retrieved 1000×720 PNGs are retained in `docs/evidence/J10.1`.
Existing AppKit NSMenu/NSMenuItem own all chrome, font, material, separators and
selection; menu ordering and native Command-, / Command-Q remain unchanged.

The software update item no longer opens J3.3's helper-update prompt. AppRouter uses
existing UpdateService/UpdateStore with synchronous `.checking` admission, one action
per live menu token, in-flight coalescing, persistence gating and generation-checked
results. Busy/offered/retained update transactions disable a new check. A new menu
permits retry after an authoritative no-update/failure result; stale items do not.

**Acceptance blocked, not story closure:** no production updater endpoint/trust/driver
composition exists. Production therefore disables the item. No fake network result,
new endpoint is added by J10.1; the subsequent J10.2 section documents its checking screen. The exact J10.1 fixture remains fail-closed;
unit tests inject a suspended service and exercise actual native menu actions. Capture
uses the existing isolated J7.1 native menu only as an explicitly labeled diagnostic
proxy; it is not an enabled J10.1 reference match. Numeric score/pixel diff remain null.
See evidence README and verification.json for checks, warnings and capture blockers.


## J10.2 — Native checking window (G066)

Exact Figma file `9DKDgUfEqidZdZQEVlQgLS`, story `34:4482` (1000×720),
Software Update window `34:4636` (420×177; content 420×146).
Fresh context/metadata/screenshot responses and byte-identical supplied/retrieved
references are stored with SHA256 hashes in `docs/evidence/J10.2`.

`UpdateRootView(softwareUpdate: true)` uses native SwiftUI stacks, the existing
Watt app icon, exact “Checking for updates…” copy, an indeterminate linear
ProgressView and native Cancel button with Escape shortcut. The SwiftUI Window
owns its title bar and chrome; no wallpaper, absolute positioning, custom progress
drawing or window decoration is reproduced. J3.3 retains its separate helper scene.

J10.1 routes here only after an injected UpdateService and persisted checking
admission. Production remains fail-closed without trusted updater composition.
Cancel invalidates the UpdateStore generation before cancelling the task, rejects
late results even from noncooperative services, and keeps persistence failures
retryable. Closing the content also requests cancellation. Service outcomes dismiss
checking; J10.3 now stays in the same scene (see below); J10.6/J10.7 remain backlog.
The Debug-only J10.2/base fixture suspends without a fabricated result or external
effects and cannot activate in SwiftPM or Release.

Verification: 13 focused tests pass (7 J101, 6 J102); full SwiftPM suite passes
591 tests, 5 skipped, zero failures, including existing J3.3 coverage. Debug build,
analyze and build-for-testing pass; Release build/analyze pass. Release
build-for-testing was also attempted but is blocked by the existing test target's
incompatible Release Watt import (J83OpeningSettingsTests); no test-fixture gates
were weakened to make Release testable. Native test execution is not claimed.

Visual acceptance remains blocked: Screen Recording preauthorized, AX trust false.
The exact fixture exposes a PID-owned 420×178 Software Update window on this host;
native titlebar geometry differs by one point from Figma. No pixel-match claim is
made; score/pixel_diff remain null. Capture processes were terminated and reaped.


## J10.3 — Native update available (G067)

Source: file `9DKDgUfEqidZdZQEVlQgLS`, frame `34:4695` (1000×720),
window `34:4849` at (240,188), 520×365. Fresh context, metadata, both identical
retrieved/supplied PNGs and SHA256 records are in `docs/evidence/J10.3`.
The rendered PNG uses “Watt? 1.1 is out” / “What changed”, while the metadata
and explicit story request use the longer headings. **The explicit requested
copy wins**: “A new version of Watt? is available”, “Watt? 1.1 is available —
you have 1.0.” and “What’s New in 1.1”. Existing native app icon replaces the
reference placeholder; no wallpaper or custom window chrome is shipped.

`SoftwareUpdateContent` observes the same UpdateStore for checking → available;
the checking view no longer dismisses an available result. A light native Window,
SF semantic text styles, grouped Form, checkbox (initially off), bordered buttons
and blue borderedProminent Install Update own the presentation. Native title bar
height is host-controlled (observed 520×366 rather than forcing Figma’s 365).
Release copy is scoped to version 1.1; other versions do not borrow these notes.

Actions produce a version/generation-scoped `UpdateOfferIntent` for later stories.
Skip/Remind Later persist the local offer dismissal before closing; failure leaves
the offer retryable. This does **not** claim a durable skip list or reminder schedule.
Install retains the offer and records a handoff, explicitly showing that download
is not available yet. The checkbox travels as preference intent only, not consent
or an installed setting. No action creates a transaction receipt, invokes download,
installs, launches, or approves a helper. Future stories consume these intents.
A restored offer requires a fresh trusted check; failed transactions retain their
receipts and reject offer/dismissal overwrite. Production composition stays closed
without an injected trusted UpdateService. Exact Debug fixture `J10.3/base` alone
injects FakeUpdateService; SwiftPM launch is false and Release omits the fixture.

Validation and known gaps are recorded in `docs/evidence/J10.3/verification.json`.
Native capture is AX-blocked; no comparable screenshot, visual pass or pixel score
is asserted. Release build-for-testing remains blocked by the existing test-target
module import configuration, without relaxing Release isolation.

## J10.4 — Downloading (G068)
- Exact Figma: `9DKDgUfEqidZdZQEVlQgLS`, frame `34:5339` (1000×720), window `34:5493` at 290,282 (420×177); content `34:5512` 380×106 at 20,20; determinate instance `34:5598`.
- Reuses J10.1–J10.3 Software Update scene, UpdateStore, UpdateService, AppRouter and existing 64×64 app icon. Copy: “Downloading Watt? 1.1…” and “2.1 MB of 4.2 MB” at fixture half-progress.
- Native ownership is durable: `ProgressView(value:)`, `.linear`, bordered Cancel and real titled NSWindow. Production inherits system appearance/accent; removed cumulative forced light/blue overrides. Semantic `WattTypography.bodyEmphasized` and `.footnote` replace fixed update fonts. Figma 13/16 and 10/13 text, 24pt button/radius6/padding16, #0088ff accent, #00000012 track, label alphas and white window are reference metadata, NOT custom-painted controls or forced metrics. Host macOS owns rendering/accessibility/dark/high-contrast behavior. DEBUG fixture alone requests Aqua.
- Version/generation-scoped admission persists an interrupted-recovery receipt marker atomically before service download. Progress validates byte ranges, fixed total, monotonicity and generation. Unknown total begins determinate zero with “Preparing download…”; no fabricated production byte count. Only matching staged receipt is admitted; no install/relaunch effect.
- Cancellation invalidates generation before persistence/service calls, drains old work before discard/retry, and retains exact receipt on errors. Exact discard acknowledgement gates clearing; failed acknowledgement persistence retries locally without cancelling an already-discarded receipt. Restart retains receipt for adapter reconciliation, not automatic resumption.
- States: initial zero, byte progress, failed/persistence-failed, cancelling, cancelled/discarded, staged-complete boundary. Install/relaunch J10.5+ remain out of scope; production updater composition remains deliberately unconfigured.
- Acceptance: native 420pt content width, 64pt icon, exact copy, determinate 50% fixture, native Cancel; malformed/stale/foreign replies fail closed; safe cleanup-gated retry; J101–J103 regressions green. Evidence: `docs/evidence/J10.4/` holds fresh MCP responses/reference SHA256 and verification/capture results. Visual acceptance is independently gated; null score/pixel diff unless actually measured.

## J10.5 — Ready to install (G069)
- Source: file `9DKDgUfEqidZdZQEVlQgLS`, frame `34:5608` (1000×720), native window reference `34:5762` (420×177), content `34:5781` at 20,20 (380×106), icon `34:5797` (64×64), title `34:5801`, 100% progress `34:5805`, footnote `34:5807`, Later `34:5814`, Install and Relaunch `34:5821`. Content instance descendants use prefix `I34:5762;4363:18606;`; the bare footnote ID is invalid in MCP.
- Fresh exact text context overrides the stale footnote layer name: “Ready to install”; “Watt? quits, updates and comes back to the menu bar. About 5 seconds.” All MCP responses, including the failed bare-node request and successful qualified request, are retained under `docs/evidence/J10.5/`.
- Native styling: semantic WattTypography headline (bold), bodyEmphasized (semibold) and footnote; primary/secondary labels; native determinate ProgressView at 1 and bordered/borderedProminent buttons. Figma Body 13/16, Headline 13/16, Footnote 10/13, blue #0088ff, track #00000012, white background, 24pt/radius6/padding16 buttons describe reference intent, not forced production metrics, accent or appearance. Native titlebar/menu/window rendering and accessibility remain OS-owned. Existing app icon is reused in place of the design placeholder. DEBUG capture alone requests Aqua.
- Navigation: J10.4 completion → ready content in the existing Software Update scene, only when staged state matches the exact active download receipt and version. 100% downloaded bytes alone are insufficient. Later checkpoints staging and dismisses without discard, timer, install or helper effects. A fresh presentation can offer that retained staging again. Install and Relaunch checkpoints staging, emits a one-shot typed ReadyIntent and dismisses; later stories must consume it and perform authenticated installation/relaunch. No fake install, five-second timer, helper update or success is performed.
- Every intent includes version, generation and full receipt, gated by a live presentation token. Close/replacement invalidates the presentation; consumption advances generation. Wrong version, stale generation, foreign receipt (including matching ID with altered timestamp), failed state and duplicate actions fail closed. Write failure keeps staging and the current presentation retryable; restart preserves an interrupted receipt but restores neither readiness nor consent. Recovery/reconciliation and production source/trust composition remain dependencies, not implied features.
- Acceptance: native 420pt content width/64pt icon, exact text, 100% progress; Later/install handoff boundaries, retry persistence and stale/closed rejection; J101–J104, NativeStyling and P04 regressions. DEBUG-only `J10.5/base`; Release must contain no fixture selectors/symbols.
- Evidence/known gaps: `docs/evidence/J10.5/verification.json`, `visual-review.json` and README contain final fresh command results. AX/TCC and Release test-target import limitations are reported explicitly; null metrics are not a visual acceptance claim.

## J10.6 — Up to date (G070)
- Source: Figma `9DKDgUfEqidZdZQEVlQgLS`, frame `34:5822` (1000×720), alert `34:5976` at (370,261), 260×198. Icon `34:5976;495:4743` (64×64), title `34:5976;152:9962`, message `34:5976;152:9963`, primary full-width OK `34:6002`.
- Exact copy: “You’re up to date”, “1.0 is the latest.”, “OK”. Runtime message uses the installed app version. Fresh context, metadata, variables, screenshot response and reference PNG/hash are preserved in `docs/evidence/J10.6`.
- Native decision: SwiftUI’s sheet-style alert was captured without an app icon on this OS; native standalone AppKit `NSAlert` owns icon, title/message typography, primary/default button, layout, material and chrome. Figma Body/Emphasized 13/16 semibold, Headline/Regular 13/16 bold, Subheadline/Regular 11/14, primary/white labels, blue accent and Liquid Glass describe native intent, not fixed production metrics. No custom glass, icon drawing, titlebar or wallpaper; no forced appearance/tint/font overrides.
- Navigation: J10.1 → J10.2 checking → accepted `success(nil)` → persisted idle + generation-scoped J10.6 alert. OK dismisses the update scene to the existing status item, not a new panel. Closing invalidates checking; restored idle alone never implies success.
- States: checking, visible success, dismissed, closed/stale rejection, persistence failure with cancellation/retry, service failure/available (not success). Persist-before-present prevents false success; failed cancellation still invalidates the generation. An active success alert blocks duplicate checks until dismissed.
- Dependencies: existing UpdateStore/AppRouter/UpdateService/P04 only. No updater endpoint, download, install or relaunch effects added; J10.7 owns error presentation/retry UI. DEBUG-only `J10.6/base` with injected nil result; Release excludes fixture symbols/selectors.
- Acceptance: exact copy and route, OK/close lifecycle, stale generation/late result rejection, failed persistence and subsequent retry; J101–J106, NativeStyling and P04 green. Native OS metrics supersede literal alert size. Full test/build/analyze/static/capture results and any AX/TCC/Release-test limitation are reported in evidence JSON; null comparison metrics are not visual approval.

## J10.7 — Couldn’t check for updates (G071)

- Source: Figma file `9DKDgUfEqidZdZQEVlQgLS`, frame `34:6003`, Alert `34:6157` at (370,230), 260×246 in a 1000×720 desktop. Exact task-supplied hierarchy/variables and downloaded reference are preserved in `docs/evidence/J10.7/figma-source.json`.
- Exact title: “Couldn’t check for updates”. Description: “No connection right now. Watt? checks again later on its own.” Native informational NSAlert with Try Again (default) and OK (secondary). macOS owns icon, typography, material, geometry and button arrangement; no custom SwiftUI alert or forced appearance/tint/glass.
- Only accepted, persisted, non-cancelled check failures without a transaction receipt create ephemeral presentation identity. Generation, identity and receipt-free failure state gate both actions. Closed/stale results and restored failures cannot reopen this alert.
- Try Again re-enters the existing checking route; failed persistence retains the error token and allows another attempt. OK dismisses to the existing status item, never opens a panel. No automatic scheduler, production endpoint or installer effects are introduced by this story; the exact description does not claim those dependencies have been implemented here.
- DEBUG-only `J10.7/base` injects a network failure. Release fixture symbols/selectors are excluded. J107 tests cover copy/default action, retry/OK identity, stale/closed results, receipts, restoration and persistence.
- Captured native output uses side-by-side buttons and a 260×218-point window on this host, unlike the reference’s vertical buttons/246-point height. This is intentional OS-owned layout, not a custom recreation. AX/TCC blocks interaction acceptance; score/pixel_diff remain null, visualPass false. See evidence README and JSON for exact validation results.


### J10.8 — After relaunch: helper update / G072
Figma `9DKDgUfEqidZdZQEVlQgLS`, frame `34:6183`, alert `34:6340`; exact title, description, Update Helper/default and Later/Escape. Native informational NSAlert owns icon, typography, materials, button arrangement and chrome; no forced tint/appearance or desktop recreation. Existing status-item bridge is retained; DEBUG fixture supplies charging +42.1 W and isolated preferences. Generation/presentation-scoped intents reject stale callbacks; relaunch verification precedes helper mutation, retries retain the operation receipt and approval is never inferred from a click. Evidence and validation gaps: `docs/evidence/J10.8/README.md`, `verification.json`, `visual-review.json`.


### J12.1 — Settings → Uninstall / G073
Figma file `9DKDgUfEqidZdZQEVlQgLS`, frame `35:4360`, Settings `35:4678`.
The native Settings scene reuses SettingsRootView's grouped Form/General section:
Open at login, Check for updates automatically, Uninstall Watt? with native destructive
Uninstall… button and exact subtitle, then Version. The DEBUG-only General excerpt is
540 points wide; row metrics, title bar, switches, borders, font and semantic colors
remain OS-owned (not copies of Figma's desktop or control geometry). Production keeps
the full Settings surface. Existing status-item bridge provides charging +42.1 W.

Opening J12.2 creates an in-memory, presentation-scoped intent only. Duplicate, busy,
closed and stale presentation requests are rejected; cancellation permits retry.
Opening/cancelling never writes preferences, clears helper state or calls removal.
Existing explicit confirmation/removal behavior remains downstream, outside G073.
Persistence errors remain visible; intent creation neither conceals nor repairs them.
The isolated fixture disables installed removal effects and is absent from Release.
Evidence, build/test results and native AX/TCC/compositor gaps: `docs/evidence/J12.1`.

### J12.2 — Confirm uninstall / G074
Exact Figma file 9DKDgUfEqidZdZQEVlQgLS, frame 35:5144 (1000×720),
Settings 35:5301 (540×187 at 230,277), status anchor 35:5300/item 35:5298.
The DEBUG-only base fixture reuses the native Settings scene, grouped General
rows Open at login / Uninstall Watt?, and status bridge (+42.1 W). Production
retains the complete Settings form. The exact row subtitle and confirmation
message come from MCP context. SwiftUI .alert owns destructive Uninstall and
Cancel controls, keyboard/Escape behavior, typography, materials and chrome;
Figma SF Pro/color/toggle/liquid-glass variables are reference evidence, not
instructions to paint imitation native controls.

Opening confirmation creates no removal effects. Explicit confirmation consumes
one presentation/generation-scoped intent before awaiting removal. Cancel,
window close, stale generations and duplicate confirms cannot remove anything.
In-flight work blocks concurrent removal even after reopening; failures permit
fresh consent. Uninstall completion never rewrites deleted preferences or updates
a stale Settings presentation. The fixture is DEBUG-only and disables real removal.
Evidence and honest visual/Release-test-build limitations: docs/evidence/J12.2.

## J12.3 / G075 — verified uninstall leaves no Watt presentation
Source: Figma `9DKDgUfEqidZdZQEVlQgLS`, frame `35:5599`, 1000×220;
Desktop Template `35:5600`. Finder/File/Edit/View/Menu Item/Window/Help and
wallpaper/menu bar belong to macOS (leading Finder chrome is outside the crop).
The only variable is SF Pro Body/Emphasized 13/16. No app window, status item,
Dock reconstruction, success panel, wallpaper asset or app typography is added.

Exact J12.2 consent is consumed once. AppRouter binds the P05 ScopedRemovalAdapter,
requires login/helper/configuration/application ownership entries, retains the
transaction receipt across retry, and terminates native presentation only on
verified absence. P05 verifies owned inventory and process state; failures retain
the app and do not rewrite preferences. Existing native termination handles
windows/status-item lifetime. Production remains fail-closed until a trusted
OwnedRemovalDriver is composed; this work does not invent installer authority.

DEBUG-only `J12.3/base` is a controlled no-Watt launch exiting before stores/scenes.
It is not a real uninstall or proof of installed-resource deletion. Evidence:
`docs/evidence/J12.3`; visual metrics are null without a valid compositor comparison.

### G076 / J12.4 — leftover helper after reinstall
Exact Figma file `9DKDgUfEqidZdZQEVlQgLS`, frame `35:5746`, Alert `35:5900`.
`LeftoverHelperAlert` is an informational NSAlert: “A helper from your last install”;
“Reconnect it and Components pick up where they left off. Or remove it.”
Reconnect is the default first button; Remove Helper is the second, never Escape.
The 260×246 Figma alert, 64-point icon, SF Pro Body/Headline/Subheadline, labels
#000000d9/#fff, accent #0088ff and secondary #e6e6e6 describe the reference only.
AppKit owns icon, fonts, material, button arrangement and geometry. No appearance,
tint, glass, desktop simulation, custom SwiftUI alert or window chrome is applied.
P05 inventory plus a different trusted installation ID detects leftovers; P02
reconciliation must authenticate before reconnect succeeds. Removal stays helper-only.
Consent is generation/presentation-scoped; durable receipts precede removal and survive
retry. Only verified outcomes are acknowledged. Closed/cancelled replies cannot publish.
DEBUG `J12.4/base` uses in-memory closures, no live helper mutation or persistent defaults.
Live installation manifest/driver and downstream J12.5 preference navigation remain
composition dependencies; no default production mutation driver has been invented.
Evidence and honest visual/build limitations: `docs/evidence/J12.4`.


## G077 — J12.5 Reconnected (35:5926)
Source: exact Figma MCP file `9DKDgUfEqidZdZQEVlQgLS`, retained under
`docs/evidence/J12.5`. Continue through the existing native SettingsRootView grouped
Form / Component Readings Section / LabeledContent and bordered Remove… Button.
Successful reconnect displays Status “On”, subtitle “Reading CPU, GPU, display and the
rest.”, and semantic Footnote “Reconnected from your last install.” (Figma SF Pro 10/13).
The reference image calls the section “Helper”; the supplied structural requirement
and existing component name remain Component Readings. No custom window, chrome,
status item, material, or desktop is introduced. The fixture requests 540-point content
width; native titlebar, row, button and font metrics remain OS-owned, not pixel-certified.
The existing status bridge uses charging Delta +42.1 W. The reconnect prompt consumes
its generation/presentation intent before awaiting P05/P02 reconciliation, persists a
receipt before work, and publishes J1.6 All Set only after durable preference transition.
Unacknowledged continuation can retry without repeating the successful helper effect.
DEBUG J12.5/base uses in-memory services only; production requires an explicitly
configured trusted adapter and preferences. Native capture/AX limitations and Release
test-build gaps are recorded honestly in the evidence; no visual score is assigned.
## G078 / J11.1 — native status-item and panel accessibility

- Keep the status item as one native `MenuBarExtra` label. Put the state, spoken
  wattage and “menu extra” role in its accessibility label, use the native help
  string for the click/VoiceOver hint, and do not add a second accessibility
  value that would repeat the wattage.
- Gate status-item AX refreshes on a state key or a 30-second interval. Sampling
  may update the visual label more often, but VoiceOver should not double-announce
  every telemetry sample.
- Keep panel order in the native `Form`/`Section`/`LabeledContent` hierarchy:
  summary, Power, Components, then native Settings… and Quit Watt? buttons.
  Mark the Components section title as a heading and use native Cmd-, Cmd-Q,
  Tab/Shift-Tab and Esc behavior rather than custom key handling.
- Reuse semantic typography and colors. Numeric values use
  `.monospacedDigit()` while the native window material, button treatment,
  focus ring and chrome remain AppKit/SwiftUI-owned.
- A native capture is evidence only when TCC trust, compositor ownership and AX
  content all pass. If any gate fails, record null score/pixel diff and the exact
  blocker; never substitute a cached view, fake window or invented visual score.

### Runtime host fallback

The ordinary local launch keeps the same native `MenuBarStatusLabel` and panel
content, but uses a public AppKit `NSStatusItem`/`NSPopover` fallback when the
host does not materialise SwiftUI `MenuBarExtra`. Debug fixture launches retain
the `MenuBarExtra` path so native visual evidence remains isolated. The fallback
also opens the native panel in a normal `Watt?` window on launch, making the app
discoverable when a menu-bar compositor hides third-party items; it does not paint
custom menu-bar chrome or replace native controls.

### C03 state correction — 2026-09-23

The exact C03 Figma state renders `Check for Updates…` enabled. The DEBUG-only
C03 fixture now injects the existing in-memory `FakeUpdateService` so AppKit
renders that state without network, installation or OS effects. Production
composition remains fail-closed with no updater until the trusted P04 service is
configured. Focused package/hosted tests and the native capture prove the state;
the existing C03 material/compositor/AX visual gates remain open. Evidence:
`docs/evidence/C03/state-correction-2026-09-23/`.
