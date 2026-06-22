import PhotosUI
import SwiftUI
import UniformTypeIdentifiers
import UIKit

struct EditProfileView: View {
    @Environment(AppDependencies.self) private var dependencies
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var surname = ""
    @State private var birthday = Date()
    @State private var hasBirthday = false
    @State private var avatarSymbol = "person.crop.circle.fill"
    @State private var avatarImageURL: URL?
    @State private var coverImageURL: URL?
    @State private var avatarPickerItem: PhotosPickerItem?
    @State private var avatarFileImporter = false
    @State private var originalSnapshot: EditProfileGlassSnapshot?
    @State private var validationMessage: String?
    @FocusState private var focusedField: EditProfileGlassField?

    var body: some View {
        ZStack {
            TideBackdropView(configuration: dependencies.preferences.backdropConfiguration())
            Color.black.opacity(0.62).ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 28) {
                    topBar
                    avatarEditor
                    identityCard
                    birthdayCard
                    accountCard
                    if let footnote = authInfo.providerFootnote {
                        Text(footnote)
                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 44)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 32)
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .task { loadCurrentUser() }
        .onChange(of: avatarPickerItem) { _, item in
            Task { await importProfileImage(item) }
        }
        .fileImporter(isPresented: $avatarFileImporter, allowedContentTypes: [.image], allowsMultipleSelection: false) { result in
            guard case .success(let urls) = result, let url = urls.first else { return }
            Task {
                guard let media = try? await MediaLibrary.shared.importFile(url),
                      media.attachmentKind == .photo else { return }
                await MainActor.run {
                    withAnimation(.easeInOut(duration: 0.35)) {
                        avatarImageURL = media.url
                    }
                }
            }
        }
    }

    private var topBar: some View {
        HStack(spacing: 16) {
            Button { dismiss() } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 58, height: 58)
                    .background(AuthGlassBackground(cornerRadius: 29, interactive: true))
            }
            .buttonStyle(.plain)

