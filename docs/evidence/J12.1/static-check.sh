#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/../../.."
git diff --check
plutil -lint Watt.xcodeproj/project.pbxproj
shasum -a 256 -c docs/evidence/J12.1/reference.sha256
python3 - <<'PY'
from pathlib import Path
import subprocess
s=Path('Features/Settings/Views/SettingsRootView.swift').read_text()
for token in ['RoundedRectangle', '.tint(', '.preferredColorScheme(', 'NSWindow(']:
    assert token not in s, token
for token in ['Form {', 'Section("General")', 'Button("Uninstall…", role: .destructive)', 'router.requestUninstall', '.formStyle(.grouped)']:
    assert token in s, token
binary='build/J121-Release/Build/Products/Release/Watt.app/Contents/MacOS/Watt'
for command in [['nm',binary], ['strings',binary]]:
    output=subprocess.check_output(command,text=True)
    for token in ['J121FixtureLaunch','J12.1/base','FixtureLaunchSelection']:
        assert token not in output, token
print('PASS: native Settings semantics and Release fixture isolation')
PY
