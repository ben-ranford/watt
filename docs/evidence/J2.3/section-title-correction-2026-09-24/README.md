# J2.3 exact heading correction — 2026-09-24

- Figma file: `9DKDgUfEqidZdZQEVlQgLS`
- Figma node: `29:3270` (`Settings`, window `29:3424`)
- Correction: exact Figma MCP context shows the excerpt section heading is
  `Helper`; the full Settings screen continues to use `Component Readings`.
- Implementation: `SettingsHelperRows` receives `sectionTitle`; J2.3/J2.4
  passes `Helper`, while the full screen passes `Component Readings`.
- Controls remain native SwiftUI/macOS grouped `Form`, menu `Picker`, labels and
  bordered-prominent `Button`.
- Build: Debug Xcode macOS build passed using derived data at
  `/tmp/watt-g086-j23-build-2`.
- Tests: `J23SettingsTurnOnTests`, 15 passed, 0 failures.
- Capture: native light fixture window, 520×288 points at 2× Retina.
- Comparison: RGB MAE `12.515001780626781`; fraction over threshold 16:
  `0.095880074786324793`.

This is durable correction evidence only. The story remains incomplete: recorded
qualitative visual score is 82/100, native spacing/titlebar metrics still differ,
the footer is below the excerpt viewport, AX is untrusted, and the production
signed/authenticated helper transport is not composed.
