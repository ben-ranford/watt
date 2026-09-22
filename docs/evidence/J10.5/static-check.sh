#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/../../.."
git diff --check
plutil -lint Watt.xcodeproj/project.pbxproj
shasum -a 256 -c docs/evidence/J10.5/reference.sha256
python3 - <<'PY'
from pathlib import Path
import subprocess
s=Path('App/RootSceneView.swift').read_text().split('#if DEBUG')[0]
for token in ['.preferredColorScheme(', '.tint(', '.system(size:', '.frame(height:', '.controlSize(', '.cornerRadius(', 'RoundedRectangle', 'LinearGradient', 'NSVisualEffectView', 'Canvas {', '.offset(', '.position(']:
    assert token not in s, token
for token in ['ProgressView(value:', '.buttonStyle(.bordered)', 'WattTypography.bodyEmphasized', 'WattTypography.footnote', 'Ready to install', 'Button("Later")', 'Button("Install and Relaunch")', '.buttonStyle(.borderedProminent)']:
    assert token in s, token
binary='build/J105-Release/Build/Products/Release/Watt.app/Contents/MacOS/Watt'
for command in [['nm',binary], ['strings',binary]]:
    output=subprocess.check_output(command,text=True)
    for token in ['J105FixtureLaunch','J10.5/base','FixtureLaunchSelection']:
        assert token not in output, token
print('PASS: native appearance/type/controls, reference checksum, Release fixture symbols/selectors absent')
PY
