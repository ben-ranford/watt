#!/bin/bash
set -euo pipefail
out="$PWD/docs/evidence/C04.8"
app="$PWD/.build/c048-native/Build/Products/Debug/Watt.app/Contents/MacOS/Watt"
rm -f "$out/capture.json" "$out/actual-status-item.png" "$out/actual-status-item-1x.png"
"$app" --watt-fixture C04.8/base --watt-c048-capture-directory "$out" > "$out/app.log" 2>&1 & pid=$!
trap 'kill "$pid" 2>/dev/null || true; wait "$pid" 2>/dev/null || true' EXIT
for ((i=0; i<150; i++)); do
  if [[ -f "$out/capture.json" ]]; then
    cat "$out/capture.json"
    exit 0
  fi
  sleep .1
done
cat "$out/app.log"
echo 'Capture did not produce actual-status-item evidence' >&2
exit 1
