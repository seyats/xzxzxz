import PhotosUI
import SwiftUI
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
                } label: { Image(systemName: "ellipsis.circle") }
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
                    .font(.subheadline).foregroundStyle(.secondary)
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
                LinearGradient(colors: [TidePalette.ink.opacity(0.28), TidePalette.subtle], startPoint: .topLeading, endPoint: .bottomTrailing)
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

struct EditProfileView: View {
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
    @State private var originalSnapshot: EditProfileSnapshot?
    @State private var validationMessage: String?
    @FocusState private var focusedField: EditProfileField?

    var body: some View {
        NavigationStack {
            ZStack {
                editProfileBackdrop
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 18) {
                        topBar
                        heroCard
                        if let activeValidationMessage {
                            validationBanner(activeValidationMessage)
                        }
                        editorSection(title: "Основное", subtitle: "Так профиль увидят в Tide.") {
                            profileTextField("Имя", text: $name, placeholder: "Имя", icon: "person.fill", focus: .name)
                            profileDivider
                            profileTextField("Фамилия", text: $surname, placeholder: "Фамилия", icon: "person.text.rectangle", focus: .surname)
                            profileDivider
                            profileTextField("Имя пользователя", text: $username, placeholder: "username", icon: "at", focus: .username)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                                .textContentType(.username)
                        }
                        editorSection(title: "О себе") {
                            VStack(alignment: .leading, spacing: 10) {
                                fieldLabel("Описание", icon: "text.alignleft")
                                TextEditor(text: $biography)
                                    .focused($focusedField, equals: .bio)
                                    .frame(minHeight: 104)
                                    .scrollContentBackground(.hidden)
                                    .font(.system(size: 16, weight: .regular, design: .rounded))
                                    .foregroundStyle(.white)
                                    .tint(.white)
                            }
                            profileDivider
                            profileTextField("Локация", text: $location, placeholder: "Город", icon: "location", focus: .location)
                                .textContentType(.fullStreetAddress)
                            profileDivider
                            profileTextField("Сайт", text: $website, placeholder: "https://", icon: "link", focus: .website)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                                .keyboardType(.URL)
                                .textContentType(.URL)
                        }
                        editorSection(title: "Личное", subtitle: "Дата рождения будет сохранена в профиле.") {
                            Toggle(isOn: $hasBirthday.animation(.easeInOut(duration: 0.35))) {
                                fieldLabel("Показывать дату рождения", icon: "calendar")
                            }
                            .toggleStyle(.switch)
                            .tint(.white.opacity(0.72))
                            if hasBirthday {
                                profileDivider
                                DatePicker("Дата рождения", selection: $birthday, displayedComponents: .date)
                                    .datePickerStyle(.compact)
                                    .tint(.white)
                                    .foregroundStyle(.white)
                            }
                        }
                        .padding(.bottom, 92)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 14)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(.hidden, for: .navigationBar)
            .safeAreaInset(edge: .bottom) { saveBar }
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

    private var topBar: some View {
        HStack(spacing: 12) {
            TideGlassIconButton(symbol: "xmark", tint: .white, size: 40) {
                withAnimation(.easeInOut(duration: 0.36)) { dismiss() }
            }
            VStack(alignment: .leading, spacing: 2) {
                Text("Изменить профиль")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                Text("Стеклянный редактор Tide")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.56))
            }
            Spacer()
        }
    }

