# J1.4 / Waiting for approval — current Figma context

Source: Figma file `9DKDgUfEqidZdZQEVlQgLS`, retrieved through Figma MCP on
2026-09-23 with `nodeId=28:1206`, `clientLanguages=swift`,
`clientFrameworks=swiftui`, and `figma-design-to-code,figma-swiftui`.

## Exact hierarchy and variants

- Frame `28:1206`: **1.4 Waiting for approval (system notification)**.
- Desktop Template `28:1207`: macOS 27, Light, dock hidden, Watt? menu bar.
- Onboarding window `28:1521`: Light, active, **Default without Title**, native
  window controls, 480 × 224 points at the supplied desktop coordinates.
- Content slot `28:1535`: spinner `28:1537` (Circular Indeterminate, Small),
  bordered Cancel, and bordered-prominent/default Open System Settings.
- System Notification `28:1584`: Light, non-stacked Liquid Glass notification,
  custom app icon, title **Background Items Added**, message **“Watt? Helper”
  can run in the background. You can manage this in Login Items & Extensions.**

The qualified parent frame is the authoritative context for content slot
`28:1535`; direct MCP selection of that nested slot is rejected as an invalid
visible-page selection. The full parent response, including nested component
variants and system-notification copy, was successfully retrieved.

## Typography and native mapping

- Body/Emphasized: SF Pro Semibold, 13/16, weight 590.
- Title 2/Emphasized: Figma reports Inter Bold, 17/22; Watt maps this to the
  semantic native SF Pro title style under the native-styling policy.
- Body/Regular: SF Pro Regular, 13/16.
- Subheadline/Regular: SF Pro Regular, 11/14.
- SwiftUI `ProgressView()` with `.controlSize(.small)` owns the indeterminate
  spinner; no painted spinner or timer is allowed.
- Native `.bordered` Cancel and `.borderedProminent` default Open System Settings
  own control metrics, keyboard roles, focus and accessibility.
- The Notification Center card is system-owned. Watt does not draw a copy,
  request permission as part of this fixture, or infer helper approval from it.

## State and verification boundary

The app-owned state is the persisted onboarding `.approval` checkpoint. Cancel
withdraws only the onboarding approval interest; Open System Settings delegates
to the injected AppRouter boundary. Neither action marks approval or changes
component-readings availability. A real service composition must provide the
macOS Login Items & Extensions effect and subsequent reconciliation.

Fresh native verification on macOS 27 (Build 26A428): the exact app-owned window
captured at 960 × 448 pixels / 2×, normalizing to 480 × 224 points. The
titlebar-cropped `native-content.png` is the visual content evidence. The
system notification is excluded because it is outside the app-owned process and
cannot be safely captured or recreated in this environment. Accessibility and
whole-frame visual completion therefore remain open; no story completion is
claimed from the app-window comparison alone.
