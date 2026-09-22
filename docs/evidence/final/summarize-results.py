#!/usr/bin/env python3
"""Summarize this pass, without promoting historical or unavailable proof."""
from pathlib import Path
import datetime, hashlib, json, re, subprocess

root=Path.cwd(); out=root/'docs/evidence/final'
def read(name): return json.loads((out/name).read_text())
def write(name,obj): (out/name).write_text(json.dumps(obj,indent=2)+'\n')
context=read('run-context.json')
checks=['toolchain','package-tests','debug-build-analyze','release-build-analyze','release-test-build','diff-check','project-lint','static-checks','shellcheck','permission-preflight','inventory','evidence-audit','finding-resolution','supplemental-checks','registry-repeat']
results={n:read(n+'.json') for n in checks}
for name,result in results.items():
    assert int((out/(name+'.exit')).read_text())==result['exitCode'],name
    assert (out/result['log']).is_file(),name

text=(out/'package-tests.log').read_text(); suites=[]
for m in re.finditer(r"Test Suite '([^']+)' (passed|failed)[^\n]*\n\s+Executed (\d+) tests?, with (?:(\d+) tests? skipped and )?(\d+) failures",text):
    suites.append({'suite':m[1],'status':m[2],'executed':int(m[3]),'skipped':int(m[4] or 0),'failures':int(m[5])})
total=next(s for s in suites if s['suite']=='All tests')
leaf=[s for s in suites if s['suite'] not in ['All tests','WattTests.xctest']]
assert sum(s['executed'] for s in leaf)==total['executed']
assert (total['executed'],total['skipped'],total['failures'])==(703,5,0)
write('suite-summary.json',{'total':total,'suites':suites,'skipReasons':[line for line in text.splitlines() if ': Test skipped' in line], 'scope':'Executed package XCTest. Swift Testing runner reports zero additional tests. Not native hosted/UI tests.'})

baseline=read('initial-files.json')
changed=[e['path'] for e in baseline if not (root/e['path']).is_file() or hashlib.sha256((root/e['path']).read_bytes()).hexdigest()!=e['sha256']]
current=set(filter(None,subprocess.check_output(['git','ls-files','-z','--cached','--others','--exclude-standard','--','.',':!:build',':!:docs/evidence/final']).decode().split('\0')))
added=sorted(current-{e['path'] for e in baseline})
head=subprocess.check_output(['git','rev-parse','HEAD'],text=True).strip()
assert not changed and not added and head==context['head'],(changed,added,head)
write('scope-preservation.json',{'baselineFiles':len(baseline),'changedOutsideFinal':changed,'addedOutsideFinal':added,'HEADUnchanged':head==context['head'],'head':head,'excluded':'final evidence, pre-existing build/, ignored files; scratch build artifacts outside repository','verdict':'PASS'})

warnings={}
for name in ['package-tests','debug-build-analyze','release-build-analyze','release-test-build']:
    lines=(out/(name+'.log')).read_text().splitlines()
    warnings[name]={'warnings':sorted(set(l for l in lines if 'warning:' in l)), 'errors':sorted(set(l for l in lines if ': error:' in l)), 'completionMarkers':[l for l in lines if l.startswith('** ')]}
write('diagnostics-summary.json',warnings)
audit=read('evidence-audit-detail.json'); static=read('static-detail.json'); membership=read('target-membership.json')
production=[
    'Live charger/system/component watts remain unavailable; P01 public metadata subset is not full telemetry proof (DEC-05).',
    'Signed/authenticated helper install, real OS approval and XPC/removal lifecycle remain unproven (P02; DEC-01/02/04).',
    'Real notification delivery and login-item OS effects remain unverified; injected adapter tests do not close P03.',
    'Approved updater endpoint/trust, signed install/relaunch and recovery remain unconfigured/unproven (P04; DEC-01/03); default AppRouter has no update service.',
    'Scoped installed uninstall/cleanup requires real disposable-installation effects proof (P05).',
    'Shipping identity/signing/notarization, final asset approval, macOS 13 runtime, and all 69 independent D1-D7 acceptance records remain open.'
]
summary={
    'verdict':'PARTIAL','finalAcceptanceVerdict':'FAIL','run':context,'completedUTC':datetime.datetime.now(datetime.timezone.utc).isoformat(),
    'checks':results,'packageTests':total,
    'nativeBuilds':{'Debug':'build/analyze/build-for-testing PASS','ReleaseApp':'build/analyze PASS','ReleaseBuildForTesting':{'status':'FAIL','exitCode':65,'diagnostic':warnings['release-test-build']['errors']},'nativeHostedOrUITestsRunThisPass':False},
    'targetMembership':{'requestedJ13J14J15':'PASS; one source-phase entry each, guarded WattFixtures imports, fresh Debug compilation','remainingPackageOnly':membership['missingWattTestsSources'],'packageOnlyTestCount':sum(s['executed'] for s in suites if s['suite'] in ['StatusPanelVoiceOverSummaryTests','UpdateOfferInstallTests'])},
    'nativeStyling':{'verdict':'PASS (source/in-process only)','productionSwiftFilesScanned':static['swiftSourceFilesScanned'],'NativeStylingTests':next(s for s in suites if s['suite']=='NativeStylingTests'),'runtimeAppearanceAcceptance':False},
    'storyInventory':{k:audit[k] for k in ['orderedStories','baseAndVariantSelections','registryReferencesEqualF00','all69F00ExportHashesAndDimensionsPass','docsFilesRead','markdownFilesRead','recordsRead','digestStatusCounts']},
    'evidenceIntegrity':{'verdict':'PARTIAL','strictAuditExitCode':results['evidence-audit']['exitCode'],'problems':audit['problems'],'historicalNotes':len(audit['historicalNotes']),'detail':'resolved-findings.json','all69CurrentD1D7AcceptanceVerified':False},
    'permissions':json.loads((out/'permission-preflight.log').read_text()),
    'supersession':'supersession-review.json','currentVisualScore':None,'currentAccessibilityScore':None,'runtimeVisualPass':False,'runtimeAccessibilityVerified':False,
    'productionBlockers':production,
    'commitReadiness':{'finalCompletionCommitReady':False,'productionReady':False,'checkpointCommit':'Possible only as scoped partial/WIP preservation with disclosed blockers; no commit made. Not a final-completion sign-off.','stagingHazards':['Existing unignored build/ is 77,431 files / 8,237,063,309 bytes; do not git add .','F00 plan/export references are ignored under .omx and do not accompany a Git-only handoff.']},
    'scopePreservation':read('scope-preservation.json'),
    'historicalOnlyNotRerun':['package-build.*','registry-probe-build.*','native-tests.*','native-process-cleanup.json'],
    'verificationHarnessCorrection':'supplemental-checks-initial.* records an overly strict null-versus-omitted optional JSON comparison (exit 1); corrected by dropping null optional fields from both operands. Final runtime registry equality passes; no product change.'
}
write('verification.json',summary)
print(json.dumps({'verdict':summary['verdict'],'package':total,'exits':{n:r['exitCode'] for n,r in results.items()},'outsideFinalChanges':changed,'outsideFinalAdded':added,'nativePackageOnlyTests':summary['targetMembership']['packageOnlyTestCount'],'finalCompletionCommitReady':False},indent=2))
