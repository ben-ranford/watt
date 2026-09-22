#!/bin/bash
# Capture only the fixture PID's verified native compositor menu; never request permission.
set -euo pipefail
cd "$(dirname "$0")/../../.."
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
out="$PWD/docs/evidence/J5.3/capture"
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
    echo "$status" > docs/evidence/J5.3/capture.exit
    exit "$status"
}
trap cleanup EXIT
[[ -x "$app" ]]
"$app" --watt-fixture J5.3/base --watt-j53-capture-directory "$out" > "$out/app.log" 2>&1 &
pid=$!
# Wait for bridge identity metadata, while the real NSMenu remains in native tracking.
for ((i=0; i<80; i++)); do
    [[ -f "$out/capture-attempt.json" ]] && break
    kill -0 "$pid" 2>/dev/null || break
    sleep .1
done
ps -p "$pid" -o pid=,comm= > "$out/process.txt" || true
xcrun swift docs/evidence/J5.3/capture-window.swift "$pid" "$out" > "$out/window-capture.log" 2>&1
