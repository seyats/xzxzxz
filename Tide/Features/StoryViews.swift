import AVKit
import PhotosUI
import SwiftUI

struct StoryViewer: View {
    @Environment(AppDependencies.self) private var dependencies
    @Environment(\.dismiss) private var dismiss
    let storyID: UUID
    @State private var progress = 0.0
    @State private var reply = ""
    @State private var isPaused = false
    @State private var hasReacted = false

    private var story: Story? { dependencies.social.stories.first { $0.id == storyID } }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            if let story {
                storyContent(story)
                VStack(spacing: 12) {
                    ProgressView(value: progress).tint(.white)
                    HStack {
                        AvatarView(user: story.author)
                        VStack(alignment: .leading) {
                            VerifiedName(user: story.author).foregroundStyle(.white)
                            Text(story.createdAt.formatted(.relative(presentation: .named))).font(.caption).foregroundStyle(.white.opacity(0.7))
                        }
                        Spacer()
                        Button { dismiss() } label: { Image(systemName: "xmark").font(.title2).foregroundStyle(.white) }
                    }
                    Spacer()
                    if !story.caption.isEmpty {
                        Text(story.caption).font(.title3.bold()).foregroundStyle(.white).multilineTextAlignment(.center).padding()
                    }
                    HStack {
                        TextField("Reply…", text: $reply)
                            .padding(.horizontal, 14).padding(.vertical, 10)
                            .background(.white.opacity(0.16), in: Capsule()).foregroundStyle(.white)
                        Button { sendReply(to: story) } label: { Image(systemName: "paperplane.fill").foregroundStyle(.white) }
                            .disabled(reply.isEmpty)
                        Button { react(to: story) } label: { Image(systemName: hasReacted ? "heart.fill" : "heart").foregroundStyle(.white) }
                    }
                }
                .padding()
                .contentShape(Rectangle())
                .onLongPressGesture(minimumDuration: 0.15, pressing: { isPaused = $0 }, perform: {})
            } else {
                ContentUnavailableView("Story expired", systemImage: "clock.badge.xmark")
                    .foregroundStyle(.white)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
        .task(id: isPaused) {
            guard story != nil, !isPaused else { return }
            dependencies.social.markStoryViewed(storyID)
            while progress < 1, !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(50))
                progress += 0.01
            }
            if progress >= 1 { dismiss() }
        }
    }

    @ViewBuilder
    private func storyContent(_ story: Story) -> some View {
        if let url = story.mediaURL {
            if story.mediaKind == .video {
                VideoPlayer(player: AVPlayer(url: url)).ignoresSafeArea()
            } else {
                AsyncImage(url: url) { phase in
                    if let image = phase.image { image.resizable().scaledToFill().ignoresSafeArea() }
                    else { Color.black.ignoresSafeArea(); ProgressView().tint(.white) }
                }
            }
        } else {
            LinearGradient(colors: [.gray.opacity(0.8), .black], startPoint: .top, endPoint: .bottom).ignoresSafeArea()
            Image(systemName: story.symbol).font(.system(size: 110, weight: .thin)).foregroundStyle(.white)
        }
    }

    private func sendReply(to story: Story) {
        guard let currentUser = dependencies.session.currentUser else { return }
        let chatID = dependencies.messenger.createDirectChat(currentUser: currentUser, otherUser: story.author)
        let text = reply
        reply = ""
        Task { await dependencies.messenger.send("Replied to your story: \(text)", to: chatID, senderID: currentUser.id) }
    }

    private func react(to story: Story) {
        hasReacted.toggle()
        if hasReacted {
            dependencies.notifications.add(kind: .storyReply, title: "Story reaction sent", body: "You reacted to \(story.author.name)'s story", targetID: story.id)
        }
    }
}

struct StoryComposerView: View {
    @Environment(AppDependencies.self) private var dependencies
    @Environment(\.dismiss) private var dismiss
    @State private var selectedItem: PhotosPickerItem?
    @State private var media: ComposerMedia?
    @State private var caption = ""
    @State private var isLoading = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Group {
                    if let media {
                        PostMediaCell(media: MediaAttachment(id: media.id, kind: media.kind, url: media.url, aspectRatio: media.aspectRatio))
                    } else {
                        ContentUnavailableView("Choose a photo or video", systemImage: "photo.on.rectangle.angled")
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: 24))
                TextField("Caption", text: $caption, axis: .vertical).textFieldStyle(.roundedBorder)
                PhotosPicker(selection: $selectedItem, matching: .any(of: [.images, .videos])) {
                    Label(media == nil ? "Choose media" : "Replace media", systemImage: "photo.badge.plus")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(TideSecondaryButtonStyle())
            }
            .padding()
            .navigationTitle("New Story")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Publish", action: publish).disabled(media == nil || isLoading) }
            }
            .onChange(of: selectedItem) { _, item in
                guard let item else { return }
                Task {
                    isLoading = true
                    defer { isLoading = false }
                    if let items = try? await MediaLibrary.shared.importItems([item]) { media = items.first }
                }
            }
        }
    }

    private func publish() {
        guard let user = dependencies.session.currentUser, let media else { return }
        dependencies.social.createStory(author: user, mediaURL: media.url, mediaKind: media.kind, caption: caption)
        dismiss()
    }
}
