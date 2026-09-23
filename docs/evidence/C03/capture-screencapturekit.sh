#!/bin/bash
set -euo pipefail

root="$(cd "$(dirname "$0")/../../.." && pwd)"
out="$root/docs/evidence/C03/screencapturekit"
derived="$root/.build/c03-screencapturekit"
app="$derived/Build/Products/Debug/Watt.app/Contents/MacOS/Watt"
probe="$derived/screencapturekit-window"

mkdir -p "$out" "$derived"
rm -f "$out"/capture.json "$out"/sck-menu-0.png "$out"/sck-menu-1.png \
  "$out"/sck-screen-0.png "$out"/sck-screen-1.png "$out"/app.log "$out"/probe.log

DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}" \
  xcodebuild -project "$root/Watt.xcodeproj" -scheme Watt -configuration Debug \
  -destination 'platform=macOS' -derivedDataPath "$derived" build \
  >"$out/build.log" 2>&1

DEVELOPER_DIR="$DEVELOPER_DIR" xcrun swiftc -swift-version 6 -warnings-as-errors \
  -o "$probe" "$root/docs/evidence/C03/screencapturekit-window.swift" \
  -framework ScreenCaptureKit -framework AppKit -framework ImageIO \
  -framework UniformTypeIdentifiers >"$out/probe-build.log" 2>&1

"$app" --watt-fixture C03/base --watt-c03-capture-directory "$out" >"$out/app.log" 2>&1 &
pid=$!
trap 'kill "$pid" 2>/dev/null || true; wait "$pid" 2>/dev/null || true' EXIT

"$probe" "$pid" "$out" >"$out/probe.log" 2>&1
python3 - "$out/capture.json" <<'PY'
import json
import pathlib
import sys

path = pathlib.Path(sys.argv[1])
data = json.loads(path.read_text())
records = data.get("records", [])
assert len(records) == 2, f"expected two native menu windows, got {len(records)}"
for record in records:
    for key in ("capture", "screenCapture"):
        image = path.parent / record[key]
        assert image.is_file(), image
print("ScreenCaptureKit app-owned menu capture contract passed")
PY
