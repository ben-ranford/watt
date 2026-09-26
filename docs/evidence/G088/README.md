# G088 — compact power table expansion

## Change

`StatusPanelModel` now reports intrinsic height for power-only panel states.
`StatusPanelView` keeps the native grouped `Form`/`Section`/`LabeledContent`
hierarchy, disables scrolling for that compact Form, and uses vertical
intrinsic sizing. Panels that include a component section retain their existing
bounded height and native scrolling behavior.

## Verification

All commands used the full Xcode toolchain:

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  swift test --filter 'J6[1-5]|J43PanelSystemDrawTests'
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  swift test
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  xcodebuild -project Watt.xcodeproj -scheme Watt -configuration Release \
  -destination 'platform=macOS' \
  -derivedDataPath /tmp/watt-g088-expand-power-table-release-20260926 \
  build analyze
git diff --check
```

Focused tests passed: 69 executed, 4 skipped, 0 failures. The full package
suite passed: 716 executed, 5 skipped, 0 failures. Release build and static
analysis passed.

## Live native popover

The rebuilt Release app was installed at `/Users/benranford/Desktop/Watt.app`
and left running. The real AppKit status item exposed the live native popover.
The current full-battery host sample rendered Charger input, System draw and
Battery together in the expanded panel; the panel content measured 320×291
points and the native popover measured 346×317 points. A screenshot is retained
at `/tmp/watt-g088-panel-crop.png` (692×634 pixels, 2×).

The native accessibility hierarchy exposed all three rows at y=172, 209 and
246 with the power region at 320×150 points. A downward wheel event over the
power region left all row positions unchanged, confirming the compact Form is
not scrollable while all rows remain visible.

The AX hierarchy still reports SwiftUI Form's underlying `AXScrollArea`; this
is an OS semantic wrapper, not a visible scrollbar or an enabled scrolling
interaction. No custom table or painted replacement was introduced.
