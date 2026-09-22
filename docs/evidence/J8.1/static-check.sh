#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/../../.."
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
bash -n docs/evidence/J8.1/capture.sh docs/evidence/J8.1/verify.sh docs/evidence/J8.1/static-check.sh
xcrun swiftc -typecheck docs/evidence/J8.1/capture-window.swift
shasum -a 256 -c docs/evidence/J8.1/reference.sha256
python3 - <<'PY'
import ast
import hashlib
import json
import struct
import subprocess
from pathlib import Path

root = Path('docs/evidence/J8.1')
ast.parse((root / 'diff-check.py').read_text())
for path in root.glob('*.json'):
    json.loads(path.read_text())
reference = json.loads((root / 'reference.json').read_text())
assert reference['story'] == 'J8.1' and reference['goal'] == 'G059'
assert reference['node'] == '32:3451' and reference['figmaFile'] == '9DKDgUfEqidZdZQEVlQgLS'
assert reference['assetURL'] == 'https://www.figma.com/api/mcp/asset/856abcfb-8fd1-4ad0-bc6e-6bc27d479d06.png'
assert reference['appearance'] == 'darkAqua' and reference['variants']['statusItemSelected'] is True
assert reference['desktopNode'] == '32:3452' and reference['statusAnchorNode'] == '32:3700'
assert reference['statusItemNode'] == '32:3697' and reference['panelNode'] == '32:3701'
assert reference['retrySlotNode'] == '32:4362' and reference['assets']['appOwned'] == []
png = (root / 'reference.png').read_bytes()
assert png[:8] == b'\x89PNG\r\n\x1a\n' and struct.unpack('>II', png[16:24]) == (1000, 720)
assert reference['sha256'] == hashlib.sha256(png).hexdigest()
assert (root / 'retrieved-screenshot.png').read_bytes() == png
model = Path('Models/PowerReading.swift').read_text()
for value in reference['copy'].values():
    assert value in model or value in Path('Features/MenuBar/Views/StatusPanelView.swift').read_text(), value
panel = Path('Features/MenuBar/Views/StatusPanelView.swift').read_text()
for token in ('case noReading', 'NoReadingPresentation.value', 'NoReadingPresentation.subtitle',
              'LabeledContent(NoReadingPresentation.retryLabel)', 'Image(systemName: NoReadingPresentation.symbol)',
              'Button(NoReadingPresentation.retryAction, action: onRetry)', '.buttonStyle(.bordered)',
              '.buttonStyle(.borderless)', '.disabled(isRetrying)', 'Form {', '.formStyle(.grouped)',
              '.fixedSize(horizontal: false, vertical: model.hasNoReading)'):
    assert token in panel, token
for token in ('RoundedRectangle', 'Gradient', '.background(', '.shadow(', '.tint(', '.position(',
              '.offset(', 'Font.custom', '.font(.system(size:', 'NSWindow(', 'NSImage('):
    assert token not in panel, token
fixture = Path('App/J81FixtureLaunch.swift').read_text()
assert fixture.startswith('#if DEBUG\n') and fixture.rstrip().endswith('#endif')
for token in ('selection.stableID == "J8.1/base"', 'NSAppearance.Name.darkAqua', 'FakeWattClock()',
              'currentReading: .unavailable', 'FakeTelemetryService(outcome: .success(.unavailable))',
              'InMemoryStorage()', 'checkpoint: .livePanel, completed: true, helperOptIn: true',
              'FakeHelperService()', 'helper.status = .connected'):
    assert token in fixture, token
for token in ('UserDefaults', 'NSWindow(', 'NSImage(', 'NSPopover(', 'NSHostingView', '.cacheDisplay(',
              '.displayIgnoringOpacity(', '.addSubview(', '.highlight(', 'CGRequestScreenCaptureAccess',
              'AXIsProcessTrustedWithOptions'):
    assert token not in fixture, token
app = Path('App/WattApp.swift').read_text()
for token in ('await powerStore.runSampling()', 'NSWorkspace.didWakeNotification',
              'NSWorkspace.shared.notificationCenter.publisher', 'powerStore.handleWake()',
              'await J81FixtureLaunch.prepare(router: router)', 'view.observeJ81StatusFixture(router: router)',
              'MenuBarExtra(isInserted:', '.menuBarExtraStyle(.window)'):
    assert token in app, token
capture = (root / 'capture-window.swift').read_text()
for token in ('CGPreflightScreenCaptureAccess()', 'AXIsProcessTrusted()', 'kCGWindowOwnerPID',
              'AXUIElementCreateApplication(pid)', 'AXUIElementGetPid', 'stillOwned()', 'kill(pid, 0)',
              'NSNull()', 'expected.allSatisfy', 'AXSelected', 'anchorWindow'):
    assert token in capture, token
for token in ('CGRequestScreenCaptureAccess', 'AXIsProcessTrustedWithOptions', '.cacheDisplay(',
              '.displayIgnoringOpacity(', 'NSWindow(', 'NSHostingView'):
    assert token not in capture, token
baseline = json.loads((root / 'pre-edit-hashes.json').read_text())
manifest = json.loads((root / 'changed-files.json').read_text())
allowed = set(manifest['sourceFiles'])
for file, digest in manifest['sourceSHA256'].items():
    assert hashlib.sha256(Path(file).read_bytes()).hexdigest() == digest, f'Stale source manifest: {file}'
for file, digest in baseline.items():
    if file not in allowed:
        assert hashlib.sha256(Path(file).read_bytes()).hexdigest() == digest, f'Unexpected edit: {file}'
project = Path('Watt.xcodeproj/project.pbxproj').read_text()
assert 'EXCLUDED_SOURCE_FILE_NAMES = "StoryFixtures.swift StoryFixtureData.swift FixtureLaunchSelection.swift"' in project
for file in ('App/J81FixtureLaunch.swift', 'Tests/WattTests/J81NoReadingTests.swift'):
    assert file in project
products = Path('.build/xcode/Build/Products')
def binaries(configuration):
    directory = products / configuration / 'Watt.app/Contents/MacOS'
    return [directory / 'Watt', *directory.glob('*.dylib')]
def symbols(configuration):
    raw = subprocess.check_output(['nm', '-j', *map(str, binaries(configuration))], text=True)
    return subprocess.check_output(['xcrun', 'swift-demangle'], input=raw, text=True)
debug, release = symbols('Debug'), symbols('Release')
for name in ('J81FixtureLaunch', 'observeJ81StatusFixture', 'FixtureLaunchSelection', 'ScenarioRegistry'):
    assert name in debug, f'Debug fixture symbol absent: {name}'
    assert name not in release, f'Fixture leaked into Release: {name}'
release_strings = subprocess.check_output(['strings', *map(str, binaries('Release'))], text=True)
for token in ('J8.1/base', '--watt-j81-capture-directory', 'J81FixtureLaunch', 'StoryFixtureData', '--watt-fixture'):
    assert token not in release_strings, f'Fixture selector/registry leaked into Release: {token}'
# Release may inline a constants-only presentation enum; test emitted copy instead.
assert reference['copy']['subtitle'] in release_strings
assert reference['copy']['title'] in release_strings
for name in ('PowerReadingStore.refresh', 'PowerReadingStore.handleWake'):
    assert name in release, f'Production behavior missing from Release: {name}'
print('J8.1 exact reference SHA, native controls/style, sampling/wake routing and fixture isolation passed')
print('Cumulative baseline outside declared source edits preserved; native/safety/authority guards retained')
print('Debug fixture symbols present; Release fixture/registry/selectors absent; production no-reading path retained')
PY
