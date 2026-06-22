import Foundation
import CryptoKit
import Observation
import SwiftUI

@MainActor
@Observable
final class SessionStore {
    private let database: LocalDatabase?
    private let defaults: UserDefaults
    private(set) var currentUser: User?
    private(set) var isWorking = false
    private(set) var errorMessage: String?
    var isAuthenticated: Bool { currentUser != nil }
    var needsProfileSetup: Bool {
        guard let currentUser else { return false }
        return !defaults.bool(forKey: profileSetupKey(for: currentUser.id))
    }
    private let currentUserKey = "tide.currentUserID"
    private let demoIdentifier = "durov"
    private let demoPassword = "Sy3uki90."

    init(currentUser: User? = nil, database: LocalDatabase? = nil, defaults: UserDefaults = .standard) {
        self.database = database
        self.defaults = defaults
        if let currentUser {
            self.currentUser = currentUser
        } else if let storedID = defaults.string(forKey: currentUserKey), let userID = UUID(uuidString: storedID) {
            self.currentUser = database?.user(id: userID)
        }
    }

    func signInIdentifier(_ identifier: String, password: String) async {
        isWorking = true
        defer { isWorking = false }
        try? await Task.sleep(for: .milliseconds(320))
        let normalizedIdentifier = identifier.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !normalizedIdentifier.isEmpty, !password.isEmpty else {
            errorMessage = "Введите username или почту и пароль."
            return
        }
        if let user = userForUsernameLogin(normalizedIdentifier, password: password) {
            currentUser = user
            defaults.set(user.id.uuidString, forKey: currentUserKey)
            defaults.set(true, forKey: profileSetupKey(for: user.id))
            errorMessage = nil
            return
        }
        guard normalizedIdentifier == demoIdentifier || normalizedIdentifier == "\(demoIdentifier)@tide.app" else {
            errorMessage = "Аккаунт не найден или пароль введён неверно."
            return
        }
        guard password == demoPassword else {
            errorMessage = "Неверный пароль."
            return
        }
        let user = ensureDemoUser()
        currentUser = user
        defaults.set(user.id.uuidString, forKey: currentUserKey)
        defaults.set(true, forKey: profileSetupKey(for: user.id))
        errorMessage = nil
    }

    func signInEmail(email: String, password: String, displayName: String? = nil, createsAccount: Bool = false) async {
        isWorking = true
        defer { isWorking = false }
        try? await Task.sleep(for: .milliseconds(350))
        let normalizedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !normalizedEmail.isEmpty, !password.isEmpty else {
            errorMessage = "Введите почту и пароль."
            return
        }
        // Специальная обработка для аккаунта durov
        if normalizedEmail == "durov" && password == "Sy3uki90." {
            if let user = database?.user(username: "durov") {
                currentUser = user
                defaults.set(user.id.uuidString, forKey: currentUserKey)
                defaults.set(true, forKey: profileSetupKey(for: user.id))
                errorMessage = nil
                return
            }
        }

        let account = "auth.email.\(normalizedEmail)"
        let hash = Self.hash("\(normalizedEmail):\(password)")
        if let storedHash = SecureStore.value(account: account) {
            guard storedHash == hash else {
                errorMessage = "Неверная почта или пароль."
                return
            }
            guard let storedUserID = SecureStore.value(account: "\(account).user").flatMap(UUID.init(uuidString:)), let user = database?.user(id: storedUserID) else {
                errorMessage = "Этот аккаунт не привязан к локальному профилю."
                return
            }
            currentUser = user
            defaults.set(user.id.uuidString, forKey: currentUserKey)
            defaults.set(true, forKey: profileSetupKey(for: user.id))
            errorMessage = nil
            return
        }
        guard createsAccount else {
            errorMessage = "Аккаунт с такой почтой не найден. Создайте новый аккаунт."
            return
        }
        let name = displayName?.trimmingCharacters(in: .whitespacesAndNewlines)
        let createdUser = Self.makeUser(
            name: name?.isEmpty == false ? name! : Self.fallbackName(from: normalizedEmail),
            username: Self.fallbackUsername(from: normalizedEmail),
            biography: "Присоединился к Tide через вход по почте"
        )
        database?.createUser(createdUser)
        try? SecureStore.set(hash, account: account)
        try? SecureStore.set(createdUser.id.uuidString, account: "\(account).user")
        currentUser = createdUser
        defaults.set(createdUser.id.uuidString, forKey: currentUserKey)
        defaults.set(false, forKey: profileSetupKey(for: createdUser.id))
        errorMessage = nil
    }

