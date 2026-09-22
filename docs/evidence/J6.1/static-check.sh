#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/../../.."
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
bash -n docs/evidence/J6.1/capture.sh docs/evidence/J6.1/verify.sh docs/evidence/J6.1/static-check.sh
xcrun swiftc -typecheck docs/evidence/J6.1/capture-window.swift
python3 - <<'PY'
import ast
import hashlib
import json
from pathlib import Path

root = Path('docs/evidence/J6.1')
ast.parse((root / 'diff-check.py').read_text())
for name in ('reference.json', 'verification.json', 'visual-review.json'):
    json.loads((root / name).read_text())
reference = json.loads((root / 'reference.json').read_text())
assert reference['node'] == '31:2745'
assert reference['appearance'] == 'darkAqua'
assert reference['sha256'] == hashlib.sha256((root / 'reference.png').read_bytes()).hexdigest()
panel = Path('Features/MenuBar/Views/StatusPanelView.swift').read_text()
for token in ('struct StatusPanelModel', 'struct StatusPanelView', 'includesComponents',
              'Form {', 'LabeledContent {', '.formStyle(.grouped)', '.buttonStyle(.borderless)',
              'Button("Settings…", action: onSettings)', 'Button("Quit Watt?", action: onQuit)'):
    assert token in panel, f'Missing shared native panel contract: {token}'
for token in ('RoundedRectangle(', 'LinearGradient(', 'RadialGradient(', 'NSVisualEffectView', '.background('):
    assert token not in panel, f'Unexpected custom panel chrome: {token}'
app = Path('App/WattApp.swift').read_text()
for token in ('enum J61FixtureLaunch', 'selection.stableID == "J6.1/base"',
              'class StatusAnchorView', 'MenuBarExtra', '.menuBarExtraStyle(.window)'):
    assert token in app, f'Missing production fixture bridge: {token}'
fixture = app.split('enum J61FixtureLaunch', 1)[1].split('\n#endif', 1)[0]
for token in ('darkAqua', 'sampleCharging', 'InMemoryStorage'):
    assert token in fixture, f'Missing deterministic dark fixture contract: {token}'
capture = (root / 'capture-window.swift').read_text()
for token in ('CGPreflightScreenCaptureAccess()', 'AXIsProcessTrusted()',
              'kCGWindowOwnerPID', 'AXUIElementCreateApplication(pid)',
              '"score": NSNull()', '"pixel_diff": NSNull()', 'stillOwned()'):
    assert token in capture, f'Missing honest compositor capture gate: {token}'
for token in ('CGRequestScreenCaptureAccess', 'AXIsProcessTrustedWithOptions', '.cacheDisplay('):
    assert token not in capture, f'Forbidden capture fallback/permission request: {token}'
print('J6.1 shared native panel, exact dark fixture, reference digest, honest capture and script checks passed')
PY
