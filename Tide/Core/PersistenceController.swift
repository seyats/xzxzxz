import Foundation
import Observation
import SwiftData

@MainActor
@Observable
final class LocalDatabase {
    let container: ModelContainer
    let context: ModelContext
    private(set) var lastError: String?

    init(inMemory: Bool = false) {
        let schema = Schema([
            UserRecord.self,
            PostRecord.self,
            MediaRecord.self,
            StoryRecord.self,
            ChatRecord.self,
            MessageRecord.self,
            CommentRecord.self,
            ModerationReportRecord.self,
            NotificationRecord.self,
            FollowRecord.self,
            BlockRecord.self,
            DraftRecord.self,
            DeviceTokenRecord.self,
            DeviceSessionRecord.self,
            AuditEventRecord.self,
            BotRecord.self
        ])
        let configuration = ModelConfiguration(
            "Tide",
            schema: schema,
            isStoredInMemoryOnly: inMemory,
            allowsSave: true
        )
        do {
            container = try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            fatalError("Unable to create Tide database: \(error.localizedDescription)")
        }
        context = ModelContext(container)
        context.autosaveEnabled = true
        bootstrapIfNeeded()
        purgeLegacyDemoDataIfNeeded()
        purgePostMediaIfNeeded()
        purgePostsIfNeeded()
    }

    func bootstrapIfNeeded() {
        guard fetch(UserRecord.self).isEmpty,
              fetch(PostRecord.self).isEmpty,
              fetch(ChatRecord.self).isEmpty,
              fetch(StoryRecord.self).isEmpty else { return }

        DemoData.users.forEach(createUser)
        DemoData.posts.forEach(createPost)
        DemoData.stories.forEach(createStory)
        DemoData.chats.forEach(createChat)
    }

    func purgeLegacyDemoDataIfNeeded() {
        let defaults = UserDefaults.standard
        guard !defaults.bool(forKey: "tide.purgedLegacyDemoData") else { return }
        do {
            let legacyUsers = fetch(UserRecord.self).contains { record in
                record.username.caseInsensitiveCompare("TideSupport") == .orderedSame
            }
            let legacyPosts = try context.fetchCount(FetchDescriptor<PostRecord>()) > 0
            let legacyChats = try context.fetchCount(FetchDescriptor<ChatRecord>()) > 0
            let legacyStories = try context.fetchCount(FetchDescriptor<StoryRecord>()) > 0
            if legacyUsers || legacyPosts || legacyChats || legacyStories {
                deleteAllContent()
                defaults.set(true, forKey: "tide.purgedLegacyDemoData")
            }
        } catch {
            lastError = error.localizedDescription
        }
    }

    func purgePostMediaIfNeeded() {
        let defaults = UserDefaults.standard
        guard !defaults.bool(forKey: "tide.purgedPostMedia") else { return }
        let postIDs = Set(fetch(PostRecord.self).map(\.id))
        fetch(MediaRecord.self)
            .filter { postIDs.contains($0.ownerID) }
            .forEach(context.delete)
        fetch(DraftRecord.self)
            .filter { $0.kind == "post" && !$0.mediaURLStrings.isEmpty }
            .forEach { $0.mediaURLStrings = [] }
        do {
            try save()
            defaults.set(true, forKey: "tide.purgedPostMedia")
        } catch {
            lastError = error.localizedDescription
        }
    }

    func purgePostsIfNeeded() {
        let defaults = UserDefaults.standard
        guard !defaults.bool(forKey: "tide.purgedPosts.v2") else { return }
        let postIDs = Set(fetch(PostRecord.self).map(\.id))
        guard !postIDs.isEmpty else {
            defaults.set(true, forKey: "tide.purgedPosts.v2")
            return
        }
        fetch(CommentRecord.self)
            .filter { postIDs.contains($0.postID) }
            .forEach(context.delete)
        fetch(MediaRecord.self)
            .filter { postIDs.contains($0.ownerID) }
            .forEach(context.delete)
        fetch(PostRecord.self).forEach(context.delete)
        fetch(DraftRecord.self)
            .filter { $0.kind == "post" }
            .forEach(context.delete)
        do {
            try save()
            defaults.set(true, forKey: "tide.purgedPosts.v2")
        } catch {
            lastError = error.localizedDescription
        }
    }

