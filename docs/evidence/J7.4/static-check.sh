#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/../../.."
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
bash -n docs/evidence/J7.4/capture.sh docs/evidence/J7.4/verify.sh docs/evidence/J7.4/static-check.sh
xcrun swiftc -typecheck docs/evidence/J7.4/capture-window.swift
shasum -a 256 -c docs/evidence/J7.4/reference.sha256
python3 - <<'PY'
import ast
import hashlib
import json
import struct
import subprocess
from pathlib import Path

root = Path('docs/evidence/J7.4')
ast.parse((root / 'diff-check.py').read_text())
for path in root.glob('*.json'):
    json.loads(path.read_text())
reference = json.loads((root / 'reference.json').read_text())
assert reference['story'] == 'J7.4' and reference['goal'] == 'G058'
assert reference['node'] == '31:7764' and reference['figmaFile'] == '9DKDgUfEqidZdZQEVlQgLS'
assert reference['assetURL'] == 'https://www.figma.com/api/mcp/asset/2775d3ec-51cb-4a81-a340-a98ea35ac5b2.png'
assert reference['appearance'] == 'aqua' and reference['statusText'] is None
assert reference['desktopNode'] == '31:7765' and reference['statusAnchorNode'] == '31:7913'
assert reference['statusItemNode'] == '31:7911' and reference['symbolName'] == 'battery.100percent.bolt'
assert reference['variants']['statusItemSelected'] is False
png = (root / 'reference.png').read_bytes()
assert png[:8] == b'\x89PNG\r\n\x1a\n'
assert struct.unpack('>II', png[16:24]) == (1000, 220)
assert reference['sha256'] == hashlib.sha256(png).hexdigest()
assert (root / 'reference.sha256').read_text().split()[0] == reference['sha256']
label = Path('Features/MenuBar/Components/MenuBarStatusLabel.swift').read_text()
icon = label.split('var body: some View {', 1)[1].split('} else {', 1)[0]
for token in ('Image(systemName: symbolName)', '.renderingMode(.template)'):
    assert token in icon, token
for token in ('Text(', '.font(', '.frame(', '.padding(', 'HStack', '.tint('):
    assert token not in icon, token
for token in ('case .iconOnly: return nil', 'preferences.showSymbol || effectiveMode == .iconOnly',
              'reading.validate()', 'reading.value(for: .delta)', '.accessibilityElement(children: .ignore)',
              '.accessibilityLabel("Watt? power reading")', '.accessibilityValue(accessibilityReading)'):
    assert token in label, token
for token in ('RoundedRectangle', 'Gradient', '.background', '.shadow', '.position(', '.offset(',
              'Font.custom', '.font(.system(size:', 'J74', 'J7.4', 'usesIconOnlyFixture'):
    assert token not in label, token
fixture = Path('App/J74FixtureLaunch.swift').read_text()
assert fixture.startswith('#if DEBUG\n') and fixture.rstrip().endswith('#endif')
for token in ('NSAppearance.Name.aqua', 'selection.stableID == "J7.4/base"', 'sampleCharging',
              'FakeWattClock', 'InMemoryStorage()', 'componentReadings = true', 'helperOptIn: true',
              'showSymbol = true', 'displayMode = .iconOnly', 'precision = .decimal',
              'FakeHelperService()', 'helper.status = .connected'):
    assert token in fixture, token
for token in ('UserDefaults', '.cacheDisplay(', '.displayIgnoringOpacity(', '.addSubview(',
              'NSWindow(', 'NSImage(', 'CGRequestScreenCaptureAccess', 'AXIsProcessTrustedWithOptions',
              '.frame =', '.font =', 'Gradient', 'RoundedRectangle'):
    assert token not in fixture, token
app = Path('App/WattApp.swift').read_text()
for token in ('MenuBarExtra(isInserted:', 'statusLabel', 'ScenePresentationBridge(',
              'view.observeJ74StatusFixture(reading: powerStore.statusReading, preferences: preferences)',
              'await J74FixtureLaunch.prepare(router: router)'):
    assert token in app, token
baseline = json.loads((root / 'pre-edit-hashes.json').read_text())
allowed = {'App/WattApp.swift', 'Features/MenuBar/Components/MenuBarStatusLabel.swift',
           'Tests/Fixtures/StoryFixtures.swift', 'Tests/Fixtures/StoryFixtureData.swift',
           'Tests/Fixtures/FixtureLaunchSelection.swift', 'Tests/WattTests/F05FixtureTests.swift',
           'Watt.xcodeproj/project.pbxproj', 'DESIGN.md', 'SCREEN-BACKLOG.md'}
for file, digest in baseline.items():
    if file not in allowed:
        assert hashlib.sha256(Path(file).read_bytes()).hexdigest() == digest, f'Unexpected edit: {file}'
capture = (root / 'capture-window.swift').read_text()
for token in ('CGPreflightScreenCaptureAccess()', 'AXIsProcessTrusted()', 'kCGWindowOwnerPID',
              'AXUIElementCreateApplication(pid)', 'NSNull()', 'ownedWindows()', 'expectedValue', 'kill(pid, 0)'):
    assert token in capture, token
for token in ('CGRequestScreenCaptureAccess', 'AXIsProcessTrustedWithOptions', '.cacheDisplay(', '.displayIgnoringOpacity('):
    assert token not in capture, token
project = Path('Watt.xcodeproj/project.pbxproj').read_text()
assert 'EXCLUDED_SOURCE_FILE_NAMES = "StoryFixtures.swift StoryFixtureData.swift FixtureLaunchSelection.swift"' in project
for file in ('App/J74FixtureLaunch.swift', 'Tests/WattTests/J74CrowdedMenuBarTests.swift'):
    assert file in project
products = Path('.build/xcode/Build/Products')
def binaries(configuration):
    directory = products / configuration / 'Watt.app/Contents/MacOS'
    return [directory / 'Watt', *directory.glob('*.dylib')]
def symbols(configuration):
    raw = subprocess.check_output(['nm', '-j', *map(str, binaries(configuration))], text=True)
    return subprocess.check_output(['xcrun', 'swift-demangle'], input=raw, text=True)
debug, release = symbols('Debug'), symbols('Release')
for name in ('J74FixtureLaunch', 'observeJ74StatusFixture', 'FixtureLaunchSelection', 'ScenarioRegistry'):
    assert name in debug, f'Debug fixture symbol absent: {name}'
    assert name not in release, f'Fixture leaked into Release: {name}'
release_strings = subprocess.check_output(['strings', *map(str, binaries('Release'))], text=True)
for token in ('J7.4/base', '--watt-j74-capture-directory', 'J74FixtureLaunch', 'StoryFixtureData', '--watt-fixture'):
    assert token not in release_strings, f'Fixture selector/registry leaked into Release: {token}'
print('J7.4 exact reference digest, shared native template icon/accessibility and fixture isolation passed')
print('All baseline sources outside the nine declared edited files preserved, including broad native/safety guards and J7.1/J7.2 tests')
print('Debug fixture symbols present; Release fixture symbols, registry and selector strings absent')
PY
