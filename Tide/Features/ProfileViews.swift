import PhotosUI
import SwiftUI
import UniformTypeIdentifiers
import UserNotifications
import UIKit

struct ProfileView: View {
    @Environment(AppDependencies.self) private var dependencies
    let user: User
    @State private var profile: User
    @State private var section: ProfileSection = .posts
    private let sections: [ProfileSection] = ProfileSection.allCases

    init(user: User) {
        self.user = user
        _profile = State(initialValue: user)
    }

    private var isCurrentUser: Bool { profile.id == dependencies.session.currentUser?.id }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 0, pinnedViews: .sectionHeaders) {
                profileHeader
                Section {
                    if visiblePosts.isEmpty {
                        ContentUnavailableView("Постов нет", systemImage: "rectangle.stack", description: Text("Опубликованные посты будут отображаться здесь."))
                            .padding(.top, 38)
                    }
                    ForEach(visiblePosts) { post in
                        PostCard(post: post)
                        Divider().padding(.leading, 68)
                    }
                } header: {
                    Picker("Раздел профиля", selection: $section) {
                        ForEach(sections, id: \.self) { Text($0.title).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                }
            }
        }
        .navigationTitle(profile.handle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if isCurrentUser {
                Button { dependencies.router.push(.settings) } label: { Image(systemName: "gearshape") }
            } else {
                Menu {
                    Button(profile.isBlocked ? "Разблокировать" : "Заблокировать", role: .destructive, action: toggleBlock)
                    Button("Пожаловаться", role: .destructive) { dependencies.router.sheet = .report(profile.id, "user") }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .onAppear { profile = dependencies.database.user(id: user.id) ?? user }
    }

    private var profileHeader: some View {
        VStack(alignment: .leading, spacing: 16) {
            ZStack(alignment: .bottomLeading) {
                coverView
                    .frame(height: 150)
                avatarButton
                    .offset(x: 18, y: 42)
            }
            HStack {
                Spacer()
                if isCurrentUser {
                    Button("Редактировать") { dependencies.router.sheet = .editProfile }
                        .buttonStyle(TideSecondaryButtonStyle())
                } else {
                    Button("Сообщение", action: startMessage)
                        .buttonStyle(TideSecondaryButtonStyle())
                    Button(profile.isFollowing ? "Вы подписаны" : "Подписаться", action: toggleFollow)
                        .buttonStyle(TidePrimaryButtonStyle())
                }
            }
            .padding(.horizontal)
            VStack(alignment: .leading, spacing: 7) {
                VerifiedName(user: profile).font(.title2)
                Text(profile.handle).foregroundStyle(.secondary)
                if profile.isVerified {
                    HStack(spacing: 6) {
                        Image("TideAuthLogo")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 14, height: 14)
                            .clipShape(Circle())
                        Text("аккаунт верифицирован")
                    }
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                }
                Text(profile.biography)
                Text("В сети с \(profile.joinedAt.formatted(.dateTime.month(.wide).year()))")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                HStack(spacing: 20) {
                    counter(profile.following, "Подписки")
                    counter(profile.followers, "Подписчики")
                    counter(authoredPosts.count, "Посты")
                }
                .padding(.top, 4)
            }
            .padding(.horizontal)
            .padding(.bottom, 8)
        }
    }

    private var coverView: some View {
        Group {
            if let coverURL = profile.coverImageURL,
               let image = UIImage(contentsOfFile: coverURL.path) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .clipped()
            } else {
                LinearGradient(
                    colors: [TidePalette.ink.opacity(0.28), TidePalette.subtle],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
        }
        .overlay(alignment: .topTrailing) {
            if isCurrentUser {
                Button {
                    dependencies.router.sheet = .editProfile
                } label: {
                    Image(systemName: "camera.fill")
                        .font(.footnote.weight(.semibold))
                        .frame(width: 34, height: 34)
                        .background(.black.opacity(0.35), in: Circle())
                }
                .padding(12)
            }
        }
    }

    private var avatarButton: some View {
        Button {
            if isCurrentUser { dependencies.router.sheet = .editProfile }
        } label: {
            AvatarView(user: profile, size: 92)
                .padding(4)
                .background(TidePalette.paper, in: Circle())
        }
        .buttonStyle(.plain)
        .disabled(!isCurrentUser)
    }

    private var authoredPosts: [Post] { dependencies.social.posts.filter { $0.author.id == profile.id } }

    private var visiblePosts: [Post] {
        switch section {
        case .media: authoredPosts.filter { !$0.media.isEmpty }
        case .saved: isCurrentUser ? dependencies.social.posts.filter(\.isSaved) : []
        case .likes: isCurrentUser ? dependencies.social.posts.filter(\.isLiked) : []
        default: authoredPosts
        }
    }

    private func counter(_ value: Int, _ title: String) -> some View {
        HStack(spacing: 4) {
            Text(value.formatted(.number.notation(.compactName))).fontWeight(.bold)
            Text(title).foregroundStyle(.secondary)
        }
        .font(.subheadline)
    }

    private func startMessage() {
        guard let currentUser = dependencies.session.currentUser else { return }
        let id = dependencies.messenger.createDirectChat(currentUser: currentUser, otherUser: profile)
        dependencies.router.push(.chat(id), tab: .chats)
    }

    private func toggleFollow() {
        profile.isFollowing.toggle()
        profile.followers = max(0, profile.followers + (profile.isFollowing ? 1 : -1))
        dependencies.database.updateUser(profile)
    }

    private func toggleBlock() {
        profile.isBlocked.toggle()
        dependencies.database.updateUser(profile)
        dependencies.social.reload()
    }
}

private enum ProfileSection: String, CaseIterable, Hashable {
    case posts
    case media
    case saved
    case likes

    var title: String {
        switch self {
        case .posts: "Посты"
        case .media: "Медиа"
        case .saved: "Сохранённое"
        case .likes: "Лайки"
        }
    }
}

struct LegacyEditProfileView: View {
    @Environment(AppDependencies.self) private var dependencies
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var surname = ""
    @State private var username = ""
    @State private var biography = ""
    @State private var location = ""
    @State private var website = ""
    @State private var birthday = Date()
    @State private var hasBirthday = false
    @State private var avatarSymbol = "person.crop.circle.fill"
    @State private var avatarImageURL: URL?
    @State private var coverImageURL: URL?
    @State private var avatarPickerItem: PhotosPickerItem?
    @State private var coverPickerItem: PhotosPickerItem?
    @State private var avatarFileImporter = false
    @State private var originalSnapshot: EditProfileSnapshot?
    @State private var validationMessage: String?
    @FocusState private var focusedField: EditProfileField?

    var body: some View {
        NavigationStack {
            Form {
                if let activeValidationMessage {
                    Section {
                        Label(activeValidationMessage, systemImage: "exclamationmark.circle.fill")
                            .foregroundStyle(.red)
                    }
                }

                Section("Фото") {
                    HStack(spacing: 14) {
                        AvatarView(user: previewUser, size: 62)
                        VStack(alignment: .leading, spacing: 6) {
                            PhotosPicker(selection: $avatarPickerItem, matching: .images) {
                                Label("Выбрать фото", systemImage: "photo")
                            }
                            PhotosPicker(selection: $coverPickerItem, matching: .images) {
                                Label("Выбрать обложку", systemImage: "rectangle.on.rectangle")
                            }
                            Button(role: .destructive) {
                                avatarImageURL = nil
                                coverImageURL = nil
                                avatarSymbol = "person.crop.circle.fill"
                            } label: {
                                Label("Удалить фото и обложку", systemImage: "trash")
                            }
                        }
                    }
                    if let coverImageURL, let image = UIImage(contentsOfFile: coverImageURL.path) {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                            .frame(height: 128)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                }

                Section("Основное") {
                    TextField("Имя", text: $name)
                        .focused($focusedField, equals: .name)
                        .textContentType(.givenName)
                    TextField("Фамилия", text: $surname)
                        .focused($focusedField, equals: .surname)
                        .textContentType(.familyName)
                    TextField("Имя пользователя", text: $username)
                        .focused($focusedField, equals: .username)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .textContentType(.username)
                }

                Section("О себе") {
                    TextField("Описание", text: $biography, axis: .vertical)
                        .focused($focusedField, equals: .bio)
                        .lineLimit(3...6)
                    TextField("Локация", text: $location)
                        .focused($focusedField, equals: .location)
                        .textContentType(.fullStreetAddress)
                    TextField("Сайт", text: $website)
                        .focused($focusedField, equals: .website)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.URL)
                        .textContentType(.URL)
                }

                Section("Личное") {
                    Toggle("Показывать дату рождения", isOn: $hasBirthday)
                    if hasBirthday {
                        DatePicker("Дата рождения", selection: $birthday, displayedComponents: .date)
                    }
                }
            }
            .navigationTitle("Изменить профиль")
            .navigationBarTitleDisplayMode(.inline)
            .scrollContentBackground(.hidden)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Готово", action: saveProfile)
                        .disabled(!canSave)
                }
            }
            .onAppear(perform: loadCurrentUser)
            .onChange(of: username) { _, value in
                let cleaned = sanitizeUsername(value)
                if cleaned != value { username = cleaned }
            }
            .onChange(of: avatarPickerItem) { _, item in
                Task { await importProfileImage(item, target: .avatar) }
            }
            .onChange(of: coverPickerItem) { _, item in
                Task { await importProfileImage(item, target: .cover) }
            }
        }
    }

    private var cleanDisplayName: String {
        [name, surname]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    private var cleanUsername: String {
        sanitizeUsername(username)
    }

    private var currentSnapshot: EditProfileSnapshot {
        EditProfileSnapshot(
            name: cleanDisplayName,
            username: cleanUsername,
            biography: biography.trimmingCharacters(in: .whitespacesAndNewlines),
            location: normalizedOptional(location),
            website: normalizedOptional(website),
            birthday: hasBirthday ? birthday : nil,
            avatarSymbol: avatarSymbol,
            avatarImageURL: avatarImageURL,
            coverImageURL: coverImageURL
        )
    }

    private var canSave: Bool {
        !cleanDisplayName.isEmpty && (originalSnapshot.map { currentSnapshot != $0 } ?? false)
    }

    private var activeValidationMessage: String? {
        if originalSnapshot != nil, cleanDisplayName.isEmpty {
            return "Укажите имя"
        }
        return validationMessage
    }

    private var previewUser: User {
        let current = dependencies.session.currentUser
        return User(
            id: current?.id ?? UUID(),
            name: cleanDisplayName.isEmpty ? "Укажите имя" : cleanDisplayName,
            username: cleanUsername.isEmpty ? (current?.username ?? "username") : cleanUsername,
            biography: biography,
            avatarSymbol: avatarSymbol,
            avatarImageURL: avatarImageURL,
            isVerified: current?.isVerified ?? false,
            isAdministrator: current?.isAdministrator ?? false,
            followers: current?.followers ?? 0,
            following: current?.following ?? 0,
            joinedAt: current?.joinedAt ?? .now,
            coverSymbol: current?.coverSymbol ?? "water",
            coverImageURL: coverImageURL,
            location: normalizedOptional(location),
            website: normalizedOptional(website),
            birthday: hasBirthday ? birthday : nil,
            status: current?.status ?? .active,
            lastSeenAt: current?.lastSeenAt ?? .now,
            isFollowing: current?.isFollowing ?? false,
            isBlocked: current?.isBlocked ?? false
        )
    }

    private func loadCurrentUser() {
        guard let user = dependencies.session.currentUser else { return }
        let parts = user.name.split(separator: " ", maxSplits: 1).map(String.init)
        name = parts.first ?? ""
        surname = parts.dropFirst().first ?? ""
        username = sanitizeUsername(user.username)
        biography = user.biography
        location = user.location ?? ""
        website = user.website ?? ""
        birthday = user.birthday ?? Date()
        hasBirthday = user.birthday != nil
        avatarSymbol = user.avatarSymbol
        avatarImageURL = user.avatarImageURL
        coverImageURL = user.coverImageURL
        originalSnapshot = currentSnapshot
    }

    private func saveProfile() {
        guard !cleanDisplayName.isEmpty else {
            withAnimation(.easeInOut(duration: 0.35)) {
                validationMessage = "Укажите имя"
                focusedField = .name
            }
            return
        }
        validationMessage = nil
        dependencies.session.updateProfile(
            name: cleanDisplayName,
            username: cleanUsername,
            biography: biography,
            location: location,
            website: website,
            birthday: hasBirthday ? birthday : nil,
            avatarSymbol: avatarSymbol,
            avatarImageURL: avatarImageURL,
            coverImageURL: coverImageURL
        )
        withAnimation(.easeInOut(duration: 0.42)) {
            dismiss()
        }
    }

    private func importProfileImage(_ item: PhotosPickerItem?, target: ProfileImageTarget) async {
        guard let item else { return }
        guard let imported = try? await MediaLibrary.shared.importItems([item]),
              let media = imported.first,
              media.kind == .photo else { return }
        await MainActor.run {
            withAnimation(.easeInOut(duration: 0.45)) {
                switch target {
                case .avatar:
                    avatarImageURL = media.url
                case .cover:
                    coverImageURL = media.url
                }
            }
        }
    }

    private func sanitizeUsername(_ value: String) -> String {
        let allowed = Set("abcdefghijklmnopqrstuvwxyz0123456789_.")
        return value
            .lowercased()
            .filter { allowed.contains($0) }
            .trimmingCharacters(in: CharacterSet(charactersIn: "."))
    }

    private func normalizedOptional(_ value: String) -> String? {
        let clean = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return clean.isEmpty ? nil : clean
    }

    private enum EditProfileField: Hashable {
        case name
        case surname
        case username
        case bio
        case location
        case website
    }

    private enum ProfileImageTarget {
        case avatar
        case cover
    }
}

private struct EditProfileSnapshot: Equatable {
    let name: String
    let username: String
    let biography: String
    let location: String?
    let website: String?
    let birthday: Date?
    let avatarSymbol: String
    let avatarImageURL: URL?
    let coverImageURL: URL?
}

struct LegacySettingsView: View {
    @Environment(AppDependencies.self) private var dependencies
    @State private var confirmsDeletion = false
    @State private var wallpaperItem: PhotosPickerItem?

    var body: some View {
        @Bindable var preferences = dependencies.preferences
        Form {
            Section("Оформление") {
                Picker("Тема", selection: $preferences.theme) {
                    ForEach(PreferencesStore.Theme.allCases) { Text($0.title).tag($0) }
                }
                LabeledContent("Дизайн", value: "Жидкое стекло")
                Picker("Фон", selection: $preferences.backdropStyle) {
                    ForEach(PreferencesStore.BackdropStyle.allCases) { Text($0.title).tag($0) }
                }
                PhotosPicker(selection: $wallpaperItem, matching: .any(of: [.images, .videos])) {
                    Label("Выбрать обои из галереи", systemImage: "photo.on.rectangle")
                }
                wallpaperPreview
                if !preferences.galleryBackdropURLString.isEmpty {
                    Slider(value: $preferences.galleryBackdropOpacity, in: 0.2...1) {
                        Text("Прозрачность обоев")
                    }
                    Button("Удалить обои", role: .destructive) {
                        preferences.galleryBackdropURLString = ""
                        preferences.galleryBackdropKind = .none
                        preferences.galleryBackdropOpacity = 1
                    }
                }
                TextField("Ресурс фона", text: $preferences.backdropResourceName)
                TextField("URL видео фона", text: $preferences.backdropVideoURLString)
                Slider(value: $preferences.backdropOpacity, in: 0.2...1)
                TextField("Фон авторизации", text: $preferences.authBackdropResourceName)
                TextField("Логотип приложения", text: $preferences.brandLogoResourceName)
            }
            Section("Уведомления") {
                Toggle("Push-уведомления", isOn: $preferences.notificationsEnabled)
                    .tint(TidePalette.success)
                Button("Запросить доступ к уведомлениям") { Task { await dependencies.push.requestAuthorization() } }
                LabeledContent("Статус", value: pushStatus)
                if let token = dependencies.push.deviceToken { LabeledContent("Токен APNs", value: String(token.prefix(12)) + "...") }
            }
            Section("Приватность") {
                Toggle("Отчёты о прочтении", isOn: $preferences.readReceiptsEnabled)
                    .tint(TidePalette.success)
                Toggle("Скрывать чувствительный контент", isOn: $preferences.sensitiveContentHidden)
                    .tint(TidePalette.success)
                NavigationLink("Заблокированные аккаунты") { BlockedAccountsView() }
                NavigationLink("Активные сессии") { ActiveSessionsView() }
            }
            Section("Данные") {
                Toggle("Автовоспроизведение видео", isOn: $preferences.autoplayVideo)
                    .tint(TidePalette.success)
                Toggle("Загрузка через сотовую сеть", isOn: $preferences.cellularUploadsEnabled)
                    .tint(TidePalette.success)
                LabeledContent("Хранилище", value: "SwiftData")
            }
            Section("Разработчикам") {
                Button("API бота Tide") { dependencies.router.push(.botPlatform) }
                Button("Открыть сайт Tide") { dependencies.router.push(.browser(URL(string: "https://tide.app")!)) }
                LabeledContent("Режим сервера", value: ServerConfiguration.current.isRemoteEnabled ? "Настроен" : "Не настроен")
            }
            if dependencies.session.currentUser?.isAdministrator == true {
                Section("Tide") { Button("Панель администратора") { dependencies.router.sheet = .adminAccess } }
            }
            Section {
                Button("Выйти", role: .destructive) { dependencies.session.signOut(); dependencies.router.reset() }
                Button("Удалить аккаунт", role: .destructive) { confirmsDeletion = true }
            }
        }
        .navigationTitle("Настройки")
        .scrollContentBackground(.hidden)
        .onChange(of: wallpaperItem) { _, item in
            Task { await importWallpaper(item) }
        }
        .confirmationDialog("Удалить этот локальный аккаунт?", isPresented: $confirmsDeletion, titleVisibility: .visible) {
            Button("Удалить аккаунт", role: .destructive) {
                dependencies.session.signOut()
                dependencies.router.reset()
            }
            Button("Отмена", role: .cancel) {}
        } message: {
            Text("Удаление на сервере тоже должно быть подтверждено бэкендом при включённой синхронизации.")
        }
    }

    private var pushStatus: String {
        switch dependencies.push.authorizationStatus {
        case .authorized: "Разрешено"
        case .denied: "Запрещено"
        case .provisional: "Временно"
        case .ephemeral: "Временный доступ"
        case .notDetermined: "Не запрошено"
        @unknown default: "Неизвестно"
        }
    }

    @ViewBuilder
    private var wallpaperPreview: some View {
        let preferences = dependencies.preferences
        if let url = URL(string: preferences.galleryBackdropURLString), url.isFileURL {
            switch preferences.galleryBackdropKind {
            case .image:
                if let image = UIImage(contentsOfFile: url.path) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(height: 132)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
            case .video:
                ZStack {
                    TideVideoThumbnailView(url: url)
                    Image(systemName: "play.circle.fill")
                        .font(.system(size: 42, weight: .semibold))
                        .foregroundStyle(.white)
                }
                .frame(height: 132)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            case .none:
                EmptyView()
            }
        }
    }

    private func importWallpaper(_ item: PhotosPickerItem?) async {
        guard let item else { return }
        guard let imported = try? await MediaLibrary.shared.importItems([item]),
              let media = imported.first else { return }
        await MainActor.run {
            dependencies.preferences.galleryBackdropURLString = media.url.absoluteString
            dependencies.preferences.galleryBackdropKind = media.kind == .video ? .video : .image
            dependencies.preferences.galleryBackdropOpacity = 1
            dependencies.preferences.backdropStyle = media.kind == .video ? .video : .image
            wallpaperItem = nil
        }
    }
}

struct BlockedAccountsView: View {
    @Environment(AppDependencies.self) private var dependencies

    var body: some View {
        List(dependencies.database.users().filter(\.isBlocked)) { user in
            UserRow(user: user)
        }
        .scrollContentBackground(.hidden)
        .overlay {
            if !dependencies.database.users().contains(where: \.isBlocked) {
                ContentUnavailableView("Заблокированных аккаунтов нет", systemImage: "person.crop.circle.badge.checkmark")
            }
        }
        .navigationTitle("Заблокированные аккаунты")
    }
}

struct LegacyActiveSessionsView: View {
    @State private var otherSessionCount = 2

    var body: some View {
        List {
            Label("Этот iPhone", systemImage: "iphone.gen3")
            if otherSessionCount > 0 {
                ForEach(0..<otherSessionCount, id: \.self) { index in
                    Label(index == 0 ? "Mac" : "Веб-браузер", systemImage: index == 0 ? "laptopcomputer" : "globe")
                }
            }
            Section("Безопасность") {
                Button("Завершить другие сессии", role: .destructive) { otherSessionCount = 0 }
                    .disabled(otherSessionCount == 0)
            }
        }
        .scrollContentBackground(.hidden)
        .navigationTitle("Активные сессии")
    }
}