    func save() throws {
        if context.hasChanges {
            try context.save()
        }
        lastError = nil
    }

    func deleteAllContent() {
        fetch(MessageRecord.self).forEach(context.delete)
        fetch(ChatRecord.self).forEach(context.delete)
        fetch(PostRecord.self).forEach(context.delete)
        fetch(MediaRecord.self).forEach(context.delete)
        fetch(StoryRecord.self).forEach(context.delete)
        fetch(CommentRecord.self).forEach(context.delete)
        fetch(ModerationReportRecord.self).forEach(context.delete)
        fetch(NotificationRecord.self).forEach(context.delete)
        fetch(FollowRecord.self).forEach(context.delete)
        fetch(BlockRecord.self).forEach(context.delete)
        fetch(DraftRecord.self).forEach(context.delete)
        fetch(DeviceTokenRecord.self).forEach(context.delete)
        fetch(DeviceSessionRecord.self).forEach(context.delete)
        fetch(AuditEventRecord.self).forEach(context.delete)
        fetch(BotRecord.self).forEach(context.delete)
        fetch(UserRecord.self).forEach(context.delete)
        trySave()
    }

    func users() -> [User] {
        fetch(UserRecord.self, sortedBy: [SortDescriptor(\.name)]).map(\.domain)
    }

    func user(id: UUID) -> User? {
        fetch(UserRecord.self).first(where: { $0.id == id })?.domain
    }

    func user(username: String) -> User? {
        fetch(UserRecord.self).first { $0.username.localizedCaseInsensitiveCompare(username) == .orderedSame }?.domain
    }

    func createUser(_ user: User) {
        context.insert(UserRecord(user: user))
        trySave()
    }

    func updateUser(_ user: User) {
        if let record = fetch(UserRecord.self).first(where: { $0.id == user.id }) {
            record.name = user.name
            record.username = user.username
            record.biography = user.biography
            record.avatarSymbol = user.avatarSymbol
            record.avatarImageURLString = user.avatarImageURL?.absoluteString
            record.coverSymbol = user.coverSymbol
            record.location = user.location
            record.website = user.website
            record.birthday = user.birthday
            record.isVerified = user.isVerified
            record.isAdministrator = user.isAdministrator
            record.followers = user.followers
            record.following = user.following
            record.lastSeenAt = user.lastSeenAt
            record.statusRawValue = user.status.rawValue
            record.isFollowing = user.isFollowing
            record.isBlocked = user.isBlocked
        } else {
            context.insert(UserRecord(user: user))
        }
        trySave()
    }

    func posts(includeRemoved: Bool = false) -> [Post] {
        let userIndex = Dictionary(uniqueKeysWithValues: users().map { ($0.id, $0) })
        let mediaIndex = Dictionary(grouping: fetch(MediaRecord.self), by: \.ownerID)
        return fetch(PostRecord.self, sortedBy: [SortDescriptor(\.createdAt, order: .reverse)])
            .filter { includeRemoved || $0.moderationStateRawValue != ModerationState.removed.rawValue }
            .compactMap { record in
                guard let author = userIndex[record.authorID], !author.isBlocked else { return nil }
                let media = (mediaIndex[record.id] ?? []).sorted { $0.sortIndex < $1.sortIndex }.map(\.domain)
                return Post(
                    id: record.id,
                    author: author,
                    body: record.body,
                    createdAt: record.createdAt,
                    media: media,
                    likeCount: record.likeCount,
                    repostCount: record.repostCount,
                    commentCount: record.commentCount,
                    viewCount: record.viewCount,
                    isLiked: record.isLiked,
                    isSaved: record.isSaved,
                    visibility: PostVisibility(rawValue: record.visibilityRawValue) ?? .everyone,
                    location: record.location,
                    moderationState: ModerationState(rawValue: record.moderationStateRawValue) ?? .visible,
                    editedAt: record.editedAt,
                    hashtags: record.hashtags,
                    mentions: record.mentions
                )
            }
    }

    func createPost(_ post: Post) {
        context.insert(PostRecord(post: post))
        post.media.enumerated().forEach { index, media in
            context.insert(MediaRecord(
                id: media.id,
                ownerID: post.id,
                kind: media.kind,
                localURL: media.url,
                aspectRatio: media.aspectRatio,
                sortIndex: index
            ))
        }
        trySave()
    }

