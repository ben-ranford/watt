#!/bin/bash
# Capture only the real fixture PID's compositor windows; no permission request or synthetic fallback.
set -uo pipefail
cd "$(dirname "$0")/../../.."
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
out="$PWD/docs/evidence/J5.1/capture"
mkdir -p "$out"
app="$PWD/.build/xcode/Build/Products/Debug/Watt.app/Contents/MacOS/Watt"
"$app" --watt-fixture J5.1/base > "$out/app.log" 2>&1 &
pid=$!
trap 'kill -TERM "$pid" 2>/dev/null || true; wait "$pid" 2>/dev/null || true' EXIT
sleep 8
ps -p "$pid" -o pid=,comm= > "$out/process.txt"
xcrun swift docs/evidence/J5.1/capture-window.swift "$pid" "$out" > "$out/window-capture.log" 2>&1
status=$?
echo "$status" > docs/evidence/J5.1/capture.exit
exit "$status"
