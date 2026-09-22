#!/bin/bash
set -euo pipefail
out="${1:?native capture output directory}"
tool="$out/image-evidence"
input="$out/light-1/gallery-light.png"
"$tool" crop "$input" "$out/crop.png" 0 0 100 100
"$tool" diff "$out/crop.png" "$out/crop.png" "$out/crop-repeat" 2 2 0
reject() {
  if "$tool" "$@"; then echo "Unexpected acceptance: $*"; exit 1; fi
}
reject crop "$input" "$out/invalid.png" -1 0 100 100
reject diff "$input" "$input" "$out/invalid" 1 2 0
reject diff "$input" "$out/crop.png" "$out/invalid" 2 2 0
reject diff "$input" "$input" "$out/invalid" 2 2 -1
echo '6 helper checks passed (crop, identical diff, bounds, scale, geometry, invalid threshold)'
