#!/bin/bash
# After a published GitHub Release, write Casks/watt.rb on ben-ranford/homebrew-tap.
# The tap's existing formula bumps are commits on main by github-actions[bot].
# This follows that. It does not open a pull request.
set -euo pipefail

if [[ -z "${HOMEBREW_TAP_TOKEN:-}" ]]; then
  echo "HOMEBREW_TAP_TOKEN is unset. Skipping the Homebrew tap update."
  exit 0
fi

tag=${RELEASE_TAG:?}
repo=${SOURCE_REPO:-ben-ranford/homebrew-tap}
source_repo=${GITHUB_REPOSITORY:?}
if [[ ! "$tag" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "Refusing release tag." >&2
  exit 1
fi
if [[ "$repo" != ben-ranford/homebrew-tap ]]; then
  echo "Refusing Homebrew tap repository." >&2
  exit 1
fi
version=${tag#v}

root=$(cd "$(dirname "$0")/.." && pwd)
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

export GH_TOKEN="${GITHUB_TOKEN:?}"
draft=$(gh release view "$tag" --repo "$source_repo" --json isDraft --jq .isDraft)
if [[ "$draft" != false ]]; then
  echo "Refusing to update the tap from a draft release." >&2
  exit 1
fi
gh release download "$tag" --repo "$source_repo" --pattern "Watt-${version}.zip" --dir "$work"
zip=$work/Watt-${version}.zip
if [[ ! -f "$zip" ]]; then
  echo "Published release is missing the zip." >&2
  exit 1
fi

git_safe() {
  git \
    -c protocol.file.allow=never \
    -c protocol.ext.allow=never \
    -c core.hooksPath=/dev/null \
    -c commit.gpgsign=false \
    "$@"
}

tap=$work/homebrew-tap
git_safe clone --origin origin --branch main --single-branch \
  https://github.com/ben-ranford/homebrew-tap.git "$tap"
mkdir -p "$tap/Casks"
python3 "$root/scripts/render_homebrew_cask.py" \
  --zip "$zip" \
  --expect-version "$version" \
  --output "$tap/Casks/watt.rb"

git_safe -C "$tap" config user.name "github-actions[bot]"
git_safe -C "$tap" config user.email "41898282+github-actions[bot]@users.noreply.github.com"
git_safe -C "$tap" add Casks/watt.rb
if git_safe -C "$tap" diff --cached --quiet; then
  echo "Homebrew cask already matches ${version}."
  exit 0
fi
git_safe -C "$tap" commit --no-verify -m "watt ${version}"

auth_header=$(printf 'x-access-token:%s' "$HOMEBREW_TAP_TOKEN" | base64 | tr -d '\n')
unset HOMEBREW_TAP_TOKEN
git_network() {
  git_safe -c "http.extraheader=AUTHORIZATION: basic ${auth_header}" "$@"
}

for attempt in 1 2 3; do
  echo "Push attempt ${attempt} for the Homebrew cask."
  if ! git_network -C "$tap" fetch origin main; then
    sleep 2
    continue
  fi
  if ! git_safe -C "$tap" rebase origin/main; then
    git_safe -C "$tap" rebase --abort || true
    sleep 2
    continue
  fi
  if git_network -C "$tap" push origin HEAD:main; then
    echo "Updated ben-ranford/homebrew-tap Casks/watt.rb for ${version}."
    exit 0
  fi
  sleep 2
done
echo "Could not push the Homebrew cask to main." >&2
exit 1
