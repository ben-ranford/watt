#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/../../.."
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
out=docs/evidence/J7.3
run() {
    local name="$1"; shift
    local status=0
    "$@" > "$out/$name.log" 2>&1 || status=$?
    echo "$status" > "$out/$name.exit"
    echo "$name: $status"
    return "$status"
}
run focused-tests swift test --filter 'J73ChooseComponentsTests|J72PerComponentMenuBarTests|J25SettingsConnectedTests|J71ShowInMenuBarTests|NativeStylingTests|F05FixtureTests|AppRouterTests'
run package-tests swift test
run package-build swift build
for configuration in Debug Release; do
    run "host-$configuration" xcodebuild -project Watt.xcodeproj -scheme Watt \
        -configuration "$configuration" -destination 'platform=macOS' \
        -derivedDataPath .build/xcode build analyze
done
run host-focused-tests xcodebuild -project Watt.xcodeproj -scheme Watt -configuration Debug \
    -destination 'platform=macOS' -derivedDataPath .build/xcode test \
    -only-testing:WattTests/J73ChooseComponentsTests -only-testing:WattTests/J25SettingsConnectedTests \
    -only-testing:WattTests/J72PerComponentMenuBarTests -only-testing:WattTests/J71ShowInMenuBarTests \
    -only-testing:WattTests/NativeStylingTests -only-testing:WattTests/F05FixtureTests \
    -only-testing:WattTests/AppRouterTests
run host-tests xcodebuild -project Watt.xcodeproj -scheme Watt -configuration Debug \
    -destination 'platform=macOS' -derivedDataPath .build/xcode test -only-testing:WattTests
run fixture-rejection python3 - <<'PY'
from pathlib import Path
import json
import subprocess

app = str(Path('.build/xcode/Build/Products/Debug/Watt.app/Contents/MacOS/Watt').resolve())
checks = []
for arguments in [['--watt-fixture', 'J7.3'],
                  ['--watt-fixture', 'J7.3/unavailable'],
                  ['--watt-fixture', 'J7.3/stale'],
                  ['--watt-fixture', 'J7.3/'],
                  ['--watt-fixture', 'J7.3//base'],
                  ['--watt-fixture', 'j7.3/base'],
                  ['--watt-fixture', 'J7.3/base/extra'],
                  ['--watt-fixture'],
                  ['--watt-fixture=J7.3/base'],
                  ['--watt-fixture', 'J7.3/base', '--watt-fixture', 'J6.1/base']]:
    result = subprocess.run([app, *arguments], capture_output=True, text=True, timeout=15)
    checks.append({'arguments': arguments, 'exit': result.returncode,
                   'output': result.stdout + result.stderr})
print(json.dumps(checks, indent=2))
assert all(check['exit'] == 1 and 'Watt fixture launch rejected:' in check['output'] for check in checks)
PY
run diff-check python3 docs/evidence/J7.3/diff-check.py
run static-check bash docs/evidence/J7.3/static-check.sh
