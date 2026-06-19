#!/usr/bin/env bash
set -euo pipefail

mkdir -p build

SIGNED_READY="false"
if [[ -n "${APPLE_TEAM_ID:-}" && -n "${IOS_CERT_BASE64:-}" && -n "${IOS_CERT_PASSWORD:-}" && -n "${IOS_PROFILE_BASE64:-}" ]]; then
  SIGNED_READY="true"
fi

if [[ "$SIGNED_READY" == "true" ]]; then
  KEYCHAIN_PATH="$RUNNER_TEMP/tide-signing.keychain-db"
  CERT_PATH="$RUNNER_TEMP/tide-signing.p12"
  PROFILE_PATH="$HOME/Library/MobileDevice/Provisioning Profiles/Tide.mobileprovision"

  mkdir -p "$HOME/Library/MobileDevice/Provisioning Profiles"
  printf '%s' "$IOS_CERT_BASE64" | base64 --decode > "$CERT_PATH"
  printf '%s' "$IOS_PROFILE_BASE64" | base64 --decode > "$PROFILE_PATH"

  security create-keychain -p "" "$KEYCHAIN_PATH"
  security set-keychain-settings -lut 21600 "$KEYCHAIN_PATH"
  security unlock-keychain -p "" "$KEYCHAIN_PATH"
  security import "$CERT_PATH" -P "$IOS_CERT_PASSWORD" -A -t cert -f pkcs12 -k "$KEYCHAIN_PATH"
  security list-keychains -d user -s "$KEYCHAIN_PATH" login.keychain-db
  security set-key-partition-list -S apple-tool:,apple:,codesign: -s -k "" "$KEYCHAIN_PATH"

  xcodebuild \
    -project Tide.xcodeproj \
    -scheme Tide \
    -configuration Release \
    -destination 'generic/platform=iOS' \
    -archivePath build/Tide.xcarchive \
    DEVELOPMENT_TEAM="$APPLE_TEAM_ID" \
    CODE_SIGN_STYLE=Automatic \
    clean archive

  xcodebuild \
    -exportArchive \
    -archivePath build/Tide.xcarchive \
    -exportOptionsPlist ExportOptions.plist \
    -exportPath build/ExportedIPA \
    DEVELOPMENT_TEAM="$APPLE_TEAM_ID"

  IPA_PATH="$(find build/ExportedIPA -name '*.ipa' -print -quit)"
  if [[ -z "$IPA_PATH" ]]; then
    echo "IPA export finished but no .ipa file was found."
    exit 1
  fi

  cp "$IPA_PATH" "build/Tide.ipa"
  exit 0
fi

echo "Signing secrets are missing, building an unsigned IPA artifact instead."

xcodebuild \
  -project Tide.xcodeproj \
  -scheme Tide \
  -configuration Release \
  -sdk iphoneos \
  -destination 'generic/platform=iOS' \
  -derivedDataPath build/DerivedData \
  CODE_SIGNING_ALLOWED=NO \
  clean build

APP_PATH="$(find build/DerivedData/Build/Products/Release-iphoneos -name 'Tide.app' -print -quit)"
if [[ -z "$APP_PATH" ]]; then
  echo "Unsigned build finished but Tide.app was not found."
  exit 1
fi

rm -rf build/Payload build/Tide.ipa
mkdir -p build/Payload
cp -R "$APP_PATH" build/Payload/
pushd build >/dev/null
ditto -c -k --sequesterRsrc --keepParent Payload Tide.ipa
popd >/dev/null
