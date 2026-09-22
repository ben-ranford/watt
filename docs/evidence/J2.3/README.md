# G038 / J2.3 — Settings: Turn On (excerpt)

**Implemented and tested; not story-done.** No commit created. Shared worktree and
branch retained: `swiftui-implementation`, `bug/G038-j23-settings-turn-on`.

## Exact reference

- Figma file `9DKDgUfEqidZdZQEVlQgLS`, node `29:3270`; Settings window `29:3424`.
- [Exact frame](https://www.figma.com/design/9DKDgUfEqidZdZQEVlQgLS/Watt-?node-id=29-3270).
- [Task-supplied Figma asset](https://www.figma.com/api/mcp/asset/978e075a-85da-4011-a401-4c5ce504c3cb.png)
  pinned as `figma-reference.png`, 1000×720; SHA-256/provenance in `reference.json`.
- Compare only native window rectangle `(240,226,520,288)`, not desktop wallpaper.
- Exact design context was supplied by the leader with Swift/SwiftUI hierarchy.
  The current asset differs in hash from historical F00 export; neither was silently substituted.

## Implementation

`SettingsRootView` retains full production Settings and exposes its shared native
Show Picker / Helper rows as a DEBUG fixture excerpt. Exact status subtitle remains
“Reading CPU, GPU, display and the rest.” even while value is Off. Helper privacy copy,
Turn On… bordered-prominent button and the approval footer are shared, not painted.

`SettingsHelperSetup` uses the existing `HelperApprovalStore` and `HelperService`
boundary (which accepts `HelperLifecycleAdapter`). AppRouter owns its presentation
instance. It starts notDetermined, disables duplicate requests during loading,
preserves denied/requiresApproval, and reconciles before every retry. It does not
invent Login Items approval or change onboarding. A fresh connected reconciliation
and eligible settings token are required to enable component preferences. Cancel
withdraws settings interest only and rejects late callbacks. Verified removal resets
the local connected presentation. Open System Settings invokes the native
`SMAppService.openSystemSettingsLoginItems()` through the existing router seam;
the API was checked in the installed official SDK header `SMAppService.h:273–283`.

**Production blocker:** P02 intentionally has no default signed lifecycle driver or
authenticated transport composition. The default setup service is therefore absent;
Turn On presents a retryable verification failure, never fake success. Inject the
real service and shared approval store at composition before enabling real helpers.
No privileged installation, user permission request or helper removal was performed.

## Verification

Use `export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer`.

| Command | Result / evidence |
| --- | --- |
| `swift test --filter J23SettingsTurnOnTests` | 9 passed; `focused-tests.log` |
| `swift test` | 314 executed, 1 skipped, 0 failures; `package-tests.log` |
| `swift build` | passed; `package-build.log` |
| `xcodebuild -project Watt.xcodeproj -scheme Watt -configuration Debug -destination 'platform=macOS' -derivedDataPath .build/xcode build analyze` | passed; `host-Debug.log` |
| Same, `-configuration Release` | passed; `host-Release.log` |
| Debug `xcodebuild … test -only-testing:WattTests -parallel-testing-enabled NO` | 302 executed, 1 skipped, 0 failures; `host-tests.log` |
| `git diff --check` | passed; `diff-check.log` |

The first package preflight used CommandLineTools and failed on unavailable
SwiftUIMacros; rerunning with the installed full Xcode toolchain resolved it. The
original failure is retained in `preflight-tests.log`. Build warnings are the existing
AppIntents metadata-extraction warning (no AppIntents dependency); no new dependency
was added. Swift compilation/typechecking and Xcode static analysis provide the
repository's available diagnostics; no separate lint configuration was introduced.
The existing skipped test and hosted/package suite-count difference remain visible
in raw logs rather than being presented as universal UI coverage.

## Visual Ralph evidence

1. `visual-review-before.json`: initial missing Turn On affordance, no capture yet.
2. `capture-iteration-1/`: real inherited-dark window; score 72, needs_iteration in
   `visual-review-iteration-1.json`. No production appearance override was added.
3. `capture-final/`: real light DEBUG fixture, native window 520×288 points captured
   at Retina 1040×576 pixels. Screen Recording preauthorized, AX untrusted.
4. `visual-review.json`: qualitative **82/100, needs_iteration**. Not a visual pass.
5. `reference-window.png`, `actual-window-1x.png`, `pixel-diff.png` and
   `pixel-diff.json`: secondary pixel comparison, normalized only for Retina scale.
   RGB MAE 12.515/255; 9.588% of pixels differ by >16 in at least one channel.
   These metrics do not substitute for visual review.

Capture succeeded; no compositor/TCC capture blocker or null score is invented.
Remaining native differences: larger grouped-form spacing puts the approval footer
below the fixed excerpt viewport, native titlebar metrics differ, and some row/header
insets differ. Exact copy/control hierarchy is present but **visual parity is not
accepted**. AX/VoiceOver and live button interaction are not verified.

Reproduce on a graphical host (capture script refuses stale output directories):

```sh
bash docs/evidence/J2.3/capture.sh
xcrun swift docs/evidence/J2.3/compare.swift "$PWD/docs/evidence/J2.3" \
  "$PWD/docs/evidence/J2.3/capture-final/native-window-<id>.png"
```

## Next handoff

1. Leader/J2.4: compose the signed, authenticated HelperLifecycleAdapter and shared
   approval store, including cross-origin delivery and real approval notifications.
2. Native visual review: reconcile reference's compressed form layout with native
   macOS metrics without custom chrome; rerun capture/diff until score ≥90.
3. On an AX-authorized host: exercise keyboard, VoiceOver, Turn On, denial, cancellation
   and retry end to end. Keep G038 blocked until missing acceptance proof is obtained.

## P1 verifier correction — verified availability only

Changes: `Features/Settings/Views/SettingsRootView.swift`,
`Services/PowerReadingStore.swift`, `Tests/WattTests/J23SettingsTurnOnTests.swift`.
Removed preview/persisted-preference inference from Settings. Status and Remove now
use the same verified setup predicate. LifecycleAdapter publishes actual lifecycle
state; disconnect/revocation invalidates connected presentation immediately. Removing
or replacing composition clears proof and invalidates late async results. Read-only
refresh occurs on appearance/activation and before helper removal, never registering
or approving anything. Query-only injected services cannot supply push disconnects;
they are revalidated at those boundaries. Persisted preferences remain intent only.

Six added regressions cover preview+opt-in with no service, composition replacement,
query-only disconnect refresh, late reply after composition removal, actual adapter
disconnect/revocation, and late authenticated reply after adapter disconnect.
Corrective logs use `p1-` prefixes, preserving original evidence:
- Focused J2.3 + P02 lifecycle: 28 passed (15 J2.3, 13 lifecycle).
- Full package: 320 executed, 1 skipped, zero failures.
- Package build passed; hosted results recorded in `p1-host-*.log` and `.exit` files.
- No new capture loop. Existing visual score **82, needs_iteration**, remains blocking;
  retained screenshots predate this state-authority correction. Story is not complete.
