# P04 — injected updater adapter (G010)

2026-09-20, assigned `swiftui-implementation` worktree, existing `feat/swiftui-implementation` branch. Read-only acceptance: main checkout `.omx/ultragoal/goals.json` G010 and implementation-plan P04 row. No Ultragoal checkpoint/ledger changes. This is isolated adapter evidence, **not a production updater or signed app installation approval**.

## Files and boundaries

- `Services/UpdateAdapter.swift`: F03 `UpdateService` implementation, injected source/install driver/storage/trust, signed manifest and transaction types. No F03 signatures changed.
- `Tests/WattTests/P04UpdaterTests.swift`: 29 tests, deterministic Ed25519 signed fixture data, invalid artifacts, in-memory installation/launch boundary and atomic temporary-file journal.
- `Watt.xcodeproj/project.pbxproj`: compatibility-only membership for these two files in existing app/unit-test targets.
- `DESIGN.md`: additive P04 entry; `docs/evidence/P04/`: this evidence.

No P01–P03 or C01 implementation/evidence edits, no app/scene wiring, dependency, credentials, TCC prompt, production endpoint/key, real app replacement or untrusted process launch.

## Implemented behavior

The pinned injected CryptoKit public key authenticates a detached signature over the exact manifest payload. Signed identity, numeric build and SHA-256 bind the exact artifact bytes. Check/download reject non-increasing builds (including previously completed transactions); recovery permits the installed target build after the new binary restarts. The driver independently validates staged artifact identity/version and must revalidate code identity and bytes before replacement. The fake models that check by decoding its signed-data artifact; it is **not** a macOS code-signature validator.

Write-ahead journal phases: downloading → staged → replacing → awaitingRelaunch → completed; pre-install cancellation/discard and recovered rollback are explicit terminal paths. Receipt equality includes UUID **and** timestamp. Duplicate IDs, missing/mismatched receipt, malformed journal and modified manifest signatures fail closed. Discard requires scoped absence proof and leaves a permanent tombstone preventing receipt reuse. Failed cleanup remains non-installable. Installation requires explicit in-memory confirmation; consent is never inferred from automatic-check preferences or restored on restart. Relaunch is a separate explicit action. Recovery does not launch or blindly repeat replacement.

Pending network work serializes operations. Explicit cancellation durably retires the download epoch before late bytes can stage. Task cancellation also prevents staging. Discard waits for pending work to drain. Driver operations are synchronous in this isolated boundary, avoiding actor reentrancy during replacement. Errors remain recoverable; no speculative destructive fallback exists.

Recovery inspects actual driver placement: authenticated new bytes wait for receipt-bound running proof; verified original reports interrupted/rolled-back rather than success; uncertain partial replacement requests rollback and verifies the restored original before recording rollback. Successful completion needs exact running artifact bytes/version/identity plus transaction receipt, not just an install callback or persisted phase. Installed corruption cannot launch. Staged resources/backup are retained after installation: no automatic unrelated deletion or cleanup is attempted.

## Artifact and recovery evidence

`targeted-tests.log`, package/native logs name each test. The fixed **test-only** private-key seed creates genuine CryptoKit Ed25519 signatures, not boolean signature mocks. The original build-1 fixture is signed; the build-2 release signature binds its artifact hash and identity. Installation and launch occur only in private in-memory fake state. No fixture is executable. `testDurableAtomicJournalRestartAndCorruptionFailClosed` recreates the storage/adapter over an actual atomic JSON file in a UUID temporary directory and preserves an unrelated sentinel; this is adapter restart simulation, not an OS process restart.

