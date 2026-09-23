# Native macOS verification host (F01)

`Watt.xcodeproj` is a checked-in, dependency-free Xcode project with a shared
`Watt` scheme and native `Watt`, hosted `WattTests`, and `WattUITests` targets.
It references the same files in App, DesignSystem, Features, Models and Services
as Package.swift: no copied sources, second entry point, or package executable
linked into another executable. Add new Swift files to the appropriate Xcode
Sources phase; the package discovers them within its explicit source directories.
Resources/Assets.xcassets belongs to the app Resources phase. Its empty icon
placeholders are deliberately not selected as a shipping app icon.

## Non-privileged F01 capture (preferred in this environment)

```sh
./scripts/capture-native-panel.sh
```

Requires a logged-in graphical session and **already available** screen-recording
access. The helper uses `CGPreflightScreenCaptureAccess` and exits without prompting
if unavailable. It builds Debug with full Xcode, launches exactly one owned PID
with `--watt-capture-status-panel`, finds its uniquely titled layer-zero window
through CGWindowList, then runs `screencapture -x -o -l` for that window only.
It never captures the desktop, invokes AX APIs, or runs XCTest UI automation.
A fresh output directory holds PNG, window ownership/bounds, pixel dimensions,
scale, nonblank sampling, SHA-256 and logs. Exit/signal cleanup terminates and
waits for the exact app PID; existing Watt instances are not terminated.

The opt-in delegate is compiled only in Debug. Ordinary launches do not create
this window; Release has no capture delegate or launch argument. The existing
StatusPanelView renders its fixed charging fixture at 320 points in light/aqua
and en_US. Only this capture window has an inert Settings callback: it is a
rendering harness, not navigation evidence. Normal menu-bar/settings code is
unchanged. No hardware/service calls or preference writes are added.

Run hosted unit tests without the blocked UI target:

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild \
  -project Watt.xcodeproj -scheme Watt -configuration Debug \
  -destination 'platform=macOS' -derivedDataPath .build/xcode \
  test -only-testing:WattTests -parallel-testing-enabled NO
```

See [retained F01 evidence](evidence/f01/README.md). Accessibility claims remain
source-native/in-process semantics only, not a runtime AX dump or VoiceOver audit.
The experimental failing NativePanelCaptureTests is absent; do not restore it.

## UI-automation workflow (requires host trust; not used for F01 capture)

Use a logged-in, unlocked macOS graphical session, full Xcode, and OS-granted
UI automation/accessibility permission for the test runner. Do not bypass TCC or
change the global `xcode-select` setting. There is no iOS target or simulator.

```sh
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
xcodebuild -list -project Watt.xcodeproj
xcodebuild -project Watt.xcodeproj -scheme Watt -configuration Debug \
  -destination 'platform=macOS' -derivedDataPath .build/xcode build
open .build/xcode/Build/Products/Debug/Watt.app
# Or select Watt / My Mac in Xcode and Run.
# Quit a manually launched copy before running the harness.
./scripts/verify-native-host.sh
```

The bundled app has `LSUIElement=YES` (accessory/menu-bar utility, no Dock icon).
Click its power reading in the menu bar to open the existing fixture panel.
The script builds, runs both test targets, records toolchain/OS/display context,
and exports retained attachments from a fresh xcresult under `.build/native-host/`.
An explicit output directory may be supplied as the first argument; do not reuse
an existing result bundle. In Xcode the same attachments are in the Test report.
`NativeHostTests.testMenuBarPanelCapture` launches the real application, clicks
its status item, checks Settings/Quit controls and attaches the application
screenshot plus the XCTest accessibility hierarchy. It terminates its app after
capture. The existing charging fixture does not poll hardware or install helpers.

This is a host smoke capture, not a Figma comparison, VoiceOver audit or proof of
sensor behavior. Desktop context can vary; F05 must add per-story fixtures,
appearance control, app-content crops, scale calibration and comparison gates.
The hierarchy records element frames; the exported PNG retains pixel dimensions.
Do not crop desktop references to match without documenting the transform.
A locked session, missing automation permission, or hidden/crowded menu bar can
block the UI test even when compilation/unit tests pass; retain that failure.

### Current local verification state (2026-09-23)

- The opt-in physical P01 probe passed against the real host through
  `./scripts/probe-native-p01.sh`. It observed the host's current battery/source
  metadata and intentionally reported no watts; see
  `docs/evidence/P01/physical-host-probe-2026-09-23.log`.
- A local-only macOS 27 UTM guest was configured without an Apple ID and the
  ad-hoc signed Watt app was launched there. The native menu-bar item and its
  Settings/Quit actions were manually rendered with computer use; no
  notarization or production service was involved.
- The host XCTest runner built and launched the real app, but the current host
  run could not complete the status-item click. XCTest reported the item at
  `{{-1.0, 1157.0}, {48.5, 24.0}}` as not hittable, consistent with the current
  crowded/edge-clipped menu-bar compositor state. This is retained as a failed
  live-host smoke result, not treated as visual or accessibility sign-off.

To finish the host UI-test gate, authenticate the host Mac's System Settings
prompt once, then add the exact runner bundle produced by the build (for
example, `.build/xcode/Build/Products/Debug/WattUITests-Runner.app`) under
**System Settings → Privacy & Security → Device Control and Data Access**.
This is the macOS 27 TCC category for UI automation. Trust the test runner,
not the Watt app; no Apple ID, notarization or production account is needed.
Afterward rerun `scripts/verify-native-host.sh` from an unlocked session with a
non-crowded menu bar. If the status item remains edge-clipped, use a clean
graphical host/VM or hide unrelated menu-bar extras rather than weakening the
test or bypassing TCC.

## Production boundary

Minimum deployment target: macOS 13. Runtime validation on a newer macOS does
not prove minimum-version compatibility. `dev.watt.verification` and its test
suffixes are **local-only bundle identifiers**, not approved production identity.
All configurations use local ad-hoc signing (`CODE_SIGN_IDENTITY=-`), no team,
no provisioning profile, no notarization, and no invented entitlements.
Before distributing, owners must approve identifiers, Developer ID team/signing,
hardened runtime and reviewed entitlements, notarization/stapling, app artwork,
and helper/login-item packaging. This project intentionally provides none of
those production capabilities. Do not treat Archive as a shipping release.