            Text("Профиль")
                .font(.system(size: 29, weight: .black, design: .rounded))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, alignment: .leading)

            Button(action: saveProfile) {
                Text("Сохранить")
                    .font(.system(size: 19, weight: .black, design: .rounded))
                    .foregroundStyle(canSave ? .white : .secondary)
                    .padding(.horizontal, 24)
                    .frame(height: 58)
                    .background(AuthGlassBackground(cornerRadius: 29, interactive: canSave))
            }
            .buttonStyle(.plain)
            .disabled(!canSave)
        }
        .padding(.top, 8)
    }

    private var avatarEditor: some View {
        VStack(spacing: 0) {
            profileAvatarPreview
                .shadow(color: .black.opacity(0.32), radius: 24, y: 14)

            Menu {
                PhotosPicker(selection: $avatarPickerItem, matching: .images) {
                    Label("Фотогалерея", systemImage: "photo.on.rectangle")
                }
                Button {
                    avatarFileImporter = true
                } label: {
                    Label("Выбрать из файлов", systemImage: "folder")
                }
                if avatarImageURL != nil {
                    Button(role: .destructive) {
                        withAnimation(.easeInOut(duration: 0.32)) {
                            avatarImageURL = nil
                        }
                    } label: {
                        Label("Удалить фото", systemImage: "trash")
                    }
                }
            } label: {
                HStack(spacing: 10) {
                    Text("Редактировать")
                    Image(systemName: "chevron.right")
                        .font(.system(size: 18, weight: .black))
                }
                .font(.system(size: 20, weight: .black, design: .rounded))
                .foregroundStyle(.white)
                .padding(.horizontal, 24)
                .frame(height: 50)
                .background(AuthGlassBackground(cornerRadius: 25, interactive: true))
            }
            .buttonStyle(.plain)
            .offset(y: -20)
        }
        .padding(.top, 18)
    }

    private var identityCard: some View {
        VStack(spacing: 0) {
            glassTextField("Имя", text: $name, field: .name)
            divider
            glassTextField("Фамилия", text: $surname, field: .surname)
        }
        .padding(.vertical, 10)
        .background(AuthGlassBackground(cornerRadius: 32, interactive: false))
        .padding(.horizontal, 24)
        .overlay(alignment: .bottomLeading) {
            if let validationMessage {
                Text(validationMessage)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(.red)
                    .offset(x: 44, y: 26)
            }
        }
    }

    private var birthdayCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Toggle("Показывать дату рождения", isOn: $hasBirthday)
                .tint(.white)
            if hasBirthday {
                DatePicker("День рождения", selection: $birthday, displayedComponents: .date)
                    .datePickerStyle(.wheel)
                    .labelsHidden()
                    .frame(maxWidth: .infinity)
                    .clipped()
            } else {
                HStack {
                    Text("Год рождения")
                    Spacer()
                    Text("Не указан")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .font(.system(size: 21, weight: .bold, design: .rounded))
        .foregroundStyle(.white)
        .padding(22)
        .background(AuthGlassBackground(cornerRadius: 28, interactive: false))
        .padding(.horizontal, 24)
    }

    private var accountCard: some View {
        VStack(spacing: 0) {
            HStack(alignment: .top, spacing: 16) {
                Text("Электронная почта")
                    .foregroundStyle(.white)
                Spacer()
                Text(authInfo.email.isEmpty ? "Не указана" : authInfo.email)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.trailing)
                    .lineLimit(2)
            }
            .padding(.horizontal, 22)
            .padding(.vertical, 18)

            divider

            Button {
                focusedField = nil
            } label: {
                HStack {
                    Text("Управление аккаунтом")
                    Spacer()
                    Image(systemName: "chevron.right")
                        .foregroundStyle(.secondary)
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 22)
                .padding(.vertical, 18)
            }
            .buttonStyle(.plain)
        }
        .font(.system(size: 21, weight: .bold, design: .rounded))
        .background(AuthGlassBackground(cornerRadius: 28, interactive: false))
        .padding(.horizontal, 24)
    }

    private var profileAvatarPreview: some View {
        ZStack {
            Circle()
                .fill(LinearGradient(
                    colors: [Color(red: 0.0, green: 0.34, blue: 0.29), Color(red: 0.0, green: 0.18, blue: 0.16)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ))
                .frame(width: 128, height: 128)
            if let avatarImageURL,
               let image = UIImage(contentsOfFile: avatarImageURL.path) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 128, height: 128)
                    .clipShape(Circle())
            } else {
                Text(String(name.first ?? surname.first ?? Character("M")).uppercased())
                    .font(.system(size: 64, weight: .regular, design: .rounded))
                    .foregroundStyle(.white)
            }
        }
    }

    private func glassTextField(_ placeholder: String, text: Binding<String>, field: EditProfileGlassField) -> some View {
        TextField(placeholder, text: text)
            .focused($focusedField, equals: field)
            .textInputAutocapitalization(.words)
            .font(.system(size: 23, weight: .bold, design: .rounded))
            .foregroundStyle(.white)
            .padding(.horizontal, 22)
            .frame(height: 64)
    }

    private var divider: some View {
        Rectangle()
            .fill(.white.opacity(0.10))
            .frame(height: 1)
            .padding(.leading, 22)
            .padding(.trailing, 18)
    }

    private var authInfo: AuthAccountInfo {
        dependencies.session.currentAuthInfo()
    }

    private var cleanDisplayName: String {
        [name, surname]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    private var currentSnapshot: EditProfileGlassSnapshot {
        EditProfileGlassSnapshot(
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            surname: surname.trimmingCharacters(in: .whitespacesAndNewlines),
            birthday: hasBirthday ? birthday : nil,
            avatarImageURL: avatarImageURL
        )
    }

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && (originalSnapshot.map { currentSnapshot != $0 } ?? false)
    }

    private var previewUser: User {
        let current = dependencies.session.currentUser
        return User(
            id: current?.id ?? UUID(),
            name: cleanDisplayName.isEmpty ? "M" : cleanDisplayName,
            username: current?.username ?? "mango",
            biography: current?.biography ?? "",
            avatarSymbol: avatarSymbol,
            avatarImageURL: avatarImageURL,
            isVerified: current?.isVerified ?? false,
            isAdministrator: current?.isAdministrator ?? false,
            followers: current?.followers ?? 0,
            following: current?.following ?? 0,
            joinedAt: current?.joinedAt ?? .now,
            coverSymbol: current?.coverSymbol ?? "water",
            coverImageURL: coverImageURL,
            location: current?.location,
            website: current?.website,
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
        birthday = user.birthday ?? Calendar.current.date(from: DateComponents(year: 2000, month: 1, day: 1)) ?? .now
        hasBirthday = user.birthday != nil
        avatarSymbol = user.avatarSymbol
        avatarImageURL = user.avatarImageURL
        coverImageURL = user.coverImageURL
        originalSnapshot = currentSnapshot
    }

    private func saveProfile() {
        guard canSave else { return }
        guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            withAnimation(.easeInOut(duration: 0.3)) {
                validationMessage = "Укажите имя"
                focusedField = .name
            }
            return
        }
        let current = dependencies.session.currentUser
        dependencies.session.updateProfile(
            name: cleanDisplayName,
            username: current?.username,
            biography: current?.biography ?? "",
            location: current?.location,
            website: current?.website,
            birthday: hasBirthday ? birthday : nil,
            avatarSymbol: avatarSymbol,
            avatarImageURL: avatarImageURL,
            coverImageURL: coverImageURL
        )
        withAnimation(.easeInOut(duration: 0.4)) {
            dismiss()
        }
    }

    private func importProfileImage(_ item: PhotosPickerItem?) async {
        guard let item else { return }
        guard let imported = try? await MediaLibrary.shared.importItems([item]),
              let media = imported.first,
              media.kind == .photo else { return }
        await MainActor.run {
            withAnimation(.easeInOut(duration: 0.35)) {
                avatarImageURL = media.url
                avatarPickerItem = nil
            }
        }
    }
}

