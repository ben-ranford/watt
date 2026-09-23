#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
DEVELOPER_DIR=${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}
DERIVED_DATA=${1:-"$ROOT/.build/p01-host-probe"}
PRODUCTS="$DERIVED_DATA/Build/Products/Debug"
APP="$PRODUCTS/Watt.app"
TEST_BUNDLE="$APP/Contents/PlugIns/WattTests.xctest"
LOG_DIR="$ROOT/docs/evidence/P01"
LOG="$LOG_DIR/physical-host-probe-$(date +%Y-%m-%d).log"

mkdir -p "$LOG_DIR"

{
    echo "command: xcodebuild build-for-testing + xcrun xctest"
    echo "date: $(date -u '+%Y-%m-%dT%H:%M:%SZ')"
    echo "developer_dir: $DEVELOPER_DIR"
    echo "derived_data: $DERIVED_DATA"

    DEVELOPER_DIR="$DEVELOPER_DIR" xcodebuild \
        -project "$ROOT/Watt.xcodeproj" \
        -scheme Watt \
        -configuration Debug \
        -destination 'platform=macOS' \
        -derivedDataPath "$DERIVED_DATA" \
        build-for-testing \
        -parallel-testing-enabled NO

    test -d "$TEST_BUNDLE"
    test -f "$APP/Contents/MacOS/Watt.debug.dylib"
    mkdir -p "$TEST_BUNDLE/Contents/Frameworks"
    cp "$APP/Contents/MacOS/Watt.debug.dylib" \
        "$TEST_BUNDLE/Contents/Frameworks/Watt.debug.dylib"
    codesign --force --deep --sign - --timestamp=none "$TEST_BUNDLE"
    codesign --verify --deep --strict --verbose=2 "$TEST_BUNDLE"

    DEVELOPER_DIR="$DEVELOPER_DIR" \
    WATT_P01_HOST_PROBE=1 \
    xcrun xctest \
        -XCTest P01TelemetryTests/testPhysicalHostPublicAPISmoke \
        "$TEST_BUNDLE"
} 2>&1 | tee "$LOG"

echo "physical host probe log: $LOG"
