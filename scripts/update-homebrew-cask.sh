#!/bin/bash
# After a published GitHub Release, write Casks/watt.rb on ben-ranford/homebrew-tap.
# The tap's existing formula bumps are commits on main by github-actions[bot].
# This follows that. It does not open a pull request.
# Push access is a write-access deploy key on homebrew-tap only.
set -euo pipefail

if [[ -z "${HOMEBREW_TAP_DEPLOY_KEY:-}" ]]; then
  echo "HOMEBREW_TAP_DEPLOY_KEY is unset. Skipping the Homebrew tap update."
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
# Fixed SSH URL. A longer insteadOf match keeps a global url.*.insteadOf
# rewrite from turning this remote into HTTPS and skipping the deploy key.
tap_url=git@github.com:ben-ranford/homebrew-tap.git

root=$(cd "$(dirname "$0")/.." && pwd)
work=$(mktemp -d)
key_file=""
cleanup() {
  if [[ -n "${key_file}" ]]; then
    rm -f "${key_file}"
  fi
  rm -rf "${work}"
}
trap cleanup EXIT

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

# GitHub's published ed25519 host key:
# https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/githubs-ssh-key-fingerprints
known_hosts=$work/known_hosts
printf '%s\n' 'github.com ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOMqqnkVzrm0SdG6UOoqKLsabgH5C9okWi0dh2l9GKJl' > "$known_hosts"

# Actions deletes this same path again from an always() step. Do not print the key.
if [[ -n "${RUNNER_TEMP:-}" ]]; then
  key_file="${RUNNER_TEMP}/homebrew-tap-deploy-key"
else
  key_file="${work}/deploy_key"
fi
install -m 0600 /dev/null "$key_file"
printf '%s\n' "$HOMEBREW_TAP_DEPLOY_KEY" > "$key_file"
chmod 0600 "$key_file"
unset HOMEBREW_TAP_DEPLOY_KEY

export GIT_SSH_COMMAND="ssh -i $(printf '%q' "$key_file") -o IdentitiesOnly=yes -o StrictHostKeyChecking=yes -o UserKnownHostsFile=$(printf '%q' "$known_hosts") -o GlobalKnownHostsFile=/dev/null -o HostKeyAlgorithms=ssh-ed25519 -o UpdateHostKeys=no -o BatchMode=yes"

git_safe() {
  git \
    -c protocol.file.allow=never \
    -c protocol.ext.allow=never \
    -c core.hooksPath=/dev/null \
    -c commit.gpgsign=false \
    -c "url.${tap_url}.insteadOf=${tap_url}" \
    "$@"
}

tap=$work/homebrew-tap
git_safe clone --origin origin --branch main --single-branch \
  "$tap_url" "$tap"
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

for attempt in 1 2 3; do
  echo "Push attempt ${attempt} for the Homebrew cask."
  if ! git_safe -C "$tap" fetch origin main; then
    sleep 2
    continue
  fi
  if ! git_safe -C "$tap" rebase origin/main; then
    git_safe -C "$tap" rebase --abort || true
    sleep 2
    continue
  fi
  if git_safe -C "$tap" push origin HEAD:main; then
    echo "Updated ben-ranford/homebrew-tap Casks/watt.rb for ${version}."
    exit 0
  fi
  sleep 2
done
echo "Could not push the Homebrew cask to main." >&2
exit 1
