#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/../../.."
git diff --check
plutil -lint Watt.xcodeproj/project.pbxproj
shasum -a 256 -c docs/evidence/J12.5/reference.sha256
python3 - <<'PY'
from pathlib import Path
import subprocess
source=Path('App/LeftoverHelperPresentation.swift').read_text()
assert 'NSAlert()' in source
for forbidden in ['NSAppearance', '.tint(', '.background(', '.frame(', 'NSVisualEffectView', 'NSHostingView', 'alert.icon =']:
    assert forbidden not in source, forbidden
assert Path('App/J125FixtureLaunch.swift').read_text().startswith('#if DEBUG')
binary='build/J125-Release/Build/Products/Release/Watt.app/Contents/MacOS/Watt'
for command in [['nm',binary],['strings',binary]]:
    output=subprocess.check_output(command,text=True)
    for token in ['J125FixtureLaunch', 'J12.5/base', 'FixtureLaunchSelection']:
        assert token not in output, token
print('PASS native styling and Release fixture isolation')
PY
