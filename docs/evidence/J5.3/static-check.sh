#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/../../.."
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
bash -n docs/evidence/J5.3/capture.sh docs/evidence/J5.3/verify.sh docs/evidence/J5.3/static-check.sh
xcrun swiftc -typecheck docs/evidence/J5.3/capture-window.swift
python3 - <<'PY'
import ast
import json
from pathlib import Path

root = Path('docs/evidence/J5.3')
ast.parse((root / 'diff-check.py').read_text())
for name in ('reference.json', 'verification.json', 'visual-review.json'):
    json.loads((root / name).read_text())
menu = Path('Features/MenuBar/Views/StatusItemContextMenu.swift').read_text()
for token in ('NSMenu', 'NSMenuItem', '.separator()', 'parent.submenu = readings',
              'Finish Setup…', 'Show in Menu Bar', 'Open Watt?', 'Settings…',
              'About Watt?', 'Check for Updates…', 'Quit Watt?',
              'key: ","', 'key: "q"', 'finishSetupFromMenu', 'presentationID: presentationID'):
    assert token in menu, f'Missing native menu contract: {token}'
for token in ('NSHostingView', 'NSVisualEffectView', '.view =', 'draw('):
    assert token not in menu, f'Unexpected custom menu presentation: {token}'
app = Path('App/WattApp.swift').read_text()
for token in ('enum J53FixtureLaunch', 'selection.stableID == "J5.3/base"',
              'class StatusAnchorView', 'func openContextMenuFixture()', 'menu.popUp('):
    assert token in app, f'Missing production fixture bridge: {token}'
capture = (root / 'capture-window.swift').read_text()
for token in ('CGPreflightScreenCaptureAccess()', 'AXIsProcessTrusted()',
              'kCGWindowOwnerPID', 'NSPopupMenuWindow', 'capture-attempt.json',
              '"score": NSNull()', '"pixel_diff": NSNull()'):
    assert token in capture, f'Missing honest compositor capture gate: {token}'
for token in ('CGRequestScreenCaptureAccess', 'AXIsProcessTrustedWithOptions', '.cacheDisplay('):
    assert token not in capture, f'Forbidden capture fallback/permission request: {token}'
print('J5.3 native menu, exact fixture, honest capture, script syntax and JSON checks passed')
PY
