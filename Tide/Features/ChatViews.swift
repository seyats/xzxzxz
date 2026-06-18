import PhotosUI
import SwiftUI

struct ChatListView: View {
    @Environment(AppDependencies.self) private var dependencies
    @State private var filter: ChatKind?

    var body: some View {
        @Bindable var messenger = dependencies.messenger
        List {
            TideConnectionBadge(state: messenger.connectionState)
                .listRowSeparator(.hidden)
            Picker("Filter", selection: $filter) {
                Text("All").tag(ChatKind?.none)
                ForEach(ChatKind.allCases) { Text($0.rawValue.capitalized).tag(Optional($0)) }
            }
            .pickerStyle(.segmented)
            .listRowSeparator(.hidden)
            ForEach(filteredChats) { chat in
                Button {
                    messenger.markRead(chat.id)
                    dependencies.router.push(.chat(chat.id))
                } label: { ChatRow(chat: chat) }
                    .buttonStyle(.plain)
                    .swipeActions(edge: .leading) {
                        Button { messenger.togglePin(chat.id) } label: { Label(chat.isPinned ? "Unpin" : "Pin", systemImage: "pin") }
                        Button { messenger.toggleMute(chat.id) } label: { Label(chat.isMuted ? "Unmute" : "Mute", systemImage: "bell.slash") }
                    }
                    .swipeActions(edge: .trailing) {
                        Button("Delete", role: .destructive) { messenger.delete(chat.id) }
                        Button("Archive") { messenger.archive(chat.id) }.tint(.secondary)
                    }
            }
        }
        .listStyle(.plain)
        .searchable(text: $messenger.query, prompt: "Chats and messages")
        .refreshable { messenger.reload() }
        .navigationTitle("Chats")
        .scrollContentBackground(.hidden)
        .toolbar { Button { dependencies.router.sheet = .newMessage } label: { Image(systemName: "square.and.pencil") } }
    }

    private var filteredChats: [Chat] {
        dependencies.messenger.filteredChats.filter { filter == nil || $0.kind == filter }
    }
}

struct ChatRow: View {
    let chat: Chat

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle().fill(TidePalette.subtle).frame(width: 54, height: 54)
                Image(systemName: chat.avatarSymbol).font(.title2)
            }
            VStack(alignment: .leading, spacing: 5) {
                HStack {
                    Text(chat.title).font(TideTypography.headline)
                    if chat.isMuted { Image(systemName: "bell.slash.fill").font(.caption).foregroundStyle(.secondary) }
                    if chat.isPinned { Image(systemName: "pin.fill").font(.caption).foregroundStyle(.secondary) }
                    Spacer()
                    Text(chat.lastMessage?.sentAt.formatted(date: .omitted, time: .shortened) ?? "")
                        .font(.caption).foregroundStyle(.secondary)
                }
                HStack {
                    if chat.lastMessage?.attachmentKind != .none { Image(systemName: "paperclip").foregroundStyle(.secondary) }
                    Text(chat.lastMessage?.body.isEmpty == false ? chat.lastMessage?.body ?? "" : "Attachment")
                        .foregroundStyle(.secondary).lineLimit(1)
                    Spacer()
                    if chat.unreadCount > 0 {
                        Text("\(chat.unreadCount)")
                            .font(.caption2.bold())
                            .padding(6)
                            .background(TidePalette.success, in: Circle())
                            .foregroundStyle(TidePalette.inverse)
                    }
                }
            }
        }
        .padding(.vertical, 5)
    }
}

struct ConversationView: View {
    @Environment(AppDependencies.self) private var dependencies
    let chatID: UUID
    @State private var draft = ""
    @State private var selectedItem: PhotosPickerItem?
    @State private var attachment: ComposerMedia?
    @State private var replyTo: Message?

