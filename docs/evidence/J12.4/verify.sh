#!/bin/bash
set -u
cd "$(dirname "$0")/../../.."
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
out=docs/evidence/J12.4
run() { name=$1; shift; "$@" > "$out/$name.log" 2>&1; echo $? > "$out/$name.exit"; }
(run focused-tests swift test --filter 'J12|F05FixtureTests|NativeStylingTests|P02HelperLifecycleTests|P05RemovalTests'
run full-tests swift test) &
tests=$!

(run debug xcodebuild -project Watt.xcodeproj -scheme Watt -configuration Debug -derivedDataPath build/J124-Debug CODE_SIGNING_ALLOWED=NO build analyze build-for-testing) &
debug=$!
run release xcodebuild -project Watt.xcodeproj -scheme Watt -configuration Release -derivedDataPath build/J124-Release CODE_SIGNING_ALLOWED=NO build analyze
run release-build-for-testing xcodebuild -project Watt.xcodeproj -scheme Watt -configuration Release -derivedDataPath build/J124-Release CODE_SIGNING_ALLOWED=NO build-for-testing
wait "$tests" "$debug"

run capture bash docs/evidence/J12.4/capture.sh
run static-checks bash docs/evidence/J12.4/static-check.sh
