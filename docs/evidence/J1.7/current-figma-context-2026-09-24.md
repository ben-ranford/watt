# J1.7 exact Figma context — 2026-09-24

File: 9DKDgUfEqidZdZQEVlQgLS

The exact Figma MCP context was freshly retrieved for the story frame and the
coach-mark component:

- Frame 28:2621: “1.7 First run — where Watt? lives”
- Desktop Template 28:2622: Light desktop, dock hidden, Finder menu bar
- Status Item Anchor (right-aligned) 28:2770
- Watt? Status Item 28:2768, showing the native battery symbol and +42.1 W
- Coach Mark (Popover) 28:2771
- Popover content slot 28:2787
- Popover variant: Light, Top (Trailing)
- Native Got It variant: active, idle, bordered-prominent/default

The parent reference is a 1000×720 desktop frame. The coach-mark application
surface is 260×136 points. The exact nested MCP response shows the native
popover surface, arrow, native material, “Watt? lives here” title, the
two-line “Click for the detail. Right-click to change the number.” message,
and the Got It action.

## Typography and tokens

- Headline/Regular: SF Pro bold, 13/16.
- Subheadline/Regular: SF Pro regular, 11/14.
- Native Light popover material, Top (Trailing) arrow placement.
- Native bordered-prominent/default Got It action.
- Native status item content uses the battery symbol and +42.1 W.

The implementation maps these to semantic SF Pro SwiftUI styles and AppKit
NSPopover/NSStatusItem. No custom popover material, arrow, shadow, status-item
chrome, or private font is introduced.

## Verification correction

The previous fixture capture referenced a non-existent Debug build path and
failed before rendering. The fresh fixture build uses the actual binary and
captures two app-owned compositor windows. The first is the real NSPopover
surface (286×162 points including native shadow/arrow); the second is the
temporary native anchor window used only to allow NSPopover to materialise when
the host does not expose a third-party status item.

The temporary anchor is capture scaffolding, not product UI. The captured
popover remains the production NSPopover with OS-owned chrome. Live status-item
activation, VoiceOver traversal, and click/keyboard interaction are not
claimed by this evidence.
