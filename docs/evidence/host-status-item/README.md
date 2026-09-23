# Native status-item host-placement probe

This is a host diagnostic, not product UI. It checks whether the current macOS
host places a minimal public AppKit `NSStatusItem` correctly before changing Watt
code or introducing non-native menu-bar chrome.

## Reproduction

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  xcrun --sdk macosx swiftc -framework AppKit probe.swift -o /tmp/status-probe
/tmp/status-probe &
PID=$!
sleep 2
/tmp/axprobe
/tmp/axstatus "$PID"
/tmp/axstatuspos "$PID"
kill -TERM "$PID" 2>/dev/null || true
```

## Result — 2026-09-23 UTC

On macOS 27.0 (26A428), with Xcode 27.0 (27A266a), the shell Accessibility probe
returned `true`. The minimal AppKit process registered a native `AXMenuBarItem`
with title `PROBE` and label `probe status item`, but its native frame was
`x=-1, y=1157, width=65, height=24` on the `1800×1169` main display.

Watt's live J4.3/J5.1/J5.2 fixtures show the same left-edge placement (`x=-1`),
while the normal fallback status item reports `x=7`. This independent reproduction
means the placement is a host menu-bar/compositor behavior, not evidence that
Watt's `NSStatusItem` registration or label implementation is missing.

No custom window, fake menu bar, private API or bitmap replacement should be added
to hide this host limitation. Comparable compositor pixels and live status-item
hit-testing remain open acceptance gates until a host with correct native placement
is available.
