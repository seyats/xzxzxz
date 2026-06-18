import PhotosUI
import SwiftUI

struct FeedView: View {
    @Environment(AppDependencies.self) private var dependencies
    @State private var selection = "feed_for_you"
    private let sections = ["feed_for_you", "feed_following", "feed_trends", "feed_search"]

    var body: some View {
        @Bindable var social = dependencies.social
        ScrollView {
            LazyVStack(spacing: 0, pinnedViews: .sectionHeaders) {
                StoryRail(stories: social.stories)
                Section {
                    if selection == "feed_trends" {
                        TrendsView()
                    } else if social.filteredPosts.isEmpty {
                        EmptyStateView(symbol: "text.page", title: "No posts", message: "Follow people or create the first post.")
                    } else {
                        ForEach(filteredPosts) { post in
                            PostCard(post: post)
                            Divider().padding(.leading, 68)
                        }
                    }
                } header: {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(sections, id: \.self) { item in
                                Button {
                                    selection = item
                                } label: {
                                    Text(LocalizedStringKey(item))
                                        .font(.caption.weight(.semibold))
                                        .padding(.horizontal, 14)
                                        .padding(.vertical, 9)
                                        .background(selection == item ? TidePalette.ink.opacity(0.12) : TidePalette.subtle, in: Capsule())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal)
                        .padding(.top, 6)
                        .padding(.bottom, 8)
                    }
                }
            }
        }
        .searchable(text: $social.query, prompt: String(localized: "feed_search_prompt"))
        .refreshable { await social.refresh() }
        .navigationTitle("Tide")
        .scrollContentBackground(.hidden)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button { dependencies.router.push(.live) } label: { Image(systemName: "dot.radiowaves.left.and.right") }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button { dependencies.router.sheet = .composer } label: { Image(systemName: "square.and.pencil") }
            }
        }
    }

    private var filteredPosts: [Post] {
        switch selection {
        case "feed_following": dependencies.social.filteredPosts.filter { $0.author.isFollowing || $0.author.id == dependencies.session.currentUser?.id }
        default: dependencies.social.filteredPosts
        }
    }
}

struct StoryRail: View {
    @Environment(AppDependencies.self) private var dependencies
    let stories: [Story]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(spacing: 14) {
                Button { dependencies.router.sheet = .createStory } label: {
                    VStack(spacing: 6) {
                        ZStack(alignment: .bottomTrailing) {
                            if let user = dependencies.session.currentUser { AvatarView(user: user, size: 60) }
                            Image(systemName: "plus.circle.fill")
                                .font(.title3)
                                .symbolRenderingMode(.palette)
                                .foregroundStyle(TidePalette.inverse, TidePalette.ink)
                                .background(TidePalette.paper, in: Circle())
                        }
                        Text(String(localized: "story_your")).font(.caption).lineLimit(1).frame(width: 68)
                    }
                }
                .buttonStyle(.plain)

                ForEach(stories) { story in
                    Button { dependencies.router.push(.stories(story.id)) } label: {
                        VStack(spacing: 6) {
                            AvatarView(user: story.author, size: 60)
                                .padding(3)
                                .overlay(Circle().stroke(story.isViewed ? TidePalette.separator : TidePalette.ink, lineWidth: 2))
                            Text(story.author.name).font(.caption).lineLimit(1).frame(width: 68)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding()
        }
    }
}

struct PostCard: View {
    @Environment(AppDependencies.self) private var dependencies
    let post: Post

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Button { dependencies.router.push(.profile(post.author)) } label: { AvatarView(user: post.author) }
                .buttonStyle(.plain)
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 6) {
                    VerifiedName(user: post.author)
                    Text(post.author.handle).foregroundStyle(.secondary).lineLimit(1)
                    Text("· \(post.createdAt.formatted(.relative(presentation: .named)))")
                        .foregroundStyle(.secondary).lineLimit(1)
                    Spacer()
                    Menu {
                        Button("Report", role: .destructive) { dependencies.router.sheet = .report(post.id, "post") }
                        if post.author.id == dependencies.session.currentUser?.id {
                            Button("Delete", role: .destructive) {
                                if let actorID = dependencies.session.currentUser?.id { dependencies.social.deletePost(post.id, actorID: actorID) }
                            }
                        }
                    } label: { Image(systemName: "ellipsis") }
                }
                Text(post.body).frame(maxWidth: .infinity, alignment: .leading)
                if !post.media.isEmpty { PostMediaGrid(media: post.media) }
                if let location = post.location {
                    Label(location, systemImage: "location.fill").font(.caption).foregroundStyle(.secondary)
                }
                PostActions(post: post)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .contentShape(Rectangle())
        .onTapGesture { dependencies.router.push(.post(post.id)) }
        .accessibilityElement(children: .contain)
    }
}