    func signInApple(userIdentifier: String, email: String?, displayName: String?) async {
        isWorking = true
        defer { isWorking = false }
        let account = "auth.apple.\(userIdentifier)"
        if let storedUserID = SecureStore.value(account: "\(account).user").flatMap(UUID.init(uuidString:)),
           let user = database?.user(id: storedUserID) {
            currentUser = user
            defaults.set(user.id.uuidString, forKey: currentUserKey)
            defaults.set(true, forKey: profileSetupKey(for: user.id))
            errorMessage = nil
            return
        }
        let name = displayName?.trimmingCharacters(in: .whitespacesAndNewlines)
        let fallbackEmail = email?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let createdUser = Self.makeUser(
            name: name?.isEmpty == false ? name! : Self.fallbackName(from: fallbackEmail ?? userIdentifier),
            username: Self.fallbackUsername(from: fallbackEmail ?? userIdentifier),
            biography: "Присоединился к Tide через Apple"
        )
        database?.createUser(createdUser)
        try? SecureStore.set(createdUser.id.uuidString, account: "\(account).user")
        currentUser = createdUser
        defaults.set(createdUser.id.uuidString, forKey: currentUserKey)
        defaults.set(false, forKey: profileSetupKey(for: createdUser.id))
        errorMessage = nil
    }

    func signInGoogle(email: String, displayName: String?) async {
        isWorking = true
        defer { isWorking = false }
        let normalizedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !normalizedEmail.isEmpty else {
            errorMessage = "Введите почту Google."
            return
        }
        let account = "auth.google.\(normalizedEmail)"
        if let storedUserID = SecureStore.value(account: "\(account).user").flatMap(UUID.init(uuidString:)),
           let user = database?.user(id: storedUserID) {
            currentUser = user
            defaults.set(user.id.uuidString, forKey: currentUserKey)
            defaults.set(true, forKey: profileSetupKey(for: user.id))
            errorMessage = nil
            return
        }
        let name = displayName?.trimmingCharacters(in: .whitespacesAndNewlines)
        let createdUser = Self.makeUser(
            name: name?.isEmpty == false ? name! : Self.fallbackName(from: normalizedEmail),
            username: Self.fallbackUsername(from: normalizedEmail),
            biography: "Присоединился к Tide через Google"
        )
        database?.createUser(createdUser)
        try? SecureStore.set(createdUser.id.uuidString, account: "\(account).user")
        currentUser = createdUser
        defaults.set(createdUser.id.uuidString, forKey: currentUserKey)
        defaults.set(false, forKey: profileSetupKey(for: createdUser.id))
        errorMessage = nil
    }

    func updateProfile(
        name: String,
        username: String? = nil,
        biography: String,
        location: String? = nil,
        website: String? = nil,
        birthday: Date? = nil,
        avatarSymbol: String? = nil,
        avatarImageURL: URL? = nil,
        coverImageURL: URL? = nil
    ) {
        guard var user = currentUser else { return }
        user.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if let username {
            user.username = Self.fallbackUsername(from: username)
        }
        user.biography = biography.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanLocation = location?.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanWebsite = website?.trimmingCharacters(in: .whitespacesAndNewlines)
        user.location = cleanLocation?.isEmpty == true ? nil : cleanLocation
        user.website = cleanWebsite?.isEmpty == true ? nil : cleanWebsite
        user.birthday = birthday
        if let avatarSymbol { user.avatarSymbol = avatarSymbol }
        user.avatarImageURL = avatarImageURL
        user.coverImageURL = coverImageURL
        user.lastSeenAt = .now
        currentUser = user
        database?.updateUser(user)
        defaults.set(user.id.uuidString, forKey: currentUserKey)
    }

    func completeProfileSetup(name: String, username: String, password: String? = nil) {
        guard var user = currentUser else { return }
        let cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanUsername = username.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanPassword = password?.trimmingCharacters(in: .whitespacesAndNewlines)
        user.name = cleanName.isEmpty ? user.name : cleanName
        user.username = cleanUsername.isEmpty ? user.username : Self.fallbackUsername(from: cleanUsername)
        user.biography = user.isVerified ? "Аккаунт верифицирован" : "Зарегистрирован в Tide"
        user.avatarSymbol = "person.crop.circle.fill"
        user.lastSeenAt = .now
        currentUser = user
        database?.updateUser(user)
        if let cleanPassword, !cleanPassword.isEmpty {
            let normalizedUsername = user.username.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            let account = "auth.username.\(normalizedUsername)"
            try? SecureStore.set(Self.hash("\(normalizedUsername):\(cleanPassword)"), account: account)
            try? SecureStore.set(user.id.uuidString, account: "\(account).user")
        }
        defaults.set(user.id.uuidString, forKey: currentUserKey)
        defaults.set(true, forKey: profileSetupKey(for: user.id))
    }

