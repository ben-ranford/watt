#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/../../.."
git diff --check
plutil -lint Watt.xcodeproj/project.pbxproj
shasum -a 256 -c docs/evidence/J10.8/reference.sha256
python3 - <<'PY'
from pathlib import Path
import subprocess
s=Path('App/HelperUpdatePresentation.swift').read_text()
for token in ['.tint(', '.appearance =', '.preferredColorScheme(', 'NSVisualEffectView', 'RoundedRectangle', 'alert.icon =']:
    assert token not in s, token
for token in ['NSAlert()', '.informational', 'alert.runModal()', 'presentationID ==', 'token == generation']:
    assert token in s, token
binary='build/J108-Release/Build/Products/Release/Watt.app/Contents/MacOS/Watt'
for command in [['nm',binary], ['strings',binary]]:
    output=subprocess.check_output(command,text=True)
    for token in ['J108FixtureLaunch','J10.8/base','FixtureLaunchSelection']:
        assert token not in output, token
print('PASS: native alert, scoped state, Release fixture isolation')
PY
