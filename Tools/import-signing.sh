#!/usr/bin/env bash
set -euo pipefail

CERTIFICATE_PATH="${RUNNER_TEMP}/tide-distribution.p12"
PROFILE_PATH="${RUNNER_TEMP}/tide.mobileprovision"
KEYCHAIN_PATH="${RUNNER_TEMP}/tide-signing.keychain-db"
PROFILE_PLIST="${RUNNER_TEMP}/tide-profile.plist"

printf '%s' "${BUILD_CERTIFICATE_BASE64}" | base64 --decode > "${CERTIFICATE_PATH}"
printf '%s' "${BUILD_PROVISION_PROFILE_BASE64}" | base64 --decode > "${PROFILE_PATH}"

security create-keychain -p "${KEYCHAIN_PASSWORD}" "${KEYCHAIN_PATH}"
security set-keychain-settings -lut 21600 "${KEYCHAIN_PATH}"
security unlock-keychain -p "${KEYCHAIN_PASSWORD}" "${KEYCHAIN_PATH}"
security import "${CERTIFICATE_PATH}" -P "${P12_PASSWORD}" -A -t cert -f pkcs12 -k "${KEYCHAIN_PATH}"
security list-keychain -d user -s "${KEYCHAIN_PATH}" login.keychain-db
security set-key-partition-list -S apple-tool:,apple: -k "${KEYCHAIN_PASSWORD}" "${KEYCHAIN_PATH}"

security cms -D -i "${PROFILE_PATH}" > "${PROFILE_PLIST}"
PROFILE_UUID="$(/usr/libexec/PlistBuddy -c 'Print :UUID' "${PROFILE_PLIST}")"
PROFILE_NAME="$(/usr/libexec/PlistBuddy -c 'Print :Name' "${PROFILE_PLIST}")"
PROFILE_DIRECTORY="${HOME}/Library/MobileDevice/Provisioning Profiles"
mkdir -p "${PROFILE_DIRECTORY}"
cp "${PROFILE_PATH}" "${PROFILE_DIRECTORY}/${PROFILE_UUID}.mobileprovision"

if [[ -n "${GITHUB_ENV:-}" ]]; then
  printf 'PROFILE_UUID=%s\n' "${PROFILE_UUID}" >> "${GITHUB_ENV}"
  printf 'PROFILE_NAME=%s\n' "${PROFILE_NAME}" >> "${GITHUB_ENV}"
  printf 'SIGNING_KEYCHAIN=%s\n' "${KEYCHAIN_PATH}" >> "${GITHUB_ENV}"
fi
