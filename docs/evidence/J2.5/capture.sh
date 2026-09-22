#!/bin/bash
# Native window only; never request permissions or capture unrelated applications.
set -euo pipefail
cd "$(dirname "$0")/../../.."
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
xcrun swiftc docs/evidence/J2.5/capture.swift -o /tmp/watt-j25-native
app=.build/j25-host/Build/Products/Debug/Watt.app/Contents/MacOS/Watt
"$app" --watt-fixture J2.5/base -AppleInterfaceStyle Light > docs/evidence/J2.5/fixture-launch.log 2>&1 &
pid=$!
trap 'kill "$pid" 2>/dev/null || true; wait "$pid" 2>/dev/null || true' EXIT
/tmp/watt-j25-native "$pid" docs/evidence/J2.5/actual-settings.png > docs/evidence/J2.5/capture.log 2>&1
