# G074 / J12.2 — Confirm uninstall

Implemented on existing worktree, branch `bug/G074-j122-confirm-uninstall`. No commit or new worktree.

Fresh MCP retrieval on 2026-09-23 is pinned in `fresh-figma/context-2026-09-23.md`, `fresh-figma/reference-2026-09-23.png` and `fresh-figma/live-ax-2026-09-23.log` (SHA-256 `1466b6e3c198db2ab44c628c4a899604f8f600e9e489e74c52c82723ae3d383c`).

## Implementation
- SettingsRootView reuses native SwiftUI alert, destructive Uninstall / Cancel roles and exact MCP message; OS owns keyboard/Escape, materials and chrome.
- AppRouter adds one-shot presentation/generation-scoped consent. Opening/canceling performs no cleanup; stale/duplicate/closed requests fail closed. In-flight removal prevents concurrent requests across reopening; fresh consent permits retry after failure.
- Uninstall completion does not rewrite deleted preferences; stale completion cannot update a reopened Settings presentation.
- DEBUG-only J12.2/base uses the existing native Settings scene/status-item bridge and in-memory preferences, disabling installed removal effects. Production retains complete Settings rows.
- Registry, Xcode sources, DESIGN.md and SCREEN-BACKLOG updated. J122ConfirmUninstallTests covers consent, cancel, retry, close, generations, concurrency and persistence. Existing J9.1/F05 source-contract assertions updated.

## Evidence
Exact Figma MCP context, metadata, screenshot response and variable definitions are saved here. `reference.png` is the user-specified asset; `screenshot.png` is the fresh MCP export. `reference.json` and `reference.sha256` preserve provenance/checksum. Reference image was visually inspected. SF Pro 13/16 and 11/14, semantic colors and liquid-glass metrics remain native-control references, not custom-painted chrome.

## Verification
- Focused J12 / NativeStyling / P05: **52 passed**.
- Full suite: **646 executed, 5 skipped, 0 failures**.
- Debug: **build, analyze, build-for-testing passed**.
- Release: **app build/analyze and fixture binary isolation passed**.
- Release build-for-testing: attempted, **exit 65**, existing incompatible Watt module dependency in test target.
- Static: diff whitespace, project plist, checksum and native-control/Release-isolation checks passed.

## Visual limitations
Capture attempted twice against the real fixture process; final capture **exit 1**. Screen capture is preauthorized, but AX trust is unavailable and no fixture-owned on-screen compositor windows were listed. No native screenshot, actual alert presentation or Return/Escape interaction is claimed. The fixture produced no native Settings identity record before timeout. No TCC permissions were requested or altered. Capture process was terminated and reaped (see capture/process-cleanup.log).
Visual pass is false; score and pixel_diff are **null**. No synthetic renderer or fake score was used. Runtime interaction and pixel parity require a trusted, visible GUI session. See verification.json and visual-review.json.

Fresh retrieval is recorded; the host still produced no PID-owned Settings/alert window, so live keyboard/button and visual comparison remain open.
