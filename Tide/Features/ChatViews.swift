import AVFoundation
import PhotosUI
import SwiftUI
import UniformTypeIdentifiers
import UIKit

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
            .tint(.primary)
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
                    .tint(.gray)

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
                    .font(.system(size: 14, weight: .semibold))
                    .frame(width: 34, height: 34)
                    .background(AuthGlassBackground(cornerRadius: 17, interactive: true))
            }
            .buttonStyle(TideGlassIconButtonStyle())
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
                            .foregroundStyle(.secondary)
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
                            .background(Color.primary.opacity(0.24), in: Circle())
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
    @Environment(\.dismiss) private var dismiss
    let chatID: UUID
    @State private var draft = ""
    @State private var selectedItem: PhotosPickerItem?
    @State private var attachment: ComposerMedia?
    @State private var replyTo: Message?
    @State private var isImportingFile = false
    @State private var isShowingCamera = false
    @State private var recorder: AVAudioRecorder?
    @State private var isRecordingVoice = false
    @State private var recorderError: String?

    var body: some View {
        if let chat = dependencies.messenger.chat(id: chatID) {
            ZStack {
                chatBackdrop
                VStack(spacing: 0) {
                    chatHeader(chat)
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                        .padding(.bottom, 8)

                    ScrollViewReader { proxy in
                        ScrollView {
                            LazyVStack(spacing: 7) {
                                ForEach(chat.messages.filter { $0.deletedAt == nil || !$0.body.isEmpty || $0.attachmentURL != nil }) { message in
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
                        .defaultScrollAnchor(.bottom)
                        .onChange(of: chat.messages.count) { _, _ in
                            if let id = chat.messages.last?.id {
                                withAnimation(.easeInOut(duration: 0.52)) {
                                    proxy.scrollTo(id, anchor: .bottom)
                                }
                            }
                        }
                        .animation(.easeInOut(duration: 0.38), value: chat.messages.count)
                    }
                    composer
                }
            }
            .navigationBarBackButtonHidden(true)
            .toolbar(.hidden, for: .navigationBar)
            .toolbar(.hidden, for: .tabBar)
            .task { dependencies.messenger.markRead(chatID) }
            .onChange(of: selectedItem) { _, item in
                guard let item else { return }
                Task {
                    if let imported = try? await MediaLibrary.shared.importItems([item]) {
                        attachment = imported.first
                    }
                    selectedItem = nil
                }
            }
            .fileImporter(isPresented: $isImportingFile, allowedContentTypes: [.item], allowsMultipleSelection: false) { result in
                guard case .success(let urls) = result, let url = urls.first else { return }
                Task {
                    if let media = try? await MediaLibrary.shared.importFile(url) {
                        await MainActor.run { attachment = media }
                    }
                }
            }
            .fullScreenCover(isPresented: $isShowingCamera) {
                CameraCaptureView { image in
                    isShowingCamera = false
                    guard let data = image.jpegData(compressionQuality: 0.88) else { return }
                    Task {
                        if let media = try? await MediaLibrary.shared.importImageData(data) {
                            await MainActor.run { attachment = media }
                        }
                    }
                } onCancel: {
                    isShowingCamera = false
                }
            }
            .alert("Не удалось записать голос", isPresented: Binding(get: { recorderError != nil }, set: { if !$0 { recorderError = nil } })) {
                Button("ОК", role: .cancel) {}
            } message: {
                Text(recorderError ?? "")
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
        ZStack {
            TideBackdropView(configuration: dependencies.preferences.backdropConfiguration())
            Color.black.opacity(0.18).ignoresSafeArea()
        }
    }

    private func chatHeader(_ chat: Chat) -> some View {
        HStack(spacing: 12) {
            Button { dismiss() } label: {
                HStack(spacing: 5) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 20, weight: .bold))
                    if chat.unreadCount > 0 {
                        Text("\(chat.unreadCount)")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(.black)
                            .frame(width: 24, height: 24)
                            .background(.white, in: Circle())
                    }
                }
                .foregroundStyle(.white)
                .frame(minWidth: 44, minHeight: 44)
                .background(AuthGlassBackground(cornerRadius: 22, interactive: true))
            }
            .buttonStyle(.plain)

            VStack(spacing: 2) {
                Text(chat.title)
                    .font(.system(size: 17, weight: .semibold))
                    .lineLimit(1)
                Text(lastSeenText(for: chat))
                    .font(.system(size: 12, weight: .regular))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 44)
            .background(AuthGlassBackground(cornerRadius: 22, interactive: false))

            Button {
                dependencies.router.push(.call(chatID, false), tab: .chats)
            } label: {
                Image(systemName: "phone.fill")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(AuthGlassBackground(cornerRadius: 22, interactive: true))
            }
            .buttonStyle(.plain)

            Button {
                dependencies.router.push(.call(chatID, true), tab: .chats)
            } label: {
                Image(systemName: "video.fill")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(AuthGlassBackground(cornerRadius: 22, interactive: true))
            }
            .buttonStyle(.plain)

            Button {
                if let profile = profileTarget(for: chat) {
                    dependencies.router.push(.profile(profile))
                }
            } label: {
                AvatarView(user: profileTarget(for: chat) ?? chat.participants.first ?? fallbackChatUser(chat), size: 44)
                    .overlay(alignment: .bottomTrailing) {
                        Circle()
                            .fill(.green)
                            .frame(width: 8, height: 8)
                            .opacity(chat.kind == .direct ? 1 : 0)
                    }
            }
            .buttonStyle(.plain)
        }
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

            HStack(spacing: 8) {
                attachmentMenu

                HStack(spacing: 8) {
                    TextField("Сообщение", text: $draft, axis: .vertical)
                        .lineLimit(1...5)
                        .textInputAutocapitalization(.sentences)
                    Image(systemName: attachment == nil ? "circle.lefthalf.filled" : "paperclip.circle.fill")
                        .font(.system(size: 19, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
                .font(.system(size: 16, weight: .regular))
                .padding(.horizontal, 14)
                .frame(minHeight: 44)
                .background(AuthGlassBackground(cornerRadius: 22, interactive: true))

                Button(action: primaryComposerAction) {
                    Image(systemName: canSend ? "arrow.up" : isRecordingVoice ? "stop.fill" : "mic.fill")
                        .font(.system(size: 19, weight: .bold))
                        .frame(width: 44, height: 44)
                        .foregroundStyle(.white)
                        .background {
                            Circle()
                                .fill(isRecordingVoice ? Color.red.opacity(0.82) : Color.primary.opacity(0.22))
                                .background(AuthGlassBackground(cornerRadius: 22, interactive: true).clipShape(Circle()))
                        }
                        .scaleEffect(isRecordingVoice ? 1.08 : 1)
                        .animation(.easeInOut(duration: 0.32), value: isRecordingVoice)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 9)
        }
        .padding(.top, 8)
        .background(.ultraThinMaterial.opacity(0.72))
    }

    private var canSend: Bool {
        !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || attachment != nil
    }

    private var attachmentMenu: some View {
        Menu {
            Button {
                isImportingFile = true
            } label: {
                Label("Прикрепить файл", systemImage: "paperclip")
            }
            Button {
                isShowingCamera = true
            } label: {
                Label("Снять фото", systemImage: "camera")
            }
            PhotosPicker(selection: $selectedItem, matching: .any(of: [.images, .videos])) {
                Label("Фото/видео из галереи", systemImage: "photo.on.rectangle")
            }
        } label: {
            Image(systemName: "paperclip")
                .font(.system(size: 22, weight: .medium))
                .foregroundStyle(.white)
                .frame(width: 44, height: 44)
                .background(AuthGlassBackground(cornerRadius: 22, interactive: true))
        }
        .buttonStyle(.plain)
    }

    private func primaryComposerAction() {
        if canSend {
            send()
        } else {
            toggleVoiceRecording()
        }
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
                attachmentKind: outgoingAttachment?.attachmentKind ?? .none,
                replyTo: replyID
            )
        }
    }

    private func toggleVoiceRecording() {
        if isRecordingVoice {
            stopVoiceRecording(sendResult: true)
        } else {
            startVoiceRecording()
        }
    }

    private func startVoiceRecording() {
        AVAudioSession.sharedInstance().requestRecordPermission { granted in
            Task { @MainActor in
                guard granted else {
                    recorderError = "Разрешите доступ к микрофону в настройках iOS."
                    return
                }
                do {
                    let session = AVAudioSession.sharedInstance()
                    try session.setCategory(.playAndRecord, mode: .spokenAudio, options: [.defaultToSpeaker])
                    try session.setActive(true)
                    let url = try await MediaLibrary.shared.voiceRecordingURL()
                    let settings: [String: Any] = [
                        AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
                        AVSampleRateKey: 44_100,
                        AVNumberOfChannelsKey: 1,
                        AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
                    ]
                    let recorder = try AVAudioRecorder(url: url, settings: settings)
                    recorder.record()
                    self.recorder = recorder
                    withAnimation(.easeInOut(duration: 0.25)) {
                        isRecordingVoice = true
                    }
                } catch {
                    recorderError = error.localizedDescription
                }
            }
        }
    }

    private func stopVoiceRecording(sendResult: Bool) {
        guard let recorder else { return }
        recorder.stop()
        self.recorder = nil
        withAnimation(.easeInOut(duration: 0.25)) {
            isRecordingVoice = false
        }
        guard sendResult else { return }
        let url = recorder.url
        let media = ComposerMedia(
            id: UUID(),
            url: url,
            kind: .link,
            aspectRatio: 1,
            attachmentKind: .audio,
            filename: "Голосовое сообщение.m4a",
            byteCount: Int64((try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0)
        )
        attachment = media
        send()
    }

    private func profileTarget(for chat: Chat) -> User? {
        if chat.kind == .direct, let currentID = dependencies.session.currentUser?.id {
            return chat.participants.first { $0.id != currentID }
        }
        return chat.participants.first
    }

    private func fallbackChatUser(_ chat: Chat) -> User {
        User(
            id: chat.id,
            name: chat.title,
            username: chat.title.lowercased().replacingOccurrences(of: " ", with: ""),
            biography: "",
            avatarSymbol: chat.avatarSymbol,
            isVerified: false,
            isAdministrator: false,
            followers: 0,
            following: 0,
            joinedAt: .now
        )
    }

    private func lastSeenText(for chat: Chat) -> String {
        guard chat.kind == .direct, let user = profileTarget(for: chat) else {
            return "\(chat.participants.count) участников"
        }
        let seconds = max(0, Int(Date().timeIntervalSince(user.lastSeenAt)))
        if seconds < 90 { return "в сети" }
        if seconds < 3600 { return "был(а) \(max(1, seconds / 60)) минут назад" }
        if seconds < 86_400 { return "был(а) \(max(1, seconds / 3600)) часов назад" }
        return "был(а) \(max(1, seconds / 86_400)) дней назад"
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
                .background(Color.primary.opacity(0.22), in: Circle())

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

struct CameraCaptureView: UIViewControllerRepresentable {
    let onImage: (UIImage) -> Void
    let onCancel: () -> Void

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.sourceType = UIImagePickerController.isSourceTypeAvailable(.camera) ? .camera : .photoLibrary
        picker.mediaTypes = ["public.image"]
        picker.allowsEditing = false
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onImage: onImage, onCancel: onCancel)
    }

    final class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        let onImage: (UIImage) -> Void
        let onCancel: () -> Void

        init(onImage: @escaping (UIImage) -> Void, onCancel: @escaping () -> Void) {
            self.onImage = onImage
            self.onCancel = onCancel
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let image = info[.originalImage] as? UIImage {
                onImage(image)
            } else {
                onCancel()
            }
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            onCancel()
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
                    Label("Ответ", systemImage: "arrowshape.turn.up.left.fill")
                        .font(.caption2)
                        .foregroundStyle(isOutgoing ? .white.opacity(0.72) : .secondary)
                }

                if message.attachmentKind != .none {
                    attachmentContent
                }

                if !message.body.isEmpty {
                    Text(message.body)
                        .font(.system(size: 16, weight: .regular))
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
            .padding(.horizontal, isVisualMedia ? 3 : 13)
            .padding(.vertical, isVisualMedia ? 3 : 9)
            .background(bubbleBackground)
            .foregroundStyle(isOutgoing ? .white : TidePalette.ink)
            .clipShape(RoundedRectangle(cornerRadius: isVisualMedia ? 19 : 18, style: .continuous))
            .overlay {
                if isVisualMedia {
                    RoundedRectangle(cornerRadius: 19, style: .continuous)
                        .stroke(.white.opacity(0.14), lineWidth: 0.7)
                }
            }
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
        if isVisualMedia {
            return AnyShapeStyle(.clear)
        }
        return isOutgoing ? AnyShapeStyle(Color.primary.opacity(0.24)) : AnyShapeStyle(.regularMaterial)
    }

    private var isVisualMedia: Bool {
        message.attachmentKind == .photo || message.attachmentKind == .video
    }

    @ViewBuilder
    private var attachmentContent: some View {
        if let url = message.attachmentURL, isVisualMedia {
            PostMediaCell(media: MediaAttachment(
                id: message.id,
                kind: message.attachmentKind == .video ? .video : .photo,
                url: url,
                aspectRatio: 1.4
            ))
            .frame(maxWidth: 250, minHeight: 140, maxHeight: 220)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        } else {
            HStack(spacing: 10) {
                Image(systemName: message.attachmentKind == .audio ? "waveform" : "doc.fill")
                    .font(.system(size: 20, weight: .semibold))
                    .frame(width: 38, height: 38)
                    .background(.white.opacity(isOutgoing ? 0.16 : 0.08), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                VStack(alignment: .leading, spacing: 2) {
                    Text(message.attachmentKind == .audio ? "Голосовое сообщение" : fileName)
                        .font(.system(size: 15, weight: .semibold))
                        .lineLimit(1)
                    Text(message.attachmentKind == .audio ? "Аудио" : "Файл")
                        .font(.caption)
                        .foregroundStyle(isOutgoing ? .white.opacity(0.68) : .secondary)
                }
            }
        }
    }

    private var fileName: String {
        message.attachmentURL?.lastPathComponent.removingPercentEncoding ?? "Файл"
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
    @State private var state: CallState = .ringing
    @State private var callSessionID: UUID?
    @State private var callError: String?

    private enum CallState: String {
        case ringing
        case connecting
        case active
        case ended

        var title: String {
            switch self {
            case .ringing: "Звонок"
            case .connecting: "Соединение"
            case .active: "Идёт звонок"
            case .ended: "Завершён"
            }
        }
    }

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            ZStack {
                callBackdrop
                VStack(spacing: 22) {
                    HStack {
                        Spacer()
                        Button {
                            Task { await endAndDismiss() }
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 15, weight: .bold))
                                .foregroundStyle(.white)
                                .frame(width: 40, height: 40)
                                .background(.white.opacity(0.10), in: Circle())
                                .overlay(Circle().stroke(.white.opacity(0.14), lineWidth: 0.8))
                        }
                        .buttonStyle(.plain)
                    }

                    Spacer(minLength: 0)

                    if let chat = dependencies.messenger.chat(id: chatID) {
                        VStack(spacing: 18) {
                            ZStack {
                                Circle()
                                    .fill(.white.opacity(0.10))
                                    .frame(width: 176, height: 176)
                                    .blur(radius: 0.2)
                                Circle()
                                    .fill(isVideo ? Color.blue.opacity(0.18) : Color.green.opacity(0.16))
                                    .frame(width: 220, height: 220)
                                    .blur(radius: 24)
                                Image(systemName: chat.avatarSymbol)
                                    .font(.system(size: 58, weight: .semibold))
                                    .foregroundStyle(.white)
                            }
                            Text(chat.title)
                                .font(.system(size: 32, weight: .bold, design: .rounded))
                                .foregroundStyle(.white)
                                .lineLimit(1)
                            Text(callDisplayText(for: context.date))
                                .font(.system(size: 17, weight: .medium, design: .rounded))
                                .foregroundStyle(.white.opacity(0.72))
                        }
                    }

                    Spacer(minLength: 0)

                    HStack(spacing: 16) {
                        callButton(isMuted ? "mic.slash.fill" : "mic.fill", active: isMuted) { isMuted.toggle() }
                        if isVideo {
                            callButton(cameraEnabled ? "video.fill" : "video.slash.fill", active: !cameraEnabled) { cameraEnabled.toggle() }
                        }
                        callButton(speakerEnabled ? "speaker.wave.2.fill" : "speaker.slash.fill", active: !speakerEnabled) { speakerEnabled.toggle() }
                        callButton("phone.down.fill", color: TidePalette.danger) {
                            Task { await endAndDismiss() }
                        }
                    }
                    .padding(.bottom, 28)
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
            }
        }
        .navigationBarBackButtonHidden()
        .toolbar(.hidden, for: .tabBar)
        .task { await bootstrapCall() }
        .onDisappear {
            Task { await endCurrentCall() }
        }
        .alert("Звонок", isPresented: Binding(get: { callError != nil }, set: { if !$0 { callError = nil } })) {
            Button("ОК", role: .cancel) {}
        } message: {
            Text(callError ?? "")
        }
    }

    private func callButton(_ symbol: String, active: Bool = false, color: Color = .white.opacity(0.16), action: @escaping () -> Void) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.34)) {
                action()
            }
        } label: {
            Image(systemName: symbol)
                .font(.title2)
                .foregroundStyle(.white)
                .frame(width: 58, height: 58)
            .background(isEndedButton(symbol) ? color : .white.opacity(active ? 0.24 : 0.12), in: Circle())
            .overlay(Circle().stroke(.white.opacity(active ? 0.34 : 0.16), lineWidth: 0.8))
        }
        .buttonStyle(TideGlassIconButtonStyle())
    }

    private var callBackdrop: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.04, green: 0.05, blue: 0.07),
                    Color(red: 0.02, green: 0.02, blue: 0.03),
                    Color.black
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            Circle()
                .fill(Color.blue.opacity(0.16))
                .frame(width: 320, height: 320)
                .blur(radius: 38)
                .offset(x: -128, y: -220)
            Circle()
                .fill(Color.green.opacity(0.12))
                .frame(width: 280, height: 280)
                .blur(radius: 34)
                .offset(x: 130, y: 220)
        }
        .ignoresSafeArea()
    }

    private func callDisplayText(for date: Date) -> String {
        switch state {
        case .ringing:
            return "Звонок"
        case .connecting:
            return "Подключаемся..."
        case .active:
            return duration(from: startedAt, to: date)
        case .ended:
            return "Завершён"
        }
    }

    private func bootstrapCall() async {
        let shouldStart = await MainActor.run { callSessionID == nil }
        guard shouldStart else { return }
        await MainActor.run {
            state = .connecting
        }
        do {
            let session = try await dependencies.api.createCall(chatID: chatID, isVideo: isVideo)
            await MainActor.run {
                callSessionID = session.id
                startedAt = .now
            }
            try? await Task.sleep(for: .milliseconds(850))
            await MainActor.run {
                withAnimation(.easeInOut(duration: 0.45)) {
                    state = .active
                }
            }
        } catch {
            await MainActor.run {
                callError = "Не удалось начать звонок."
                state = .ended
            }
        }
    }

    private func endCurrentCall() async {
        let sessionID = await MainActor.run { callSessionID }
        guard let sessionID else { return }
        _ = try? await dependencies.api.endCall(id: sessionID)
        await MainActor.run {
            self.callSessionID = nil
        }
    }

    private func endAndDismiss() async {
        await MainActor.run {
            state = .ended
        }
        await endCurrentCall()
        dismiss()
    }

    private func isEndedButton(_ symbol: String) -> Bool {
        symbol == "phone.down.fill"
    }

    private func duration(from: Date, to: Date) -> String {
        let seconds = max(0, Int(to.timeIntervalSince(from)))
        return String(format: "%02d:%02d", seconds / 60, seconds % 60)
    }
}
