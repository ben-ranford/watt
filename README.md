# Watt?

Watt? is a native macOS menu-bar app. It shows what your Mac is drawing or charging, in watts. Open the status item for a short power panel. The secondary-click menu and Settings choose the reading, optional component breakdown, notifications, and helper access.

## Requirements

- macOS 13 or later
- Xcode with the macOS SDK

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

## Licence

A licence has not been chosen yet. All rights reserved until one is added to this repository.
