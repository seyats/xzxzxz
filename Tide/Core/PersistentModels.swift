import Foundation
import SwiftData

@Model
final class UserRecord {
    @Attribute(.unique) var id: UUID
    var name: String
    var username: String
    var biography: String
    var avatarSymbol: String
    var avatarImageURLString: String?
    var coverSymbol: String
    var location: String?
    var website: String?
    var birthday: Date?
    var isVerified: Bool
    var isAdministrator: Bool
    var followers: Int
    var following: Int
    var joinedAt: Date
    var lastSeenAt: Date
    var coverImageURLString: String?
    var statusRawValue: String
    var isFollowing: Bool
    var isBlocked: Bool

    init(user: User) {
        id = user.id
        name = user.name
        username = user.username
        biography = user.biography
        avatarSymbol = user.avatarSymbol
        avatarImageURLString = user.avatarImageURL?.absoluteString
        coverSymbol = user.coverSymbol
        location = user.location
        website = user.website
        birthday = user.birthday
        isVerified = user.isVerified
        isAdministrator = user.isAdministrator
        followers = user.followers
        following = user.following
        joinedAt = user.joinedAt
        lastSeenAt = user.lastSeenAt
        coverImageURLString = user.coverImageURL?.absoluteString
        statusRawValue = user.status.rawValue
        isFollowing = user.isFollowing
        isBlocked = user.isBlocked
    }

    var domain: User {
        User(
            id: id,
            name: name,
            username: username,
            biography: biography,
            avatarSymbol: avatarSymbol,
            avatarImageURL: avatarImageURLString.flatMap(URL.init(string:)),
            isVerified: isVerified,
            isAdministrator: isAdministrator,
            followers: followers,
            following: following,
            joinedAt: joinedAt,
            coverSymbol: coverSymbol,
            coverImageURL: coverImageURLString.flatMap(URL.init(string:)),
            location: location,
            website: website,
            birthday: birthday,
            status: AccountStatus(rawValue: statusRawValue) ?? .active,
            lastSeenAt: lastSeenAt,
            isFollowing: isFollowing,
            isBlocked: isBlocked
        )
    }
}

@Model
final class PostRecord {
    @Attribute(.unique) var id: UUID
    var authorID: UUID
    var body: String
    var createdAt: Date
    var likeCount: Int
    var repostCount: Int
    var commentCount: Int
    var viewCount: Int
    var isLiked: Bool
    var isSaved: Bool
    var visibilityRawValue: String
    var location: String?
    var moderationStateRawValue: String
    var editedAt: Date?
    var hashtags: [String]
    var mentions: [String]

    init(post: Post) {
        id = post.id
        authorID = post.author.id
        body = post.body
        createdAt = post.createdAt
        likeCount = post.likeCount
        repostCount = post.repostCount
        commentCount = post.commentCount
        viewCount = post.viewCount
        isLiked = post.isLiked
        isSaved = post.isSaved
        visibilityRawValue = post.visibility.rawValue
        location = post.location
        moderationStateRawValue = post.moderationState.rawValue
        editedAt = post.editedAt
        hashtags = post.hashtags
        mentions = post.mentions
    }
}

@Model
final class MediaRecord {
    @Attribute(.unique) var id: UUID
    var ownerID: UUID
    var kindRawValue: String
    var localURLString: String?
    var remoteURLString: String?
    var aspectRatio: Double
    var duration: Double
    var sortIndex: Int
    var createdAt: Date

    init(
        id: UUID = UUID(),
        ownerID: UUID,
        kind: MediaKind,
        localURL: URL?,
        remoteURL: URL? = nil,
        aspectRatio: Double,
        duration: Double = 0,
        sortIndex: Int = 0,
        createdAt: Date = .now
    ) {
        self.id = id
        self.ownerID = ownerID
        kindRawValue = kind.rawValue
        localURLString = localURL?.absoluteString
        remoteURLString = remoteURL?.absoluteString
        self.aspectRatio = aspectRatio
        self.duration = duration
        self.sortIndex = sortIndex
        self.createdAt = createdAt
    }

    var domain: MediaAttachment {
        MediaAttachment(
            id: id,
            kind: MediaKind(rawValue: kindRawValue) ?? .photo,
            url: remoteURLString.flatMap(URL.init(string:)) ?? localURLString.flatMap(URL.init(string:)),
            aspectRatio: aspectRatio
        )
    }
}

