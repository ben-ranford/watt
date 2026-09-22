#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/../../.."
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
bash -n docs/evidence/J6.4/capture.sh docs/evidence/J6.4/verify.sh docs/evidence/J6.4/static-check.sh
xcrun swiftc -typecheck docs/evidence/J6.4/capture-window.swift
python3 - <<'PY'
import ast
import hashlib
import json
import subprocess
from pathlib import Path

root = Path('docs/evidence/J6.4')
ast.parse((root / 'diff-check.py').read_text())
for name in ('reference.json', 'verification.json', 'visual-review.json'):
    json.loads((root / name).read_text())
reference = json.loads((root / 'reference.json').read_text())
assert reference['node'] == '31:4956'
assert reference['figmaFile'] == '9DKDgUfEqidZdZQEVlQgLS'
assert reference['selectedStatusItem'] == '−13.0 W'
assert reference['componentsVisible'] is False
assert reference['sha256'] == '7256ff7ac281ea2e2f26a22b6a70ccee4f874a6c72f3a70b222202328d54881b'
assert reference['appearance'] == 'darkAqua'
assert reference['sha256'] == hashlib.sha256((root / 'reference.png').read_bytes()).hexdigest()
panel = Path('Features/MenuBar/Views/StatusPanelView.swift').read_text()
for token in ('struct StatusPanelModel', 'struct StatusPanelView', 'includesComponents',
              'StatusPanelState', 'hasInsufficientCharger',
              'Label(model.title, systemImage: InsufficientChargerPresentation.symbol)',
              'Form {', 'LabeledContent {', '.formStyle(.grouped)', '.buttonStyle(.borderless)',
              'Button("Settings…", action: onSettings)', 'Button("Quit Watt?", action: onQuit)'):
    assert token in panel, f'Missing shared native panel contract: {token}'
for token in ('RoundedRectangle(', 'LinearGradient(', 'RadialGradient(', 'NSVisualEffectView', '.background('):
    assert token not in panel, f'Unexpected custom panel chrome: {token}'
model = Path('Models/PowerReading.swift').read_text()
for token in ('Charger can’t keep up', 'exclamationmark.triangle.fill', 'The battery covers the rest.'):
    assert token in model, f'Missing semantic warning content: {token}'
app = Path('App/WattApp.swift').read_text()
for token in ('enum J64FixtureLaunch', 'J6.4',
              'class StatusAnchorView', 'MenuBarExtra', '.menuBarExtraStyle(.window)'):
    assert token in app, f'Missing production fixture bridge: {token}'
fixture = app.split('enum J64FixtureLaunch', 1)[1].split('\n#endif', 1)[0]
for token in ('darkAqua', 'sampleInsufficientCharger', 'InMemoryStorage'):
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
assert '#if DEBUG\n@MainActor\nenum J64FixtureLaunch' in app
binary_root = Path('.build/xcode/Build/Products')
def symbols(configuration):
    directory = binary_root / configuration / 'Watt.app/Contents/MacOS'
    # Xcode may place Debug implementation in Watt.debug.dylib behind a launcher.
    binaries = [directory / 'Watt', *directory.glob('*.dylib')]
    return subprocess.check_output(['nm', '-j', *map(str, binaries)], text=True)
debug_symbols = symbols('Debug')
release_symbols = symbols('Release')
for name in ('J64FixtureLaunch', 'sampleInsufficientCharger', 'FixtureLaunchSelection', 'ScenarioRegistry'):
    assert name in debug_symbols, f'Debug harness symbol absent: {name}'
    assert name not in release_symbols, f'Fixture harness leaked into Release: {name}'
print('Debug fixture symbols present; Release fixture symbols absent')
print('J6.4 shared native panel, exact dark fixture, reference digest, honest capture and script checks passed')
PY
