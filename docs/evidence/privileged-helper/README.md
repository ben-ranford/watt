# Privileged helper capture candidate

Recorded 2026-09-27 on this Mac (macOS 27.0, build 26A428; Xcode 27.0, build 27A266a). **The code milestone passed. Installation and CPU/GPU source validation have not passed.** No installed helper or real component watts are claimed.

## Implemented

- A bundled `SMAppService` daemon, mutual OS-enforced XPC signing requirements, bounded protocol and fixed CPU/GPU `powermetrics` capture. Requests cannot select an arbitrary executable, path, arguments, or privileged output file; only fixed protocol commands are accepted. Raw capture is capped at 1 MiB, serialized diagnostic replies at 2 MiB, and execution/cleanup at four seconds.
- Registration, approval reconciliation, persisted update/removal receipts, authenticated reconnect, scoped removal and a user-privilege diagnostic export. Registration mutation survives expected old-session invalidation; new-session handshakes still reject invalidated replies.
- Independent system/component freshness and failure handling. CPU/GPU estimates require a fresh complete pair; a missing channel suppresses both. Display, SSD and Other are unavailable. The production decoder is deliberately unfinished until a real capture establishes schema and units; raw capture is never presented as a reading.
- Debug/Release ad-hoc builds are verification candidates. `HelperSigned`/`WattHelperSigned` select Apple Development signing and require the owner's development team. Missing signing prerequisites leave registration unavailable.

Generated native layout:

```text
Watt.app/Contents/MacOS/WattHelper
Watt.app/Contents/Library/LaunchDaemons/dev.watt.verification.helper.plist
```

App ID remains `dev.watt.verification`. Helper ID and Mach service are `dev.watt.verification.helper`. The plist uses `BundleProgram = Contents/MacOS/WattHelper` and `AbandonProcessGroup = false`.

Implementation references: [protocol and signing](../../../HelperShared/HelperXPC.swift), [bounded sampler](../../../Helper/FixedPowerSampler.swift), [daemon](../../../HelperDaemon/Daemon.swift), [IPC](../../../Services/ProductionHelperIPC.swift), [lifecycle](../../../Services/ProductionHelperLifecycle.swift), [telemetry](../../../Services/ProductionHelperTelemetry.swift). Earlier non-root findings remain in [Gate 0](../helper-gate0/README.md); [G003 lifecycle evidence](G003-lifecycle.md) records the process-inventory checks.

## Verification performed

The final results below were observed in the leader's tool outputs and independent agent reports during this session. They are not backed by invented standalone log files. See the [quality gate](../../../.omx/ultragoal/quality-gate.md) for durable orchestration metadata.

| Check | Observed result | What it establishes |
|---|---|---|
| `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --quiet` | 775 tests executed, 5 skipped, 0 failures | Automated code/fixture coverage; skipped tests remain gaps |
| Native `xcodebuild` Debug and Release builds, Watt scheme, macOS destination | Both exit 0 | App/helper packaging compiles in both configurations |
| Native `xcodebuild` Debug `analyze` | Exit 0 | Static analysis completes |
| `plutil -lint` on generated daemon plist | OK | Generated plist syntax |
| `codesign -dvv` on embedded helper | ID `dev.watt.verification.helper`, arm64, ad-hoc, no TeamIdentifier | Actual unsigned-development identity; not installation trust |
| Launch embedded ad-hoc helper directly | Exit 78, `signed configuration required` | Fails closed before listening |
| Focused process/XPC tests | Passed, including TERM-resistant child KILL/reap, combined-stream overflow, recovery and anonymous XPC serialization | Bounded process behavior and transport serialization; not signed-peer acceptance |
| Independent final code review / architecture review | APPROVE, 0 issues / CLEAR | Reviewed capture-candidate implementation |
| `git diff --check` | Clean | Patch whitespace check |

Native commands used the full Xcode through `DEVELOPER_DIR`; the machine's global `xcode-select` still points at Command Line Tools. Builds and analysis used `-project Watt.xcodeproj -scheme Watt -destination 'platform=macOS'` with the respective configuration. Review verdicts do not waive the host gates below.

## External gates still blocked

- `security find-identity -v -p codesigning`: **0 valid identities**. No usable Apple-issued app/helper signing identity is installed.
- `xcodebuild -scheme WattHelperSigned -configuration HelperSigned ... build`: fails because Watt and WattHelper require `DEVELOPMENT_TEAM`.
- Unprivileged `powermetrics` requires superuser access; `sudo -n` reports that a password is required. No password was collected or privileged registration attempted.
- Signed wrong-client/wrong-helper tests, real OS approval, authenticated installed daemon PID/UID, root source capture, actual update/removal/reinstall and daemon-kill descendant cleanup are unverified. Current-Mac verification would not establish macOS 13 runtime support or power accuracy.

## Resume after owner prerequisites

1. Provision an Apple-issued signing identity/private key in Keychain and the associated development team through the owner's normal Apple/Xcode account workflow. Recheck `security find-identity -v -p codesigning`. Do not substitute ad-hoc signing or transmit an administrator password through tooling.
2. Build the concrete signed candidate with the owner's actual team value:

   ```sh
   DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild \
     -project Watt.xcodeproj -scheme WattHelperSigned -configuration HelperSigned \
     -destination 'platform=macOS' -derivedDataPath .build/xcode-signed \
     DEVELOPMENT_TEAM="$WATT_SIGNING_TEAM" build
   ```

   `$WATT_SIGNING_TEAM` must be set to that team. Verify the app and embedded helper with `codesign --verify --strict`, inspect identifiers/team/entitlements, and lint the generated daemon plist. If this host requires notarization, resolve the owner-controlled Developer ID/notarization prerequisite before installation; do not bypass it.
3. Place the verified signed app at a stable installation location, preserving any existing installation deliberately. Launch it and enable the helper through Watt's normal Settings/onboarding flow. The owner approves the macOS administrator/background-item prompt. Re-query actual ServiceManagement state; `.enabled` alone does not establish authenticated operation.
4. Verify authenticated ping, expected daemon build/instance and root PID/UID. In Settings, use **Export Helper Diagnostic…** to save the bounded response through the ordinary app save panel. Retain sanitized raw capture, hardware/OS/tool details, acquisition interval and exit status here. Capture at least three idle samples and a bounded CPU workload/recovery sample.
5. Establish actual CPU/GPU keys, units and missingness from those captures, then implement the decoder and real-fixture tests. Rebuild and re-sign. Show estimates only when both channels from the same acquisition validate and remain fresh. If either channel is unsupported, keep the helper installed with both estimates unavailable and record the source diagnosis. Never infer Display/SSD/Other or splice separate acquisitions.
6. Complete signed wrong-peer rejection, expiry/wake/reconnect, interrupted update and removal tests from the [verification specification](../../../.omx/plans/test-spec-watt-privileged-helper.md). Prove unregister completion and separate helper/sampler cessation, including daemon interruption during sampling. Reinstall/reapprove after removal and leave the verified helper installed. Record pass/fail/blocked evidence and final state before claiming installation complete.
