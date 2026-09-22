#!/bin/bash
# Non-privileged, window-only smoke capture. Never invokes the XCTest UI runner.
set -euo pipefail
cd "$(dirname "$0")/.."
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
output="${1:-.build/native-capture/$(date -u +%Y%m%dT%H%M%SZ)}"
mkdir -p "$(dirname "$output")"
mkdir "$output" # Fail on reuse: stale PNGs must not pass verification.
output="$(cd "$output" && pwd)"
exec > >(tee "$output/verification.log") 2>&1
xcrun swiftc scripts/capture-native-panel.swift -o "$output/capture-window"
"$output/capture-window" --preflight
xcodebuild -version
xcodebuild -project Watt.xcodeproj -scheme Watt -configuration Debug \
  -destination 'platform=macOS' -derivedDataPath .build/xcode build > "$output/build.log" 2>&1
app="$PWD/.build/xcode/Build/Products/Debug/Watt.app/Contents/MacOS/Watt"
"$app" --watt-capture-status-panel > "$output/app.log" 2>&1 &
pid=$!
cleanup() {
  kill -TERM "$pid" 2>/dev/null || true
  wait "$pid" 2>/dev/null || true
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM
"$output/capture-window" "$pid" "$output"
shasum -a 256 "$output/status-panel.png" > "$output/status-panel.sha256"
