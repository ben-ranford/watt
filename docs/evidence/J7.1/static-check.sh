#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/../../.."
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
bash -n docs/evidence/J7.1/capture.sh docs/evidence/J7.1/verify.sh docs/evidence/J7.1/static-check.sh
xcrun swiftc -typecheck docs/evidence/J7.1/capture-window.swift
python3 - <<'PY'
import ast
import hashlib
import json
import struct
import subprocess
from pathlib import Path

root = Path('docs/evidence/J7.1')
ast.parse((root / 'diff-check.py').read_text())
for path in root.glob('*.json'):
    json.loads(path.read_text())
reference = json.loads((root / 'reference.json').read_text())
assert reference['node'] == '31:6173'
assert reference['figmaFile'] == '9DKDgUfEqidZdZQEVlQgLS'
assert reference['story'] == 'J7.1' and reference['goal'] == 'G055'
assert reference['assetURL'] == 'https://www.figma.com/api/mcp/asset/5a226808-f4c5-4972-ada6-17b9b182fe88.png'
assert reference['appearance'] == 'aqua'
assert reference['statusAnchorNode'] == '31:6484'
assert reference['selectedStatusItem'] == 'battery glyph +42.1 W'
assert reference['mainMenu']['bounds'] == dict(x=651, y=38, width=230, height=187)
assert reference['submenu']['bounds'] == dict(x=465, y=38, width=190, height=141)
assert reference['submenu']['checked'] == 'Delta' and reference['submenu']['highlight'] == 'Components'
png = (root / 'reference.png').read_bytes()
assert png[:8] == b'\x89PNG\r\n\x1a\n'
assert struct.unpack('>II', png[16:24]) == (1000, 720)
assert reference['sha256'] == hashlib.sha256(png).hexdigest() == 'cbb1d098466ed5c3b58b0ac8748bcd75a928550d38a9c4b2309c8d48e3fe5cd9'
assert (root / 'reference.sha256').read_text().split()[0] == reference['sha256']
menu = Path('Features/MenuBar/Views/StatusItemContextMenu.swift').read_text()
for token in ('NSMenu', 'NSMenuItem', 'keyEquivalentModifierMask', 'readings.showsStateColumn = true',
              'readings.autoenablesItems = false', 'componentsAvailable()', 'router.showSettings',
              'router.showStatusPanel', 'router.showUpdate', 'orderFrontStandardAboutPanel', '.terminate(nil)'):
    assert token in menu, f'Missing native behavior: {token}'
for token in ('RoundedRectangle', 'Gradient', '.background', '.shadow', '.tint',
              'NSHostingView', '.view =', '.minimumWidth =', '.font =', '.image ='):
    assert token not in menu, f'Custom menu chrome: {token}'
app = Path('App/WattApp.swift').read_text()
assert '#if DEBUG\n@MainActor\nenum J71FixtureLaunch' in app
fixture = app.split('enum J71FixtureLaunch', 1)[1].split('\n#endif', 1)[0]
for token in ('NSAppearance.Name.aqua', 'selection.stableID == "J7.1/base"', 'sampleCharging',
              'FakeWattClock', 'InMemoryStorage()', 'componentReadings = true', 'helperOptIn: true',
              'helper.status = .connected', 'refreshStatus()', 'NSApplication.shared.postEvent',
              'NSRightArrowFunctionKey', 'submenu.highlightedItem?.title != "Components"'):
    assert token in fixture, f'Missing isolated fixture/native tracking: {token}'
for token in ('UserDefaults', '.cacheDisplay(', 'CGRequestScreenCaptureAccess', 'AXIsProcessTrustedWithOptions'):
    assert token not in fixture
for token in ('event.type == .rightMouseDown', 'event.modifierFlags.contains(.control)',
              'NSMenu.popUpContextMenu(menu, with: event, for: self)', 'view.openJ71ContextMenuFixture()'):
    assert token in app
capture = (root / 'capture-window.swift').read_text()
for token in ('CGPreflightScreenCaptureAccess()', 'AXIsProcessTrusted()',
              'kCGWindowOwnerPID', 'AXUIElementCreateApplication(pid)', 'NSNull()'):
    assert token in capture, f'Missing capture gate: {token}'
for token in ('CGRequestScreenCaptureAccess', 'AXIsProcessTrustedWithOptions', '.cacheDisplay('):
    assert token not in capture
project = Path('Watt.xcodeproj/project.pbxproj').read_text()
assert 'EXCLUDED_SOURCE_FILE_NAMES = "StoryFixtures.swift StoryFixtureData.swift FixtureLaunchSelection.swift"' in project
assert 'Tests/WattTests/J71ShowInMenuBarTests.swift' in project
products = Path('.build/xcode/Build/Products')
def symbols(configuration):
    directory = products / configuration / 'Watt.app/Contents/MacOS'
    binaries = [directory / 'Watt', *directory.glob('*.dylib')]
    return subprocess.check_output(['nm', '-j', *map(str, binaries)], text=True)
debug, release = symbols('Debug'), symbols('Release')
for name in ('J71FixtureLaunch', 'openJ71ContextMenuFixture', 'sampleCharging', 'FixtureLaunchSelection', 'ScenarioRegistry'):
    assert name in debug, f'Debug fixture symbol absent: {name}'
    assert name not in release, f'Fixture leaked into Release: {name}'
release_binary = products / 'Release/Watt.app/Contents/MacOS/Watt'
release_strings = subprocess.check_output(['strings', str(release_binary)], text=True)
for token in ('J7.1/base', '--watt-j71-capture-directory', 'J71FixtureLaunch'):
    assert token not in release_strings, f'Fixture selector leaked into Release: {token}'
print('J7.1 exact reference digest, native menu/bridge, fixture isolation and script checks passed')
print('Debug fixture symbols present; Release fixture symbols and selector strings absent')
PY
