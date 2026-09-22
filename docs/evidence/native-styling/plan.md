# Native styling correction plan
Scope: shared controls, status panel and onboarding shell; retain existing scene/router,
model, persistence, fixture selectors and accessibility identifiers. No new stories.

1. Audit DESIGN.md and retained Figma contexts; distinguish native library appearance
   from explicit product values. Preserve 320pt panel, 480pt onboarding, 580pt settings
   widths, semantic text tokens and data; remove sampled wallpaper/material gradients,
   manual disabled/action colors, drawn separators and rounded window/card replicas.
2. Run current shared/picker/F05/router regression tests before edits. Add native
   control contracts and retain callback/unavailable-reading/navigation regressions.
3. Use Button roles/styles, radio-group Picker, LabeledContent, Section/Form, Divider
   and host-owned window chrome. Update shared gallery callers to real grouped Forms.
   No unnecessary NavigationStack/WindowGroup: existing scenes remain authoritative.
4. Compile an isolated app-owned native rendering host for light/dark panel, grouped
   settings, reading selection, action states and onboarding. Cache genuine NSHostingView
   drawing; inspect in-process accessibility semantics without AX/TCC permissions.
5. Run focused/full package and native tests, Debug/Release build/analyze, static checks;
   retain reference crops, raw native captures and honest comparisons/limitations.
No checkpoint; old visual approvals do not transfer to corrected native styling.

## Bounded review corrections — 2026-09-22
- Inspect retained Figma exports 25:787/27:1354 and fresh light/dark captures.
- Add source regressions first for one native focus-field label and section-footer
  notes; keep shell content, control states, callbacks and routing unchanged.
- Remove the redundant LabeledContent wrapper around the native TextField. Move
  the specimen menu-bar note into its Section footer. Convert SettingsRootView's
  shell composition to a grouped Form/Section without custom spacing or paint.
- Run focused regressions red/green, full package/hosted WattTests, Debug build,
  Release analyze and static checks. Recapture affected specimens plus the actual
  settings shell, preserve earlier evidence, and report runtime/visual limitations.
