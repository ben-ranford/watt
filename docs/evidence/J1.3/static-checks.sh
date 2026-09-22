#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/../../.."
git diff --check
bash -n docs/evidence/J1.3/capture.sh
python3 - <<'PY'
from pathlib import Path
source = Path('Features/Onboarding/Views/OnboardingFlowView.swift').read_text().split('struct OfferComponentReadingsView')[1]
for token in ['Form {', 'LabeledContent', '.formStyle(.grouped)', 'Text("Not Now")', 'Text("Turn On…")', '.buttonStyle(.bordered)', '.buttonStyle(.borderedProminent)', '.keyboardShortcut(.defaultAction)']:
    assert token in source, token
for token in ['RoundedRectangle', 'LinearGradient', '.background(', '.tint(', 'title: "Back"']:
    assert token not in source, token
buttons = Path('DesignSystem/Components/WattActionButton.swift').read_text()
assert '.buttonStyle(.bordered)' in buttons
assert '.buttonStyle(.borderedProminent)' in buttons
release = Path('/tmp/watt-g030-release/Build/Products/Release/Watt.app/Contents/MacOS/Watt').read_bytes()
assert b'--watt-j13-capture-directory' not in release
print('PASS: native controls, no custom painting/extra Back, release fixture isolation, shell syntax, diff whitespace')
PY
