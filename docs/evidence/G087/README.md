# G087 — menu-bar Settings action fallback

## Fix

The visible production menu-bar item is a public AppKit fallback on this host.
Its Settings action no longer relies on `showSettingsWindow:` reporting a
materialised SwiftUI Settings scene. It closes the native status popover and
opens the shared `SettingsRootView` in a native `Watt? Settings` window at the
existing 580-point settings width and 838-point content height.

## Verification

- Focused C05/J6.1 regression suite: **11 tests, 0 failures**.
- Release `xcodebuild build analyze`: **BUILD SUCCEEDED**, **ANALYZE SUCCEEDED**.
- Rebuilt release installed at `/Users/benranford/Desktop/Watt.app`.
- Native AX press on the live `Settings…` button returned success; the panel
  closed and AX reported a visible `Watt? Settings` window.
- The captured settings window showed the real SwiftUI `Form`/`Section` rows,
  native controls and native title-bar chrome; no replacement settings UI was
  introduced.
