#!/usr/bin/env python3
"""Render Casks/watt.rb for ben-ranford/homebrew-tap.

The cask installs the GitHub Release zip. A postflight_steps block removes the
quarantine attribute with xattr. Homebrew rejects --no-quarantine and the
legacy postflight Ruby block, so the cask uses neither. The macOS requirement
is a symbol (`depends_on macos: :ventura`), which already means that release
or newer. Direct zip and disk-image downloads still need the Finder Open step;
that text stays in the README, not in the cask caveats.
"""

from __future__ import annotations

import argparse
import hashlib
import plistlib
import sys
import zipfile
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import release_lib


# Homebrew cask symbols for the major macOS version this app can require.
# An unknown major fails the render rather than emitting a symbol we invented.
MACOS_CASK_SYMBOL = {
    13: 'ventura',
    14: 'sonoma',
    15: 'sequoia',
    26: 'tahoe',
}

CAVEATS = """\
Watt is ad-hoc signed and is not notarised.
This cask removes the quarantine attribute so Gatekeeper does not block the first launch.
"""


def macos_dependency(minimum_system_version: str) -> str:
    release_lib.validate_minimum(minimum_system_version)
    major = int(minimum_system_version.split('.', 1)[0])
    symbol = MACOS_CASK_SYMBOL.get(major)
    if symbol is None:
        raise release_lib.ReleaseError(
            'no Homebrew macOS symbol for minimum system version ' + minimum_system_version
        )
    return ':' + symbol


def zap_lines(bundle_id: str) -> list[str]:
    identity = release_lib.validate_identity(bundle_id)
    helper = identity + '.helper'
    return [
        '"/Library/Application Support/Watt"',
        '"/Library/Application Support/Watt-maintenance-result.json"',
        '"/Library/LaunchDaemons/' + helper + '.plist"',
        '"/Library/PrivilegedHelperTools/' + helper + '"',
        '"~/Library/Application Support/Watt"',
        '"~/Library/Preferences/' + identity + '.plist"',
    ]


def render_cask(*, version: str, sha256: str, bundle_id: str, minimum_system_version: str) -> str:
    release_lib.parse_version(version)
    if len(sha256) != 64 or any(char not in '0123456789abcdef' for char in sha256):
        raise release_lib.ReleaseError('sha256 must be 64 lowercase hex characters')
    dependency = macos_dependency(minimum_system_version)
    trash = ',\n        '.join(zap_lines(bundle_id))
    helper = release_lib.validate_identity(bundle_id) + '.helper'
    caveats = '\n'.join('    ' + line if line else '' for line in CAVEATS.splitlines())
    # {{appdir}} is a Homebrew install-step token, not Ruby interpolation.
    # An f-string needs four braces to emit one pair.
    return f"""cask "watt" do
  version "{version}"
  sha256 "{sha256}"

  url "https://github.com/ben-ranford/watt/releases/download/v#{{version}}/Watt-#{{version}}.zip"
  name "Watt?"
  desc "Menu bar power draw monitor"
  homepage "https://github.com/ben-ranford/watt"

  auto_updates true
  depends_on macos: {dependency}

  app "Watt.app"

  postflight_steps do
    run "/usr/bin/xattr", args: ["-dr", "com.apple.quarantine", "{{{{appdir}}}}/Watt.app"]
  end

  zap launchctl: "{helper}",
      trash:     [
        {trash},
      ]

  caveats <<~EOS
{caveats}
  EOS
end
"""


def zip_app_info(path: Path) -> dict[str, str | int]:
    with zipfile.ZipFile(path) as archive:
        names = [name for name in archive.namelist() if name.endswith('Watt.app/Contents/Info.plist')]
        if len(names) != 1:
            raise release_lib.ReleaseError('release zip must contain one Watt.app Info.plist')
        info = plistlib.loads(archive.read(names[0]))
    identity = release_lib.validate_identity(str(info.get('CFBundleIdentifier', '')))
    marketing = str(info.get('CFBundleShortVersionString', ''))
    release_lib.parse_version(marketing)
    minimum = release_lib.validate_minimum(str(info.get('LSMinimumSystemVersion', '')))
    return {'identity': identity, 'marketing': marketing, 'minimum': minimum}


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open('rb') as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b''):
            digest.update(chunk)
    return digest.hexdigest()


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--zip', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--expect-version', required=True)
    args = parser.parse_args()
    try:
        info = zip_app_info(args.zip)
        if info['marketing'] != args.expect_version:
            raise release_lib.ReleaseError('zip marketing version does not match the release tag')
        text = render_cask(
            version=str(info['marketing']),
            sha256=sha256_file(args.zip),
            bundle_id=str(info['identity']),
            minimum_system_version=str(info['minimum']),
        )
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(text)
    except (release_lib.ReleaseError, OSError, zipfile.BadZipFile, plistlib.InvalidFileException) as error:
        print('BLOCKED: ' + str(error), file=sys.stderr)
        sys.exit(1)


if __name__ == '__main__':
    main()
