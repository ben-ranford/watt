# G076 / J12.4 — leftover helper

Exact Figma: file `9DKDgUfEqidZdZQEVlQgLS`, frame `35:5746`, Alert `35:5900`.
`figma-context.json`, `figma-metadata.json`, `figma-variables.json` retain MCP text responses;
`figma-screenshot.json` retains the MCP screenshot URL response, downloaded to
`mcp-screenshot.png`. `reference.png` is the exact user-specified screenshot download,
verified by `reference.sha256`. No reconstructed reference pixels.

## Implementation
- `App/LeftoverHelperPresentation.swift`: informational NSAlert and scoped consent state.
- `Services/ScopedRemovalAdapter.swift`: verified owned inventory detects the helper from
  an installation ID distinct from the current reinstall; reconnect uses P02 authentication;
  removal uses only the existing helper scope, never uninstall or UI-supplied paths.
- `App/AppRouter.swift` / `App/WattApp.swift`: explicit adapter configuration and startup
  presentation boundary; close invalidates consent, termination closes the prompt.
- `App/J124FixtureLaunch.swift`: DEBUG-only `--watt-fixture J12.4/base`, in-memory effects
  and preferences only. Registry, Xcode project, F05 assertion and J124 tests updated.

Durable receipts precede removal. Retries reuse receipts; failed acknowledgement retries
persistence, not the effect. No unknown/pending/absent response means reconnect success.
Old/closed/cancelled responses cannot acknowledge completion. Default live dependencies
are fail-closed. The repository has no production OwnedRemovalDriver/installation manifest
provider: live reinstall detection, real helper mutation and downstream J12.5 continuation
are **not** end-to-end verified. The installer composition must supply trusted IDs, driver,
storage and completion routing. The fixture is not proof of these production effects.

## Reproduce
`bash docs/evidence/J12.4/verify.sh` uses `/Applications/Xcode.app/Contents/Developer`;
Debug build/analyze/build-for-testing, Release build/analyze and Release test-build attempt,
focused J12/F05/P02/P05/NativeStyling tests, then full Swift suite.
`bash docs/evidence/J12.4/capture.sh` launches and reaps only its fixture PID.
`bash docs/evidence/J12.4/static-check.sh` checks diff, project, checksum and Release symbols.
See `verification.json` and per-command logs/exit files for results. No independent linter
configuration exists; compiler/analyzer, native-style tests and static checks provide diagnostics.

## Native visual review
Captured and inspected `capture/native-window.png` against `reference.png`. The PID-owned
native NSAlert shows the exact title, description and stacked Reconnect/Remove Helper buttons.
Reconnect is blue/default; the secondary button is grey. No custom icon, fonts, glass, tint,
appearance or desktop chrome was supplied. AppKit chose a generic app icon on this build.
The native window is 260×252 points (520×504 captured pixels), versus Figma's 260×246.
The current desktop/material, icon rendering, line wrapping and text scale differ visibly.
Desktop placement is system context, not app-owned geometry. AX trust is false; Screen
Recording is preauthorized and capture succeeded. Live AX button activation was not verified.
No permission prompt, geometry override, pixel score or visual-pass claim was fabricated.
`score` and `pixel_diff` are null; visual parity remains unverified.

## Final verification run
- Full suite: **660 tests, 5 skipped, 0 failures**, `full-tests.exit=0`.
- Focused suite: **101 tests, 0 failures**, `focused-tests.exit=0`.
- Debug build/analyze/test-build: exit 0. Release app build/analyze: exit 0.
- Release test-build attempt: exit 65, existing module built without `-enable-testing`.
- Native capture and static/diff/project/checksum/Release-isolation checks: exit 0.
- Final run logs supersede earlier failed attempts. No commit or new worktree created.

## Fresh Figma and native evidence — 2026-09-23
- Figma MCP re-queried for exact frame `35:5746` with design context, metadata, variables and screenshot; screenshot pinned at `fresh-figma/reference-2026-09-23.png` with SHA-256 `78a2df9be1045781e5d8dde16d879b10bc42fbf608f6aaacb6dbacfda0d029d2`.
- Exact hierarchy, text, tokens and native boundary are recorded in `fresh-figma/context-2026-09-23.md`.
- `J12.4/base` was launched from the current Debug binary. Fresh AX evidence confirms the exact native dialog, title, description and enabled `Reconnect` / `Remove Helper` buttons.
- Fresh PID-owned capture is under `fresh-figma/live-capture-2026-09-23/`. It confirms the native dark NSAlert rendering, but no visual-pass or pixel-parity claim is made because native AppKit appearance and the light Figma reference differ (260 × 252 capture versus 260 × 246 Figma bounds).
- The fixture was reaped; the normal Desktop app remained running. No production helper was reconnected or removed.
