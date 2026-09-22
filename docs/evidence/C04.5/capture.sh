#!/bin/bash
set -euo pipefail
out="$PWD/docs/evidence/C04.5"
app="$PWD/.build/c045-native/Build/Products/Debug/Watt.app/Contents/MacOS/Watt"
rm -f "$out/capture.json" "$out/actual-status-item.png" "$out/actual-status-item-1x.png"
"$app" --watt-fixture C04.5/base --watt-c045-capture-directory "$out" > "$out/app.log" 2>&1 & pid=$!
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
