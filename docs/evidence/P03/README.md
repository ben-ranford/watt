# P03 — Notification and login adapters

2026-09-20 · G009 · existing worktree `swiftui-implementation`, branch `feat/swiftui-implementation`. No ultragoal checkpoint or ledger mutation.

## Changes and scope

- `Services/PowerReadingStore.swift`, appended P03 section: native public UserNotifications and SMAppService drivers behind injected protocols; F03-compatible adapters; Gate E power notification effects; login status/intent reconciliation.
- `Tests/WattTests/AppRouterTests.swift`, appended P03 section: two deterministic fakes and 15 tests.
- `DESIGN.md`, appended P03 contract/limitations.
- `docs/evidence/P03/`: this report, command logs, exit results and toolchain metadata.

Existing target-member files are used so the native project needs no membership edits. Earlier F03/P01/P02 source sections and evidence remain unchanged. AppRouter remains presentation-only. No production composition, dependency, screen or C01 change.

## Behavior and official API limits

[Apple notification permission guidance](https://developer.apple.com/documentation/usernotifications/asking-permission-to-use-notifications) separates checking settings from requesting permission. The injected native driver requests alert/sound authorization only through the explicit request method, then rereads settings. Ordinary delivery/status/preferences do not request permission. Denied status is returned without reprompting. Provisional/unknown permission conservatively maps to denied in the narrower three-state F03 interface: this deliberately forgoes provisional quiet delivery rather than assuming full authorization.

J6.3 fully charged and J6.4 insufficient charger each cover preference off/on × authorized/denied/not-determined/provisional/unknown. Off suppresses effects; undetermined returns a permission action; denied returns a Notification Settings action; authorized enqueues. These are semantic actions only: no undocumented Settings URL or automatic Settings launch. Authorization cannot guarantee visible banners (user notification settings, Focus and OS scheduling still apply). Enqueue success is labeled accepted, not displayed. Neither permission nor notification results change helper consent, preferences, power readings or AppRouter. OS approval notices remain OS-owned.

Episode IDs must come from a validated power-state transition; this slice does not choose charger thresholds, create events from every sample, or wire live telemetry. Event IDs are namespaced and deduplicated for one bridge lifetime, including concurrent calls. Failed enqueue can retry. Preference-off is rechecked after the effects layer's status read; already-dispatched/accepted work is not withdrawn. Permission may change again while a system request is underway. Accepted ID retention is in memory; durable cross-process notification deduplication, bounded retention policy and pending/delivered notification cleanup remain future integration concerns.

[Apple SMAppService.mainApp](https://developer.apple.com/documentation/servicemanagement/smappservice/mainapp) is the public macOS 13+ main-app login registration surface. Production composition must explicitly inject this service into `NativeLoginRegistrationDriver`. No service is instantiated by tests, previews, or app composition here. [Registration](https://developer.apple.com/documentation/servicemanagement/smappservice/register()) is subject to user approval. [Requires approval](https://developer.apple.com/documentation/servicemanagement/smappservice/status-swift.enum/requiresapproval) also represents revoked consent; it is not effective enabled. Reconciliation reads current status without writing intent or retrying registration. Enabled/pending registration and verified-absent removal are idempotent. Unknown/not-found do not count as absence proof. Errors are observable; successful calls are followed by status verification. Ambiguous effects are not blindly retried within an adapter lifetime. Synchronous login driver effects execute on MainActor without adapter reentrancy.

Restart tests create a new adapter against fake authoritative state; they do not prove actual login/relaunch behavior. Ambiguous operation memory is not durable across process restart. A production driver must reconcile external state before retrying unresolved work. No timeout machinery, helper approval bypass, signing entitlement claim, privileged API or TCC reset is introduced. macOS 13 is the declared deployment target; current-host compilation/testing is not macOS 13 runtime proof.

## Verification

All commands run in the assigned worktree with:

```sh
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
xcrun swift test --filter P03NotificationLoginTests > docs/evidence/P03/targeted-tests.log 2>&1
xcrun swift test > docs/evidence/P03/package-tests.log 2>&1
xcodebuild -project Watt.xcodeproj -scheme Watt -configuration Debug -destination 'platform=macOS' -derivedDataPath .build/p03-native build > docs/evidence/P03/debug-build.log 2>&1
xcodebuild -project Watt.xcodeproj -scheme Watt -configuration Debug -destination 'platform=macOS' -derivedDataPath .build/p03-native test -only-testing:WattTests -parallel-testing-enabled NO > docs/evidence/P03/native-tests.log 2>&1
xcodebuild -project Watt.xcodeproj -scheme Watt -configuration Release -destination 'platform=macOS' -derivedDataPath .build/p03-analyze analyze > docs/evidence/P03/release-analyze.log 2>&1
git diff --check > docs/evidence/P03/diff-check.log 2>&1
```

| Check | Result |
| --- | --- |
| Focused P03 | 15 tests, 0 failures |
| Package suite | 138 tests, 1 intentional P01 physical-host-probe skip, 0 failures |
| Native-hosted unit suite | 138 tests, same 1 skip, 0 failures; TEST SUCCEEDED |
| Native Debug | BUILD SUCCEEDED |
| Native Release analysis | ANALYZE SUCCEEDED |
| Whitespace diff | Passed |

All four recorded package/build/native/analyzer exit codes are 0. Native result bundle: `.build/p03-native/Logs/Test/Test-Watt-2026.09.20_22-59-04-+1000.xcresult`. `compile.log` is the earlier compile-only run before P03 tests were added (no matching tests); final proof is `targeted-tests.log` plus both full suites. Compiler/typechecking, Release analysis and diff checks are the available static checks; no dedicated linter configuration exists. Existing unhandled build-artifact, AppIntents metadata, destination and XCTest deployment warnings are nonfatal.

Tests cover the 20 power preference/permission combinations, explicit denial/recovery, independent event IDs, preference changes, concurrent duplicate delivery, authorization/enqueue errors, cancellation before effects, all 10 login desired/status combinations, pending approval/external approval, register/remove/restart idempotence, unresolved failures, failed preference persistence, unverified removal, and native status mapping without system-service creation.

## Completion boundary / blockers

**Isolated adapter implementation and deterministic verification complete; no local blocker.** Real signed-app permission/notification delivery, login registration, System Settings interaction and actual restart logs were intentionally not generated: they would prompt or mutate the host and are outside this task's safe verification boundary. Production wiring and that separate native integration evidence remain open; these fake/native-hosted unit tests do not close that gate.

## Read-only native status follow-up (2026-09-20)

Reproduce from the worktree root:

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer bash scripts/P03/read-only-status.sh
```

`scripts/P03/StatusProbe.swift` reads only public
`UNUserNotificationCenter.current().notificationSettings().authorizationStatus`
and `SMAppService.mainApp.status`. The runner compiles with Swift 6,
macOS 13 deployment target and warnings as errors, builds a separate minimal
app bundle at `.build/p03-read-only/P03StatusProbe.app`, then directly executes
its binary twice sequentially, waiting for each process to exit. No Launch
Services registration or `open` invocation is used. A 30-second read deadline
exits with code 2 rather than hanging. Rerunning overwrites this follow-up's
build/output artifacts only.

Identity: `dev.watt.evidence.P03StatusProbe`, **not Watt's production identity**.
The app-bundle context is required by the notification center; this is not an
installed or production-signed app verification. No entitlements or signing
identity are added. The probe does not request authorization, enqueue/deliver
notifications, register/unregister a login item, open Settings, alter TCC or
background-item configuration, or use Accessibility. No OMX state/ledger is
changed. As with any OS query, OS-internal bookkeeping is outside this probe's
control; no system-state mutation API is invoked.

Recorded evidence: [combined log](read-only-status.log),
[first process](read-only-status-run-1.json),
[second process](read-only-status-run-2.json), and
[validation](read-only-status-checks.log).

| Fresh process | UTC start/read | PID | Notification authorization | Main-app status | Exit |
| --- | --- | --- | --- | --- | --- |
| 1 | 2026-09-20T13:05:00Z | 13052 | `notDetermined` (0) | `notFound` (3) | 0 |
| 2 | 2026-09-20T13:05:01Z | 13058 | `notDetermined` (0) | `notFound` (3) | 0 |

Host: macOS 27.0 (26A428), arm64; Xcode 27.0 (27A266a), Swift 6.4.
Both processes independently reread matching statuses. This is a **probe-process
restart/reconciliation log**, not a Watt restart, user-session restart, machine
reboot, login launch, or execution of the product adapter. `notFound` is reported
verbatim and is not verified registration absence. Read-only status is **not
proof of notification delivery, approval mutation, or permission/registration
success**. Existing signed production integration gates remain open.

Follow-up checks: shell syntax, Swift 6 strict typecheck/build, bundle plist
syntax, JSON/PID/status reconciliation assertions, mutation-API source scan,
and tracked/untracked-file whitespace checks pass. No product files changed;
the earlier product test/build results above are historical, not rerun for
this standalone evidence-only follow-up.
