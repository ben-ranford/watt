# G039 / J2.4 — Settings waiting for approval

Status: **implementation verified; visual/live-system acceptance blocked**. No commit.
Exact source: Figma file 9DKDgUfEqidZdZQEVlQgLS, node 29:3926.
The exact get_design_context hierarchy was fetched during implementation, not inferred
from neighboring J2.3. Pinned reference URL, SHA-256 and bounds: reference.json.
The MCP asset hash differs from the older F00 export; neither is silently substituted.

## Exact hierarchy / ownership
- Native Watt? Settings window, Menu Bar section, Show / Delta picker.
- Helper section / Status: Waiting for approval…
- Subtitle: Turn on “Watt? Helper” in Login Items & Extensions.
- Helper row: native bordered-prominent Open System Settings.
- Separate macOS-owned notification: Background Items Added; message:
  “Watt? Helper” can run in the background. You can manage this in Login Items & Extensions.
  Watt does not draw this notification, desktop, permission prompt or approval success.

## Implementation / reviewer corrections
SettingsHelperRows reuses native Form/Section/LabeledContent/Picker/Button.
Pending copy replaces off-state privacy/footer and duplicate message.
AppRouter's existing SMAppService.openSystemSettingsLoginItems closure is unchanged.
Fixture J2.4/base uses an in-memory pending service and inert open-settings callback;
production with no verified helper fails closed. Escape cancels only Settings origin.
Closing via onDisappear detaches presentation authority with approvals.close(.settings),
preserving durable interest and invalidating local late replies.

Settings foreground refresh delivers authenticated connected evidence only for its
active token. Passive/cancelled/closed presentations cannot enable preferences.
The coordinator's optional origin-scoped connected delivery removes only the chosen
origin's token and retires the generation only once no tokens remain. Default global
delivery retains its existing behavior. Cross-origin tests prove Settings cannot
consume onboarding delivery, either order works, and delivery remains single-use.

## Verification (all final exit files = 0)
- swift test --filter 'J24SettingsApprovalTests|J23SettingsTurnOnTests|F05FixtureTests':
  48 passed, including 11 focused J2.4 tests.
- swift build: passed.
- swift test: 331 executed, 1 skipped, 0 failures.
- Host xcodebuild test -only-testing:WattTests -parallel-testing-enabled NO:
  319 executed, 1 skipped, 0 failures.
- Debug and Release xcodebuild build analyze: both passed.
- git diff --check: passed.
- Initial full-suite fixture allowlist failures were corrected; final logs are reruns.
- No separate lint tool is configured; compiler diagnostics, static analysis,
  native-styling regression tests and diff whitespace checks were used.

Commands use DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer,
project Watt.xcodeproj, scheme Watt, destination platform=macOS,
derivedDataPath .build/xcode. Package and host validation ran in parallel;
dependent builds/tests/capture ran sequentially.

## Native capture and visual-ralph verdict
Reproduction: bash docs/evidence/J2.4/capture.sh (fresh capture-final directory).
Captured the actual host application's PID-scoped native window, no desktop or
permission prompts: capture-final/native-window-10606.png. Screen capture was
preauthorized; AXTrusted is false. Exact window metadata is in window.json.
The host is dark; no forced appearance or fabricated light screenshot was added.
Reference is 1000x720, app crop 520x269; actual window is 520x288 (retina 1040x576).
compare.swift creates secondary localization evidence by resampling to 520x269;
that unequal-size/different-appearance diff is **not** an acceptance metric.

visual-review.json: **blocked, score null, visualPass false, storyDone false**.
Live OS notification, signed helper approval, AX/VoiceOver/keyboard interaction and
light-reference comparison are unverified. No successful real approval is claimed.

## Handoff
Keep G039/J2.4 blocked in the leader-owned plan until a signed-helper/AX-authorized
host supplies live approval, system notification and comparable visual evidence.
No worker changes to ultragoal ledger/state. Shared pre-existing work is preserved.
