#!/bin/bash
# Developer ID keychain, inside-out signing, notarisation, and cleanup.
#
# Tracing is off for the whole script. The p12, its password, the .p8, and the
# decoded files are never echoed, cat, or printed. Derived secrets (the
# temporary keychain password) are registered with ::add-mask::.
# Material lives only under $RUNNER_TEMP/watt-developer-id and is removed by
# `cleanup`, which CI runs with if: always().
set -euo pipefail
set +x
umask 077

secret_dir="${RUNNER_TEMP:?}/watt-developer-id"
keychain="${secret_dir}/signing.keychain-db"
identity_file="${secret_dir}/identity"
ready_file="${secret_dir}/ready"
password_file="${secret_dir}/keychain-password"
p12_file="${secret_dir}/developer-id.p12"
p8_file="${secret_dir}/AuthKey.p8"
# Public team id of the Developer ID Application certificate. Not a secret.
readonly WATT_DEVELOPER_ID_TEAM="GUT4TJFVQ2"

mask() {
  local value="${1:-}"
  if [[ -n "${value}" ]]; then
    printf '%s\n' "::add-mask::${value}"
  fi
}

cleanup() {
  set +x
  if [[ -f "${keychain}" ]] && command -v security >/dev/null 2>&1; then
    security delete-keychain "${keychain}" >/dev/null 2>&1 || true
  fi
  rm -rf "${secret_dir}"
}