    func updatePost(_ post: Post) {
        guard let record = fetch(PostRecord.self).first(where: { $0.id == post.id }) else {
            createPost(post)
            return
        }
        record.body = post.body
        record.likeCount = post.likeCount
        record.repostCount = post.repostCount
        record.commentCount = post.commentCount
        record.viewCount = post.viewCount
        record.isLiked = post.isLiked
        record.isSaved = post.isSaved
        record.visibilityRawValue = post.visibility.rawValue
        record.location = post.location
        record.moderationStateRawValue = post.moderationState.rawValue
        record.editedAt = post.editedAt
        record.hashtags = post.hashtags
        record.mentions = post.mentions
        trySave()
    }

    func removePost(_ id: UUID, moderatorID: UUID) {
        guard let record = fetch(PostRecord.self).first(where: { $0.id == id }) else { return }
        record.moderationStateRawValue = ModerationState.removed.rawValue
        context.insert(AuditEventRecord(actorID: moderatorID, action: "post.remove", targetID: id))
        trySave()
    }

    func stories() -> [Story] {
        let now = Date.now
        let userIndex = Dictionary(uniqueKeysWithValues: users().map { ($0.id, $0) })
        return fetch(StoryRecord.self, sortedBy: [SortDescriptor(\.createdAt, order: .reverse)])
            .filter { $0.expiresAt > now }
            .compactMap { record in
                guard let author = userIndex[record.authorID] else { return nil }
                return Story(
                    id: record.id,
                    author: author,
                    createdAt: record.createdAt,
                    isViewed: record.isViewed,
                    symbol: record.symbol,
                    mediaURL: record.mediaURLString.flatMap(URL.init(string:)),
                    mediaKind: MediaKind(rawValue: record.mediaKindRawValue) ?? .photo,
                    caption: record.caption,
                    expiresAt: record.expiresAt,
                    viewCount: record.viewCount
                )
            }
    }

    func createStory(_ story: Story) {
        context.insert(StoryRecord(story: story))
        trySave()
    }

    func markStoryViewed(_ id: UUID) {
        guard let record = fetch(StoryRecord.self).first(where: { $0.id == id }) else { return }
        guard !record.isViewed else { return }
        record.isViewed = true
        record.viewCount += 1
        trySave()
    }

    func chats(participantID: UUID? = nil) -> [Chat] {
        let userIndex = Dictionary(uniqueKeysWithValues: users().map { ($0.id, $0) })
        let messagesIndex = Dictionary(grouping: fetch(MessageRecord.self), by: \.chatID)
        return fetch(ChatRecord.self, sortedBy: [SortDescriptor(\.lastActivityAt, order: .reverse)])
            .filter { record in
                guard let participantID else { return true }
                return record.participantIDs.contains(participantID)
            }
            .map { record in
            let participants = record.participantIDs.compactMap { userIndex[$0] }
            let messages = (messagesIndex[record.id] ?? []).sorted { $0.sentAt < $1.sentAt }.map(\.domain)
            return Chat(
                id: record.id,
                title: record.title,
                avatarSymbol: record.avatarSymbol,
                kind: ChatKind(rawValue: record.kindRawValue) ?? .direct,
                participants: participants,
                messages: messages,
                unreadCount: record.unreadCount,
                isPinned: record.isPinned,
                isArchived: record.isArchived,
                isMuted: record.isMuted,
                lastActivityAt: record.lastActivityAt
            )
        }
    }

    func createChat(_ chat: Chat) {
        context.insert(ChatRecord(chat: chat))
        chat.messages.forEach { context.insert(MessageRecord(message: $0, chatID: chat.id)) }
        trySave()
    }

    func insertMessage(_ message: Message, chatID: UUID) {
        context.insert(MessageRecord(message: message, chatID: chatID))
        if let chat = fetch(ChatRecord.self).first(where: { $0.id == chatID }) {
            chat.lastActivityAt = message.sentAt
        }
        trySave()
    }

