# Tide Bot API

The full visual guide lives at `Tide/Resources/Docs/index.html` and opens in-app from Settings → Developers → Tide Bot API.

What the bundle includes:

- authenticated bot requests and secret handling;
- webhook delivery and long polling;
- message sending, callbacks, and inline keyboards;
- a Swift actor-based client for local automation and previews;
- OpenAPI 3.1 documentation for backend integration.

Core routes:

```text
POST /bot<token>/getMe
POST /bot<token>/getUpdates
POST /bot<token>/sendMessage
POST /bot<token>/setWebhook
POST /bot<token>/deleteWebhook
POST /bot<token>/answerCallbackQuery
```

Webhook deliveries arrive as JSON `BotUpdate` payloads and include `X-Tide-Bot-Secret`.
Verify the secret, acknowledge quickly, deduplicate by update ID, and move slow work into a queue.
