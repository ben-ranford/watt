#!/bin/bash
# App-owned native NSMenu render attempt. No AX/TCC or desktop screenshot.
set -euo pipefail
out="$PWD/docs/evidence/C03"
rm -f "$out/capture-attempt.json" "$out/native-menu-0.png" "$out/native-menu-1.png"
app="$PWD/.build/c03-native/Build/Products/Debug/Watt.app/Contents/MacOS/Watt"
"$app" --watt-fixture C03/base --watt-c03-capture-directory "$out" > "$out/app.log" 2>&1 & pid=$!
trap 'kill "$pid" 2>/dev/null || true; wait "$pid" 2>/dev/null || true' EXIT
for ((i=0; i<100; i++)); do
  if [[ -f "$out/capture-attempt.json" ]]; then
    cat "$out/capture-attempt.json"
    python3 - "$out" <<'CHECK'
import json, pathlib, sys
root = pathlib.Path(sys.argv[1])
data = json.loads((root / "capture-attempt.json").read_text())
assert data["parentHighlighted"] is True, "Parent must be highlighted"
assert data["submenuHighlighted"] == "none", "Delta must remain idle"
assert data["deltaChecked"] is True, "Delta must remain checked"
assert len(data["windows"]) == 2, "Both native menu surfaces must be captured"
for window in data["windows"]:
    assert window["class"] == "NSPopupMenuWindow"
    assert (root / window["capture"]).is_file()
print("Native capture state contract passed (not a visual verdict)")
CHECK
    exit 0
  fi
  sleep .1
done
echo 'Native capture blocked: no app-owned menu capture metadata within 10s' >&2
exit 1
