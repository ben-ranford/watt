#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/../../.."
git diff --check
plutil -lint Watt.xcodeproj/project.pbxproj
shasum -a 256 -c docs/evidence/J10.3/reference.sha256
python3 - <<'PY'
from pathlib import Path
s=Path('App/RootSceneView.swift').read_text()
for token in ['LinearGradient', 'Canvas {', '.position(', '.offset(', 'DesktopTemplate', 'NSBezierPath']:
    assert token not in s, token
for token in ['Form {', '.formStyle(.grouped)', '.toggleStyle(.checkbox)', '.buttonStyle(.borderedProminent)', 'Image("WattAppIcon")', 'A new version of Watt? is available', 'What’s New in', 'Neural Engine', 'Now in Components.', 'Steadier numbers', 'Less jumping when load spikes.', 'New helper', 'macOS asks you to approve it once.', 'Install future updates automatically', 'Skip This Version', 'Remind Me Later', 'Install Update']:
    assert token in s, token
assert 'Window("Software Update", id: "software-update")' in Path('App/WattApp.swift').read_text()
r=Path('App/AppRouter.swift').read_text().split('func chooseUpdateOffer')[1].split('init(')[0]
for token in ['.download(', '.install(', '.recover(', 'OperationReceipt(']: assert token not in r
print('Native ownership/copy and intent-only effect boundary checks passed')
PY
python3 - <<'PY'
import subprocess
binary='build/J103-Release/Build/Products/Release/Watt.app/Contents/MacOS/Watt'
symbols=subprocess.check_output(['nm',binary],text=True)
assert 'J103FixtureLaunch' not in symbols
print('Release J103 fixture symbols absent')
PY
