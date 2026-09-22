#!/bin/bash
# J11.1 native capture: fail closed; never request TCC or substitute a window.
set -u
cd "$(dirname "$0")/../../.."
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
out="$PWD/docs/evidence/J11.1/capture"
rm -rf "$out"
mkdir -p "$out"
write_blocked() {
  python3 - "$1" "$out/window.json" <<'PY'
import json, os, sys
reason=sys.argv[1]
json.dump({
  "fixture":"J11.1/base", "node":"36:5057", "panelNode":"36:5061",
  "status":"blocked", "reason":reason, "nativeCapture":None,
  "score":None, "pixel_diff":None, "visualPass":False,
  "comparableCapture":False, "screenCapturePreauthorized":None,
  "AXTrusted":None, "appOwnedCompositorWindowCount":0,
  "permissionRequests":0, "replacementWindow":False
}, open(sys.argv[2], "w"), indent=2, sort_keys=True)
PY
}
dev="$(xcode-select -p 2>&1 || true)"
if ! xcodebuild -version > "$out/toolchain.log" 2>&1; then
  write_blocked "Xcode unavailable through DEVELOPER_DIR=$DEVELOPER_DIR (xcodebuild: $(tr '\n' ' ' < "$out/toolchain.log"))"
  echo "1" > "$PWD/docs/evidence/J11.1/capture.exit"
  echo "blocked: $dev" > "$out/capture.log"
  exit 1
fi
app="$PWD/build/J111-Debug/Build/Products/Debug/Watt.app/Contents/MacOS/Watt"
if [[ ! -x "$app" ]]; then
  write_blocked "Debug fixture app is unavailable; capture not attempted"
  echo "1" > "$PWD/docs/evidence/J11.1/capture.exit"
  exit 1
fi
"$app" --watt-fixture J11.1/base --watt-j111-capture-directory "$out" > "$out/app.log" 2>&1 &
pid=$!
trap 'kill -TERM "$pid" 2>/dev/null || true; wait "$pid" 2>/dev/null || true' EXIT
sleep 4
xcrun --sdk macosx swift docs/evidence/J11.1/capture-window.swift "$pid" "$out" > "$out/window-capture.log" 2>&1
status=$?
echo "$status" > "$PWD/docs/evidence/J11.1/capture.exit"
exit "$status"
