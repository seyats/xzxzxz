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
                        ContentUnavailableView("РџРѕСЃС‚РѕРІ РЅРµС‚", systemImage: "rectangle.stack", description: Text("РћРїСѓР±Р»РёРєРѕРІР°РЅРЅС‹Рµ РїРѕСЃС‚С‹ Р±СѓРґСѓС‚ РѕС‚РѕР±СЂР°Р¶Р°С‚СЊСЃСЏ Р·РґРµСЃСЊ."))
                            .padding(.top, 38)
                    }
                    ForEach(visiblePosts) { post in
                        PostCard(post: post)
                        Divider().padding(.leading, 68)
                    }
                } header: {
                    Picker("Р Р°Р·РґРµР» РїСЂРѕС„РёР»СЏ", selection: $section) {
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
                    Button(profile.isBlocked ? "Р Р°Р·Р±Р»РѕРєРёСЂРѕРІР°С‚СЊ" : "Р—Р°Р±Р»РѕРєРёСЂРѕРІР°С‚СЊ", role: .destructive, action: toggleBlock)
                    Button("РџРѕР¶Р°Р»РѕРІР°С‚СЊСЃСЏ", role: .destructive) { dependencies.router.sheet = .report(profile.id, "user") }
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
                    Button(String(localized: "profile_edit_profile_button")) { dependencies.router.sheet = .editProfile }.buttonStyle(TideSecondaryButtonStyle())
                } else {
                    Button(String(localized: "profile_message"), action: startMessage).buttonStyle(TideSecondaryButtonStyle())
                    Button(profile.isFollowing ? String(localized: "profile_following_state") : String(localized: "profile_follow"), action: toggleFollow).buttonStyle(TidePrimaryButtonStyle())
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
                        Text("Р°РєРєР°СѓРЅС‚ РІРµСЂРёС„РёС†РёСЂРѕРІР°РЅ")
                    }
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                }
                Text(profile.biography)
                Text("\(String(localized: "profile_joined")) \(profile.joinedAt.formatted(.dateTime.month(.wide).year()))")
                    .font(.subheadline).foregroundStyle(.secondary)
                HStack(spacing: 20) {
                    counter(profile.following, String(localized: "profile_following"))
                    counter(profile.followers, String(localized: "profile_followers"))
                    counter(authoredPosts.count, String(localized: "profile_posts"))
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
        case .posts: "РџРѕСЃС‚С‹"
        case .media: "РњРµРґРёР°"
        case .saved: "РЎРѕС…СЂР°РЅС‘РЅРЅРѕРµ"
        case .likes: "Р›Р°Р№РєРё"
        }
    }
}

struct EditProfileView: View {
    @Environment(AppDependencies.self) private var dependencies
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var username = ""
    @State private var biography = ""
    @State private var location = ""
    @State private var website = ""
    @State private var birthday = Date()
    @State private var hasBirthday = false
    @State private var avatarSymbol = "person.crop.circle.fill"
    @State private var avatarImageURL: URL?
    @State private var coverImageURL: URL?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    bannerSection
                        .padding(.top, 10)

                    avatarBlock
                        .padding(.top, -58)