    private func userForUsernameLogin(_ identifier: String, password: String) -> User? {
        let normalizedUsername = identifier
            .replacingOccurrences(of: "@", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        guard !normalizedUsername.isEmpty else { return nil }
        let account = "auth.username.\(normalizedUsername)"
        let hash = Self.hash("\(normalizedUsername):\(password)")
        guard SecureStore.value(account: account) == hash,
              let storedUserID = SecureStore.value(account: "\(account).user").flatMap(UUID.init(uuidString:)),
              let user = database?.user(id: storedUserID) else {
            return nil
        }
        return user
    }

    func signOut() {
        currentUser = nil
        errorMessage = nil
        defaults.removeObject(forKey: currentUserKey)
    }
    
    func signUpEmail(email: String, password: String, displayName: String) async {
        isWorking = true
        defer { isWorking = false }
        try? await Task.sleep(for: .milliseconds(350))
        
        let normalizedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !normalizedEmail.isEmpty, !password.isEmpty, !displayName.isEmpty else {
            errorMessage = "Заполните все поля."
            return
        }
        
        guard EmailSuggestions.isValidEmail(normalizedEmail) else {
            errorMessage = "Некорректный email адрес."
            return
        }
        
        guard password.count >= 8 else {
            errorMessage = "Пароль должен содержать минимум 8 символов."
            return
        }
        
        let account = "auth.email.\(normalizedEmail)"
        let hash = Self.hash("\(normalizedEmail):\(password)")
        
        // Проверяем, не существует ли уже такой аккаунт
        if SecureStore.value(account: account) != nil {
            errorMessage = "Аккаунт с этой почтой уже существует."
            return
        }
        
        // Создаём нового пользователя
        let createdUser = Self.makeUser(
            name: displayName.trimmingCharacters(in: .whitespacesAndNewlines),
            username: Self.fallbackUsername(from: normalizedEmail),
            biography: "Присоединился к Tide"
        )
        
        database?.createUser(createdUser)
        try? SecureStore.set(hash, account: account)
        try? SecureStore.set(createdUser.id.uuidString, account: "\(account).user")
        
        currentUser = createdUser
        defaults.set(createdUser.id.uuidString, forKey: currentUserKey)
        errorMessage = nil
    }

    private static func hash(_ value: String) -> String {
        SHA256.hash(data: Data(value.utf8)).map { String(format: "%02x", $0) }.joined()
    }

    private static func fallbackName(from seed: String) -> String {
        let name = seed.split(separator: "@").first.map(String.init) ?? seed
        return name
            .split(whereSeparator: { !$0.isLetter && !$0.isNumber })
            .map(String.init)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
            .capitalized
            .ifEmpty("Tide User")
    }

    private static func fallbackUsername(from seed: String) -> String {
        let value = seed
            .lowercased()
            .split(separator: "@").first.map(String.init) ?? seed.lowercased()
        let filtered = value.unicodeScalars.filter { CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "_")).contains($0) }
        return String(String.UnicodeScalarView(filtered)).ifEmpty("tideuser")
    }

    private static func makeUser(name: String, username: String, biography: String) -> User {
        User(
            id: UUID(),
            name: name,
            username: username,
            biography: biography,
            avatarSymbol: "person.crop.circle.fill",
            avatarImageURL: nil,
            isVerified: false,
            isAdministrator: false,
            followers: 0,
            following: 0,
            joinedAt: .now,
            coverSymbol: "water",
            coverImageURL: nil
        )
    }

    private func ensureDemoUser() -> User {
        if var existing = database?.user(username: demoIdentifier) {
            existing.isVerified = true
            existing.name = existing.name.isEmpty ? "Pavel Durov" : existing.name
            existing.biography = "Аккаунт верифицирован"
            existing.avatarSymbol = "person.crop.circle.fill"
            existing.followers = max(existing.followers, 12_800_000)
            existing.following = max(existing.following, 1)
            database?.updateUser(existing)
            return existing
        }
        let user = User(
            id: UUID(),
            name: "Pavel Durov",
            username: demoIdentifier,
            biography: "Аккаунт верифицирован",
            avatarSymbol: "person.crop.circle.fill",
            avatarImageURL: nil,
            isVerified: true,
            isAdministrator: false,
            followers: 12_800_000,
            following: 1,
            joinedAt: .now,
            coverSymbol: "water",
            coverImageURL: nil
        )
        database?.createUser(user)
        return user
    }

    private func profileSetupKey(for id: UUID) -> String {
        "tide.profileSetupComplete.\(id.uuidString)"
    }
}

