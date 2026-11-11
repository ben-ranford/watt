#!/bin/bash
# Download the updates already published on GitHub Pages into a Pages artifact.
# A docs deploy calls this before copying the landing page. Failure leaves the
# destination's updates/ directory untouched, and the caller must not deploy.
set -euo pipefail

dest=${PAGES_DIR:?}
base=${PAGES_UPDATES_BASE:-https://ben-ranford.github.io/watt/updates}
base=${base%/}
max_bytes=${PAGES_MAX_BYTES:-104857600}

python3 - "$base" <<'PY'
import sys
from urllib.parse import urlparse

url = urlparse(sys.argv[1])
if url.username or url.password or url.query or url.fragment:
    raise SystemExit('Refusing update base.')
if url.scheme == 'https':
    raise SystemExit(0)
if url.scheme == 'http' and url.hostname == '127.0.0.1':
    raise SystemExit(0)
raise SystemExit('Refusing update base.')
PY

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

fetch_code() {
  local url=$1 out=$2
  curl -sS -L --retry 3 --max-time 60 -o "$out" -w '%{http_code}' "$url" || true
}

manifest_code=$(fetch_code "$base/manifest.json" "$work/manifest.json")
tar_code=$(fetch_code "$base/Watt.tar" "$work/Watt.tar")

allow_absent=false
if [[ "${PAGES_ALLOW_ABSENT:-}" == true ]]; then
  allow_absent=true
fi
if [[ "$allow_absent" == true && "$manifest_code" == 404 && "$tar_code" == 404 ]]; then
  echo "No published updates to preserve."
  if [[ -n "${GITHUB_OUTPUT:-}" ]]; then
    echo "updates=absent" >> "$GITHUB_OUTPUT"
  fi
  exit 0
fi
if [[ "$manifest_code" != 200 || "$tar_code" != 200 ]]; then
  echo "Refusing to deploy without the published updates (manifest HTTP ${manifest_code}, tar HTTP ${tar_code})." >&2
  exit 1
fi

python3 - "$work/manifest.json" "$work/Watt.tar" "$max_bytes" <<'PY'
import json
import sys
from pathlib import Path

manifest_path, tar_path, limit_text = sys.argv[1:]
limit = int(limit_text)
document = json.loads(Path(manifest_path).read_text())
if not isinstance(document, dict) or not isinstance(document.get('payload'), str) or not document['payload']:
    raise SystemExit('Published manifest is not a signed update document.')
if not isinstance(document.get('signature'), str) or not document['signature']:
    raise SystemExit('Published manifest is not a signed update document.')
data = Path(tar_path).read_bytes()
if len(data) < 262 or data[257:262] != b'ustar':
    raise SystemExit('Published artifact is not an uncompressed ustar archive.')
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
echo "Preserved updates/manifest.json and updates/Watt.tar."
if [[ -n "${GITHUB_OUTPUT:-}" ]]; then
  echo "updates=preserved" >> "$GITHUB_OUTPUT"
fi
