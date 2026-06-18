import PhotosUI
import SwiftUI

struct FeedView: View {
    @Environment(AppDependencies.self) private var dependencies
    @State private var selection = "For You"
    private let sections = ["For You", "Following", "Trends", "Search"]

    var body: some View {
        @Bindable var social = dependencies.social
        ScrollView {
            LazyVStack(spacing: 0, pinnedViews: .sectionHeaders) {
                StoryRail(stories: social.stories)
                Section {
                    if selection == "Trends" {
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
                    Picker("Feed", selection: $selection) {
                        ForEach(sections, id: \.self) { Text($0).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                    .background(.bar)
                }
            }
        }
        .searchable(text: $social.query, prompt: "Posts, people and hashtags")
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
        case "Following": dependencies.social.filteredPosts.filter { $0.author.isFollowing || $0.author.id == dependencies.session.currentUser?.id }
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
                        Text("Your story").font(.caption).lineLimit(1).frame(width: 68)
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
                TextEditor(text: $bodyText)
                    .frame(minHeight: 180)
                    .font(TideTypography.body)
                if !selectedMedia.isEmpty { ComposerMediaStrip(media: selectedMedia, remove: removeMedia) }
                Picker("Visibility", selection: $visibility) {
                    ForEach(PostVisibility.allCases) { Text($0.title).tag($0) }
                }
                Section("Add") {
                    PhotosPicker(selection: $selectedItems, maxSelectionCount: 10, matching: .any(of: [.images, .videos])) {
                        Label("Photo or video", systemImage: "photo.on.rectangle")
                    }
                    TextField("Location", text: $location)
                    if isImporting { ProgressView("Importing media") }
                }
            }
            .navigationTitle("New Post")
            .navigationBarTitleDisplayMode(.inline)
            .scrollContentBackground(.hidden)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Post", action: publish)
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
}
