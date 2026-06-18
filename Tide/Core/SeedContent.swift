import Foundation

struct SeedContent: Decodable, Sendable {
    let schemaVersion: Int
    let generatedAt: Date
    let posts: [SeedPost]
}

struct SeedPost: Decodable, Identifiable, Sendable {
    let id: UUID
    let author: SeedAuthor
    let body: String
    let createdAt: Date
    let statistics: SeedStatistics
    let tags: [String]
    let visibility: String
}

struct SeedAuthor: Decodable, Sendable {
    let name: String
    let username: String
    let verified: Bool
}

struct SeedStatistics: Decodable, Sendable {
    let likes: Int
    let reposts: Int
    let comments: Int
    let views: Int
}

enum SeedContentLoader {
    static func load(bundle: Bundle = .main) throws -> SeedContent {
        guard let url = bundle.url(forResource: "SeedContent", withExtension: "json") else {
            throw SeedContentError.resourceMissing
        }
        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(SeedContent.self, from: data)
    }
}

enum SeedContentError: LocalizedError {
    case resourceMissing

    var errorDescription: String? {
        switch self {
        case .resourceMissing: "SeedContent.json is missing from the application bundle."
        }
    }
}

