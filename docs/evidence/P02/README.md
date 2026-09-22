# P02 — isolated helper lifecycle contract/adapter story

2026-09-20. Assigned worktree: `watt-worktrees/swiftui-implementation`, existing `feat/swiftui-implementation` branch. Base revision and toolchain are in `toolchain.log`. The worktree already contained implementation work; only the P02 additions below are claimed. No goal/ledger checkpoint was written.

## Result and boundary

**Isolated contract/adapter story complete; full signed production-helper gate remains open.** Read-only acceptance sources: main checkout `.omx/ultragoal/goals.json` G008 and `.omx/plans/watt-native-implementation-plan.md` P02. The latter requires signed isolated install logs; deterministic fakes cannot substitute for that proof.

**Separate production prerequisite (DEC-01/02/04): signed helper installation, real OS approval, authenticated XPC and verified removal require production integration and evidence.** This contract/adapter story does not implement or verify that production lifecycle. Its completion does not close the signed production-helper gate.

- `Services/PowerReadingStore.swift`, P02 section: `HelperLifecycleAdapter`, injected `HelperLifecycleDriver` and `HelperIPCTransport`, identity/version model and allowlisted request/response envelope. Existing F03 and P01 behavior was not edited.
- `Tests/WattTests/AppRouterTests.swift`, P02 section/extensions: deterministic driver/transport fakes and 13 focused lifecycle tests. Kept in existing native target source files to avoid out-of-scope project configuration changes.
- `DESIGN.md`: appended P02 contract and explicit limitations.
- `docs/evidence/P02/`: this README and `targeted-tests.log`, `package-tests.log`, `debug-build.log`, `native-tests.log`, `release-analyze.log`, `diff-check.log`, `toolchain.log`, `worktree-status.log`.

No UI, AppRouter, preferences, telemetry, native project membership or completed C01 evidence changes. No new dependency or production composition change.

## Contract / safety

Registration is permitted only after fresh authoritative absence (including no-in-flight proof) and candidate verification. Pending/connected registration rejoins without reinstalling. Unknown/disabled states fail closed. The actual authenticated peer must match the configured identifier, team and protocol version before any request. Identity here is a trusted transport result, **not a claim received from the helper**. The transport must enforce actual peer authentication and client authorization in a future production implementation.

Connected requires enabled registration, authenticated connection and exact correlated ping reply. Requests bind UUID, generation, receipt and allowlisted command; no arbitrary command/path execution. Lifecycle operations serialize. Disconnect/removal retires generations immediately; old replies cannot reconnect. Removal during in-flight work returns an interrupted receipt for explicit retry after drain, rather than racing destructive work. Absence must be verified after unregister. Update requires an authenticated prepare request, candidate verification, receipt-specific applied-version proof, and authenticated reconnect; connection alone never proves update success.

Ambiguous registration/update attempts are remembered within the adapter instance and not blindly replayed. Durable process-restart idempotence, installed-version/receipt proof, owned-resource inventory, finite operation deadlines, actual signing/authorization, ServiceManagement registration and XPC connection ownership are **driver/transport obligations**, not implemented OS claims. Driver errors (including timedOut) are surfaced; the adapter does not own a timer or forcibly terminate a hung driver. No actual helper is installed or removed, no System Settings approval is automated, and no privileged path/root/TCC bypass is used. macOS 13 remains the deployment target; execution here is on the current host, not proof of macOS 13 runtime compatibility.

F03 `HelperApprovalStore` is reused unchanged: withdrawal affects only that origin, rejoin replaces presentation authority, all-origin cancellation retires the wait generation, late OS approval may update independently reconciled effective availability but cannot navigate a withdrawn origin, and successful delivery is single-use. The adapter owns no scene navigation or preferences writes. Existing AppRouter only presents destinations.

## Focused coverage

13 tests cover registration/approval/IPC success; candidate and peer identity mismatch and incompatible version; unknown/disabled status and malformed correlation; stale generation and authenticated reconnect; remove versus suspended reconnect; cancelled task versus late reply; per-origin withdrawal/rejoin and shared single delivery; all-origin withdrawal and late OS approval; interrupted update/removal and receipt-specific recovery; successful update; wrong-generation IPC reply; unknown removal and pre-cancelled registration; timeout/disconnect retry without installation. Continuations and expectations control ordering; no sleeps, production helper, OS permission prompts or wall-clock race assumptions.

## Reproduce

From the assigned worktree:

```sh
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
mkdir -p docs/evidence/P02
xcrun swift test --filter P02HelperLifecycleTests > docs/evidence/P02/targeted-tests.log 2>&1
xcrun swift test > docs/evidence/P02/package-tests.log 2>&1
xcodebuild -project Watt.xcodeproj -scheme Watt -configuration Debug -destination 'platform=macOS' -derivedDataPath .build/p02-native build > docs/evidence/P02/debug-build.log 2>&1
xcodebuild -project Watt.xcodeproj -scheme Watt -configuration Debug -destination 'platform=macOS' -derivedDataPath .build/p02-native test -only-testing:WattTests -parallel-testing-enabled NO > docs/evidence/P02/native-tests.log 2>&1
xcodebuild -project Watt.xcodeproj -scheme Watt -configuration Release -destination 'platform=macOS' -derivedDataPath .build/p02-analyze analyze > docs/evidence/P02/release-analyze.log 2>&1
git diff --check > docs/evidence/P02/diff-check.log 2>&1
```

Final results: targeted **13 tests, 0 failures**; package and native hosted unit suites **123 tests, 1 intentional P01 physical-host-probe skip, 0 failures** each; Debug **BUILD SUCCEEDED**, Release **ANALYZE SUCCEEDED**; `git diff --check` passed. Native `.xcresult` path is printed in `native-tests.log`. No dedicated lint configuration: compiler diagnostics, Release analyzer and whitespace checks are scoped static validation. Existing unhandled build-artifact, AppIntents metadata, destination-selection and XCTest deployment-link warnings do not fail these checks. Native hosted tests are not UI/accessibility/TCC or signed installation proof.
