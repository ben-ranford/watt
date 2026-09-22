#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/../../.."
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
bash -n docs/evidence/J6.3/capture.sh docs/evidence/J6.3/verify.sh docs/evidence/J6.3/static-check.sh
xcrun swiftc -typecheck docs/evidence/J6.3/capture-window.swift
python3 - <<'PY'
import ast
import hashlib
import json
import subprocess
from pathlib import Path

root = Path('docs/evidence/J6.3')
ast.parse((root / 'diff-check.py').read_text())
for name in ('reference.json', 'verification.json', 'visual-review.json'):
    json.loads((root / name).read_text())
reference = json.loads((root / 'reference.json').read_text())
assert reference['node'] == '31:4355'
assert reference['figmaFile'] == '9DKDgUfEqidZdZQEVlQgLS'
assert reference['selectedStatusItem'] == '0.0 W'
assert reference['componentsVisible'] is False
assert reference['sha256'] == '13696607c0ea717fd3476b8355bcdbbd1cd77c8d2f7530648ac359632bd9d813'
assert reference['appearance'] == 'darkAqua'
assert reference['sha256'] == hashlib.sha256((root / 'reference.png').read_bytes()).hexdigest()
panel = Path('Features/MenuBar/Views/StatusPanelView.swift').read_text()
for token in ('struct StatusPanelModel', 'struct StatusPanelView', 'includesComponents',
              'StatusPanelState', 'hasFullOnAdapter',
              'Full', '100% · running straight off the charger',
              'Form {', 'LabeledContent {', '.formStyle(.grouped)', '.buttonStyle(.borderless)',
              'Button("Settings…", action: onSettings)', 'Button("Quit Watt?", action: onQuit)'):
    assert token in panel, f'Missing shared native panel contract: {token}'
for token in ('RoundedRectangle(', 'LinearGradient(', 'RadialGradient(', 'NSVisualEffectView', '.background('):
    assert token not in panel, f'Unexpected custom panel chrome: {token}'
app = Path('App/WattApp.swift').read_text()
for token in ('enum J63FixtureLaunch', 'selection.stableID == "J6.3/base"',
              'class StatusAnchorView', 'MenuBarExtra', '.menuBarExtraStyle(.window)'):
    assert token in app, f'Missing production fixture bridge: {token}'
fixture = app.split('enum J63FixtureLaunch', 1)[1].split('\n#endif', 1)[0]
for token in ('darkAqua', 'sampleFullOnAdapter', 'InMemoryStorage'):
    assert token in fixture, f'Missing deterministic dark fixture contract: {token}'
capture = (root / 'capture-window.swift').read_text()
for token in ('CGPreflightScreenCaptureAccess()', 'AXIsProcessTrusted()',
              'kCGWindowOwnerPID', 'AXUIElementCreateApplication(pid)',
              '"score": NSNull()', '"pixel_diff": NSNull()', 'stillOwned()'):
    assert token in capture, f'Missing honest compositor capture gate: {token}'
for token in ('CGRequestScreenCaptureAccess', 'AXIsProcessTrustedWithOptions', '.cacheDisplay('):
    assert token not in capture, f'Forbidden capture fallback/permission request: {token}'
project = Path('Watt.xcodeproj/project.pbxproj').read_text()
assert 'EXCLUDED_SOURCE_FILE_NAMES = "StoryFixtures.swift StoryFixtureData.swift FixtureLaunchSelection.swift"' in project
assert '#if DEBUG\n@MainActor\nenum J63FixtureLaunch' in app
binary_root = Path('.build/xcode/Build/Products')
def symbols(configuration):
    directory = binary_root / configuration / 'Watt.app/Contents/MacOS'
    # Xcode may place Debug implementation in Watt.debug.dylib behind a launcher.
    binaries = [directory / 'Watt', *directory.glob('*.dylib')]
    return subprocess.check_output(['nm', '-j', *map(str, binaries)], text=True)
debug_symbols = symbols('Debug')
release_symbols = symbols('Release')
for name in ('J63FixtureLaunch', 'sampleFullOnAdapter', 'FixtureLaunchSelection', 'ScenarioRegistry'):
    assert name in debug_symbols, f'Debug harness symbol absent: {name}'
    assert name not in release_symbols, f'Fixture harness leaked into Release: {name}'
print('Debug fixture symbols present; Release fixture symbols absent')
print('J6.3 shared native panel, exact dark fixture, reference digest, honest capture and script checks passed')
PY
