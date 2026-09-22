#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/../../.."
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
bash -n docs/evidence/J7.2/capture.sh docs/evidence/J7.2/verify.sh docs/evidence/J7.2/static-check.sh
xcrun swiftc -typecheck docs/evidence/J7.2/capture-window.swift
shasum -a 256 -c docs/evidence/J7.2/reference.sha256
python3 - <<'PY'
import ast
import hashlib
import json
import struct
import subprocess
from pathlib import Path

root = Path('docs/evidence/J7.2')
ast.parse((root / 'diff-check.py').read_text())
for path in root.glob('*.json'):
    json.loads(path.read_text())
reference = json.loads((root / 'reference.json').read_text())
assert reference['node'] == '31:6952'
assert reference['figmaFile'] == '9DKDgUfEqidZdZQEVlQgLS'
assert reference['story'] == 'J7.2' and reference['goal'] == 'G056'
assert reference['assetURL'] == 'https://www.figma.com/api/mcp/asset/e2e5a443-246c-47c9-8ec8-5e2b3e8dbc4b.png'
assert reference['appearance'] == 'aqua'
assert reference['statusAnchorNode'] == '31:7101' and reference['statusItemNode'] == '31:7099'
assert reference['statusText'] == 'CPU 9.8 · GPU 4.1 W' and reference['showsSymbol'] is False
png = (root / 'reference.png').read_bytes()
assert png[:8] == b'\x89PNG\r\n\x1a\n'
assert struct.unpack('>II', png[16:24]) == (1000, 220)
assert reference['sha256'] == hashlib.sha256(png).hexdigest()
assert (root / 'reference.sha256').read_text().split()[0] == reference['sha256']
label = Path('Features/MenuBar/Components/MenuBarStatusLabel.swift').read_text()
for token in ('preferences.selectedComponents.map', 'reading.validate()', 'if showsSymbol',
              'Text(text)', '.font(WattTypography.bodyEmphasized)'):
    assert token in label, f'Missing shared label semantics: {token}'
for token in ('RoundedRectangle', 'Gradient', '.background', '.shadow', '.position(', '.offset(',
              'Font.custom', '.font(.system(size:', 'CPU 9.8 · GPU 4.1 W', 'J72', 'J7.2'):
    assert token not in label, f'Custom or story-specific status rendering: {token}'
app = Path('App/WattApp.swift').read_text()
assert '#if DEBUG\n@MainActor\nenum J72FixtureLaunch' in app
fixture = app.split('enum J72FixtureLaunch', 1)[1]
for token in ('NSAppearance.Name.aqua', 'selection.stableID == "J7.2/base"', 'samplePerComponent',
              'FakeWattClock', 'InMemoryStorage()', 'componentReadings = true', 'helperOptIn: true',
              'selectedComponents = ["CPU", "GPU"]', 'showSymbol = false', 'displayMode = .components',
              'precision = .decimal', 'MenuBarStatusLabel(reading: reading, preferences: preferences)'):
    assert token in fixture, f'Missing isolated fixture/shared semantics: {token}'
for token in ('UserDefaults', '.cacheDisplay(', '.displayIgnoringOpacity(', '.addSubview(',
              'NSWindow(', 'NSImage(', 'CPU 9.8 · GPU 4.1 W', 'CGRequestScreenCaptureAccess',
              'AXIsProcessTrustedWithOptions', '.frame =', '.font =', 'Gradient', 'RoundedRectangle'):
    assert token not in fixture, f'Custom/synthetic/side-effect fixture path: {token}'
for token in ('MenuBarExtra(isInserted:', 'statusLabel', 'ScenePresentationBridge(',
              'view.observeJ72StatusFixture(reading: powerStore.statusReading, preferences: preferences)'):
    assert token in app
baseline = json.loads((root / 'pre-edit-hashes.json').read_text())
for file in ('Features/MenuBar/Views/StatusItemContextMenu.swift', 'Features/MenuBar/Views/MenuBarRootView.swift',
             'Models/PowerReading.swift', 'Models/WattPreferences.swift'):
    assert hashlib.sha256(Path(file).read_bytes()).hexdigest() == baseline[file], f'Unexpected edit: {file}'
capture = (root / 'capture-window.swift').read_text()
for token in ('CGPreflightScreenCaptureAccess()', 'AXIsProcessTrusted()', 'kCGWindowOwnerPID',
              'AXUIElementCreateApplication(pid)', 'NSNull()', 'ownedWindows()', 'expectedText'):
    assert token in capture, f'Missing capture gate: {token}'
for token in ('CGRequestScreenCaptureAccess', 'AXIsProcessTrustedWithOptions', '.cacheDisplay('):
    assert token not in capture
project = Path('Watt.xcodeproj/project.pbxproj').read_text()
assert 'EXCLUDED_SOURCE_FILE_NAMES = "StoryFixtures.swift StoryFixtureData.swift FixtureLaunchSelection.swift"' in project
assert 'Tests/WattTests/J72PerComponentMenuBarTests.swift' in project
products = Path('.build/xcode/Build/Products')
def binaries(configuration):
    directory = products / configuration / 'Watt.app/Contents/MacOS'
    return [directory / 'Watt', *directory.glob('*.dylib')]
def symbols(configuration):
    raw = subprocess.check_output(['nm', '-j', *map(str, binaries(configuration))], text=True)
    return subprocess.check_output(['xcrun', 'swift-demangle'], input=raw, text=True)
debug, release = symbols('Debug'), symbols('Release')
for name in ('J72FixtureLaunch', 'observeJ72StatusFixture', 'samplePerComponent', 'FixtureLaunchSelection', 'ScenarioRegistry'):
    assert name in debug, f'Debug fixture symbol absent: {name}'
    assert name not in release, f'Fixture leaked into Release: {name}'
release_strings = subprocess.check_output(['strings', *map(str, binaries('Release'))], text=True)
for token in ('J7.2/base', '--watt-j72-capture-directory', 'J72FixtureLaunch', 'StoryFixtureData', '--watt-fixture'):
    assert token not in release_strings, f'Fixture selector/registry leaked into Release: {token}'
print('J7.2 exact reference digest, shared native label/bridge, fixture isolation and script checks passed')
print('StatusItemContextMenu, MenuBarRootView, PowerReading and PreferencesStore unchanged from slice baseline')
print('Debug fixture symbols present; Release fixture symbols, registry and selector strings absent')
PY
