#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/../../.."
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
out=docs/evidence/J6.4
run() {
    local name="$1"; shift
    local status=0
    "$@" > "$out/$name.log" 2>&1 || status=$?
    echo "$status" > "$out/$name.exit"
    echo "$name: $status"
    return "$status"
}
run focused-tests swift test --filter 'J64InsufficientChargerTests|J63FullOnAdapterTests|J63FixtureTests|J64FixtureTests|J62ChargingHoldTests|J62FixtureTests|J61DarkChargingTests|J61FixtureTests|J52FinishSetupTests|J52FixtureTests|J51WelcomeClosedTests|J18LivePanelTests|J21ComponentsUnavailableTests|J22ComponentsOffTests|NativeStylingTests|F05FixtureTests|AppRouterTests'
run package-tests swift test
run package-build swift build
for configuration in Debug Release; do
    run "host-$configuration" xcodebuild -project Watt.xcodeproj -scheme Watt \
        -configuration "$configuration" -destination 'platform=macOS' \
        -derivedDataPath .build/xcode build analyze
done
run host-focused-tests xcodebuild -project Watt.xcodeproj -scheme Watt -configuration Debug \
    -destination 'platform=macOS' -derivedDataPath .build/xcode test \
    -only-testing:WattTests/J64InsufficientChargerTests -only-testing:WattTests/J64FixtureTests \
    -only-testing:WattTests/J63FullOnAdapterTests -only-testing:WattTests/J63FixtureTests \
    -only-testing:WattTests/J62ChargingHoldTests -only-testing:WattTests/J62FixtureTests \
    -only-testing:WattTests/J61DarkChargingTests -only-testing:WattTests/J61FixtureTests \
    -only-testing:WattTests/J52FinishSetupTests -only-testing:WattTests/J52FixtureTests \
    -only-testing:WattTests/F05FixtureTests -only-testing:WattTests/AppRouterTests \
    -only-testing:WattTests/J51WelcomeClosedTests -only-testing:WattTests/J18LivePanelTests \
    -only-testing:WattTests/J21ComponentsUnavailableTests \
    -only-testing:WattTests/J22ComponentsOffTests -only-testing:WattTests/NativeStylingTests
run host-tests xcodebuild -project Watt.xcodeproj -scheme Watt -configuration Debug \
    -destination 'platform=macOS' -derivedDataPath .build/xcode test -only-testing:WattTests
run fixture-rejection python3 - <<'PY'
from pathlib import Path
import json
import subprocess

app = str(Path('.build/xcode/Build/Products/Debug/Watt.app/Contents/MacOS/Watt').resolve())
checks = []
for arguments in [['--watt-fixture', 'J6.4/unavailable'],
                  ['--watt-fixture', 'J6.4/base/extra'],
                  ['--watt-fixture'],
                  ['--watt-fixture=J6.4/base'],
                  ['--watt-fixture', 'J6.4/base', '--watt-fixture', 'J6.1/base']]:
    result = subprocess.run([app, *arguments], capture_output=True, text=True, timeout=15)
    checks.append({'arguments': arguments, 'exit': result.returncode,
                   'output': result.stdout + result.stderr})
print(json.dumps(checks, indent=2))
assert all(check['exit'] == 1 and 'Watt fixture launch rejected:' in check['output'] for check in checks)
PY
run diff-check python3 docs/evidence/J6.4/diff-check.py
run static-check bash docs/evidence/J6.4/static-check.sh
