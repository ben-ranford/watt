# G060 / J8.2 — Readings resume automatically (no alert)

Implemented in the cumulative worktree on `bug/G060-j82-readings-resume`. No
commit was created and prior worktree changes were preserved.

## Exact Figma reference

- File `9DKDgUfEqidZdZQEVlQgLS`, [node 32:4456](https://www.figma.com/design/9DKDgUfEqidZdZQEVlQgLS/Watt-?node-id=32-4456).
- Story frame: **8.2 Readings resume automatically (no alert)**; 1000 × 220.
- Supplied reference URL: `https://www.figma.com/api/mcp/asset/ff26f087-6b64-469e-ae62-515e6ea75f8c.png`.
- The supplied asset URL returned HTTP 404 when evidence was collected. The live
  Figma MCP screenshot response and its SHA-256 are retained in
  [`figma-screenshot.json`](figma-screenshot.json); no substitute image or
  visual score is claimed.
- Figma metadata is retained in [`figma-hierarchy.xml`](figma-hierarchy.xml),
  [`figma-context.json`](figma-context.json), and [`reference.json`](reference.json).

The frame is a dark system desktop with hidden Dock. Its right-aligned native
status anchor `32:4574` contains Watt? Status Item `32:4572`, rendered as the
normal SF Pro Body/Emphasized 13/16 semibold item with the SF Symbol and
`+42.1 W`. There is no alert, panel, wallpaper renderer, gradient, custom
status-item background, or other app-owned desktop chrome.

## Implementation

Recovery uses the existing `PowerReadingStore` generation/validation path:

`wake → invalidate → shared refresh → accept fresh sample → published status label`

The new `J82FixtureLaunch` starts with `.unavailable`, resumes via
`PowerReadingStore.refresh()` using deterministic fixture telemetry, preserves
the existing `WattDisplayMode`, and observes the real `MenuBarExtra` status
button. It never opens a panel or alert and does not allocate a replacement
window or status item. SF Symbols, typography and menu-bar materials remain
system-owned.

## Evidence boundary

The exact Debug fixture was built and its focused native tests were run. The
native capture attempt is in [`capture/`](capture/) and
[`visual-review.json`](visual-review.json). If AX, compositor ownership or TCC
preflight is unavailable, the capture is recorded as blocked with null score
and pixel diff; the fixture PID is still terminated and reaped.

The default CommandLineTools `swift test` invocation is blocked by the
pre-existing `SwiftUIMacros.StateMacro` component-gallery plugin failure. With
Xcode selected via `DEVELOPER_DIR`, the full package suite passed (555 tests,
5 skipped). Native Xcode verification and the host capture gate are recorded
in [`verification.json`](verification.json).
