import Foundation

enum DemoData {
    static let currentUser: User = users[0]

    static let users: [User] = [
        User(
            id: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!,
            name: "Maya Chen",
            username: "maya",
            biography: "Design lead at Tide",
            avatarSymbol: "person.crop.circle.fill",
            isVerified: true,
            isAdministrator: false,
            followers: 12500,
            following: 312,
            joinedAt: .now.addingTimeInterval(-86400 * 720),
            coverSymbol: "water"
        ),
        User(
            id: UUID(uuidString: "22222222-2222-2222-2222-222222222222")!,
            name: "Aleksey Petrov",
            username: "aleksey",
            biography: "Builds chat products",
            avatarSymbol: "person.crop.circle.fill",
            isVerified: false,
            isAdministrator: false,
            followers: 842,
            following: 267,
            joinedAt: .now.addingTimeInterval(-86400 * 410),
            coverSymbol: "cloud.sun"
        ),
        User(
            id: UUID(uuidString: "33333333-3333-3333-3333-333333333333")!,
            name: "Tide Moderation",
            username: "moderation",
            biography: "Trust and safety",
            avatarSymbol: "shield.lefthalf.filled",
            isVerified: true,
            isAdministrator: true,
            followers: 0,
            following: 0,
            joinedAt: .now.addingTimeInterval(-86400 * 30),
            coverSymbol: "shield"
        )
    ]

    static let posts: [Post] = [
        Post(
            id: UUID(uuidString: "44444444-4444-4444-4444-444444444444")!,
            author: users[0],
            body: "Building the next Tide release with calmer motion and cleaner feeds.",
            createdAt: .now.addingTimeInterval(-3600 * 5),
            media: [],
            likeCount: 18,
            repostCount: 3,
            commentCount: 4,
            viewCount: 512,
            isLiked: false,
            isSaved: false,
            visibility: .everyone,
            location: "Berlin",
            hashtags: ["Tide", "Design"]
        ),
        Post(
            id: UUID(uuidString: "55555555-5555-5555-5555-555555555555")!,
            author: users[1],
            body: "Maya, this draft feels much closer to Telegram x X energy.",
            createdAt: .now.addingTimeInterval(-3600 * 19),
            media: [],
            likeCount: 42,
            repostCount: 5,
            commentCount: 7,
            viewCount: 860,
            isLiked: true,
            isSaved: false,
            visibility: .followers,
            location: nil,
            hashtags: ["messenger", "ui"]
        )
    ]

    static let stories: [Story] = [
        Story(
            id: UUID(uuidString: "66666666-6666-6666-6666-666666666666")!,
            author: users[0],
            createdAt: .now.addingTimeInterval(-3600),
            isViewed: false,
            symbol: "sparkles",
            caption: "New auth screen polish",
            viewCount: 18
        )
    ]

    static let chats: [Chat] = [
        Chat(
            id: UUID(uuidString: "77777777-7777-7777-7777-777777777777")!,
            title: users[1].name,
            avatarSymbol: users[1].avatarSymbol,
            kind: .direct,
            participants: [users[0], users[1]],
            messages: [
                Message(
                    id: UUID(uuidString: "88888888-8888-8888-8888-888888888888")!,
                    senderID: users[0].id,
                    body: "Hey, can you review the registration flow?",
                    sentAt: .now.addingTimeInterval(-1800),
                    state: .read,
                    reaction: "🔥",
                    isEdited: false
                ),
                Message(
                    id: UUID(uuidString: "99999999-9999-9999-9999-999999999999")!,
                    senderID: users[1].id,
                    body: "Yes, it needs a more premium feel.",
                    sentAt: .now.addingTimeInterval(-1200),
                    state: .delivered,
                    reaction: nil,
                    isEdited: false
                )
            ],
            unreadCount: 0,
            isPinned: true,
            isArchived: false,
            isMuted: false,
            lastActivityAt: .now.addingTimeInterval(-1200)
        )
    ]
    static let comments: [(id: UUID, author: User, body: String)] = []
    static let trends: [(String, Int)] = []
    static let liveStreams: [LiveStream] = []
    static let liveMessages: [String] = []
    static let reports: [String] = []
    static let adminMetrics: [(String, String, String)] = []
}
