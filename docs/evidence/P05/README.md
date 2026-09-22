# P05 — scoped removal and uninstall adapter (G011)

2026-09-20. Assigned `swiftui-implementation` worktree, existing `feat/swiftui-implementation` branch. Read-only acceptance: implementation-plan P05 row and G011 objective in the main checkout. **No Ultragoal checkpoint or ledger mutation.**

## Scope and safety

This is **isolated adapter and in-memory integration evidence**, not production uninstall or signed helper removal. No filesystem deletion, launch-item mutation, app termination, real helper connection, user-data modification, dependency addition, permission prompt or scene wiring is implemented or exercised. The only native app launch is the ordinary hosted unit-test app. The fake fixture's `/fixture/...` strings are dictionary keys, never filesystem operations.

Changed files:
- `Services/ScopedRemovalAdapter.swift`: manifest/inventory/transaction/report types, injected driver boundary, F03 `UninstallCoordinator` implementation, helper-only removal, authenticated reconnect and explicit rollback.
- `Tests/WattTests/P05RemovalTests.swift`: 24 focused deterministic tests, including table-driven failures at all four steps.
- `Watt.xcodeproj/project.pbxproj`: compatibility-only membership for these two new files in existing app/test targets.
- `DESIGN.md`: additive P05 section.
- `docs/evidence/P05/`: commands/results and this evidence.

No P01–P04/C01 source or evidence changes. Existing F03 outcomes and P02 helper contracts are unchanged.

## Contract and behavior

The explicit manifest binds an installation UUID to exact owned resource paths and kinds. Empty, relative, root, noncanonical, duplicate and overlapping paths are rejected. Path syntax alone is **not ownership proof**: the driver must prove installation identity/object ownership and reject symlink substitution or an intervening owner at every effect. No recursive directory authority is implied.

Removal serializes operations and performs **login → helper → configuration → application** cleanup. The driver journal is saved before effects and binds the entire receipt (UUID and timestamp), manifest, scope and initial inventory. A different receipt/manifest/scope cannot replay or escalate that transaction. Every step reads fresh inventory and verifies its effect before proceeding. Missing entries are idempotent no-ops. Ambiguous post-effect failures return failure immediately; retry reconciles observed absence rather than replaying already-completed steps. Driver-side durable intent and idempotence remain required for in-flight/ambiguous OS effects.

Helper removal authenticates through P02 `HelperLifecycleAdapter.reconcile`, which verifies actual-peer identity and correlated handshake, before issuing the owned-driver removal. The effect boundary must independently reauthenticate. `reconnect()` reauthenticates on **every** call, never registers or updates a leftover helper. Wrong identity, timeout or mismatched handshake fails closed. Helper-only success requires no helper paths/process and preservation of the initial app-running state, including on retry; other owned resources remain intact. This is observable adapter inventory, not production presentation/store wiring.

`ScopedRemovalReport` retains failure reason, failed step, remaining scoped paths and fresh process/inventory state. Unknown inventory conservatively lists every scoped path. Empty remaining paths alone never mean success: a running helper/app prevents full uninstall success. `.verifiedAbsent` is based on fresh driver evidence, never a cached receipt or successful remove callback. Reconciliation after reconstruction uses the same journal and new inventory; newly appearing paths revoke prior success.

Rollback is explicit, not automatic permission/registration restoration. It first persists `rollingBack`, restores only receipt-owned backups in reverse order, then requires the exact baseline inventory/process state before saving `rolledBack`. Restoration errors remain retryable; intervening data is not overwritten. Repeating rollback is safe. A rolling-back or rolled-back receipt cannot resume deletion or report uninstall success. The isolated driver holds one transaction: authorizing a new removal after rollback requires a separately reviewed driver transaction-retirement/new-intent policy, not receipt substitution.

## Acceptance evidence

