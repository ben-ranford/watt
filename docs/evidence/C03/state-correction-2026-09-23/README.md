# C03 state correction — 2026-09-23

The exact Figma node `22:1095` shows an enabled `Check for Updates…` row.
The earlier C03 DEBUG fixture constructed `AppRouter()` without an updater, so
AppKit correctly dimmed that row even though the reference state was enabled.

The fix is isolated to DEBUG C03 composition: the fixture injects the existing
in-memory `FakeUpdateService`, while normal production composition still uses
`AppRouter()` with no updater and remains fail-closed until a trusted P04
service is configured. No network, install, or OS update effect is performed.

## Verification

- Package `C03ContextMenuTests`: **9 passed, 0 failures**.
- Hosted `C03ContextMenuTests`: **9 passed, 0 failures**.
- Debug build + analyze: succeeded.
- Native fixture capture: two `NSPopupMenuWindow` surfaces at 230×187pt and
  190×141pt; parent highlighted, Delta checked, submenu idle.
- Direct native capture inspection confirms `Check for Updates…` is now enabled.

The captured surfaces remain native AppKit diagnostics, not a visual acceptance
claim. OS-owned menu material, font rasterization, separator insets, live
status-item placement, AX/VoiceOver and physical interaction remain open gates.