    func updateMessage(_ message: Message) {
        guard let record = fetch(MessageRecord.self).first(where: { $0.id == message.id }) else { return }
        record.body = message.body
        record.stateRawValue = message.state.rawValue
        record.reaction = message.reaction
        record.isEdited = message.isEdited
        record.attachmentURLString = message.attachmentURL?.absoluteString
        record.attachmentKindRawValue = message.attachmentKind.rawValue
        record.replyToMessageID = message.replyToMessageID
        record.forwardedFromMessageID = message.forwardedFromMessageID
        record.deletedAt = message.deletedAt
        trySave()
    }

    func updateChat(_ chat: Chat) {
        guard let record = fetch(ChatRecord.self).first(where: { $0.id == chat.id }) else {
            createChat(chat)
            return
        }
        record.title = chat.title
        record.unreadCount = chat.unreadCount
        record.isPinned = chat.isPinned
        record.isArchived = chat.isArchived
        record.isMuted = chat.isMuted
        record.lastActivityAt = chat.lastActivityAt
        trySave()
    }

    func deleteChat(_ id: UUID) {
        fetch(MessageRecord.self).filter { $0.chatID == id }.forEach(context.delete)
        if let chat = fetch(ChatRecord.self).first(where: { $0.id == id }) {
            context.delete(chat)
        }
        trySave()
    }

    func comments(postID: UUID) -> [Comment] {
        let userIndex = Dictionary(uniqueKeysWithValues: users().map { ($0.id, $0) })
        return fetch(CommentRecord.self, sortedBy: [SortDescriptor(\.createdAt)])
            .filter { $0.postID == postID }
            .compactMap { record in
                guard let author = userIndex[record.authorID] else { return nil }
                return Comment(id: record.id, postID: record.postID, author: author, body: record.body, createdAt: record.createdAt, likeCount: record.likeCount, isLiked: record.isLiked)
            }
    }

    func createComment(postID: UUID, authorID: UUID, body: String) {
        context.insert(CommentRecord(postID: postID, authorID: authorID, body: body))
        if let post = fetch(PostRecord.self).first(where: { $0.id == postID }) {
            post.commentCount += 1
        }
        trySave()
    }

    func deviceSessions(userID: UUID) -> [DeviceSession] {
        fetch(DeviceSessionRecord.self, sortedBy: [SortDescriptor(\.lastSeenAt, order: .reverse)])
            .filter { $0.userID == userID }
            .map(\.domain)
    }

    func upsertDeviceSession(_ session: DeviceSession) {
        fetch(DeviceSessionRecord.self)
            .filter { $0.userID == session.userID && $0.isCurrent && $0.id != session.id }
            .forEach { $0.isCurrent = false }
        if let record = fetch(DeviceSessionRecord.self).first(where: { $0.id == session.id }) {
            record.userID = session.userID
            record.deviceName = session.deviceName
            record.systemVersion = session.systemVersion
            record.appVersion = session.appVersion
            record.lastSeenAt = session.lastSeenAt
            record.isCurrent = session.isCurrent
        } else {
            context.insert(DeviceSessionRecord(session: session))
        }
        trySave()
    }

    func deleteDeviceSession(_ id: UUID) {
        guard let record = fetch(DeviceSessionRecord.self).first(where: { $0.id == id && !$0.isCurrent }) else { return }
        context.delete(record)
        trySave()
    }

    func protectedLocalMediaURLs() -> Set<URL> {
        var urls = Set<URL>()
        for user in fetch(UserRecord.self) {
            [user.avatarImageURLString, user.coverImageURLString]
                .compactMap { $0.flatMap(URL.init(string:)) }
                .filter(\.isFileURL)
                .forEach { urls.insert($0.standardizedFileURL) }
        }
        for story in fetch(StoryRecord.self) {
            if let url = story.mediaURLString.flatMap(URL.init(string:)), url.isFileURL {
                urls.insert(url.standardizedFileURL)
            }
        }
        for message in fetch(MessageRecord.self) {
            if let url = message.attachmentURLString.flatMap(URL.init(string:)), url.isFileURL {
                urls.insert(url.standardizedFileURL)
            }
        }
        return urls
    }

    func reports() -> [ModerationReport] {
        fetch(ModerationReportRecord.self, sortedBy: [SortDescriptor(\.createdAt, order: .reverse)]).map(\.domain)
    }