refuse_untrusted() {
  if [[ "${GITHUB_EVENT_NAME:-}" == "pull_request_target" ]]; then
    echo "BLOCKED: pull_request_target cannot use signing secrets." >&2
    exit 1
  fi
  local trusted=false
  case "${GITHUB_EVENT_NAME:-}:${GITHUB_REF:-}" in
    push:refs/heads/main) trusted=true ;;
    push:refs/tags/*) trusted=true ;;
  esac
  if [[ "${GITHUB_EVENT_NAME:-}" == "pull_request" && -n "${GITHUB_REPOSITORY:-}" && "${GITHUB_HEAD_REPO:-}" == "${GITHUB_REPOSITORY}" ]]; then
    trusted=true
  fi
  if [[ "${trusted}" != true ]]; then
    echo "BLOCKED: Developer ID secrets are only used on push to main, tags, and same-repo pull requests." >&2
    exit 1
  fi
}

require_names() {
  local missing=()
  local name
  for name in "$@"; do
    if [[ -z "${!name:-}" ]]; then
      missing+=("${name}")
    fi
  done
  if [[ ${#missing[@]} -gt 0 ]]; then
    echo "BLOCKED: Developer ID secrets are missing: ${missing[*]}" >&2
    exit 1
  fi
}

unlock_keychain() {
  if [[ ! -f "${keychain}" || ! -f "${password_file}" ]]; then
    echo "BLOCKED: Developer ID keychain is not imported." >&2
    exit 1
  fi
  WATT_KEYCHAIN_PATH="${keychain}" WATT_KEYCHAIN_PASSWORD_FILE="${password_file}" python3 - <<'PY'
import os
import subprocess
import sys

password = open(os.environ["WATT_KEYCHAIN_PASSWORD_FILE"], encoding="utf-8").read().strip()
if not password:
    sys.stderr.write("BLOCKED: signing keychain password is empty\n")
    sys.exit(1)
# Register the derived password with the log masker without printing it again.
sys.stdout.write("::add-mask::" + password + "\n")
keychain = os.environ["WATT_KEYCHAIN_PATH"]
unlocked = subprocess.run(
    ["security", "unlock-keychain", "-p", password, keychain],
    capture_output=True,
)
if unlocked.returncode != 0:
    sys.stderr.write("BLOCKED: could not unlock the signing keychain\n")
    sys.exit(1)
PY
}

import_identity() {
  refuse_untrusted
  require_names \
    DEVELOPER_ID_P12_BASE64 \
    DEVELOPER_ID_P12_PASSWORD \
    APPLE_TEAM_ID \
    ASC_KEY_ID \
    ASC_ISSUER_ID \
    ASC_KEY_P8_BASE64
  if [[ "${APPLE_TEAM_ID}" != "${WATT_DEVELOPER_ID_TEAM}" ]]; then
    echo "BLOCKED: APPLE_TEAM_ID is not the Watt Developer ID team." >&2
    exit 1
  fi
  mask "${DEVELOPER_ID_P12_PASSWORD}"
  mask "${ASC_KEY_ID}"
  mask "${ASC_ISSUER_ID}"
  mkdir -p "${secret_dir}"
  chmod 700 "${secret_dir}"
  python3 - "${secret_dir}" <<'PY'
import base64
import os
import pathlib
import sys

root = pathlib.Path(sys.argv[1])

def write(env_name, filename):
    raw = os.environ.get(env_name, "")
    try:
        data = base64.b64decode(raw, validate=True)
    except Exception:
        sys.stderr.write("BLOCKED: " + env_name + " is not valid base64\n")
        sys.exit(1)
    if not data:
        sys.stderr.write("BLOCKED: " + env_name + " decoded empty\n")
        sys.exit(1)
    path = root / filename
    path.write_bytes(data)
    path.chmod(0o600)

write("DEVELOPER_ID_P12_BASE64", "developer-id.p12")
write("ASC_KEY_P8_BASE64", "AuthKey.p8")
PY
  local keychain_password
  keychain_password="$(openssl rand -base64 32)"
  mask "${keychain_password}"
  WATT_SECRET_DIR="${secret_dir}" WATT_KEYCHAIN_PASSWORD="${keychain_password}" python3 - <<'PY'
import os
import pathlib

path = pathlib.Path(os.environ["WATT_SECRET_DIR"]) / "keychain-password"
path.write_text(os.environ["WATT_KEYCHAIN_PASSWORD"])
path.chmod(0o600)
PY
  if ! security create-keychain -p "${keychain_password}" "${keychain}" >/dev/null 2>"${secret_dir}/security.err"; then
    echo "BLOCKED: could not create the signing keychain." >&2
    rm -f "${secret_dir}/security.err"
    exit 1
  fi
  security set-keychain-settings -lut 21600 "${keychain}" >/dev/null
  if ! security unlock-keychain -p "${keychain_password}" "${keychain}" >/dev/null 2>"${secret_dir}/security.err"; then
    echo "BLOCKED: could not unlock the signing keychain." >&2
    rm -f "${secret_dir}/security.err"
    exit 1
  fi
  if ! security import "${p12_file}" \
    -k "${keychain}" \
    -P "${DEVELOPER_ID_P12_PASSWORD}" \
    -f pkcs12 \
    -T /usr/bin/codesign \
    -T /usr/bin/security \
    >/dev/null 2>"${secret_dir}/security.err"
  then
    echo "BLOCKED: security import failed." >&2
    rm -f "${secret_dir}/security.err"
    exit 1
  fi
  if ! security set-key-partition-list -S apple-tool:,apple:,codesign: -s -k "${keychain_password}" "${keychain}" >/dev/null 2>"${secret_dir}/security.err"; then
    echo "BLOCKED: could not allow codesign to use the signing key." >&2
    rm -f "${secret_dir}/security.err"
    exit 1
  fi
  rm -f "${secret_dir}/security.err"
  unset keychain_password
  local previous=""
  previous="$(security list-keychains -d user | sed -e 's/^ *//' -e 's/"//g' | tr '\n' ' ')"
  # shellcheck disable=SC2086
  # Search list only. Leave the login keychain as the default so ad-hoc test
  # builds in the same job do not start looking up the temporary keychain.
  security list-keychains -d user -s "${keychain}" ${previous} >/dev/null
  WATT_KEYCHAIN_PATH="${keychain}" WATT_IDENTITY_FILE="${identity_file}" WATT_DEVELOPER_ID_TEAM="${WATT_DEVELOPER_ID_TEAM}" python3 - <<'PY'
import os
import subprocess
import sys

keychain = os.environ["WATT_KEYCHAIN_PATH"]
team = os.environ["WATT_DEVELOPER_ID_TEAM"]
found = subprocess.run(
    ["security", "find-identity", "-v", "-p", "codesigning", keychain],
    capture_output=True,
    text=True,
)
if found.returncode != 0:
    sys.stderr.write("BLOCKED: could not list codesigning identities\n")
    sys.exit(1)
identities = []
for line in found.stdout.splitlines():
    if "Developer ID Application:" not in line or '"' not in line:
        continue
    identities.append(line.split('"', 2)[1])
if len(identities) != 1:
    sys.stderr.write("BLOCKED: expected one Developer ID Application identity\n")
    sys.exit(1)
identity = identities[0]
if "(%s)" % team not in identity:
    sys.stderr.write("BLOCKED: Developer ID identity team does not match APPLE_TEAM_ID\n")
    sys.exit(1)
cert = subprocess.run(
    ["security", "find-certificate", "-c", identity, "-p", keychain],
    capture_output=True,
    text=True,
)
if cert.returncode != 0 or "BEGIN CERTIFICATE" not in cert.stdout:
    sys.stderr.write("BLOCKED: could not read the Developer ID certificate\n")
    sys.exit(1)
