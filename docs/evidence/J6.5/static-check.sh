#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/../../.."
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
bash -n docs/evidence/J6.5/capture.sh docs/evidence/J6.5/verify.sh docs/evidence/J6.5/static-check.sh
xcrun swiftc -typecheck docs/evidence/J6.5/capture-window.swift
python3 - <<'PY'
import ast
import hashlib
import json
import subprocess
from pathlib import Path

root = Path('docs/evidence/J6.5')
ast.parse((root / 'diff-check.py').read_text())
for name in ('reference.json', 'verification.json', 'visual-review.json'):
    json.loads((root / name).read_text())
reference = json.loads((root / 'reference.json').read_text())
assert reference['node'] == '31:5571'
assert reference['figmaFile'] == '9DKDgUfEqidZdZQEVlQgLS'
assert reference['selectedStatusItem'] == '−18.4 W'
assert reference['componentsVisible'] is False
assert reference['story'] == 'J6.5'
assert reference['goal'] == 'G054'
assert reference['assetURL'] == 'https://www.figma.com/api/mcp/asset/e5d93c42-8a3c-4991-91bc-1bb798e1d7dd.png'
assert reference['referencePanelBounds'] == {'x': 645, 'y': 38, 'width': 320, 'height': 265}
assert reference['copy'] == ['On battery', '−18.4 W', '64% · about 4 h 10 min left',
                             'Charger input', 'Unplugged', 'System draw', '18.4 W',
                             'Battery', '−18.4 W', 'Settings…', 'Quit Watt?']
assert reference['appearance'] == 'darkAqua'
assert reference['sha256'] == '2fc0d5e53483f6377d473195b64643f6b4316da85ea9c78e83af1a7c21ce1c47'
assert reference['sha256'] == hashlib.sha256((root / 'reference.png').read_bytes()).hexdigest()
panel = Path('Features/MenuBar/Views/StatusPanelView.swift').read_text()
for token in ('struct StatusPanelModel', 'struct StatusPanelView', 'includesComponents',
              'StatusPanelState', 'Unplugged',
              'Form {', 'LabeledContent {', '.formStyle(.grouped)', '.buttonStyle(.borderless)',
              'Button("Settings…", action: onSettings)', 'Button("Quit Watt?", action: onQuit)'):
    assert token in panel, f'Missing shared native panel contract: {token}'
for token in ('RoundedRectangle(', 'LinearGradient(', 'RadialGradient(', 'NSVisualEffectView', '.background('):
    assert token not in panel, f'Unexpected custom panel chrome: {token}'
app = Path('App/WattApp.swift').read_text()
for token in ('enum J65FixtureLaunch', 'selection.stableID == "J6.5/base"',
              'class StatusAnchorView', 'MenuBarExtra', '.menuBarExtraStyle(.window)'):
    assert token in app, f'Missing production fixture bridge: {token}'
fixture = app.split('enum J65FixtureLaunch', 1)[1].split('\n#endif', 1)[0]
for token in ('darkAqua', 'sampleOnBattery', 'InMemoryStorage', 'J61FixtureLaunch.prepare(preferences: preferences)'):
    assert token in fixture, f'Missing deterministic dark fixture contract: {token}'
shared_fixture = app.split('enum J61FixtureLaunch', 1)[1].split('\n#endif', 1)[0]
for token in ('componentReadings = false', 'completed: true'):
    assert token in shared_fixture, f'Missing shared isolated fixture preference: {token}'
capture = (root / 'capture-window.swift').read_text()
for token in ('CGPreflightScreenCaptureAccess()', 'AXIsProcessTrusted()',
              'kCGWindowOwnerPID', 'AXUIElementCreateApplication(pid)',
              '"score": NSNull()', '"pixel_diff": NSNull()', 'stillOwned()'):
    assert token in capture, f'Missing honest compositor capture gate: {token}'
for token in ('CGRequestScreenCaptureAccess', 'AXIsProcessTrustedWithOptions', '.cacheDisplay('):
    assert token not in capture, f'Forbidden capture fallback/permission request: {token}'
project = Path('Watt.xcodeproj/project.pbxproj').read_text()
assert 'EXCLUDED_SOURCE_FILE_NAMES = "StoryFixtures.swift StoryFixtureData.swift FixtureLaunchSelection.swift"' in project
assert '#if DEBUG\n@MainActor\nenum J65FixtureLaunch' in app
binary_root = Path('.build/xcode/Build/Products')
def symbols(configuration):
    directory = binary_root / configuration / 'Watt.app/Contents/MacOS'
    # Xcode may place Debug implementation in Watt.debug.dylib behind a launcher.
    binaries = [directory / 'Watt', *directory.glob('*.dylib')]
    return subprocess.check_output(['nm', '-j', *map(str, binaries)], text=True)
debug_symbols = symbols('Debug')
release_symbols = symbols('Release')
for name in ('J65FixtureLaunch', 'sampleOnBattery', 'FixtureLaunchSelection', 'ScenarioRegistry'):
    assert name in debug_symbols, f'Debug harness symbol absent: {name}'
    assert name not in release_symbols, f'Fixture harness leaked into Release: {name}'
print('Debug fixture symbols present; Release fixture symbols absent')
print('J6.5 shared native panel, exact dark fixture, reference digest, honest capture and script checks passed')
PY