private enum EditProfileGlassField: Hashable {
    case name
    case surname
}

private struct EditProfileGlassSnapshot: Equatable {
    let name: String
    let surname: String
    let birthday: Date?
    let avatarImageURL: URL?
}

struct SettingsView: View {
    @Environment(AppDependencies.self) private var dependencies
    @State private var confirmsDeletion = false

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 26) {
                Text("Настройки")
                    .font(.system(size: 42, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 24)
                    .padding(.top, 16)

                SettingsGlassSection(title: "Приложение") {
                    SettingsGlassRow(symbol: "circle.lefthalf.filled", title: "Оформление") {
                        dependencies.router.push(.appearance)
                    }
                    SettingsGlassRow(symbol: "hand.tap", title: "Тактильный отклик") {}
                    SettingsGlassRow(symbol: "bell", title: "Уведомления") {}
                    SettingsGlassRow(symbol: "rectangle.inset.filled", title: "Виджет") {}
                    SettingsGlassRow(symbol: "globe", title: "Язык приложения", trailing: "русский") {}
                }

                SettingsGlassSection(title: "Tide") {
                    SettingsGlassRow(symbol: "slider.horizontal.3", title: "Настроить") {}
                    SettingsGlassRow(symbol: "rectangle.connected.to.line.below", title: "Коннекторы") {
                        dependencies.router.push(.botPlatform)
                    }
                    SettingsGlassRow(symbol: "atom", title: "Продвинутые") {
                        dependencies.router.push(.dataManagement)
                    }
                    NavigationLink {
                        ActiveSessionsView()
                    } label: {
                        SettingsGlassRowContent(symbol: "iphone.gen3", title: "Сессии", trailing: nil)
                    }
                    .buttonStyle(.plain)
                    SettingsGlassRow(symbol: "externaldrive", title: "Хранилище") {
                        dependencies.router.push(.storage)
                    }
                }

                SettingsGlassSection(title: nil) {
                    SettingsGlassRow(symbol: "star.square", title: "Детский режим") {}
                    SettingsGlassRow(symbol: "18.square", title: "Настройки контента для взрослых") {}
                }

                SettingsGlassSection(title: "Аккаунт") {
                    SettingsGlassRow(symbol: "rectangle.portrait.and.arrow.right", title: "Выйти", role: .destructive) {
                        withAnimation(.easeInOut(duration: 0.42)) {
                            dependencies.session.signOut()
                            dependencies.router.reset()
                        }
                    }
                    SettingsGlassRow(symbol: "trash", title: "Удалить аккаунт", role: .destructive) {
                        confirmsDeletion = true
                    }
                }
            }
            .padding(.bottom, 36)
        }
        .background {
            TideBackdropView(configuration: dependencies.preferences.backdropConfiguration())
            Color.black.opacity(0.66).ignoresSafeArea()
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog("Удалить этот локальный аккаунт?", isPresented: $confirmsDeletion, titleVisibility: .visible) {
            Button("Удалить аккаунт", role: .destructive) {
                dependencies.session.signOut()
                dependencies.router.reset()
            }
            Button("Отмена", role: .cancel) {}
        }
    }
}

