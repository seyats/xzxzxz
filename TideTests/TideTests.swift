import Foundation
import Testing
@testable import Tide

@MainActor
struct TideTests {
    @Test func likingPostUpdatesStateAndCount() {
        let original = DemoData.posts[1]
        let store = SocialStore(posts: [original], stories: [])
        store.toggleLike(original.id)
        #expect(store.posts[0].isLiked != original.isLiked)
        #expect(store.posts[0].likeCount == original.likeCount + (original.isLiked ? -1 : 1))
    }

    @Test func searchMatchesBodyAndAuthor() {
        let store = SocialStore(posts: DemoData.posts, stories: [])
        store.query = "Maya"
        #expect(!store.filteredPosts.isEmpty)
        #expect(store.filteredPosts.allSatisfy { $0.author.name == "Maya Chen" || $0.body.localizedCaseInsensitiveContains("Maya") })
    }

    @Test func sendingMessageAppendsIt() async {
        let chat = DemoData.chats[0]
        let store = MessengerStore(chats: [chat])
        await store.send("New message", to: chat.id, senderID: DemoData.currentUser.id)
        #expect(store.chat(id: chat.id)?.messages.last?.body == "New message")
        #expect(store.chat(id: chat.id)?.messages.last?.state == .delivered)
    }

    @Test func swiftDataPersistsPostMutation() {
        let database = LocalDatabase(inMemory: true)
        guard var post = database.posts().first else {
            Issue.record("Seeded post is missing")
            return
        }
        post.isSaved = true
        post.body = "Persisted body"
        database.updatePost(post)
        let reloaded = database.posts().first { $0.id == post.id }
        #expect(reloaded?.isSaved == true)
        #expect(reloaded?.body == "Persisted body")
    }

    @Test func moderationReportCanBeResolved() {
        let database = LocalDatabase(inMemory: true)
        let store = ModerationStore(database: database)
        let reportID = UUID()
        let report = ModerationReport(
            id: reportID,
            reporterID: DemoData.users[2].id,
            targetID: DemoData.posts[0].id,
            targetType: "post",
            reason: .spam,
            details: "Automated test",
            status: .open,
            createdAt: .now,
            resolvedAt: nil,
            moderatorID: nil
        )
        database.createReport(report)
        store.reload()
        store.resolve(reportID, status: .resolved, moderatorID: DemoData.currentUser.id)
        #expect(store.reports.first(where: { $0.id == reportID })?.status == .resolved)
    }

    @Test func draftRoundTripUsesSwiftData() {
        let database = LocalDatabase(inMemory: true)
        database.saveDraft(ownerID: DemoData.currentUser.id, text: "Offline draft", visibility: .followers, mediaURLs: [])
        let draft = database.postDraft(ownerID: DemoData.currentUser.id)
        #expect(draft?.text == "Offline draft")
        #expect(draft?.visibilityRawValue == PostVisibility.followers.rawValue)
    }

    @Test func notificationReadStatePersists() {
        let database = LocalDatabase(inMemory: true)
        let store = NotificationStore(database: database)
        store.add(kind: .mention, title: "Mention", body: "Hello")
        guard let id = store.notifications.first?.id else {
            Issue.record("Notification is missing")
            return
        }
        store.markRead(id)
        #expect(store.notifications.first(where: { $0.id == id })?.isRead == true)
    }
}
