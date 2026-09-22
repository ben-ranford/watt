#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/../../.."
git diff --check
plutil -lint Watt.xcodeproj/project.pbxproj
shasum -a 256 -c docs/evidence/J10.2/reference.sha256
python3 - <<'PY'
from pathlib import Path
s=Path('App/RootSceneView.swift').read_text()
for token in ['LinearGradient', 'Canvas {', '.position(', '.offset(', 'DesktopTemplate', 'NSBezierPath']:
    assert token not in s, token
for token in ['ProgressView()', '.progressViewStyle(.linear)', 'Button("Cancel")', 'router.cancelUpdateCheck()', 'Checking for updates…']:
    assert token in s, token
assert 'Window("Software Update", id: "software-update")' in Path('App/WattApp.swift').read_text()
print('Native scene/progress/button ownership and no absolute positioning checks passed')
PY
