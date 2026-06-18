import Foundation

struct BotUser: Codable, Identifiable, Sendable {
    let id: Int64
    let isBot: Bool
    let firstName: String
    let lastName: String?
    let username: String?
}

struct BotChat: Codable, Identifiable, Sendable {
    enum Kind: String, Codable, Sendable { case privateChat = "private", group, supergroup, channel }
    let id: Int64
    let kind: Kind
    let title: String?
    let username: String?
    let firstName: String?
    let lastName: String?
}

struct BotMessage: Codable, Identifiable, Sendable {
    let id: Int64
    let date: Date
    let chat: BotChat
    let from: BotUser?
    let text: String?
    let caption: String?
    let entities: [BotMessageEntity]?
}

struct BotMessageEntity: Codable, Sendable {
    let type: String
    let offset: Int
    let length: Int
    let url: URL?
    let user: BotUser?
}

struct BotCallbackQuery: Codable, Identifiable, Sendable {
    let id: String
    let from: BotUser
    let message: BotMessage?
    let data: String?
}

struct BotUpdate: Codable, Identifiable, Sendable {
    let id: Int64
    let message: BotMessage?
    let editedMessage: BotMessage?
    let channelPost: BotMessage?
    let callbackQuery: BotCallbackQuery?
}

struct BotInlineKeyboardButton: Codable, Sendable {
    let text: String
    let url: URL?
    let callbackData: String?

    init(text: String, url: URL? = nil, callbackData: String? = nil) {
        self.text = text
        self.url = url
        self.callbackData = callbackData
    }
}

struct BotInlineKeyboardMarkup: Codable, Sendable {
    let inlineKeyboard: [[BotInlineKeyboardButton]]
}

struct BotAPIResponse<Result: Codable & Sendable>: Codable, Sendable {
    let ok: Bool
    let result: Result?
    let description: String?
    let errorCode: Int?
}

enum BotParseMode: String, Codable, Sendable {
    case markdownV2 = "MarkdownV2"
    case html = "HTML"
}

struct SendBotMessageRequest: Codable, Sendable {
    let chatID: Int64
    let text: String
    let parseMode: BotParseMode?
    let disableNotification: Bool
    let replyMarkup: BotInlineKeyboardMarkup?
}

struct SetWebhookRequest: Codable, Sendable {
    let url: URL
    let secretToken: String
    let allowedUpdates: [String]
    let dropPendingUpdates: Bool
}

enum BotAPIError: LocalizedError, Sendable {
    case invalidEndpoint
    case invalidResponse
    case rejected(String)

    var errorDescription: String? {
        switch self {
        case .invalidEndpoint: "Bot API endpoint is invalid"
        case .invalidResponse: "Bot API returned an invalid response"
        case .rejected(let message): message
        }
    }
}

actor TideBotAPIClient {
    private let baseURL: URL
    private let token: String
    private let session: URLSession
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(token: String, baseURL: URL, session: URLSession = .shared) {
        self.token = token
        self.baseURL = baseURL
        self.session = session
        encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        encoder.dateEncodingStrategy = .secondsSince1970
        decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .secondsSince1970
    }

    func getMe() async throws -> BotUser {
        try await call("getMe", body: Optional<String>.none, result: BotUser.self)
    }

    func getUpdates(offset: Int64? = nil, timeout: Int = 30) async throws -> [BotUpdate] {
        struct Request: Codable, Sendable { let offset: Int64?; let timeout: Int }
        return try await call("getUpdates", body: Request(offset: offset, timeout: timeout), result: [BotUpdate].self)
    }

    func sendMessage(
        chatID: Int64,
        text: String,
        parseMode: BotParseMode? = .html,
        disableNotification: Bool = false,
        keyboard: BotInlineKeyboardMarkup? = nil
    ) async throws -> BotMessage {
        let request = SendBotMessageRequest(chatID: chatID, text: text, parseMode: parseMode, disableNotification: disableNotification, replyMarkup: keyboard)
        return try await call("sendMessage", body: request, result: BotMessage.self)
    }

    func setWebhook(url: URL, secretToken: String, allowedUpdates: [String] = ["message", "callback_query"]) async throws -> Bool {
        let request = SetWebhookRequest(url: url, secretToken: secretToken, allowedUpdates: allowedUpdates, dropPendingUpdates: false)
        return try await call("setWebhook", body: request, result: Bool.self)
    }

    func deleteWebhook(dropPendingUpdates: Bool = false) async throws -> Bool {
        struct Request: Codable, Sendable { let dropPendingUpdates: Bool }
        return try await call("deleteWebhook", body: Request(dropPendingUpdates: dropPendingUpdates), result: Bool.self)
    }

    func answerCallbackQuery(id: String, text: String? = nil, showAlert: Bool = false) async throws -> Bool {
        struct Request: Codable, Sendable { let callbackQueryID: String; let text: String?; let showAlert: Bool }
        return try await call("answerCallbackQuery", body: Request(callbackQueryID: id, text: text, showAlert: showAlert), result: Bool.self)
    }

    private func call<Body: Encodable & Sendable, Result: Codable & Sendable>(_ method: String, body: Body?, result: Result.Type) async throws -> Result {
        guard let url = URL(string: "bot\(token)/\(method)", relativeTo: baseURL) else { throw BotAPIError.invalidEndpoint }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let body { request.httpBody = try encoder.encode(body) }
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, 200..<500 ~= http.statusCode else { throw BotAPIError.invalidResponse }
        let envelope = try decoder.decode(BotAPIResponse<Result>.self, from: data)
        guard envelope.ok, let value = envelope.result else { throw BotAPIError.rejected(envelope.description ?? "Bot API request failed") }
        return value
    }
}
