# Final cumulative verification — 2026-09-23 Australia/Sydney

## Verdict
**Current follow-up: PARTIAL.** Current main is `343263a` as of 2026-09-23. The follow-up below supersedes only the old membership and Release test-module failures; it does not close final acceptance or production gates.

### Historical prior-pass verdict — `b1d4c11`
**PARTIAL. Not ready for a final-completion/production commit.** A scoped WIP checkpoint is possible with the blockers below disclosed. No commit was made; no source, product, or test files were edited. Existing cumulative edits and branch `bug/G081-final-project-verification` were preserved.

## Current follow-up

The [current-followup/](current-followup/) folder preserves the supplied logs
byte-for-byte for main `343263a` on 2026-09-23. See the
[current follow-up index](current-followup/current-followup.json) for commands,
provenance and limitations, and [git-revision.txt](current-followup/git-revision.txt)
for the full HEAD and documentation worktree branch. This documentation update
did not rerun package tests or Xcode builds. The SwiftPM logs do not record their
original argv; the index labels equivalent commands rather than claiming exact
invocation provenance.

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
- Strict evidence audit exits 1: **275 checksum passes, 57 mismatches, 3 missing named files**. 56 mismatches are historical source snapshots; C03 README has a stale metadata digest. J8.2/J8.3 missing local export aliases resolve to ignored F00 originals; J8.2 MCP screenshot bytes are absent. J11.2 raw JSON-plus-prose is not strict JSON; normalized JSON and PNG hashes verify. No missing verification log/exit links found.
- Original F00 inventory exits 1 on changed historical SCREEN-BACKLOG.md hash; current identity/export checks independently pass. Historical manifests were not rewritten.
- A supplemental verifier assertion initially treated omitted optional JSON keys as unequal to null; corrected normalization passes. Initial failure is retained as `supplemental-checks-initial.*`, not hidden or attributed to the product.

## Production and commit blockers
G082 resolves the historical Release test-module compatibility and two package-only regression-file membership blockers. AX/runtime interaction evidence, evidence-audit integrity, evidence portability/reproducibility, and all 69 current independent acceptance records remain unresolved. Production Gates A–E are not closed: live power telemetry, signed/authenticated helper lifecycle, real notification/login effects, approved trusted updater and signed install/relaunch, and installed scoped uninstall/cleanup remain unproven. Shipping signing/notarization, final assets and macOS 13 runtime evidence remain open. Current default updater composition fails closed.

Warnings remain: OnboardingFlowView main-actor isolation, AppIntents extraction, macOS-13 deployment versus macOS-14 XCTest libraries, and SwiftPM's existing unhandled build artifacts. This is not a warning-free result.

For the historical prior pass, `scope-preservation.json` verifies all **2,882 baseline non-build tracked/nonignored files unchanged**, no added files outside final evidence, and unchanged HEAD. Only `docs/evidence/final/` verification files were updated; no reset/revert, commit, permission or production-service changes.

**Do not `git add .`:** the historical prior pass recorded unignored `build/` containing 77,431 files / 8,237,063,309 bytes. Ignored `.omx` F00 references require a separate portable handoff. Final-completion readiness is false; preserving partial work is a different claim.

Historical prior-pass index: `verification.json` (unchanged). Current follow-up index: [current-followup.json](current-followup/current-followup.json). Details: `suite-summary.json`, `target-membership.json`, `supersession-review.json`, `evidence-audit-detail.json`, `resolved-findings.json`, and `diagnostics-summary.json`. Historical `package-build.*`, `registry-probe-build.*`, `native-tests.*`, and `native-process-cleanup.json` were not rerun and must not be read as fresh evidence. No current visual/accessibility scores were assigned.
