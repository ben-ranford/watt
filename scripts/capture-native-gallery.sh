#!/bin/bash
# F02 gallery through the F01 app-owned, permission-preflighted capture mechanism.
set -euo pipefail
cd "$(dirname "$0")/.."
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
output="${1:-docs/verification/f02-gallery/$(date -u +%Y%m%dT%H%M%SZ)}"
mkdir -p "$(dirname "$output")"
mkdir "$output"
output="$(cd "$output" && pwd)"
exec > >(tee "$output/verification.log") 2>&1
xcrun swiftc scripts/capture-native-panel.swift -o "$output/capture-window"
"$output/capture-window" --preflight
xcodebuild -project Watt.xcodeproj -scheme Watt -configuration Debug \
  -destination 'platform=macOS' -derivedDataPath .build/f02-native build > "$output/build.log" 2>&1
app="$PWD/.build/f02-native/Build/Products/Debug/Watt.app/Contents/MacOS/Watt"
pid=""
cleanup() {
  if [[ -n "$pid" ]]; then kill -TERM "$pid" 2>/dev/null || true; wait "$pid" 2>/dev/null || true; fi
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM
for specimen in gallery reading settings; do
for appearance in light dark; do
  variant="$appearance"
  args=("--watt-capture-gallery-$appearance")
  if [[ "$specimen" != gallery ]]; then
    variant="$specimen-$appearance"
    args+=("--watt-specimen-$specimen")
  fi
  mkdir "$output/$variant"
  "$app" "${args[@]}" > "$output/$variant/app.log" 2>&1 &
  pid=$!
  "$output/capture-window" "$pid" "$output/$variant" "$variant"
  shasum -a 256 "$output/$variant/gallery-$variant.png" > "$output/$variant/gallery.sha256"
  cleanup
  pid=""
done
done
