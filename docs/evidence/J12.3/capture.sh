#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/../../.."
out=docs/evidence/J12.3
binary=build/J123-Debug/Build/Products/Debug/Watt.app/Contents/MacOS/Watt
"$binary" --watt-fixture J12.3/base > "$out/launch.log" 2>&1 &
pid=$!
wait "$pid"
printf '{"pid":%s,"exitCode":0,"controlledNoWattLaunch":true,"productionUninstallVerified":false}\n' "$pid" > "$out/launch.json"
if kill -0 "$pid" 2>/dev/null; then exit 2; fi
swift "$out/capture.swift" "$out"
# Never activate Finder, alter wallpaper/Dock, hide unrelated apps, or request TCC access.
screencapture -x "$out/native-desktop.png"
