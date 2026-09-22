#!/bin/bash
# No TCC requests, preferences, network, hardware or production app composition.
set -euo pipefail
cd "$(dirname "$0")/../.."
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
out="${1:?supply a new output directory}"
mkdir -p "$(dirname "$out")"
mkdir "$out"
out="$(cd "$out" && pwd)"
xcrun swiftc scripts/capture-native-panel.swift -o "$out/capture-window"
"$out/capture-window" --preflight
xcrun swiftc -D DEBUG -parse-as-library Tests/Fixtures/*.swift DesignSystem/Theme/*.swift \
  DesignSystem/Components/*.swift DesignSystem/Verification/*.swift Models/*.swift Services/*.swift \
  scripts/F05/GalleryHost.swift -o "$out/gallery-host"
xcrun swiftc scripts/F05/image-evidence.swift -o "$out/image-evidence"
pid=""
cleanup() { if [[ -n "$pid" ]]; then kill -TERM "$pid" 2>/dev/null || true; wait "$pid" 2>/dev/null || true; fi; }
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM
for appearance in light dark; do
  for run in 1 2; do
    dir="$out/$appearance-$run"; mkdir "$dir"
    "$out/gallery-host" --watt-fixture "F02.gallery.$appearance" > "$dir/app.log" 2>&1 & pid=$!
    "$out/capture-window" "$pid" "$dir" "$appearance"
    cleanup; pid=""
  done
  scale=$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["pixelsPerPoint"])' "$out/$appearance-1/window.json")
  scale2=$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["pixelsPerPoint"])' "$out/$appearance-2/window.json")
  # Strict repeatability calibration, not a Figma visual acceptance threshold.
  "$out/image-evidence" diff "$out/$appearance-1/gallery-$appearance.png" "$out/$appearance-2/gallery-$appearance.png" "$out/$appearance-repeat" "$scale" "$scale2" 0
  "$out/image-evidence" perturb "$out/$appearance-1/gallery-$appearance.png" "$out/$appearance-perturbed.png"
  set +e
  "$out/image-evidence" diff "$out/$appearance-1/gallery-$appearance.png" "$out/$appearance-perturbed.png" "$out/$appearance-negative" "$scale" "$scale" 0
  result=$?
  set -e
  [[ "$result" == 2 ]] || { echo 'Perturbation was not detected'; exit 1; }
done

python3 - "$out" <<'PYMETA'
import datetime, hashlib, json, pathlib, platform, subprocess, sys
root = pathlib.Path(sys.argv[1])
record = {
    "kind": "F05 foundation-only smoke; no story Done",
    "dateUTC": datetime.datetime.now(datetime.timezone.utc).isoformat(),
    "commit": subprocess.check_output(["git", "rev-parse", "HEAD"], text=True).strip(),
    "dirtyWorktree": bool(subprocess.check_output(["git", "status", "--porcelain"], text=True)),
    "xcode": subprocess.check_output(["xcodebuild", "-version"], text=True).strip(),
    "osBuild": subprocess.check_output(["sw_vers"], text=True).strip(),
    "architecture": platform.machine(), "locale": "en_US",
    "destination": "native macOS; iOS Simulator not applicable",
    "fixtures": ["F02.gallery.light", "F02.gallery.dark"],
    "storage": "local view state only; no WattApp composition",
    "masks": [], "threshold": "0 changed pixels; exact-repeat smoke only, not a Figma acceptance threshold",
    "accessibility": "not audited", "productionServices": "not invoked or verified",
    "storyVerdict": "not implemented", "reviewerVerdict": "pending",
    "sha256": {str(p.relative_to(root)): hashlib.sha256(p.read_bytes()).hexdigest() for p in sorted(root.rglob("*.png"))}
}
(root / "evidence.json").write_text(json.dumps(record, indent=2, sort_keys=True) + "\n")
PYMETA
