#!/bin/bash
# Capture actual fixture PID-owned settings window and popup without prompting for access.
set -euo pipefail
cd "$(dirname "$0")/../../.."
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
out="$PWD/docs/evidence/J7.3/capture"
mkdir "$out" # A fresh directory is mandatory; refuse stale evidence.
app="$PWD/.build/xcode/Build/Products/Debug/Watt.app/Contents/MacOS/Watt"
pid=""
cleanup() {
    local status=$?
    if [[ -n "$pid" ]]; then
        kill -TERM "$pid" 2>/dev/null || true
        for ((i=0; i<30; i++)); do
            kill -0 "$pid" 2>/dev/null || break
            sleep .1
        done
        if kill -0 "$pid" 2>/dev/null; then kill -KILL "$pid" 2>/dev/null || true; fi
        wait "$pid" 2>/dev/null || true
        if kill -0 "$pid" 2>/dev/null; then
            echo "Fixture PID $pid remains alive" > "$out/process-cleanup.log"
            status=1
        else
            echo "Fixture PID $pid terminated and reaped" > "$out/process-cleanup.log"
        fi
    fi
    echo "$status" > docs/evidence/J7.3/capture.exit
    exit "$status"
}
trap cleanup EXIT
[[ -x "$app" ]]
"$app" --watt-fixture J7.3/base --watt-j73-capture-directory "$out" > "$out/app.log" 2>&1 &
pid=$!
for ((i=0; i<100; i++)); do
    [[ -f "$out/capture-attempt.json" ]] && break
    kill -0 "$pid" 2>/dev/null || break
    sleep .1
done
ps -p "$pid" -o pid=,comm= > "$out/process.txt" || true
xcrun swift docs/evidence/J7.3/capture-window.swift "$pid" "$out" > "$out/window-capture.log" 2>&1