| Acceptance | Focused tests |
| --- | --- |
| Ordered full removal, no defined owned artifacts, unrelated sentinel, safe second retry | `testOrderedSuccessAndSecondRetryPreservesSentinel` |
| Failure before every step, remaining paths, stop ordering, retry | `testFailureAtEveryStepListsRemainingAndRetryIsSafe` |
| Failure after every effect, no duplicate deletion | `testAmbiguousFailureAfterEveryEffectReconcilesWithoutReplay` |
| Helper disabled with app running, unrelated owned entries unchanged | `testHelperRemovalLeavesAppRunningAndOtherOwnedResourcesIntact` |
| Unexpected app exit cannot be hidden by helper retry | `testHelperRetryCannotHideUnexpectedAppExit` |
| Leftover helper reauthentication, auth failure, timeout/correlation rejection | `testReconnectAuthenticatesEveryTime`, `testAuthenticationFailureBlocksHelperRemovalAndLaterSteps`, `testReconnectRejectsTimeoutAndUncorrelatedHandshake` |
| No-op cleanup, missing bytes with live processes, unknown inventory | `testNoOpDriverCannotClaimSuccess`, `testMissingBytesWithRunningHelperCannotClaimSuccess`, `testRunningAppPreventsFullUninstallSuccessEvenWithNoPaths`, `testUnknownInventoryFailsClosedAndListsAllPaths` |
| Already absent paths, write-ahead persistence failure | `testAlreadyAbsentPathsAreNotRemoved`, `testJournalFailurePreventsEffects` |
| Restart recovery and fresh evidence; journal/receipt/manifest/scope rejection | `testRestartRecoveryUsesSameManifestAndFreshInventory`, `testReceiptAndScopeMismatchCannotEscalateCleanup`, `testForeignInstallationJournalRejected`, `testReconcileWithoutJournalCannotClaimSuccess` |
| Rollback after every step, repeated rollback, failure at every restore step | `testRollbackAfterEveryPartialFailureRestoresBaselineAndIsIdempotent`, `testRollbackFailureAtEveryStepCanRecover` |
| Restore cannot lie or overwrite intervening data | `testRollbackNoOpCannotClaimRestoration`, `testRollbackPreservesInterveningDataInsteadOfOverwriting` |
| Manifest validation, concurrent retry and cancellation after an acknowledged effect | `testMalformedAndOverlappingManifestRejected`, `testConcurrentRetryCannotDuplicateEffectsAndCancellationReportsReality` |

## Reproduction and results

All commands run from this worktree with `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer`:

```sh
swift test --filter P05RemovalTests
swift test
xcodebuild -project Watt.xcodeproj -scheme Watt -configuration Debug \
  -destination 'platform=macOS' -derivedDataPath .build/P05-native -only-testing:WattTests test
xcodebuild -project Watt.xcodeproj -scheme Watt -configuration Debug \
  -destination 'platform=macOS' -derivedDataPath .build/P05-native build analyze
xcodebuild -project Watt.xcodeproj -scheme Watt -configuration Release \
  -destination 'platform=macOS' -derivedDataPath .build/P05-native analyze
git diff --check
plutil -lint Watt.xcodeproj/project.pbxproj
```

Each check has a named `.log` and `.exit` artifact here. `sources.sha256` fingerprints the implementation, tests and project membership. `toolchain.log` records macOS and Xcode versions. Native tests deliberately select hosted `WattTests`, not UI automation. The package/native suite's one intentional skip is the existing P01 live probe, not P05. No dedicated linter is configured; compiler/typechecking, Debug/Release analyzer and whitespace checks provide static validation.

| Final check | Result |
| --- | --- |
| Focused P05 package tests | **24 tests, 0 failures** |
| Full package tests | **191 tests, 1 intentional P01 skip, 0 failures** |
| Native hosted unit tests | **191 tests, 1 intentional P01 skip, 0 failures**; includes all 24 P05 tests |
| Debug build + analysis | **BUILD SUCCEEDED; ANALYZE SUCCEEDED** |
| Release analysis | **ANALYZE SUCCEEDED** |
| Diff/project syntax and additive-file whitespace | **PASS** |

All final command exit codes are 0. Release analysis emits the existing non-fatal AppIntents metadata-extraction warning (no AppIntents.framework dependency). The initial focused test iteration caught an enum-pattern compile issue and a duplicate-key construction in the invalid-manifest test; both were corrected before these final runs. A final review added the app-running-baseline retry regression; all checks above were rerun against that final source.

## Production limits / open gates

- There is **no production OwnedRemovalDriver**. Inventory/cleanup/process-exit/restore effects are dictionary simulations, and reconstruction retains an in-memory journal rather than proving OS-process/disk durability.
- Signed ServiceManagement packaging and authenticated XPC production prerequisites from P02 remain open. The fake transport exercises P02 identity and handshake rejection, not actual audit-token/signature validation.
- Concrete drivers must provide finite deadlines, authoritative registration/process absence (including in-flight effects), authenticated peer/client identity, race-safe exact-object ownership checks, symlink/TOCTOU protection, durable write-ahead journal and backup validation, and atomic receipt-bound effect reconciliation.
- Configuration manifests must enumerate approved installation-owned files only. Shared directories, unrelated preferences, user documents, other installations, update staging/backups and recovery records are **not implicitly authorized**. P04 recovery material cannot be deleted until its own transaction/discard policy permits it.
- Recovery journal/backups are retained driver control data outside the test resource inventory. A production “nothing left behind” claim additionally requires a reviewed finalization/retention policy and independent post-exit verification. This adapter's full-uninstall success proves only the declared resource/process inventory through its injected driver.
- OS approval cannot be recreated or silently granted by rollback. Real restore may require user action and must remain partial until independently proven. Production helper-disabled/app-running UI wiring, app/status-item exit, actual app deletion and signed cleanup acceptance are **not claimed**.

P05's isolated adapter slice does not close Gate E or production effects-based story Done.
