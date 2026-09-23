# G031 — J1.4 Waiting for approval

## Fresh evidence — 2026-09-23

- [Current Figma context](current-figma-context-2026-09-23.md)
- [Fresh Debug build/analyze](fresh-build-analyze-2026-09-23.log)
- [Fresh package tests](fresh-package-focused-2026-09-23.log)
- [Fresh native tests](fresh-native-focused-2026-09-23.log)
- [Fresh capture](fresh-capture-2026-09-23.log)

The exact parent frame was re-retrieved through Figma MCP. The implementation
uses the native waiting window and excludes the system-owned notification. The
fresh compositor capture is authoritative for visual inspection; the direct
`NSView.cacheDisplay` PNG is retained as a host-specific transparent/black
capture artifact rather than used to claim fidelity.

- Frame `28:1206`; window `28:1521` (480×224 at 260,258); content
  `28:1535`; spinner `28:1537`; system notification `28:1584`.
- `WaitingForApprovalView` is selected by the existing `.approval` checkpoint.
  Native indeterminate `ProgressView()`, title “One switch in System Settings”,
  body “Turn on “Watt? Helper” in Login Items & Extensions. This window moves on by itself.”, bordered
  Cancel, borderedProminent/default Open System Settings. No painted spinner,
  simulated approval, timer, or fake notification. Existing native style retained.
- Actions dispatch through injectable AppRouter adapter callbacks, guarded against
  stale checkpoints. They do not grant approval, mark completion, or invent J3.1.
  **Integration limit:** callbacks default to no effects, matching the existing
  router boundary. Installed-service composition must supply cancellation and
  System Settings actions. No live helper registration or OS effect is claimed.
- Debug `J1.4/base` fixture: fresh in-memory preferences, fixed telemetry,
  native aqua window, en_US, no live services. Other J1.4 lifecycle variants
  explicitly reject rendering rather than falsely showing the base state.
- System notification is **unavailable under safe app-owned capture/TCC**.
  It is system-owned and excluded, not recreated. No prompt or permission bypass.
- Focused tests cover exact copy, native controls, fixture gating, action dispatch,
  stale-action guards, unchanged approval state and native window construction.
  Exact Figma MCP context and native styling are recorded in the fresh evidence
  files. No live AX audit or whole-frame visual approval is claimed.

## Verification — correction, 2026-09-22
- `focused-tests.log` / `focused-tests.exit`: 2 J14 tests, 0 failures. Tests cover
  exact title/body, native controls, action guards, and 480×224 window sizing.
- `capture-build.log` / `capture-build.exit`: Debug BUILD SUCCEEDED, required to
  recapture the corrected app rather than a stale binary.
- `capture-run.log` / `capture-run.exit`, `window-capture.log`: capture succeeded.
  `actual-content.png` is 480×224; `native-window.png` is 960×448 at 2×.
  `capture.json` records the exact rendered copy and 480×224 content bounds.
- `native-content.png` is a crop of the app-owned native compositor window below
  the 32-point titlebar, used for content comparison without recreating chrome.
- The direct `actual-content.png` cache-display artifact is transparent/black on
  this host; it is not used as visual acceptance evidence.
- Native window capture visually inspected: title, complete two-line body,
  indeterminate spinner, Cancel and Open System Settings are visible, unclipped.
  Native control/font/chrome differences remain; no pixel-identical parity claim.
- The native titlebar contributes 32 points on this host; the SwiftUI content is
  192 points high. The regression test locks the resulting 224-point window.
- The system-owned notification remains unavailable under safe app-owned
  capture/TCC; it is excluded, not fabricated.
- Per the narrowed request, full tests, Release, analyze and broad static checks
  were not rerun. Fresh focused package/native tests and Debug build/analyze are
  recorded above; existing full-suite and Release logs remain historical evidence.

```sh
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
xcrun swift test --scratch-path /tmp/watt-g031-swift --filter J14ApprovalTests
xcodebuild -project Watt.xcodeproj -scheme Watt -configuration Debug -derivedDataPath /tmp/watt-g031-debug build
bash docs/evidence/J1.4/capture.sh
```

## Independent visual-ralph result — 2026-09-22

- **App-owned waiting window: 92/100 — PASS.** This records the independent
  visual-ralph result supplied in the task, not a new review or implementation
  self-approval. The structured result is in `visual-review.json`.
- Exact window geometry: `native-window.png` is 960×448 pixels at 2×,
  normalized to **480×224 points**, matching reference window `28:1521`
  at (260,258) in `figma-frame.png`. `native-content.png` is the app-owned
  content crop; the native-window capture is the evidence for window chrome.
- Residual native button, traffic-light, spinner and surface differences remain.
  PASS is a visual-only result, not pixel-identical parity or a calibrated
  pixel-diff score.
- **Excluded:** the system Notification Center card (`28:1584`) is system-owned
  and unverifiable under safe app-owned capture/TCC. It is not recreated,
  scored or covered by this PASS; no whole-frame approval is claimed.
- No live AX interaction, VoiceOver audit or TCC verification is claimed.
  No permission prompt or TCC bypass is claimed. Visual PASS is not
  accessibility sign-off or approval of an overall gate including AX/TCC.
- `capture.json` and `window.json` remain unchanged capture-time metadata.
  Their `visualPass: false` and outstanding-review wording do not record the
  later independent visual-only verdict; this section and `visual-review.json`
  record that result without closing the separate AX/TCC gaps.

Fresh verification reran the focused package/native tests, Debug build/analyze
and the native capture. The system Notification Center card remains excluded by
the safe app-owned capture boundary; no permission prompt, TCC bypass, live
approval, AX/VoiceOver audit or whole-frame visual approval is claimed.
