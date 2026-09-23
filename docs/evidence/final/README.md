# Final cumulative verification — 2026-09-23 Australia/Sydney

## Verdict
**Current follow-up: PARTIAL.** Current main is `fd9fb69` as of 2026-09-23. The follow-up below supersedes only the old membership and Release test-module failures; it does not close final acceptance or production gates.

### Historical prior-pass verdict — `b1d4c11`
**PARTIAL. Not ready for a final-completion/production commit.** A scoped WIP checkpoint is possible with the blockers below disclosed. No commit was made; no source, product, or test files were edited. Existing cumulative edits and branch `bug/G081-final-project-verification` were preserved.

## Current follow-up

The [current-followup/](current-followup/) folder preserves the supplied logs
byte-for-byte for the earlier main `343263a` on 2026-09-23. See the
[current follow-up index](current-followup/current-followup.json) for commands,
provenance and limitations, and [git-revision.txt](current-followup/git-revision.txt)
for the full recorded HEAD and documentation worktree branch. The SwiftPM logs
do not record their original argv; the index labels equivalent commands rather
than claiming exact invocation provenance. The latest native Settings correction
and fresh verification are documented below and under
`docs/evidence/J11.2/fresh-figma/live-capture-2026-09-23-state-fix/`.

| Check | Result | Evidence |
|---|---|---|
| Focused J13OfferTests + NativeStylingTests | **16 executed, 0 failures** | [focused-tests.log](current-followup/focused-tests.log) |
| Full package tests | **704 executed, 5 skipped, 0 failures** | [full-package.log](current-followup/full-package.log) |
| Release app build / analyze | **PASS / PASS** | [release-app.log](current-followup/release-app.log) |
| Release test build | **PASS; compilation, not test execution** | [release-tests.log](current-followup/release-tests.log) |
| G082 check-project | **PASS** | [g082-check-project.log](current-followup/g082-check-project.log) |
| G082 check-test-boundary | **PASS** | [g082-check-boundary.log](current-followup/g082-check-boundary.log) |

[G082](../G082/README.md) supersedes the historical missing Xcode membership for
`StatusPanelVoiceOverSummaryTests.swift` and `UpdateOfferInstallTests.swift`, and
the Release `Watt` module compatibility failure. These are no longer current
blockers at `343263a`; the prior failures below remain historical evidence.

**This is a follow-up, not all 69 independent D1–D7 acceptance records.** Live
AX/VoiceOver, TCC and compositor acceptance gates remain open. Evidence-audit
integrity and portability/reproducibility blockers and production Gates A–E
remain open. No new runtime visual/accessibility or final-completion sign-off
is claimed. `verification.json` and all historical logs remain unchanged.

## Latest Figma/native evidence refresh — `a7e8b35`

The sequential end-of-plan evidence refresh is now merged to current `main` for
J12.4, J12.5, J11.1, J11.2 and J11.3. Each record re-queried the exact Figma
node through MCP, pinned the screenshot hash and hierarchy/tokens, launched the
matching DEBUG fixture, recorded native AX evidence, and preserved the exact host
limitation without claiming a visual pass.

| Story | Current evidence | Remaining gate |
|---|---|---|
| J12.4 | Native AX alert exposes `A helper from your last install`, exact description, `Reconnect`, `Remove Helper`; PID-owned native alert capture retained | AppKit dark/native appearance differs from the light Figma component; production helper inventory/mutation remains unproven |
| J12.5 | Native AX status item exposes `Watt?, charging, plus 42.1 watts, menu extra`; Settings scene did not surface in the observation interval | No live Settings visual/production reconnect proof |
| J11.1 | Native AX status-item label and successful activation recorded | `.window` panel compositor/VoiceOver runtime not surfaced |
| J11.2 | Fresh AX activated PID-owned Settings; exact native controls/strings, `Status` `On`, `Helper` `Remove…`, and privacy copy recorded; strict native capture is 580×870 | Visual Ralph remains blocked: grouped native Form vertical rhythm still differs materially; keyboard/VoiceOver/production helper proof remains open |
| J11.3 | Native `AXSheet` exposes exact destructive title/message and `Cancel`/`Uninstall`; final action not pressed | AppKit horizontal buttons/no custom icon versus Figma stacked alert; keyboard/VoiceOver runtime unverified |

