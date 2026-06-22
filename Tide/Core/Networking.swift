import Foundation
import Observation

struct ServerConfiguration: Sendable {
    let apiBaseURL: URL?
    let webSocketURL: URL?

    static var current: ServerConfiguration {
        let dictionary = ProcessInfo.processInfo.environment
        let api = dictionary["TIDE_API_BASE_URL"].flatMap(URL.init(string:))
            ?? (Bundle.main.object(forInfoDictionaryKey: "TideAPIBaseURL") as? String).flatMap(URL.init(string:))
        let socket = dictionary["TIDE_WEBSOCKET_URL"].flatMap(URL.init(string:))
            ?? (Bundle.main.object(forInfoDictionaryKey: "TideWebSocketURL") as? String).flatMap(URL.init(string:))
        return ServerConfiguration(apiBaseURL: api, webSocketURL: socket)
    }

    var isRemoteEnabled: Bool { apiBaseURL != nil }
}

enum APIError: LocalizedError, Sendable {
    case notConfigured
    case invalidResponse
    case unauthorized
    case server(Int, String)
    case invalidPayload

    var errorDescription: String? {
        switch self {
        case .notConfigured: "Сервер Tide не настроен."
        case .invalidResponse: "Сервер вернул некорректный ответ."
        case .unauthorized: "Сессия истекла. Войдите ещё раз."
        case .server(let status, let message): "Ошибка сервера \(status): \(message)"
        case .invalidPayload: "Не удалось подготовить запрос."
        }
    }
}

struct EmptyResponse: Codable, Sendable {}

struct AuthSessionDTO: Codable, Sendable {
    let token: String
    let userID: UUID
    let username: String
    let displayName: String
    let requiresProfileSetup: Bool
}

struct ChatDTO: Codable, Identifiable, Sendable {
    let id: UUID
    let title: String
    let kind: String
    let participantIDs: [UUID]
    let updatedAt: Date
}

struct MessageDTO: Codable, Identifiable, Sendable {
    let id: UUID
    let chatID: UUID
    let senderID: UUID
    let body: String
    let attachmentURL: URL?
    let attachmentKind: String
    let replyToMessageID: UUID?
    let sentAt: Date
    let state: String
}

struct CallSessionDTO: Codable, Identifiable, Sendable {
    let id: UUID
    let chatID: UUID
    let initiatorID: UUID
    let isVideo: Bool
    let state: String
    let startedAt: Date?
    let endedAt: Date?
}

struct MediaUploadDTO: Codable, Sendable {
    let uploadURL: URL
    let publicURL: URL
    let kind: String
    let expiresAt: Date
}

struct LoginRequestDTO: Codable, Sendable {
    let identifier: String
    let password: String
}

struct RegisterRequestDTO: Codable, Sendable {
    let email: String?
    let username: String
    let password: String
    let displayName: String
}

struct CreateChatRequestDTO: Codable, Sendable {
    let participantIDs: [UUID]
    let title: String?
    let kind: String
}

struct SendMessageRequestDTO: Codable, Sendable {
    let chatID: UUID
    let body: String
    let attachmentURL: URL?
    let attachmentKind: String
    let replyToMessageID: UUID?
}

struct UpdateMessageRequestDTO: Codable, Sendable {
    let body: String
}

struct MediaUploadRequestDTO: Codable, Sendable {
    let kind: String
    let fileName: String
    let contentType: String
}

struct CreateCallRequestDTO: Codable, Sendable {
    let chatID: UUID
    let isVideo: Bool
}

struct DeviceTokenRequestDTO: Codable, Sendable {
    let token: String
    let environment: String
}

struct TideRemoteMessengerAPI: Sendable {
    let client: APIClient

    func login(identifier: String, password: String) async throws -> AuthSessionDTO {
        try await client.post("/auth/login", body: LoginRequestDTO(identifier: identifier, password: password), as: AuthSessionDTO.self)
    }

