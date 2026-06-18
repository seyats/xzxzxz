# Architecture

## Composition root

`TideApp` creates one `LocalDatabase` and one `AppDependencies` graph. The graph owns session, social, messenger, notifications, moderation, preferences, push registration, administrator access, REST, WebSocket and routing services. Feature views obtain shared services from the SwiftUI environment while keeping transient editor and presentation state local.

## Persistence

`LocalDatabase` owns a single SwiftData `ModelContainer` and `ModelContext`. The schema contains users, posts, media, stories, chats, messages, comments, reports, notifications, follows, blocks, drafts, device tokens, audit events and bots. Domain values remain small Codable structs; records map at the persistence boundary. This lets a server transport change without leaking DTO or database details into views.

The initial launch seeds a realistic offline account. Subsequent mutations are durable SwiftData writes. Post drafts and imported media survive relaunches.

## Navigation

`AppRouter` stores an independent `NavigationStack` path for each tab and centralizes global sheets and deep links. Home, Chats, Activity and Profile retain separate navigation history. App Intents use one `IntentHandoff` URL path into the router.

## Networking

`APIClient` is a typed async/await REST client. `ChatSocketClient` is an actor around `URLSessionWebSocketTask` with connection states, receive streaming and exponential reconnect. `MessengerStore` writes outgoing messages locally before transport, updates delivery state after sending and accepts incoming socket envelopes idempotently.

Without server URLs the stores remain fully functional in offline mode. Cross-device real-time messaging, remote media and remote APNs delivery require the self-hosted services described in `BACKEND.md`.

## Security

Administrator PINs and development bot tokens use Keychain. Admin access supports biometric authentication and temporary lockout. Moderation decisions append audit records. APNs tokens are stored in SwiftData and must be synchronized to the production backend over authenticated TLS.

## UI

The visual system is monochrome and uses native iOS 26 Liquid Glass only for controls and grouped surfaces. Feed and chat lists use lazy containers, stable UUID identity and narrow observation. Media views support local or remote images and video playback.

## Automation

XcodeGen creates the project from `project.yml`. GitHub CI builds and tests on an iOS Simulator without signing. The release workflow imports a distribution identity and matching provisioning profile, archives the app and exports a signed IPA plus dSYMs.