subject = subprocess.run(
    ["openssl", "x509", "-noout", "-subject", "-nameopt", "RFC2253"],
    input=cert.stdout,
    capture_output=True,
    text=True,
)
if subject.returncode != 0 or ("OU=%s" % team) not in subject.stdout:
    sys.stderr.write("BLOCKED: certificate subject does not match APPLE_TEAM_ID\n")
    sys.exit(1)
path = os.environ["WATT_IDENTITY_FILE"]
with open(path, "w", encoding="utf-8") as handle:
    handle.write(identity + "\n")
os.chmod(path, 0o600)
PY
  : > "${ready_file}"
  chmod 600 "${ready_file}" "${identity_file}" "${password_file}" "${p12_file}" "${p8_file}"
  echo "Imported one Developer ID Application identity into a temporary keychain."
}

xcode_settings() {
  if [[ ! -f "${ready_file}" || ! -f "${identity_file}" ]]; then
    printf '%s\n' \
      'CODE_SIGN_STYLE=Manual' \
      'CODE_SIGN_IDENTITY=-' \
      'AD_HOC_CODE_SIGNING_ALLOWED=YES' \
      'CODE_SIGNING_ALLOWED=YES' \
      'CODE_SIGNING_REQUIRED=YES'
    return 0
  fi
  local identity
  identity="$(tr -d '\n' < "${identity_file}")"
  printf '%s\n' \
    'CODE_SIGN_STYLE=Manual' \
    "CODE_SIGN_IDENTITY=${identity}" \
    "DEVELOPMENT_TEAM=${WATT_DEVELOPER_ID_TEAM}" \
    'AD_HOC_CODE_SIGNING_ALLOWED=NO' \
    'CODE_SIGNING_ALLOWED=YES' \
    'CODE_SIGNING_REQUIRED=YES' \
    'ENABLE_HARDENED_RUNTIME=YES' \
    'ENABLE_TESTABILITY=NO' \
    'CODE_SIGN_INJECT_BASE_ENTITLEMENTS=NO' \
    'OTHER_CODE_SIGN_FLAGS=--timestamp'
}

sign_with_entitlements() {
  local identity="$1"
  local target="$2"
  local entitlements="$3"
  /usr/bin/codesign --force --sign "${identity}" \
    --options runtime \
    --timestamp \
    --entitlements "${entitlements}" \
    "${target}"
}

sign_nested() {
  local identity="$1"
  local target="$2"
  local fallback="$3"
  local extracted="${secret_dir}/entitlements.plist"
  rm -f "${extracted}"
  if /usr/bin/codesign -d --entitlements :- "${target}" > "${extracted}" 2>/dev/null \
    && [[ -s "${extracted}" ]] \
    && ! grep -q 'com.apple.security.get-task-allow' "${extracted}" \
    && ! grep -q 'com.apple.security.cs.disable-library-validation' "${extracted}"
  then
    sign_with_entitlements "${identity}" "${target}" "${extracted}"
  elif [[ -s "${extracted}" ]]; then
    sign_with_entitlements "${identity}" "${target}" "${fallback}"
  else
    /usr/bin/codesign --force --sign "${identity}" --options runtime --timestamp "${target}"
  fi
  rm -f "${extracted}"
}

sign_app() {
  local app="$1"
  local root entitlements identity item tool
  root="$(cd "$(dirname "$0")/.." && pwd)"
  entitlements="${root}/Resources/Entitlements/HardenedRuntime.entitlements"
  unlock_keychain
  identity="$(tr -d '\n' < "${identity_file}")"
  if [[ ! -d "${app}" ]]; then
    echo "BLOCKED: app bundle is missing." >&2
    exit 1
  fi
  # Deepest nested bundle or library first. The outer app is signed last.
  # Signing does not use a deep flag. That flag re-signs nested code with the
  # parent's entitlements and can break a helper that has its own signature.
  while IFS= read -r item; do
    [[ -n "${item}" && "${item}" != "${app}" ]] || continue
    sign_nested "${identity}" "${item}" "${entitlements}"
  done < <(find "${app}" -depth \( -name '*.app' -o -name '*.xpc' -o -name '*.appex' -o -name '*.framework' -o -name '*.plugin' -o -name '*.dylib' \) -print)
  for tool in WattHelper WattMaintenance WattHelperInstaller; do
    if [[ -f "${app}/Contents/MacOS/${tool}" ]]; then
      sign_with_entitlements "${identity}" "${app}/Contents/MacOS/${tool}" "${entitlements}"
    fi
  done
  sign_with_entitlements "${identity}" "${app}" "${entitlements}"
  echo "Signed nested code inside-out with Developer ID Application."
}