| Acceptance | Evidence |
| --- | --- |
| Signed old → new, check/download/authenticate/stage/install/relaunch | `testSignedInstallRelaunchRestartAndSentinel` |
| Invalid signature, wrong signed identity, downgrade, altered bytes, wrong embedded identity | `testInvalidSignatureWrongIdentityAndDowngrade`, `testCorruptDownloadNeverStages`, `testSignedManifestCannotOverrideArtifactIdentity` |
| Fresh stage revalidation, confirmation and consent loss after restart | `testConfirmationRequiredAndNotRestored`, `testStagedArtifactRevalidatedBeforeInstallAndRecovery` |
| Cancellation, stale download reply, concurrency, Task cancellation | `testCancelSuspendedDownloadRejectsLateReplyAndConcurrentWork`, `testTaskCancellationDoesNotStageLateDownload` |
| Interrupted replacement before/during/after write | `testInterruptedReplacementRecoveryAtEveryBoundary` |
| Rollback failure/retry and corrupt installed bytes | `testRollbackFailureRemainsRecoverable`, `testInstalledCorruptionNeverLaunchesAndRecoveryRestoresOriginal` |
| Failed launch, wrong running receipt, no duplicate replacement/launch on recovery | `testRelaunchFailureWrongRunningReceiptAndRetry`, `testPostReplacementAndCompletionWriteFailuresRecoverWithoutReplay` |
| Durable journal corruption/signature tamper/duplicate or wrong receipt | `testDurableAtomicJournalRestartAndCorruptionFailClosed`, `testJournalSignatureTamperAndReadFailure`, `testDuplicateJournalReceiptsAndWrongVersionFailClosed`, `testExactReceiptNotOnlyUUID` |
| Write failures before effects/after replacement/completion/discard | `testPersistenceFailurePreventsEffectsAndRetryPreservesReceipt`, `testPostReplacementAndCompletionWriteFailuresRecoverWithoutReplay`, `testDiscardTombstoneWriteFailureCanRetryButCannotInstall` |
| Absence proof, idempotent discard, permanent receipt retirement | `testDiscardRequiresAbsenceAndCanRetry`, `testCancelledDiscardedReceiptCannotBeReusedAcrossRestart` |
| Stage/network/verification/cleanup errors, post-install cancellation restrictions, same-build replay | remaining focused tests |

## Verification and reproduction

```sh
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
xcrun swift test --filter P04UpdaterTests
xcrun swift test
xcodebuild -project Watt.xcodeproj -scheme Watt -configuration Debug -destination 'platform=macOS' -derivedDataPath .build/p04-native build
xcodebuild -project Watt.xcodeproj -scheme Watt -configuration Debug -destination 'platform=macOS' -derivedDataPath .build/p04-native test -only-testing:WattTests -parallel-testing-enabled NO
xcodebuild -project Watt.xcodeproj -scheme Watt -configuration Release -destination 'platform=macOS' -derivedDataPath .build/p04-analyze analyze
git diff --check
plutil -lint Watt.xcodeproj/project.pbxproj
```

Initial results before minimum-OS correction (all command exits 0):

| Check | Result |
| --- | --- |
| Focused package | **25 tests, 0 failures** |
| Full package | **163 tests, 1 intentional P01 physical-host-probe skip, 0 failures** |
| Native hosted full unit suite | **163 tests, 1 intentional P01 skip, 0 failures**, including all 25 P04 tests |
| Debug build | **BUILD SUCCEEDED** |
| Release analysis | **ANALYZE SUCCEEDED** |
| Project plist and tracked/new-source whitespace | **PASS** |

Native result bundle: `.build/p04-native/Logs/Test/Test-Watt-2026.09.20_23-14-55-+1000.xcresult`.
Existing non-fatal warnings: unhandled local build/evidence files in SwiftPM, AppIntents metadata extraction skipped, XCTest libraries newer than the macOS 13 deployment target, and multiple matching destination selection. None is a P04 source diagnostic.

Each test/build operation has a matching log and exit file. Compiler/typechecking, Release analyzer, project plist validation and whitespace checks provide static validation; no separate lint configuration exists. Native hosted tests are unit tests, not UI/TCC or production installation proof. macOS 13 is the deployment target; execution on this host does not prove macOS 13 runtime compatibility.

## Official references and production limitations