    func register(email: String?, username: String, password: String, displayName: String) async throws -> AuthSessionDTO {
        try await client.post("/auth/register", body: RegisterRequestDTO(email: email, username: username, password: password, displayName: displayName), as: AuthSessionDTO.self)
    }

    func logout() async throws {
        try await client.post("/auth/logout", body: EmptyResponse(), as: EmptyResponse.self)
    }

    func chats() async throws -> [ChatDTO] {
        try await client.get("/chats", as: [ChatDTO].self)
    }

    func createChat(participantIDs: [UUID], title: String?, kind: String) async throws -> ChatDTO {
        try await client.post("/chats", body: CreateChatRequestDTO(participantIDs: participantIDs, title: title, kind: kind), as: ChatDTO.self)
    }

    func messages(chatID: UUID) async throws -> [MessageDTO] {
        try await client.get("/chats/\(chatID.uuidString)/messages", as: [MessageDTO].self)
    }

    func sendMessage(_ request: SendMessageRequestDTO) async throws -> MessageDTO {
        try await client.post("/messages", body: request, as: MessageDTO.self)
    }

    func updateMessage(id: UUID, body: String) async throws -> MessageDTO {
        try await client.patch("/messages/\(id.uuidString)", body: UpdateMessageRequestDTO(body: body), as: MessageDTO.self)
    }

    func deleteMessage(id: UUID) async throws {
        try await client.delete("/messages/\(id.uuidString)")
    }

    func requestMediaUpload(kind: String, fileName: String, contentType: String) async throws -> MediaUploadDTO {
        try await client.post("/media/upload", body: MediaUploadRequestDTO(kind: kind, fileName: fileName, contentType: contentType), as: MediaUploadDTO.self)
    }

    func createCall(chatID: UUID, isVideo: Bool) async throws -> CallSessionDTO {
        try await client.post("/calls", body: CreateCallRequestDTO(chatID: chatID, isVideo: isVideo), as: CallSessionDTO.self)
    }

    func joinCall(id: UUID) async throws -> CallSessionDTO {
        try await client.post("/calls/\(id.uuidString)/join", body: EmptyResponse(), as: CallSessionDTO.self)
    }

    func endCall(id: UUID) async throws -> CallSessionDTO {
        try await client.post("/calls/\(id.uuidString)/end", body: EmptyResponse(), as: CallSessionDTO.self)
    }

    func registerDevice(token: String, environment: String) async throws {
        try await client.post("/devices/apns", body: DeviceTokenRequestDTO(token: token, environment: environment), as: EmptyResponse.self)
    }
}

actor APIClient {
    private let configuration: ServerConfiguration
    private let session: URLSession
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    private var authorizationToken: String?

    init(configuration: ServerConfiguration = .current, session: URLSession = .shared) {
        self.configuration = configuration
        self.session = session
        encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
    }

    func setAuthorizationToken(_ token: String?) {
        authorizationToken = token
    }

    func get<Response: Decodable & Sendable>(_ path: String, as type: Response.Type) async throws -> Response {
        try await request(path: path, method: "GET", body: Optional<String>.none, as: type)
    }

    func post<Body: Encodable & Sendable, Response: Decodable & Sendable>(_ path: String, body: Body, as type: Response.Type) async throws -> Response {
        try await request(path: path, method: "POST", body: body, as: type)
    }

    func patch<Body: Encodable & Sendable, Response: Decodable & Sendable>(_ path: String, body: Body, as type: Response.Type) async throws -> Response {
        try await request(path: path, method: "PATCH", body: body, as: type)
    }

    func delete(_ path: String) async throws {
        let _: EmptyResponse = try await request(path: path, method: "DELETE", body: Optional<String>.none, as: EmptyResponse.self)
    }

    private func request<Body: Encodable & Sendable, Response: Decodable & Sendable>(
        path: String,
        method: String,
        body: Body?,
        as type: Response.Type
    ) async throws -> Response {
        guard let baseURL = configuration.apiBaseURL else { throw APIError.notConfigured }
        guard let url = URL(string: path, relativeTo: baseURL) else { throw APIError.invalidPayload }
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let authorizationToken {
            request.setValue("Bearer \(authorizationToken)", forHTTPHeaderField: "Authorization")
        }
        if let body {
            request.httpBody = try encoder.encode(body)
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw APIError.invalidResponse }
        if http.statusCode == 401 { throw APIError.unauthorized }
        guard 200..<300 ~= http.statusCode else {
            throw APIError.server(http.statusCode, String(data: data, encoding: .utf8) ?? "Unknown error")
        }
        if Response.self == EmptyResponse.self, data.isEmpty {
            return EmptyResponse() as! Response
        }
        return try decoder.decode(Response.self, from: data)
    }
}