struct AppearanceView: View {
    @Environment(AppDependencies.self) private var dependencies
    @AppStorage("tide.textScale") private var textScale = 0.42
    @State private var wallpaperItem: PhotosPickerItem?
    @State private var isImportingWallpaperFile = false

    var body: some View {
        @Bindable var preferences = dependencies.preferences
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 24) {
                GlassScreenHeader(title: "Оформление")

                HStack(spacing: 14) {
                    appearanceModeCard(title: "Система", symbol: "circle.lefthalf.filled", theme: .system)
                    appearanceModeCard(title: "День", symbol: "sun.max.fill", theme: .light)
                    appearanceModeCard(title: "Ночь", symbol: "moon.fill", theme: .dark)
                }
                .padding(.horizontal, 24)

                VStack(alignment: .leading, spacing: 18) {
                    Text("Размер текста")
                        .font(.system(size: 20, weight: .black, design: .rounded))
                        .foregroundStyle(.secondary)

                    VStack(spacing: 22) {
                        HStack {
                            Text("A")
                                .font(.system(size: 17, weight: .black, design: .rounded))
                            Slider(value: $textScale, in: 0...1)
                                .tint(.white)
                            Text("A")
                                .font(.system(size: 26, weight: .black, design: .rounded))
                        }
                        .foregroundStyle(.secondary)

                        VStack(spacing: 16) {
                            Text("Расскажи мне о Вселенной.")
                                .font(.system(size: CGFloat(19 + textScale * 6), weight: .bold, design: .rounded))
                                .padding(.horizontal, 18)
                                .frame(height: 52)
                                .background(.white.opacity(0.08), in: Capsule())
                            Text("Вселенная — это всё, что существует: пространство, время, материя, энергия и законы, по которым всё работает.")
                                .font(.system(size: CGFloat(18 + textScale * 6), weight: .semibold, design: .rounded))
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            Text("Предпросмотр")
                                .font(.system(size: 18, weight: .black, design: .rounded))
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 26)
                                .frame(height: 44)
                                .background(AuthGlassBackground(cornerRadius: 22, interactive: false))
                        }
                    }
                    .padding(22)
                    .background(AuthGlassBackground(cornerRadius: 28, interactive: false))
                }
                .padding(.horizontal, 24)