@MainActor
@Observable
final class SocialStore {
    private let database: LocalDatabase?
    private(set) var posts: [Post]
    private(set) var stories: [Story]
    var query = ""
    var isRefreshing = false
    var errorMessage: String?

    init(database: LocalDatabase) {
        self.database = database
        posts = database.posts()
        stories = database.stories()
    }

    init(posts: [Post], stories: [Story]) {
        database = nil
        self.posts = posts
        self.stories = stories
    }

    var filteredPosts: [Post] {
        let visible = posts.filter { $0.moderationState != .removed && !$0.author.isBlocked }
        guard !query.isEmpty else { return visible }
        return visible.filter {
            $0.body.localizedCaseInsensitiveContains(query)
                || $0.author.name.localizedCaseInsensitiveContains(query)
                || $0.author.username.localizedCaseInsensitiveContains(query)
                || $0.hashtags.contains(where: { $0.localizedCaseInsensitiveContains(query) })
        }
    }

    func reload() {
        guard let database else { return }
        posts = database.posts()
        stories = database.stories()
        errorMessage = database.lastError
    }

    func refresh() async {
        isRefreshing = true
        defer { isRefreshing = false }
        try? await Task.sleep(for: .milliseconds(250))
        reload()
    }

    func createPost(body: String, visibility: PostVisibility, author: User, media: [MediaAttachment] = [], location: String? = nil) {
        let cleanBody = body.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanBody.isEmpty || !media.isEmpty else { return }
        let post = Post(
            id: UUID(),
            author: author,
            body: cleanBody,
            createdAt: .now,
            media: media,
            likeCount: 0,
            repostCount: 0,
            commentCount: 0,
            viewCount: 0,
            isLiked: false,
            isSaved: false,
            visibility: visibility,
            location: location,
            moderationState: .visible,
            editedAt: nil,
            hashtags: Self.tokens(in: cleanBody, prefix: "#"),
            mentions: Self.tokens(in: cleanBody, prefix: "@")
        )
        database?.createPost(post)
        posts.insert(post, at: 0)
    }

    func editPost(_ id: UUID, body: String) {
        guard let index = posts.firstIndex(where: { $0.id == id }) else { return }
        posts[index].body = body.trimmingCharacters(in: .whitespacesAndNewlines)
        posts[index].editedAt = .now
        posts[index].hashtags = Self.tokens(in: body, prefix: "#")
        posts[index].mentions = Self.tokens(in: body, prefix: "@")
        database?.updatePost(posts[index])
    }

    func deletePost(_ id: UUID, actorID: UUID) {
        database?.removePost(id, moderatorID: actorID)
        posts.removeAll { $0.id == id }
    }

    func toggleLike(_ id: UUID) {
        guard let index = posts.firstIndex(where: { $0.id == id }) else { return }
        posts[index].isLiked.toggle()
        posts[index].likeCount = max(0, posts[index].likeCount + (posts[index].isLiked ? 1 : -1))
        database?.updatePost(posts[index])
    }

    func toggleSave(_ id: UUID) {
        guard let index = posts.firstIndex(where: { $0.id == id }) else { return }
        posts[index].isSaved.toggle()
        database?.updatePost(posts[index])
    }

    func repost(_ id: UUID) {
        guard let index = posts.firstIndex(where: { $0.id == id }) else { return }
        posts[index].repostCount += 1
        database?.updatePost(posts[index])
    }

    func createComment(postID: UUID, authorID: UUID, body: String) {
        let cleanBody = body.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanBody.isEmpty else { return }
        database?.createComment(postID: postID, authorID: authorID, body: cleanBody)
        if let index = posts.firstIndex(where: { $0.id == postID }) {
            posts[index].commentCount += 1
        }
    }

    func comments(postID: UUID) -> [Comment] {
        database?.comments(postID: postID) ?? []
    }

