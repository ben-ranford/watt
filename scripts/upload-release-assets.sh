#!/bin/bash
# Upload the archive products to the draft GitHub Release, then publish it.
set -euo pipefail

tag=${RELEASE_TAG:?}
output=${OUTPUT_DIR:?}
if [[ ! "$tag" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "Refusing release tag." >&2
  exit 1
fi
version=${tag#v}

files=(
  "$output/Watt-$version.tar"
  "$output/Watt-$version.tar.sha256"
  "$output/Watt-$version.zip"
  "$output/Watt-$version.dmg"
  "$output/distribution-preflight.txt"
)
if [[ -f "$output/Watt-$version-update-manifest.json" ]]; then
  files+=("$output/Watt-$version-update-manifest.json")
fi
for file in "${files[@]}"; do
  if [[ ! -f "$file" ]]; then
    echo "Missing release asset." >&2
    exit 1
  fi
done

gh release upload "$tag" "${files[@]}" --clobber
gh release edit "$tag" --draft=false
echo "Published GitHub release assets."
