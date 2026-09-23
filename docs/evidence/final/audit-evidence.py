#!/usr/bin/env python3
"""Read-only cumulative evidence audit; historical source hashes are not current baselines."""
from pathlib import Path
import hashlib,json,re,struct,collections
root=Path.cwd(); out=root/'docs/evidence/final'; problems=[]; notes=[]
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
f00=root/'.omx/plans/f00-reference-evidence'; manifest_path=f00/'manifest.json'
manifest_available=manifest_path.is_file()
if manifest_available:
 manifest=json.loads(manifest_path.read_text())
else:
 # F00 is intentionally ignored runtime state. Keep the audit runnable after a
 # worktree handoff, but make the missing authoritative export manifest an
 # explicit blocker rather than crashing before the portable checks run.
 manifest=None
 problems.append({'kind':'missing portable F00 reference manifest',
                  'path':str(manifest_path.relative_to(root)),
                  'resolution':'restore the approved F00 manifest/runtime evidence before final sign-off'})
registry=json.loads((root/'Tests/Fixtures/StoryFixtureData.swift').read_text().split('#"""',1)[1].split('"""#',1)[0])
backlog=(root/'SCREEN-BACKLOG.md').read_text(); design=(root/'DESIGN.md').read_text()
plan_path=root/'.omx/plans/watt-native-implementation-plan.md'
if plan_path.is_file():
 plan=plan_path.read_text()
else:
 plan=''
 problems.append({'kind':'missing portable approved implementation plan','path':str(plan_path.relative_to(root)),'resolution':'restore the approved plan artifact before final sign-off'})
if manifest_available:
 pairs=[(s['story'],s['node']) for s in manifest['stories']]
else:
 summary=json.loads((out/'story-status-summary.json').read_text())
 pairs=[(s['story'],s['node']) for s in summary]
plan_pairs=re.findall(r'^### \d+\. (\S+) — [^\n]+\n- \*\*Figma:\*\* \[`([^`]+)`\]',plan,re.M) if plan else pairs
assert pairs==[(s['id'],s['node']) for s in registry]==re.findall(r'^\| \d+ \| \*\*([^*]+)\*\* \| \[`([^`]+)`\]',backlog,re.M)==plan_pairs
assert len(pairs)==len(set(pairs))==69
for r in registry:
 assert (root/'docs/evidence'/r['id']/'README.md').exists(),r['id']
 assert list((root/'docs/evidence'/r['id']).rglob('*.png')),r['id']
 if manifest_available:
  s=next(s for s in manifest['stories'] if s['story']==r['id'])
  assert s==json.loads(r['referenceJSON']),r['id']
  data=(f00/s['frame_export']['path']).read_bytes(); assert hashlib.sha256(data).hexdigest()==s['frame_export']['sha256'],s['story']
  assert struct.unpack('>II',data[16:24])==(s['frame_export']['width_pixels'],s['frame_export']['height_pixels'])
if manifest_available:
 for path,expected in manifest['evidence_hashes'].items():
  if sha(f00/path)!=expected: problems.append({'kind':'F00 evidence digest mismatch','path':path})
 for path,expected in manifest['source_hashes'].items():
  if sha(root/path)!=expected: notes.append({'kind':'historical F00 source revision changed','path':path})
# Read every retained docs file, retaining an inventory digest rather than duplicating content.
files=[]; json_errors=[]; records=[]; readmes=[]; digest_checks=[]
for p in sorted((root/'docs').rglob('*')):
 if not p.is_file() or out in p.parents: continue
 data=p.read_bytes(); files.append({'path':str(p.relative_to(root)),'bytes':len(data),'sha256':hashlib.sha256(data).hexdigest()})
 if p.suffix=='.json':
  try: j=json.loads(data)
  except Exception as e: json_errors.append({'path':str(p.relative_to(root)),'error':str(e)}); continue
  if p.name in ('verification.json','visual-review.json','visual-ralph-verdict.json'):
   records.append({'path':str(p.relative_to(root)),'record':j})
 if p.suffix=='.md':
  text=data.decode(); lines=text.splitlines()
  readmes.append({'path':str(p.relative_to(root)),'text':text})
 if p.suffix=='.sha256':
  for line in data.decode().splitlines():
   m=re.match(r'^([0-9a-fA-F]{64})\s+\*?(.+)$',line)
   if not m: continue
   expected,path=m.groups(); target=Path(path)
   candidates=[target] if target.is_absolute() else [p.parent/target,root/target]
   target=next((c for c in candidates if c.is_file()),None)
   status='missing' if target is None else ('pass' if sha(target)==expected else 'mismatch')
   entry={'manifest':str(p.relative_to(root)),'path':path,'status':status}
   if target is not None: entry['resolved']=str(target.relative_to(root)) if target.is_relative_to(root) else str(target)
   digest_checks.append(entry)
# Check current verification log references, not prose or deliberately preserved initial-failure records.
links=[]
def walk(obj,p):
 if isinstance(obj,dict):
  for k,v in obj.items():
   if k in ('log','exit_file') and isinstance(v,str) and not v.startswith('/') and '\n' not in v:
    candidates=[p.parent/v,root/v]
    if not any(c.is_file() for c in candidates): links.append({'record':str(p.relative_to(root)),'field':k,'path':v})
   walk(v,p)
 elif isinstance(obj,list):
  for v in obj:walk(v,p)
for r in records:
 if Path(r['path']).name=='verification.json':walk(r['record'],root/r['path'])
for e in json_errors: problems.append({'kind':'invalid JSON',**e})
# Source digests intentionally describe earlier implementation revisions. Evidence-media mismatches do not.
for e in digest_checks:
 if e['status']!='pass':
  historical=Path(e['path']).suffix=='.swift' or e['manifest'].endswith('/sources.sha256')
  (notes if historical else problems).append({'kind':'historical source digest' if historical else 'evidence digest',**e})
for e in links:problems.append({'kind':'missing verification record link',**e})
summary={'orderedStories':69,'baseAndVariantSelections':sum(len(s['variants']) for s in registry),'f00ManifestAvailable':manifest_available,'registryReferencesEqualF00':manifest_available,'all69F00ExportHashesAndDimensionsPass':manifest_available,'portableStoryReadmesAndPNGsPass':True,'docsFilesRead':len(files),'markdownFilesRead':len(readmes),'recordsRead':len(records),'jsonErrors':json_errors,'digestStatusCounts':dict(collections.Counter(x['status'] for x in digest_checks)),'problems':problems,'historicalNotes':notes}
(out/'docs-inventory.json').write_text(json.dumps(files,indent=2)+'\n')
(out/'evidence-records.json').write_text(json.dumps(records,indent=2)+'\n')
(out/'digest-checks.json').write_text(json.dumps(digest_checks,indent=2)+'\n')
(out/'evidence-audit-detail.json').write_text(json.dumps(summary,indent=2)+'\n')
print(json.dumps(summary,indent=2)); raise SystemExit(bool(problems))
