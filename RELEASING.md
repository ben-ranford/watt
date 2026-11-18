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
4. **Homebrew cask**, only after that publish, downloads the published zip, hashes it, and commits `Casks/watt.rb` to `main` on `ben-ranford/homebrew-tap` when the signed rollout is already complete. A staged release leaves the cask on the last fully rolled-out version until `.github/workflows/rollout.yml` reaches 100% or the release is critical. The rendered cask removes the quarantine attribute in `postflight_steps`. The tap's formula bumps already land that way, as `github-actions[bot]` commits. The job clones and pushes that commit over SSH with a write-access deploy key. If `HOMEBREW_TAP_DEPLOY_KEY` is unset, the job prints a notice and exits successfully. It does not update the tap from a draft. A release with no signed manifest still updates the cask, because there is no rollout to wait for.
5. **GitHub Pages**, only after that publish, downloads `Watt-X.Y.Z-update-manifest.json` and `Watt-X.Y.Z.tar` from the same release and stages them as `updates/manifest.json` and `updates/Watt.tar`. It then copies the landing page from that commit (`docs/index.html` and the files beside it) into the same directory. `scripts/stage-pages-site.sh` does not remove `updates/`. `scripts/verify-pages-artifact.sh` requires `index.html` and both update files before `actions/upload-pages-artifact` and `actions/deploy-pages` run. One deploy replaces the site, so the manifest, the tar, and the landing page change together. If the signed manifest is absent, the job skips the deploy and exits successfully, and the live site, including `updates/`, stays as it is. The job's token has `pages: write` and `id-token: write`, and it uses the `github-pages` environment. In the repository settings, set **Pages → Build and deployment → Source** to **GitHub Actions**. Do not add a custom domain.

A push to `main` that does not publish a release still updates the landing page. `.github/workflows/pages.yml` downloads the files already at `https://ben-ranford.github.io/watt/updates/`, checks that they are a signed document and an uncompressed ustar, and copies the landing page in beside them. It deploys only after the same artifact check sees both paths. Anything other than those two HTTP 200 responses fails the job before upload, so a docs-only change cannot replace `/updates/` with an empty directory. The docs deploy and the release deploy share the `pages` concurrency group with `cancel-in-progress: false`, so one cannot replace the site while the other is still deploying. Pull requests run the artifact check and do not deploy.

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

The manifest is `SignedUpdate`: base64 `payload` and base64 `signature`. The payload is the compact JSON `UpdateManifest` (`identity`, `build`, `sha256`, `minimumSystemVersion`, `notes` when that release has changelog text, and `rollout` when the release is staged). `notes` is the body of the matching `CHANGELOG.md` section. `notes` and `rollout` are omitted when absent, so a manifest signed before either field still verifies. The signature is Ed25519 over those exact payload bytes. Older clients verify that signature and ignore `rollout`; they do not reject the manifest. They also do not stage, so they install as soon as they see the build. Clients that understand `rollout` are the ones that follow the schedule.

`distribution-preflight` fails while the bundle identifier starts with `dev.watt.verification`, while the compiled update URLs differ from `Resources/ReleaseIdentity.json`, or while the Ed25519 public key is absent. The job still uploads the app and the preflight log. It does **not** upload an update manifest in that case, and the Pages job does not deploy. Publishing a manifest the installed app cannot accept would give the updater nothing it can use.

## Updater endpoints

`WATTUpdateManifestURL` and `WATTUpdateArtifactURL` are compiled into the app from `Resources/ReleaseIdentity.json`. `scripts/release-archive.sh` passes them to `xcodebuild` as `WATT_UPDATE_MANIFEST_URL` and `WATT_UPDATE_ARTIFACT_URL`. `Resources/App/Info.plist` stores those references as `$(WATT_UPDATE_MANIFEST_URL)` and `$(WATT_UPDATE_ARTIFACT_URL)`, and the same file stores `$(WATT_UPDATE_PUBLIC_KEY)` and `$(WATT_HELPER_TRUST_MODE)`. Xcode expands the references while it builds `Contents/Info.plist`, before it signs the app. Xcode ignores `INFOPLIST_KEY_*` for keys it does not already know, so a custom `INFOPLIST_KEY_WATTUpdateManifestURL` never reaches the binary. Debug and local builds leave the three update settings empty. `UpdateConfiguration` rejects an empty value, and the app keeps running with updates not configured. After the archive, `scripts/check_archived_plist.py` reads the signed Info.plist and exits if a value the archive passed is missing or still contains `$(`. That failure stops the release job. Both URLs must be `https`, with no user, password, query, or fragment. `ProductionUpdateSource` allows a few redirects only when the host stays the same.

