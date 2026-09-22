#!/bin/bash
# Capture only a fixture PID-owned native panel; no desktop or cached-view substitute.
set -euo pipefail
cd "$(dirname "$0")/../../.."
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
out="$PWD/docs/evidence/J6.5/capture"
mkdir "$out" # Reject reuse so an old capture cannot pass as fresh.
app="$PWD/.build/xcode/Build/Products/Debug/Watt.app/Contents/MacOS/Watt"
pid=""
cleanup() {
    local status=$?
    if [[ -n "$pid" ]]; then
        kill -TERM "$pid" 2>/dev/null || true
        wait "$pid" 2>/dev/null || true
        if kill -0 "$pid" 2>/dev/null; then
            echo "Fixture PID $pid remains alive" > "$out/process-cleanup.log"
            status=1
        else
            echo "Fixture PID $pid terminated and reaped" > "$out/process-cleanup.log"
        fi
    fi
    echo "$status" > docs/evidence/J6.5/capture.exit
    exit "$status"
}
trap cleanup EXIT
[[ -x "$app" ]]
"$app" --watt-fixture J6.5/base > "$out/app.log" 2>&1 &
pid=$!
# The real status bridge opens MenuBarExtra; no replacement window is created here.
sleep 4
ps -p "$pid" -o pid=,comm= > "$out/process.txt" || true
xcrun swift docs/evidence/J6.5/capture-window.swift "$pid" "$out" > "$out/window-capture.log" 2>&1
