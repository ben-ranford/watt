#!/bin/bash
set -uo pipefail
cd "$(dirname "$0")/../../.."
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
out=docs/evidence/J4.3
result=0
run() {
    local name="$1"; shift
    "$@" > "$out/$name.log" 2>&1
    local status=$?
    echo "$status" > "$out/$name.exit"
    if (( status != 0 )); then result=1; fi
}
run focused-tests swift test --filter 'J43PanelSystemDrawTests|J42ReadingBatteryUnavailableTests|NativeStylingTests|F05FixtureTests|AppRouterTests'
run package-tests swift test
run package-build swift build
for configuration in Debug Release; do
    run "host-$configuration" xcodebuild -project Watt.xcodeproj -scheme Watt         -configuration "$configuration" -destination 'platform=macOS'         -derivedDataPath .build/xcode build analyze
done
run host-tests xcodebuild -project Watt.xcodeproj -scheme Watt -configuration Debug     -destination 'platform=macOS' -derivedDataPath .build/xcode test -only-testing:WattTests
run diff-check git diff --check
exit "$result"
