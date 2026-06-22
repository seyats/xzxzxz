import PhotosUI
import SwiftUI

struct FeedView: View {
    @Environment(AppDependencies.self) private var dependencies
    @State private var selection: FeedSection = .forYou
    private let sections: [FeedSection] = FeedSection.allCases

    var body: some View {
        @Bindable var social = dependencies.social
        ScrollView {
            LazyVStack(spacing: 0, pinnedViews: .sectionHeaders) {
                StoryRail(stories: social.stories)
                Section {
                    if selection == .trends {
                        TrendsView()
                    } else if social.filteredPosts.isEmpty {
                        EmptyStateView(symbol: "bubble.left.and.bubble.right", title: "Tide сфокусирован на общении", message: "Посты скрыты. Истории, чаты, фото, видео и файлы остаются в сообщениях.")
                    } else {
                        ForEach(filteredPosts) { post in
                            PostCard(post: post, mode: .feed)
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
                                    Text(item.title)
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
        .searchable(text: $social.query, prompt: "Посты, люди и хэштеги")
        .refreshable { await social.refresh() }
        .navigationTitle("Лента")
        .scrollContentBackground(.hidden)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button { dependencies.router.push(.live) } label: { Image(systemName: "dot.radiowaves.left.and.right") }
            }
        }
    }

    private var filteredPosts: [Post] {
        switch selection {
        case .following: dependencies.social.filteredPosts.filter { $0.author.isFollowing || $0.author.id == dependencies.session.currentUser?.id }
        default: dependencies.social.filteredPosts
        }
    }
}

private enum FeedSection: String, CaseIterable, Hashable {
    case forYou
    case following
    case trends
    case search

    var title: String {
        switch self {
        case .forYou: "Для вас"
        case .following: "Подписки"
        case .trends: "Тренды"
        case .search: "Поиск"
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
                        Text("Ваша история").font(.caption).lineLimit(1).frame(width: 68)
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
    var mode: Mode = .feed

    enum Mode {
        case feed
        case detail
    }

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
                        Button("Пожаловаться", role: .destructive) { dependencies.router.sheet = .report(post.id, "post") }
                        if post.author.id == dependencies.session.currentUser?.id {
                            Button("Удалить", role: .destructive) {
                                if let actorID = dependencies.session.currentUser?.id { dependencies.social.deletePost(post.id, actorID: actorID) }
                            }
                        }
                    } label: { Image(systemName: "ellipsis") }
                }
                Text(post.body)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                    .onTapGesture { openPostIfNeeded() }
                if let location = post.location {
                    Label(location, systemImage: "location.fill").font(.caption).foregroundStyle(.secondary)
                }
                PostActions(post: post, opensReplies: mode == .feed)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .accessibilityElement(children: .contain)
    }

    private func openPostIfNeeded() {
        guard mode == .feed else { return }
        withAnimation(.easeInOut(duration: 0.42)) {
            dependencies.router.push(.post(post.id))
        }
    }
}

struct PostActions: View {
    @Environment(AppDependencies.self) private var dependencies
    let post: Post
    var opensReplies = true

    var body: some View {
        HStack {
            action("bubble.left", post.commentCount) {
                guard opensReplies else { return }
                dependencies.router.push(.post(post.id))
            }
            Spacer()
            action("arrow.2.squarepath", post.repostCount, color: TidePalette.positive) { dependencies.social.repost(post.id) }
            Spacer()
            action(post.isLiked ? "heart.fill" : "heart", post.likeCount, color: post.isLiked ? TidePalette.danger : .secondary) {
                dependencies.social.toggleLike(post.id)
            }
            Spacer()
            action(post.isSaved ? "bookmark.fill" : "bookmark", nil, color: post.isSaved ? TidePalette.positive : .secondary) { dependencies.social.toggleSave(post.id) }
            Spacer()
            action("square.and.arrow.up", nil) {
                dependencies.router.sheet = .share(URL(string: "https://tide.app/post/\(post.id)")!)
            }
        }
    }

    private func action(_ symbol: String, _ count: Int?, color: Color = .secondary, action: @escaping () -> Void) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.42)) {
                action()
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: symbol)
                if let count { Text(count.formatted(.number.notation(.compactName))).font(.caption) }
            }
            .foregroundStyle(color)
            .font(.system(size: 15, weight: .semibold, design: .rounded))
            .padding(.horizontal, 12)
            .frame(height: 34)
            .background(.ultraThinMaterial, in: Capsule())
            .shadow(color: color.opacity(0.16), radius: 12, y: 4)
            .contentShape(Capsule())
        }
        .buttonStyle(TideGlassIconButtonStyle())
    }
}

