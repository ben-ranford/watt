#!/bin/bash
# Stage updates/manifest.json and updates/Watt.tar for one GitHub Pages deploy.
# Both files come from the same published release, then one artifact replaces the site.
set -euo pipefail

tag=${RELEASE_TAG:?}
repo=${SOURCE_REPO:-ben-ranford/watt}
dest=${PAGES_DIR:-site}
# GitHub blocks a single file at 100 MiB. Pages publishes that file as a static asset.
max_bytes=${PAGES_MAX_BYTES:-104857600}

if [[ ! "$tag" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "Refusing release tag." >&2
  exit 1
fi
version=${tag#v}
asset_base=${RELEASE_ASSET_BASE:-https://github.com/${repo}/releases/download/${tag}}

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

fetch_code() {
  local url=$1 out=$2
  curl -sS -L --retry 3 -o "$out" -w '%{http_code}' "$url" || true
}

manifest_code=$(fetch_code "$asset_base/Watt-${version}-update-manifest.json" "$work/manifest.json")
if [[ "$manifest_code" == 404 ]]; then
  echo "No signed update manifest on ${tag}. Skipping the GitHub Pages deploy."
  if [[ -n "${GITHUB_OUTPUT:-}" ]]; then
    echo "deploy=false" >> "$GITHUB_OUTPUT"
  fi
  exit 0
fi
if [[ "$manifest_code" != 200 ]]; then
  echo "Could not download the signed update manifest (HTTP ${manifest_code})." >&2
  exit 1
fi

tar_code=$(fetch_code "$asset_base/Watt-${version}.tar" "$work/Watt.tar")
if [[ "$tar_code" != 200 ]]; then
  echo "Signed manifest is present but the ustar artifact is missing (HTTP ${tar_code})." >&2
  exit 1
fi

python3 - "$work/manifest.json" "$work/Watt.tar" "$max_bytes" <<'PY'
import json
import sys
from pathlib import Path

manifest_path, tar_path, limit_text = sys.argv[1:]
limit = int(limit_text)
document = json.loads(Path(manifest_path).read_text())
if not isinstance(document, dict) or not isinstance(document.get('payload'), str) or not isinstance(document.get('signature'), str):
    raise SystemExit('Downloaded manifest is not a signed update document.')
data = Path(tar_path).read_bytes()
if len(data) < 262 or data[257:262] != b'ustar':
    raise SystemExit('Downloaded artifact is not an uncompressed ustar archive.')
if len(data) > limit:
    raise SystemExit(
        f'Watt.tar is {len(data)} bytes, above the {limit}-byte GitHub Pages file limit. '
        'Refusing to publish it.'
    )
PY

mkdir -p "$dest/updates"
cp "$work/manifest.json" "$dest/updates/manifest.json"
cp "$work/Watt.tar" "$dest/updates/Watt.tar"
cmp -s "$work/manifest.json" "$dest/updates/manifest.json"
cmp -s "$work/Watt.tar" "$dest/updates/Watt.tar"
echo "Staged updates/manifest.json and updates/Watt.tar from ${tag}."
if [[ -n "${GITHUB_OUTPUT:-}" ]]; then
  echo "deploy=true" >> "$GITHUB_OUTPUT"
fi