    var body: some View {
        if let chat = dependencies.messenger.chat(id: chatID) {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(chat.messages.filter { $0.deletedAt == nil || !$0.body.isEmpty }) { message in
                            MessageBubble(message: message, chatID: chatID, isOutgoing: message.senderID == dependencies.session.currentUser?.id) {
                                replyTo = message
                            }
                            .id(message.id)
                        }
                    }
                    .padding()
                }
                .defaultScrollAnchor(.bottom)
                .safeAreaInset(edge: .bottom) { composer }
                .onChange(of: chat.messages.count) { _, _ in
                    if let id = chat.messages.last?.id { withAnimation { proxy.scrollTo(id, anchor: .bottom) } }
                }
            }
            .navigationTitle(chat.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(.hidden, for: .tabBar)
            .toolbar {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button { dependencies.router.push(.call(chatID, false)) } label: { Image(systemName: "phone") }
                    Button { dependencies.router.push(.call(chatID, true)) } label: { Image(systemName: "video") }
                }
            }
            .task { dependencies.messenger.markRead(chatID) }
            .onChange(of: selectedItem) { _, item in
                guard let item else { return }
                Task {
                    if let imported = try? await MediaLibrary.shared.importItems([item]) {
                        attachment = imported.first
                    }
                }
            }
        } else {
            EmptyStateView(symbol: "bubble.left", title: "Chat unavailable", message: "This conversation no longer exists.")
        }
    }

    private var composer: some View {
        VStack(spacing: 0) {
            if let replyTo {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Replying").font(.caption.bold())
                        Text(replyTo.body).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                    }
                    Spacer()
                    Button { self.replyTo = nil } label: { Image(systemName: "xmark.circle.fill") }
                }
                .padding(.horizontal)
                .padding(.top, 8)
            }
            if let attachment {
                ComposerMediaStrip(media: [attachment]) { media in
                    self.attachment = nil
                    Task { await MediaLibrary.shared.remove(media) }
                }
                .padding(.horizontal)
            }
            HStack(spacing: 10) {
                PhotosPicker(selection: $selectedItem, matching: .any(of: [.images, .videos])) {
                    Image(systemName: "plus.circle.fill").font(.title2)
                }
                TextField("Message", text: $draft, axis: .vertical)
                    .lineLimit(1...5)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 9)
                    .background(TidePalette.subtle, in: RoundedRectangle(cornerRadius: 18))
                Button(action: send) {
                    Image(systemName: draft.isEmpty && attachment == nil ? "mic.fill" : "arrow.up.circle.fill").font(.title2)
                }
                .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && attachment == nil)
            }
            .padding(.horizontal)
            .padding(.vertical, 10)
        }
        .background(.bar)
    }

    private func send() {
        let message = draft
        let outgoingAttachment = attachment
        let replyID = replyTo?.id
        draft = ""
        attachment = nil
        replyTo = nil
        guard let senderID = dependencies.session.currentUser?.id else { return }
        Task {
            await dependencies.messenger.send(
                message,
                to: chatID,
                senderID: senderID,
                attachmentURL: outgoingAttachment?.url,
                attachmentKind: outgoingAttachment?.kind == .video ? .video : outgoingAttachment == nil ? .none : .photo,
                replyTo: replyID
            )
        }
    }
}

struct MessageBubble: View {
    @Environment(AppDependencies.self) private var dependencies
    let message: Message
    let chatID: UUID
    let isOutgoing: Bool
    let reply: () -> Void