struct PostActions: View {
    @Environment(AppDependencies.self) private var dependencies
    let post: Post

    var body: some View {
        HStack {
            action("bubble.left", post.commentCount) { dependencies.router.push(.post(post.id)) }
            Spacer()
            action("arrow.2.squarepath", post.repostCount, color: TidePalette.success) { dependencies.social.repost(post.id) }
            Spacer()
            action(post.isLiked ? "heart.fill" : "heart", post.likeCount, color: post.isLiked ? TidePalette.danger : .secondary) {
                dependencies.social.toggleLike(post.id)
            }
            Spacer()
            action(post.isSaved ? "bookmark.fill" : "bookmark", nil, color: post.isSaved ? TidePalette.success : .secondary) { dependencies.social.toggleSave(post.id) }
            Spacer()
            action("square.and.arrow.up", nil) {
                dependencies.router.sheet = .share(URL(string: "https://tide.app/post/\(post.id)")!)
            }
        }
    }

    private func action(_ symbol: String, _ count: Int?, color: Color = .secondary, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: symbol)
                if let count { Text(count.formatted(.number.notation(.compactName))).font(.caption) }
            }
            .foregroundStyle(color)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

struct ComposerView: View {
    @Environment(AppDependencies.self) private var dependencies
    @Environment(\.dismiss) private var dismiss
    @State private var bodyText = ""
    @State private var visibility = PostVisibility.everyone
    @State private var selectedItems: [PhotosPickerItem] = []
    @State private var selectedMedia: [ComposerMedia] = []
    @State private var location = ""
    @State private var isImporting = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            AvatarView(user: dependencies.session.currentUser ?? User(id: UUID(), name: "Tide", username: "tide", biography: "", avatarSymbol: "person.crop.circle.fill", isVerified: false, isAdministrator: false, followers: 0, following: 0, joinedAt: .now, coverSymbol: "water"), size: 38)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("new_post_identity")
                                    .font(.caption).foregroundStyle(.secondary)
                                Text(dependencies.session.currentUser?.handle ?? "@tide")
                                    .font(.subheadline.weight(.semibold))
                            }
                            Spacer()
                            TextField(String(localized: "new_post_location"), text: $location)
                                .frame(width: 120)
                                .textInputAutocapitalization(.never)
                        }
                        ZStack(alignment: .topLeading) {
                            if bodyText.isEmpty {
                                Text("new_post_placeholder")
                                    .foregroundStyle(.secondary)
                                    .padding(.top, 8)
                                    .padding(.leading, 5)
                            }
                            TextEditor(text: $bodyText)
                                .frame(minHeight: 160)
                                .scrollContentBackground(.hidden)
                        }
                        if !selectedMedia.isEmpty { ComposerMediaStrip(media: selectedMedia, remove: removeMedia) }
                        HStack(spacing: 10) {
                            actionTile(symbol: "photo.on.rectangle", title: "new_post_media")
                            actionTile(symbol: "location.fill", title: "new_post_location")
                            actionTile(symbol: "clock.badge.checkmark", title: "new_post_schedule")
                        }
                    }
                } header: {
                    EmptyView()
                }
                Section {
                    PhotosPicker(selection: $selectedItems, maxSelectionCount: 10, matching: .any(of: [.images, .videos])) {
                        Label("new_post_add_media", systemImage: "photo.on.rectangle")
                    }
                    if isImporting { ProgressView("Importing media") }
                }
                Picker("Visibility", selection: $visibility) {
                    ForEach(PostVisibility.allCases) { Text($0.title).tag($0) }
                }
            }
            .navigationTitle(String(localized: "new_post_title"))
            .navigationBarTitleDisplayMode(.inline)
            .scrollContentBackground(.hidden)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button(String(localized: "action_cancel")) { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "new_post_publish"), action: publish)
                        .disabled(bodyText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && selectedMedia.isEmpty)
                }
            }
            .task { restoreDraft() }
            .onChange(of: selectedItems) { _, items in
                Task {
                    isImporting = true
                    defer { isImporting = false }
                    if let imported = try? await MediaLibrary.shared.importItems(items) { selectedMedia = imported }
                }
            }
            .onDisappear { saveDraftIfNeeded() }
        }
    }

    private func actionTile(symbol: String, title: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: symbol)
                .font(.title3)
            Text(LocalizedStringKey(title))
                .font(.caption2.weight(.semibold))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(TidePalette.subtle, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func publish() {
        guard let user = dependencies.session.currentUser else { return }
        let attachments = selectedMedia.map { MediaAttachment(id: $0.id, kind: $0.kind, url: $0.url, aspectRatio: $0.aspectRatio) }
        dependencies.social.createPost(body: bodyText, visibility: visibility, author: user, media: attachments, location: location.isEmpty ? nil : location)
        if let draft = dependencies.database.postDraft(ownerID: user.id) { dependencies.database.deleteDraft(draft) }
        bodyText = ""
        selectedMedia = []
        dismiss()
    }

    private func restoreDraft() {
        guard let user = dependencies.session.currentUser,
              let draft = dependencies.database.postDraft(ownerID: user.id) else { return }
        bodyText = draft.text
        visibility = PostVisibility(rawValue: draft.visibilityRawValue) ?? .everyone
    }

    private func saveDraftIfNeeded() {
        guard let user = dependencies.session.currentUser,
              !bodyText.isEmpty || !selectedMedia.isEmpty else { return }
        dependencies.database.saveDraft(ownerID: user.id, text: bodyText, visibility: visibility, mediaURLs: selectedMedia.map(\.url))
    }

    private func removeMedia(_ media: ComposerMedia) {
        selectedMedia.removeAll { $0.id == media.id }
        Task { await MediaLibrary.shared.remove(media) }
    }
}