The stable URLs are:

- `https://ben-ranford.github.io/watt/updates/manifest.json`
- `https://ben-ranford.github.io/watt/updates/Watt.tar`

`ben-ranford.github.io` serves that host directly. There is no custom domain, so these URLs do not redirect to another host. GitHub's `releases/download` URLs redirect to `release-assets.githubusercontent.com`, which the updater rejects, so the Pages copies are what the app fetches. The versioned GitHub Release files are the bytes the workflow copies. A release without `WATT_UPDATE_SIGNING_KEY` still archives. The public-key setting stays empty, preflight then fails, and no manifest is signed or deployed. A release that passed a URL or public key and then lost it from the compiled plist fails before that point.

The public key embedded as `WATTUpdatePublicKey` is the `WATT_UPDATE_PUBLIC_KEY` build setting, derived from `WATT_UPDATE_SIGNING_KEY`. Existing administrator installations still need that same 32-byte key through the installer's separate `provisionReleaseKey` path. The workflow does not install or rotate a protected generation. The uncompressed `Watt.tar` for this app is the ustar of `Watt.app`. The source tree, one icon, and the system Swift runtime put that well under GitHub's 100 MiB file limit. The Pages job refuses a tar above that limit instead of choosing another host.

## Signing

Releases are ad-hoc signed (`CODE_SIGN_IDENTITY=-`) with the hardened runtime. They are not Developer ID signed and they are not notarised. The archive job packages `Watt.xcarchive/Products/Applications/Watt.app` after `codesign --verify`. There is no export or notary step.

The privileged helper does not trust "any ad-hoc caller with this bundle id". Release builds set `WATT_HELPER_TRUST_MODE` to `protected-installation`. `Resources/App/Info.plist` and `Resources/Helper/Info.plist` both expand `$(WATT_HELPER_TRUST_MODE)` before signing. The app reads that key from its own Info.plist and selects certificate trust only when the compiled value is exactly `certificate`. The HelperSigned configuration sets the same build setting to `certificate` on the app and the helper. `WATTSigningTeam` is `$(DEVELOPMENT_TEAM)` in both plists. Debug and Release leave the team empty, which those builds can do because they use protected installation. The helper's XPC requirement is the installed app's cdhash. After an update, that pin changes only when the administrator installer has checked the Ed25519 manifest and the archive sha256, or through the existing reviewed helper-update flow. Both restart the helper with the new record. A missing record does not fall back to a team requirement or an identifier-only requirement.

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

## Staged rollout

`Resources/ReleaseRollout.json` is the schedule signed into a new manifest. The default is not critical, with one step per day:

| Elapsed | Cohort |
| --- | --- |
| 0–24 hours | 1% |
| 1 day | 2% |
| 2 days | 5% |
| 3 days | 10% |
| 4 days | 20% |
| 5 days | 50% |
| 6 days and after | 100% |

`basis` is the unix time of signing. The whole object sits inside the signed payload (`basis`, `interval`, `steps`, `paused`, `percent`, `critical`, `halted`), so a changed schedule or a changed pause fails verification. Each install stores one random bucket from 0 through 99 in its update journal (`updater.rollout-bucket.v1`). The bucket never leaves the Mac. An automatic check offers the build when the bucket is below the current cohort. A check before `basis` offers it to nobody.

**Check for Updates** in the menu and **Check for Updates Now** in Settings are manual checks. They skip a running or paused schedule. They do not skip a halted release.

