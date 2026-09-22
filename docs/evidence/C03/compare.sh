#!/bin/bash
# Comparison derivatives only; raw native menu captures are never altered.
set -euo pipefail
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
out="$PWD/docs/evidence/C03"
cmp .omx/plans/f00-reference-evidence/exports/22-1095.png "$out/reference-22-1095.png"
xcrun swiftc scripts/F05/image-evidence.swift -o .build/c03-image-evidence
.build/c03-image-evidence crop "$out/reference-22-1095.png" "$out/reference-menu.png" 561 38 230 187
.build/c03-image-evidence crop "$out/reference-22-1095.png" "$out/reference-submenu.png" 375 38 190 141
.build/c03-image-evidence crop "$out/reference-22-1095.png" "$out/reference-menus.png" 375 38 416 187
sips -z 187 230 "$out/native-menu-0.png" --out "$out/native-menu-1x.png" > "$out/normalization.log"
sips -z 141 190 "$out/native-menu-1.png" --out "$out/native-submenu-1x.png" >> "$out/normalization.log"
for name in menu submenu; do
  result=0
  .build/c03-image-evidence diff "$out/reference-$name.png" "$out/native-$name-1x.png" "$out/$name-comparison" 1 1 0.01 || result=$?
  [[ "$result" == 0 || "$result" == 2 ]] || exit "$result"
  echo "$name pixel diagnostic exit: $result (not a visual verdict)"
done
(cd "$out" && shasum -a 256 ./*.png > images.sha256)
(cd "$out" && shasum -a 256 ./*.json ./*.sh README.md > metadata.sha256)
