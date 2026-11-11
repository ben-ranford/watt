#!/usr/bin/env python3
"""Fail when Watt ships an empty AppIcon set or the Xcode placeholder icon.

The v1.0.1 asset catalog had an empty AppIcon.appiconset images array, so
Finder, the Dock, alerts and notifications had no icon. The setup window
loaded WattAppIcon, which was Xcode's grey placeholder. This check runs in
the release-config tests and again from scripts/release-archive.sh.
"""

from __future__ import annotations

import hashlib
import json
import plistlib
import struct
import sys
import zlib
from pathlib import Path

# SHA-256 of Resources/Assets.xcassets/WattAppIcon.imageset/watt-app-icon.png
# at v1.0.1: the grey rounded placeholder, 256×256 RGBA.
PLACEHOLDER_SHA256 = '948a88b21b68fcf435b3ca2c4c5b8be2900ee3f585cf7befe6dc3e9f97ad9b67'

# macOS app-icon slots. Pixel size is points × scale.
MAC_SLOTS = (
    ('16x16', '1x', 16),
    ('16x16', '2x', 32),
    ('32x32', '1x', 32),
    ('32x32', '2x', 64),
    ('128x128', '1x', 128),
    ('128x128', '2x', 256),
    ('256x256', '1x', 256),
    ('256x256', '2x', 512),
    ('512x512', '1x', 512),
    ('512x512', '2x', 1024),
)

APP_ICON = Path('Resources/Assets.xcassets/AppIcon.appiconset')
WATT_ICON = Path('Resources/Assets.xcassets/WattAppIcon.imageset')
INFO_PLIST = Path('Resources/App/Info.plist')
PROJECT = Path('Watt.xcodeproj/project.pbxproj')
ICON_NAME = 'AppIcon'
ICON_SETTING = '"ASSETCATALOG_COMPILER_APPICON_NAME" = "AppIcon";'


def failures(root: Path, *, placeholder_sha256: str = PLACEHOLDER_SHA256) -> list[str]:
    """Reasons the tree at `root` must not ship. Empty means the icon is present."""
    found: list[str] = []

    def require(value: bool, reason: str) -> None:
        if not value:
            found.append(reason)

    catalog = root / APP_ICON / 'Contents.json'
    try:
        document = json.loads(catalog.read_text())
    except (OSError, json.JSONDecodeError) as error:
        found.append('AppIcon.appiconset/Contents.json is unreadable: ' + str(error))
        document = {}
    images = document.get('images', None)
    require(isinstance(images, list), 'AppIcon.appiconset is missing an images array')
    if isinstance(images, list):
        require(len(images) > 0, 'AppIcon.appiconset images array is empty')
        intent = document.get('properties', {}).get('template-rendering-intent')
        require(intent != 'template', 'AppIcon must not use template rendering')
        seen: set[tuple[str, str]] = set()
        for image in images:
            if not isinstance(image, dict):
                found.append('AppIcon.appiconset has an image entry that is not an object')
                continue
            key = (str(image.get('size', '')), str(image.get('scale', '')))
            seen.add(key)
            filename = image.get('filename', '')
            require(
                image.get('idiom') == 'mac' and isinstance(filename, str) and filename != '',
                'AppIcon slot is missing a macOS file: ' + ' '.join(key),
            )
            if not isinstance(filename, str) or filename == '':
                continue
            path = root / APP_ICON / filename
            expected = next((pixels for size, scale, pixels in MAC_SLOTS if (size, scale) == key), None)
            if expected is None:
                continue
            _require_icon(found, path, expected, placeholder_sha256, 'AppIcon ' + filename)
        for size, scale, _pixels in MAC_SLOTS:
            require((size, scale) in seen, 'AppIcon.appiconset is missing ' + size + ' @' + scale)

    imageset = root / WATT_ICON / 'Contents.json'
    try:
        bundled = json.loads(imageset.read_text())
    except (OSError, json.JSONDecodeError) as error:
        found.append('WattAppIcon.imageset/Contents.json is unreadable: ' + str(error))
        bundled = {}
    names = [
        image.get('filename')
        for image in bundled.get('images', [])
        if isinstance(image, dict) and isinstance(image.get('filename'), str)
    ]
    require(len(names) > 0, 'WattAppIcon.imageset has no image file')
    for name in names:
        _require_icon(found, root / WATT_ICON / name, 1024, placeholder_sha256, 'WattAppIcon ' + name)

    try:
        with (root / INFO_PLIST).open('rb') as handle:
            info = plistlib.load(handle)
    except (OSError, plistlib.InvalidFileException) as error:
        found.append('Resources/App/Info.plist is unreadable: ' + str(error))
        info = {}
    require(info.get('CFBundleIconName') == ICON_NAME, 'CFBundleIconName must be AppIcon in Resources/App/Info.plist')

    try:
        project = (root / PROJECT).read_text()
    except OSError as error:
        found.append('Watt.xcodeproj/project.pbxproj is unreadable: ' + str(error))
        project = ''
    require(
        project.count(ICON_SETTING) == 3,
        'ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon must be set on the Watt Debug, Release and HelperSigned configurations',
    )
    return found