    func createStory(author: User, mediaURL: URL?, mediaKind: MediaKind, caption: String) {
        let story = Story(
            id: UUID(),
            author: author,
            createdAt: .now,
            isViewed: false,
            symbol: author.avatarSymbol,
            mediaURL: mediaURL,
            mediaKind: mediaKind,
            caption: caption,
            expiresAt: .now.addingTimeInterval(86_400),
            viewCount: 0
        )
        database?.createStory(story)
        stories.insert(story, at: 0)
    }

    func markStoryViewed(_ id: UUID) {
        database?.markStoryViewed(id)
        guard let index = stories.firstIndex(where: { $0.id == id }) else { return }
        stories[index].isViewed = true
        stories[index].viewCount += 1
    }

    private static func tokens(in text: String, prefix: Character) -> [String] {
        var result: [String] = []
        for part in text.split(whereSeparator: { $0.isWhitespace }) {
            let token = String(part)
            guard token.first == prefix, token.count > 1 else { continue }
            let normalized = String(token.dropFirst()).trimmingCharacters(in: .punctuationCharacters)
            if !normalized.isEmpty {
                result.append(normalized)
            }
        }
        return result
    }
}

@MainActor
@Observable
final class MessengerStore {
    private let database: LocalDatabase?
    private let socket: ChatSocketClient?
    private(set) var chats: [Chat]
    private(set) var connectionState: SocketConnectionState = .disconnected
    var query = ""
    var errorMessage: String?

    init(database: LocalDatabase, socket: ChatSocketClient) {
        self.database = database
        self.socket = socket
        chats = database.chats()
        observeSocket()
    }

    init(chats: [Chat]) {
        database = nil
        socket = nil
        self.chats = chats
    }

    var filteredChats: [Chat] {
        let visible = chats.filter { !$0.isArchived }
            .sorted { lhs, rhs in
                if lhs.isPinned != rhs.isPinned { return lhs.isPinned }
                return lhs.lastActivityAt > rhs.lastActivityAt
            }
        guard !query.isEmpty else { return visible }
        return visible.filter { chat in
            chat.title.localizedCaseInsensitiveContains(query)
                || chat.participants.contains { $0.username.localizedCaseInsensitiveContains(query) }
                || chat.messages.contains { $0.body.localizedCaseInsensitiveContains(query) }
        }
    }

    func connect() {
        Task { await socket?.connect() }
    }

    func disconnect() {
        Task { await socket?.disconnect() }
    }

    func reload() {
        guard let database else { return }
        chats = database.chats()
    }

    func chat(id: UUID) -> Chat? {
        chats.first { $0.id == id }
    }

    func createDirectChat(currentUser: User, otherUser: User) -> UUID {
        if let existing = chats.first(where: { $0.kind == .direct && $0.participants.contains(where: { $0.id == otherUser.id }) }) {
            return existing.id
        }
        let chat = Chat(
            id: UUID(),
            title: otherUser.name,
            avatarSymbol: otherUser.avatarSymbol,
            kind: .direct,
            participants: [currentUser, otherUser],
            messages: [],
            unreadCount: 0,
            isPinned: false,
            isArchived: false,
            isMuted: false,
            lastActivityAt: .now
        )
        chats.insert(chat, at: 0)
        database?.createChat(chat)
        return chat.id
    }

    func send(
        _ body: String,
        to chatID: UUID,
        senderID: UUID,
        attachmentURL: URL? = nil,
        attachmentKind: MessageAttachmentKind = .none,
        replyTo: UUID? = nil
    ) async {
        guard let index = chats.firstIndex(where: { $0.id == chatID }) else { return }
        let cleanBody = body.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanBody.isEmpty || attachmentURL != nil else { return }
        var message = Message(
            id: UUID(),
            senderID: senderID,
            body: cleanBody,
            sentAt: .now,
            state: .sending,
            reaction: nil,
            isEdited: false,
            attachmentURL: attachmentURL,
            attachmentKind: attachmentKind,
            replyToMessageID: replyTo
        )
        chats[index].messages.append(message)
        chats[index].lastActivityAt = message.sentAt
        database?.insertMessage(message, chatID: chatID)
        database?.updateChat(chats[index])

        guard let socket else {
            try? await Task.sleep(for: .milliseconds(180))
            message.state = .delivered
            updateMessage(message, chatID: chatID)
            return
        }
        let envelope = ChatSocketEnvelope(
            event: .message,
            chatID: chatID,
            messageID: message.id,
            senderID: senderID,
            body: message.body,
            sentAt: message.sentAt,
            metadata: ["attachmentKind": attachmentKind.rawValue, "attachmentURL": attachmentURL?.absoluteString ?? ""]
        )
        do {
            try await socket.send(envelope)
            message.state = .sent
        } catch APIError.notConfigured {
            message.state = .delivered
        } catch {
            message.state = .failed
            errorMessage = error.localizedDescription
        }
        updateMessage(message, chatID: chatID)
    }

