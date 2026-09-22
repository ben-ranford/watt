from pathlib import Path
import json,hashlib,subprocess,sys
root=Path.cwd(); out=root/'docs/evidence/final'; f00=root/'.omx/plans/f00-reference-evidence'
manifest=json.loads((f00/'manifest.json').read_text()); retained=json.loads((out/'docs-inventory.json').read_text()); findings=[]
for story in ['J8.2','J8.3']:
 s=next(s for s in manifest['stories'] if s['story']==story); p=f00/s['frame_export']['path']; digest=hashlib.sha256(p.read_bytes()).hexdigest()
 claimed=(root/f'docs/evidence/{story}/reference.sha256').read_text(); expected=next(l.split()[0] for l in claimed.splitlines() if 'reference-export-from-story-manifest.png' in l)
 assert digest==expected
 findings.append({'story':story,'kind':'missing local checksum alias resolved to F00 export','path':str(p.relative_to(root)),'sha256':digest,'portableInGit':False,'remainingGap':'reference.sha256 names an absent sibling file; ignored F00 export is required on handoff'})
p=root/'docs/evidence/J8.2/figma-screenshot.json'; obj=json.loads(p.read_text()); digest=obj['mcpResponse']['sha256']; matches=[x['path'] for x in retained if x['sha256']==digest]
findings.append({'story':'J8.2','kind':'MCP screenshot bytes absent from docs' if not matches else 'MCP screenshot bytes found','claimedSHA256':digest,'matches':matches,'remainingGap':'URL/metadata/hash is not retained screenshot bytes'})
p=root/'docs/evidence/J11.2/figma-screenshot-response.json';raw=p.read_text();first=json.loads(raw.splitlines()[0]);normalized=json.loads((p.parent/'figma-screenshot.json').read_text()); assert normalized['mcpResponse']==first
for n in ['reference','screenshot']:
 assert hashlib.sha256((p.parent/(n+'.png')).read_bytes()).hexdigest()==normalized[n+'SHA256']
findings.append({'story':'J11.2','kind':'raw tool text mislabeled .json; valid normalized JSON and both PNG hashes verified','remainingGap':'Do not feed the raw mixed-text response to a strict JSON parser; preserve provenance'})
findings.append({'story':'C03','kind':'metadata.sha256 README.md digest stale','remainingGap':'Documentation was extended after snapshot; image hash checks pass, but current checksum manifest is not wholly reproducible'})
old=json.loads((out/'initial-files.json').read_text()); changed=[]
for x in old:
 p=root/x['path']
 if not p.exists() or hashlib.sha256(p.read_bytes()).hexdigest()!=x['sha256']:changed.append(x['path'])
findings.append({'kind':'concurrent change detection','changedSinceG081Start':changed,'scope':f'All {len(old)} initial tracked/nonignored non-build files; excludes final evidence; baseline refreshed for this pass'})
(out/'resolved-findings.json').write_text(json.dumps(findings,indent=2)+'\n')
print(json.dumps(findings,indent=2));sys.exit(bool(changed))
