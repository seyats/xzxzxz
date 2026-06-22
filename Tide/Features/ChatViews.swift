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

            Picker("Фильтр", selection: $filter) {
                Text("Все").tag(ChatKind?.none)
                ForEach(ChatKind.allCases) { Text($0.title).tag(Optional($0)) }
            }
            .pickerStyle(.segmented)
            .tint(TidePalette.success)
            .listRowSeparator(.hidden)

            ForEach(filteredChats) { chat in
                Button {
                    messenger.markRead(chat.id)
                    dependencies.router.push(.chat(chat.id))
                } label: {
                    ChatRow(chat: chat)
                }
                .buttonStyle(.plain)
                .swipeActions(edge: .leading) {
                    Button { messenger.togglePin(chat.id) } label: {
                        Label(chat.isPinned ? "Открепить" : "Закрепить", systemImage: "pin")
                    }
                    .tint(TidePalette.success)

                    Button { messenger.toggleMute(chat.id) } label: {
                        Label(chat.isMuted ? "Включить звук" : "Выключить звук", systemImage: "bell.slash")
                    }
                    .tint(.orange)
                }
                .swipeActions(edge: .trailing) {
                    Button("Удалить", role: .destructive) { messenger.delete(chat.id) }
                    Button("В архив") { messenger.archive(chat.id) }
                        .tint(.secondary)
                }
            }
        }
        .listStyle(.plain)
        .searchable(text: $messenger.query, prompt: "Чаты и сообщения")
        .refreshable { messenger.reload() }
        .navigationTitle("Чаты")
        .scrollContentBackground(.hidden)
        .toolbar {
            Button { dependencies.router.sheet = .newMessage } label: {
                Image(systemName: "square.and.pencil")
            }
        }
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
                Circle()
                    .fill(TidePalette.subtle)
                    .frame(width: 52, height: 52)
                Image(systemName: chat.avatarSymbol)
                    .font(.title3)
            }

            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 6) {
                    Text(chat.title)
                        .font(TideTypography.headline)
                        .lineLimit(1)
                    if chat.isMuted {
                        Image(systemName: "bell.slash.fill")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    if chat.isPinned {
                        Image(systemName: "pin.fill")
                            .font(.caption)
                            .foregroundStyle(TidePalette.success)
                    }
                    Spacer()
                    Text(chat.lastMessage?.sentAt.formatted(date: .omitted, time: .shortened) ?? "")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                HStack {
                    if chat.lastMessage?.attachmentKind != .none {
                        Image(systemName: "paperclip")
                            .foregroundStyle(.secondary)
                    }
                    Text(chat.lastMessage?.body.isEmpty == false ? chat.lastMessage?.body ?? "" : "Вложение")
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    Spacer()
                    if chat.unreadCount > 0 {
                        Text("\(chat.unreadCount)")
                            .font(.caption2.bold())
                            .padding(6)
                            .background(TidePalette.success, in: Circle())
                            .foregroundStyle(.white)
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
                    LazyVStack(spacing: 7) {
                        ForEach(chat.messages.filter { $0.deletedAt == nil || !$0.body.isEmpty }) { message in
                            MessageBubble(
                                message: message,
                                chatID: chatID,
                                isOutgoing: message.senderID == dependencies.session.currentUser?.id
                            ) {
                                replyTo = message
                            }
                            .id(message.id)
                            .transition(.asymmetric(
                                insertion: .opacity.combined(with: .move(edge: .bottom)).combined(with: .scale(scale: 0.96)),
                                removal: .opacity
                            ))
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                }
                .background(chatBackdrop)
                .defaultScrollAnchor(.bottom)
                .safeAreaInset(edge: .bottom) { composer }
                .onChange(of: chat.messages.count) { _, _ in
                    if let id = chat.messages.last?.id {
                        withAnimation(.easeInOut(duration: 0.52)) {
                            proxy.scrollTo(id, anchor: .bottom)
                        }
                    }
                }
                .animation(.easeInOut(duration: 0.38), value: chat.messages.count)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(.hidden, for: .tabBar)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    ConversationToolbarTitle(chat: chat)
                }
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button { dependencies.router.push(.call(chatID, false)) } label: {
                        Image(systemName: "phone")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(TidePalette.success)
                            .frame(width: 34, height: 34)
                            .background(AuthGlassBackground(cornerRadius: 17, interactive: true))
                    }
                    .buttonStyle(AuthSmoothButtonStyle())
                    Button { dependencies.router.push(.call(chatID, true)) } label: {
                        Image(systemName: "video")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(TidePalette.success)
                            .frame(width: 34, height: 34)
                            .background(AuthGlassBackground(cornerRadius: 17, interactive: true))
                    }
                    .buttonStyle(AuthSmoothButtonStyle())
                }
            }
            .task { dependencies.messenger.markRead(chatID) }
            .onChange(of: selectedItem) { item in
                guard let item else { return }
                Task {
                    if let imported = try? await MediaLibrary.shared.importItems([item]) {
                        attachment = imported.first
                    }
                }
            }
        } else {
            EmptyStateView(
                symbol: "bubble.left",
                title: "Чат недоступен",
                message: "Эта беседа больше не существует."
            )
        }
    }

    private var chatBackdrop: some View {
        LinearGradient(
            colors: [
                Color(uiColor: .systemBackground),
                TidePalette.success.opacity(0.06),
                Color(uiColor: .systemBackground)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }

    private var composer: some View {
        VStack(spacing: 8) {
            if let replyTo {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Ответ")
                            .font(.caption.bold())
                        Text(replyTo.body)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    Spacer()
                    Button { self.replyTo = nil } label: {
                        Image(systemName: "xmark.circle.fill")
                    }
                }
                .padding(.horizontal, 14)
                .padding(.top, 8)
            }

            if let attachment {
                ComposerMediaStrip(media: [attachment]) { media in
                    self.attachment = nil
                    Task { await MediaLibrary.shared.remove(media) }
                }
                .padding(.horizontal, 14)
            }

            HStack(spacing: 9) {
                PhotosPicker(selection: $selectedItem, matching: .any(of: [.images, .videos])) {
                    Image(systemName: "plus")
                        .font(.system(size: 17, weight: .semibold))
                        .frame(width: 34, height: 34)
                        .foregroundStyle(TidePalette.success)
                        .tideGlass(interactive: true, cornerRadius: 17, tint: TidePalette.success.opacity(0.08))
                }

                TextField("Сообщение", text: $draft, axis: .vertical)
                    .lineLimit(1...5)
                    .padding(.horizontal, 13)
                    .padding(.vertical, 9)
                    .background(AuthGlassBackground(cornerRadius: 18, interactive: true))
                    .overlay {
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(TidePalette.separator, lineWidth: 0.6)
                    }

                Button(action: send) {
                    Image(systemName: draft.isEmpty && attachment == nil ? "mic.fill" : "arrow.up")
                        .font(.system(size: 17, weight: .bold))
                        .frame(width: 34, height: 34)
                        .foregroundStyle(.white)
                        .background(canSend ? TidePalette.success : .secondary.opacity(0.45), in: Circle())
                }
                .disabled(!canSend)
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 9)
        }
        .padding(.top, 8)
        .background(.ultraThinMaterial)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(.white.opacity(0.08))
                .frame(height: 0.6)
        }
    }

    private var canSend: Bool {
        !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || attachment != nil
    }

    private func send() {
        let message = draft
        let outgoingAttachment = attachment
        let replyID = replyTo?.id
        withAnimation(.easeInOut(duration: 0.32)) {
            draft = ""
            attachment = nil
            replyTo = nil
        }
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

private struct ConversationToolbarTitle: View {
    let chat: Chat

    var body: some View {
        HStack(spacing: 9) {
            Image(systemName: chat.avatarSymbol)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 32, height: 32)
                .background(TidePalette.success.gradient, in: Circle())

            VStack(alignment: .leading, spacing: 1) {
                Text(chat.title)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .lineLimit(1)
                Text(chat.participants.count > 2 ? "\(chat.participants.count) участников" : "в сети")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: 210, alignment: .leading)
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
                    Label("Ответ", systemImage: "arrowshape.turn.up.left.fill")
                        .font(.caption2)
                        .foregroundStyle(isOutgoing ? .white.opacity(0.72) : .secondary)
                }

                if message.attachmentKind != .none, let url = message.attachmentURL {
                    PostMediaCell(media: MediaAttachment(
                        id: message.id,
                        kind: message.attachmentKind == .video ? .video : .photo,
                        url: url,
                        aspectRatio: 1.4
                    ))
                    .frame(maxWidth: 250, minHeight: 140, maxHeight: 220)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }

                if !message.body.isEmpty {
                    Text(message.body)
                        .font(.system(size: 16, weight: .regular, design: .rounded))
                }

                HStack(spacing: 4) {
                    if message.isEdited { Text("изменено") }
                    Text(message.sentAt.formatted(date: .omitted, time: .shortened))
                    if isOutgoing { deliverySymbol }
                }
                .font(.caption2)
                .foregroundStyle(isOutgoing ? .white.opacity(0.68) : .secondary)

                if let reaction = message.reaction {
                    Text(reaction)
                        .padding(5)
                        .background(.regularMaterial, in: Circle())
                        .offset(y: 12)
                }
            }
            .padding(.horizontal, 13)
            .padding(.vertical, 9)
            .background(bubbleBackground)
            .foregroundStyle(isOutgoing ? .white : TidePalette.ink)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .contextMenu {
                Button("Ответить", systemImage: "arrowshape.turn.up.left", action: reply)
                Menu("Реакция") {
                    ForEach(["❤️", "🔥", "😂", "😮", "😢", "👏"], id: \.self) { reaction in
                        Button(reaction) {
                            dependencies.messenger.react(reaction, messageID: message.id, chatID: chatID)
                        }
                    }
                }
                Button("Пожаловаться", systemImage: "exclamationmark.bubble", role: .destructive) {
                    dependencies.router.sheet = .report(message.id, "message")
                }
                if isOutgoing {
                    Button("Удалить", systemImage: "trash", role: .destructive) {
                        dependencies.messenger.deleteMessage(message.id, chatID: chatID)
                    }
                }
            }

            if !isOutgoing { Spacer(minLength: 52) }
        }
    }

    private var bubbleBackground: some ShapeStyle {
        isOutgoing ? AnyShapeStyle(TidePalette.success.gradient) : AnyShapeStyle(.regularMaterial)
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
                Button { createChat(with: user) } label: {
                    UserRow(user: user)
                }
                .buttonStyle(.plain)
            }
            .searchable(text: $query, prompt: "Имя или ник")
            .navigationTitle("Новое сообщение")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") { dismiss() }
                }
            }
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
                Color.black.ignoresSafeArea()
                VStack(spacing: 28) {
                    Spacer()
                    if let chat = dependencies.messenger.chat(id: chatID) {
                        ZStack {
                            Circle()
                                .fill(.white.opacity(0.12))
                                .frame(width: 132, height: 132)
                            Image(systemName: chat.avatarSymbol)
                                .font(.system(size: 52))
                                .foregroundStyle(.white)
                        }
                        Text(chat.title)
                            .font(.largeTitle.bold())
                            .foregroundStyle(.white)
                    }
                    Text(duration(from: startedAt, to: context.date))
                        .font(.title3.monospacedDigit())
                        .foregroundStyle(.white.opacity(0.7))
                    Spacer()
                    HStack(spacing: 16) {
                        callButton(isMuted ? "mic.slash.fill" : "mic.fill", active: isMuted) { isMuted.toggle() }
                        if isVideo {
                            callButton(cameraEnabled ? "video.fill" : "video.slash.fill", active: !cameraEnabled) { cameraEnabled.toggle() }
                        }
                        callButton(speakerEnabled ? "speaker.wave.2.fill" : "speaker.slash.fill", active: !speakerEnabled) { speakerEnabled.toggle() }
                        callButton("phone.down.fill", color: TidePalette.danger) { dismiss() }
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
            Image(systemName: symbol)
                .font(.title2)
                .foregroundStyle(.white)
                .frame(width: 58, height: 58)
                .background(active ? TidePalette.success.opacity(0.7) : color, in: Circle())
        }
    }

    private func duration(from: Date, to: Date) -> String {
        let seconds = max(0, Int(to.timeIntervalSince(from)))
        return String(format: "%02d:%02d", seconds / 60, seconds % 60)
    }
}
