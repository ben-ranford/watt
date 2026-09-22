# G073 / J12.1 — Settings uninstall

Implemented in existing worktree on `bug/G073-j121-settings-uninstall`; no commit.
Pre-existing unrelated work is preserved.

## Source and behavior
- `Features/Settings/Views/SettingsRootView.swift`: shared native General section,
  two preference Toggles, LabeledContent, destructive Uninstall… Button and Version.
  Production remains the full Settings Form; DEBUG fixture shows the General excerpt.
- `App/AppRouter.swift`: presentation-scoped, in-memory J12.2 intent. Opening it
  never calls cleanup, writes preferences, clears helper state or claims removal.
  Busy/duplicate/stale/closed requests fail closed; cancel permits retry.
  Existing native confirmation and explicit confirmed removal remain downstream.
- `App/J121FixtureLaunch.swift`, `App/WattApp.swift`: DEBUG-only isolated fixture,
  native Settings scene and existing status-item bridge, +42.1 W. Installed removal
  effects disabled in fixture. No replacement window, chrome, desktop or controls.
- Registry, Xcode project, DESIGN and SCREEN-BACKLOG updated.
- Six J121 tests cover selectors, scoped intent, duplicate/busy/stale rejection,
  retry, persistence safety, configured Settings route/status and native row order.
  F05 registry expectation and J73 Settings callsite assertion updated.

## Exact reference
Figma file `9DKDgUfEqidZdZQEVlQgLS`, frame `35:4360` (1000×720),
native window `35:4678` (540×271), status item `35:4675`.
`context.json`, `metadata.json`, `screenshot.json`, `variable_defs.json`
contain exact MCP text responses. `context.png` is the fresh MCP screenshot;
`reference.png` is the exact user-supplied screenshot asset, checked by
`reference.sha256`. Reference inspected; typography/control/color variables map
to native semantic styles, not custom hex-painted controls.

## Verification
Reproduce using `bash docs/evidence/J12.1/verify.sh` (bounded capture).
- Focused J12 / NativeStyling / P05: **46 tests passed**.
- Full `swift test`: **640 tests, 5 skipped, 0 failures**.
- Xcode Debug: **build, analyze, build-for-testing passed**.
- Release app: **build and analyze passed**; binary strings/symbol checks prove
  J121 fixture and fixture parser isolation.
- Release build-for-testing: **attempted, exit 65**. Existing Release test target
  cannot resolve a compatible/testable Watt module; not represented as a pass.
- Static/diff checks, project plist and reference checksum: **passed**.
The initial CLT invocation failed; rerunning with
`DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer` produced the results above.
The first full run exposed J73's exact callsite-string assertion; it was updated
for the added argument, with the prior relaunch/removal argument pair kept together.

## Native capture / remaining acceptance gaps
Capture **exit 1**, not a visual pass. The bounded launch produced no native Settings
observation file and no fixture PID-owned on-screen compositor windows.
AX trust was **false**; screen-capture preauthorization was **true**. No TCC prompt,
permission change, synthetic desktop, replacement window or offscreen rendering
was used to bypass the gate. The fixture process was terminated and reaped.
There is no native screenshot to inspect. Live button/keyboard interaction, status
item pixels and appearance/accessibility parity remain unverified.
`visual-review.json` and `verification.json` retain **score: null** and
**pixel_diff: null**, **visualPass: false**. Source/unit/build proof does not imply
pixel-level fidelity or live AX acceptance. See `capture/window.json` and logs.
