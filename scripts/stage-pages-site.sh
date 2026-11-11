#!/bin/bash
# Copy the static landing page into a Pages artifact.
# This script never creates, deletes, or replaces updates/.
set -euo pipefail

source_root=${PAGES_SOURCE:?}
dest=${PAGES_DIR:?}

if [[ ! -d "$source_root/docs" ]]; then
  echo "Landing page source is missing docs/." >&2
  exit 1
fi
if [[ -e "$source_root/docs/updates" || -L "$source_root/docs/updates" ]]; then
  echo "The landing page source must not contain docs/updates." >&2
  exit 1
fi

files=(
  index.html
  site.css
  icon.png
  social-preview.png
)
shots=(
  menu-bar-light.png
  menu-bar-dark.png
  panel-light.png
  panel-dark.png
  settings-light.png
  settings-dark.png
)

for name in "${files[@]}"; do
  if [[ ! -f "$source_root/docs/$name" ]]; then
    echo "Missing docs/$name." >&2
    exit 1
  fi
done
for name in "${shots[@]}"; do
  if [[ ! -f "$source_root/docs/screenshots/$name" ]]; then
    echo "Missing docs/screenshots/$name." >&2
    exit 1
  fi
done

mkdir -p "$dest/screenshots"
for name in "${files[@]}"; do
  cp "$source_root/docs/$name" "$dest/$name"
done
for name in "${shots[@]}"; do
  cp "$source_root/docs/screenshots/$name" "$dest/screenshots/$name"
done

if [[ -e "$dest/updates/index.html" ]]; then
  echo "updates/index.html would hide the update manifest directory." >&2
  exit 1
fi
echo "Staged the landing page."
