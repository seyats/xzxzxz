import Foundation
import SwiftUI

struct User: Identifiable, Hashable, Codable, Sendable {
    let id: UUID
    var name: String
    var username: String
    var biography: String
    var avatarSymbol: String
    var avatarImageURL: URL? = nil
    var isVerified: Bool
    var isAdministrator: Bool
    var followers: Int
    var following: Int
    var joinedAt: Date
    var coverSymbol: String = "water"
    var coverImageURL: URL? = nil
    var location: String? = nil
    var website: String? = nil
    var birthday: Date? = nil
    var status: AccountStatus = .active
    var lastSeenAt: Date = .now
    var isFollowing: Bool = false
    var isBlocked: Bool = false

    var handle: String { "@\(username)" }
}

struct Post: Identifiable, Hashable, Codable, Sendable {
    let id: UUID
    let author: User
    var body: String
    var createdAt: Date
    var media: [MediaAttachment]
    var likeCount: Int
    var repostCount: Int
    var commentCount: Int
    var viewCount: Int
    var isLiked: Bool
    var isSaved: Bool
    var visibility: PostVisibility
    var location: String?
    var moderationState: ModerationState = .visible
    var editedAt: Date? = nil
    var hashtags: [String] = []
    var mentions: [String] = []
}

struct MediaAttachment: Identifiable, Hashable, Codable, Sendable {
    let id: UUID
    let kind: MediaKind
    let url: URL?
    let aspectRatio: Double
}

enum MediaKind: String, Hashable, Codable, Sendable {
    case photo
    case video
    case link
}

enum PostVisibility: String, CaseIterable, Identifiable, Codable, Sendable {
    case everyone
    case followers
    case onlyMe

    var id: String { rawValue }

    var title: String {
        switch self {
        case .everyone: "Для всех"
        case .followers: "Только подписчикам"
        case .onlyMe: "Только мне"
        }
    }
}

struct Story: Identifiable, Hashable, Codable, Sendable {
    let id: UUID
    let author: User
    let createdAt: Date
    var isViewed: Bool
    let symbol: String
    var mediaURL: URL? = nil
    var mediaKind: MediaKind = .photo
    var caption: String = ""
    var expiresAt: Date = .now.addingTimeInterval(86_400)
    var viewCount: Int = 0
}

struct Chat: Identifiable, Hashable, Codable, Sendable {
    let id: UUID
    var title: String
    var avatarSymbol: String
    var kind: ChatKind
    var participants: [User]
    var messages: [Message]
    var unreadCount: Int
    var isPinned: Bool
    var isArchived: Bool
    var isMuted: Bool = false
    var lastActivityAt: Date = .now

    var lastMessage: Message? { messages.last }
}

enum ChatKind: String, CaseIterable, Identifiable, Codable, Sendable {
    case direct
    case group
    case channel

    var id: String { rawValue }

    var title: String {
        switch self {
        case .direct: "Личный"
        case .group: "Группа"
        case .channel: "Канал"
        }
    }
}

struct Message: Identifiable, Hashable, Codable, Sendable {
    let id: UUID
    let senderID: UUID
    var body: String
    let sentAt: Date
    var state: DeliveryState
    var reaction: String?
    var isEdited: Bool
    var attachmentURL: URL? = nil
    var attachmentKind: MessageAttachmentKind = .none
    var replyToMessageID: UUID? = nil
    var forwardedFromMessageID: UUID? = nil
    var deletedAt: Date? = nil
}

enum DeliveryState: String, Codable, Sendable {
    case sending
    case sent
    case delivered
    case read
    case failed
}

enum MessageAttachmentKind: String, CaseIterable, Codable, Sendable {
    case none
    case photo
    case video
    case audio
    case file
}

enum AuthProvider: String, CaseIterable, Codable, Sendable {
    case email
    case google
    case apple

    var title: String {
        switch self {
        case .email: "Почта"
        case .google: "Google"
        case .apple: "Apple"
        }
    }
}

struct AuthAccountInfo: Hashable, Codable, Sendable {
    var provider: AuthProvider
    var email: String
    var displayName: String