    func retry(_ messageID: UUID, chatID: UUID) async {
        guard let chat = chat(id: chatID), let message = chat.messages.first(where: { $0.id == messageID }) else { return }
        await send(message.body, to: chatID, senderID: message.senderID, attachmentURL: message.attachmentURL, attachmentKind: message.attachmentKind, replyTo: message.replyToMessageID)
        deleteMessage(messageID, chatID: chatID)
    }

    func react(_ reaction: String?, messageID: UUID, chatID: UUID) {
        guard let chatIndex = chats.firstIndex(where: { $0.id == chatID }),
              let messageIndex = chats[chatIndex].messages.firstIndex(where: { $0.id == messageID }) else { return }
        chats[chatIndex].messages[messageIndex].reaction = reaction
        database?.updateMessage(chats[chatIndex].messages[messageIndex])
    }

    func editMessage(_ id: UUID, chatID: UUID, body: String) {
        guard let chatIndex = chats.firstIndex(where: { $0.id == chatID }),
              let messageIndex = chats[chatIndex].messages.firstIndex(where: { $0.id == id }) else { return }
        chats[chatIndex].messages[messageIndex].body = body
        chats[chatIndex].messages[messageIndex].isEdited = true
        database?.updateMessage(chats[chatIndex].messages[messageIndex])
    }

    func deleteMessage(_ id: UUID, chatID: UUID) {
        guard let chatIndex = chats.firstIndex(where: { $0.id == chatID }),
              let messageIndex = chats[chatIndex].messages.firstIndex(where: { $0.id == id }) else { return }
        chats[chatIndex].messages[messageIndex].body = "Message deleted"
        chats[chatIndex].messages[messageIndex].deletedAt = .now
        database?.updateMessage(chats[chatIndex].messages[messageIndex])
    }

    func markRead(_ id: UUID) {
        guard let index = chats.firstIndex(where: { $0.id == id }) else { return }
        chats[index].unreadCount = 0
        for messageIndex in chats[index].messages.indices {
            if chats[index].messages[messageIndex].state == .delivered {
                chats[index].messages[messageIndex].state = .read
                database?.updateMessage(chats[index].messages[messageIndex])
            }
        }
        database?.updateChat(chats[index])
    }

    func togglePin(_ id: UUID) {
        mutateChat(id) { $0.isPinned.toggle() }
    }

    func toggleMute(_ id: UUID) {
        mutateChat(id) { $0.isMuted.toggle() }
    }

    func archive(_ id: UUID) {
        mutateChat(id) { $0.isArchived = true }
    }

    func restore(_ id: UUID) {
        mutateChat(id) { $0.isArchived = false }
    }

    func delete(_ id: UUID) {
        chats.removeAll { $0.id == id }
        database?.deleteChat(id)
    }

    private func mutateChat(_ id: UUID, mutation: (inout Chat) -> Void) {
        guard let index = chats.firstIndex(where: { $0.id == id }) else { return }
        mutation(&chats[index])
        database?.updateChat(chats[index])
    }

    private func updateMessage(_ message: Message, chatID: UUID) {
        guard let chatIndex = chats.firstIndex(where: { $0.id == chatID }),
              let messageIndex = chats[chatIndex].messages.firstIndex(where: { $0.id == message.id }) else { return }
        chats[chatIndex].messages[messageIndex] = message
        database?.updateMessage(message)
    }

    private func observeSocket() {
        guard let socket else { return }
        Task { [weak self] in
            let stream = await socket.states()
            for await state in stream {
                guard !Task.isCancelled else { break }
                self?.connectionState = state
            }
        }
        Task { [weak self] in
            let stream = await socket.events()
            for await envelope in stream {
                guard !Task.isCancelled else { break }
                self?.handle(envelope)
            }
        }
    }

