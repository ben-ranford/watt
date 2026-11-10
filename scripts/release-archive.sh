#!/bin/bash
# Archive Watt, export or package the app, and optionally sign an update manifest.
set -euo pipefail

root=$(cd "$(dirname "$0")/.." && pwd)
cd "$root"

if [[ "$(uname -s)" != Darwin ]]; then
  echo "Archiving Watt needs macOS and Xcode. This runner cannot build the app." >&2
  exit 1
fi

version=${RELEASE_VERSION:?}
tag=${RELEASE_TAG:?}
output=${OUTPUT_DIR:?}
workdir=${RUNNER_TEMP:-${TMPDIR:-/tmp}}/watt-release-$$
SECRET_DIR=$workdir/secrets
mkdir -p "$workdir" "$SECRET_DIR" "$output"
chmod 700 "$SECRET_DIR"
umask 077
trap 'rm -rf "$SECRET_DIR"' EXIT

python3 scripts/release_plan.py > "$workdir/plan.json"
PLAN=$workdir/plan.json

plan_field() {
  python3 - "$PLAN" "$1" <<'PY'
import json
import sys
value = json.load(open(sys.argv[1]))[sys.argv[2]]
if isinstance(value, bool):
    print("true" if value else "false")
else:
    print(value)
PY
}

if [[ "$tag" != "v$version" ]]; then
  echo "Refusing release tag." >&2
  exit 1
fi

code_signing=$(plan_field code_signing)
signing_key_present=$(plan_field signing_key_present)
embed_update=$(plan_field embed_update)
manifest_url=$(plan_field manifest_url)
artifact_url=$(plan_field artifact_url)
if [[ "$code_signing" != ad-hoc ]]; then
  echo "Releases are ad-hoc signed." >&2
  exit 1
fi
for flag in "$signing_key_present" "$embed_update"; do
  case "$flag" in
    true|false) ;;
    *) echo "Unexpected release plan." >&2; exit 1 ;;
  esac
done

python3 scripts/sync-release-version.py --release
identity_build=$(python3 -c 'import json; print(json.load(open("Resources/ReleaseIdentity.json"))["build"])')
case "$identity_build" in
  ''|*[!0-9]*) echo "Refusing identity build." >&2; exit 1 ;;
esac

# Same preference as .github/workflows/ci.yml. Xcode.app on the xcode-27 image
# is an older symlink than Xcode_27.2.app, so do not pin that path.
selected=""
for app in \
  /Applications/Xcode_27.2.app \
  /Applications/Xcode_27.1.app \
  /Applications/Xcode_27.app \
  /Applications/Xcode.app
do
  if [[ -d "${app}/Contents/Developer" ]]; then
    selected="${app}"
    break
  fi
done
if [[ -n "${selected}" ]]; then
  export DEVELOPER_DIR="${selected}/Contents/Developer"
fi
xcodebuild -version

echo "Checking resolved Xcode settings before archive."
xcodebuild -project Watt.xcodeproj -scheme Watt -configuration Release \
  -destination 'generic/platform=macOS' -showBuildSettings > "$workdir/settings.txt"
python3 scripts/check_xcode_settings.py "$workdir/settings.txt" --marketing "$version" --build "$identity_build"

echo "Archiving with an ad-hoc signature. This release is not Developer ID signed or notarised."
settings=(
  "MARKETING_VERSION=$version"
  "CURRENT_PROJECT_VERSION=$identity_build"
  CODE_SIGN_STYLE=Manual
  CODE_SIGN_IDENTITY=-
  AD_HOC_CODE_SIGNING_ALLOWED=YES
  CODE_SIGNING_ALLOWED=YES
  CODE_SIGNING_REQUIRED=YES
  ENABLE_HARDENED_RUNTIME=YES
  INFOPLIST_KEY_WATTHelperTrustMode=protected-installation
  WATT_HELPER_TRUST_MODE=protected-installation
)

