#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/../../.."
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
out="$PWD/docs/evidence/J10.5/capture"
mkdir -p "$out"
app="$PWD/build/J105-Debug/Build/Products/Debug/Watt.app/Contents/MacOS/Watt"
pid=""
cleanup() {
    if [[ -n "$pid" ]]; then
        kill -TERM "$pid" 2>/dev/null || true
        for ((i=0; i<30; i++)); do kill -0 "$pid" 2>/dev/null || break; sleep .1; done
        if kill -0 "$pid" 2>/dev/null; then kill -KILL "$pid" 2>/dev/null || true; fi
        wait "$pid" 2>/dev/null || true
        echo "Fixture PID $pid terminated and reaped" > "$out/process-cleanup.log"
    fi
}
trap cleanup EXIT
"$app" --watt-fixture J10.5/base > "$out/app.log" 2>&1 &
pid=$!
sleep 3
ps -p "$pid" -o pid=,comm= > "$out/process.txt" || true
xcrun swift docs/evidence/J10.5/capture-window.swift "$pid" "$out" > "$out/window-capture.log" 2>&1
