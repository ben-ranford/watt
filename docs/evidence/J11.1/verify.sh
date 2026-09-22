#!/bin/bash
# J11.1 evidence verification. Native compositor/AX gates remain fail-closed.
set -u
cd "$(dirname "$0")/../../.."
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
out="$PWD/docs/evidence/J11.1"
status=0
xcode-select -p > "$out/toolchain.log" 2>&1 || true
xcodebuild -version >> "$out/toolchain.log" 2>&1 || status=1
echo "DEVELOPER_DIR=$DEVELOPER_DIR" > "$out/validation.log"
echo "Xcode commands are explicitly routed through the full Xcode toolchain." >> "$out/validation.log"
python3 - <<'PY' >> "$out/static-check.log" 2>&1 || status=1
import hashlib, json
from pathlib import Path
root=Path('.')
ev=root/'docs/evidence/J11.1'
for name in ['figma-context.json','figma-metadata.json','figma-screenshot.json','figma-variables.json','reference.json']:
    json.loads((ev/name).read_text())
expected=(ev/'reference.sha256').read_text().split()[0]
actual=hashlib.sha256((ev/'reference.png').read_bytes()).hexdigest()
assert actual == expected, (actual, expected)
assert 'A22600000000000000000003' in (root/'Watt.xcodeproj/project.pbxproj').read_text()
assert 'A22600000000000000000001' in (root/'Watt.xcodeproj/project.pbxproj').read_text()
print('static evidence and project-registration checks passed')
PY
bash -n "$out/capture.sh" "$out/verify.sh" 2>/dev/null || status=1
xcrun --sdk macosx swiftc -parse "$out/capture-window.swift" >> "$out/static-check.log" 2>&1 || status=1
echo "$status" > "$out/verify.exit"
exit "$status"
