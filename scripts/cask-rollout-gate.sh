#!/bin/bash
# Decide whether this release may move the Homebrew cask.
# A staged rollout stays off the cask until the signed manifest says every
# install may take it. No manifest means there is nothing to stage, so the
# cask updates as it did before rollout existed.
set -euo pipefail

tag=${RELEASE_TAG:?}
repo=${GITHUB_REPOSITORY:?}
if [[ ! "$tag" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "Refusing release tag." >&2
  exit 1
fi
if [[ ! "$repo" =~ ^[A-Za-z0-9._-]+/[A-Za-z0-9._-]+$ ]]; then
  echo "Refusing repository." >&2
  exit 1
fi
version=${tag#v}
name="Watt-${version}-update-manifest.json"
root=$(cd "$(dirname "$0")/.." && pwd)

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

assets=$(gh release view "$tag" --repo "$repo" --json assets --jq '.assets[].name')
bump=true
if printf '%s\n' "$assets" | grep -Fxq "$name"; then
  gh release download "$tag" --repo "$repo" --pattern "$name" --dir "$work"
  decision=$(python3 - "$work/$name" "$root/scripts" <<'PY'
import json
import sys
import time
from pathlib import Path

sys.path.insert(0, sys.argv[2])
import rollout_manifest

document = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
payload = json.loads(__import__("base64").b64decode(document["payload"]))
print("true" if rollout_manifest.cask_ready(payload, int(time.time())) else "false")
PY
)
  if [[ "$decision" == "true" ]]; then
    bump=true
    echo "Signed rollout is complete or critical. The Homebrew cask can move."
  else
    bump=false
    echo "Staged rollout has not reached every install. Leaving the Homebrew cask on the last complete version."
  fi
else
  echo "No signed update manifest on ${tag}. The Homebrew cask can move."
fi

if [[ -n "${GITHUB_OUTPUT:-}" ]]; then
  echo "bump=${bump}" >> "$GITHUB_OUTPUT"
fi