                    VStack(spacing: 12) {
                        profileField(title: "Name") {
                            TextField("", text: $name)
                                .textContentType(.name)
                        }
                        profileField(title: "Username") {
                            TextField("", text: $username)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                                .textContentType(.username)
                        }
                        profileField(title: "Bio") {
                            TextEditor(text: $biography)
                                .frame(minHeight: 100)
                                .scrollContentBackground(.hidden)
                        }
                        profileField(title: "Location") {
                            TextField("", text: $location)
                                .textContentType(.fullStreetAddress)
                        }
                        profileField(title: "Website") {
                            TextField("", text: $website)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                                .keyboardType(.URL)
                                .textContentType(.URL)
                        }
                        profileField(title: "Birthday") {
                            VStack(alignment: .leading, spacing: 10) {
                                Toggle("Show birthday", isOn: $hasBirthday)
                                    .toggleStyle(.switch)
                                if hasBirthday {
                                    DatePicker("", selection: $birthday, displayedComponents: .date)
                                        .labelsHidden()
                                        .datePickerStyle(.compact)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 24)
                }
            }
            .scrollContentBackground(.hidden)
            .background(
                LinearGradient(
                    colors: [
                        .black,
                        .white.opacity(0.02),
                        .black
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
            )
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 14, weight: .semibold))
                            .frame(width: 38, height: 38)
                            .background(AuthGlassBackground(cornerRadius: 18, interactive: true))
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        dependencies.session.updateProfile(
                            name: name,
                            username: username,
                            biography: biography,
                            location: location,
                            website: website,
                            birthday: hasBirthday ? birthday : nil,
                            avatarSymbol: avatarSymbol,
                            avatarImageURL: avatarImageURL,
                            coverImageURL: coverImageURL
                        )
                        dismiss()
                    }
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .frame(height: 36)
                    .background(AuthGlassBackground(cornerRadius: 18, interactive: true))
                }
            }
            .toolbarBackground(.hidden, for: .navigationBar)
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                let user = dependencies.session.currentUser
                name = user?.name ?? ""
                username = user?.username ?? ""
                biography = user?.biography ?? ""
                location = user?.location ?? ""
                website = user?.website ?? ""
                if let birthdayValue = user?.birthday {
                    birthday = birthdayValue
                    hasBirthday = true
                } else {
                    hasBirthday = false
                }
                avatarSymbol = user?.avatarSymbol ?? avatarSymbol
                avatarImageURL = user?.avatarImageURL
                coverImageURL = user?.coverImageURL
            }
        }
    }

    private var bannerSection: some View {
        ZStack(alignment: .bottomLeading) {
            Group {
                if let coverImageURL, let image = UIImage(contentsOfFile: coverImageURL.path) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                } else {
                    ZStack {
                        LinearGradient(
                            colors: [
                                .white.opacity(0.18),
                                .white.opacity(0.04),
                                .clear
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                        Circle()
                            .fill(.white.opacity(0.14))
                            .frame(width: 220, height: 220)
                            .offset(x: 98, y: -56)
                        Circle()
                            .fill(.white.opacity(0.07))
                            .frame(width: 140, height: 140)
                            .offset(x: -92, y: 42)
                    }
                }
            }
            .frame(height: 220)
            .frame(maxWidth: .infinity)
            .clipped()
            .overlay(
                RoundedRectangle(cornerRadius: 34, style: .continuous)
                    .stroke(.white.opacity(0.14), lineWidth: 0.6)
            )
            .background(AuthGlassBackground(cornerRadius: 34, interactive: false))

            VStack(alignment: .leading, spacing: 4) {
                Text("Edit Profile")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.95))
                Text("Liquid glass banner")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white.opacity(0.5))
            }
            .padding(18)
        }
        .clipShape(RoundedRectangle(cornerRadius: 34, style: .continuous))
        .padding(.horizontal, 16)
    }

    private var avatarBlock: some View {
        VStack(spacing: 10) {
            AvatarView(user: previewUser, size: 114)
                .padding(5)
                .background(.black.opacity(0.18), in: Circle())
                .overlay(Circle().stroke(.white.opacity(0.18), lineWidth: 0.7))
            Text("Avatar and cover remain in sync")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)
        }
    }

    private func profileField<Content: View>(title: String, @ViewBuilder content: @escaping () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.secondary)
            content()
                .font(.system(size: 16, weight: .regular))
                .tint(.white)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(AuthGlassBackground(cornerRadius: 22, interactive: true))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(.white.opacity(0.1), lineWidth: 0.5)
        )
    }

    private var previewUser: User {
        User(
            id: dependencies.session.currentUser?.id ?? UUID(),
            name: name.isEmpty ? (dependencies.session.currentUser?.name ?? "") : name,
            username: username.isEmpty ? (dependencies.session.currentUser?.username ?? "") : username,
            biography: biography,
            avatarSymbol: avatarSymbol,
            avatarImageURL: avatarImageURL,
            isVerified: dependencies.session.currentUser?.isVerified ?? false,
            isAdministrator: dependencies.session.currentUser?.isAdministrator ?? false,
            followers: dependencies.session.currentUser?.followers ?? 0,
            following: dependencies.session.currentUser?.following ?? 0,
            joinedAt: dependencies.session.currentUser?.joinedAt ?? .now,
            coverSymbol: dependencies.session.currentUser?.coverSymbol ?? "water",
            coverImageURL: coverImageURL,
            location: location.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : location.trimmingCharacters(in: .whitespacesAndNewlines),
            website: website.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : website.trimmingCharacters(in: .whitespacesAndNewlines),
            birthday: hasBirthday ? birthday : nil,
            status: dependencies.session.currentUser?.status ?? .active,
            lastSeenAt: dependencies.session.currentUser?.lastSeenAt ?? .now,
            isFollowing: dependencies.session.currentUser?.isFollowing ?? false,
            isBlocked: dependencies.session.currentUser?.isBlocked ?? false
        )
    }
}

