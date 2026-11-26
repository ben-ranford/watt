# Contributing

Pull requests are welcome. Open one against `main`.

## Table of Contents

- [Issues](#issues)
- [Pull requests](#pull-requests)
- [Conventional commits](#conventional-commits)
- [Validation](#validation)
- [Security](#security)
- [Names](#names)
- [What the app reads](#what-the-app-reads)
- [Privileged helper](#privileged-helper)
- [Developer ID signing](#developer-id-signing)
- [Update verification](#update-verification)
- [Homebrew cask](#homebrew-cask)
- [Site screenshots](#site-screenshots)
- [Build](#build)

## Issues

Bug reports and feature requests use the forms in `.github/ISSUE_TEMPLATE/`. Blank issues are turned off.

A bug report needs the macOS version, the Watt version, the Mac model, the steps, what you expected, what happened, and any logs you have. GitHub applies the `bug` label.

A feature request needs the problem, the proposed behavior, and the acceptance criteria. GitHub applies the `feature` label.

## Pull requests

Use the template in `.github/pull_request_template.md`. Keep these headings, in this order: Summary, Linked issue, Change type, Validation, Test plan, and Docs and changelog. `Assumptions to confirm` is optional. When you include it, every line is a checkbox.

Summary says what changed and why, in your own words. Tick one change type, and make it the bump the title uses (`fix` patch, `feat` minor, `!` or `BREAKING CHANGE` major, anything else no bump). Test plan is a checkbox list. Put a Mac check there, under `## Test plan`.

Delete the `Closes #` line when there is no issue. Leave Mac serial numbers, hardware UUIDs, and notes such as "mac time" out of the title and the description.

## Conventional commits

This repository uses [Conventional Commits](https://www.conventionalcommits.org/en/v1.0.0/) because [Release Please](https://github.com/googleapis/release-please) cuts releases from the pull request title. The pull request check rejects a title Release Please cannot read, and it checks the description against the template. Release Please's own pull request is checked on the title only.

`fix:` is a patch. `feat:` is a minor. `feat!:` or a `BREAKING CHANGE` footer is a major. These types do not bump the version: `build:`, `chore:`, `ci:`, `deps:`, `docs:`, `perf:`, `refactor:`, `revert:`, `style:`, and `test:`.

```text
type(optional-scope)!: subject
```

The scope is lowercase kebab-case, such as `menu-bar`. The subject starts with a lowercase letter and does not end with a period. The whole title is 72 characters or fewer.

`chore(main): release 1.0.1` is the title Release Please uses for its own pull request. The release steps are in [RELEASING.md](RELEASING.md).

## Validation

These checks run on every pull request, including every pull request into `main`. They are the checks to require before merge:

| Check | Workflow | What it runs |
| --- | --- | --- |
| `macOS` | Build and test | Debug and Release `xcodebuild` builds, `xcodebuild test` for `WattTests`, and `swift test`. That `xcodebuild test` records line coverage and compares the app and helper targets with `.github/coverage-floor.json`. While `enforce` is false the job warns; while `enforce` is true it fails. A pull request also uploads the Release `Watt.app` as the `Watt-app-pr` workflow artifact for 7 days. Same-repo pull requests sign that app with Developer ID and notarise it. Fork pull requests, which cannot read the signing secrets, upload an ad-hoc build instead. That Release build compiles the public update URLs from `Resources/ReleaseIdentity.json` and the public key in `Resources/UpdatePublicKey.txt`. |
| `Release config` | Release | `python3 scripts/test_release_pipeline.py` |
| `gitleaks` | Secret scan | Working-tree secret scan. The same scanner is the optional pre-commit hook in `.pre-commit-config.yaml`. |
| `Conventional commit` | PR title | The pull request title is a Conventional Commit, and the description follows the template. Release Please is title-only. Editing the description re-runs this check. |

Require those four checks. `Release Please`, `Build and publish`, `Update Homebrew cask`, and `Publish update endpoints` stay in the Release workflow and are skipped on a pull request that does not publish. A skipped required check blocks the merge.

Before you ask for review:

```sh
xcodebuild -project Watt.xcodeproj -scheme Watt -configuration Debug -destination 'platform=macOS' build
xcodebuild -project Watt.xcodeproj -scheme Watt -configuration Release -destination 'platform=macOS' build
xcodebuild test -project Watt.xcodeproj -scheme Watt -configuration Debug -destination 'platform=macOS' -only-testing:WattTests
swift test
```

`WattUITests` drive the menu bar and are not part of the CI unit-test run. Run them on a Mac when you change that host.

If you change `scripts/` or `.github/workflows/`:

```sh
python3 scripts/test_release_pipeline.py
python3 scripts/test_coverage_floor.py
```

The lint check is the gitleaks secret scan.

CI gives `xcodebuild test` the same 120 second per-test allowance as `scripts/verify-native-host.sh`. The step stops the process after 10 minutes and retries once when `xcodebuild` does not exit. An assertion failure fails the check immediately.

The same macOS job compares line coverage with `.github/coverage-floor.json`. The file stores a whole-number percent for the Watt app, `WattHelper`, `WattMaintenance`, `WattHelperInstaller`, and the total of those binaries, plus an `enforce` flag. Test bundles, generated files, and SwiftUI previews are not counted. The job prints the actual and floor percentages in the log and the step summary. While `enforce` is false, a short total is a warning annotation and the job stays green. While `enforce` is true, a short total fails the job. When coverage is two or more points above a floor, the job prints a notice and leaves the file unchanged. That gate stays in the `macOS` check.

UI changes need a manual check on macOS. Attach screenshots to the pull request.

Release Please writes `CHANGELOG.md` from the pull request title. Edit `CHANGELOG.md` by hand only on a release pull request. Update the docs when the change affects them.

## Security

Report a vulnerability privately through [GitHub Security Advisories](https://github.com/ben-ranford/watt/security/advisories/new). Do not put exploit details in a public issue. If that form is unavailable, contact [@ben-ranford](https://github.com/ben-ranford) and ask for a private channel before sending details. This repository has no `SECURITY.md`. The issue chooser lists the bug and feature forms, and vulnerability reports use the advisory link above.

## Names

This repository, its folder, and the Homebrew cask are named `watt`. The Swift package in `Package.swift` is named `Watt`. The running app's display name is Watt?. The public README uses the display name only.

## What the app reads

Watt? is a menu-bar utility (`LSUIElement`). System readings come from IOKit. Public power-source descriptions omit live watt telemetry. Measured battery, charger, and system watts are read from `AppleSmartBattery` registry properties when the hardware exposes them, and the parser fails closed when it does not. The charger row adds the adapter’s rated wattage and name from `AdapterDetails` or `IOPSCopyExternalPowerAdapterDetails`. Time to full and time remaining come from the IOPS time keys when that estimate is a real duration. Missing, zero, and still-calculating values are left out. CPU and GPU estimates are a separate path. They come from `powermetrics`, which the root helper runs. The menu bar can show at most two components, and only CPU and GPU. Display, SSD, and Other are not provided.

A desktop (`batteryState == .noBattery` with battery capability unsupported) has no battery row. The panel title is Drawing, and the detail is the Mac’s own line when it has one, otherwise “No battery, so it’s all draw”.

Release builds require macOS 13.0 or later. The deployment target, the Swift package, and the release check all use that minimum (`LSMinimumSystemVersion` `13.0`, Homebrew `depends_on macos: :ventura`).

Idle-cost notes, including the host samples from 18 Nov 2026, are in [docs/PERFORMANCE.md](docs/PERFORMANCE.md). Those figures are measurements of particular builds. They are not a comparison with other apps.

## Privileged helper

`WattHelper` (`io.github.ben-ranford.watt.helper`) is a launch daemon. The administrator installer places the binary at `/Library/PrivilegedHelperTools/io.github.ben-ranford.watt.helper` and its launchd plist at `/Library/LaunchDaemons/io.github.ben-ranford.watt.helper.plist`. That plist sets `UserName` to `root`. `WattHelperInstaller` does not take privilege itself. An administrator runs it, and macOS then asks you to approve Watt? Helper in Login Items & Extensions.

The helper's sampler runs one fixed command, `/usr/bin/powermetrics` with `-f plist -n 1 -i 1000 -s cpu_power,gpu_power`. It does not accept an executable, arguments, or paths from the app. The helper returns that plist unchanged. The app reads `processor.cpu_power` and `processor.gpu_power` as milliwatts and keeps the sample only when those averages match `cpu_energy` and `gpu_energy` in millijoules across `elapsed_ns`, and `combined_power` matches the cpu, gpu, and ane sum. A missing key, a different unit, or a value above 200 W on one rail leaves both estimates unavailable. CPU and GPU estimates appear only when both are available. Display, SSD, and Other are unavailable. Battery delta, charger input, and system draw come from IOKit power sources and do not need the helper.

A fresh install does not register the helper by itself. Setup and Settings offer **Install Helper…**, which runs the bundled `WattHelperInstaller` and asks for an administrator password. `SMAppService` daemon registration does not write the exact code-hash pins the helper requires, so the app does not use that API for this path. The installer still checks the preflight digest against the staged bytes before it writes anything. Homebrew does not install the helper during `brew install`; the cask only places `Watt.app` in Applications.

Release builds set `WATTHelperTrustMode` to `protected-installation` by expanding `$(WATT_HELPER_TRUST_MODE)` in the app and helper Info.plist before signing. The local Apple Development configuration sets that build setting to `certificate`. The app selects certificate trust only when the compiled value is exactly `certificate`. The helper's XPC requirement is the installed app's cdhash. It does not trust every ad-hoc signature that carries the bundle identifier. A missing or stale pin rejects the caller. It is not replaced with a team requirement or an identifier-only requirement. After an update, that pin changes only when the administrator installer has checked the Ed25519 manifest and the archive SHA-256, or through the reviewed helper-update flow. Both restart the helper with the new record. Certificate trust is the local Apple Development configuration. Distribution preflight rejects it.

The helper's XPC requirement stays the installed app's cdhash. Developer ID puts the team in the code directory, so the cdhash changes on the first signed release even when the rest of the binary would have matched. The in-app updater rotates that pin after the Ed25519 manifest and the archive SHA-256 check. Replacing `Watt.app` by hand, without that installer, leaves the helper rejecting the new hash until **Install Helper…** runs again.

Open at login uses `SMAppService` on the main app. An ad-hoc designated requirement is the cdhash, and the Developer ID designated requirement is the team certificate, so the first launch of a signed build can ask you to allow Watt in Login Items. Later updates keep the same team, so that prompt is once. Notification permission is also tied to the signing identity and can be asked again once. Watt does not request Accessibility or any other TCC permission, and it does not store keychain items.

Administrator commands, protected paths, and recovery are in [HelperInstaller/README.md](HelperInstaller/README.md).

## Developer ID signing

Release archives are signed with the Developer ID Application certificate for team `GUT4TJFVQ2`, the hardened runtime, and a secure timestamp. Nested tools (`WattHelper`, `WattMaintenance`, `WattHelperInstaller`) are signed with that same identity before the app bundle. The app is notarised, and the ticket is stapled to `Watt.app` before the zip, the disk image, and the update tar are packed. The disk image is signed, notarised, and stapled as its own container. A zip cannot carry a staple of its own; the ticket travels inside the app.

Gatekeeper accepts that download. There is no Control-click step, and the README does not document one.

The Homebrew cask does not remove `com.apple.quarantine`. A stapled notarised app launches with that attribute set. A cask published from an older ad-hoc release still has that step until the signed release replaces it.

Local Debug builds stay ad-hoc (`CODE_SIGN_IDENTITY=-`) so they can be built without the Developer ID certificate. The HelperSigned configuration is still the local Apple Development setup. Fork pull requests cannot read the signing secrets and upload an ad-hoc Release artifact. Same-repo pull requests and `main` notarise the Release app.

The release flow is described in [RELEASING.md](RELEASING.md).

## Update verification

The app reads two HTTPS URLs from its Info.plist. Release builds fill `$(WATT_UPDATE_MANIFEST_URL)` and `$(WATT_UPDATE_ARTIFACT_URL)` from `Resources/ReleaseIdentity.json`:

- `https://ben-ranford.github.io/watt/updates/manifest.json`
- `https://ben-ranford.github.io/watt/updates/Watt.tar`

GitHub Pages publishes both files together. The manifest is a `SignedUpdate`: base64 `payload` and base64 `signature`. The payload is the compact JSON `UpdateManifest` (`identity`, `build`, `sha256`, `minimumSystemVersion`, optional `notes`, and optional `rollout`). The signature is Ed25519 over those exact payload bytes. The app checks it with the public key built into that release. The private key is not in this repository. Apple's signature is not the update check. A client that does not know `rollout` still verifies the signature and ignores that field.

A manifest is accepted only when the signature is valid, `identity` is `io.github.ben-ranford.watt`, `build` is a positive integer newer than the installed build, `minimumSystemVersion` is a `MAJOR.MINOR[.PATCH]` version this Mac can run, and the SHA-256 of `Watt.tar` matches `sha256`. A staged `rollout` then keeps an automatic check to the signed cohort. The cohort is a random number stored on this Mac. It is not sent anywhere. **Check for Updates** skips that schedule. A halted release is not offered, and a critical one is offered to every install. Update URLs must be `https`, with no user, password, query, or fragment. Redirects are allowed only when the host stays the same, and only up to three of them. The updater reads the uncompressed ustar of `Watt.app`. The zip and the disk image are downloads for people. They are not the update artifact.

**Check for Updates…** in the menu and **Check for Updates Now** in Settings both use that signed-manifest updater. Automatic checks start on. Up to date and couldn’t-check results use the existing update window. With no privileged-helper record, the app replaces its own bundle. With a helper record, the administrator installer rotates that installation after it checks the same manifest and archive digest, then restarts the helper. The ready window says Watt? quits, updates, and comes back to the menu bar, in about 5 seconds.

The first launch after that update shows **What’s New** once, using the signed release notes. The app remembers that the window appeared as soon as it is shown, so closing the Mac without pressing Done does not bring it back. A fresh install does not show it. The same notes stay available from **What’s New** in the About panel.

There is no analytics and no crash reporter. The helper does not open a network connection. The update fetch is a download of those two URLs. It does not upload a reading.

## Homebrew cask

The cask downloads `Watt-X.Y.Z.zip` from GitHub Releases and installs `Watt.app`. It sets `auto_updates true`, so Homebrew leaves upgrades to Watt. `brew upgrade` does not replace the app unless you pass `--greedy`. The cask moves when a rollout is complete or the release is critical, not while a staged rollout is still in progress. New installs during a rollout get the last complete version, then follow the in-app schedule.

## Site screenshots

`SiteScreenshotTests` renders the images in `docs/screenshots/` from the SwiftUI views with sample power readings. Light appearance, then dark: the menu bar, the panel, and Settings. The README and the landing page show those images. The watt figures in them are the sample, not a measurement of a Mac, and the public pages do not describe the test.

## Build

Building from source needs Xcode with the macOS SDK. Continuous integration runs on the Xcode 27 image because `WattTests` references `NSMenuItem.preferredImageVisibility`, which the macOS 27 SDK declares. Running the installed app does not require Xcode.

From the repository root:

```sh
xcodebuild -project Watt.xcodeproj -scheme Watt -configuration Debug -destination 'platform=macOS' build
```

The Swift package is the development harness for the same sources:

```sh
swift build
swift test
```

`scripts/configure-release-identity.py` applies a reviewed bundle identifier and build number. `scripts/verify-release-readiness.sh` checks one built `.app` without publishing it. Administrator installation of the privileged helper is described in [HelperInstaller/README.md](HelperInstaller/README.md). Signing and publishing are in [RELEASING.md](RELEASING.md).
