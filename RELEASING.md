# Releasing Watt

Releases are cut from `main` by [Release Please](https://github.com/googleapis/release-please). Merging its release pull request tags the repository and opens a draft GitHub Release. A macOS workflow then archives `Watt`, packages it, and uploads the files. The in-app updater stays the Ed25519 manifest already implemented in `Services/UpdateAdapter.swift`.

## Starting version

The manifest starts at **1.0.0**.

- There are no git tags.
- `Resources/ReleaseIdentity.json` is the reviewed release config: bundle id `io.github.ben-ranford.watt`, build `1`, and the GitHub Pages update URLs.
- The settings screen falls back to `1.0` when `CFBundleShortVersionString` is missing, and Xcode's marketing version was unset. `Config/Version.xcconfig` now sets it to `1.0.0`.
- The public history starts at a single squashed commit, so the first changelog has one entry.

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

Minor and patch must stay below 1000. `1.0.0` / build `1` remains valid only on the unreleased tree. A tagged release must use the encoded build, which is greater than `1`. The app has not shipped, so nothing migrates from the old `dev.watt.verification` id.

`scripts/configure-release-identity.py` (check mode, no `--write`) runs on the macOS runner and must pass before the archive is uploaded. Use that script's `--input` and `--write` yourself when you change the bundle identifier. Do not point it at a file that contains a private key.

## Workflow

`.github/workflows/release.yml` runs on pull requests (script checks only) and on pushes to `main`.

1. **Release Please** opens or updates one pull request. The job reads `headBranchName` from that action's `pr` output and checks it out. The accepted names are `release-please--branches--main` and `release-please--branches--main--components--<component>`. The branch component is `component`, or package name `Watt` when `component` is unset, which produces `release-please--branches--main--components--Watt`. `include-component-in-tag` stays false so the tag remains `vX.Y.Z`. Anything else is refused. When that pull request is merged, Release Please creates a **draft** GitHub Release and tag `vX.Y.Z`.
2. While the pull request is open, the same job syncs `CFBundleVersion` onto that branch and pushes the commit there. Wait until that job is green before merging, so the tag contains the encoded build.
3. **Build and publish** checks out the release commit on `xcode-27` (the same runner and Xcode 27 selection as CI), runs `xcodebuild -showBuildSettings`, archives the `Watt` scheme in the Release configuration with an ad-hoc signature, and uploads artifacts. A successful upload marks the release as published. A failed build leaves the draft in place; delete that draft if you are not going to retry it.
4. **Homebrew cask**, only after that publish, downloads the published zip, hashes it, and commits `Casks/watt.rb` to `main` on `ben-ranford/homebrew-tap`. The rendered cask removes the quarantine attribute in `postflight`. The tap's formula bumps already land that way, as `github-actions[bot]` commits. The job clones and pushes that commit over SSH with a write-access deploy key. If `HOMEBREW_TAP_DEPLOY_KEY` is unset, the job prints a notice and exits successfully. It does not update the tap from a draft.
5. **GitHub Pages**, only after that publish, downloads `Watt-X.Y.Z-update-manifest.json` and `Watt-X.Y.Z.tar` from the same release and deploys both as `updates/manifest.json` and `updates/Watt.tar`. One `actions/upload-pages-artifact` plus one `actions/deploy-pages` replaces the site, so the manifest and the tar change together. If the signed manifest is absent, the job skips the deploy and exits successfully. The job's token has `pages: write` and `id-token: write`, and it uses the `github-pages` environment. In the repository settings, set **Pages → Build and deployment → Source** to **GitHub Actions**. Do not add a custom domain.

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

`distribution-preflight` fails while the bundle identifier starts with `dev.watt.verification`, while the compiled update URLs differ from `Resources/ReleaseIdentity.json`, or while the Ed25519 public key is absent. The job still uploads the app and the preflight log. It does **not** upload an update manifest in that case, and the Pages job does not deploy. Publishing a manifest the installed app cannot accept would give the updater nothing it can use.

## Updater endpoints

`WATTUpdateManifestURL` and `WATTUpdateArtifactURL` are compiled into the app from `Resources/ReleaseIdentity.json`. Both must be `https`, with no user, password, query, or fragment. `ProductionUpdateSource` allows a few redirects only when the host stays the same.

The stable URLs are:

- `https://ben-ranford.github.io/watt/updates/manifest.json`
- `https://ben-ranford.github.io/watt/updates/Watt.tar`

`ben-ranford.github.io` serves that host directly. There is no custom domain, so these URLs do not redirect to another host. GitHub's `releases/download` URLs redirect to `release-assets.githubusercontent.com`, which the updater rejects, so the Pages copies are what the app fetches. The versioned GitHub Release files are the bytes the workflow copies. A release without `WATT_UPDATE_SIGNING_KEY` still archives. Preflight then fails because `WATTUpdatePublicKey` is missing, and no manifest is signed or deployed.

The public key embedded as `WATTUpdatePublicKey` is derived from `WATT_UPDATE_SIGNING_KEY`. Existing administrator installations still need that same 32-byte key through the installer's separate `provisionReleaseKey` path. The workflow does not install or rotate a protected generation. The uncompressed `Watt.tar` for this app is the ustar of `Watt.app`. The source tree, one icon, and the system Swift runtime put that well under GitHub's 100 MiB file limit. The Pages job refuses a tar above that limit instead of choosing another host.

## Signing

Releases are ad-hoc signed (`CODE_SIGN_IDENTITY=-`) with the hardened runtime. They are not Developer ID signed and they are not notarised. The archive job packages `Watt.xcarchive/Products/Applications/Watt.app` after `codesign --verify`. There is no export or notary step.

The privileged helper does not trust "any ad-hoc caller with this bundle id". Release builds set `WATTHelperTrustMode` to `protected-installation`, and the helper's XPC requirement is the installed app's cdhash. After an update, that pin changes only when the administrator installer has checked the Ed25519 manifest and the archive sha256, or through the existing reviewed helper-update flow. Both restart the helper with the new record. A missing record does not fall back to a team requirement or an identifier-only requirement.

If `APPLE_CERTIFICATE_P12_BASE64`, `APPLE_CERTIFICATE_PASSWORD`, `APPLE_TEAM_ID`, or any `APPLE_NOTARY_*` secret is still set, the archive job fails until those secrets are removed.

## Secrets

Create these in **Settings → Secrets and variables → Actions**. None of these values belong in the repository.

### Update manifest

| Secret | Contents |
| --- | --- |
| `WATT_UPDATE_SIGNING_KEY` | Base64 of an Ed25519 PKCS#8 PEM. This is the only update secret. |

```sh
openssl genpkey -algorithm ED25519 -out watt-update.pem
base64 -i watt-update.pem | tr -d '\n'
```

Keep `watt-update.pem` offline. The workflow derives the public key and can print it into the built app; it never writes the private key into the repository or the release log. The manifest and tar URLs are not secrets. Delete `WATT_UPDATE_MANIFEST_URL` and `WATT_UPDATE_ARTIFACT_URL` if they were added earlier. Without the signing key the archive still builds, distribution preflight fails cleanly, and Pages is left unchanged.

### Homebrew tap

| Secret | Contents |
| --- | --- |
| `HOMEBREW_TAP_DEPLOY_KEY` | OpenSSH ed25519 private key for a write-access deploy key on `ben-ranford/homebrew-tap` only. |

The key pushes `Casks/watt.rb` to that repository's `main` branch over SSH (`git@github.com:ben-ranford/homebrew-tap.git`). `main` on the tap is unprotected. Leave the secret unset to skip the tap update. Do not install this deploy key on this repository or on any other repository.

## First release

1. Merge this change. A squash title starting with `ci:` does not open a release by itself.
2. Make the repository public before the first release. The Pages job clones the release commit and downloads the release assets without a contents token, and `ben-ranford.github.io` only serves a public project site.
3. In **Settings → Pages → Build and deployment**, set **Source** to **GitHub Actions**. Leave the custom domain empty. That creates the `github-pages` environment the deploy job uses.
4. Remove any Apple signing or notarization secrets, and remove `WATT_UPDATE_MANIFEST_URL` and `WATT_UPDATE_ARTIFACT_URL` if they exist. Add `WATT_UPDATE_SIGNING_KEY` when you want a signed manifest. Add `HOMEBREW_TAP_DEPLOY_KEY` when you want the cask commit. An ad-hoc archive does not need either secret; without the signing key, preflight fails and Pages is not updated.
5. When you want the first tag to be exactly `v1.0.0`, add `"release-as": "1.0.0"` to the `.` package in `release-please-config.json` and push to `main`. Release Please opens a pull request that should also contain `chore: sync CFBundleVersion to the release marketing version` (build `1000000`). Merge that pull request, then delete `release-as` before the next release. Leaving `release-as` in the file pins every later release to the same version.
6. If you skip `release-as`, the next `fix:` on `main` proposes `1.0.1` and the next `feat:` proposes `1.1.0`.
7. After the macOS job publishes the release, read `distribution-preflight.txt`. With the signing key set, preflight passes for `io.github.ben-ranford.watt` and the Pages job publishes both update files. The installed app then fetches the stable URLs above.

## Decisions still open

- The production bundle identifier is `io.github.ben-ranford.watt`. Distribution preflight still rejects a bundle id that starts with `dev.watt.verification`.
- The stable manifest and tar are hosted on GitHub Pages at the two URLs above. Releases stay ad-hoc signed. Developer ID and notarization are not the release path.
- Zip and disk image are both attached for people installing by hand. The updater reads only the tar. The cask uses the zip and clears quarantine itself. Drop either hand-install download later if you do not want it; keep the tar.

## What was checked here

`python3 scripts/test_release_pipeline.py` covers the version encoding, the manifest byte layout, an OpenSSL Ed25519 sign/verify round trip, secret-plan failures, and the workflow shape. `bash -n` parses the shell scripts. `actionlint` checks the workflow when it is installed.

The archive job runs `xcodebuild -showBuildSettings` and checks that the `Watt` target resolves `MARKETING_VERSION` and `CURRENT_PROJECT_VERSION` before it archives. It then signs ad hoc. It does not call `notarytool`.