@Model
final class StoryRecord {
    @Attribute(.unique) var id: UUID
    var authorID: UUID
    var createdAt: Date
    var expiresAt: Date
    var isViewed: Bool
    var symbol: String
    var mediaURLString: String?
    var mediaKindRawValue: String
    var caption: String
    var viewCount: Int

    init(story: Story) {
        id = story.id
        authorID = story.author.id
        createdAt = story.createdAt
        expiresAt = story.expiresAt
        isViewed = story.isViewed
        symbol = story.symbol
        mediaURLString = story.mediaURL?.absoluteString
        mediaKindRawValue = story.mediaKind.rawValue
        caption = story.caption
        viewCount = story.viewCount
    }
}

@Model
final class ChatRecord {
    @Attribute(.unique) var id: UUID
    var title: String
    var avatarSymbol: String
    var kindRawValue: String
    var participantIDs: [UUID]
    var unreadCount: Int
    var isPinned: Bool
    var isArchived: Bool
    var isMuted: Bool
    var lastActivityAt: Date

    init(chat: Chat) {
        id = chat.id
        title = chat.title
        avatarSymbol = chat.avatarSymbol
        kindRawValue = chat.kind.rawValue
        participantIDs = chat.participants.map(\.id)
        unreadCount = chat.unreadCount
        isPinned = chat.isPinned
        isArchived = chat.isArchived
        isMuted = chat.isMuted
        lastActivityAt = chat.lastActivityAt
    }
}

@Model
final class MessageRecord {
    @Attribute(.unique) var id: UUID
    var chatID: UUID
    var senderID: UUID
    var body: String
    var sentAt: Date
    var stateRawValue: String
    var reaction: String?
    var isEdited: Bool
    var attachmentURLString: String?
    var attachmentKindRawValue: String
    var replyToMessageID: UUID?
    var forwardedFromMessageID: UUID?
    var deletedAt: Date?

    init(message: Message, chatID: UUID) {
        id = message.id
        self.chatID = chatID
        senderID = message.senderID
        body = message.body
        sentAt = message.sentAt
        stateRawValue = message.state.rawValue
        reaction = message.reaction
        isEdited = message.isEdited
        attachmentURLString = message.attachmentURL?.absoluteString
        attachmentKindRawValue = message.attachmentKind.rawValue
        replyToMessageID = message.replyToMessageID
        forwardedFromMessageID = message.forwardedFromMessageID
        deletedAt = message.deletedAt
    }

    var domain: Message {
        Message(
            id: id,
            senderID: senderID,
            body: body,
            sentAt: sentAt,
            state: DeliveryState(rawValue: stateRawValue) ?? .sent,
            reaction: reaction,
            isEdited: isEdited,
            attachmentURL: attachmentURLString.flatMap(URL.init(string:)),
            attachmentKind: MessageAttachmentKind(rawValue: attachmentKindRawValue) ?? .none,
            replyToMessageID: replyToMessageID,
            forwardedFromMessageID: forwardedFromMessageID,
            deletedAt: deletedAt
        )
    }
}

@Model
final class CommentRecord {
    @Attribute(.unique) var id: UUID
    var postID: UUID
    var authorID: UUID
    var body: String
    var createdAt: Date
    var likeCount: Int
    var isLiked: Bool

    init(id: UUID = UUID(), postID: UUID, authorID: UUID, body: String, createdAt: Date = .now, likeCount: Int = 0, isLiked: Bool = false) {
        self.id = id
        self.postID = postID
        self.authorID = authorID
        self.body = body
        self.createdAt = createdAt
        self.likeCount = likeCount
        self.isLiked = isLiked
    }
}

@Model
final class ModerationReportRecord {
    @Attribute(.unique) var id: UUID
    var reporterID: UUID
    var targetID: UUID
    var targetType: String
    var reasonRawValue: String
    var details: String
    var statusRawValue: String
    var createdAt: Date
    var resolvedAt: Date?
    var moderatorID: UUID?

    init(report: ModerationReport) {
        id = report.id
        reporterID = report.reporterID
        targetID = report.targetID
        targetType = report.targetType
        reasonRawValue = report.reason.rawValue
        details = report.details
        statusRawValue = report.status.rawValue
        createdAt = report.createdAt
        resolvedAt = report.resolvedAt
        moderatorID = report.moderatorID
    }

    var domain: ModerationReport {
        ModerationReport(
            id: id,
            reporterID: reporterID,
            targetID: targetID,
            targetType: targetType,
            reason: ReportReason(rawValue: reasonRawValue) ?? .other,
            details: details,
            status: ReportStatus(rawValue: statusRawValue) ?? .open,
            createdAt: createdAt,
            resolvedAt: resolvedAt,
            moderatorID: moderatorID
        )
    }
}

