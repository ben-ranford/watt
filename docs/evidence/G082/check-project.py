"""Read-only G082 target membership and Release-boundary regression checks."""
import json
from pathlib import Path
import subprocess

root = Path(__file__).resolve().parents[3]
project = root / "Watt.xcodeproj/project.pbxproj"
objects = json.loads(subprocess.check_output(
    ["plutil", "-convert", "json", "-o", "-", str(project)]))["objects"]
targets = {o["name"]: o for o in objects.values() if o["isa"] == "PBXNativeTarget"}

def sources(target):
    return [objects[objects[file]["fileRef"]]["path"]
            for phase in target["buildPhases"]
            if objects[phase]["isa"] == "PBXSourcesBuildPhase"
            for file in objects[phase]["files"]]

def config(target, name):
    return next(objects[c]["buildSettings"]
                for c in objects[target["buildConfigurationList"]]["buildConfigurations"]
                if objects[c]["name"] == name)

for name in ("StatusPanelVoiceOverSummaryTests", "UpdateOfferInstallTests"):
    path = f"Tests/WattTests/{name}.swift"
    assert sources(targets["WattTests"]).count(path) == 1, path
    assert path not in sources(targets["Watt"]), path
    assert path not in sources(targets["WattUITests"]), path
    print(f"PASS: {path} belongs exactly once to WattTests only")

release = config(targets["Watt"], "Release")
assert release["ENABLE_TESTABILITY"] == "YES"
assert release["EXCLUDED_SOURCE_FILE_NAMES"].split() == [
    "StoryFixtures.swift", "StoryFixtureData.swift", "FixtureLaunchSelection.swift"]
project_object = next(o for o in objects.values() if o["isa"] == "PBXProject")
for target in [project_object, *targets.values()]:
    settings = config(target, "Release")
    flags = str(settings.get("SWIFT_ACTIVE_COMPILATION_CONDITIONS", ""))
    flags += str(settings.get("OTHER_SWIFT_FLAGS", ""))
    assert "DEBUG" not in flags and "SWIFT_PACKAGE" not in flags
assert "EXCLUDED_SOURCE_FILE_NAMES" not in config(targets["WattTests"], "Release")
print("PASS: Release app testability enabled; fixture exclusions preserved; no DEBUG/SWIFT_PACKAGE flags or test exclusions added")

for target in targets.values():
    for phase in target["buildPhases"]:
        assert phase in objects
    for dep in target["dependencies"]:
        assert objects[dep]["target"] in objects
assert any(objects[d]["target"] == "76F8DF47B09E22FC4CC39C80"
           for d in targets["WattTests"]["dependencies"])
print("PASS: WattTests retains explicit dependency on Watt")
