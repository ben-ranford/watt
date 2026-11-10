# Releasing Watt

Releases are cut from `main` by [Release Please](https://github.com/googleapis/release-please). Merging its release pull request tags the repository and opens a draft GitHub Release. A macOS workflow then archives `Watt`, packages it, and uploads the files. The in-app updater stays the Ed25519 manifest already implemented in `Services/UpdateAdapter.swift`.

## Starting version

The manifest starts at **1.0.0**.

- There are no git tags.
- `Resources/ReleaseIdentity.json` is the reviewed local identity: `dev.watt.verification`, build `1`.
- The settings screen falls back to `1.0` when `CFBundleShortVersionString` is missing, and Xcode's marketing version was unset. `Config/Version.xcconfig` now sets it to `1.0.0`.
- `bootstrap-sha` in `release-please-config.json` is `e66b12fb2b4b705ee3610c102374efc2f0cf3706`, the commit before this pipeline. Older history is not replayed into the first changelog.

`1.0.0` with build `1` is the unreleased verification pair. It is not a tagged release. The first release pull request rewrites `CFBundleVersion` to the encoded build below.

## What a release contains

Release Please updates `version.txt`, `Config/Version.xcconfig`, `.release-please-manifest.json`, and `CHANGELOG.md`. Conventional Commits choose the bump: `fix:` patch, `feat:` minor, `feat!:` or `BREAKING CHANGE` major. `ci:` and `chore:` do not bump.

The integer build cannot be a semver string. `UpdateConfiguration` accepts only a positive base-10 integer with no leading zero. On the release branch the workflow runs `scripts/sync-release-version.py --write`, which keeps the bundle identifier and sets every compiled build to:

```text
MAJOR * 1000000 + MINOR * 1000 + PATCH
```

| Marketing version | CFBundleVersion |
| --- | --- |
| 1.0.0 | 1000000 |
| 1.0.1 | 1000001 |
| 1.1.0 | 1001000 |
| 1.2.3 | 1002003 |

Minor and patch must stay below 1000. `1.0.0` / build `1` remains valid only on the unreleased tree. A tagged release must use the encoded build, which is greater than `1`, so an existing verification install can still move forward.

`scripts/configure-release-identity.py` (check mode, no `--write`) runs on the macOS runner and must pass before the archive is uploaded. Use that script's `--input` and `--write` yourself when you change the bundle identifier. Do not point it at a file that contains a private key.

## Workflow

`.github/workflows/release.yml` runs on pull requests (script checks only) and on pushes to `main`.

1. **Release Please** opens or updates one pull request, branch `release-please--branches--main`. When that pull request is merged it creates a **draft** GitHub Release and tag `vX.Y.Z`.
2. While the pull request is open, the same job syncs `CFBundleVersion` onto that branch. Wait until that job is green before merging, so the tag contains the encoded build.
3. **Build and publish** checks out the release commit on `macos-latest`, runs `xcodebuild -showBuildSettings`, archives the `Watt` scheme in the Release configuration, exports the app, and uploads artifacts. A successful upload marks the release as published. A failed build leaves the draft in place; delete that draft if you are not going to retry it.

The `test` job has `contents: read`. Release Please adds `contents`, `pull-requests`, and `issues` write so it can open the pull request and tag. The build job has only `contents: write`. Third-party actions are pinned to commit SHAs. Release names and tags are passed to scripts through the environment and checked against `vMAJOR.MINOR.PATCH` before they are used.

GitHub will not run a second workflow from the `GITHUB_TOKEN` release that Release Please creates. The archive is a later job in this same workflow, which is why it can see `release_created`.

In the repository settings, enable **Allow GitHub Actions to create and approve pull requests**.

## Artifacts

| File | Role |
| --- | --- |
| `Watt-X.Y.Z.tar` | Updater artifact. Uncompressed ustar whose entries are `Watt.app/...`, produced by `scripts/verify-release-readiness.sh local --archive` and rechecked by `WattMaintenance --validate-archive`. |
| `Watt-X.Y.Z.tar.sha256` | SHA-256 of that tar. The signed manifest uses these bytes. |
| `Watt-X.Y.Z.zip` | App download for people. Not the updater artifact. |
| `Watt-X.Y.Z.dmg` | Disk image download. Not the updater artifact. |
| `distribution-preflight.txt` | Result of `scripts/verify-release-readiness.sh distribution-preflight`. |
| `Watt-X.Y.Z-update-manifest.json` | Signed updater document. Present only when preflight passed and `WATT_UPDATE_SIGNING_KEY` is set. |

The manifest is `SignedUpdate`: base64 `payload` and base64 `signature`. The payload is the compact JSON `UpdateManifest` (`identity`, `build`, `sha256`, `minimumSystemVersion`) in `JSONEncoder`'s default layout. The signature is Ed25519 over those exact payload bytes.

`distribution-preflight` fails while the bundle identifier is still `dev.watt.verification`, or while the update URL and public key are absent. The job still uploads the app and the preflight log. It does **not** upload an update manifest in that case, even if the signing key secret is set. Publishing a manifest for an unprovisioned identity would give the updater nothing it can accept.

## Updater endpoints

`WATTUpdateManifestURL` and `WATTUpdateArtifactURL` are compiled into the app from secrets. Both must be `https`, with no user, password, query, or fragment. `ProductionUpdateSource` allows a few redirects only when the host stays the same.

GitHub's `releases/download` URLs redirect to `release-assets.githubusercontent.com`. The updater rejects that redirect. Put the manifest and the tar on one host you control and keep those two URLs stable: the copy of Watt that is already installed keeps fetching the URLs it was built with. After each release, copy the new manifest bytes and the new tar bytes to those URLs. The versioned GitHub Release files are the source you copy from.

The public key embedded as `WATTUpdatePublicKey` is derived from `WATT_UPDATE_SIGNING_KEY`. Existing administrator installations still need that same 32-byte key through the installer's separate `provisionReleaseKey` path. The workflow does not install or rotate a protected generation.

## Secrets

Create these in **Settings → Secrets and variables → Actions**. Leave a set unset to skip that step. Setting only part of a set fails the build. None of these values belong in the repository.

### Developer ID signing

All three, or none. When they are absent the log says the archive is using the project's ad-hoc identity and notarization is skipped.

| Secret | Contents |
| --- | --- |
| `APPLE_CERTIFICATE_P12_BASE64` | Developer ID Application certificate and private key, exported from Keychain Access as a `.p12`, then base64-encoded with no line breaks. |
| `APPLE_CERTIFICATE_PASSWORD` | Password for that `.p12`. |
| `APPLE_TEAM_ID` | 10-character Team ID from the Apple Developer membership page. |

```sh
base64 -i DeveloperID.p12 | tr -d '\n'
```

The temporary keychain password is generated in the job and the keychain is deleted at the end. There is no provisioning-profile secret: the project has no entitlements file. If export later demands a profile, that is a separate change.

### Notarization

All three, or none. Notarization also requires the Developer ID secrets. The job submits the app, staples it, then builds the tar, zip, and disk image from the stapled app and notarizes the disk image too.

| Secret | Contents |
| --- | --- |
| `APPLE_NOTARY_KEY_ID` | App Store Connect API key id (10 characters). |
| `APPLE_NOTARY_ISSUER_ID` | Issuer UUID shown on the App Store Connect API keys page. |
| `APPLE_NOTARY_KEY_P8_BASE64` | The `.p8` key, base64-encoded. Apple only lets you download it once. |

The API key needs a role that can submit to notarization. Store the `.p8` outside the repository.

### Update manifest

| Secret | Contents |
| --- | --- |
| `WATT_UPDATE_SIGNING_KEY` | Base64 of an Ed25519 PKCS#8 PEM. This is the only copy the workflow needs. |
| `WATT_UPDATE_MANIFEST_URL` | Stable HTTPS URL of the signed manifest. |
| `WATT_UPDATE_ARTIFACT_URL` | Stable HTTPS URL of the ustar tar. |

```sh
openssl genpkey -algorithm ED25519 -out watt-update.pem
base64 -i watt-update.pem | tr -d '\n'
```

Keep `watt-update.pem` offline. The workflow derives the public key and can print it into the built app; it never writes the private key into the repository or the release log. Set both URLs together with the key. URLs without the key fail the build. The key without the URLs skips embedding and, because preflight then fails, skips the manifest.

## First release

1. Merge this change. A squash title starting with `ci:` does not open a release by itself.
2. Add the secrets you have. Ad-hoc archives work with no secrets. Signed manifests and Developer ID builds wait until the matching secrets exist.
3. When you want the first tag to be exactly `v1.0.0`, add `"release-as": "1.0.0"` to the `.` package in `release-please-config.json` and push to `main`. Release Please opens a pull request that should also contain `chore: sync CFBundleVersion to the release marketing version` (build `1000000`). Merge that pull request, then delete `release-as` before the next release. Leaving `release-as` in the file pins every later release to the same version.
4. If you skip `release-as`, the next `fix:` on `main` proposes `1.0.1` and the next `feat:` proposes `1.1.0`.
5. After the macOS job publishes the release, read `distribution-preflight.txt`. It stays blocked until you replace `dev.watt.verification` with the production bundle identifier and the update secrets are present.
6. If preflight passed, copy `Watt-X.Y.Z-update-manifest.json` to `WATT_UPDATE_MANIFEST_URL` and `Watt-X.Y.Z.tar` to `WATT_UPDATE_ARTIFACT_URL`.

## Decisions still open

- The production bundle identifier is still `dev.watt.verification`. Distribution preflight is written to refuse that prefix.
- Where the stable manifest and tar are hosted. GitHub Release asset URLs are not usable as `WATTUpdate*URL`.
- Whether the first public build should wait for a Developer ID certificate. Without the Apple secrets the published app is ad-hoc, which matches the current local release route and is not a notarized download.
- The Apple Team ID, certificate, and App Store Connect API key are the owner's. This repository does not invent them.
- Zip and disk image are both attached for people installing by hand. The updater reads only the tar. Drop either download later if you do not want it; keep the tar.

## What was checked here

`python3 scripts/test_release_pipeline.py` covers the version encoding, the manifest byte layout, an OpenSSL Ed25519 sign/verify round trip, secret-plan failures, and the workflow shape. `bash -n` parses the shell scripts. `actionlint` checks the workflow when it is installed.

This agent ran on Linux. It did not run `xcodebuild`, `codesign`, `notarytool`, or `hdiutil`, and it did not execute `scripts/configure-release-identity.py` or `scripts/verify-release-readiness.py`, because those need `/usr/bin/plutil` and a Mac. The archive job runs `xcodebuild -showBuildSettings` and checks that the `Watt` target resolves `MARKETING_VERSION` and `CURRENT_PROJECT_VERSION` before it archives.
