"""Read-only regression checks for G082's conditional test-source boundary."""
from pathlib import Path
import re
import subprocess

root = Path(__file__).resolve().parents[3]
model = (root / "Models/PowerReading.swift").read_text()
samples = re.findall(r"static let (sample\w+)", model.split("#if DEBUG")[1].split("#endif")[0])
fixtures = re.compile(
    r"\b(?:ScenarioRegistry|FixtureLaunchSelection|WattFixtureLaunchGate|"
    r"J\w*FixtureLaunch|J25FixtureSession|C0410PanelSelection|" + "|".join(samples) + r")\b"
)

def without_literals(source):
    return re.sub(
        r'//[^\n]*|/\*[\s\S]*?\*/|"""[\s\S]*?"""|"(?:\\.|[^"\\])*"',
        lambda match: "\n" * match[0].count("\n"), source
    )

changed = 0
for path in sorted((root / "Tests/WattTests").glob("*.swift")):
    relative = str(path.relative_to(root))
    source = path.read_text()
    baseline = subprocess.check_output(["git", "show", f"HEAD:{relative}"], cwd=root, text=True)
    if source != baseline:
        # Every existing test body/import/helper is preserved verbatim.
        delta = subprocess.check_output(["git", "diff", "--", relative], cwd=root, text=True)
        additions = [line[1:] for line in delta.splitlines() if line.startswith("+") and not line.startswith("+++")]
        removals = [line for line in delta.splitlines() if line.startswith("-") and not line.startswith("---")]
        assert not removals, relative
        assert all(line.strip() in ("#if DEBUG || SWIFT_PACKAGE", "#endif") for line in additions), relative
        changed += 1
    stack = []
    for line_number, line in enumerate(without_literals(source).splitlines(), 1):
        line = line.strip()
        if line.startswith("#if "):
            stack.append(line)
        elif line.startswith("#endif"):
            stack.pop()
        elif line.startswith(("#else", "#elseif")):
            stack[-1] = ""
        elif fixtures.search(line):
            assert any("DEBUG" in condition for condition in stack), f"{relative}:{line_number}: {line}"
    assert not stack, relative

print(f"PASS: {changed} changed test files contain only conditional-compilation additions")
print("PASS: fixture symbols and DEBUG-only samples are guarded throughout WattTests")
print("PASS: existing test bodies, helpers, imports, and Release-safe sampleCharging uses preserved")
