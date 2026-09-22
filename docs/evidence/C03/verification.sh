#!/bin/bash
set -euo pipefail
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
out="$PWD/docs/evidence/C03"
package_checks() {
  swift test --scratch-path .build/c03-package --filter 'C03ContextMenuTests|F05FixtureTests' > "$out/package-focused.log" 2>&1
  swift test --scratch-path .build/c03-package > "$out/package-full.log" 2>&1
}
native_checks() {
  xcodebuild -project Watt.xcodeproj -scheme Watt -configuration Debug -destination 'platform=macOS' -derivedDataPath .build/c03-native build analyze > "$out/debug-build-analyze.log" 2>&1
  bash "$out/capture.sh" > "$out/capture-run.log" 2>&1
  xcodebuild -project Watt.xcodeproj -scheme Watt -configuration Debug -destination 'platform=macOS' -derivedDataPath .build/c03-native test -only-testing:WattTests/F05FixtureTests -only-testing:WattTests/C03ContextMenuTests -parallel-testing-enabled NO > "$out/native-focused.log" 2>&1
  xcodebuild -project Watt.xcodeproj -scheme Watt -configuration Debug -destination 'platform=macOS' -derivedDataPath .build/c03-native test -only-testing:WattTests -parallel-testing-enabled NO > "$out/native-full.log" 2>&1
}
release_checks() {
  xcodebuild -project Watt.xcodeproj -scheme Watt -configuration Release -destination 'platform=macOS' -derivedDataPath .build/c03-release build analyze > "$out/release-build-analyze.log" 2>&1
  if strings .build/c03-release/Build/Products/Release/Watt.app/Contents/MacOS/Watt | grep -E 'C03FixtureLaunch|watt-c03-capture|capture-attempt.json|--watt-fixture'; then
    echo 'Release isolation FAILED' > "$out/release-isolation.log"; return 1
  fi
  echo 'No C03 harness / fixture selector strings in Release binary' > "$out/release-isolation.log"
}
package_checks & package=$!
native_checks & native=$!
release_checks & release=$!
wait "$package"
wait "$native"
wait "$release"
git diff --check > "$out/diff-check.log"
bash -n "$out/capture.sh" "$out/verification.sh"
echo 'Verification succeeded'