                SettingsGlassSection(title: "Обои") {
                    PhotosPicker(selection: $wallpaperItem, matching: .any(of: [.images, .videos])) {
                        SettingsGlassRowContent(symbol: "photo.on.rectangle", title: "Фотогалерея", trailing: preferences.galleryBackdropKind == .none ? nil : preferences.galleryBackdropKind.title)
                    }
                    .buttonStyle(.plain)
                    Button {
                        isImportingWallpaperFile = true
                    } label: {
                        SettingsGlassRowContent(symbol: "folder", title: "Выбрать из файлов", trailing: nil)
                    }
                    .buttonStyle(.plain)
                    if preferences.galleryBackdropKind != .none {
                        wallpaperPreview
                        HStack {
                            Text("Прозрачность")
                            Slider(value: $preferences.galleryBackdropOpacity, in: 0.2...1)
                                .tint(.white)
                        }
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 22)
                        .padding(.vertical, 14)
                        Button(role: .destructive) {
                            preferences.galleryBackdropURLString = ""
                            preferences.galleryBackdropKind = .none
                            preferences.galleryBackdropOpacity = 1
                        } label: {
                            SettingsGlassRowContent(symbol: "trash", title: "Удалить обои", trailing: nil, role: .destructive)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.bottom, 34)
        }
        .background {
            TideBackdropView(configuration: dependencies.preferences.backdropConfiguration())
            Color.black.opacity(0.66).ignoresSafeArea()
        }
        .toolbar(.hidden, for: .navigationBar)
        .navigationBarBackButtonHidden(true)
        .onChange(of: wallpaperItem) { _, item in
            Task { await importWallpaper(item) }
        }
        .fileImporter(isPresented: $isImportingWallpaperFile, allowedContentTypes: [.item], allowsMultipleSelection: false) { result in
            guard case .success(let urls) = result, let url = urls.first else { return }
            Task {
                guard let media = try? await MediaLibrary.shared.importFile(url) else { return }
                await MainActor.run { applyWallpaper(media) }
            }
        }
    }

    private func appearanceModeCard(title: String, symbol: String, theme: PreferencesStore.Theme) -> some View {
        let selected = dependencies.preferences.theme == theme
        return Button {
            withAnimation(.easeInOut(duration: 0.35)) {
                dependencies.preferences.theme = theme
            }
        } label: {
            VStack(spacing: 16) {
                Image(systemName: symbol)
                    .font(.system(size: 34, weight: .black))
                Text(title)
                    .font(.system(size: 18, weight: .black, design: .rounded))
            }
            .foregroundStyle(selected ? .white : .secondary)
            .frame(maxWidth: .infinity)
            .frame(height: 132)
            .background(AuthGlassBackground(cornerRadius: 24, interactive: selected))
        }
        .buttonStyle(.plain)
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
                        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                        .padding(.horizontal, 22)
                }
            case .video:
                ZStack {
                    TideVideoThumbnailView(url: url)
                    Image(systemName: "play.circle.fill")
                        .font(.system(size: 42, weight: .semibold))
                        .foregroundStyle(.white)
                }
                .frame(height: 132)
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                .padding(.horizontal, 22)
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
            applyWallpaper(media)
            wallpaperItem = nil
        }
    }

    private func applyWallpaper(_ media: ComposerMedia) {
        let preferences = dependencies.preferences
        preferences.galleryBackdropURLString = media.url.absoluteString
        preferences.galleryBackdropKind = media.kind == .video ? .video : .image
        preferences.galleryBackdropOpacity = 1
        preferences.backdropStyle = media.kind == .video ? .video : .image
    }
}

