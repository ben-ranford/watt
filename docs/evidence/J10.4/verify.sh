#!/bin/bash
set -u
cd "$(dirname "$0")/../../.."
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
out=docs/evidence/J10.4
run() { name=$1; shift; "$@" > "$out/$name.log" 2>&1; echo $? > "$out/$name.exit"; }
run focused-tests swift test --filter 'J10|NativeStylingTests|P04UpdaterTests'
run full-tests swift test
