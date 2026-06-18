# Tide for iOS 26

Tide is a local-first Swift 6 and SwiftUI social application targeting iOS 26. It includes a persistent feed, real profiles, photo/video posts, comments, stories, direct and group chat, notifications, moderation, an administrator console, live rooms, an in-app browser, App Intents and a Bot API developer console.

## Data and networking

SwiftData is the on-device source of truth. Users, posts, media metadata, comments, chats, messages, stories, reports, notifications, drafts, device tokens, audit events and bot registrations survive relaunches.

The app works offline without any cloud dependency. When `TIDE_API_BASE_URL` and `TIDE_WEBSOCKET_URL` are configured, the included async REST and WebSocket clients become the transport boundary for a self-hosted backend. See `BACKEND.md` for the server contract.

## Generate the Xcode project

```sh
brew install xcodegen
swift Tools/GenerateAppIcon.swift
xcodegen generate
open Tide.xcodeproj
```

Select an Apple Development Team in Signing & Capabilities and run the `Tide` scheme on an iOS 26 simulator or device. Xcode 26 or newer is required.

## IPA builds

The repository contains GitHub Actions for unsigned simulator CI and a manually triggered signed IPA build. The signed workflow imports your certificate and provisioning profile from encrypted GitHub Secrets. Follow `BUILDING.md` exactly.

## Bot platform

Open Settings → Developers → Tide Bot API. The bundled black-and-white HTML guide documents tokens, updates, webhooks, commands, inline keyboards, rate limits and the included Swift SDK. The same guide lives in `Tide/Resources/Docs/index.html`.

## Deep links

- `tide://profile/durov`
- `tide://post/<UUID>`
- `tide://chat/<UUID>`
- `tide://compose`
- `tide://notifications`

## Development content

`Tide/Resources/SeedContent.json` is now an empty fixture by default so the app starts without demo posts. Regenerate it with `Tools/GenerateSeedContent.ps1` only if you need a local test catalogue.

Never commit Apple certificates, provisioning profiles, APNs keys, bot tokens, backend secrets or production access tokens.