`critical: true` skips the schedule for every check, including automatic ones. Set that in `Resources/ReleaseRollout.json` before the release is tagged, and set it back to `false` before the next release so the next one is staged again. `workflow_dispatch` can also mark an already published release critical.

`paused: true` freezes `percent`. The clock does not advance the cohort. A manual check can still opt in. `halted: true` offers the build to nobody, including a manual check, and the cask does not move.

`.github/workflows/rollout.yml` uses the same `pages` concurrency group as the other deploys, with `cancel-in-progress: false`. It downloads the live manifest and `Watt.tar` first. If either is missing or not a signed ustar, it does not deploy, so a rollout run cannot replace `/updates/` with an empty directory. The first time neither file exists, the run exits without deploying. A daily run at 06:17 UTC re-signs `percent` when the schedule has moved and the rollout is not paused or halted. Clients do not wait for that run; they read the schedule themselves. The run is what updates the signed snapshot and what moves the cask once the last step is due.

Maintainer actions, from a checkout of `main`:

```sh
gh workflow run Rollout --ref main -f action=pause
gh workflow run Rollout --ref main -f action=pause -f percent=2
gh workflow run Rollout --ref main -f action=halt
gh workflow run Rollout --ref main -f action=resume
gh workflow run Rollout --ref main -f action=advance
gh workflow run Rollout --ref main -f action=finish
gh workflow run Rollout --ref main -f action=critical
```

`pause` with no percent freezes the cohort the schedule has reached. `percent` is 0 through 100 and is only read for `pause`. `halt` is how you stop a bad rollout: nobody is offered the build until you `resume`, `advance`, `finish`, or mark it `critical`. `advance` moves to the next step now. `finish` opens the build to every install and then updates the cask. `critical` does the same and also skips staging for this build. Each of those re-signs the manifest with `WATT_UPDATE_SIGNING_KEY` and publishes it through the Pages deploy. The tar is the one already on the site. The workflow refuses to sign a manifest whose sha256 does not match that tar, or a manifest this key did not already sign.

The Homebrew cask cannot be staged. It stays on the last complete version until the signed rollout is at 100% or the release is critical, and it moves immediately when there is no rollout block. The cask has `auto_updates true`, so `brew upgrade` does not replace Watt unless someone passes `--greedy`. Shipping the cask at the start of a staged release would still give every new `brew install` and every greedy upgrade the new build at once. Holding it until the rollout is finished keeps that pointer on a version the app is no longer withholding. A critical release moves the app and the cask together.

## What’s New

After an update, the first launch of the new version shows the signed release notes once, in a small window. The app records that the window appeared as soon as it is on screen. Quitting or crashing without pressing Done does not show it again. A fresh install does not show it, and neither does a later launch of the same version. The notes for the running version stay available from the About panel’s **What’s New** credit. That text is the signed `notes` field, checked again from the update journal. If the signature does not verify, the automatic window stays closed.

## Decisions still open

- The production bundle identifier is `io.github.ben-ranford.watt`. Distribution preflight still rejects a bundle id that starts with `dev.watt.verification`.
- The stable manifest and tar are hosted on GitHub Pages at the two URLs above. Releases stay ad-hoc signed. Developer ID and notarization are not the release path.
- Zip and disk image are both attached for people installing by hand. The updater reads only the tar. The cask uses the zip and clears quarantine itself. Drop either hand-install download later if you do not want it; keep the tar.

## What was checked here

`python3 scripts/test_release_pipeline.py` covers the version encoding, the manifest byte layout, an OpenSSL Ed25519 sign/verify round trip, secret-plan failures, the workflow shape, and the Pages artifact. That test builds an artifact that contains the landing page and `updates/`, and it checks a release deploy cannot upload without both. `bash -n` parses the shell scripts. `actionlint` checks the workflow when it is installed.

The archive job runs `xcodebuild -showBuildSettings` and checks that the `Watt` target resolves `MARKETING_VERSION` and `CURRENT_PROJECT_VERSION` before it archives. It then signs ad hoc. It does not call `notarytool`.
