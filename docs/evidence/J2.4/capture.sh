#!/bin/bash
# App-owned Settings window only. No desktop capture, permission prompts or replacement chrome.
set -euo pipefail
cd "$(dirname "$0")/../../.."
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
out="$PWD/docs/evidence/J2.4/capture-final"
mkdir "$out"
app="$PWD/.build/xcode/Build/Products/Debug/Watt.app/Contents/MacOS/Watt"
"$app" --watt-fixture J2.4/base > "$out/app.log" 2>&1 &
pid=$!
trap 'kill -TERM "$pid" 2>/dev/null || true; wait "$pid" 2>/dev/null || true' EXIT
sleep 8
ps -p "$pid" -o pid=,comm= > "$out/process.txt"
xcrun swift docs/evidence/J2.4/capture-window.swift "$pid" "$out" > "$out/window-capture.log" 2>&1
