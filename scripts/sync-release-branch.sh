#!/bin/bash
# Push the encoded CFBundleVersion onto the open Release Please branch.
set -euo pipefail

cd "$(dirname "$0")/.."
branch=$(git rev-parse --abbrev-ref HEAD)
if [[ "$branch" != "release-please--branches--main" ]]; then
  echo "Refusing to sync CFBundleVersion from this checkout." >&2
  exit 1
fi

python3 scripts/sync-release-version.py --write
git add -- \
  Resources/ReleaseIdentity.json \
  Resources/Helper/Info.plist \
  HelperShared/HelperXPC.swift \
  Watt.xcodeproj/project.pbxproj
if git diff --cached --quiet; then
  echo "CFBundleVersion already matches the release marketing version."
  exit 0
fi

git -c user.name='github-actions[bot]' -c user.email='41898282+github-actions[bot]@users.noreply.github.com' \
  commit -m "chore: sync CFBundleVersion to the release marketing version"
git push origin HEAD:release-please--branches--main