struct StorageView: View {
    @Environment(AppDependencies.self) private var dependencies
    @State private var snapshot = MediaStorageSnapshot(files: [])
    @State private var isClearing = false

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 24) {
                GlassScreenHeader(title: "Хранилище")

                Text("Использование кэша")
                    .font(.system(size: 21, weight: .black, design: .rounded))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 40)

                VStack(spacing: 0) {
                    storageRow("Видео Tide", bytes: snapshot.videoBytes)
                    divider
                    storageRow("Изображения Tide", bytes: snapshot.imageBytes)
                    divider
                    storageRow("Аудио и голосовые", bytes: snapshot.audioBytes)
                    divider
                    storageRow("Файлы", bytes: snapshot.documentBytes)
                }
                .padding(.vertical, 10)
                .background(AuthGlassBackground(cornerRadius: 28, interactive: false))
                .padding(.horizontal, 24)

                Text("Кэшированные медиафайлы можно повторно загрузить. Очистка освободит место, но не удалит активные аватары, обложки и вложения из базы.")
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 40)

                Button(role: .destructive) {
                    Task { await clearCache() }
                } label: {
                    Text(isClearing ? "Очищаем..." : "Очистить кэш")
                        .font(.system(size: 20, weight: .black, design: .rounded))
                        .frame(maxWidth: .infinity)
                        .frame(height: 60)
                        .foregroundStyle(.red)
                        .background(AuthGlassBackground(cornerRadius: 30, interactive: !isClearing))
                }
                .buttonStyle(.plain)
                .disabled(isClearing)
                .padding(.horizontal, 24)
            }
            .padding(.bottom, 34)
        }
        .background {
            TideBackdropView(configuration: dependencies.preferences.backdropConfiguration())
            Color.black.opacity(0.68).ignoresSafeArea()
        }
        .toolbar(.hidden, for: .navigationBar)
        .navigationBarBackButtonHidden(true)
        .task { await loadSnapshot() }
    }

    private func storageRow(_ title: String, bytes: Int64) -> some View {
        HStack {
            Text(title)
                .foregroundStyle(.white)
            Spacer()
            Text(formatBytes(bytes))
                .foregroundStyle(.secondary)
        }
        .font(.system(size: 22, weight: .bold, design: .rounded))
        .padding(.horizontal, 22)
        .frame(height: 58)
    }

    private var divider: some View {
        Rectangle()
            .fill(.white.opacity(0.10))
            .frame(height: 1)
            .padding(.leading, 22)
            .padding(.trailing, 18)
    }

    private func loadSnapshot() async {
        let loaded = (try? await MediaLibrary.shared.storageSnapshot()) ?? MediaStorageSnapshot(files: [])
        await MainActor.run { snapshot = loaded }
    }

    private func clearCache() async {
        isClearing = true
        let protectedURLs = dependencies.database.protectedLocalMediaURLs()
        try? await MediaLibrary.shared.clearCache(protecting: protectedURLs)
        await loadSnapshot()
        isClearing = false
    }
}

struct DataManagementView: View {
    @Environment(AppDependencies.self) private var dependencies
    @State private var snapshot = MediaStorageSnapshot(files: [])

    var body: some View {
        VStack(alignment: .leading, spacing: 34) {
            GlassScreenHeader(title: "Управление данными")

            Button {
                dependencies.router.push(.storageFiles)
            } label: {
                HStack(spacing: 16) {
                    Image(systemName: "cylinder.split.1x2")
                        .font(.system(size: 25, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 34)
                    Text("Управление облачным хранилищем")
                        .font(.system(size: 22, weight: .black, design: .rounded))
                    Spacer()
                    Text(formatBytes(snapshot.totalBytes))
                        .font(.system(size: 21, weight: .black, design: .rounded))
                        .foregroundStyle(.secondary)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 19, weight: .black))
                        .foregroundStyle(.secondary)
                }
                .foregroundStyle(.white)
                .padding(22)
                .background(AuthGlassBackground(cornerRadius: 28, interactive: true))
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 24)

            Spacer()
        }
        .background {
            TideBackdropView(configuration: dependencies.preferences.backdropConfiguration())
            Color.black.opacity(0.68).ignoresSafeArea()
        }
        .toolbar(.hidden, for: .navigationBar)
        .navigationBarBackButtonHidden(true)
        .task { snapshot = (try? await MediaLibrary.shared.storageSnapshot()) ?? MediaStorageSnapshot(files: []) }
    }
}

struct StorageFilesView: View {
    @Environment(AppDependencies.self) private var dependencies
    @State private var snapshot = MediaStorageSnapshot(files: [])
    @State private var filter: StorageFileFilter = .all
    @State private var sort: StorageFileSort = .recent

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                GlassBackButton()
                Spacer()
                VStack(spacing: 2) {
                    Text(formatBytes(snapshot.totalBytes))
                        .font(.system(size: 26, weight: .black, design: .rounded))
                    Text("\(snapshot.files.count) файлов")
                        .font(.system(size: 14, weight: .black, design: .rounded))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                filterMenu
            }
            .padding(.horizontal, 24)
            .padding(.top, 12)
            .padding(.bottom, 18)