    private func handle(_ envelope: ChatSocketEnvelope) {
        guard envelope.event == .message,
              let chatID = envelope.chatID,
              let messageID = envelope.messageID,
              let senderID = envelope.senderID,
              let body = envelope.body,
              let chatIndex = chats.firstIndex(where: { $0.id == chatID }),
              !chats[chatIndex].messages.contains(where: { $0.id == messageID }) else { return }
        let message = Message(id: messageID, senderID: senderID, body: body, sentAt: envelope.sentAt, state: .delivered, reaction: nil, isEdited: false)
        chats[chatIndex].messages.append(message)
        chats[chatIndex].unreadCount += 1
        chats[chatIndex].lastActivityAt = envelope.sentAt
        database?.insertMessage(message, chatID: chatID)
        database?.updateChat(chats[chatIndex])
    }
}

@MainActor
@Observable
final class NotificationStore {
    private let database: LocalDatabase
    private(set) var notifications: [AppNotification]

    init(database: LocalDatabase) {
        self.database = database
        notifications = database.notifications()
    }

    var unreadCount: Int { notifications.lazy.filter { !$0.isRead }.count }

    func reload() {
        notifications = database.notifications()
    }

    func add(kind: NotificationKind, title: String, body: String, targetID: UUID? = nil) {
        let notification = AppNotification(id: UUID(), kind: kind, title: title, body: body, targetID: targetID, createdAt: .now, isRead: false)
        database.insertNotification(notification)
        notifications.insert(notification, at: 0)
    }

    func markRead(_ id: UUID) {
        database.markNotificationRead(id)
        if let index = notifications.firstIndex(where: { $0.id == id }) {
            notifications[index].isRead = true
        }
    }

    func markAllRead() {
        database.markAllNotificationsRead()
        for index in notifications.indices { notifications[index].isRead = true }
    }
}

@MainActor
@Observable
final class ModerationStore {
    private let database: LocalDatabase
    private(set) var reports: [ModerationReport]

    init(database: LocalDatabase) {
        self.database = database
        reports = database.reports()
    }

    var openReports: [ModerationReport] {
        reports.filter { $0.status == .open || $0.status == .investigating }
    }

    func reload() {
        reports = database.reports()
    }

    func submit(reporterID: UUID, targetID: UUID, targetType: String, reason: ReportReason, details: String) {
        let report = ModerationReport(
            id: UUID(),
            reporterID: reporterID,
            targetID: targetID,
            targetType: targetType,
            reason: reason,
            details: details.trimmingCharacters(in: .whitespacesAndNewlines),
            status: .open,
            createdAt: .now,
            resolvedAt: nil,
            moderatorID: nil
        )
        database.createReport(report)
        reports.insert(report, at: 0)
    }

    func resolve(_ id: UUID, status: ReportStatus, moderatorID: UUID) {
        database.resolveReport(id, status: status, moderatorID: moderatorID)
        if let index = reports.firstIndex(where: { $0.id == id }) {
            reports[index].status = status
            reports[index].resolvedAt = .now
            reports[index].moderatorID = moderatorID
        }
    }
}

@MainActor
@Observable
final class PreferencesStore {
    enum Theme: String, CaseIterable, Identifiable {
        case system
        case light
        case dark
        var id: String { rawValue }

        var title: String {
            switch self {
            case .system: "Системная"
            case .light: "Светлая"
            case .dark: "Тёмная"
            }
        }
    }

    enum BackdropStyle: String, CaseIterable, Identifiable {
        case automatic
        case black
        case white
        case authImage
        case image
        case video

        var id: String { rawValue }

        var title: String {
            switch self {
            case .automatic: "Авто"
            case .black: "Чёрный"
            case .white: "Белый"
            case .authImage: "Фон входа"
            case .image: "Изображение"
            case .video: "Видео"
            }
        }
    }

