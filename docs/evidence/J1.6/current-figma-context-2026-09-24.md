# J1.6 exact Figma context — 2026-09-24

File: 9DKDgUfEqidZdZQEVlQgLS

The qualified Figma MCP context was retrieved for the exact implementation
frame and its onboarding-window subtree:

- Frame 28:2199: “1.6 All set”
- Desktop Template 28:2200: Light appearance, dock hidden, Watt? menu-bar host
- Onboarding window 28:2353: Light, active, Default, without title
- Content slot 28:2365: included in the qualified parent response; direct
  selection is invalid in the MCP context
- FormLogin row 28:2532: “Open at login”, native switch on
- Native-prominent Done action in the window

The parent response reports a 480×328 point onboarding window. The hierarchy
contains the app-icon placeholder, centered title/body, one FormLogin row and
the bottom-right Done action. The reference is an OS-style composition, not a
request to paint a custom macOS window or control.

## Typography and tokens

- Body/Regular: SF Pro regular, 13/16.
- Body/Emphasized: SF Pro semibold, 13/16, approximately weight 590.
- Title 2/Emphasized: Figma Inter bold, 17/22; the implementation maps this
  to the existing semantic native title style rather than adding a font.
- Light background, native traffic lights, native switch and native-prominent
  action.
- The exact visual frame measures 480×328 points. The implementation uses the
  existing onboarding width token and native Form metrics.

## Implementation decision

A fresh native capture using FormStyle.columns produced a 480×293 point window
with a compact, unrounded login row. That was a material discrepancy against
the exact 480×328 reference. Changing only the native SwiftUI Form style to
.grouped produced a fresh 480×328 point window with the expected rounded native
row. No custom padding, background, corner radius, shadow, or control drawing
was introduced.

This document records the MCP evidence and the native correction. It does not
claim AX trust, VoiceOver traversal, live switch/Done interaction, or
macOS login-item registration.