Evidence is under each story's `fresh-figma/` directory. These are documentation
and verification updates only; they do not close the project-wide D1–D7, TCC,
compositor, or production Gates A–E blockers. The normal `/Users/benranford/Desktop/Watt.app`
remains running separately from all fixtures.

## Latest J11.2 correction — `fd9fb69`

The J11.2 record now reflects the exact Figma frame `36:5186` and its native
window node `36:5188`. The fixture prepares helper state during app composition,
before the native menu-bar bridge materializes, eliminating the startup race
that previously produced the stale disconnected state. The Settings content
height token is `838` points, yielding the Figma window geometry of `580×870`
while preserving native macOS Settings/Form control ownership. The connected
state retains the Figma privacy subtitle and exposes `Status` `On` and
`Helper` `Remove…` through AX.

Fresh evidence is retained at
[`docs/evidence/J11.2/fresh-figma/live-capture-2026-09-23-state-fix/`](../J11.2/fresh-figma/live-capture-2026-09-23-state-fix/): focused J11.2 tests
pass `6/6`; the full Swift suite passes `704 executed, 5 skipped, 0 failures`;
Debug and Release app build/analyze checks pass. This does not claim visual
acceptance: the native grouped Form's vertical rhythm still differs from the
reference, and live keyboard/VoiceOver plus production helper evidence remain
open. No custom-painted replacement or forced tint was introduced.

## Historical prior-pass evidence — `b1d4c11`
The following table and retained evidence describe the prior pass, not current
main. “Fresh” in this historical record means fresh for that prior pass only.

All commands used `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer`: Xcode 27.0 (27A266a), Swift 6.4. `verification.json` lists exact commands, scratch paths, durations and real exits; matching `.log` and `.exit` files retain output. Builds used fresh temporary directories outside the repository.

| Check | Result |
|---|---|
| Full package tests | **703 executed, 5 skipped, 0 failures; exit 0** |
| Debug build / analyze / build-for-testing | **All succeeded; exit 0** |
| Release app build / analyze | **Both succeeded; exit 0** |
| Release build-for-testing | **FAIL, exit 65**: compatible `Watt` module dependency unresolved at `J13OfferTests.swift:7:18`; no Release tests executed |
| `git diff --check` | PASS, exit 0 |
| Project `plutil -lint` | PASS, exit 0; fresh Debug/Release app Info.plists also pass |
| J13/J14/J15 target membership | PASS: each appears once in WattTests Sources, uses guarded WattFixtures import, and appears in the successful Debug compile log |
| Native styling | Source checks pass across 43 Swift files; all 10 NativeStylingTests pass. Not visual/runtime AX acceptance |
| Aggregate static checks | Exit 1: **StatusPanelVoiceOverSummaryTests.swift and UpdateOfferInstallTests.swift remain outside Xcode membership**; their 7+4 package tests pass |
| Shell checks | 143 shell syntax checks and selected five-script ShellCheck pass |
| Registry | **69 exact ordered story/node pairs; 136 selections**; two byte-identical compiled probe runs; full embedded references match F00 |
| Reference exports | All 69 F00 export hashes and dimensions pass |
| Permission preflight | Exit 1: **AXTrusted=false**, Screen Recording preauthorized=true; no permission requested/changed, no new capture attempted |

Five package skips are four unavailable AX-label checks (J6.2–J6.5) and the opt-in P01 physical-host probe. Package tests and test-bundle compilation do not prove native hosted execution, UI interaction or VoiceOver. No additional native UI tests were run in this pass. Earlier `native-tests.*` timeout records are historical, not fresh results.