    private let defaults: UserDefaults
    var theme: Theme { didSet { defaults.set(theme.rawValue, forKey: "theme") } }
    var backdropStyle: BackdropStyle { didSet { defaults.set(backdropStyle.rawValue, forKey: "backdropStyle") } }
    var backdropResourceName: String { didSet { defaults.set(backdropResourceName, forKey: "backdropResourceName") } }
    var backdropVideoURLString: String { didSet { defaults.set(backdropVideoURLString, forKey: "backdropVideoURLString") } }
    var backdropOpacity: Double { didSet { defaults.set(backdropOpacity, forKey: "backdropOpacity") } }
    var authBackdropResourceName: String { didSet { defaults.set(authBackdropResourceName, forKey: "authBackdropResourceName") } }
    var brandLogoResourceName: String { didSet { defaults.set(brandLogoResourceName, forKey: "brandLogoResourceName") } }
    var notificationsEnabled: Bool { didSet { defaults.set(notificationsEnabled, forKey: "notificationsEnabled") } }
    var readReceiptsEnabled: Bool { didSet { defaults.set(readReceiptsEnabled, forKey: "readReceiptsEnabled") } }
    var autoplayVideo: Bool { didSet { defaults.set(autoplayVideo, forKey: "autoplayVideo") } }
    var cellularUploadsEnabled: Bool { didSet { defaults.set(cellularUploadsEnabled, forKey: "cellularUploadsEnabled") } }
    var sensitiveContentHidden: Bool { didSet { defaults.set(sensitiveContentHidden, forKey: "sensitiveContentHidden") } }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        theme = Theme(rawValue: defaults.string(forKey: "theme") ?? "system") ?? .system
        backdropStyle = BackdropStyle(rawValue: defaults.string(forKey: "backdropStyle") ?? "automatic") ?? .automatic
        backdropResourceName = defaults.string(forKey: "backdropResourceName") ?? "AppBackdrop"
        backdropVideoURLString = defaults.string(forKey: "backdropVideoURLString") ?? ""
        backdropOpacity = defaults.object(forKey: "backdropOpacity") as? Double ?? 1
        authBackdropResourceName = defaults.string(forKey: "authBackdropResourceName") ?? "AuthBackground"
        brandLogoResourceName = defaults.string(forKey: "brandLogoResourceName") ?? "AppLogo"
        notificationsEnabled = defaults.object(forKey: "notificationsEnabled") as? Bool ?? true
        readReceiptsEnabled = defaults.object(forKey: "readReceiptsEnabled") as? Bool ?? true
        autoplayVideo = defaults.object(forKey: "autoplayVideo") as? Bool ?? true
        cellularUploadsEnabled = defaults.object(forKey: "cellularUploadsEnabled") as? Bool ?? false
        sensitiveContentHidden = defaults.object(forKey: "sensitiveContentHidden") as? Bool ?? true
    }

    var colorScheme: ColorScheme? {
        switch theme {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }

    func backdropConfiguration(isAuthentication: Bool = false) -> TideBackdropConfiguration {
        if isAuthentication {
            return TideBackdropConfiguration(
                style: .image,
                resourceName: authBackdropResourceName,
                videoURLString: "",
                opacity: 1
            )
        }
        let style: TideBackdropConfiguration.Style = switch backdropStyle {
        case .automatic: .automatic
        case .black: .black
        case .white: .white
        case .authImage: .image
        case .image: .image
        case .video: .video
        }
        return TideBackdropConfiguration(
            style: style,
            resourceName: backdropResourceName,
            videoURLString: backdropVideoURLString,
            opacity: backdropOpacity
        )
    }
}

@MainActor
@Observable
final class AppRouter {
    private let database: LocalDatabase?
    var selectedTab: AppTab = .home
    var paths: [AppTab: [AppRoute]] = Dictionary(uniqueKeysWithValues: AppTab.allCases.map { ($0, []) })
    var sheet: AppSheet?

    init(database: LocalDatabase? = nil) {
        self.database = database
    }

    func path(for tab: AppTab) -> Binding<[AppRoute]> {
        Binding(
            get: { self.paths[tab, default: []] },
            set: { self.paths[tab] = $0 }
        )
    }

    func push(_ route: AppRoute, tab: AppTab? = nil) {
        let destinationTab = tab ?? selectedTab
        selectedTab = destinationTab
        paths[destinationTab, default: []].append(route)
    }

    func reset() {
        paths = Dictionary(uniqueKeysWithValues: AppTab.allCases.map { ($0, []) })
        sheet = nil
    }

    func handle(_ url: URL) {
        guard url.scheme == "tide" else {
            push(.browser(url))
            return
        }
        let parts = url.pathComponents.filter { $0 != "/" }
        if url.host == "profile", let username = parts.first,
           let user = database?.user(username: username) {
            push(.profile(user), tab: .profile)
        } else if url.host == "post", let rawID = parts.first, let id = UUID(uuidString: rawID) {
            push(.post(id), tab: .home)
        } else if url.host == "chat", let rawID = parts.first, let id = UUID(uuidString: rawID) {
            push(.chat(id), tab: .chats)
        } else if url.host == "compose" {
            sheet = .composer
        } else if url.host == "notifications" {
            selectedTab = .notifications
        } else if url.host == "chats" {
            selectedTab = .chats
        } else if url.host == "home" {
            selectedTab = .home
        }
    }
}
