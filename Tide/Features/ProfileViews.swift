import PhotosUI
import SwiftUI
import UserNotifications
import UIKit

struct ProfileView: View {
    @Environment(AppDependencies.self) private var dependencies
    let user: User
    @State private var profile: User
    @State private var section = "profile_tab_posts"
    private let sections = ["profile_tab_posts", "profile_tab_media", "profile_tab_saved", "profile_tab_likes"]

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
                        ContentUnavailableView("No posts", systemImage: "rectangle.stack", description: Text("Published posts will appear here."))
                            .padding(.top, 38)
                    }
                    ForEach(visiblePosts) { post in
                        PostCard(post: post)
                        Divider().padding(.leading, 68)
                    }
                } header: {
                    Picker("Profile section", selection: $section) {
                        ForEach(sections, id: \.self) { Text(LocalizedStringKey($0)).tag($0) }
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
                    Button(profile.isBlocked ? "Unblock" : "Block", role: .destructive, action: toggleBlock)
                    Button("Report", role: .destructive) { dependencies.router.sheet = .report(profile.id, "user") }
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
        case "profile_tab_media": authoredPosts.filter { !$0.media.isEmpty }
        case "profile_tab_saved": isCurrentUser ? dependencies.social.posts.filter(\.isSaved) : []
        case "profile_tab_likes": isCurrentUser ? dependencies.social.posts.filter(\.isLiked) : []
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

struct EditProfileView: View {
    @Environment(AppDependencies.self) private var dependencies
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var username = ""
    @State private var biography = ""
    @State private var avatarSymbol = "person.crop.circle.fill"
    @State private var avatarImageURL: URL?
    @State private var coverImageURL: URL?
    @State private var avatarItem: PhotosPickerItem?
    @State private var coverItem: PhotosPickerItem?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    coverPicker
                    avatarPicker
                    VStack(alignment: .leading, spacing: 12) {
                        TextField(String(localized: "profile_name"), text: $name)
                            .textFieldStyle(.roundedBorder)
                        TextField(String(localized: "profile_username"), text: $username)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .textFieldStyle(.roundedBorder)
                        TextField(String(localized: "profile_bio"), text: $biography, axis: .vertical)
                            .lineLimit(3...6)
                            .textFieldStyle(.roundedBorder)
                    }
                    .padding()
                    .background(TidePalette.elevated, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                }
                .padding()
            }
            .navigationTitle(String(localized: "profile_edit_title"))
            .scrollContentBackground(.hidden)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button(String(localized: "action_cancel")) { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "action_save")) {
                        dependencies.session.updateProfile(name: name, username: username, biography: biography, avatarSymbol: avatarSymbol, avatarImageURL: avatarImageURL, coverImageURL: coverImageURL)
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || username.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || biography.count > 150)
                }
            }
            .onAppear {
                name = dependencies.session.currentUser?.name ?? ""
                username = dependencies.session.currentUser?.username ?? ""
                biography = dependencies.session.currentUser?.biography ?? ""
                avatarSymbol = dependencies.session.currentUser?.avatarSymbol ?? avatarSymbol
                avatarImageURL = dependencies.session.currentUser?.avatarImageURL
                coverImageURL = dependencies.session.currentUser?.coverImageURL
            }
            .onChange(of: avatarItem) { item in
                guard let item else { return }
                Task {
                    if let imported = try? await MediaLibrary.shared.importItems([item]) {
                        avatarImageURL = imported.first?.url
                    }
                }
            }
            .onChange(of: coverItem) { item in
                guard let item else { return }
                Task {
                    if let imported = try? await MediaLibrary.shared.importItems([item]) {
                        coverImageURL = imported.first?.url
                    }
                }
            }
        }
    }

    private var coverPicker: some View {
        PhotosPicker(selection: $coverItem, matching: .images) {
            ZStack(alignment: .bottomLeading) {
                Group {
                    if let coverImageURL, let image = UIImage(contentsOfFile: coverImageURL.path) {
                        Image(uiImage: image).resizable().scaledToFill()
                    } else {
                        LinearGradient(colors: [TidePalette.ink.opacity(0.32), TidePalette.subtle], startPoint: .topLeading, endPoint: .bottomTrailing)
                    }
                }
                .frame(height: 170)
                .clipped()
                .overlay(alignment: .bottomLeading) {
                    Text("cover_tap_to_change")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.86))
                        .padding(12)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private var avatarPicker: some View {
        PhotosPicker(selection: $avatarItem, matching: .images) {
            VStack(spacing: 12) {
                AvatarView(user: previewUser, size: 96)
                    .overlay(Circle().stroke(.white.opacity(0.25), lineWidth: 1))
                Text("avatar_tap_to_change")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
        }
        .buttonStyle(.plain)
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
            Section("Appearance") {
                Picker("Theme", selection: $preferences.theme) {
                    ForEach(PreferencesStore.Theme.allCases) { Text($0.title).tag($0) }
                }
                LabeledContent("Design", value: "Monochrome Liquid Glass")
                Picker("Backdrop", selection: $preferences.backdropStyle) {
                    ForEach(PreferencesStore.BackdropStyle.allCases) { Text($0.title).tag($0) }
                }
                TextField("Backdrop resource", text: $preferences.backdropResourceName)
                TextField("Backdrop video URL", text: $preferences.backdropVideoURLString)
                Slider(value: $preferences.backdropOpacity, in: 0.2...1)
                TextField("Auth background resource", text: $preferences.authBackdropResourceName)
                TextField("App logo resource", text: $preferences.brandLogoResourceName)
            }
            Section("Notifications") {
                Toggle("Push Notifications", isOn: $preferences.notificationsEnabled)
                Button("Request notification access") { Task { await dependencies.push.requestAuthorization() } }
                LabeledContent("Authorization", value: pushStatus)
                if let token = dependencies.push.deviceToken { LabeledContent("APNs token", value: String(token.prefix(12)) + "…") }
            }
            Section("Privacy") {
                Toggle("Read Receipts", isOn: $preferences.readReceiptsEnabled)
                Toggle("Hide Sensitive Content", isOn: $preferences.sensitiveContentHidden)
                NavigationLink("Blocked Accounts") { BlockedAccountsView() }
                NavigationLink("Active Sessions") { ActiveSessionsView() }
            }
            Section("Data") {
                Toggle("Autoplay Video", isOn: $preferences.autoplayVideo)
                Toggle("Upload over Cellular", isOn: $preferences.cellularUploadsEnabled)
                LabeledContent("Storage", value: "SwiftData")
            }
            Section("Developers") {
                Button("Tide Bot API") { dependencies.router.push(.botPlatform) }
                Button("Open Tide website") { dependencies.router.push(.browser(URL(string: "https://tide.app")!)) }
                LabeledContent("Backend", value: ServerConfiguration.current.isRemoteEnabled ? "Configured" : "Offline mode")
            }
            if dependencies.session.currentUser?.isAdministrator == true {
                Section("Tide") { Button("Admin Panel") { dependencies.router.sheet = .adminAccess } }
            }
            Section {
                Button("Log Out", role: .destructive) { dependencies.session.signOut(); dependencies.router.reset() }
                Button("Delete Account", role: .destructive) { confirmsDeletion = true }
            }
        }
        .navigationTitle(String(localized: "settings_title"))
        .scrollContentBackground(.hidden)
        .confirmationDialog("Delete this local account?", isPresented: $confirmsDeletion, titleVisibility: .visible) {
            Button("Delete Account", role: .destructive) {
                dependencies.session.signOut()
                dependencies.router.reset()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Server-side deletion must also be confirmed by your backend when remote sync is enabled.")
        }
    }

    private var pushStatus: String {
        switch dependencies.push.authorizationStatus {
        case .authorized: "Authorized"
        case .denied: "Denied"
        case .provisional: "Provisional"
        case .ephemeral: "Ephemeral"
        case .notDetermined: "Not requested"
        @unknown default: "Unknown"
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
                ContentUnavailableView("No blocked accounts", systemImage: "person.crop.circle.badge.checkmark")
            }
        }
        .navigationTitle(String(localized: "settings_blocked_accounts"))
    }
}

struct ActiveSessionsView: View {
    @State private var otherSessionCount = 2

    var body: some View {
        List {
            Label("This iPhone", systemImage: "iphone.gen3")
            if otherSessionCount > 0 {
                ForEach(0..<otherSessionCount, id: \.self) { index in
                    Label(index == 0 ? "Mac" : "Web Browser", systemImage: index == 0 ? "laptopcomputer" : "globe")
                }
            }
            Section("Security") {
                Button("Terminate Other Sessions", role: .destructive) { otherSessionCount = 0 }
                    .disabled(otherSessionCount == 0)
            }
        }
        .scrollContentBackground(.hidden)
        .navigationTitle(String(localized: "settings_active_sessions"))
    }
}