    private var heroCard: some View {
        ZStack(alignment: .bottomLeading) {
            coverPreview
                .frame(height: 214)
                .frame(maxWidth: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: 34, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 34, style: .continuous)
                        .stroke(.white.opacity(0.16), lineWidth: 0.8)
                }
                .shadow(color: .black.opacity(0.32), radius: 26, y: 18)

            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .bottom, spacing: 14) {
                    AvatarView(user: previewUser, size: 104)
                        .padding(6)
                        .background(.ultraThinMaterial, in: Circle())
                        .overlay(Circle().stroke(.white.opacity(0.2), lineWidth: 0.8))
                        .shadow(color: .black.opacity(0.32), radius: 18, y: 8)
                    VStack(alignment: .leading, spacing: 5) {
                        Text(cleanDisplayName.isEmpty ? "Укажите имя" : cleanDisplayName)
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                            .minimumScaleFactor(0.74)
                        Text("@\(cleanUsername.isEmpty ? "username" : cleanUsername)")
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.64))
                    }
                    Spacer()
                }
                HStack(spacing: 8) {
                    PhotosPicker(selection: $avatarPickerItem, matching: .images) {
                        glassPill("Фото", symbol: "camera.fill")
                    }
                    .buttonStyle(TideGlassIconButtonStyle())
                    PhotosPicker(selection: $coverPickerItem, matching: .images) {
                        glassPill("Обложка", symbol: "photo.fill")
                    }
                    .buttonStyle(TideGlassIconButtonStyle())
                    Button {
                        withAnimation(.easeInOut(duration: 0.38)) {
                            avatarImageURL = nil
                            coverImageURL = nil
                            avatarSymbol = "person.crop.circle.fill"
                        }
                    } label: {
                        glassPill("Удалить", symbol: "trash", tint: TidePalette.danger)
                    }
                    .buttonStyle(TideGlassIconButtonStyle())
                }
            }
            .padding(18)
        }
        .background(AuthGlassBackground(cornerRadius: 34, interactive: false))
        .clipShape(RoundedRectangle(cornerRadius: 34, style: .continuous))
    }

    @ViewBuilder
    private var coverPreview: some View {
        if let coverImageURL, let image = UIImage(contentsOfFile: coverImageURL.path) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .overlay(.black.opacity(0.28))
        } else {
            ZStack {
                LinearGradient(
                    colors: [.white.opacity(0.16), .white.opacity(0.04), .black.opacity(0.7)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                RadialGradient(
                    colors: [.white.opacity(0.2), .clear],
                    center: .topTrailing,
                    startRadius: 16,
                    endRadius: 240
                )
                TideBrandLogoView(size: 86, style: .circle)
                    .opacity(0.26)
                    .blur(radius: 0.4)
                    .offset(x: 106, y: -52)
            }
        }
    }

    private var saveBar: some View {
        HStack(spacing: 12) {
            Button {
                withAnimation(.easeInOut(duration: 0.36)) { dismiss() }
            } label: {
                Text("Отмена")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(TideGlassButtonStyle(tint: .white.opacity(0.34), cornerRadius: 22, minHeight: 48))

            Button(action: saveProfile) {
                Text("Готово")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(TideGlassButtonStyle(tint: canSave ? Color.white : Color.gray, cornerRadius: 22, minHeight: 48))
            .disabled(!canSave)
            .opacity(canSave ? 1 : 0.48)
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 10)
        .background(.ultraThinMaterial)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(.white.opacity(0.12))
                .frame(height: 0.6)
        }
    }

    private var editProfileBackdrop: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            LinearGradient(
                colors: [.white.opacity(0.08), .clear, .white.opacity(0.04)],
                startPoint: .topTrailing,
                endPoint: .bottomLeading
            )
            .blur(radius: 12)
            .ignoresSafeArea()
        }
    }

    private func editorSection<Content: View>(title: String, subtitle: String? = nil, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.92))
                if let subtitle {
                    Text(subtitle)
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.46))
                }
            }
            content()
        }
        .padding(16)
        .background(AuthGlassBackground(cornerRadius: 24, interactive: true))
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(.white.opacity(0.1), lineWidth: 0.7)
        }
    }

    private func profileTextField(_ title: String, text: Binding<String>, placeholder: String, icon: String, focus: EditProfileField) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            fieldLabel(title, icon: icon)
            TextField(placeholder, text: text)
                .focused($focusedField, equals: focus)
                .font(.system(size: 16, weight: .regular, design: .rounded))
                .foregroundStyle(.white)
                .tint(.white)
        }
        .textFieldStyle(.plain)
    }

    private func fieldLabel(_ title: String, icon: String) -> some View {
        Label(title, systemImage: icon)
            .font(.system(size: 12, weight: .semibold, design: .rounded))
            .foregroundStyle(.white.opacity(0.48))
    }

    private var profileDivider: some View {
        Rectangle()
            .fill(.white.opacity(0.08))
            .frame(height: 0.7)
    }

    private func glassPill(_ title: String, symbol: String, tint: Color = .white) -> some View {
        Label(title, systemImage: symbol)
            .font(.system(size: 12, weight: .bold, design: .rounded))
            .foregroundStyle(tint)
            .padding(.horizontal, 12)
            .frame(height: 34)
            .background(.ultraThinMaterial, in: Capsule())
            .overlay(Capsule().stroke(.white.opacity(0.13), lineWidth: 0.7))
    }

    private func validationBanner(_ message: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "xmark.circle.fill")
            Text(message)
            Spacer()
        }
        .font(.system(size: 14, weight: .bold, design: .rounded))
        .foregroundStyle(TidePalette.danger)
        .padding(.horizontal, 14)
        .frame(height: 44)
        .background(AuthGlassBackground(cornerRadius: 18, interactive: false))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(TidePalette.danger.opacity(0.28), lineWidth: 0.7)
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

struct SettingsView: View {
    @Environment(AppDependencies.self) private var dependencies
    @State private var confirmsDeletion = false

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

struct ActiveSessionsView: View {
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
