#!/bin/bash
set -euo pipefail
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
cd "$(dirname "$0")/../../.."
host="$PWD/docs/evidence/native-styling/CaptureHost.swift"
out="${1:-$PWD/docs/evidence/native-styling/verification-2026-09-22}"
mkdir -p "$out"
mkdir -p .build/native-styling-capture
xcrun swiftc -D DEBUG -parse-as-library   DesignSystem/Theme/*.swift DesignSystem/Components/*.swift DesignSystem/Verification/*.swift   Models/*.swift Services/*.swift Features/MenuBar/Views/StatusPanelView.swift   Features/Onboarding/Views/OnboardingFlowView.swift Features/Settings/Views/SettingsRootView.swift "$host"   -o .build/native-styling-capture/host
.build/native-styling-capture/host "$out"
