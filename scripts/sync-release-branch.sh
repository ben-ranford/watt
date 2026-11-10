#!/bin/bash
# Push the encoded CFBundleVersion onto the Release Please branch in RELEASE_PLEASE_BRANCH.
set -euo pipefail

branch="${RELEASE_PLEASE_BRANCH:-}"
pattern='^release-please--branches--main(--components--[A-Za-z0-9._-]+)?$'
if [[ ! "${branch}" =~ ${pattern} ]]; then
  echo "Refusing to sync CFBundleVersion onto an unexpected release branch." >&2
  exit 1
fi

cd "$(dirname "$0")/.."
head="$(git rev-parse --abbrev-ref HEAD)"
if [[ "${head}" != "${branch}" ]]; then
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
git push origin "HEAD:${branch}"