struct ComposerView: View {
    @Environment(AppDependencies.self) private var dependencies
    @Environment(\.dismiss) private var dismiss
    @State private var bodyText = ""
    @State private var visibility = PostVisibility.everyone
    @State private var location = ""

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            AvatarView(user: dependencies.session.currentUser ?? User(id: UUID(), name: "Tide", username: "tide", biography: "", avatarSymbol: "person.crop.circle.fill", isVerified: false, isAdministrator: false, followers: 0, following: 0, joinedAt: .now, coverSymbol: "water"), size: 38)
                            VStack(alignment: .leading, spacing: 2) {
                        Text("Публикует")
                            .font(.caption).foregroundStyle(.secondary)
                                Text(dependencies.session.currentUser?.handle ?? "@tide")
                                    .font(.subheadline.weight(.semibold))
                            }
                            Spacer()
                            TextField("Локация", text: $location)
                                .frame(width: 120)
                                .textInputAutocapitalization(.never)
                        }
                        ZStack(alignment: .topLeading) {
                            if bodyText.isEmpty {
                                Text("Что у вас нового?")
                                    .foregroundStyle(.secondary)
                                    .padding(.top, 8)
                                    .padding(.leading, 5)
                            }
                            TextEditor(text: $bodyText)
                                .frame(minHeight: 160)
                                .scrollContentBackground(.hidden)
                        }
                        HStack(spacing: 10) {
                            actionTile(symbol: "location.fill", title: "Локация")
                            actionTile(symbol: "clock.badge.checkmark", title: "Запланировать")
                        }
                    }
                } header: {
                    EmptyView()
                }
                Picker("Видимость", selection: $visibility) {
                    ForEach(PostVisibility.allCases) { Text($0.title).tag($0) }
                }
            }
            .navigationTitle("Новый пост")
            .navigationBarTitleDisplayMode(.inline)
            .scrollContentBackground(.hidden)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Отмена") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Опубликовать", action: publish)
                        .disabled(bodyText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .task { restoreDraft() }
            .onDisappear { saveDraftIfNeeded() }
        }
    }

    private func actionTile(symbol: String, title: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: symbol)
                .font(.title3)
            Text(title)
                .font(.caption2.weight(.semibold))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(TidePalette.subtle, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func publish() {
        guard let user = dependencies.session.currentUser else { return }
        dependencies.social.createPost(body: bodyText, visibility: visibility, author: user, media: [], location: location.isEmpty ? nil : location)
        if let draft = dependencies.database.postDraft(ownerID: user.id) { dependencies.database.deleteDraft(draft) }
        bodyText = ""
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
              !bodyText.isEmpty else { return }
        dependencies.database.saveDraft(ownerID: user.id, text: bodyText, visibility: visibility, mediaURLs: [])
    }
}

struct PostDetailView: View {
    @Environment(AppDependencies.self) private var dependencies
    @Environment(\.dismiss) private var dismiss
    let postID: UUID
    @State private var reply = ""

    private var comments: [Comment] { dependencies.social.comments(postID: postID) }

    var body: some View {
        Group {
            if let post = dependencies.social.posts.first(where: { $0.id == postID }) {
                ScrollView {
                    VStack(spacing: 18) {
                        topBar
                        PostCard(post: post, mode: .detail)
                            .background(.clear)
                        repliesSection
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 18)
                }
                .safeAreaInset(edge: .bottom) {
                    replyComposer
                }
            } else {
                EmptyStateView(symbol: "exclamationmark.triangle", title: "Пост недоступен", message: "Возможно, он был удалён.")
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
        .navigationBarBackButtonHidden(true)
    }

    private func sendReply() {
        guard let authorID = dependencies.session.currentUser?.id else { return }
        withAnimation(.easeInOut(duration: 0.42)) {
            dependencies.social.createComment(postID: postID, authorID: authorID, body: reply)
            reply = ""
        }
    }

    private var topBar: some View {
        HStack {
            Button { dismiss() } label: {
                Image(systemName: "chevron.left.circle.fill")
                    .font(.system(size: 34, weight: .semibold))
                    .symbolRenderingMode(.hierarchical)
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)
            Spacer()
            Text("Пост")
                .font(.system(size: 15, weight: .semibold))
            Spacer()
            Color.clear.frame(width: 36, height: 36)
        }
    }

    private var repliesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Ответы")
                .font(.system(size: 15, weight: .semibold))
            if comments.isEmpty {
                EmptyRepliesState()
                    .padding(.vertical, 18)
            } else {
                VStack(spacing: 16) {
                    ForEach(comments) { comment in
                        VStack(alignment: .leading, spacing: 7) {
                            UserRow(user: comment.author)
                            Text(comment.body)
                        }
                        .padding(.vertical, 10)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var replyComposer: some View {
        HStack(spacing: 12) {
            TextField("Ваш ответ", text: $reply, axis: .vertical)
                .lineLimit(1...4)
                .textInputAutocapitalization(.sentences)
                .autocorrectionDisabled(false)
                .tint(.primary)
                .padding(.vertical, 10)
                .padding(.leading, 14)
            Button(action: sendReply) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 16, weight: .black))
                    .foregroundStyle(.primary)
                    .frame(width: 38, height: 38)
            }
            .disabled(reply.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            .buttonStyle(.plain)
            .opacity(reply.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.35 : 1)
            .padding(.trailing, 8)
        }
        .background(.regularMaterial, in: Capsule())
        .padding(.horizontal, 16)
        .padding(.bottom, 10)
    }
}

struct EmptyRepliesState: View {
    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: "bubble.left")
                .font(.system(size: 22, weight: .regular))
                .foregroundStyle(.secondary)
            Text("Ответов нет")
                .font(.system(size: 15, weight: .semibold))
            Text("Начните разговор.")
                .font(.system(size: 13, weight: .regular))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 18)
        .background(.clear)
    }
}
struct TrendsView: View {
    var body: some View {
        ContentUnavailableView("Трендов пока нет", systemImage: "chart.bar.xaxis", description: Text("Популярные темы появятся, когда в ленте будет больше живого контента."))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 40)
    }
}