            if visibleFiles.isEmpty {
                ContentUnavailableView("Файлов нет", systemImage: "tray", description: Text("Здесь появятся загруженные фото, видео, аудио и документы."))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView(showsIndicators: false) {
                    LazyVStack(spacing: 0) {
                        ForEach(visibleFiles) { file in
                            storageFileRow(file)
                            Rectangle()
                                .fill(.white.opacity(0.08))
                                .frame(height: 1)
                                .padding(.leading, 126)
                        }
                    }
                    .padding(.bottom, 26)
                }
            }
        }
        .background {
            TideBackdropView(configuration: dependencies.preferences.backdropConfiguration())
            Color.black.opacity(0.72).ignoresSafeArea()
        }
        .toolbar(.hidden, for: .navigationBar)
        .navigationBarBackButtonHidden(true)
        .task { snapshot = (try? await MediaLibrary.shared.storageSnapshot()) ?? MediaStorageSnapshot(files: []) }
    }

    private var filterMenu: some View {
        Menu {
            ForEach(StorageFileFilter.allCases) { item in
                Button {
                    filter = item
                } label: {
                    if filter == item {
                        Label(item.title, systemImage: "checkmark")
                    } else {
                        Text(item.title)
                    }
                }
            }
            Divider()
            Section("Сортировать по") {
                ForEach(StorageFileSort.allCases) { item in
                    Button {
                        sort = item
                    } label: {
                        if sort == item {
                            Label(item.title, systemImage: "checkmark")
                        } else {
                            Text(item.title)
                        }
                    }
                }
            }
        } label: {
            Image(systemName: "line.3.horizontal.decrease")
                .font(.system(size: 25, weight: .black))
                .foregroundStyle(.white)
                .frame(width: 58, height: 58)
                .background(AuthGlassBackground(cornerRadius: 29, interactive: true))
        }
    }

    private var visibleFiles: [MediaStoredFile] {
        let filtered = snapshot.files.filter { file in
            switch filter {
            case .all: true
            case .images: file.category == .images
            case .videos: file.category == .videos
            case .documents: file.category == .files
            case .audio: file.category == .audio
            }
        }
        switch sort {
        case .recent:
            return filtered.sorted { $0.createdAt > $1.createdAt }
        case .created:
            return filtered.sorted { $0.createdAt < $1.createdAt }
        case .name:
            return filtered.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        case .size:
            return filtered.sorted { $0.byteCount > $1.byteCount }
        }
    }

    private func storageFileRow(_ file: MediaStoredFile) -> some View {
        HStack(spacing: 18) {
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .stroke(.secondary.opacity(0.55), lineWidth: 2)
                .frame(width: 28, height: 28)

            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(.white.opacity(0.08))
                    .frame(width: 74, height: 74)
                Image(systemName: icon(for: file.category))
                    .font(.system(size: 31, weight: .semibold))
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(file.name.isEmpty ? "Untitled" : file.name)
                    .font(.system(size: 21, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Text("\(formatBytes(file.byteCount)) • \(file.createdAt.formatted(.relative(presentation: .named)))")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 14)
    }

    private func icon(for category: MediaStorageCategory) -> String {
        switch category {
        case .images: "photo"
        case .videos: "play.rectangle.fill"
        case .audio: "waveform"
        case .files: "doc"
        }
    }
}

struct ActiveSessionsView: View {
    @Environment(AppDependencies.self) private var dependencies
    @State private var sessions: [DeviceSession] = []

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 24) {
                GlassScreenHeader(title: "Сессии")

                SettingsGlassSection(title: "Активные устройства") {
                    ForEach(sessions) { session in
                        HStack(spacing: 16) {
                            Image(systemName: session.isCurrent ? "iphone.gen3" : "desktopcomputer")
                                .font(.system(size: 26, weight: .semibold))
                                .foregroundStyle(.secondary)
                                .frame(width: 34)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(session.isCurrent ? "\(session.deviceName) · текущее" : session.deviceName)
                                    .font(.system(size: 19, weight: .black, design: .rounded))
                                    .foregroundStyle(.white)
                                Text("\(session.systemVersion) · \(session.lastSeenAt.formatted(.relative(presentation: .named)))")
                                    .font(.system(size: 14, weight: .bold, design: .rounded))
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            if !session.isCurrent {
                                Button("Завершить", role: .destructive) {
                                    dependencies.deviceSessions.terminate(session, currentUserID: dependencies.session.currentUser?.id)
                                    reload()
                                }
                                .font(.system(size: 15, weight: .black, design: .rounded))
                            }
                        }
                        .padding(.horizontal, 22)
                        .frame(height: 76)
                    }
                }

                Text("Текущую сессию можно завершить только через выход из аккаунта.")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 40)
            }
            .padding(.bottom, 34)
        }
        .background {
            TideBackdropView(configuration: dependencies.preferences.backdropConfiguration())
            Color.black.opacity(0.68).ignoresSafeArea()
        }
        .toolbar(.hidden, for: .navigationBar)
        .navigationBarBackButtonHidden(true)
        .task { reload() }
    }

    private func reload() {
        dependencies.deviceSessions.reload(for: dependencies.session.currentUser?.id)
        sessions = dependencies.deviceSessions.sessions
    }
}

