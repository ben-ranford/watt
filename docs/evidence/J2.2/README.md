# G037 / J2.2 — Panel, component readings off

**Native implemented; visual verdict blocked. No commit.**

## Exact source

`reference.json` records exact Figma frame **29:2456**, hierarchy, export URL, bounds
and SHA-256. `figma-reference.png` is the supplied exact export (1000×720), verified
against the pinned fixture hash. Figma `get_design_context` confirmed:

- Selected status item **+42.1 W**; panel **Charging**, **+42.1 W**,
  **64% · full in about 38 min**.
- Power: **Charger input 65.0 W**, **System draw 22.9 W**, **Battery +42.1 W**.
- Components: **Off**, **Turn on the helper to see where the power goes.**,
  native bordered **Turn On…**. Native borderless **Settings…**, **Quit Watt?**.
- SF Pro semantic Body/Headline/Large Title/Subheadline; native Form/Section and
  MenuBarExtra chrome, not painted Figma/macOS decoration.

## Implementation and boundaries

StatusPanelView now accepts `componentReadingsEnabled`; MenuBarRootView observes
PreferencesStore. Disabled readings hide even available cached components, show Off,
and use the reference 320×347 panel size. Enabled/unavailable behavior and the existing
320×473 live panel are preserved. Turn On… opens Settings using the existing callback,
without altering preferences, enabling a helper, or inventing approval success.

**Downstream dependency:** Settings currently has status/removal but no helper-enable
setup affordance. J2.3 must implement that flow separately; J2.2's setup navigation is
therefore a functional dead end beyond arrival at Settings. No J2.3 completion claim.

Review corrections: Quit is an ordinary native Button. Production Settings/onboarding/
coach mark no longer force light/Aqua. Shared settingsWidth/onboardingWidth/xs tokens
replace production 580/480/4 literals. Verification hosts retain deterministic appearance.

## Fresh verification (2026-09-22)

All logs and exit codes are in this directory:

| Check | Result |
|---|---|
| `swift build` | pass |
| `swift test --filter 'J22ComponentsOffTests\|J18LivePanelTests\|J17CoachMarkTests\|NativeStylingTests\|C05SettingsTests'` | 29 passed |
| `swift test` | 305 executed, 1 skipped, 0 failures |
| Hosted `xcodebuild … test -only-testing:WattTests -parallel-testing-enabled NO` | 293 executed, 1 skipped, 0 failures; all 5 J2.2 tests passed |
| Debug + Release `xcodebuild … build analyze` | both passed |
| `git diff --check` | pass |

Xcode arguments: `-project Watt.xcodeproj -scheme Watt -destination 'platform=macOS'
-derivedDataPath .build/xcode -configuration Debug` (or Release).
`DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer`.
No SwiftLint executable/configuration is available; compiler checks, native-style
regression tests, Xcode analysis and whitespace checks provide bounded static checks.
Existing package unhandled-file and missing-AppIntents metadata warnings remain.
Source-contract tests do not prove AX traversal, actual button clicks, or visual parity.

## Capture / visual-ralph contract

Pre-edit verdict: `visual-review-before.json`. Final: `visual-review.json`:
**score null, verdict blocked, category_match unknown, visualPass false, storyDone false**.
No actual image means no differences assessment or secondary pixel diff is possible.

Reproduction after building Debug:

```sh
bash docs/evidence/J2.2/capture.sh
```

The script refuses an existing `capture-final` directory to prevent stale evidence.
Use a fresh evidence directory on a rerun. Launch:
`Watt --watt-fixture J2.2/base --watt-j22-capture-directory <fresh-directory>`.
Fixture state is isolated in-memory, fixed charging data, completed livePanel,
components disabled, light/Aqua, 320×347 app content. The in-app hook only attempts
cacheDisplay after attachment to the real MenuBarExtra. The compositor fallback
only enumerates/captures windows belonging to that exact process, never the desktop.
Native macOS is the target; an iOS simulator is not a valid substitute.

Fresh attempt: process remained running, no app content PNG appeared;
`capture-final/window.json` shows **zero owned on-screen windows**, screen recording
**preauthorized**, AX **untrusted**. `window-capture.log` records exit 1: no capturable
app-owned compositor window. No TCC prompt, AX manipulation, synthesized wallpaper,
replacement status item, or fake panel was used. The preflight itself passed;
do not misreport this as denied screen-recording permission.

## Handoff

1. Review native implementation and the J2.3 setup dependency separately.
2. On an authorized graphical macOS host, capture the real panel and selected status
   item, exercise Turn On…/Settings…/Quit and verify appearance inheritance.
3. Compare a calibrated app-owned crop against exact reference panel bounds
   (645,38,320,347), retain actual/diff artifacts, and produce an honest visual verdict.
   Only score ≥90 plus interaction/evidence review can clear the visual gate.
