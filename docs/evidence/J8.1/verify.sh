#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/../../.."
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
out=docs/evidence/J8.1
run() {
    local name="$1"; shift
    local status=0
    "$@" > "$out/$name.log" 2>&1 || status=$?
    echo "$status" > "$out/$name.exit"
    echo "$name: $status"
    return "$status"
}
run environment xcrun swift --version
run xcode-version xcodebuild -version
run os-version sw_vers
run focused-tests swift test --filter 'J81NoReadingTests|J74CrowdedMenuBarTests|J6[1-5]|J72PerComponentMenuBarTests|C04[89]StatusItemTests|NativeStylingTests|F05FixtureTests|AppRouterTests|P01TelemetryTests'
run package-tests swift test
run package-build swift build
for configuration in Debug Release; do
    run "host-$configuration" xcodebuild -project Watt.xcodeproj -scheme Watt \
        -configuration "$configuration" -destination 'platform=macOS' \
        -derivedDataPath .build/xcode build analyze
done
run host-focused-tests xcodebuild -project Watt.xcodeproj -scheme Watt -configuration Debug \
    -destination 'platform=macOS' -derivedDataPath .build/xcode test \
    -only-testing:WattTests/J81NoReadingTests \
    -only-testing:WattTests/J74CrowdedMenuBarTests \
    -only-testing:WattTests/J61DarkChargingTests \
    -only-testing:WattTests/J61FixtureTests \
    -only-testing:WattTests/J62ChargingHoldTests \
    -only-testing:WattTests/J62FixtureTests \
    -only-testing:WattTests/J63FullOnAdapterTests \
    -only-testing:WattTests/J63FixtureTests \
    -only-testing:WattTests/J64InsufficientChargerTests \
    -only-testing:WattTests/J64FixtureTests \
    -only-testing:WattTests/J65OnBatteryTests \
    -only-testing:WattTests/J65FixtureTests \
    -only-testing:WattTests/J72PerComponentMenuBarTests \
    -only-testing:WattTests/C048StatusItemTests \
    -only-testing:WattTests/C049StatusItemTests \
    -only-testing:WattTests/NativeStylingTests \
    -only-testing:WattTests/F05FixtureTests \
    -only-testing:WattTests/AppRouterTests \
    -only-testing:WattTests/P01TelemetryTests
run host-tests xcodebuild -project Watt.xcodeproj -scheme Watt -configuration Debug \
    -destination 'platform=macOS' -derivedDataPath .build/xcode test -only-testing:WattTests
run fixture-rejection python3 - <<'PY'
from pathlib import Path
import json
import subprocess

app = str(Path('.build/xcode/Build/Products/Debug/Watt.app/Contents/MacOS/Watt').resolve())
checks = []
for arguments in [['--watt-fixture', 'J8.1'],
                  ['--watt-fixture', 'J8.1/unavailable'],
                  ['--watt-fixture', 'J8.1/stale'],
                  ['--watt-fixture', 'J8.1/'],
                  ['--watt-fixture', 'J8.1//base'],
                  ['--watt-fixture', 'j8.1/base'],
                  ['--watt-fixture', 'J8.1/base/extra'],
                  ['--watt-fixture'],
                  ['--watt-fixture=J8.1/base'],
                  ['--watt-fixture', 'J8.1/base', '--watt-fixture', 'J6.1/base']]:
    result = subprocess.run([app, *arguments], capture_output=True, text=True, timeout=15)
    checks.append({'arguments': arguments, 'exit': result.returncode,
                   'output': result.stdout + result.stderr})
print(json.dumps(checks, indent=2))
assert all(check['exit'] == 1 and 'Watt fixture launch rejected:' in check['output'] for check in checks)
PY
run diff-check python3 docs/evidence/J8.1/diff-check.py
run static-check bash docs/evidence/J8.1/static-check.sh
