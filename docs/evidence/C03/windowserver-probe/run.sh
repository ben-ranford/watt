#!/bin/bash
# Compile-only probe: does not execute capture or request permissions.
set -euo pipefail
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
cd "$(dirname "$0")"
{ xcodebuild -version; xcrun swiftc --version; sw_vers; xcrun --show-sdk-path; } > environment.log 2>&1
result=0
xcrun swiftc -swift-version 6 -typecheck probe.swift > typecheck.log 2>&1 || result=$?
printf 'typecheck exit: %s\n' "$result"
cat typecheck.log
if [[ "$result" == 0 ]]; then
  echo 'API is compile-available; runtime capture and visual comparison remain untested.'
  exit 0
fi
exit "$result"
