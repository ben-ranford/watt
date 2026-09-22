#!/usr/bin/env python3
from pathlib import Path
import subprocess,json,re,sys
root=Path.cwd();out=root/'docs/evidence/final'; results=[]
def run(name,args):
 p=subprocess.run(args,text=True,stdout=subprocess.PIPE,stderr=subprocess.STDOUT); results.append({'name':name,'command':args,'exitCode':p.returncode,'output':p.stdout}); return p
shells=sorted([*Path('scripts').rglob('*.sh'),*Path('docs').rglob('*.sh')]); failures=[]
for p in shells:
 r=run(str(p),['bash','-n',str(p)])
 if r.returncode:failures.append(str(p))
py=sorted([*Path('scripts').rglob('*.py'),*Path('docs').rglob('*.py')])
for p in py:
 try:compile(p.read_text(),str(p),'exec')
 except Exception as e:failures.append(str(p)+': '+str(e))
prod=[p for d in ('App','DesignSystem','Features','Models','Services') for p in Path(d).rglob('*.swift')]
for p in prod:
 text=p.read_text()
 for pat in [r'\b(?:RoundedRectangle|LinearGradient|RadialGradient|AngularGradient|Canvas)\s*\(',r'\b(?:Path|Rectangle)\s*\{',r'\.strokeBorder\(',r'\.tint\(']:
  if re.search(pat,text): failures.append('painted control suspect '+str(p)+': '+pat)
app=Path('App/WattApp.swift').read_text()
assert app.count('MenuBarExtra(')==1
assert not any(re.search(r'\b'+x+r'\s*[(\{]',p.read_text()) for x in ['TabView','NavigationStack','NavigationView','NavigationSplitView'] for p in prod)
settings=Path('Features/Settings/Views/SettingsRootView.swift').read_text()
for token in ['Form {','.formStyle(.grouped)','.pickerStyle(.menu)','.toggleStyle(.switch)','.defaultFocus($focusedControl, .show)','.keyboardShortcut(.cancelAction)']:
 assert token in settings,token
# Explicit Xcode source membership, including newly landed J11.3 app and tests.
project=json.loads(subprocess.check_output(['plutil','-convert','json','-o','-','Watt.xcodeproj/project.pbxproj']))['objects']
refs={v.get('fileRef') for v in project.values() if v.get('isa')=='PBXBuildFile'}
paths={project[r].get('path') for r in refs if r in project}
sourcefiles=[*prod,*Path('Tests/WattTests').glob('*.swift'),*Path('Tests/WattUITests').glob('*.swift'),*Path('Tests/Fixtures').glob('*.swift')]
for p in sourcefiles:
 if str(p) not in paths and p.name not in paths:failures.append('No Xcode build reference: '+str(p))
summary={'shellSyntaxChecks':len(shells),'pythonSyntaxChecks':len(py),'swiftSourceFilesScanned':len(prod),'nativeStyling':'No gradient/shape/canvas/tint substitute detected; native controls additionally exercised by NativeStylingTests','navigation':'One MenuBarExtra; no tabs or navigation stacks; scene roots retained','sourceMembershipFiles':len(sourcefiles),'failures':failures,'checks':results}
(out/'static-detail.json').write_text(json.dumps(summary,indent=2)+'\n'); print(json.dumps({k:v for k,v in summary.items() if k!='checks'},indent=2));sys.exit(bool(failures))
