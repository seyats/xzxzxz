#!/usr/bin/env bash
set -euo pipefail

: "${DEVELOPMENT_TEAM:?APPLE_TEAM_ID is required}"
: "${PRODUCT_BUNDLE_IDENTIFIER:?APP_BUNDLE_ID is required}"
: "${PROFILE_NAME:?Provisioning profile was not imported}"

MARKETING_VERSION="${MARKETING_VERSION:-1.0.0}"
CURRENT_PROJECT_VERSION="${CURRENT_PROJECT_VERSION:-1}"
EXPORT_METHOD="${EXPORT_METHOD:-app-store-connect}"

rm -rf build/archive build/export
mkdir -p build/archive build/export
swift Tools/GenerateAppIcon.swift
xcodegen generate

xcodebuild \
  -project Tide.xcodeproj \
  -scheme Tide \
  -configuration Release \
  -destination 'generic/platform=iOS' \
  -archivePath build/archive/Tide.xcarchive \
  DEVELOPMENT_TEAM="${DEVELOPMENT_TEAM}" \
  PRODUCT_BUNDLE_IDENTIFIER="${PRODUCT_BUNDLE_IDENTIFIER}" \
  MARKETING_VERSION="${MARKETING_VERSION}" \
  CURRENT_PROJECT_VERSION="${CURRENT_PROJECT_VERSION}" \
  CODE_SIGN_STYLE=Manual \
  CODE_SIGN_IDENTITY='Apple Distribution' \
  PROVISIONING_PROFILE_SPECIFIER="${PROFILE_NAME}" \
  archive

EXPORT_PLIST="${RUNNER_TEMP:-build}/TideExportOptions.plist"
cp ExportOptions.plist "${EXPORT_PLIST}"
/usr/libexec/PlistBuddy -c "Set :method ${EXPORT_METHOD}" "${EXPORT_PLIST}"
/usr/libexec/PlistBuddy -c "Set :signingStyle manual" "${EXPORT_PLIST}"
/usr/libexec/PlistBuddy -c "Add :teamID string ${DEVELOPMENT_TEAM}" "${EXPORT_PLIST}" 2>/dev/null || /usr/libexec/PlistBuddy -c "Set :teamID ${DEVELOPMENT_TEAM}" "${EXPORT_PLIST}"
/usr/libexec/PlistBuddy -c 'Add :provisioningProfiles dict' "${EXPORT_PLIST}" 2>/dev/null || true
/usr/libexec/PlistBuddy -c "Add :provisioningProfiles:${PRODUCT_BUNDLE_IDENTIFIER} string ${PROFILE_NAME}" "${EXPORT_PLIST}" 2>/dev/null || /usr/libexec/PlistBuddy -c "Set :provisioningProfiles:${PRODUCT_BUNDLE_IDENTIFIER} ${PROFILE_NAME}" "${EXPORT_PLIST}"

xcodebuild \
  -exportArchive \
  -archivePath build/archive/Tide.xcarchive \
  -exportPath build/export \
  -exportOptionsPlist "${EXPORT_PLIST}"

test -n "$(find build/export -maxdepth 1 -name '*.ipa' -print -quit)"