public_key=
if [[ "$signing_key_present" == true ]]; then
  python3 scripts/sign-update-manifest.py --public-key-out "$SECRET_DIR/public-key.txt"
  public_key=$(tr -d '\n' < "$SECRET_DIR/public-key.txt")
  case "$public_key" in
    ''|*[!A-Za-z0-9+/=]*) echo "Refusing derived update public key." >&2; exit 1 ;;
  esac
fi
if [[ "$embed_update" == true ]]; then
  case "$manifest_url$artifact_url" in
    *[[:space:]]*) echo "Refusing update URL." >&2; exit 1 ;;
  esac
  settings+=(
    "INFOPLIST_KEY_WATTUpdateManifestURL=$manifest_url"
    "INFOPLIST_KEY_WATTUpdateArtifactURL=$artifact_url"
  )
fi
if [[ "$signing_key_present" == true ]]; then
  settings+=("INFOPLIST_KEY_WATTUpdatePublicKey=$public_key")
fi

echo "Archiving Watt."
xcodebuild archive \
  -project Watt.xcodeproj \
  -scheme Watt \
  -configuration Release \
  -destination 'generic/platform=macOS' \
  -archivePath "$workdir/Watt.xcarchive" \
  "${settings[@]}"

archived=$workdir/Watt.xcarchive/Products/Applications/Watt.app
app=$output/Watt.app
rm -rf "$app"
ditto "$archived" "$app"
/usr/bin/codesign --verify --deep --strict --all-architectures "$app"

app=$(python3 -c 'import os,sys; print(os.path.realpath(sys.argv[1]))' "$app")
info=$(python3 scripts/read_app_info.py "$app/Contents/Info.plist" --expect-marketing "$version")
identity=$(printf '%s\n' "$info" | sed -n 's/^IDENTITY=//p')
built=$(printf '%s\n' "$info" | sed -n 's/^BUILD=//p')
minimum=$(printf '%s\n' "$info" | sed -n 's/^MINIMUM=//p')
case "$identity" in
  ''|*[!A-Za-z0-9.-]*) echo "Refusing bundle identifier." >&2; exit 1 ;;
esac
case "$built" in
  "$identity_build") ;;
  *) echo "Built CFBundleVersion does not match ReleaseIdentity.json." >&2; exit 1 ;;
esac
case "$minimum" in
  [0-9]*.[0-9]*) ;;
  *) echo "Refusing minimum system version." >&2; exit 1 ;;
esac
case "$minimum" in
  *[!0-9.]*) echo "Refusing minimum system version." >&2; exit 1 ;;
esac

archive=$output/Watt-$version.tar
rm -f "$archive"
scripts/verify-release-readiness.sh local "$app" --archive "$archive"
shasum -a 256 "$archive" > "$output/Watt-$version.tar.sha256"
ditto -c -k --keepParent "$app" "$output/Watt-$version.zip"
hdiutil create -volname Watt -srcfolder "$app" -ov -format UDZO "$output/Watt-$version.dmg"

set +e
scripts/verify-release-readiness.sh distribution-preflight "$app" > "$output/distribution-preflight.txt" 2>&1
preflight=$?
set -e
cat "$output/distribution-preflight.txt"
if [[ "$preflight" -eq 0 && "$signing_key_present" == true ]]; then
  python3 scripts/sign-update-manifest.py \
    --archive "$archive" \
    --identity "$identity" \
    --build "$built" \
    --minimum-system-version "$minimum" \
    --output "$output/Watt-$version-update-manifest.json"
  echo "Signed update manifest from the ustar artifact sha256."
elif [[ "$signing_key_present" == true ]]; then
  echo "WATT_UPDATE_SIGNING_KEY is set, but distribution preflight failed. Not publishing an update manifest."
else
  echo "Signed update manifest skipped because WATT_UPDATE_SIGNING_KEY is absent."
fi

echo "Release products are in $output"
