# Administrator installer

`WattHelperInstaller` is an explicit local administrator tool. It does not obtain privilege itself or expose installation commands through telemetry XPC. GitHub builds use local ad-hoc signatures and exact CodeDirectory hash pins; no Apple account is required by this trust mode.

The bundled application must contain `Watt`, `WattHelper`, and `WattMaintenance`, with their configured identifiers, a positive numeric `CFBundleVersion`, and valid ad-hoc signatures. Release archives additionally need `LSMinimumSystemVersion` matching their authenticated manifest. All universal slices are checked.

## Reviewed local installation

1. Run `WattHelperInstaller --preflight --source /absolute/path/Watt.app` as the ordinary user. Inspect the returned hashes and whole-tree approval digest for the intended local build.
2. An administrator invokes `WattHelperInstaller --bootstrap-reviewed --source /absolute/path/Watt.app --approval <digest>`. For a newer build, use `--rotate-reviewed` with a freshly reviewed preflight digest.
3. Open the exact application path printed by the installer as the ordinary user. The installer never runs the GUI as root.

Preflight does not write protected paths. Installation re-copies inputs into root-controlled staging and checks the approved bytes again. It installs the app under `/Library/Application Support/Watt/generations/<installation UUID>-<generation>/Watt.app`, the helper at `/Library/PrivilegedHelperTools/io.github.ben-ranford.watt.helper`, and its launchd plist at `/Library/LaunchDaemons/io.github.ben-ranford.watt.helper.plist`. Public hash pins are root-owned `helper-trust.json`; the mutation journal and lock are private. Ancestors must be protected directories, and symlinks are refused.

Old application generations remain available during rotation. One public generation becomes active only after corresponding app/helper bytes are verified and placed. A crash leaves a private journal; a stale app cannot authenticate against the new exact helper pins.

## Separately provisioned release trust

An administrator can provision an explicit release public key independently of local helper bootstrap:

```
WattHelperInstaller --provision-release-key --installation <UUID> --identity io.github.ben-ranford.watt --public-key <base64 Ed25519 public key>
WattHelperInstaller --rotate-release --installation <UUID> --manifest /absolute/path/manifest.json --archive /absolute/path/release.tar
```

The first command refuses to overwrite an existing release trust configuration. The second stages both supplied files before verifying the detached signature, identity, strictly newer build, minimum OS, archive digest, bounded USTAR structure, and actual signed bundle contents. It then performs the same administrator-owned generation rotation. No private signing key is installed or accepted. No production public key or endpoint is supplied by the repository.

## Removal and recovery

```
WattHelperInstaller --remove-helper --installation <UUID> --generation <N>
WattHelperInstaller --uninstall --installation <UUID> --generation <N>
WattHelperInstaller --recover --installation <UUID> --generation <N>
WattHelperInstaller --discard-release-stage --installation <UUID>
```

These commands require administrator execution and independently read protected state. Helper removal stops the launchd service and checks process cessation before deleting the exact helper/plist/pin resources. Full protected uninstall additionally refuses running application generations, validates every owned generation, refuses foreign resources, and removes the protected generations and release trust. User preferences and login-item state are handled separately by the app's scoped removal workflow.

Recovery resumes only the recorded exact installation/generation. Interrupted release input staging before mutation can be explicitly discarded; an active installation journal must be recovered first. Missing identity, changed resources, uncertain process inventory, foreign files, and concurrent operations fail closed.

## Verification boundary

Tests use real temporary files and actual ad-hoc signatures with injected owner/launchd/process authority. They exercise bootstrap, rotation, interruption/recovery, exact removal, foreign-object refusal, and authenticated release archives. Production CLI flags cannot change owner or destinations. Actual administrator installation, launchd behavior on supported Macs, cross-process protected XPC, and root telemetry capture remain host verification gates. Those operations were not run during implementation.

## Binding an application maintenance receipt

Application-coordinated release rotation adds `--request /absolute/path/request.json` to `--rotate-release`; protected uninstall adds the same argument to `--uninstall`. The bounded request is an encoded `ProtectedMaintenanceBinding`: full receipt UUID and creation date, installation UUID, previous/next generation, operation, build, and operation-specific digests. Updates additionally bind the authenticated signed-payload digest, archive digest, and all replacement app/helper/maintenance CodeDirectory hashes. Manual operations without requests do not complete an app transaction.

The request is copied into private protected staging before it is decoded. Update bindings become part of the new public protected record and survive recovery; a private used-receipt registry refuses replay. Uninstall bindings survive in the private journal and are published to `/Library/Application Support/Watt-maintenance-result.json` after protected resource removal. The result is root-owned and public-readable.

`removalPlanSHA256` correlates the administrator operation with a user-context removal plan. It grants no authority over user paths, and the administrator tool neither accepts nor interprets per-user destinations. The user-context worker must independently match the complete receipt and exact plan digest and verify original parent exit, helper cessation, and absence of all scoped protected resources before reporting success. A decoded root result alone is not an absence proof.
