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
            editProfileBackground.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 16) {
                    topBar
                    avatarEditor
                    identityCard
                    birthdayCard
                    accountCard
                    if let footnote = authInfo.providerFootnote {
                        Text(footnote)
                            .font(.system(size: 13, weight: .regular))
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 28)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
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

    private var editProfileBackground: Color {
        Color(red: 64.0 / 255.0, green: 64.0 / 255.0, blue: 64.0 / 255.0)
    }

    private var topBar: some View {
        HStack(spacing: 12) {
            Button { dismiss() } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 40, height: 40)
                    .background(StandardPanelBackground(cornerRadius: 16))
            }
            .buttonStyle(.plain)

            Text("Профиль")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, alignment: .leading)

            Button(action: saveProfile) {
                Text("Сохранить")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(canSave ? .white : .secondary)
                    .padding(.horizontal, 16)
                    .frame(height: 40)
                    .background(StandardPanelBackground(cornerRadius: 16))
            }
            .buttonStyle(.plain)
            .disabled(!canSave)
        }
        .padding(.top, 4)
    }

    private var avatarEditor: some View {
        VStack(spacing: 0) {
            profileAvatarPreview
                .shadow(color: .black.opacity(0.22), radius: 14, y: 8)

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
                    .font(.system(size: 16, weight: .semibold))
                }
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 14)
                .frame(height: 36)
                .background(StandardPanelBackground(cornerRadius: 16))
            }
            .buttonStyle(.plain)
            .offset(y: -12)
        }
        .padding(.top, 8)
    }

    private var identityCard: some View {
        VStack(spacing: 0) {
            standardTextField("Имя", text: $name, field: .name)
            divider
            standardTextField("Фамилия", text: $surname, field: .surname)
        }
        .padding(.vertical, 4)
        .background(EditProfileCardBackground(cornerRadius: 22))
        .padding(.horizontal, 16)
        .overlay(alignment: .bottomLeading) {
            if let validationMessage {
                Text(validationMessage)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.red)
                    .offset(x: 28, y: 20)
            }
        }
    }

    private var birthdayCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Toggle("Показывать дату рождения", isOn: Binding(
                get: { hasBirthday },
                set: { value in
                    withAnimation(.easeInOut(duration: 0.35)) {
                        hasBirthday = value
                    }
                }
            ))
                .tint(.green)
            if hasBirthday {
                DatePicker("День рождения", selection: $birthday, displayedComponents: .date)
                    .datePickerStyle(.wheel)
                    .labelsHidden()
                    .frame(maxWidth: .infinity)
                    .frame(height: 156)
                    .clipped()
                    .transition(.opacity.combined(with: .move(edge: .top)))
            } else {
                HStack {
                    Text("Год рождения")
                    Spacer()
                    Text("Не указан")
                        .foregroundStyle(.secondary)
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .animation(.easeInOut(duration: 0.35), value: hasBirthday)
        .font(.system(size: 15, weight: .semibold))
        .foregroundStyle(.white)
        .padding(12)
        .background(EditProfileCardBackground(cornerRadius: 22))
        .padding(.horizontal, 16)
    }

    private var accountCard: some View {
        VStack(spacing: 0) {
            HStack(alignment: .top, spacing: 12) {
                Text("Электронная почта")
                    .foregroundStyle(.white)
                Spacer()
                Text(authInfo.email.isEmpty ? "Не указана" : authInfo.email)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.trailing)
                    .lineLimit(2)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

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
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .buttonStyle(.plain)
        }
        .font(.system(size: 15, weight: .regular))
        .background(EditProfileCardBackground(cornerRadius: 22))
        .padding(.horizontal, 16)
    }

    private var profileAvatarPreview: some View {
        ZStack {
            Circle()
                .fill(LinearGradient(
                    colors: [Color(red: 0.0, green: 0.34, blue: 0.29), Color(red: 0.0, green: 0.18, blue: 0.16)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ))
                .frame(width: 96, height: 96)
            if let avatarImageURL,
               let image = UIImage(contentsOfFile: avatarImageURL.path) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 96, height: 96)
                    .clipShape(Circle())
            } else {
                Text(String(name.first ?? surname.first ?? Character("M")).uppercased())
                    .font(.system(size: 48, weight: .regular, design: .rounded))
                    .foregroundStyle(.white)
            }
        }
    }

    private func standardTextField(_ placeholder: String, text: Binding<String>, field: EditProfileGlassField) -> some View {
        TextField(placeholder, text: text)
            .focused($focusedField, equals: field)
            .textInputAutocapitalization(.words)
            .font(.system(size: 15, weight: .regular))
            .foregroundStyle(.white)
            .padding(.horizontal, 16)
            .frame(height: 48)
    }

    private var divider: some View {
        Rectangle()
            .fill(.white.opacity(0.08))
            .frame(height: 1)
            .padding(.leading, 16)
            .padding(.trailing, 16)
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

private struct EditProfileCardBackground: View {
    let cornerRadius: CGFloat

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(Color(red: 78.0 / 255.0, green: 78.0 / 255.0, blue: 78.0 / 255.0).opacity(0.90))
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(Color.white.opacity(0.06), lineWidth: 1)
            }
            .shadow(color: .black.opacity(0.10), radius: 10, y: 5)
    }
}