@Model
final class NotificationRecord {
    @Attribute(.unique) var id: UUID
    var recipientID: UUID?
    var kindRawValue: String
    var title: String
    var body: String
    var targetID: UUID?
    var createdAt: Date
    var isRead: Bool

    init(notification: AppNotification) {
        id = notification.id
        recipientID = notification.recipientID
        kindRawValue = notification.kind.rawValue
        title = notification.title
        body = notification.body
        targetID = notification.targetID
        createdAt = notification.createdAt
        isRead = notification.isRead
    }

    var domain: AppNotification {
        AppNotification(
            id: id,
            recipientID: recipientID,
            kind: NotificationKind(rawValue: kindRawValue) ?? .system,
            title: title,
            body: body,
            targetID: targetID,
            createdAt: createdAt,
            isRead: isRead
        )
    }
}

@Model
final class FollowRecord {
    @Attribute(.unique) var id: UUID
    var followerID: UUID
    var followingID: UUID
    var createdAt: Date

    init(followerID: UUID, followingID: UUID, createdAt: Date = .now) {
        id = UUID()
        self.followerID = followerID
        self.followingID = followingID
        self.createdAt = createdAt
    }
}

@Model
final class BlockRecord {
    @Attribute(.unique) var id: UUID
    var ownerID: UUID
    var blockedUserID: UUID
    var createdAt: Date

    init(ownerID: UUID, blockedUserID: UUID, createdAt: Date = .now) {
        id = UUID()
        self.ownerID = ownerID
        self.blockedUserID = blockedUserID
        self.createdAt = createdAt
    }
}

@Model
final class DraftRecord {
    @Attribute(.unique) var id: UUID
    var ownerID: UUID
    var kind: String
    var text: String
    var visibilityRawValue: String
    var mediaURLStrings: [String]
    var updatedAt: Date

    init(id: UUID = UUID(), ownerID: UUID, kind: String, text: String, visibility: PostVisibility, mediaURLStrings: [String] = [], updatedAt: Date = .now) {
        self.id = id
        self.ownerID = ownerID
        self.kind = kind
        self.text = text
        visibilityRawValue = visibility.rawValue
        self.mediaURLStrings = mediaURLStrings
        self.updatedAt = updatedAt
    }
}

@Model
final class DeviceTokenRecord {
    @Attribute(.unique) var id: UUID
    var token: String
    var environment: String
    var updatedAt: Date

    init(token: String, environment: String) {
        id = UUID()
        self.token = token
        self.environment = environment
        updatedAt = .now
    }
}

@Model
final class DeviceSessionRecord {
    @Attribute(.unique) var id: UUID
    var userID: UUID
    var deviceName: String
    var systemVersion: String
    var appVersion: String
    var lastSeenAt: Date
    var isCurrent: Bool

    init(session: DeviceSession) {
        id = session.id
        userID = session.userID
        deviceName = session.deviceName
        systemVersion = session.systemVersion
        appVersion = session.appVersion
        lastSeenAt = session.lastSeenAt
        isCurrent = session.isCurrent
    }

    var domain: DeviceSession {
        DeviceSession(
            id: id,
            userID: userID,
            deviceName: deviceName,
            systemVersion: systemVersion,
            appVersion: appVersion,
            lastSeenAt: lastSeenAt,
            isCurrent: isCurrent
        )
    }
}

@Model
final class AuditEventRecord {
    @Attribute(.unique) var id: UUID
    var actorID: UUID
    var action: String
    var targetID: UUID?
    var metadata: String
    var createdAt: Date

    init(actorID: UUID, action: String, targetID: UUID?, metadata: String = "", createdAt: Date = .now) {
        id = UUID()
        self.actorID = actorID
        self.action = action
        self.targetID = targetID
        self.metadata = metadata
        self.createdAt = createdAt
    }
}

@Model
final class BotRecord {
    @Attribute(.unique) var id: UUID
    var ownerID: UUID
    var name: String
    var username: String
    var tokenAccount: String
    var webhookURLString: String?
    var isEnabled: Bool
    var createdAt: Date
    var lastUpdateAt: Date?

    init(ownerID: UUID, name: String, username: String, tokenAccount: String, webhookURL: URL? = nil) {
        id = UUID()
        self.ownerID = ownerID
        self.name = name
        self.username = username
        self.tokenAccount = tokenAccount
        webhookURLString = webhookURL?.absoluteString
        isEnabled = true
        createdAt = .now
    }
}