- [Apple CryptoKit `isValidSignature(_:for:)`](https://developer.apple.com/documentation/cryptokit/curve25519/signing/publickey/isvalidsignature(_:for:)): verifies Ed25519 signatures; used directly against pinned fixture trust. Apple documentation JSON was inspected to confirm API semantics.
- [Apple `SecStaticCodeCheckValidity`](https://developer.apple.com/documentation/security/secstaticcodecheckvalidity(_:_:_:)): checks code against signing validity/requirements. Reference inspection is recorded in `security-reference.log`. This is a future production driver obligation, **not an API called by this adapter**.
- [Apple atomic Data writing](https://developer.apple.com/documentation/foundation/nsdata/writingoptions/atomic): the temporary journal fixture uses Foundation atomic replacement, not a claim of power-loss/fsync durability.

**DEC-01/03 production gate remains open:** approved authenticated release endpoint, production pinned trust/key rotation, signing/team/designated requirement/notarization and supported-version policy, archive extraction limits, symlink/race-resistant owned paths, atomic replacement/backup on supported filesystems, directory durability, cross-process locking, authenticated running-process receipt/identity and single-process relaunch proof, rollback backup authenticity and real signed app old→new execution evidence are not implemented here. There is no production source, installation driver or durable journal composition and the adapter is not wired into AppRouter/UI.

Storage is a trusted single-owner protocol boundary: signatures protect manifest authenticity, **not journal phase/tombstone integrity against a local attacker**. A production journal must be app-owned, access-controlled, atomic and durable; forged lifecycle state is not an authentication mechanism. `PreferenceStorage` alone does not guarantee these properties. Transport deadlines/size limits/cancellation and OS code identity enforcement belong to the injected implementations. The bounded fake launch proves protocol checks only, not an actual process identity or process count. Evidence does not close consuming J10 UI stories or the production signed-install gate.

## Minimum-OS correction (2026-09-20)

Independent verification identified that the initial adapter did not reject candidates requiring a newer macOS. Corrected only `Services/UpdateAdapter.swift`, `Tests/WattTests/P04UpdaterTests.swift`, this P04 evidence and the P04 section of `DESIGN.md`; no P01–P03/C01 files or Ultragoal state were changed.

The signed `UpdateManifest` now requires `minimumSystemVersion`. Its grammar is `MAJOR.MINOR[.PATCH]`: ASCII decimal components representable by Swift `Int`, positive major, nonnegative minor/patch, no signs, spaces, suffixes or leading zeros (except a single zero). An omitted patch means zero. A missing/null/non-string field or malformed grammar fails with `invalidData`; a lexicographically numerically newer requirement fails with `incompatibleVersion`. `UpdateTrust` requires an injected `OperatingSystemVersion`; there is no silently assumed host version or missing-field fallback. Earlier manifests/journals lacking the required field fail closed rather than being migrated speculatively.

Compatibility gates run during check/download and immediately before installation; relaunch also checks compatibility. Signature/identity/build/digest checks remain intact. Authentication is separate from the host compatibility gate so existing authenticated transactions can still recover/rollback or cancel/discard if the host changes. A regression test stages on macOS 14.2.1, restarts with injected macOS 13.0, proves replacement is rejected, then proves staged recovery and discard remain available. Other new tests cover equal/older numeric versions (including patch normalization and numeric ordering), newer major/minor/patch, malformed/overflow/Unicode strings, and absent/null/numeric fields without staging or replacement.

Fresh verification uses `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer` and the commands above, with Debug `build analyze` instead of only `build`. Logs and exit codes use the `os-` prefix:

| Check | Correction result |
| --- | --- |
| Focused P04 package tests | **29 tests, 0 failures** |
| Full package tests | **167 tests, 1 intentional P01 skip, 0 failures** |
| Native hosted unit tests | **167 tests, 1 intentional P01 skip, 0 failures** |
| Debug build and analysis | **BUILD SUCCEEDED; ANALYZE SUCCEEDED** |
| Release analysis | **ANALYZE SUCCEEDED** |
| Diff/project syntax and changed-file whitespace | **PASS** (`os-diff-check.log`) |

An initial invocation without the documented `DEVELOPER_DIR` selected CommandLineTools and failed on unrelated SwiftUI compilation; rerunning with the project Xcode toolchain passed. No unrelated source changes were made to resolve it. No dedicated linter configuration exists; compiler/typechecking, native analyzer and whitespace checks provide the requested static checks.

This closes the isolated manifest compatibility omission, **not** the production supported-version policy or signed-install gate. A real driver must verify the actual bundle minimum OS against the signed manifest, in addition to code identity/version/digest. No real replacement, launch, private API, production transport or signing policy was implemented. The leader retains Ultragoal checkpoint ownership.
