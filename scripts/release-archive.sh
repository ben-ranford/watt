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
KEYCHAIN=
mkdir -p "$workdir" "$SECRET_DIR" "$output"
chmod 700 "$SECRET_DIR"
umask 077

cleanup() {
  if [[ -n "$KEYCHAIN" ]]; then
    security delete-keychain "$KEYCHAIN" >/dev/null 2>&1 || true
  fi
  rm -rf "$SECRET_DIR"
}
trap cleanup EXIT

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
notarize=$(plan_field notarize)
signing_key_present=$(plan_field signing_key_present)
embed_update=$(plan_field embed_update)
manifest_url=$(plan_field manifest_url)
artifact_url=$(plan_field artifact_url)
team_id=$(plan_field team_id)
case "$code_signing" in
  ad-hoc|developer-id) ;;
  *) echo "Unexpected signing mode." >&2; exit 1 ;;
esac
for flag in "$notarize" "$signing_key_present" "$embed_update"; do
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

if [[ -d /Applications/Xcode.app/Contents/Developer ]]; then
  export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
fi
xcodebuild -version

echo "Checking resolved Xcode settings before archive."
xcodebuild -project Watt.xcodeproj -scheme Watt -configuration Release \
  -destination 'generic/platform=macOS' -showBuildSettings > "$workdir/settings.txt"
python3 scripts/check_xcode_settings.py "$workdir/settings.txt" --marketing "$version" --build "$identity_build"

settings=(
  "MARKETING_VERSION=$version"
  "CURRENT_PROJECT_VERSION=$identity_build"
)
if [[ "$code_signing" == developer-id ]]; then
  echo "Importing Developer ID certificate into a temporary keychain."
  KEYCHAIN=$workdir/watt-release.keychain-db
  keychain_password=$(openssl rand -base64 32)
  python3 scripts/decode_secret.py APPLE_CERTIFICATE_P12_BASE64 "$SECRET_DIR/certificate.p12"
  security create-keychain -p "$keychain_password" "$KEYCHAIN"
  security set-keychain-settings -lut 21600 "$KEYCHAIN"
  security unlock-keychain -p "$keychain_password" "$KEYCHAIN"
  security list-keychains -d user -s "$KEYCHAIN"
  security default-keychain -s "$KEYCHAIN"
  security import "$SECRET_DIR/certificate.p12" -k "$KEYCHAIN" -P "$APPLE_CERTIFICATE_PASSWORD" \
    -T /usr/bin/codesign -T /usr/bin/security -f pkcs12
  security set-key-partition-list -S apple-tool:,apple:,codesign: -s -k "$keychain_password" "$KEYCHAIN" >/dev/null
  settings+=(
    "DEVELOPMENT_TEAM=$team_id"
    CODE_SIGN_STYLE=Manual
    "CODE_SIGN_IDENTITY=Developer ID Application"
    CODE_SIGNING_REQUIRED=YES
    CODE_SIGNING_ALLOWED=YES
    ENABLE_HARDENED_RUNTIME=YES
    OTHER_CODE_SIGN_FLAGS=--timestamp
  )
else
  settings+=(
    CODE_SIGN_STYLE=Manual
    CODE_SIGN_IDENTITY=-
    CODE_SIGNING_REQUIRED=NO
  )
fi

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
    "INFOPLIST_KEY_WATTUpdatePublicKey=$public_key"
  )
fi

echo "Archiving Watt."
xcodebuild archive \
  -project Watt.xcodeproj \
  -scheme Watt \
  -configuration Release \
  -destination 'generic/platform=macOS' \
  -archivePath "$workdir/Watt.xcarchive" \
  "${settings[@]}"

if [[ "$code_signing" == developer-id ]]; then
  python3 scripts/write_export_options.py developer-id "$workdir/export.plist" --team-id "$team_id"
else
  python3 scripts/write_export_options.py ad-hoc "$workdir/export.plist"
fi

exported=$workdir/export/Watt.app
archived=$workdir/Watt.xcarchive/Products/Applications/Watt.app
app=$output/Watt.app
rm -rf "$app"
if xcodebuild -exportArchive \
  -archivePath "$workdir/Watt.xcarchive" \
  -exportPath "$workdir/export" \
  -exportOptionsPlist "$workdir/export.plist" \
  && /usr/bin/codesign --verify --deep --strict "$exported"
then
  ditto "$exported" "$app"
elif [[ "$code_signing" == developer-id ]]; then
  echo "xcodebuild -exportArchive did not produce a verifiable Developer ID app." >&2
  exit 1
else
  echo "xcodebuild -exportArchive did not produce a verifiable ad-hoc app. Packaging the archived Watt.app instead."
  ditto "$archived" "$app"
fi
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

if [[ "$notarize" == true ]]; then
  echo "Submitting the app for notarization."
  python3 scripts/decode_secret.py APPLE_NOTARY_KEY_P8_BASE64 "$SECRET_DIR/AuthKey.p8"
  submission=$workdir/Watt-notarize.zip
  ditto -c -k --keepParent "$app" "$submission"
  xcrun notarytool submit "$submission" \
    --key "$SECRET_DIR/AuthKey.p8" \
    --key-id "$APPLE_NOTARY_KEY_ID" \
    --issuer "$APPLE_NOTARY_ISSUER_ID" \
    --wait
  rm -f "$submission"
  xcrun stapler staple "$app"
  /usr/bin/codesign --verify --deep --strict --all-architectures "$app"
fi

archive=$output/Watt-$version.tar
rm -f "$archive"
scripts/verify-release-readiness.sh local "$app" --archive "$archive"
shasum -a 256 "$archive" > "$output/Watt-$version.tar.sha256"
ditto -c -k --keepParent "$app" "$output/Watt-$version.zip"
hdiutil create -volname Watt -srcfolder "$app" -ov -format UDZO "$output/Watt-$version.dmg"

if [[ "$notarize" == true ]]; then
  echo "Submitting the disk image for notarization."
  xcrun notarytool submit "$output/Watt-$version.dmg" \
    --key "$SECRET_DIR/AuthKey.p8" \
    --key-id "$APPLE_NOTARY_KEY_ID" \
    --issuer "$APPLE_NOTARY_ISSUER_ID" \
    --wait
  xcrun stapler staple "$output/Watt-$version.dmg"
fi

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
