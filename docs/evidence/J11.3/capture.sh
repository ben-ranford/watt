#!/bin/bash
# Capture only the exact J11.3 DEBUG fixture's real native Settings scene.
set -euo pipefail
cd "$(dirname "$0")/../../.."
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
out="$PWD/docs/evidence/J11.3/capture"
out="$out-$(date -u +%Y%m%dT%H%M%S)-$$"
mkdir -p "$out"
printf "%s\n" "$out" > docs/evidence/J11.3/capture-directory.txt
app="$PWD/build/J113-Debug/Build/Products/Debug/Watt.app/Contents/MacOS/Watt"
pid=""
cleanup() {
    local result=$?
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
            result=1
        else
            echo "Fixture PID $pid terminated and reaped" > "$out/process-cleanup.log"
        fi
    fi
    echo "$result" > docs/evidence/J11.3/capture.exit
    exit "$result"
}
trap cleanup EXIT
[[ -x "$app" ]]
"$app" --watt-fixture J11.3/base --watt-j113-capture-directory "$out" > "$out/app.log" 2>&1 &
pid=$!
for ((i=0; i<100; i++)); do
    [[ -f "$out/capture-attempt.json" ]] && break
    kill -0 "$pid" 2>/dev/null || break
    sleep .1
done
ps -p "$pid" -o pid=,comm= > "$out/process.txt" || true
xcrun swift docs/evidence/J11.3/capture-window.swift "$pid" "$out"