    var providerFootnote: String? {
        switch provider {
        case .email:
            nil
        case .google:
            "Вход выполнен с аккаунтом Google."
        case .apple:
            "Вход выполнен с аккаунтом Apple."
        }
    }
}

struct DeviceSession: Identifiable, Hashable, Codable, Sendable {
    let id: UUID
    var userID: UUID
    var deviceName: String
    var systemVersion: String
    var appVersion: String
    var lastSeenAt: Date
    var isCurrent: Bool
}

enum AccountStatus: String, CaseIterable, Codable, Sendable {
    case active
    case restricted
    case suspended
    case deleted

    var title: String {
        switch self {
        case .active: "Активный"
        case .restricted: "Ограничен"
        case .suspended: "Заблокирован"
        case .deleted: "Удалён"
        }
    }
}

enum ModerationState: String, CaseIterable, Codable, Sendable {
    case visible
    case limited
    case pendingReview
    case removed
}

enum ReportReason: String, CaseIterable, Identifiable, Codable, Sendable {
    case spam
    case harassment
    case violence
    case nudity
    case misinformation
    case copyright
    case other

    var id: String { rawValue }

    var title: String {
        switch self {
        case .spam: "Спам"
        case .harassment: "Домогательства"
        case .violence: "Насилие"
        case .nudity: "Нагота"
        case .misinformation: "Дезинформация"
        case .copyright: "Авторские права"
        case .other: "Другое"
        }
    }
}

enum ReportStatus: String, CaseIterable, Codable, Sendable {
    case open
    case investigating
    case resolved
    case dismissed
}

enum NotificationKind: String, CaseIterable, Codable, Sendable {
    case message
    case like
    case repost
    case comment
    case mention
    case follow
    case storyReply
    case live
    case system
}

struct ModerationReport: Identifiable, Hashable, Codable, Sendable {
    let id: UUID
    let reporterID: UUID
    let targetID: UUID
    let targetType: String
    var reason: ReportReason
    var details: String
    var status: ReportStatus
    var createdAt: Date
    var resolvedAt: Date?
    var moderatorID: UUID?
}

struct AppNotification: Identifiable, Hashable, Codable, Sendable {
    let id: UUID
    var recipientID: UUID?
    var kind: NotificationKind
    var title: String
    var body: String
    var targetID: UUID?
    var createdAt: Date
    var isRead: Bool
}

struct Comment: Identifiable, Hashable, Codable, Sendable {
    let id: UUID
    let postID: UUID
    let author: User
    var body: String
    var createdAt: Date
    var likeCount: Int
    var isLiked: Bool
}

struct LiveStream: Identifiable, Hashable, Sendable {
    let id: UUID
    let host: User
    var title: String
    var category: String
    var viewerCount: Int
    var isLive: Bool
    var symbol: String
}

enum Loadable<Value> {
    case idle
    case loading
    case loaded(Value)
    case empty
    case failed(String)
}

enum AppTab: String, CaseIterable, Identifiable {
    case home
    case chats
    case notifications
    case profile

    var id: String { rawValue }

    var title: String {
        switch self {
        case .home: "Лента"
        case .chats: "Чаты"
        case .notifications: "Уведомления"
        case .profile: "Профиль"
        }
    }

    var shortTitle: String {
        switch self {
        case .home: "Лента"
        case .chats: "Чаты"
        case .notifications: "Уведомления"
        case .profile: "Профиль"
        }
    }

    var symbol: String {
        switch self {
        case .home: "house"
        case .chats: "bubble.left.and.bubble.right"
        case .notifications: "bell"
        case .profile: "person.crop.circle"
        }
    }
}

enum AppRoute: Hashable {
    case post(UUID)
    case profile(User)
    case chat(UUID)
    case stories(UUID)
    case live
    case browser(URL)
    case admin
    case notifications
    case moderation(UUID)
    case botPlatform
}

enum AppSheet: Identifiable {
    case composer
    case newMessage
    case share(URL)
    case report(UUID, String)
    case createStory
    case adminAccess

    var id: String {
        switch self {
        case .composer: "composer"
        case .newMessage: "new-message"
        case .share(let url): "share-\(url.absoluteString)"
        case .report(let id, _): "report-\(id)"
        case .createStory: "create-story"
        case .adminAccess: "admin-access"
        }
    }
}
