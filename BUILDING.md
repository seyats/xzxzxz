# Building Tide and producing an IPA

## Local development

Requirements:

- macOS with Xcode 26 or newer
- XcodeGen
- an iOS 26 Simulator

Generate and open the project:

```sh
brew install xcodegen
swift Tools/GenerateAppIcon.swift
xcodegen generate
open Tide.xcodeproj
```

The Simulator build does not need an Apple Developer account. A device build and every installable IPA must be signed.

## GitHub CI

`.github/workflows/ci.yml` generates the Xcode project, builds the app without code signing and runs the test target. It does not create an IPA because simulator products cannot be installed on physical iPhones.

## Signed IPA workflow

Enable Push Notifications and Associated Domains for the App ID in Apple Developer. Create a distribution certificate and an App Store Connect, Ad Hoc, Development, or Enterprise provisioning profile for the same bundle ID.

Add these encrypted GitHub repository secrets:

| Secret | Value |
| --- | --- |
| `APPLE_TEAM_ID` | Ten-character Apple Developer Team ID |
| `APP_BUNDLE_ID` | Bundle ID, for example `com.company.tide` |
| `BUILD_CERTIFICATE_BASE64` | Base64-encoded `.p12` distribution certificate |
| `P12_PASSWORD` | Password used when exporting the `.p12` |
| `BUILD_PROVISION_PROFILE_BASE64` | Base64-encoded `.mobileprovision` file |
| `KEYCHAIN_PASSWORD` | Random temporary keychain password |

Encode files on macOS:

```sh
base64 -i TideDistribution.p12 | pbcopy
base64 -i Tide.mobileprovision | pbcopy
```

Open GitHub Actions, run `Build Signed IPA`, and select the export method that matches the provisioning profile. The workflow uploads the IPA and dSYMs as private run artifacts.

## Server configuration

Set `TIDE_API_BASE_URL` and `TIDE_WEBSOCKET_URL` as launch environment variables in Xcode, or fill `TideAPIBaseURL` and `TideWebSocketURL` through build settings. Without them the app intentionally stays in local-first offline mode backed by SwiftData.

Never commit signing certificates, provisioning profiles, APNs private keys, bot tokens, server secrets, or production URLs containing credentials.
