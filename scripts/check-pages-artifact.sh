#!/bin/bash
# Build a Pages artifact from this repo and fixture update files, then require
# both the landing page and updates/. No network. CI and the release tests run it.
set -euo pipefail

root=$(cd "$(dirname "$0")/.." && pwd)
dest=$(mktemp -d)
trap 'rm -rf "$dest"' EXIT

python3 - "$dest" <<'PY'
import io
import tarfile
import sys
from pathlib import Path

updates = Path(sys.argv[1]) / 'updates'
updates.mkdir(parents=True)
(updates / 'manifest.json').write_bytes(b'{"payload":"e30=","signature":"YQ=="}')
buffer = io.BytesIO()
with tarfile.open(fileobj=buffer, mode='w', format=tarfile.USTAR_FORMAT) as archive:
    payload = b'watt-app'
    info = tarfile.TarInfo('Watt.app/Contents/Info.plist')
    info.size = len(payload)
    archive.addfile(info, io.BytesIO(payload))
data = buffer.getvalue()
if data[257:262] != b'ustar':
    raise SystemExit('Fixture tar is not ustar.')
(updates / 'Watt.tar').write_bytes(data)
PY

manifest_before=$(python3 -c 'import hashlib,sys; print(hashlib.sha256(open(sys.argv[1],"rb").read()).hexdigest())' "$dest/updates/manifest.json")
tar_before=$(python3 -c 'import hashlib,sys; print(hashlib.sha256(open(sys.argv[1],"rb").read()).hexdigest())' "$dest/updates/Watt.tar")

PAGES_SOURCE="$root" PAGES_DIR="$dest" bash "$root/scripts/stage-pages-site.sh"

manifest_after=$(python3 -c 'import hashlib,sys; print(hashlib.sha256(open(sys.argv[1],"rb").read()).hexdigest())' "$dest/updates/manifest.json")
tar_after=$(python3 -c 'import hashlib,sys; print(hashlib.sha256(open(sys.argv[1],"rb").read()).hexdigest())' "$dest/updates/Watt.tar")
if [[ "$manifest_before" != "$manifest_after" || "$tar_before" != "$tar_after" ]]; then
  echo "Staging the landing page changed updates/." >&2
  exit 1
fi

PAGES_DIR="$dest" PAGES_REQUIRE_UPDATES=true bash "$root/scripts/verify-pages-artifact.sh"
test -s "$dest/index.html"
test -s "$dest/updates/manifest.json"
test -s "$dest/updates/Watt.tar"
echo "PASS: landing page and updates/ are both in the Pages artifact."
