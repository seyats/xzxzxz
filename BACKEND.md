# Tide backend contract

The iOS application is local-first. SwiftData is the durable on-device source of truth; a self-hosted backend is optional for multi-device accounts, real-time chat, remote media and APNs delivery.

## Required services

- Identity service issuing short-lived access tokens and refresh tokens.
- REST API for users, follows, posts, comments, stories, moderation and upload sessions.
- WebSocket gateway for messages, typing, presence and read receipts.
- Object storage with signed upload and download URLs.
- APNs provider using token-based authentication.
- Bot API gateway and webhook delivery queue.

## REST conventions

- Base path: `/v1`.
- JSON uses snake_case on the wire and ISO-8601 timestamps.
- Mutations accept an `Idempotency-Key` header.
- Pagination uses opaque `cursor` and `next_cursor` values.
- Errors use `{ "error": { "code": "...", "message": "...", "request_id": "..." } }`.
- Uploads use short-lived signed URLs; raw videos do not pass through the API process.

Suggested endpoints:

```text
POST   /v1/auth/session
POST   /v1/auth/refresh
GET    /v1/users/{id}
PATCH  /v1/users/me
POST   /v1/users/{id}/follow
DELETE /v1/users/{id}/follow
GET    /v1/feed
POST   /v1/posts
GET    /v1/posts/{id}
DELETE /v1/posts/{id}
POST   /v1/posts/{id}/comments
POST   /v1/uploads
POST   /v1/stories
GET    /v1/chats
GET    /v1/chats/{id}/messages
POST   /v1/reports
GET    /v1/admin/reports
PATCH  /v1/admin/reports/{id}
POST   /v1/devices/apns
```

## WebSocket events

The client already understands envelopes with `event`, `chat_id`, `message_id`, `sender_id`, `body`, `sent_at`, and string metadata. Authenticate during the HTTP upgrade with a bearer token.

Supported event names:

- `message`
- `message_updated`
- `typing`
- `presence`
- `read_receipt`
- `ping`

Every client message must have a UUID generated before transmission. The server treats it as an idempotency key, persists once, and broadcasts the accepted event to all account devices.

## Push notifications

The app registers with APNs and stores its device token in SwiftData. A production sync adapter must upload the token to `/v1/devices/apns`. The server maps notification payloads to `tide://post/{id}`, `tide://profile/{username}`, or `tide://chat/{id}` deep links.

Use alert pushes for user-visible events and background pushes only for bounded synchronization. Do not include message plaintext in a push when end-to-end encryption is enabled.
