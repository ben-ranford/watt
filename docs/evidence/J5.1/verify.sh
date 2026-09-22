#!/bin/bash
set -uo pipefail
cd "$(dirname "$0")/../../.."
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
out=docs/evidence/J5.1
result=0
run() {
    local name="$1"; shift
    "$@" > "$out/$name.log" 2>&1
    local status=$?
    echo "$status" > "$out/$name.exit"
    echo "$name: $status"
    if (( status != 0 )); then result=1; fi
}
run focused-tests swift test --filter 'J51WelcomeClosedTests|J17CoachMarkTests|J41WelcomeDesktopTests|NativeStylingTests|F05FixtureTests|AppRouterTests'
run package-tests swift test
run package-build swift build
for configuration in Debug Release; do
    run "host-$configuration" xcodebuild -project Watt.xcodeproj -scheme Watt \
        -configuration "$configuration" -destination 'platform=macOS' \
        -derivedDataPath .build/xcode build analyze
done
run host-focused-tests xcodebuild -project Watt.xcodeproj -scheme Watt -configuration Debug \
    -destination 'platform=macOS' -derivedDataPath .build/xcode test \
    -only-testing:WattTests/J51WelcomeClosedTests -only-testing:WattTests/J17CoachMarkTests \
    -only-testing:WattTests/J41WelcomeDesktopTests -only-testing:WattTests/NativeStylingTests
run host-tests xcodebuild -project Watt.xcodeproj -scheme Watt -configuration Debug \
    -destination 'platform=macOS' -derivedDataPath .build/xcode test -only-testing:WattTests
run diff-check python3 docs/evidence/J5.1/diff-check.py
exit "$result"
