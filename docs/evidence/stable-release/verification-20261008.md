# Local software verification — 2026-10-08

The independently verifiable software work is complete. This is not a stable-release approval: real privileged installation/XPC, genuine component samples and their decoder, production configuration, and supported-host acceptance remain blocked owner gates.

| Check | Result |
| --- | --- |
| Full SwiftPM suite | 845 tests, 5 skipped, 0 failures |
| Native hosted XCTest suite | 813 tests, 6 skipped, 0 failures |
| Native Release build and static analysis | Passed |
| Reviewed identity input consistency | Passed, including isolated identity/build mutation and daemon rename |
| Bundle/tool identities, strict signatures, fixture exclusion | Passed |
| USTAR creation and same-reader archive validation | Passed |
| Scoped quarantine clearing | Passed for final bundle and embedded executables |
| Distribution preflight with absent production inputs | Refused, as required |
| Certificate-selected ad-hoc artifact | Refused, as required |
| Installer unprivileged staged preflight | Passed |
| Independent code review / architecture review | APPROVE / CLEAR |
| Python syntax, native project validation, diff checks | Passed |

Evidence logs from this run: `/tmp/watt-final-full-tests.log`, `/tmp/watt-final-native-tests.log`, `/tmp/watt-final-native.log`, `/tmp/watt-final-uninstall-focused.log`, `/tmp/watt-final-artifact.log`, `/tmp/watt-final-distribution-preflight.log`, `/tmp/watt-final-installer-preflight.log`. Native results are in `/tmp/watt-native-host-tests/Logs/Test/`. These local logs are transient; this document preserves their result and limits.

The native suite has the five existing host-dependent skips and one additional observed fixture permission skip. That skip applies only to a native app host receiving Cocoa 513 with underlying POSIX `EPERM` when attempting the real fixture bundle mutation. Other errors fail the test. The corresponding mutation and refusal cases pass in SwiftPM. No system-wide Gatekeeper or TCC setting was changed.

Implemented software includes mutual helper code-hash authentication, reviewed administrator install/rotation/removal tooling, separately authenticated update transport and bounded archive extraction, durable journals, protected update handoff/retry, actual-process startup acknowledgement, owned uninstall and explicit rollback, historical ownership after helper-only removal, and terminal helper absence verification. Test privilege/layout injection uses isolated user-owned fixtures; it is not evidence of an actual root installation.

The final locally verified bundle is `/private/tmp/watt-stable-native/Build/Products/Release/Watt.app`; its validated archive is `/private/tmp/watt-verified-release-final-20261008.tar`. They retain the explicit local verification identity/build and are not production release artifacts. No publication or real privileged install/removal/replacement occurred.

CPU/GPU readings remain unavailable until real root samples establish supported schema and units. Battery, charger and system readings are independent. Apple-issued certificates and notarization are not prerequisites for the selected GitHub/ad-hoc helper route.
