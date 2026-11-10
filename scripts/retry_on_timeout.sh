#!/bin/bash
# Run a command under scripts/run_with_timeout.py.
# Retry only when the watchdog exits 124.
# When WATT_RESULT_BUNDLE is set, delete it before every attempt so xcodebuild
# can write a new result bundle after a killed run.
set -euo pipefail

if [[ $# -lt 4 || "$3" != "--" ]]; then
  echo "usage: retry_on_timeout.sh <seconds> <retries> -- <command>..." >&2
  exit 2
fi
seconds="$1"
retries="$2"
shift 3
if [[ ! "$seconds" =~ ^[0-9]+$ || "$seconds" -lt 1 || ! "$retries" =~ ^[0-9]+$ ]]; then
  echo "seconds must be a positive integer and retries a non-negative integer" >&2
  exit 2
fi

if [[ -n "${WATT_RESULT_BUNDLE:-}" ]]; then
  case "${WATT_RESULT_BUNDLE}" in
    /*/WattTests.xcresult) ;;
    *)
      echo "refusing to delete result bundle: ${WATT_RESULT_BUNDLE}" >&2
      exit 2
      ;;
  esac
fi

root=$(cd "$(dirname "$0")" && pwd)
attempt=0
status=0
while true; do
  if [[ -n "${WATT_RESULT_BUNDLE:-}" ]]; then
    rm -rf -- "${WATT_RESULT_BUNDLE}"
  fi
  status=0
  python3 "${root}/run_with_timeout.py" --seconds "${seconds}" -- "$@" || status=$?
  if [[ "${status}" -ne 124 || "${attempt}" -ge "${retries}" ]]; then
    exit "${status}"
  fi
  attempt=$((attempt + 1))
  echo "command did not exit within ${seconds}s; retrying (${attempt}/${retries})." >&2
done