private struct GlassScreenHeader: View {
    let title: String

    var body: some View {
        HStack {
            GlassBackButton()
            Spacer()
            Text(title)
                .font(.system(size: 28, weight: .black, design: .rounded))
                .foregroundStyle(.white)
            Spacer()
            Color.clear.frame(width: 58, height: 58)
        }
        .padding(.horizontal, 24)
        .padding(.top, 12)
    }
}

private struct GlassBackButton: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Button { dismiss() } label: {
            Image(systemName: "chevron.left")
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 58, height: 58)
                .background(AuthGlassBackground(cornerRadius: 29, interactive: true))
        }
        .buttonStyle(.plain)
    }
}

private struct SettingsGlassSection<Content: View>: View {
    let title: String?
    @ViewBuilder var content: Content

    init(title: String?, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let title {
                Text(title)
                    .font(.system(size: 21, weight: .black, design: .rounded))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 24)
            }
            VStack(spacing: 0) {
                content
            }
            .background(AuthGlassBackground(cornerRadius: 30, interactive: false))
            .padding(.horizontal, 24)
        }
    }
}

private struct SettingsGlassRow: View {
    let symbol: String
    let title: String
    var trailing: String?
    var role: ButtonRole?
    let action: () -> Void

    var body: some View {
        Button(role: role, action: action) {
            SettingsGlassRowContent(symbol: symbol, title: title, trailing: trailing, role: role)
        }
        .buttonStyle(.plain)
    }
}

private struct SettingsGlassRowContent: View {
    let symbol: String
    let title: String
    var trailing: String?
    var role: ButtonRole?

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: symbol)
                .font(.system(size: 27, weight: .semibold))
                .foregroundStyle(role == .destructive ? .red : .secondary)
                .frame(width: 34)
            Text(title)
                .font(.system(size: 22, weight: .black, design: .rounded))
                .foregroundStyle(role == .destructive ? .red : .white)
            Spacer()
            if let trailing {
                Text(trailing)
                    .font(.system(size: 21, weight: .black, design: .rounded))
                    .foregroundStyle(.secondary)
            }
            Image(systemName: "chevron.right")
                .font(.system(size: 19, weight: .black))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 22)
        .frame(height: 68)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(.white.opacity(0.10))
                .frame(height: 1)
                .padding(.leading, 78)
                .padding(.trailing, 18)
        }
    }
}

private enum StorageFileFilter: CaseIterable, Identifiable {
    case all
    case images
    case videos
    case documents
    case audio

    var id: String { title }

    var title: String {
        switch self {
        case .all: "Все"
        case .images: "Изображения"
        case .videos: "Видео"
        case .documents: "Документы"
        case .audio: "Качество звука"
        }
    }
}

private enum StorageFileSort: CaseIterable, Identifiable {
    case recent
    case created
    case name
    case size

    var id: String { title }

    var title: String {
        switch self {
        case .recent: "Недавние"
        case .created: "Дата создания"
        case .name: "Имя"
        case .size: "Размер"
        }
    }
}

private func formatBytes(_ bytes: Int64) -> String {
    ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
}
