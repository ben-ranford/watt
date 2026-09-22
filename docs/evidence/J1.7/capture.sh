#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/../../.."
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
out="$PWD/docs/evidence/J1.7"
app="${WATT_J17_APP:-/tmp/watt-g034-debug/Build/Products/Debug/Watt.app/Contents/MacOS/Watt}"
"$app" --watt-fixture J1.7/base --watt-j17-capture-directory "$out" > "$out/fixture-launch.log" 2>&1 &
pid=$!
trap 'kill "$pid" 2>/dev/null || true' EXIT
sleep 4
xcrun swift "$out/capture-window.swift" "$pid" "$out" > "$out/window-capture.log" 2>&1