def _require_icon(found: list[str], path: Path, pixels: int, placeholder_sha256: str, label: str) -> None:
    try:
        data = path.read_bytes()
    except OSError as error:
        found.append(label + ' is missing: ' + str(error))
        return
    digest = hashlib.sha256(data).hexdigest()
    if digest == placeholder_sha256:
        found.append(label + ' matches the placeholder icon')
        return
    try:
        width, height, rgba = _decode_png(data)
    except ValueError as error:
        found.append(label + ' is not a usable PNG: ' + str(error))
        return
    if width != pixels or height != pixels:
        found.append(label + ' is ' + str(width) + '×' + str(height) + ', expected ' + str(pixels) + '×' + str(pixels))
        return
    if not _has_mark(rgba):
        found.append(label + ' has no dark body and green reading dot')


def _has_mark(rgba: bytes) -> bool:
    """True when the icon still has the dark squircle and the green dot."""
    dark = green = False
    for offset in range(0, len(rgba), 4):
        red, green_channel, blue, alpha = rgba[offset:offset + 4]
        if alpha < 200:
            continue
        if red < 80 and green_channel < 80 and blue < 90:
            dark = True
        if green_channel >= 100 and green_channel >= red + 30 and green_channel >= blue + 15:
            green = True
        if dark and green:
            return True
    return False


def _paeth(left: int, up: int, upper_left: int) -> int:
    estimate = left + up - upper_left
    left_distance = abs(estimate - left)
    up_distance = abs(estimate - up)
    upper_left_distance = abs(estimate - upper_left)
    if left_distance <= up_distance and left_distance <= upper_left_distance:
        return left
    if up_distance <= upper_left_distance:
        return up
    return upper_left


def _decode_png(data: bytes) -> tuple[int, int, bytes]:
    """Decode a non-interlaced 8-bit RGBA PNG. Returns width, height, and pixels."""
    signature = b'\x89PNG\r\n\x1a\n'
    if not data.startswith(signature):
        raise ValueError('missing PNG signature')
    position = len(signature)
    width = height = None
    compressed = bytearray()
    while position + 8 <= len(data):
        length = struct.unpack('>I', data[position:position + 4])[0]
        kind = data[position + 4:position + 8]
        start = position + 8
        end = start + length
        if end + 4 > len(data):
            raise ValueError('truncated chunk')
        chunk = data[start:end]
        position = end + 4
        if kind == b'IHDR':
            width, height, bit_depth, color_type, _compression, _filter, interlace = struct.unpack('>IIBBBBB', chunk)
            if bit_depth != 8 or color_type != 6 or interlace != 0:
                raise ValueError('expected 8-bit non-interlaced RGBA')
        elif kind == b'IDAT':
            compressed.extend(chunk)
        elif kind == b'IEND':
            break
    if width is None or height is None or not compressed:
        raise ValueError('PNG is missing IHDR or IDAT')
    try:
        raw = zlib.decompress(bytes(compressed))
    except zlib.error as error:
        raise ValueError('PNG pixels did not inflate') from error
    channels = 4
    stride = width * channels
    expected = height * (stride + 1)
    if len(raw) != expected:
        raise ValueError('PNG pixel buffer has the wrong length')
    rows = bytearray()
    previous = bytearray(stride)
    cursor = 0
    for _row in range(height):
        filter_type = raw[cursor]
        cursor += 1
        row = bytearray(raw[cursor:cursor + stride])
        cursor += stride
        if filter_type == 0:
            pass
        elif filter_type == 1:
            for index in range(stride):
                left = row[index - channels] if index >= channels else 0
                row[index] = (row[index] + left) & 255
        elif filter_type == 2:
            for index in range(stride):
                row[index] = (row[index] + previous[index]) & 255
        elif filter_type == 3:
            for index in range(stride):
                left = row[index - channels] if index >= channels else 0
                row[index] = (row[index] + ((left + previous[index]) // 2)) & 255
        elif filter_type == 4:
            for index in range(stride):
                left = row[index - channels] if index >= channels else 0
                upper_left = previous[index - channels] if index >= channels else 0
                row[index] = (row[index] + _paeth(left, previous[index], upper_left)) & 255
        else:
            raise ValueError('unsupported PNG filter')
        previous = row
        rows.extend(row)
    return width, height, bytes(rows)


def main() -> None:
    root = Path(__file__).resolve().parents[1]
    reasons = failures(root)
    if reasons:
        print('BLOCKED: app icon is missing or still the placeholder.', file=sys.stderr)
        for reason in reasons:
            print('BLOCKED: ' + reason, file=sys.stderr)
        sys.exit(1)
    print('PASS: AppIcon has every macOS size and does not match the placeholder')


if __name__ == '__main__':
    main()