    func createReport(_ report: ModerationReport) {
        context.insert(ModerationReportRecord(report: report))
        trySave()
    }

    func resolveReport(_ reportID: UUID, status: ReportStatus, moderatorID: UUID) {
        guard let record = fetch(ModerationReportRecord.self).first(where: { $0.id == reportID }) else { return }
        record.statusRawValue = status.rawValue
        record.resolvedAt = .now
        record.moderatorID = moderatorID
        context.insert(AuditEventRecord(actorID: moderatorID, action: "report.\(status.rawValue)", targetID: reportID))
        trySave()
    }

    func notifications(recipientID: UUID? = nil) -> [AppNotification] {
        fetch(NotificationRecord.self, sortedBy: [SortDescriptor(\.createdAt, order: .reverse)])
            .filter { record in
                guard let recipientID else { return true }
                return record.recipientID == recipientID
            }
            .map(\.domain)
    }

    func insertNotification(_ notification: AppNotification) {
        context.insert(NotificationRecord(notification: notification))
        trySave()
    }

    func markNotificationRead(_ id: UUID) {
        guard let record = fetch(NotificationRecord.self).first(where: { $0.id == id }) else { return }
        record.isRead = true
        trySave()
    }

    func markAllNotificationsRead(recipientID: UUID? = nil) {
        fetch(NotificationRecord.self)
            .filter { record in
                guard let recipientID else { return true }
                return record.recipientID == recipientID
            }
            .forEach { $0.isRead = true }
        trySave()
    }

    func saveDraft(ownerID: UUID, text: String, visibility: PostVisibility, mediaURLs: [URL]) {
        let drafts = fetch(DraftRecord.self).filter { $0.ownerID == ownerID && $0.kind == "post" }
        let record = drafts.first ?? DraftRecord(ownerID: ownerID, kind: "post", text: text, visibility: visibility)
        if drafts.isEmpty { context.insert(record) }
        record.text = text
        record.visibilityRawValue = visibility.rawValue
        record.mediaURLStrings = mediaURLs.map(\.absoluteString)
        record.updatedAt = .now
        trySave()
    }

    func postDraft(ownerID: UUID) -> DraftRecord? {
        fetch(DraftRecord.self).first { $0.ownerID == ownerID && $0.kind == "post" }
    }

    func deleteDraft(_ draft: DraftRecord) {
        context.delete(draft)
        trySave()
    }

    func saveDeviceToken(_ token: String, environment: String) {
        let records = fetch(DeviceTokenRecord.self)
        if let existing = records.first {
            existing.token = token
            existing.environment = environment
            existing.updatedAt = .now
        } else {
            context.insert(DeviceTokenRecord(token: token, environment: environment))
        }
        trySave()
    }

    func auditEvents() -> [AuditEventRecord] {
        fetch(AuditEventRecord.self, sortedBy: [SortDescriptor(\.createdAt, order: .reverse)])
    }

    func bots(ownerID: UUID) -> [BotRecord] {
        fetch(BotRecord.self, sortedBy: [SortDescriptor(\.createdAt, order: .reverse)]).filter { $0.ownerID == ownerID }
    }

    func createBot(ownerID: UUID, name: String, username: String, token: String) throws {
        let account = "bot-token-\(UUID().uuidString)"
        try SecureStore.set(token, account: account)
        context.insert(BotRecord(ownerID: ownerID, name: name, username: username, tokenAccount: account))
        try save()
    }

    func updateBot(_ bot: BotRecord, webhookURL: URL?, enabled: Bool) {
        bot.webhookURLString = webhookURL?.absoluteString
        bot.isEnabled = enabled
        bot.lastUpdateAt = .now
        trySave()
    }

    func deleteBot(_ bot: BotRecord) {
        context.delete(bot)
        trySave()
    }

    private func fetch<T: PersistentModel>(_ type: T.Type, sortedBy: [SortDescriptor<T>] = []) -> [T] {
        do {
            return try context.fetch(FetchDescriptor<T>(sortBy: sortedBy))
        } catch {
            lastError = error.localizedDescription
            return []
        }
    }

    private func trySave() {
        do {
            try save()
        } catch {
            lastError = error.localizedDescription
        }
    }
}
