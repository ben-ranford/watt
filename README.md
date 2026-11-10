# watt

[![standard-readme compliant](https://img.shields.io/badge/readme%20style-standard-brightgreen.svg?style=flat-square)](https://github.com/RichardLitt/standard-readme)
[![Build and test](https://github.com/ben-ranford/watt/actions/workflows/ci.yml/badge.svg)](https://github.com/ben-ranford/watt/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

Native macOS menu-bar power monitor, built in SwiftUI

This repository, its folder, and the Homebrew cask are named `watt`. The Swift package in `Package.swift` is named `Watt`. The running app's display name is Watt?.

Watt? sits in the menu bar and shows what the Mac is drawing or charging, in watts. Click the status item for a short power panel. The secondary-click menu and Settings choose the reading, optional CPU and GPU estimates, notifications, and helper access.

## Table of Contents

- [Security](#security)
  - [Privileged helper](#privileged-helper)
  - [Ad-hoc signing](#ad-hoc-signing)
  - [Update verification](#update-verification)
  - [Reporting a vulnerability](#reporting-a-vulnerability)
- [Background](#background)
- [Install](#install)
  - [Dependencies](#dependencies)
  - [Homebrew](#homebrew)
  - [Download](#download)
  - [Updating](#updating)
- [Usage](#usage)
- [Build](#build)
- [Support](#support)
- [Maintainers](#maintainers)
- [Contributing](#contributing)
- [License](#license)

## Security

Releases are ad-hoc signed and are not notarised. A root helper supplies Apple's CPU and GPU power estimates. The app accepts an update only after it checks an Ed25519 signature and the archive digest.

### Privileged helper

`WattHelper` (`io.github.ben-ranford.watt.helper`) is a launch daemon. The administrator installer places the binary at `/Library/PrivilegedHelperTools/io.github.ben-ranford.watt.helper` and its launchd plist at `/Library/LaunchDaemons/io.github.ben-ranford.watt.helper.plist`. That plist sets `UserName` to `root`. `WattHelperInstaller` does not take privilege itself. An administrator runs it, and macOS then asks you to approve Watt? Helper in Login Items & Extensions.

The helper's sampler runs one fixed command, `/usr/bin/powermetrics` with `-f plist -n 1 -i 1000 -s cpu_power,gpu_power`. It does not accept an executable, arguments, or paths from the app. CPU and GPU estimates appear only when both are available. Display, SSD, and Other are unavailable. Battery delta, charger input, and system draw come from IOKit power sources and do not need the helper.

Release builds set `WATTHelperTrustMode` to `protected-installation`. The helper's XPC requirement is the installed app's cdhash. It does not trust every ad-hoc signature that carries the bundle identifier. A missing or stale pin rejects the caller. It is not replaced with a team requirement or an identifier-only requirement. After an update, that pin changes only when the administrator installer has checked the Ed25519 manifest and the archive SHA-256, or through the reviewed helper-update flow. Both restart the helper with the new record. Certificate trust is the local Apple Development configuration. Distribution preflight rejects it.

Administrator commands, protected paths, and recovery are in [HelperInstaller/README.md](HelperInstaller/README.md).

### Ad-hoc signing

Release archives are signed with `CODE_SIGN_IDENTITY=-` and the hardened runtime. They are not Developer ID signed and they are not notarised. Gatekeeper therefore blocks the first launch of a zip or disk image downloaded from GitHub Releases. The steps are under [Download](#download).

The Homebrew cask removes `com.apple.quarantine` from the installed `Watt.app` after install, so that first-launch block does not apply to a cask install.

### Update verification

The app reads two HTTPS URLs compiled from `Resources/ReleaseIdentity.json`:

- `https://ben-ranford.github.io/watt/updates/manifest.json`
- `https://ben-ranford.github.io/watt/updates/Watt.tar`

GitHub Pages publishes both files together. The manifest is a `SignedUpdate`: base64 `payload` and base64 `signature`. The payload is the compact JSON `UpdateManifest` (`identity`, `build`, `sha256`, `minimumSystemVersion`). The signature is Ed25519 over those exact payload bytes. The app checks it with the public key built into that release. The private key is not in this repository.

A manifest is accepted only when the signature is valid, `identity` is `io.github.ben-ranford.watt`, `build` is a positive integer newer than the installed build, `minimumSystemVersion` is a `MAJOR.MINOR[.PATCH]` version this Mac can run, and the SHA-256 of `Watt.tar` matches `sha256`. Update URLs must be `https`, with no user, password, query, or fragment. Redirects are allowed only when the host stays the same, and only up to three of them. The updater reads the uncompressed ustar of `Watt.app`. The zip and the disk image are downloads for people. They are not the update artifact.

The release flow is described in [RELEASING.md](RELEASING.md).

### Reporting a vulnerability

Report a vulnerability privately through [GitHub Security Advisories](https://github.com/ben-ranford/watt/security/advisories/new). Do not put exploit details in a public issue. If that form is unavailable, contact [@ben-ranford](https://github.com/ben-ranford) and ask for a private channel before sending details.

## Background

Watt? is a native SwiftUI menu-bar utility (`LSUIElement`). It exists to show Mac power in watts from the status item: battery delta, charger input, and system draw, plus optional CPU and GPU estimates.

System readings come from IOKit. Public power-source descriptions omit live watt telemetry. Measured battery, charger, and system watts are read from `AppleSmartBattery` registry properties when the hardware exposes them, and the parser fails closed when it does not. CPU and GPU estimates are a separate path. They come from `powermetrics`, which the root helper runs. The menu bar can show at most two components, and only CPU and GPU. Display, SSD, and Other are not provided.

See also [RELEASING.md](RELEASING.md) for how a release is signed and published, and [HelperInstaller/README.md](HelperInstaller/README.md) for the administrator installer.

## Install

### Dependencies

Watt requires macOS 13.0 or later. The deployment target, the Swift package, and the release check all use that minimum (`LSMinimumSystemVersion` `13.0`, Homebrew `>= :ventura`).

Building from source needs Xcode with the macOS SDK. Continuous integration runs on the Xcode 27 image because `WattTests` references `NSMenuItem.preferredImageVisibility`, which the macOS 27 SDK declares. Running the installed app does not require Xcode.

### Homebrew

The cask `watt` is published from [ben-ranford/homebrew-tap](https://github.com/ben-ranford/homebrew-tap).

```sh
brew install --cask ben-ranford/tap/watt
```

The cask downloads `Watt-X.Y.Z.zip` from GitHub Releases, installs `Watt.app`, and removes the quarantine attribute in `postflight`. It sets `auto_updates true`, so Homebrew leaves upgrades to Watt. `brew upgrade` does not replace the app unless you pass `--greedy`.

### Download

Download `Watt-X.Y.Z.zip` or `Watt-X.Y.Z.dmg` from the [GitHub Releases](https://github.com/ben-ranford/watt/releases) page and move Watt into Applications.

Watt is ad-hoc signed and is not notarised, so Gatekeeper blocks the first launch of a zip or disk image. In Finder, Control-click Watt and choose Open, then choose Open. If macOS still blocks it, open System Settings → Privacy & Security and choose Open Anyway.

### Updating

**Check for Updates…** is in the secondary-click menu. Automatic checks start on, and Settings can turn them off. The app downloads the signed manifest and `Watt.tar` described under [Update verification](#update-verification). With no privileged-helper record, it replaces its own bundle. With a helper record, the administrator installer rotates that installation after it checks the same manifest and archive digest, then restarts the helper. The ready window says Watt? quits, updates, and comes back to the menu bar, in about 5 seconds.

## Usage

Launch the installed app:

```sh
open -a Watt
```

Watt? has no Dock icon. Click the menu-bar item for the power panel. Secondary-click it for the menu:

- **Show in Menu Bar** chooses Battery Delta (the default), Charger Input, System Draw, Per Component, or Icon Only. Per Component stays off until the helper is approved and both CPU and GPU estimates are available. Icon Only keeps the item in place when the menu bar is full.
- **Open Watt?** opens the panel. **Settings…** (Command-,) opens settings. **About Watt?**, **Check for Updates…**, and **Quit Watt?** (Command-Q) are on the same menu.

Settings can set the reading, whether a symbol is shown, precision (`42 W`, `42.1 W`, or `42.10 W`), the update interval (every second, every 2 seconds, or every 5 seconds), and smooth readings. Smooth readings average the last 5 seconds. Notifications cover a charger that cannot keep up for 5 minutes, and a full charge. Open at login is available from the same window. Component readings, when the helper is connected, are CPU and GPU only.

## Build

From the repository root:

```sh
xcodebuild -project Watt.xcodeproj -scheme Watt -configuration Debug -destination 'platform=macOS' build
```

The Swift package is the development harness for the same sources:

```sh
swift build
swift test
```

`scripts/configure-release-identity.py` applies a reviewed bundle identifier and build number. `scripts/verify-release-readiness.sh` checks one built `.app` without publishing it. Administrator installation of the privileged helper is described in [HelperInstaller/README.md](HelperInstaller/README.md).

## Support

Watt is free and open source. [GitHub Sponsors](https://github.com/sponsors/ben-ranford) is there for anyone who wants to support development.

## Maintainers

[@ben-ranford](https://github.com/ben-ranford)

## Contributing

Questions and bug reports go in [GitHub issues](https://github.com/ben-ranford/watt/issues). Pull requests are welcome. Open one against `main`.

This repository uses [Conventional Commits](https://www.conventionalcommits.org/en/v1.0.0/) because [Release Please](https://github.com/googleapis/release-please) cuts releases from them. `fix:` is a patch, `feat:` is a minor, and `feat!:` or `BREAKING CHANGE` is a major. `ci:` and `chore:` do not bump the version. The release steps are in [RELEASING.md](RELEASING.md).

## License

[MIT](LICENSE) © 2026 Benjamin Ranford
