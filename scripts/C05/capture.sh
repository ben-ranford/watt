#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/../.."
out="${1:-$PWD/docs/evidence/C05}"
mkdir -p "$out"
out="$(cd "$out" && pwd)"
rm -f "$out/capture.json" "$out/actual-content.png"
app="$PWD/.build/c05-native/Build/Products/Debug/Watt.app/Contents/MacOS/Watt"
"$app" --watt-fixture C05/base --watt-c05-capture-directory "$out" > "$out/app.log" 2>&1 & pid=$!
trap 'kill "$pid" 2>/dev/null || true; wait "$pid" 2>/dev/null || true' EXIT
for ((i=0; i<150; i++)); do
    if [[ -f "$out/capture.json" ]]; then
        shasum -a 256 "$out/actual-content.png" > "$out/images.sha256"
        cat "$out/capture.json"
        exit 0
    fi
    sleep .1
done
cat "$out/app.log"
echo 'C05 capture did not produce evidence' >&2
exit 1