notarize_payload() {
  local payload="$1"
  local staple_target="$2"
  refuse_untrusted
  require_names ASC_KEY_ID ASC_ISSUER_ID
  mask "${ASC_KEY_ID}"
  mask "${ASC_ISSUER_ID}"
  if [[ ! -f "${p8_file}" ]]; then
    echo "BLOCKED: App Store Connect API key file is missing." >&2
    exit 1
  fi
  local result="${secret_dir}/notary-result.json"
  local log="${secret_dir}/notary-log.json"
  local submission_id=""
  set +e
  xcrun notarytool submit "${payload}" \
    --key "${p8_file}" \
    --key-id "${ASC_KEY_ID}" \
    --issuer "${ASC_ISSUER_ID}" \
    --wait \
    --output-format json \
    > "${result}"
  local submit_status=$?
  set -e
  set +e
  WATT_NOTARY_RESULT="${result}" WATT_NOTARY_STATUS="${submit_status}" python3 - <<'PY'
import json
import os
import sys

path = os.environ["WATT_NOTARY_RESULT"]
code = int(os.environ["WATT_NOTARY_STATUS"])
try:
    data = json.load(open(path, encoding="utf-8"))
except (OSError, ValueError):
    data = {}
submission = str(data.get("id") or "")
state = str(data.get("status") or "")
sys.stdout.write("notarytool status=%s\n" % (state or "unknown"))
if submission:
    with open(path + ".id", "w", encoding="utf-8") as handle:
        handle.write(submission)
if code != 0 or state != "Accepted":
    sys.exit(1)
PY
  local parsed=$?
  set -e
  if [[ "${parsed}" -ne 0 ]]; then
    if [[ -f "${result}.id" ]]; then
      submission_id="$(tr -d '\n' < "${result}.id")"
    fi
    if [[ -n "${submission_id}" ]]; then
      set +e
      xcrun notarytool log "${submission_id}" \
        --key "${p8_file}" \
        --key-id "${ASC_KEY_ID}" \
        --issuer "${ASC_ISSUER_ID}" \
        "${log}"
      set -e
      if [[ -f "${log}" ]]; then
        echo "notarytool log:"
        cat "${log}"
      else
        echo "BLOCKED: notarytool log was not written." >&2
      fi
    else
      echo "BLOCKED: notarytool did not return a submission id." >&2
    fi
    exit 1
  fi
  xcrun stapler staple "${staple_target}"
  xcrun stapler validate "${staple_target}"
  echo "Stapled notarisation ticket."
}

notarize_app() {
  local app="$1"
  local zip="${secret_dir}/notary-app.zip"
  rm -f "${zip}"
  ditto -c -k --keepParent "${app}" "${zip}"
  notarize_payload "${zip}" "${app}"
  rm -f "${zip}"
}

notarize_dmg() {
  local dmg="$1"
  local identity
  unlock_keychain
  identity="$(tr -d '\n' < "${identity_file}")"
  /usr/bin/codesign --force --sign "${identity}" --timestamp "${dmg}"
  notarize_payload "${dmg}" "${dmg}"
}

verify_app() {
  local app="$1"
  local require_ticket="${2:-}"
  local tool
  for tool in Watt WattHelper WattMaintenance WattHelperInstaller; do
    /usr/bin/codesign --verify --strict --all-architectures --verbose=2 "${app}/Contents/MacOS/${tool}"
  done
  /usr/bin/codesign --verify --deep --strict --all-architectures --verbose=2 "${app}"
  /usr/bin/codesign --display --verbose=4 "${app}"
  if [[ "${require_ticket}" == "--require-ticket" ]]; then
    xcrun stapler validate "${app}"
    /usr/sbin/spctl -a -vvv -t exec "${app}"
    echo "PASS: Developer ID signature, hardened runtime, and notarisation ticket."
  fi
}

command="${1:-}"
case "${command}" in
  import) import_identity ;;
  unlock) unlock_keychain ;;
  cleanup) cleanup ;;
  xcode-settings) xcode_settings ;;
  sign-app) sign_app "${2:?}" ;;
  notarize-app) notarize_app "${2:?}" ;;
  notarize-dmg) notarize_dmg "${2:?}" ;;
  verify-app) verify_app "${2:?}" "${3:-}" ;;
  *)
    echo "usage: developer-id.sh import|unlock|cleanup|xcode-settings|sign-app|notarize-app|notarize-dmg|verify-app" >&2
    exit 2
    ;;
esac
