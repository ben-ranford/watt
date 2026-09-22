#!/bin/bash
# J11.2 evidence verification. Native compositor/AX gates remain fail-closed.
set -u
cd "$(dirname "$0")/../../.."
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
out="$PWD/docs/evidence/J11.2"
status=0
xcode-select -p > "$out/toolchain.log" 2>&1 || true
xcodebuild -version >> "$out/toolchain.log" 2>&1 || status=1
: > "$out/static-check.log"
{
  echo "DEVELOPER_DIR=$DEVELOPER_DIR"
  echo "Xcode commands are explicitly routed through the full Xcode toolchain."
} > "$out/validation.log"
python3 - <<'PY' >> "$out/static-check.log" 2>&1 || status=1
import hashlib, json
from pathlib import Path
import xml.etree.ElementTree as ET
root=Path('.')
ev=root/'docs/evidence/J11.2'
for name in ['figma-context.json','figma-metadata.json','figma-screenshot.json','figma-variables.json','reference.json','reference-digest.json','verification.json','visual-review.json']:
    json.loads((ev/name).read_text())
xml=(ev/'figma-metadata.xml').read_text()
xml_payload=xml[:xml.rfind('</frame>') + len('</frame>')]
ET.fromstring(xml_payload)
for image, digest in [('reference.png','reference.sha256'),('screenshot.png','screenshot.sha256')]:
    expected=(ev/digest).read_text().split()[0]
    actual=hashlib.sha256((ev/image).read_bytes()).hexdigest()
    assert actual == expected, (image, actual, expected)
project=(root/'Watt.xcodeproj/project.pbxproj').read_text()
assert 'A22700000000000000000003' in project
assert 'A22700000000000000000001' in project
assert 'A22700000000000000000004' in project
assert 'A22700000000000000000002' in project
source=(root/'Features/Settings/Views/SettingsRootView.swift').read_text()
for token in ['Form {','.formStyle(.grouped)','.pickerStyle(.menu)','.toggleStyle(.switch)','.defaultFocus($focusedControl, .show)']:
    assert token in source, token
for forbidden in ['RoundedRectangle','LinearGradient','NSVisualEffectView','.preferredColorScheme(','.tint(']:
    assert forbidden not in source, forbidden
print('static evidence, checksums, native-control and project-registration checks passed')
PY
bash -n "$out/capture.sh" "$out/verify.sh" 2>/dev/null || status=1
xcrun --sdk macosx swiftc -parse "$out/capture-window.swift" >> "$out/static-check.log" 2>&1 || status=1
git diff --check >> "$out/static-check.log" 2>&1 || status=1
plutil -lint Watt.xcodeproj/project.pbxproj >> "$out/static-check.log" 2>&1 || status=1
echo "$status" > "$out/static-checks.exit"
run_check() {
  local name="$1"; shift
  "$@" > "$out/$name.log" 2>&1
  local result=$?
  echo "$result" > "$out/$name.exit"
  return "$result"
}
# Independent build directories avoid native build database conflicts.
(
  run_check focused-tests xcrun swift test --filter 'J111|J112|NativeStylingTests'
  run_check package-tests xcrun swift test
) & package_pid=$!
run_check debug-build-analyze xcodebuild -project Watt.xcodeproj -scheme Watt -configuration Debug -derivedDataPath build/J112-Debug CODE_SIGNING_ALLOWED=NO build analyze build-for-testing & debug_pid=$!
(
  run_check release-build-analyze xcodebuild -project Watt.xcodeproj -scheme Watt -configuration Release -derivedDataPath build/J112-Release CODE_SIGNING_ALLOWED=NO build analyze
  run_check release-build-for-testing xcodebuild -project Watt.xcodeproj -scheme Watt -configuration Release -derivedDataPath build/J112-Release CODE_SIGNING_ALLOWED=NO build-for-testing
) & release_pid=$!
wait "$package_pid" || status=1
wait "$debug_pid" || status=1
wait "$release_pid" || status=1
for check in focused-tests package-tests debug-build-analyze release-build-analyze release-build-for-testing; do
  [[ "$(cat "$out/$check.exit" 2>/dev/null)" == 0 ]] || status=1
done
echo "$status" > "$out/verify.exit"
exit "$status"
