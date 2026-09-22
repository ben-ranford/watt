#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/../../.."
git diff --check
plutil -lint Watt.xcodeproj/project.pbxproj
shasum -a 256 -c docs/evidence/J12.3/reference.sha256
python3 - <<'PY'
from pathlib import Path
import subprocess
s=Path('App/J123FixtureLaunch.swift').read_text()
assert s.startswith('#if DEBUG')
for token in ['NSWindow(', 'NSStatusItem(', 'DesktopTemplate', 'Wallpaper', 'Color(']:
    assert token not in s, token
binary='build/J123-Release/Build/Products/Release/Watt.app/Contents/MacOS/Watt'
for command in [['nm',binary], ['strings',binary]]:
    output=subprocess.check_output(command,text=True)
    for token in ['J123FixtureLaunch','J12.3/base','FixtureLaunchSelection']:
        assert token not in output, token
print('PASS: no replacement desktop UI; Release fixture isolation')
PY
