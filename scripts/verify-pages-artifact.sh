#!/bin/bash
# Require the landing page in a built Pages artifact.
# PAGES_REQUIRE_UPDATES=true (the default) also requires updates/manifest.json
# and updates/Watt.tar, unchanged by the landing-page copy.
set -euo pipefail

dest=${PAGES_DIR:?}
require_updates=${PAGES_REQUIRE_UPDATES:-true}
max_bytes=${PAGES_MAX_BYTES:-104857600}

for name in \
  index.html why-is-my-mac-charging-slowly.html compare.html \
  robots.txt sitemap.xml \
  site.css icon.png social-preview.png
do
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
import re
import struct
import sys
import xml.etree.ElementTree as ET
from pathlib import Path
from urllib.parse import urlparse

dest = Path(sys.argv[1])
require_updates = sys.argv[2] == 'true'
limit = int(sys.argv[3])

def reject_remote_html(text, name):
    lowered = text.lower()
    if 'http://' in lowered:
        raise SystemExit(f'{name} contains an http:// URL.')
    for token in (
        'googleapis', 'googletagmanager', 'google-analytics', 'plausible',
        'gtag(', 'cdn.jsdelivr', 'unpkg.com', 'fonts.google',
    ):
        if token in lowered:
            raise SystemExit(f'{name} loads a remote resource ({token}).')
    for attrs in re.findall(r'<script\b([^>]*)>', text, flags=re.I):
        if re.search(r'\bsrc\s*=', attrs, re.I):
            raise SystemExit(f'{name} loads a script.')
        kind = re.search(r'\btype\s*=\s*["\']([^"\']+)["\']', attrs, re.I)
        if kind is None or kind.group(1).lower() != 'application/ld+json':
            raise SystemExit(f'{name} contains a script element.')

pages = (
    'index.html',
    'why-is-my-mac-charging-slowly.html',
    'compare.html',
)
for name in pages:
    reject_remote_html((dest / name).read_text(encoding='utf-8'), name)

robots = (dest / 'robots.txt').read_text(encoding='utf-8')
if 'User-agent: *' not in robots or '\nAllow: /\n' not in f'\n{robots}\n':
    raise SystemExit('robots.txt does not allow all crawlers.')
sitemap_line = 'Sitemap: https://ben-ranford.github.io/watt/sitemap.xml'
if sitemap_line not in robots:
    raise SystemExit('robots.txt does not point at the sitemap.')

required_pages = {
    'https://ben-ranford.github.io/watt/',
    'https://ben-ranford.github.io/watt/why-is-my-mac-charging-slowly.html',
    'https://ben-ranford.github.io/watt/compare.html',
}
locs = []
for element in ET.parse(dest / 'sitemap.xml').getroot().iter():
    if element.tag.endswith('loc') and element.text and element.text.strip():
        locs.append(element.text.strip())
if set(locs) != required_pages:
    raise SystemExit(f'sitemap.xml pages are {locs}, expected the three site pages.')
root = dest.resolve()
for loc in locs:
    parsed = urlparse(loc)
    if parsed.scheme != 'https' or parsed.netloc != 'ben-ranford.github.io':
        raise SystemExit(f'sitemap loc is outside the site: {loc}')
    if parsed.query or parsed.fragment:
        raise SystemExit(f'sitemap loc has a query or fragment: {loc}')
    prefix = '/watt/'
    if not parsed.path.startswith(prefix):
        raise SystemExit(f'sitemap loc is outside /watt/: {loc}')
    relative = parsed.path[len(prefix):] or 'index.html'
    if relative.endswith('/'):
        relative += 'index.html'
    target = (dest / relative).resolve()
    if root not in target.parents or not target.is_file():
        raise SystemExit(f'sitemap URL does not resolve in the Pages artifact: {loc}')
print('Sitemap URLs resolve in the Pages artifact.')

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
