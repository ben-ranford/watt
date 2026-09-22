"""Check tracked diffs and this slice's files, including pre-existing untracked sources."""
from pathlib import Path
import subprocess
import sys

files = ['App/AppRouter.swift', 'App/WattApp.swift', 'Features/MenuBar/Views/StatusItemContextMenu.swift', 'Tests/Fixtures/StoryFixtures.swift', 'Tests/Fixtures/StoryFixtureData.swift', 'Tests/Fixtures/FixtureLaunchSelection.swift', 'Tests/WattTests/F05FixtureTests.swift', 'Tests/WattTests/J53FinishSetupTests.swift', 'Tests/WattTests/J51WelcomeClosedTests.swift', 'Tests/WattTests/J21ComponentsUnavailableTests.swift', 'Watt.xcodeproj/project.pbxproj', 'DESIGN.md', 'SCREEN-BACKLOG.md']
failed = subprocess.run(['git', 'diff', '--check']).returncode != 0
for file in files + [str(p) for p in Path('docs/evidence/J5.3').iterdir()
                     if p.suffix in {'.md', '.py', '.sh', '.swift', '.json'}]:
    result = subprocess.run(['git', 'diff', '--no-index', '--check', '/dev/null', file],
                            capture_output=True, text=True)
    if result.returncode not in (0, 1) or result.stdout or result.stderr:
        print(file, result.stdout, result.stderr)
        failed = True
sys.exit(1 if failed else 0)
