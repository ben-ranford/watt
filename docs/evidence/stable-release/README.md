# GitHub release readiness

The target is GitHub distribution with ad-hoc code signatures and administrator-established exact code-hash trust. No Apple account, Developer ID, App Store or notarization is required by this route. Ad-hoc signing supplies executable identity, not publisher verification. Root access is required for `/usr/bin/powermetrics`, independently of signing.

The local installer copies reviewed bytes into private staging, validates the staged bundle and each architecture, and installs one protected generation under `/Library/Application Support/Watt/generations`. The root helper and its launchd plist use fixed paths. A root-owned public record binds app/helper/maintenance hashes and generation; root-private journals retain recovery state. The telemetry XPC service does not accept installation, deletion or shell commands.

Administrator bootstrap, per-build rotation and uninstall must be tested on a real supported host. Local fixture results do not prove installed launchd/XPC behavior. Normal app updates download and stage with separately provisioned release trust, then request administrator installation before replacing protected placement or pins. Handoff acceptance is not completion or absence proof.

The developer build number `1` and `dev.watt.verification` identities are local verification values. Production identities/builds/endpoints/key must be deliberately provisioned and kept coherent across app/helper/tools; no production endpoint or release key is supplied in source.

`Resources/ReleaseIdentity.json` is the reviewed source for compiled identity and numeric build. Run `python3 scripts/configure-release-identity.py` to check coherence. For an owner-provided identity JSON, use `--input /absolute/path/identity.json --write` to update compiled helper identities, native targets, helper metadata and daemon naming together, then rebuild. Endpoint and Ed25519 key configuration remain separate explicit release inputs.

## Local verification

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun swift test --build-system native
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project Watt.xcodeproj -scheme Watt -configuration Release -destination 'platform=macOS' -derivedDataPath /tmp/watt-release build analyze
scripts/verify-release-readiness.sh local /private/tmp/watt-release/Build/Products/Release/Watt.app --clear-quarantine
scripts/verify-release-readiness.sh local /private/tmp/watt-release/Build/Products/Release/Watt.app --archive /private/tmp/watt-release.tar
scripts/verify-release-readiness.sh distribution-preflight /private/tmp/watt-release/Build/Products/Release/Watt.app
```

Distribution preflight fails until the release configuration is provisioned. Passing artifact checks does not satisfy the independent installed/hardware gates listed below. No command publishes or performs privileged installation. Archives are uncompressed POSIX ustar, bounded and revalidated using the same reader as the updater. Symlinks, special entries, extended archive types and traversal are refused.

## Quarantine for a downloaded GitHub build

The user explicitly chose to remove quarantine from Watt executables. After checking that the downloaded artifact is the intended GitHub release, remove the bundle's quarantine attribute before running its embedded installer:

```sh
/usr/bin/xattr -dr com.apple.quarantine '/absolute/path/to/Watt.app'
```

This applies only to the selected Watt bundle and its embedded executables. Downloads can acquire quarantine again on another Mac. Clearing the attribute is separate from verifying the release digest/key and exact executable hashes. No system-wide Gatekeeper or TCC changes are needed.

## Administrator installation

Preflight is unprivileged and prints a complete staged inventory and approval digest:

```sh
'/absolute/path/to/Watt.app/Contents/MacOS/WattHelperInstaller' --preflight --source '/absolute/path/to/Watt.app'
```

Review that inventory. For the chosen local bootstrap, pass its exact approval digest to `--bootstrap-reviewed`; use `--rotate-reviewed` for a later reviewed local build. Invoke the installer with administrator authority only as an explicit installation step. Launch the installed generation as the ordinary user using the app path printed by the installer. Do not run the GUI as root. `--remove-helper`, `--uninstall`, and `--recover` require the exact installation UUID and generation from the protected record.

## Protected updates and uninstall

Install & Relaunch stages the authenticated release and opens a receipt-specific package containing `administrator-command.txt`, the signed manifest, archive and exact root request. The maintenance companion acquires both existing writer locks before the GUI quits. Run the package's exact command with administrator authority within five minutes. The root installer validates staged bytes with its separately provisioned release key and binds the new app/helper/maintenance hashes to the entire receipt. The companion verifies the resulting protected generation and launches the replacement through private challenge pipes. Its final handshake keeps the observer alive until the child confirms startup acceptance; this establishes authenticated code startup, not full GUI or hardware readiness.

An interrupted update retains its stage. Restart displays a fresh Resume Install & Relaunch action; recovery does not restore install consent automatically. Full uninstall similarly opens a fixed `WattMaintenance-<installation UUID>` directory with the bound administrator command, then an independent ordinary-user companion waits for exit, removes only enrolled user preferences, and verifies the root installer's receipt-bound removal result and process/resource absence. Handoff acceptance alone is never reported as successful removal.

Unprivileged removals retain exact receipt-specific backups beside the original app/preferences for rollback. Protected uninstall retains a byte-identical user-owned companion so recovery still works after the protected app is removed. Run that saved `WattMaintenance` executable with `--recover-uninstall <installation UUID> <receipt UUID>` for explicit rollback of user-owned resources. Recovery authenticates its actual OS process and exact inventory, refuses intervening files, and preserves its journal; protected app/helper restoration separately requires the root installer's reviewed recovery. These retained backups can contain user preferences and remain until deliberately cleaned after verification. A completed rollback permits a newly confirmed operation with a new receipt.

Uninstall composition is independent of helper connection and update configuration. A user-owned app can uninstall when fixed helper files and actual helper processes are verified absent; certificate mode uses its actual authenticated helper service and Apple team requirements. After protected helper-only removal, the running root-owned application retains its immutable generation record, so full uninstall still follows administrator maintenance rather than treating the application as user-owned. Conflicting ownership or unknown process inventory refuses removal.

## Remaining stable-release gates

- Explicit production identity/version, GitHub endpoints and separately provisioned Ed25519 release key.
- Actual administrator-installed ad-hoc mutual XPC authentication, coherent per-build rotation, crash recovery, uninstall and reinstall.
- Genuine root `powermetrics` samples on supported hardware, verified schema/units and an accurate CPU/GPU decoder. Connected helper plus diagnostic export still does not make component readings valid.
- macOS 13/runtime hardware coverage and native keyboard/VoiceOver acceptance.
- Complete release artifact and explicitly authorized GitHub publication.

CPU/GPU remain unavailable while the source is unvalidated. Battery, charger and system readings continue independently. Apple certificates and notarization are optional distribution choices, not blocked measurement prerequisites.
