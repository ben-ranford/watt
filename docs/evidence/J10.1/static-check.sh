#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/../../.."
git diff --check
plutil -lint Watt.xcodeproj/project.pbxproj
shasum -a 256 -c docs/evidence/J10.1/reference.sha256
python3 - <<'PY'
from pathlib import Path
s=Path('Features/MenuBar/Views/StatusItemContextMenu.swift').read_text()
assert 'action: router.showUpdate' not in s
for token in ['LinearGradient', 'NSHostingView', 'draw(', 'NSColor(', 'DesktopTemplate']:
 assert token not in s, token
assert 'NSMenuItemValidation' in s
assert 'router.canCheckForUpdates' in s
print('Native menu ownership / no custom drawing / service validation checks passed')
PY
