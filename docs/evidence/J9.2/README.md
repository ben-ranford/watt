# G063 / J9.2 — Helper removed

Fresh MCP retrieval on 2026-09-23 is pinned in `fresh-figma/context-2026-09-23.md` and `fresh-figma/reference-2026-09-23.png` (SHA-256 `9959442e28b7db0732fd6ce189114f7ddb3486e79342328244bd23ce4b9bb904`).

Reference: Figma file `9DKDgUfEqidZdZQEVlQgLS`, exact node `32:5844`.
Fresh MCP design context, metadata and screenshot response are retained alongside
the retrieved PNG and user-supplied PNG. Both PNGs have identical SHA-256 hashes
in `reference.sha256`; no screenshot was reconstructed or retouched.
Frame: 1000×720; native Settings reference: 520×269 at (240,236);
grouped content: 480×198 at (20,20). See `reference.json`.

## Implementation

- Shared Settings grouped Form renders Menu Bar Show/Delta and Component Readings
  Status/Off + bordered Turn On… after verified absence.
- `resetAfterVerifiedRemoval` owns success presentation. J9.1 removal uses the same
  route; cancellation/failure/pending work cannot claim removal success.
- Component selections, symbol, precision and other preferences survive removal.
  The shared status label remains; fixture presents +42.1 W with the system symbol.
- Turn On uses the existing helper approval coordinator, not direct preference
  toggling. Registration acknowledgement is not an authenticated connection.
- Only the native Debug target selects `--watt-fixture J9.2/base`.
  SwiftPM rejects it; Release contains no J9.2 fixture implementation/strings.
- No custom desktop, window, materials, traffic lights, alert or control drawing.
  System layout is allowed to differ across macOS versions.
- Explicit hierarchy says “Component Readings”; fresh screenshot says “Helper”.
  Explicit user hierarchy takes precedence. This discrepancy is not hidden.

## Reproduction

Run from the implementation worktree with
`DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer`:

```sh
swift test --filter 'J9[12]'
swift test
xcodebuild -project Watt.xcodeproj -scheme Watt -destination 'platform=macOS' -configuration Debug build analyze
xcodebuild -project Watt.xcodeproj -scheme Watt -destination 'platform=macOS' -configuration Release -derivedDataPath build/J92-release build analyze
xcodebuild -project Watt.xcodeproj -scheme Watt -destination 'platform=macOS' -configuration Debug -derivedDataPath build/J92-native-tests -only-testing:WattTests test
bash docs/evidence/J9.2/capture.sh
```

The capture script creates a fresh `capture` directory (it does not overwrite an
existing attempt). Archive an earlier attempt before rerunning. It launches only
the isolated fixture process, validates PID/AX/window identity, and reaps its PID.
It never requests TCC permissions or draws a replacement window.

## Evidence / limits

11 focused tests passed (5 J9.2, 6 J9.1). Full package suite: 572 tests, 5 skipped,
0 failures. Debug and Release build/analyze succeeded. Project plist, shell syntax,
reference hashes, diff whitespace and Release fixture isolation checks passed.
The initial package command used the Command Line Tools toolchain and failed
because SwiftUI macros were missing; rerunning with full Xcode succeeded.

Capture: AXTrusted=false, screen capture preauthorized=true, no fixture PID-owned
compositor windows. Native visual comparison and live interaction are unverified.
No pixel diff, similarity score or visual pass is fabricated. See `verification.json`
for final native runner status and `capture/window.json` for direct evidence.

Fresh native AX probe on 2026-09-23 is retained at `fresh-figma/live-ax-2026-09-23.log`; helper-removal Settings visuals remain bounded by the host compositor/AX limitation, so visual acceptance is not claimed.