struct PostDetailView: View {
    @Environment(AppDependencies.self) private var dependencies
    let postID: UUID
    @State private var reply = ""

    private var comments: [Comment] { dependencies.social.comments(postID: postID) }

    var body: some View {
        Group {
            if let post = dependencies.social.posts.first(where: { $0.id == postID }) {
                List {
                    PostCard(post: post).listRowInsets(EdgeInsets()).listRowSeparator(.hidden)
                    Section("Replies") {
                        if comments.isEmpty {
                            ContentUnavailableView("No replies", systemImage: "bubble.left", description: Text("Start the conversation."))
                        }
                        ForEach(comments) { comment in
                            VStack(alignment: .leading, spacing: 7) {
                                UserRow(user: comment.author)
                                Text(comment.body)
                            }
                        }
                    }
                }
                .scrollContentBackground(.hidden)
                .safeAreaInset(edge: .bottom) {
                    HStack {
                        TextField("Post your reply", text: $reply)
                        Button("Send", action: sendReply)
                            .disabled(reply.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                    .padding()
                    .background(.bar)
                }
            } else {
                EmptyStateView(symbol: "exclamationmark.triangle", title: "Post unavailable", message: "It may have been deleted.")
            }
        }
        .navigationTitle("Post")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func sendReply() {
        guard let authorID = dependencies.session.currentUser?.id else { return }
        dependencies.social.createComment(postID: postID, authorID: authorID, body: reply)
        reply = ""
    }
}

struct TrendsView: View {
    var body: some View {
        ContentUnavailableView("No trends yet", systemImage: "chart.bar.xaxis", description: Text("Trending topics will appear when real posts arrive."))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 40)
    }
}
