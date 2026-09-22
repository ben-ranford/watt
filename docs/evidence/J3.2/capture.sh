#!/bin/bash
# Real MenuBarExtra only; no replacement surface, AX prompt, or desktop capture.
set -euo pipefail
cd "$(dirname "$0")/../../.."
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
out="$PWD/docs/evidence/J3.2/capture-final"
mkdir "$out" # Reject stale evidence reuse.
app="$PWD/.build/xcode/Build/Products/Debug/Watt.app/Contents/MacOS/Watt"
"$app" --watt-fixture J3.2/base --watt-j32-capture-directory "$out" > "$out/app.log" 2>&1 &
pid=$!
trap 'kill -TERM "$pid" 2>/dev/null || true; wait "$pid" 2>/dev/null || true' EXIT
sleep 8
ps -p "$pid" -o pid=,comm= > "$out/process.txt"
# Reuse the PID-scoped J1.8 capture implementation; change only the fixture metadata.
sed 's/J1.8\/base/J3.2\/base/g' docs/evidence/J1.8/capture-window.swift > "$out/capture-window.swift"
xcrun swift "$out/capture-window.swift" "$pid" "$out" > "$out/window-capture.log" 2>&1
