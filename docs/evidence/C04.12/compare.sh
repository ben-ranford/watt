#!/bin/bash
# Raw evidence remains untouched. Diagnostics are not a visual verdict.
set -euo pipefail
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
out="$PWD/docs/evidence/C04.12"
xcrun swiftc scripts/F05/image-evidence.swift -o .build/c0412-image-evidence
# The app writes the 1x bitmap directly; never downsample the Retina diagnostic.
test -f "$out/actual-status-item-1x.png"
printf '%s\n' 'Direct AppKit 560x44 bitmap, 560x44 points; no resize/resampling.' > "$out/normalization.log"
.build/c0412-image-evidence crop "$out/reference-24-1960.png" "$out/reference-item.png" 204 5 97 24
.build/c0412-image-evidence crop "$out/actual-status-item-1x.png" "$out/actual-item.png" 204 5 97 24
for scope in frame item; do
  if [[ "$scope" == frame ]]; then
    reference="$out/reference-24-1960.png"; actual="$out/actual-status-item-1x.png"
  else
    reference="$out/reference-item.png"; actual="$out/actual-item.png"
  fi
  status=0
  .build/c0412-image-evidence diff "$reference" "$actual" "$out/$scope-comparison" 1 1 0.01 || status=$?
  [[ "$status" == 0 || "$status" == 2 ]] || exit "$status"
  echo "$scope diagnostic exit $status — not a visual verdict"
done
(cd "$out" && shasum -a 256 ./*.png > images.sha256)
