#!/usr/bin/env bash
set -euo pipefail

MARKETING_VERSION="${MARKETING_VERSION:-1.0.0}"
CURRENT_PROJECT_VERSION="${CURRENT_PROJECT_VERSION:-1}"

rm -rf build/archive build/export build/unsigned
mkdir -p build/archive build/export build/unsigned/Payload

xcodegen generate

xcodebuild \
  -project Tide.xcodeproj \
  -scheme Tide \
  -configuration Release \
  -destination 'generic/platform=iOS' \
  -archivePath build/archive/Tide.xcarchive \
  DEVELOPMENT_TEAM="${DEVELOPMENT_TEAM:-}" \
  PRODUCT_BUNDLE_IDENTIFIER="${PRODUCT_BUNDLE_IDENTIFIER:-com.tide.app}" \
  MARKETING_VERSION="${MARKETING_VERSION}" \
  CURRENT_PROJECT_VERSION="${CURRENT_PROJECT_VERSION}" \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO \
  archive

APP_PATH="$(find build/archive/Tide.xcarchive/Products/Applications -maxdepth 1 -name '*.app' -print -quit)"
test -n "${APP_PATH}"
cp -R "${APP_PATH}" build/unsigned/Payload/
cd build/unsigned
zip -qry ../export/Tide-unsigned.ipa Payload