struct SettingsView: View {
    @Environment(AppDependencies.self) private var dependencies
    @State private var confirmsDeletion = false

    var body: some View {
        @Bindable var preferences = dependencies.preferences
        Form {
            Section("РћС„РѕСЂРјР»РµРЅРёРµ") {
                Picker("Theme", selection: $preferences.theme) {
                    ForEach(PreferencesStore.Theme.allCases) { Text($0.title).tag($0) }
                }
                LabeledContent("Дизайн", value: "Monochrome Liquid Glass")
                Picker("Backdrop", selection: $preferences.backdropStyle) {
                    ForEach(PreferencesStore.BackdropStyle.allCases) { Text($0.title).tag($0) }
                }
                TextField("Ресурс фона", text: $preferences.backdropResourceName)
                TextField("URL видео фона", text: $preferences.backdropVideoURLString)
                Slider(value: $preferences.backdropOpacity, in: 0.2...1)
                TextField("Фон авторизации", text: $preferences.authBackdropResourceName)
                TextField("Логотип приложения", text: $preferences.brandLogoResourceName)
            }
            Section("РЈРІРµРґРѕРјР»РµРЅРёСЏ") {
                Toggle("Push-СѓРІРµРґРѕРјР»РµРЅРёСЏ", isOn: $preferences.notificationsEnabled)
                Button("Р—Р°РїСЂРѕСЃРёС‚СЊ РґРѕСЃС‚СѓРї Рє СѓРІРµРґРѕРјР»РµРЅРёСЏРј") { Task { await dependencies.push.requestAuthorization() } }
                LabeledContent("РЎС‚Р°С‚СѓСЃ", value: pushStatus)
                if let token = dependencies.push.deviceToken { LabeledContent("APNs token", value: String(token.prefix(12)) + "вЂ¦") }
            }
            Section("РџСЂРёРІР°С‚РЅРѕСЃС‚СЊ") {
                Toggle("РћС‚С‡С‘С‚С‹ Рѕ РїСЂРѕС‡С‚РµРЅРёРё", isOn: $preferences.readReceiptsEnabled)
                Toggle("РЎРєСЂС‹РІР°С‚СЊ С‡СѓРІСЃС‚РІРёС‚РµР»СЊРЅС‹Р№ РєРѕРЅС‚РµРЅС‚", isOn: $preferences.sensitiveContentHidden)
                NavigationLink("Р—Р°Р±Р»РѕРєРёСЂРѕРІР°РЅРЅС‹Рµ Р°РєРєР°СѓРЅС‚С‹") { BlockedAccountsView() }
                NavigationLink("РђРєС‚РёРІРЅС‹Рµ СЃРµСЃСЃРёРё") { ActiveSessionsView() }
            }
            Section("Р”Р°РЅРЅС‹Рµ") {
                Toggle("РђРІС‚РѕРІРѕСЃРїСЂРѕРёР·РІРµРґРµРЅРёРµ РІРёРґРµРѕ", isOn: $preferences.autoplayVideo)
                Toggle("Р—Р°РіСЂСѓР·РєР° С‡РµСЂРµР· СЃРѕС‚РѕРІСѓСЋ СЃРµС‚СЊ", isOn: $preferences.cellularUploadsEnabled)
                LabeledContent("РҐСЂР°РЅРёР»РёС‰Рµ", value: "SwiftData")
            }
            Section("Р Р°Р·СЂР°Р±РѕС‚С‡РёРєР°Рј") {
                Button("API Р±РѕС‚Р° Tide") { dependencies.router.push(.botPlatform) }
                Button("РћС‚РєСЂС‹С‚СЊ СЃР°Р№С‚ Tide") { dependencies.router.push(.browser(URL(string: "https://tide.app")!)) }
                LabeledContent("Режим сервера", value: ServerConfiguration.current.isRemoteEnabled ? "Настроен" : "Не настроен")
            }
            if dependencies.session.currentUser?.isAdministrator == true {
                Section("Tide") { Button("РџР°РЅРµР»СЊ Р°РґРјРёРЅРёСЃС‚СЂР°С‚РѕСЂР°") { dependencies.router.sheet = .adminAccess } }
            }
            Section {
                Button("Р’С‹Р№С‚Рё", role: .destructive) { dependencies.session.signOut(); dependencies.router.reset() }
                Button("РЈРґР°Р»РёС‚СЊ Р°РєРєР°СѓРЅС‚", role: .destructive) { confirmsDeletion = true }
            }
        }
        .navigationTitle(String(localized: "settings_title"))
        .scrollContentBackground(.hidden)
        .confirmationDialog("РЈРґР°Р»РёС‚СЊ СЌС‚РѕС‚ Р»РѕРєР°Р»СЊРЅС‹Р№ Р°РєРєР°СѓРЅС‚?", isPresented: $confirmsDeletion, titleVisibility: .visible) {
            Button("РЈРґР°Р»РёС‚СЊ Р°РєРєР°СѓРЅС‚", role: .destructive) {
                dependencies.session.signOut()
                dependencies.router.reset()
            }
            Button("РћС‚РјРµРЅР°", role: .cancel) {}
        } message: {
            Text("РЈРґР°Р»РµРЅРёРµ РЅР° СЃРµСЂРІРµСЂРµ С‚РѕР¶Рµ РґРѕР»Р¶РЅРѕ Р±С‹С‚СЊ РїРѕРґС‚РІРµСЂР¶РґРµРЅРѕ Р±СЌРєРµРЅРґРѕРј РїСЂРё РІРєР»СЋС‡С‘РЅРЅРѕР№ СЃРёРЅС…СЂРѕРЅРёР·Р°С†РёРё.")
        }
    }

