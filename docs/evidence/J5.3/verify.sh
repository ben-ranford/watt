#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/../../.."
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
out=docs/evidence/J5.3
run() {
    local name="$1"; shift
    local status=0
    "$@" > "$out/$name.log" 2>&1 || status=$?
    echo "$status" > "$out/$name.exit"
    echo "$name: $status"
    return "$status"
}
run focused-tests swift test --filter 'J53FinishSetupTests|J53FixtureTests|J52FinishSetupTests|J52FixtureTests|J51WelcomeClosedTests|J18LivePanelTests|J21ComponentsUnavailableTests|J22ComponentsOffTests|NativeStylingTests|F05FixtureTests|AppRouterTests'
run package-tests swift test
run package-build swift build
for configuration in Debug Release; do
    run "host-$configuration" xcodebuild -project Watt.xcodeproj -scheme Watt \
        -configuration "$configuration" -destination 'platform=macOS' \
        -derivedDataPath .build/xcode build analyze
done
run host-focused-tests xcodebuild -project Watt.xcodeproj -scheme Watt -configuration Debug \
    -destination 'platform=macOS' -derivedDataPath .build/xcode test \
    -only-testing:WattTests/J53FinishSetupTests -only-testing:WattTests/J53FixtureTests \
    -only-testing:WattTests/J52FinishSetupTests -only-testing:WattTests/J52FixtureTests \
    -only-testing:WattTests/F05FixtureTests -only-testing:WattTests/AppRouterTests \
    -only-testing:WattTests/J51WelcomeClosedTests -only-testing:WattTests/J18LivePanelTests \
    -only-testing:WattTests/J21ComponentsUnavailableTests \
    -only-testing:WattTests/J22ComponentsOffTests -only-testing:WattTests/NativeStylingTests
run host-tests xcodebuild -project Watt.xcodeproj -scheme Watt -configuration Debug \
    -destination 'platform=macOS' -derivedDataPath .build/xcode test -only-testing:WattTests
run diff-check python3 docs/evidence/J5.3/diff-check.py
run static-check bash docs/evidence/J5.3/static-check.sh
