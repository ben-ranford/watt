#!/bin/bash
# Run from worktree root. Isolated app-local input only; no desktop capture or AX.
set -euo pipefail
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
out="$PWD/docs/evidence/C03/custom-view-experiment"
xcrun swiftc -swift-version 6 -warnings-as-errors "$out/probe.swift" -o .build/c03-menu-view-probe > "$out/build.log" 2>&1
for mode in native custom; do
  rm -f "$out/$mode.json" "$out/$mode-0.png" "$out/$mode-1.png"
  .build/c03-menu-view-probe "$mode" "$out"
done
python3 - "$out" <<'CHECK'
import json, pathlib, sys
root = pathlib.Path(sys.argv[1])
for mode in ('native', 'custom'):
    data = json.loads((root / f'{mode}.json').read_text())
    assert data['submenuAttached'] and data['deltaStateRetained']
    assert 'shortcut dispatched: true' in data['events']
    assert 'open: submenu' in data['events']
    assert all((root / f'{mode}-{i}.png').is_file() for i in range(2))
    print(mode, data['events'])
# This records the observed rejection, not a cross-version AppKit guarantee.
native = json.loads((root / 'native.json').read_text())['events']
custom = json.loads((root / 'custom.json').read_text())['events']
assert 'action: Charger' in native and 'fallback cancel' not in native
assert 'action: Charger' not in custom and 'fallback cancel' in custom
CHECK
(cd "$out" && shasum -a 256 ./*.swift ./*.png ./*.json > artifacts.sha256)
