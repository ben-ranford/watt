"""Whitespace and evidence gating only; never invent pixel similarity from missing captures."""
from pathlib import Path
import json
import subprocess
import sys

root = Path('docs/evidence/J8.1')
files = json.loads((root / 'changed-files.json').read_text())['sourceFiles']
failed = subprocess.run(['git', 'diff', '--check']).returncode != 0
for file in files + [str(p) for p in root.iterdir()
                     if p.suffix in {'.md', '.py', '.sh', '.swift', '.json'}]:
    # Upstream Apple documentation is retained verbatim as retrieval evidence.
    if Path(file).name.startswith('apple-'):
        continue
    result = subprocess.run(['git', 'diff', '--no-index', '--check', '/dev/null', file],
                            capture_output=True, text=True)
    if result.returncode not in (0, 1) or result.stdout or result.stderr:
        print(file, result.stdout, result.stderr)
        failed = True
review = json.loads((root / 'visual-review.json').read_text())
capture_path = root / 'capture/window.json'
capture = json.loads(capture_path.read_text()) if capture_path.exists() else {}
if not capture.get('comparableCapture'):
    assert review['score'] is None and review['pixel_diff'] is None
    assert review['visualPass'] is False and not review['comparableCapture']
    print('No comparable native capture: visual score/pixel diff remain null; no visual pass')
elif review['visualPass']:
    assert review['comparableCapture'] and review['score'] is not None
    assert review['pixel_diff'] is not None
print('Whitespace checks passed' if not failed else 'Whitespace checks failed')
sys.exit(1 if failed else 0)
