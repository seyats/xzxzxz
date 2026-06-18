import Foundation

enum DemoData {
    static let users: [User] = []
    static let posts: [Post] = []
    static let stories: [Story] = []
    static let chats: [Chat] = []
    static let comments: [(id: UUID, author: User, body: String)] = []
    static let trends: [(String, Int)] = []
    static let liveStreams: [LiveStream] = []
    static let liveMessages: [String] = []
    static let reports: [String] = []
    static let adminMetrics: [(String, String, String)] = []
}
