#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/../../.."
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
out=docs/evidence/J7.1
run() {
    local name="$1"; shift
    local status=0
    "$@" > "$out/$name.log" 2>&1 || status=$?
    echo "$status" > "$out/$name.exit"
    echo "$name: $status"
    return "$status"
}
run focused-tests swift test --filter 'J71ShowInMenuBarTests|J53FinishSetupTests|NativeStylingTests|F05FixtureTests|AppRouterTests'
run package-tests swift test
run package-build swift build
for configuration in Debug Release; do
    run "host-$configuration" xcodebuild -project Watt.xcodeproj -scheme Watt \
        -configuration "$configuration" -destination 'platform=macOS' \
        -derivedDataPath .build/xcode build analyze
done
run host-focused-tests xcodebuild -project Watt.xcodeproj -scheme Watt -configuration Debug \
    -destination 'platform=macOS' -derivedDataPath .build/xcode test \
    -only-testing:WattTests/J71ShowInMenuBarTests -only-testing:WattTests/J53FinishSetupTests \
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
for arguments in [['--watt-fixture', 'J7.1/unavailable'],
                  ['--watt-fixture', 'J7.1/stale'],
                  ['--watt-fixture', 'J7.1/'],
                  ['--watt-fixture', 'J7.1//base'],
                  ['--watt-fixture', 'j7.1/base'],
                  ['--watt-fixture', 'J7.1/base/extra'],
                  ['--watt-fixture'],
                  ['--watt-fixture=J7.1/base'],
                  ['--watt-fixture', 'J7.1/base', '--watt-fixture', 'J6.1/base']]:
    result = subprocess.run([app, *arguments], capture_output=True, text=True, timeout=15)
    checks.append({'arguments': arguments, 'exit': result.returncode,
                   'output': result.stdout + result.stderr})
print(json.dumps(checks, indent=2))
assert all(check['exit'] == 1 and 'Watt fixture launch rejected:' in check['output'] for check in checks)
PY
run diff-check python3 docs/evidence/J7.1/diff-check.py
run static-check bash docs/evidence/J7.1/static-check.sh
