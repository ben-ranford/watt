#!/bin/bash
# J11.2 native capture: fail closed; never request TCC or substitute a window.
set -u
cd "$(dirname "$0")/../../.."
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
out="$PWD/docs/evidence/J11.2/capture"
if [[ -d "$out" ]]; then mv "$out" "${out}-$(date +%Y%m%dT%H%M%S)-$$"; fi
mkdir -p "$out"
write_blocked() {
  python3 - "$1" "$out/window.json" <<'PY'
import json, sys
reason=sys.argv[1]
json.dump({
  "fixture":"J11.2/base", "node":"36:5186", "windowNode":"36:5188", "formNode":"36:5197",
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
  echo "1" > "$PWD/docs/evidence/J11.2/capture.exit"
  echo "blocked: $dev" > "$out/capture.log"
  exit 1
fi
app="$PWD/build/J112-Debug/Build/Products/Debug/Watt.app/Contents/MacOS/Watt"
if [[ ! -x "$app" ]]; then
  write_blocked "Debug fixture app is unavailable; capture not attempted"
  echo "1" > "$PWD/docs/evidence/J11.2/capture.exit"
  exit 1
fi
"$app" --watt-fixture J11.2/base --watt-j112-capture-directory "$out" > "$out/app.log" 2>&1 &
pid=$!
cleanup() {
  kill -TERM "$pid" 2>/dev/null || true
  for ((i=0; i<30; i++)); do kill -0 "$pid" 2>/dev/null || break; sleep .1; done
  if kill -0 "$pid" 2>/dev/null; then kill -KILL "$pid" 2>/dev/null || true; fi
  wait "$pid" 2>/dev/null || true
  echo "Fixture PID $pid terminated and reaped" > "$out/process-cleanup.log"
}
trap cleanup EXIT
sleep 10
ps -p "$pid" -o pid=,etime=,comm= > "$out/process.log" 2>&1 || true
xcrun --sdk macosx swift "$PWD/docs/evidence/J11.2/capture-window.swift" "$pid" "$out" > "$out/window-capture.log" 2>&1
status=$?
echo "$status" > "$PWD/docs/evidence/J11.2/capture.exit"
exit "$status"
