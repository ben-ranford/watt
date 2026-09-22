# G042 / J3.2 — Helper switched off later in System Settings

## Exact source
Figma file `9DKDgUfEqidZdZQEVlQgLS`, node `29:5439`. Retrieved get_design_context before implementation. `reference.json` pins the exact supplied 1000×720 dark asset URL and downloaded SHA-256; `figma-reference.png` is the unmodified asset.

The selected status item is “+42.1 W”. Native panel: Charger input 65.0 W, System draw 22.9 W, Battery +42.1 W; filled warning triangle → native SF Symbol `exclamationmark.triangle.fill`; “Helper is off”; “Showing Delta until it’s back.”; bordered “Fix…”; borderless “Settings…” and “Quit Watt?”.

## Implementation
- Existing StatusPanelView/MenuBarRootView/MenuBarExtra and status-item bridge only. Native chrome/material, system typography, existing 320×347 compact panel. No custom-painted panel, glyph, desktop, selected item, or OS approval.
- SettingsHelperSetup remembers verified connection and publishes runtime loss on disconnect/revoked or pending approval/verified absence. Initial setup failure remains J3.1, not J3.2. Persistence errors cannot restore component visibility. Attempt IDs and adapter generations reject late replies. Saved component intent survives runtime denial. Authenticated external reconnect alone does not clear Delta: a validated, fresh helper-source component sample timestamped after authentication is required; fixture/system/old/stale/unavailable samples cannot clear it.
- Menu label and secondary menu use an effective Delta override while preserving saved display choice. Components are suppressed even if stale component samples remain. Independent power rows retain the existing capability/source/freshness policy (stale power is explicitly identified by the existing accessibility summary; unavailable values are em dashes).
- Fix… reuses Settings navigation. Existing native approval action remains SMAppService.openSystemSettingsLoginItems; opening it never implies approval.
- DEBUG J3.2/base uses in-memory preferences, fixed charging telemetry, and authenticated fixture driver/transport followed by disconnect. No live registration or system changes.

## Validation
Commands and raw logs/exit codes are alongside this file:
- `swift test --filter J32`: PASS, 8 focused tests.
- `swift test`: PASS, 357 tests, 1 skipped, 0 failures.
- `swift build`: PASS.
- `xcodebuild -project Watt.xcodeproj -scheme Watt -configuration Debug|Release -destination 'platform=macOS' -derivedDataPath .build/xcode build analyze`: PASS for both configurations.
- Full host `xcodebuild ... test -parallel-testing-enabled NO -test-timeouts-enabled YES -maximum-test-execution-time-allowance 60` attempted: unit tests pass; NativeHostTests.testMenuBarPanelCapture fails (native status item not hittable), 2 UI tests skipped. Overall exit 65; native UI result is not waived.
- `git diff --check`: PASS. No separate lint configuration; Swift compiler plus Xcode analyzer provide diagnostics.

## Native capture / visual-ralph — BLOCKED, not visually complete
After Debug build: `bash docs/evidence/J3.2/capture.sh`. Uses the actual host with `--watt-fixture J3.2/base --watt-j32-capture-directory <output>`, darkAqua confined to DEBUG fixture, existing native status-item opener. Use a fresh output directory for another run; the script rejects capture-final reuse.

Capture attempted without requesting new permissions. `capture-final/window.json`: screenCapturePreauthorized=true, AXTrusted=false, no PID-owned compositor windows. Thus no selected-status-item/panel capture, app-owned crop, overlay, or numeric pixel score exists. `visual-review.json` and `pixel-diff.json` fail closed with null scores. The Figma screenshot is not passed off as an app capture. Reference is 1000×720; panel is 320×347; desktop/menu bar ownership remains macOS.

**P01 production blocker remains open:** the default app now starts with unavailable telemetry instead of fabricated preview watts; production provider composition/polling is not implemented by J3.2. DEBUG fixture telemetry is unchanged. **Live helper-loss detection is blocked:** no real production helper monitor is installed; loss/recovery is proven only with injected authenticated drivers. Live signed helper disconnect/revocation, System Settings interaction, and AX/VoiceOver remain unverified. J3.2 is not production-ready; fixture authentication and unit tests do not prove real privileged IPC or OS approval. No commit; unrelated shared-worktree edits retained.
