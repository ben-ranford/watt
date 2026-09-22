#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/../../.."
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
bash -n docs/evidence/J7.3/capture.sh docs/evidence/J7.3/verify.sh docs/evidence/J7.3/static-check.sh
xcrun swiftc -typecheck docs/evidence/J7.3/capture-window.swift
shasum -a 256 -c docs/evidence/J7.3/reference.sha256
python3 - <<'PY'
import ast
import hashlib
import json
import struct
import subprocess
from pathlib import Path

root = Path('docs/evidence/J7.3')
ast.parse((root / 'diff-check.py').read_text())
for path in root.glob('*.json'):
    json.loads(path.read_text())
reference = json.loads((root / 'reference.json').read_text())
assert reference['node'] == '31:7102' and reference['figmaFile'] == '9DKDgUfEqidZdZQEVlQgLS'
assert reference['story'] == 'J7.3' and reference['goal'] == 'G057'
assert reference['assetURL'] == 'https://www.figma.com/api/mcp/asset/b3c4703f-fb7f-4529-bd75-09578341b687.png'
assert reference['settingsWindowNode'] == '31:7256' and reference['menuNode'] == '31:7533'
assert reference['appearance'] == 'aqua' and reference['variants'] == ['base']
png = (root / 'reference.png').read_bytes()
assert png[:8] == b'\x89PNG\r\n\x1a\n' and struct.unpack('>II', png[16:24]) == (1000, 720)
assert reference['sha256'] == hashlib.sha256(png).hexdigest()
settings = Path('Features/Settings/Views/SettingsRootView.swift').read_text()
menu = Path('DesignSystem/Components/ComponentSelectionMenu.swift').read_text()
for token in ('Form {', 'Section {', 'LabeledContent {', 'ComponentSelectionMenu(', '.formStyle(.grouped)',
              'Two fit. More crowd the menu bar.', 'WattSpacing.settingsExcerptWidth'):
    assert token in settings, token
assert 'componentChoices' not in settings
for source in (settings, menu):
    for token in ('RoundedRectangle', 'LinearGradient', '.shadow(', '.background(', '.overlay(',
                  '.position(', '.offset(', 'Font.custom', '.font(.system(size:'):
        assert token not in source, token
for token in ('NSPopUpButton(', 'NSMenu(title:', 'NSMenuItem(title:', 'menu.showsStateColumn = true',
              'cell?.usesItemFromMenu = false', 'cell?.altersStateOfSelectedItem = false',
              'func menuNeedsUpdate', 'preferences.toggleComponent', 'powerStore.availableComponentIDs'):
    assert token in menu, token
for token in ('.view =', '.font =', '.image =', '.frame =', '.appearance =', 'NSHostingView', '.minimumWidth ='):
    assert token not in menu, token
fixture = Path('App/J73FixtureLaunch.swift').read_text()
assert fixture.startswith('#if DEBUG\n') and fixture.endswith('#endif\n')
for token in ('J7.3/base', 'InMemoryStorage()', 'FakeWattClock', 'samplePerComponent', 'NSAppearance.Name.aqua',
              'helper.status = .connected', 'selectedComponents = ["CPU", "GPU"]',
              'checkpoint: .livePanel, completed: true', 'button.performClick(nil)'):
    assert token in fixture, token
for token in ('NSWindow(', 'NSImage(', '.cacheDisplay(', '.displayIgnoringOpacity(', 'UserDefaults',
              'CGRequestScreenCaptureAccess', 'AXIsProcessTrustedWithOptions', '.frame ='):
    assert token not in fixture, token
app = Path('App/WattApp.swift').read_text()
for token in ('SettingsRootView(menuBarExcerpt: settingsMenuBarExcerpt)',
              'await J73FixtureLaunch.prepare(router: router)\n                    router.showSettings()',
              '@Environment(\\.openSettings)', 'J73FixtureLaunch.openComponentsMenu()'):
    assert token in app, token
baseline = json.loads((root / 'pre-edit-hashes.json').read_text())
for file in ('DesignSystem/Components/ReadingPicker.swift', 'Features/MenuBar/Components/MenuBarStatusLabel.swift',
             'Features/MenuBar/Views/StatusItemContextMenu.swift'):
    assert hashlib.sha256(Path(file).read_bytes()).hexdigest() == baseline[file], file
capture = (root / 'capture-window.swift').read_text()
for token in ('CGPreflightScreenCaptureAccess()', 'AXIsProcessTrusted()', 'kCGWindowOwnerPID',
              'AXUIElementCreateApplication(pid)', 'NSNull()', 'ownedWindows()', 'AXMenuItemMarkChar',
              'settings.components', 'menus.count == 1'):
    assert token in capture, token
for token in ('CGRequestScreenCaptureAccess', 'AXIsProcessTrustedWithOptions', '.cacheDisplay('):
    assert token not in capture, token
project = Path('Watt.xcodeproj/project.pbxproj').read_text()
assert 'EXCLUDED_SOURCE_FILE_NAMES = "StoryFixtures.swift StoryFixtureData.swift FixtureLaunchSelection.swift"' in project
for file in ('J73ChooseComponentsTests.swift', 'ComponentSelectionMenu.swift', 'J73FixtureLaunch.swift'):
    assert file in project, file
products = Path('.build/xcode/Build/Products')
def binaries(configuration):
    directory = products / configuration / 'Watt.app/Contents/MacOS'
    return [directory / 'Watt', *directory.glob('*.dylib')]
def symbols(configuration):
    raw = subprocess.check_output(['nm', '-j', *map(str, binaries(configuration))], text=True)
    return subprocess.check_output(['xcrun', 'swift-demangle'], input=raw, text=True)
debug, release = symbols('Debug'), symbols('Release')
for name in ('J73FixtureLaunch', 'FixtureLaunchSelection', 'ScenarioRegistry'):
    assert name in debug and name not in release, name
assert 'ComponentSelectionMenu' in debug and 'ComponentSelectionMenu' in release
release_strings = subprocess.check_output(['strings', *map(str, binaries('Release'))], text=True)
for token in ('J7.3/base', '--watt-j73-capture-directory', 'J73FixtureLaunch', 'StoryFixtureData', '--watt-fixture'):
    assert token not in release_strings, token
print('J7.3 exact reference/SHA, native Form/popup semantics, fixture isolation and capture gates passed')
print('ReadingPicker, J7.2 label and J7.1 context menu unchanged; Debug fixture present and Release fixture/registry absent')
PY