    var body: some View {
        HStack {
            if isOutgoing { Spacer(minLength: 52) }
            VStack(alignment: .leading, spacing: 6) {
                if message.replyToMessageID != nil {
                    Label("Reply", systemImage: "arrowshape.turn.up.left.fill")
                        .font(.caption2).foregroundStyle(.secondary)
                }
                if message.attachmentKind != .none, let url = message.attachmentURL {
                    PostMediaCell(media: MediaAttachment(
                        id: message.id,
                        kind: message.attachmentKind == .video ? .video : .photo,
                        url: url,
                        aspectRatio: 1.4
                    ))
                    .frame(maxWidth: 250, minHeight: 140, maxHeight: 220)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                if !message.body.isEmpty { Text(message.body) }
                HStack(spacing: 4) {
                    if message.isEdited { Text("edited") }
                    Text(message.sentAt.formatted(date: .omitted, time: .shortened))
                    if isOutgoing { deliverySymbol }
                }
                .font(.caption2).foregroundStyle(.secondary)
                if let reaction = message.reaction {
                    Text(reaction).padding(5).background(TidePalette.paper, in: Circle()).offset(y: 12)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .background(isOutgoing ? TidePalette.ink : TidePalette.subtle, in: RoundedRectangle(cornerRadius: 18))
            .foregroundStyle(isOutgoing ? TidePalette.inverse : TidePalette.ink)
            .contextMenu {
                Button("Reply", systemImage: "arrowshape.turn.up.left", action: reply)
                Menu("React") {
                    ForEach(["❤", "🔥", "😂", "😮", "😢", "👏"], id: \.self) { reaction in
                        Button(reaction) { dependencies.messenger.react(reaction, messageID: message.id, chatID: chatID) }
                    }
                }
                Button("Report", systemImage: "exclamationmark.bubble", role: .destructive) {
                    dependencies.router.sheet = .report(message.id, "message")
                }
                if isOutgoing {
                    Button("Delete", systemImage: "trash", role: .destructive) {
                        dependencies.messenger.deleteMessage(message.id, chatID: chatID)
                    }
                }
            }
            if !isOutgoing { Spacer(minLength: 52) }
        }
    }

    @ViewBuilder
    private var deliverySymbol: some View {
        switch message.state {
        case .sending: ProgressView().controlSize(.mini)
        case .sent: Image(systemName: "checkmark")
        case .delivered: Image(systemName: "checkmark.circle")
        case .read: Image(systemName: "checkmark.circle.fill")
        case .failed: Image(systemName: "exclamationmark.circle.fill")
        }
    }
}

struct NewMessageView: View {
    @Environment(AppDependencies.self) private var dependencies
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""

    var body: some View {
        NavigationStack {
            List(filteredUsers) { user in
                Button { createChat(with: user) } label: { UserRow(user: user) }.buttonStyle(.plain)
            }
            .searchable(text: $query, prompt: "Name or username")
            .navigationTitle("New Message")
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } } }
        }
    }

    private var filteredUsers: [User] {
        dependencies.database.users().filter { user in
            user.id != dependencies.session.currentUser?.id
                && (query.isEmpty || user.name.localizedCaseInsensitiveContains(query) || user.username.localizedCaseInsensitiveContains(query))
        }
    }

    private func createChat(with user: User) {
        guard let currentUser = dependencies.session.currentUser else { return }
        let id = dependencies.messenger.createDirectChat(currentUser: currentUser, otherUser: user)
        dismiss()
        dependencies.router.push(.chat(id), tab: .chats)
    }
}

struct CallView: View {
    @Environment(AppDependencies.self) private var dependencies
    @Environment(\.dismiss) private var dismiss
    let chatID: UUID
    let isVideo: Bool
    @State private var isMuted = false
    @State private var speakerEnabled = true
    @State private var cameraEnabled = true
    @State private var startedAt = Date.now

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            ZStack {
                TidePalette.ink.ignoresSafeArea()
                VStack(spacing: 28) {
                    Spacer()
                    if let chat = dependencies.messenger.chat(id: chatID) {
                        ZStack {
                            Circle().fill(.white.opacity(0.12)).frame(width: 132, height: 132)
                            Image(systemName: chat.avatarSymbol).font(.system(size: 52)).foregroundStyle(.white)
                        }
                        Text(chat.title).font(.largeTitle.bold()).foregroundStyle(.white)
                    }
                    Text(duration(from: startedAt, to: context.date)).font(.title3.monospacedDigit()).foregroundStyle(.white.opacity(0.7))
                    Spacer()
                    HStack(spacing: 20) {
                        callButton(isMuted ? "mic.slash.fill" : "mic.fill", active: isMuted) { isMuted.toggle() }
                        if isVideo { callButton(cameraEnabled ? "video.fill" : "video.slash.fill", active: !cameraEnabled) { cameraEnabled.toggle() } }
                        callButton(speakerEnabled ? "speaker.wave.2.fill" : "speaker.slash.fill", active: !speakerEnabled) { speakerEnabled.toggle() }
                        callButton("phone.down.fill", color: .red) { dismiss() }
                    }
                    .padding(.bottom, 38)
                }
            }
        }
        .navigationBarBackButtonHidden()
        .toolbar(.hidden, for: .tabBar)
    }

    private func callButton(_ symbol: String, active: Bool = false, color: Color = .white.opacity(0.16), action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol).font(.title2).foregroundStyle(.white).frame(width: 62, height: 62)
                .background(active ? .white.opacity(0.35) : color, in: Circle())
        }
    }

    private func duration(from: Date, to: Date) -> String {
        let seconds = max(0, Int(to.timeIntervalSince(from)))
        return String(format: "%02d:%02d", seconds / 60, seconds % 60)
    }
}
