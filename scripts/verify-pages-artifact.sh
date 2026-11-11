#!/bin/bash
# Require the landing page in a built Pages artifact.
# PAGES_REQUIRE_UPDATES=true (the default) also requires updates/manifest.json
# and updates/Watt.tar, unchanged by the landing-page copy.
set -euo pipefail

dest=${PAGES_DIR:?}
require_updates=${PAGES_REQUIRE_UPDATES:-true}
max_bytes=${PAGES_MAX_BYTES:-104857600}

for name in index.html site.css icon.png social-preview.png; do
  if [[ ! -s "$dest/$name" ]]; then
    echo "Pages artifact is missing $name." >&2
    exit 1
  fi
done
for name in \
  menu-bar-light.png menu-bar-dark.png \
  panel-light.png panel-dark.png \
  settings-light.png settings-dark.png
do
  if [[ ! -s "$dest/screenshots/$name" ]]; then
    echo "Pages artifact is missing screenshots/$name." >&2
    exit 1
  fi
done
if [[ -e "$dest/updates/index.html" ]]; then
  echo "Pages artifact has updates/index.html." >&2
  exit 1
fi

python3 - "$dest" "$require_updates" "$max_bytes" <<'PY'
import json
import struct
import sys
from pathlib import Path

dest = Path(sys.argv[1])
require_updates = sys.argv[2] == 'true'
limit = int(sys.argv[3])

html = (dest / 'index.html').read_text(encoding='utf-8').lower()
if '<script' in html:
    raise SystemExit('Landing page contains a script element.')
css = (dest / 'site.css').read_text(encoding='utf-8').lower()
if '@import' in css or 'url(http' in css or 'fonts.google' in css:
    raise SystemExit('Landing page stylesheet loads a remote resource.')

preview = (dest / 'social-preview.png').read_bytes()
if preview[:8] != b'\x89PNG\r\n\x1a\n' or preview[12:16] != b'IHDR':
    raise SystemExit('social-preview.png is not a PNG.')
width, height = struct.unpack('>II', preview[16:24])
if (width, height) != (1280, 640):
    raise SystemExit(f'social-preview.png is {width}x{height}, expected 1280x640.')

manifest_path = dest / 'updates' / 'manifest.json'
tar_path = dest / 'updates' / 'Watt.tar'
present = manifest_path.is_file() or tar_path.is_file()
if require_updates or present:
    if not manifest_path.is_file() or not tar_path.is_file():
        raise SystemExit('Pages artifact is missing updates/manifest.json or updates/Watt.tar.')
    document = json.loads(manifest_path.read_text(encoding='utf-8'))
    if not isinstance(document, dict) or not isinstance(document.get('payload'), str) or not document['payload']:
        raise SystemExit('updates/manifest.json is not a signed update document.')
    if not isinstance(document.get('signature'), str) or not document['signature']:
        raise SystemExit('updates/manifest.json is not a signed update document.')
    data = tar_path.read_bytes()
    if len(data) < 262 or data[257:262] != b'ustar':
        raise SystemExit('updates/Watt.tar is not an uncompressed ustar archive.')
    if len(data) > limit:
        raise SystemExit(f'updates/Watt.tar is {len(data)} bytes, above the {limit}-byte limit.')
print('Pages artifact contains the landing page and the required update paths.')
PY