enum SocketConnectionState: Equatable, Sendable {
    case disconnected
    case connecting
    case connected
    case reconnecting(Int)
    case failed(String)
}

struct ChatSocketEnvelope: Codable, Sendable {
    enum Event: String, Codable, Sendable {
        case authenticate
        case message
        case messageUpdated
        case typing
        case presence
        case readReceipt
        case callInvite
        case callState
        case ping
    }

    let event: Event
    let chatID: UUID?
    let messageID: UUID?
    let senderID: UUID?
    let body: String?
    let sentAt: Date
    let metadata: [String: String]
}

actor ChatSocketClient {
    private let configuration: ServerConfiguration
    private let session: URLSession
    private var task: URLSessionWebSocketTask?
    private var receiverTask: Task<Void, Never>?
    private var reconnectTask: Task<Void, Never>?
    private var token: String?
    private var attempt = 0
    private var continuation: AsyncStream<ChatSocketEnvelope>.Continuation?
    private var stateContinuation: AsyncStream<SocketConnectionState>.Continuation?

    init(configuration: ServerConfiguration = .current, session: URLSession = .shared) {
        self.configuration = configuration
        self.session = session
    }

    func events() -> AsyncStream<ChatSocketEnvelope> {
        AsyncStream { continuation in
            self.continuation = continuation
            continuation.onTermination = { [weak self] _ in
                Task { await self?.disconnect() }
            }
        }
    }

    func states() -> AsyncStream<SocketConnectionState> {
        AsyncStream { continuation in
            self.stateContinuation = continuation
            continuation.yield(.disconnected)
        }
    }

    func connect(token: String? = nil) {
        guard task == nil else { return }
        guard let url = configuration.webSocketURL else {
            stateContinuation?.yield(.failed("WebSocket URL is not configured"))
            return
        }
        self.token = token
        stateContinuation?.yield(attempt == 0 ? .connecting : .reconnecting(attempt))
        var request = URLRequest(url: url)
        if let token { request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }
        let socket = session.webSocketTask(with: request)
        task = socket
        socket.resume()
        stateContinuation?.yield(.connected)
        attempt = 0
        receiverTask = Task { await receiveLoop() }
    }

    func disconnect() {
        reconnectTask?.cancel()
        receiverTask?.cancel()
        task?.cancel(with: .goingAway, reason: nil)
        task = nil
        stateContinuation?.yield(.disconnected)
    }

    func send(_ envelope: ChatSocketEnvelope) async throws {
        guard let task else { throw APIError.notConfigured }
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(envelope)
        try await task.send(.data(data))
    }

    private func receiveLoop() async {
        guard let task else { return }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        do {
            while !Task.isCancelled {
                let payload = try await task.receive()
                let data: Data
                switch payload {
                case .data(let value): data = value
                case .string(let value): data = Data(value.utf8)
                @unknown default: continue
                }
                let envelope = try decoder.decode(ChatSocketEnvelope.self, from: data)
                continuation?.yield(envelope)
            }
        } catch {
            self.task = nil
            stateContinuation?.yield(.failed(error.localizedDescription))
            scheduleReconnect()
        }
    }

    private func scheduleReconnect() {
        attempt += 1
        let delay = min(pow(2, Double(attempt)), 30)
        reconnectTask = Task {
            try? await Task.sleep(for: .seconds(delay))
            guard !Task.isCancelled else { return }
            connect(token: token)
        }
    }
}