private struct StandardPanelBackground: View {
    let cornerRadius: CGFloat

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(Color(red: 72.0 / 255.0, green: 72.0 / 255.0, blue: 72.0 / 255.0).opacity(0.90))
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(Color.white.opacity(0.06), lineWidth: 1)
            }
            .shadow(color: .black.opacity(0.10), radius: 8, y: 4)
    }
}

struct SettingsView: View {
    @Environment(AppDependencies.self) private var dependencies

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 16) {
                GlassScreenHeader(title: "Настройки")
                    .padding(.top, 8)

                SettingsProfileCard(
                    user: dependencies.session.currentUser,
                    authInfo: dependencies.session.currentAuthInfo()
                )
                .padding(.horizontal, 16)

                SettingsGlassSection(title: "Информация") {
                    SettingsGlassRowContent(
                        symbol: "checkmark.seal",
                        title: "Старые настройки и редактирование профиля удалены",
                        trailing: nil,
                        role: nil,
                        showsChevron: false
                    )
                }
            }
            .padding(.bottom, 28)
        }
        .background(SettingsScreenBackground().ignoresSafeArea())
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct SettingsProfileCard: View {
    let user: User?
    let authInfo: AuthAccountInfo

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            if let user {
                AvatarView(user: user, size: 68)
            } else {
                Circle()
                    .fill(.white.opacity(0.08))
                    .frame(width: 68, height: 68)
                    .overlay {
                        Image(systemName: "person.crop.circle.fill")
                            .font(.system(size: 30, weight: .semibold))
                            .foregroundStyle(.secondary)
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                if let user {
                    VerifiedName(user: user)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(.white)
                    Text(user.handle)
                        .font(.system(size: 14, weight: .regular))
                        .foregroundStyle(.secondary)
                    if !user.biography.isEmpty {
                        Text(user.biography)
                            .font(.system(size: 14, weight: .regular))
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                } else {
                    Text("Профиль")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(.white)
                    Text("Откройте профиль, чтобы изменить имя, фото и био.")
                        .font(.system(size: 14, weight: .regular))
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                HStack(spacing: 8) {
                    Label(authInfo.provider.title, systemImage: authInfo.provider == .email ? "envelope" : "person.crop.circle")
                        .font(.system(size: 12, weight: .semibold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(.white.opacity(0.08), in: Capsule())

                    if !authInfo.email.isEmpty {
                        Text(authInfo.email)
                            .font(.system(size: 12, weight: .regular))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }

                if let footnote = authInfo.providerFootnote {
                    Text(footnote)
                        .font(.system(size: 12, weight: .regular))
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(SignalSettingsCardBackground())
    }
}

private struct SettingsToggleRow: View {
    let symbol: String
    let title: String
    @Binding var isOn: Bool

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: symbol)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(width: 24)

            Text(title)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white)

            Spacer()

            Toggle("", isOn: $isOn)
                .labelsHidden()
                .tint(.green)
        }
        .padding(.horizontal, 16)
        .frame(height: 48)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(.white.opacity(0.07))
                .frame(height: 1)
                .padding(.leading, 52)
                .padding(.trailing, 16)
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
            VStack(alignment: .leading, spacing: 14) {
                GlassScreenHeader(title: "Оформление")

                HStack(spacing: 10) {
                    appearanceModeCard(title: "Система", symbol: "circle.lefthalf.filled", theme: .system)
                    appearanceModeCard(title: "День", symbol: "sun.max.fill", theme: .light)
                    appearanceModeCard(title: "Ночь", symbol: "moon.fill", theme: .dark)
                }
                .padding(.horizontal, 16)

                VStack(alignment: .leading, spacing: 14) {
                    Text("Размер текста")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.secondary)

                    VStack(spacing: 22) {
                        HStack {
                            Text("A")
                                .font(.system(size: 16, weight: .semibold))
                            Slider(value: $textScale, in: 0...1)
                                .tint(.green)
                            Text("A")
                                .font(.system(size: 20, weight: .semibold))
                        }
                        .foregroundStyle(.secondary)

                        VStack(spacing: 16) {
                            Text("Расскажи мне о Вселенной.")
                                .font(.system(size: CGFloat(17 + textScale * 4), weight: .semibold))
                                .padding(.horizontal, 18)
                                .frame(height: 48)
                                .background(.white.opacity(0.08), in: Capsule())
                            Text("Вселенная — это всё, что существует: пространство, время, материя, энергия и законы, по которым всё работает.")
                                .font(.system(size: CGFloat(16 + textScale * 4), weight: .regular))
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            Text("Предпросмотр")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 26)
                                .frame(height: 40)
                                .background(StandardPanelBackground(cornerRadius: 16))
                        }
                    }
                    .padding(14)
                    .background(StandardPanelBackground(cornerRadius: 16))
                }
                .padding(.horizontal, 16)

                SettingsGlassSection(title: "Обои") {
                    Menu {
                        PhotosPicker(selection: $wallpaperItem, matching: .any(of: [.images, .videos])) {
                            Label("Фотогалерея", systemImage: "photo.on.rectangle")
                        }
                        Button {
                            isImportingWallpaperFile = true
                        } label: {
                            Label("Выбрать из файлов", systemImage: "folder")
                        }
                    } label: {
                        SettingsGlassRowContent(
                            symbol: "photo.on.rectangle",
                            title: "Сменить",
                            trailing: preferences.galleryBackdropKind == .none ? nil : preferences.galleryBackdropKind.title
                        )
                    }
                    .buttonStyle(.plain)
                    if preferences.galleryBackdropKind != .none {
                        wallpaperPreview
                        HStack {
                            Text("Прозрачность")
                            Slider(value: $preferences.galleryBackdropOpacity, in: 0.2...1)
                                .tint(.green)
                        }
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
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
        .background(SettingsScreenBackground().ignoresSafeArea())
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
            VStack(spacing: 10) {
                Image(systemName: symbol)
                    .font(.system(size: 18, weight: .semibold))
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
            }
            .foregroundStyle(selected ? .white : .secondary)
            .frame(maxWidth: .infinity)
            .frame(height: 88)
            .background(StandardPanelBackground(cornerRadius: 18))
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
                        .frame(height: 104)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .padding(.horizontal, 16)
                }
            case .video:
                ZStack {
                    TideVideoThumbnailView(url: url)
                    Image(systemName: "play.circle.fill")
                        .font(.system(size: 34, weight: .semibold))
                        .foregroundStyle(.white)
                }
                .frame(height: 104)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .padding(.horizontal, 16)
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
            VStack(alignment: .leading, spacing: 14) {
                GlassScreenHeader(title: "Хранилище")

                Text("Использование кэша")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 32)

                VStack(spacing: 0) {
                    storageRow("Видео Tide", bytes: snapshot.videoBytes)
                    divider
                    storageRow("Изображения Tide", bytes: snapshot.imageBytes)
                    divider
                    storageRow("Аудио и голосовые", bytes: snapshot.audioBytes)
                    divider
                    storageRow("Файлы", bytes: snapshot.documentBytes)
                }
                .padding(.vertical, 6)
                .background(AuthGlassBackground(cornerRadius: 22, interactive: false))
                .padding(.horizontal, 16)

                Text("Кэшированные медиафайлы можно повторно загрузить. Очистка освободит место, но не удалит активные аватары, обложки и вложения из базы.")
                    .font(.system(size: 14, weight: .regular))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 32)

                Button(role: .destructive) {
                    Task { await clearCache() }
                } label: {
                    Text(isClearing ? "Очищаем..." : "Очистить кэш")
                        .font(.system(size: 16, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .foregroundStyle(.red)
                        .background(AuthGlassBackground(cornerRadius: 22, interactive: !isClearing))
                }
                .buttonStyle(.plain)
                .disabled(isClearing)
                .padding(.horizontal, 16)
            }
            .padding(.bottom, 34)
        }
        .background(SettingsScreenBackground().ignoresSafeArea())
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
        .font(.system(size: 16, weight: .semibold))
        .padding(.horizontal, 16)
        .frame(height: 48)
    }

    private var divider: some View {
        Rectangle()
            .fill(.white.opacity(0.10))
            .frame(height: 1)
            .padding(.leading, 16)
            .padding(.trailing, 16)
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
        VStack(alignment: .leading, spacing: 22) {
            GlassScreenHeader(title: "Управление данными")

            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 12) {
                    Image(systemName: "cylinder.split.1x2")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 24)
                    Text("Управление облачным хранилищем")
                        .font(.system(size: 16, weight: .semibold))
                    Spacer()
                    Text(formatBytes(snapshot.totalBytes))
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.secondary)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.secondary)
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 16)
                .frame(height: 64)
                .background(StandardPanelBackground(cornerRadius: 16))
                Text("Список файлов больше не доступен.")
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 16)
            }
            .padding(.horizontal, 16)

            Spacer()
        }
        .background(SettingsScreenBackground().ignoresSafeArea())
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
                        .font(.system(size: 22, weight: .semibold))
                    Text("\(snapshot.files.count) файлов")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                filterMenu
            }
            .padding(.horizontal, 16)
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
                                .padding(.leading, 106)
                        }
                    }
                    .padding(.bottom, 26)
                }
            }
        }
        .background(SettingsScreenBackground().ignoresSafeArea())
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
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 40, height: 40)
                .background(StandardPanelBackground(cornerRadius: 16))
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
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .stroke(.secondary.opacity(0.55), lineWidth: 2)
                .frame(width: 24, height: 24)

            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(.white.opacity(0.08))
                    .frame(width: 54, height: 54)
                Image(systemName: icon(for: file.category))
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(file.name.isEmpty ? "Untitled" : file.name)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Text("\(formatBytes(file.byteCount)) • \(file.createdAt.formatted(.relative(presentation: .named)))")
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
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
            VStack(alignment: .leading, spacing: 14) {
                GlassScreenHeader(title: "Сессии")

                SettingsGlassSection(title: "Активные устройства") {
                    ForEach(sessions) { session in
                        HStack(spacing: 16) {
                            Image(systemName: session.isCurrent ? "iphone.gen3" : "desktopcomputer")
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundStyle(.secondary)
                                .frame(width: 24)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(session.isCurrent ? "\(session.deviceName) · текущее" : session.deviceName)
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundStyle(.white)
                                Text("\(session.systemVersion) · \(session.lastSeenAt.formatted(.relative(presentation: .named)))")
                                    .font(.system(size: 13, weight: .regular))
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            if !session.isCurrent {
                                Button("Завершить", role: .destructive) {
                                    dependencies.deviceSessions.terminate(session, currentUserID: dependencies.session.currentUser?.id)
                                    reload()
                                }
                                .font(.system(size: 14, weight: .semibold))
                            }
                        }
                        .padding(.horizontal, 16)
                        .frame(height: 64)
                    }
                }

                Text("Текущую сессию можно завершить только через выход из аккаунта.")
                    .font(.system(size: 14, weight: .regular))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 32)
            }
            .padding(.bottom, 34)
        }
        .background(SettingsScreenBackground().ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .navigationBarBackButtonHidden(true)
        .task { reload() }
    }

    private func reload() {
        dependencies.deviceSessions.reload(for: dependencies.session.currentUser?.id)
        sessions = dependencies.deviceSessions.sessions
    }
}