    private var pushStatus: String {
        switch dependencies.push.authorizationStatus {
        case .authorized: "Р Р°Р·СЂРµС€РµРЅРѕ"
        case .denied: "Р—Р°РїСЂРµС‰РµРЅРѕ"
        case .provisional: "Р’СЂРµРјРµРЅРЅРѕ"
        case .ephemeral: "Р’СЂРµРјРµРЅРЅС‹Р№ РґРѕСЃС‚СѓРї"
        case .notDetermined: "РќРµ Р·Р°РїСЂРѕС€РµРЅРѕ"
        @unknown default: "РќРµРёР·РІРµСЃС‚РЅРѕ"
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
                ContentUnavailableView("Р—Р°Р±Р»РѕРєРёСЂРѕРІР°РЅРЅС‹С… Р°РєРєР°СѓРЅС‚РѕРІ РЅРµС‚", systemImage: "person.crop.circle.badge.checkmark")
            }
        }
        .navigationTitle(String(localized: "settings_blocked_accounts"))
    }
}

struct ActiveSessionsView: View {
    @State private var otherSessionCount = 2

    var body: some View {
        List {
            Label("Р­С‚РѕС‚ iPhone", systemImage: "iphone.gen3")
            if otherSessionCount > 0 {
                ForEach(0..<otherSessionCount, id: \.self) { index in
                    Label(index == 0 ? "Mac" : "Р’РµР±-Р±СЂР°СѓР·РµСЂ", systemImage: index == 0 ? "laptopcomputer" : "globe")
                }
            }
            Section("Р‘РµР·РѕРїР°СЃРЅРѕСЃС‚СЊ") {
                Button("Р—Р°РІРµСЂС€РёС‚СЊ РґСЂСѓРіРёРµ СЃРµСЃСЃРёРё", role: .destructive) { otherSessionCount = 0 }
                    .disabled(otherSessionCount == 0)
            }
        }
        .scrollContentBackground(.hidden)
        .navigationTitle(String(localized: "settings_active_sessions"))
    }
}
