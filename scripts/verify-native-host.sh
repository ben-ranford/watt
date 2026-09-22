#!/bin/bash
# Run from a logged-in macOS graphical session with Xcode UI automation access.
set -euo pipefail
cd "$(dirname "$0")/.."
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
output="${1:-.build/native-host/$(date -u +%Y%m%dT%H%M%SZ)}"
mkdir -p "$output"
output="$(cd "$output" && pwd)"
exec > >(tee "$output/verification.log") 2>&1
set -x
xcodebuild -version
sw_vers
system_profiler SPDisplaysDataType
defaults read -g AppleInterfaceStyle || true
xcodebuild -list -project Watt.xcodeproj
args=(-project Watt.xcodeproj -scheme Watt -configuration Debug -destination 'platform=macOS' -derivedDataPath .build/xcode)
xcodebuild "${args[@]}" build
test_status=0
xcodebuild "${args[@]}" test -parallel-testing-enabled NO -test-timeouts-enabled YES -maximum-test-execution-time-allowance 120 -resultBundlePath "$output/Host.xcresult" || test_status=$?
if [[ -d "$output/Host.xcresult" ]]; then
  xcrun xcresulttool export attachments --path "$output/Host.xcresult" --output-path "$output/attachments"
fi
exit "$test_status"