struct GlassScreenHeader: View {
    let title: String

    var body: some View {
        HStack {
            GlassBackButton()
            Spacer()
            Text(title)
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(.white)
            Spacer()
            Color.clear.frame(width: 40, height: 40)
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }
}

struct GlassBackButton: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Button { dismiss() } label: {
            Image(systemName: "chevron.left")
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 40, height: 40)
                .tideGlass(interactive: true, cornerRadius: 18, tint: .white.opacity(0.08))
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
        VStack(alignment: .leading, spacing: 8) {
            if let title {
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 16)
            }
            VStack(spacing: 0) {
                content
            }
            .background(SignalSettingsSectionBackground())
            .padding(.horizontal, 16)
        }
    }
}

private struct SettingsGlassRow: View {
    let symbol: String
    let title: String
    var trailing: String?
    var role: ButtonRole?
    var showsChevron = true
    let action: () -> Void

    var body: some View {
        Button(role: role, action: action) {
            SettingsGlassRowContent(symbol: symbol, title: title, trailing: trailing, role: role, showsChevron: showsChevron)
        }
        .buttonStyle(.plain)
    }
}

private struct SettingsGlassRowContent: View {
    let symbol: String
    let title: String
    var trailing: String?
    var role: ButtonRole?
    var showsChevron = true

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: symbol)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(role == .destructive ? .red : .secondary)
                .frame(width: 24)
            Text(title)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(role == .destructive ? .red : .white)
            Spacer()
            if let trailing {
                Text(trailing)
                    .font(.system(size: 15, weight: .regular))
                    .foregroundStyle(.secondary)
            }
            if showsChevron {
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 16)
        .frame(height: 48)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(.white.opacity(0.08))
                .frame(height: 1)
                .padding(.leading, 52)
                .padding(.trailing, 16)
        }
    }
}

private struct SignalSettingsSectionBackground: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 18, style: .continuous)
            .fill(.ultraThinMaterial)
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Color.white.opacity(0.10), lineWidth: 0.8)
            }
    }
}

private struct SignalSettingsCardBackground: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 24, style: .continuous)
            .fill(.ultraThinMaterial)
            .overlay {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(Color.white.opacity(0.10), lineWidth: 0.8)
            }
    }
}


struct SettingsScreenBackground: View {
    var body: some View {
        LinearGradient(
            colors: [
                Color(red: 0.08, green: 0.08, blue: 0.09),
                Color(red: 0.06, green: 0.06, blue: 0.07),
            ],
            startPoint: .top,
            endPoint: .bottom
        )
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
