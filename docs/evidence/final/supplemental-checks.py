#!/usr/bin/env python3
"""Read-only checks of cumulative code/artifacts; outputs only in final evidence."""
from pathlib import Path
import hashlib, json, re, subprocess

root = Path.cwd()
out = root / 'docs/evidence/final'
context = json.loads((out / 'run-context.json').read_text())
scratch = Path(context['scratch'])
def save(name, value):
    (out / name).write_text(json.dumps(value, indent=2) + '\n')

objects = json.loads(subprocess.check_output(['plutil', '-convert', 'json', '-o', '-', 'Watt.xcodeproj/project.pbxproj']))['objects']
targets = {}
for target in objects.values():
    if target.get('isa') != 'PBXNativeTarget':
        continue
    members = []
    for phase_id in target['buildPhases']:
        phase = objects[phase_id]
        if phase['isa'] != 'PBXSourcesBuildPhase':
            continue
        for build_id in phase['files']:
            ref = objects[objects[build_id]['fileRef']]
            members.append(ref['path'])
    targets[target['name']] = members
requested = {}
for name in ['J13OfferTests', 'J14ApprovalTests', 'J15PreviewTests']:
    path = 'Tests/WattTests/' + name + '.swift'
    source = (root / path).read_text()
    requested[path] = {'WattTestsSourcePhaseOccurrences': targets['WattTests'].count(path),
                       'packageOnlyFixtureImportGuard': '#if SWIFT_PACKAGE\nimport WattFixtures\n#endif' in source,
                       'debugBuildLogMentionsSource': path in (out/'debug-build-analyze.log').read_text()}
    assert all(v == 1 or v is True for v in requested[path].values()), requested[path]
missing = [str(p) for p in sorted(Path('Tests/WattTests').glob('*.swift')) if str(p) not in targets['WattTests'] and p.name not in targets['WattTests']]
save('target-membership.json', {'requestedJ13J14J15': requested, 'requestedVerdict': 'PASS', 'missingWattTestsSources': missing, 'targetSources': targets, 'limitation': 'Source-phase membership and successful Debug compilation, not native test execution. Two new regression files remain package-only.'})

plists = [root/'Watt.xcodeproj/project.pbxproj'] + [scratch/config/'Build/Products'/config/'Watt.app/Contents/Info.plist' for config in ['Debug', 'Release']]
plist_results = []
for path in plists:
    proc = subprocess.run(['plutil','-lint',str(path)],text=True,capture_output=True)
    plist_results.append({'path':str(path),'exitCode':proc.returncode,'output':proc.stdout+proc.stderr})
    assert proc.returncode == 0, plist_results[-1]
save('plist-detail.json', plist_results)

binary = scratch/'Release/Build/Products/Release/Watt.app/Contents/MacOS/Watt'
strings = subprocess.check_output(['strings','-a',str(binary)],text=True)
patterns = ['--watt-fixture','FixtureLaunchSelection','ScenarioRegistry','J113FixtureLaunch','WattComponentGallery','--watt-capture']
hits = [p for p in patterns if p in strings]
save('release-isolation.json', {'binary':str(binary),'sha256':hashlib.sha256(binary.read_bytes()).hexdigest(),'fixtureSelectorsAndSymbolsAbsent':not hits,'patterns':patterns,'hits':hits,'scope':'Listed strings only; not production-service or comprehensive binary security proof'})
assert not hits, hits

registry = json.loads((root/'Tests/Fixtures/StoryFixtureData.swift').read_text().split('#"""',1)[1].split('"""#',1)[0])
probe = scratch/'registry-probe'
subprocess.run(['xcrun','swiftc','-D','DEBUG','Tests/Fixtures/StoryFixtures.swift','Tests/Fixtures/StoryFixtureData.swift','scripts/F05/RegistryProbe.swift','-o',str(probe)],check=True)
outputs = []
for i in [1,2]:
    data = subprocess.check_output([str(probe)])
    (out/f'registry-run-{i}.json').write_bytes(data)
    outputs.append(data)
assert outputs[0] == outputs[1]
# Swift JSONEncoder omits nil optional appearance; source JSON retains null.
normalized = lambda rows: [{k: v for k, v in row.items() if v is not None} for row in rows]
assert normalized(json.loads(outputs[0])) == normalized(registry)
save('registry-determinism.json', {'command':[str(probe)],'runs':2,'allRunExitCodes':[0,0],'identicalBytes':True,'matchesSourceRegistryIgnoringNullOptionalKeys':True,'stories':len(registry),'variants':sum(len(s['variants']) for s in registry),'sha256':hashlib.sha256(outputs[0]).hexdigest()})

stories = []
for story in registry:
    directory = root/'docs/evidence'/story['id']
    records = []
    for filename in ['verification.json','visual-review.json','visual-ralph-verdict.json']:
        p = directory/filename
        if not p.exists():
            continue
        j = json.loads(p.read_text())
        records.append({'path':str(p.relative_to(root)),'status':j.get('status'),'recordedVisualPass':j.get('visualPass'),'supersession':j.get('supersession'), 'scope':'Retained record only; not reaccepted against current cumulative source'})
    stories.append({'story':story['id'],'node':story['node'],'README':str((directory/'README.md').relative_to(root)),'records':records,'currentIndependentD1D7AcceptanceVerified':False})
assert len(stories) == 69
save('story-status-summary.json', stories)

c01 = json.loads((root/'docs/evidence/C01/visual-review.json').read_text())
j113 = json.loads((root/'docs/evidence/J11.3/visual-review.json').read_text())
assert c01['supersession']['state'] == 'historical-superseded'
assert c01['visualPass'] is None
save('supersession-review.json', {
    'C01':{'sources':['DESIGN.md:362-379','DESIGN.md:564-585','docs/evidence/C01/visual-review.json','docs/evidence/C01/README.md'],
           'supersession':c01['supersession'],'currentVisualPass':None,'currentVisualScore':None,
           'conflict':'C01 README still leads with the historical PASS and obsolete C01-only gate wording. Explicit JSON supersession and DESIGN native-control mapping take precedence; README was not edited.'},
    'J11.3':{'sources':['docs/evidence/J11.3/README.md','docs/evidence/J11.3/verification.json','docs/evidence/J11.3/visual-review.json'],
             'captureExit':int((root/'docs/evidence/J11.3/capture.exit').read_text()),'record':j113,
             'currentVisualScore':None,'runtimeKeyboardVerified':False,'voiceOverVerified':False,
             'limitation':'Package/source shortcut and cancellation tests do not prove actual Return/Escape, focus traversal or VoiceOver; no new native capture attempted.'}
})
print(json.dumps({'requestedJ13J14J15':'PASS','otherPackageOnlyTests':missing,'plistChecks':len(plists),'releaseFixtureStrings':'absent','registry':'69 stories / 136 variants, two byte-identical runs; matches source','C01':'historical score superseded; current review pending','J11.3':'native visual/keyboard/VoiceOver acceptance blocked'},indent=2))
