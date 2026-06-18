#!/usr/bin/env bash
set -euo pipefail

mkdir -p build

xcodebuild \
  -project Tide.xcodeproj \
  -scheme Tide \
  -configuration Debug \
  -sdk iphonesimulator \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath build/DerivedData \
  CODE_SIGNING_ALLOWED=NO \
  build

SIMULATOR_ID="$(xcrun simctl list devices available | awk -F '[()]' '/iPhone/{print $2; exit}')"
if [[ -z "${SIMULATOR_ID}" ]]; then
  echo "No available iPhone simulator found"
  exit 1
fi

xcrun simctl boot "${SIMULATOR_ID}" 2>/dev/null || true
xcodebuild \
  -project Tide.xcodeproj \
  -scheme Tide \
  -configuration Debug \
  -destination "platform=iOS Simulator,id=${SIMULATOR_ID}" \
  -derivedDataPath build/DerivedData \
  -resultBundlePath build/TideTests.xcresult \
  CODE_SIGNING_ALLOWED=NO \
  test
