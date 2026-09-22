#!/bin/bash
# Writes build/evidence artifacts only; never launches Settings or registers the app.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
BUILD="$ROOT/.build/p03-read-only"
APP="$BUILD/P03StatusProbe.app"
OUT="$ROOT/docs/evidence/P03"
mkdir -p "$APP/Contents/MacOS" "$OUT"
cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleIdentifier</key><string>dev.watt.evidence.P03StatusProbe</string>
<key>CFBundleExecutable</key><string>P03StatusProbe</string>
<key>CFBundleName</key><string>P03StatusProbe</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleVersion</key><string>1</string>
<key>LSMinimumSystemVersion</key><string>13.0</string>
<key>LSUIElement</key><true/>
</dict></plist>
PLIST
{
    printf 'capture_started_utc=%s\nDEVELOPER_DIR=%s\n' "$(date -u +%FT%TZ)" "$DEVELOPER_DIR"
    sw_vers
    xcrun swiftc --version
    xcodebuild -version
    xcrun swiftc -parse-as-library -swift-version 6 -warnings-as-errors \
        -target "$(uname -m)-apple-macosx13.0" \
        "$ROOT/scripts/P03/StatusProbe.swift" -o "$APP/Contents/MacOS/P03StatusProbe"
    for run in 1 2; do
        printf 'run_%s_started_utc=%s\n' "$run" "$(date -u +%FT%TZ)"
        if "$APP/Contents/MacOS/P03StatusProbe" "$run" > "$OUT/read-only-status-run-$run.json"; then
            cat "$OUT/read-only-status-run-$run.json"
            printf 'run_%s_exit=0\n' "$run"
        else
            code=$?
            printf 'run_%s_exit=%s\n' "$run" "$code"
            exit "$code"
        fi
        if [ "$run" = 1 ]; then sleep 1; fi
    done
    printf 'capture_finished_utc=%s\n' "$(date -u +%FT%TZ)"
} > "$OUT/read-only-status.log" 2>&1
cat "$OUT/read-only-status.log"
