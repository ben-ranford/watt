# Watt?

Watt? is a native macOS menu-bar app. It shows what your Mac is drawing or charging, in watts. Open the status item for a short power panel. The secondary-click menu and Settings choose the reading, optional component breakdown, notifications, and helper access.

## Requirements

- macOS 13 or later
- Xcode with the macOS SDK

## Install

Download `Watt-X.Y.Z.zip` or `Watt-X.Y.Z.dmg` from the GitHub Releases page and move Watt into Applications.

Watt is ad-hoc signed and is not notarised, so Gatekeeper blocks the first launch of a zip or disk image. In Finder, Control-click Watt and choose Open, then choose Open. If macOS still blocks it, open System Settings → Privacy & Security and choose Open Anyway.

After a release has published the cask, Homebrew is the other install path:

```sh
brew install ben-ranford/tap/watt
```

The cask downloads the same GitHub Release zip and removes the quarantine attribute after install. Watt then updates itself; `brew upgrade` does not replace it.

## Build and test

From the repository root:

```sh
xcodebuild -project Watt.xcodeproj -scheme Watt -configuration Debug -destination 'platform=macOS' build
```

The Swift package is the development harness for the same sources:

```sh
swift build
swift test
```

`scripts/configure-release-identity.py` applies a reviewed bundle identifier and build number. `scripts/verify-release-readiness.sh` checks one built `.app` without publishing it. Administrator installation of the privileged helper is described in `HelperInstaller/README.md`.

## Support

Watt is free and open source. [GitHub Sponsors](https://github.com/sponsors/ben-ranford) is there for anyone who wants to support development.

## Licence

Watt is released under the [MIT License](LICENSE). Copyright 2026 Benjamin Ranford.