## Historical prior-pass supersession and evidence gaps
- **C01:** explicit `visual-review.json` supersession and DESIGN.md native-control mapping invalidate the historical custom-chrome visual PASS for current styling. Current visual score/pass are unavailable. C01 README still contains conflicting historical PASS/C01-only wording; it was not edited.
- **J11.3:** re-read README, verification and visual records. Historical capture exited 1 with no accepted implementation image. Return/Escape, focus traversal, VoiceOver and current visual acceptance remain unverified. Reference screenshots are not implementation captures.
- Read/hashed 2,753 retained docs files, including 89 Markdown documents and 95 verification/visual records. `story-status-summary.json` maps all 69 stories; retained records are not fresh D1–D7 sign-off.
- The historical strict evidence audit exited 1 with **275 checksum passes, 57 mismatches, and 3 missing named files**; that baseline is retained in the historical logs. A fresh portable audit on 2026-09-24 now reads **3,110 docs files / 97 records**, with **295 checksum passes and no current evidence-digest or JSON problems** after restoring the J8.2/J8.3 aliases, refreshing C03 metadata, and separating the J11.2 mixed response text from strict JSON. The only remaining audit problem is the ignored F00 reference manifest/export directory, which is unavailable in this Git worktree and remains required before final sign-off.
- Original F00 inventory exits 1 on changed historical SCREEN-BACKLOG.md hash; current identity/export checks independently pass. Historical manifests were not rewritten.
- A supplemental verifier assertion initially treated omitted optional JSON keys as unequal to null; corrected normalization passes. Initial failure is retained as `supplemental-checks-initial.*`, not hidden or attributed to the product.

## Production and commit blockers
G082 resolves the historical Release test-module compatibility and two package-only regression-file membership blockers. AX/runtime interaction evidence, evidence-audit integrity, evidence portability/reproducibility, and all 69 current independent acceptance records remain unresolved. Production Gates A–E are not closed: live power telemetry, signed/authenticated helper lifecycle, real notification/login effects, approved trusted updater and signed install/relaunch, and installed scoped uninstall/cleanup remain unproven. Shipping signing/notarization, final assets and macOS 13 runtime evidence remain open. Current default updater composition fails closed.

Warnings remain: OnboardingFlowView main-actor isolation, AppIntents extraction, macOS-13 deployment versus macOS-14 XCTest libraries, and SwiftPM's existing unhandled build artifacts. This is not a warning-free result.

For the historical prior pass, `scope-preservation.json` verifies all **2,882 baseline non-build tracked/nonignored files unchanged**, no added files outside final evidence, and unchanged HEAD. Only `docs/evidence/final/` verification files were updated; no reset/revert, commit, permission or production-service changes.

**Do not `git add .`:** the historical prior pass recorded unignored `build/` containing 77,431 files / 8,237,063,309 bytes. Ignored `.omx` F00 references require a separate portable handoff. Final-completion readiness is false; preserving partial work is a different claim.

Historical prior-pass index: `verification.json` (unchanged). Current follow-up index: [current-followup.json](current-followup/current-followup.json). Details: `suite-summary.json`, `target-membership.json`, `supersession-review.json`, `evidence-audit-detail.json`, `resolved-findings.json`, and `diagnostics-summary.json`. Historical `package-build.*`, `registry-probe-build.*`, `native-tests.*`, and `native-process-cleanup.json` were not rerun and must not be read as fresh evidence. No current visual/accessibility scores were assigned.

## Fresh current-main verification — 2026-09-24

After the native live telemetry/status-item fixes and compositor evidence refresh,
current `main` at `a8e97c9` was freshly verified with the Xcode toolchain:

| Check | Result |
|---|---|
| Full Swift package tests | **713 executed, 5 skipped, 0 failures** |
| Release native app build | **PASS** |
| Release native app analyze | **PASS** |
| Running status-item AX probe | **PASS** — native `AXMenuBarItem`, live `17.2 W` sample |

The reproducible commands and raw logs are retained under
[`current-2026-09-24/`](current-2026-09-24/). The running app remains a native
AppKit status item backed by live `SystemPowerIn`/`SystemLoad` telemetry. This
fresh verification still does not claim closure for the explicit compositor
visual, TCC/VoiceOver, hardware, or production-effect gates.
