"""Whitespace validation only; pixel comparison requires a proven live native capture."""
from pathlib import Path
import subprocess
import sys

files = [
    'App/WattApp.swift', 'App/J73FixtureLaunch.swift',
    'DesignSystem/Components/ComponentSelectionMenu.swift',
    'Features/Settings/Views/SettingsRootView.swift', 'Models/WattPreferences.swift',
    'Services/PowerReadingStore.swift', 'Tests/Fixtures/StoryFixtures.swift',
    'Tests/Fixtures/StoryFixtureData.swift', 'Tests/Fixtures/FixtureLaunchSelection.swift',
    'Tests/WattTests/F05FixtureTests.swift', 'Tests/WattTests/NativeStylingTests.swift',
    'Tests/WattTests/J23SettingsTurnOnTests.swift', 'Tests/WattTests/J73ChooseComponentsTests.swift', 'Watt.xcodeproj/project.pbxproj',
    'DESIGN.md', 'SCREEN-BACKLOG.md',
]
failed = subprocess.run(['git', 'diff', '--check']).returncode != 0
for file in files + [str(p) for p in Path('docs/evidence/J7.3').iterdir()
                     if p.suffix in {'.md', '.py', '.sh', '.swift', '.json'}]:
    result = subprocess.run(['git', 'diff', '--no-index', '--check', '/dev/null', file],
                            capture_output=True, text=True)
    if result.returncode not in (0, 1) or result.stdout or result.stderr:
        print(file, result.stdout, result.stderr)
        failed = True
print('Pixel diff: null; this script checks source whitespace only.')
sys.exit(1 if failed else 0)
