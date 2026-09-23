# G083 — Figma MCP reinspection

This record captures the exact Figma MCP retrieval performed for the G083
native-metrics correction on 2026-09-23. It is a design-context inspection,
not a new implementation screenshot or visual-pass verdict.

## Retrieval

- File key: `9DKDgUfEqidZdZQEVlQgLS`
- Exact frame: `27:1584` — **1.3 Offer component readings**
- Retrieval: Figma `get_design_context`, Swift / SwiftUI target
- Saved visual reference: `docs/evidence/J1.3/figma-frame.png`
- Top-level frame: `27:1585` — **Desktop Template**
- Figma frame export: 1000×720 pixels

## Hierarchy and variants

The exact frame contains a light-mode macOS desktop template with the dock
hidden and a composed onboarding window:

- Window: `27:1738` — **Watt? Onboarding Window**; light mode, active, **Default
  without Title**.
- Content area: `27:1750`.
- App icon placeholder: custom Watt app icon variant.
- Facts component: `27:2106` — **FormHelperFacts**.
- Primary action: **ButtonEnable**, active / content area / idle / **Bordered –
  Prominent (Default) D**, label `Turn On…`.
- Secondary action: **ButtonNotNow**, active / content area / idle / **Bordered**,
  label `Not Now`.

The facts component has three rows and native-style leading/right accessory
variants:

| Row | Leading title | Right label |
|---|---|---|
| `WhatItReads` | `What it reads` | `Power sensors only` |
| `NetworkAccess` | `Network` | `Never` |
| `RemoveIt` | `Remove it` | `Any time, in Settings` |

Each leading accessory has its symbol and disclosure enabled, with no subtitle;
each right accessory uses the label variant, with info disabled.

## Design details relevant to G083

- The reference window crop is 480×412 points at `(260, 164)` in the desktop
  frame.
- Typography returned by the inspection is **Body / Emphasized** — SF Pro
  Semibold, 13pt / 16pt; **Title 2 / Emphasized** — Inter Bold, 17pt / 22pt;
  and **Body / Regular** — SF Pro Regular, 13pt / 16pt.
- The facts surface is a grouped native form hierarchy rather than three
  custom-painted rows.
- The actions are native bordered controls; the design-context variants do not
  specify custom label padding.

## Implementation mapping

`Features/Onboarding/Views/OnboardingFlowView.swift` maps the facts component
to SwiftUI `Form` with `.formStyle(.grouped)` and three `LabeledContent` rows.
The action components map to native `.bordered` and `.borderedProminent`
buttons, with no manual horizontal padding inside either button label. The
existing identifiers and action transitions are preserved:

- `onboarding.helper.notNow` → `.allSet`
- `onboarding.helper.turnOn` → `.approval`

This inspection confirms that the production correction follows the exact
retrieved component hierarchy and variants. Native rendering and visual limits
remain as documented in [README.md](README.md) and [visual-review.json](visual-review.json).
