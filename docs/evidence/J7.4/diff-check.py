"""Check cumulative tracked diffs and J7.4 sources/evidence, including untracked files."""
from pathlib import Path
import subprocess
import sys

files = ['App/WattApp.swift', 'App/J74FixtureLaunch.swift',
         'Features/MenuBar/Components/MenuBarStatusLabel.swift',
         'Tests/Fixtures/StoryFixtures.swift', 'Tests/Fixtures/StoryFixtureData.swift',
         'Tests/Fixtures/FixtureLaunchSelection.swift', 'Tests/WattTests/F05FixtureTests.swift',
         'Tests/WattTests/J74CrowdedMenuBarTests.swift', 'Watt.xcodeproj/project.pbxproj',
         'DESIGN.md', 'SCREEN-BACKLOG.md']
failed = subprocess.run(['git', 'diff', '--check']).returncode != 0
for file in files + [str(p) for p in Path('docs/evidence/J7.4').iterdir()
                     if p.suffix in {'.md', '.py', '.sh', '.swift', '.json'}]:
    result = subprocess.run(['git', 'diff', '--no-index', '--check', '/dev/null', file],
                            capture_output=True, text=True)
    if result.returncode not in (0, 1) or result.stdout or result.stderr:
        print(file, result.stdout, result.stderr)
        failed = True
print('Whitespace checks passed' if not failed else 'Whitespace checks failed')
sys.exit(1 if failed else 0)
