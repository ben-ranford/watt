#!/bin/bash
# Run from the repository root after building the native Debug target.
# Requires existing Screen Recording permission; never requests TCC or AX access.
set -euo pipefail
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
out="$PWD/docs/evidence/C01"
xcrun swiftc "$out/capture.swift" -o .build/c01-capture
.build/c01-capture --preflight
app="$PWD/.build/c01-native/Build/Products/Debug/Watt.app/Contents/MacOS/Watt"
"$app" --watt-fixture C01 > "$out/app.log" 2>&1 & pid=$!
trap 'kill "$pid" 2>/dev/null || true; wait "$pid" 2>/dev/null || true' EXIT
.build/c01-capture "$pid" "$out" C01 > "$out/capture.log" 2>&1

# Retain raw pixels; comparison alone uses an explicitly resampled derivative.
sips -z 473 320 "$out/gallery-C01.png" --out "$out/captured-panel-1x.png" > "$out/normalization.log"
xcrun swiftc scripts/F05/image-evidence.swift -o .build/c01-image-evidence
comparison_exit=0
.build/c01-image-evidence diff "$out/reference-panel.png" \
  "$out/captured-panel-1x.png" "$out/comparison" 1 1 0.01 || comparison_exit=$?
if [[ "$comparison_exit" != 0 && "$comparison_exit" != 2 ]]; then
  exit "$comparison_exit"
fi
echo "Pixel comparison exit: $comparison_exit (2 = diagnostic tolerance failure, not visual verdict)"
(cd "$out" && shasum -a 256 reference-21-928.png reference-panel.png gallery-C01.png \
  captured-panel-1x.png comparison-overlay.png comparison-diff.png > images.sha256)
