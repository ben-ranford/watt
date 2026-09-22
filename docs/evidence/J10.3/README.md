# J10.3 — Update available (G067)

Exact Figma file `9DKDgUfEqidZdZQEVlQgLS`, frame `34:4695`, window `34:4849`.
Fresh MCP context, metadata, screenshot response and both retrieved/supplied PNGs
are retained with SHA256 hashes. The PNGs are identical. Rendered PNG headings
use “Watt? 1.1 is out” / “What changed”; explicit requested copy and metadata names
take precedence. The older F00 fixture reference remains historical, not fresh proof.

## Implementation
- Native light Software Update window, existing app icon, semantic SF typography,
  grouped Form rows, initially-off checkbox, native buttons and blue primary action.
- Checking transitions to available in the same scene. Local dismissal is persisted
  before Skip/Remind closes; failed writes retain the offer and allow retry.
- Version/generation-scoped intents hand off to later stories. Install does not
  download or install; it retains the offer and displays the unavailable boundary.
  Skip is not yet a durable skip list; Later is not a scheduled reminder. Automatic
  updates is a preference intent, not persisted policy or install consent.
- Retained transaction receipts cannot be overwritten by an offer or its actions.
  Restored offers require a fresh trusted check. No production updater is defaulted.
- Exact Debug `J10.3/base` injects FakeUpdateService only; SwiftPM launch is closed
  and Release fixture symbols are absent. No dependency or commit added.

## Verification
See `verification.json`, logs and exit files.
- Focused J101/J102/J103: **20 tests, 0 failures** (7/6/7).
- Full package: **598 tests, 5 skipped, 0 failures**.
- Debug: build, analyze, build-for-testing passed.
- Release: build and analyze passed; build-for-testing **failed (65)** on the existing
  incompatible `Watt` module import in the test target, first J83OpeningSettingsTests:7.
- Static native-control/copy/effect checks, project plist, hashes, whitespace and
  Release fixture-symbol checks passed. No native XCTest execution is claimed.
- Existing skips: four AX-dependent power-row checks and opt-in physical telemetry.
  Build warnings include AppIntents extraction, XCTest minimum OS and SwiftPM
  unhandled cumulative build artifacts.

## Honest capture boundary
`capture.sh` launched the final Debug fixture, observed its PID-owned **520×366**
Software Update window and cleaned up the exact PID. Figma specifies 520×365;
the title bar belongs to macOS, not a one-point custom chrome recreation.
Screen Recording was preauthorized; Accessibility was **not**. Capture refused to
bypass that gate or prompt. There is no comparable native PNG, verified live button
interaction, clipping proof, pixel diff or visual score. `visualPass` is false;
`score` and `pixel_diff` are null. Initial capture is retained separately.

Cumulative edits were preserved in the existing worktree. The existing branch was
renamed from `bug/G066-j102-checking` to `bug/G067-j103-update-available` to follow the
required issue naming convention; no new worktree, branch fork or commit was made.
