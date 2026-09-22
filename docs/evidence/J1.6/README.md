# G033 / J1.6 — All set

Implementation is present; **story acceptance remains blocked**, not complete.
Worktree: `swiftui-implementation`, branch: `bug/G033-j16-all-set`.
Existing cumulative story edits were preserved. No commit or checkpoint.

## Implementation
- `Features/Onboarding/Views/OnboardingFlowView.swift`: `.allSet` presents
  `AllSetView`, exact “That’s it” copy and menu-bar guidance, existing app-icon
  placeholder, native grouped Form/Section/switch Toggle and prominent Done.
  Shared system typography/spacing are reused; no custom control or chrome paint.
- Done persists completion and `.coachMark`, dismisses onboarding, then requests
  the existing status-panel route. Duplicate/wrong-checkpoint calls are ignored;
  failed persistence stays on All set with retry feedback. J1.7 owns the future
  coach-mark presentation. Existing Back, native close and Escape paths remain.
- Open at login defaults on and binds to persisted preferences. This is desired
  preference state, **not evidence of OS login-item registration**.
- `App/WattApp.swift`: isolated DEBUG `J16FixtureLaunch` and app-owned capture.
- `Tests/Fixtures/StoryFixtures.swift`: J1.6 render-target registration.
- `Tests/WattTests/J16AllSetTests.swift`: six focused behavior/control tests.
- `Tests/WattTests/F05FixtureTests.swift`: expected registry update and fixture-ID
  failure diagnostic. `Watt.xcodeproj/project.pbxproj`: hosted J16 test membership.
- `DESIGN.md` unchanged: existing reusable native-style decisions suffice.

## Exact visual evidence
Supplied export downloaded from
`https://www.figma.com/api/mcp/asset/dabb7293-ccf0-42dc-ae89-62882941f7cd.png`.
SHA-256 `7de9c607b695153a9ec739336b421a60f00af96f7228f44599ac3101760c299b`
matches registered frame **28:2199**. Window **28:2353** occupies
**(260,206), 480×328** in the 1000×720 reference; content **28:2365**, row **28:2532**.

`bash docs/evidence/J1.6/capture.sh` passed. `native-window.png` is a fresh,
PID-scoped native compositor capture, **960×656 pixels / 480×328 points at 2×**.
`actual-content.png` is a separate 480×328 app-owned cacheDisplay diagnostic.
See `capture.json`, `window.json`, `image-hashes.txt` and `permissions.log`.
No desktop capture, permission request or TCC bypass was used.

### Independent Visual Ralph verdict
The supplied independent review records **score 94, verdict pass,
category_match true** in [visual-review.json](visual-review.json). Equivalent
**480×328-point** geometry matches the composition, exact copy and wrapping,
centered icon/title, enabled switch and bottom-right Done.

Remaining differences are minor or reflect native compositor behavior and
rasterization:
- Native Done is approximately **56pt** wide versus **65pt** in the reference;
  right alignment is preserved.
- Guidance text is approximately **5pt higher**; the grouped login row is
  approximately **1pt lower**.
- Native system typography, off-white background, traffic-light appearance and
  disabled zoom differ from Figma.

Preserve native controls; **no material source changes are required** by this
visual verdict. Secondary diff was unavailable because Pillow was not installed;
**no pixel diff or pixel-identical parity is claimed**. The score reflects visual
judgment, not a calibrated pixel-diff score.

`independentVisualApproval` is now **true**. `visualPass` and `storyDone` remain
**false** while story acceptance is blocked by AX/TCC/live interaction.
This documentation-only update records the supplied review and debugger fix;
it performs no new visual review, capture, build, test or accessibility audit. Existing reproduction commands were not rerun; product code and capture
metadata remain unchanged.

## Fresh verification — 2026-09-22
Commands run from this worktree with
`DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer`:

| Command | Result | Evidence |
| --- | --- | --- |
| `xcrun swift test --scratch-path /tmp/watt-g033-swift --filter J16AllSetTests` | 6 passed, 0 failures | `focused-tests.log/.exit` |
| `xcrun swift test --scratch-path /tmp/watt-g033-gating-swift` | 283 executed, 1 hardware skip, 0 failures | `/tmp/watt-g033-gating-swift.log` |
| `xcodebuild -project Watt.xcodeproj -scheme Watt -configuration Debug -derivedDataPath /tmp/watt-g033-debug build analyze` | BUILD and ANALYZE SUCCEEDED, exit 0 | `debug-build-analyze.log/.exit` |
| `xcodebuild -project Watt.xcodeproj -scheme Watt -configuration Release -derivedDataPath /tmp/watt-g033-release build analyze` | BUILD and ANALYZE SUCCEEDED, exit 0 | `release-build-analyze.log/.exit` |
| `xcodebuild -project Watt.xcodeproj -scheme Watt -configuration Debug -destination 'platform=macOS' -derivedDataPath /tmp/watt-g033-gating -only-testing:WattTests -parallel-testing-enabled NO -resultBundlePath /tmp/watt-g033-gating-native.xcresult test` | 271 executed, 1 hardware skip, 0 failures; TEST SUCCEEDED | `/tmp/watt-g033-gating-native.log` |
| Same native test command with `-only-testing:WattTests/F05FixtureTests/testAppCompositionRejectsUnimplementedStoriesAndGalleriesBeforeLaunch` replacing the suite selector and `/tmp/watt-g033-gating-focused.xcresult` as the result bundle | Fixture-gate test passed; TEST SUCCEEDED | `/tmp/watt-g033-gating-focused.log` |
| `git diff --check`; `bash -n` and ShellCheck of capture script; `plutil -lint Watt.xcodeproj/project.pbxproj`; Release `nm` check excluding J16FixtureLaunch | Passed | `static-checks.log/.exit` |

The debugger fixed the previously failing
**J1.4/cancel-one-approve-other-onboarding** fixture gate in `App/WattApp.swift`:
story launch validation now uses `selection.smokeLaunchArguments()` to reject
unimplemented non-base variants. The focused hosted fixture-gate test and full
hosted suite are green; the package suite is also green. The debugger logs in
`/tmp` listed above supersede the earlier `native-tests.log/.exit` and
`native-focused-tests.log/.exit` failure records retained in this directory.
These `/tmp` logs are local, non-durable evidence, not bundled artifacts.
This documentation update inspected those logs and the fix; it did not rerun
commands or alter product code.
Build logs contain the non-fatal “no AppIntents.framework dependency” metadata warning.
The skipped test is the opt-in physical telemetry probe.

## Remaining acceptance blockers
- Read-only permission probe: screen capture **preauthorized**, AX trusted **false**.
  Native compositor evidence succeeded, but live switch/keyboard/Done traversal,
  VoiceOver and actual post-onboarding status-item interaction are **unverified**.
- Unit tests prove routing requests and persistence, not physical OS interaction.
  No live login-item registration or helper connectivity claimed.
- Independent visual approval is recorded and the full hosted suite is green.
  Neither closes AX/TCC/live interaction gaps.
  Fixture “implemented” means a render target exists, not story acceptance.

Independent visual approval recorded; story acceptance remains blocked.
