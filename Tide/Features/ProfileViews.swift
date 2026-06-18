import PhotosUI
import SwiftUI
import UserNotifications

struct ProfileView: View {
    @Environment(AppDependencies.self) private var dependencies
    let user: User
    @State private var profile: User
    @State private var section = "Posts"
    private let sections = ["Posts", "Media", "Saved", "Likes"]

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
                        ForEach(sections, id: \.self) { Text($0).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .padding()
                    .background(.bar)
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
                LinearGradient(colors: [TidePalette.ink.opacity(0.32), TidePalette.subtle], startPoint: .topLeading, endPoint: .bottomTrailing)
                    .frame(height: 150)
                    .overlay(Image(systemName: profile.coverSymbol).font(.system(size: 64, weight: .ultraLight)).opacity(0.25))
                AvatarView(user: profile, size: 92)
                    .padding(4)
                    .background(TidePalette.paper, in: Circle())
                    .offset(x: 18, y: 42)
            }
            HStack {
                Spacer()
                if isCurrentUser {
                    Button("Edit Profile") { dependencies.router.sheet = .editProfile }.buttonStyle(TideSecondaryButtonStyle())
                } else {
                    Button("Message", action: startMessage).buttonStyle(TideSecondaryButtonStyle())
                    Button(profile.isFollowing ? "Following" : "Follow", action: toggleFollow).buttonStyle(TidePrimaryButtonStyle())
                }
            }
            .padding(.horizontal)
            VStack(alignment: .leading, spacing: 7) {
                VerifiedName(user: profile).font(.title2)
                Text(profile.handle).foregroundStyle(.secondary)
                if profile.status != .active {
                    Label(profile.status.rawValue.capitalized, systemImage: "exclamationmark.shield.fill").font(.caption).foregroundStyle(.secondary)
                }
                Text(profile.biography)
                Text("Joined \(profile.joinedAt.formatted(.dateTime.month(.wide).year()))")
                    .font(.subheadline).foregroundStyle(.secondary)
                HStack(spacing: 20) {
                    counter(profile.following, "Following")
                    counter(profile.followers, "Followers")
                    counter(authoredPosts.count, "Posts")
                }
                .padding(.top, 4)
            }
            .padding(.horizontal)
            .padding(.bottom, 8)
        }
    }

    private var authoredPosts: [Post] { dependencies.social.posts.filter { $0.author.id == profile.id } }

    private var visiblePosts: [Post] {
        switch section {
        case "Media": authoredPosts.filter { !$0.media.isEmpty }
        case "Saved": isCurrentUser ? dependencies.social.posts.filter(\.isSaved) : []
        case "Likes": isCurrentUser ? dependencies.social.posts.filter(\.isLiked) : []
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
    @State private var biography = ""
    @State private var avatarSymbol = "person.crop.circle.fill"
    @State private var avatarImageURL: URL?
    @State private var avatarItem: PhotosPickerItem?
    private let symbols = ["person.crop.circle.fill", "water.waves", "camera.fill", "paintpalette.fill", "waveform", "sparkles"]

    var body: some View {
        NavigationStack {
            Form {
                Section("Photo") {
                    if let user = dependencies.session.currentUser {
                        HStack { Spacer(); AvatarView(user: updatedPreview(from: user), size: 92); Spacer() }
                    }
                    PhotosPicker(selection: $avatarItem, matching: .images) {
                        Label("Pick avatar from gallery", systemImage: "photo")
                    }
                    Picker("Avatar", selection: $avatarSymbol) {
                        ForEach(symbols, id: \.self) { Image(systemName: $0).tag($0) }
                    }
                    .pickerStyle(.segmented)
                }
                Section("Profile") {
                    TextField("Name", text: $name)
                    TextField("Biography", text: $biography, axis: .vertical).lineLimit(3...6)
                    Text("\(biography.count)/150").font(.caption).foregroundStyle(biography.count > 150 ? .red : .secondary)
                }
            }
            .navigationTitle("Edit Profile")
            .scrollContentBackground(.hidden)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        dependencies.session.updateProfile(name: name, biography: biography, avatarSymbol: avatarSymbol, avatarImageURL: avatarImageURL)
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || biography.count > 150)
                }
            }
            .onAppear {
                name = dependencies.session.currentUser?.name ?? ""
                biography = dependencies.session.currentUser?.biography ?? ""
                avatarSymbol = dependencies.session.currentUser?.avatarSymbol ?? avatarSymbol
                avatarImageURL = dependencies.session.currentUser?.avatarImageURL
            }
            .onChange(of: avatarItem) { _, item in
                guard let item else { return }
                Task {
                    if let imported = try? await MediaLibrary.shared.importItems([item]) {
                        avatarImageURL = imported.first?.url
                    }
                }
            }
        }
    }

    private func updatedPreview(from user: User) -> User {
        var preview = user
        preview.avatarSymbol = avatarSymbol
        preview.avatarImageURL = avatarImageURL
        return preview
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
                    ForEach(PreferencesStore.Theme.allCases) { Text($0.rawValue.capitalized).tag($0) }
                }
                LabeledContent("Design", value: "Monochrome Liquid Glass")
                Picker("Backdrop", selection: $preferences.backdropStyle) {
                    ForEach(PreferencesStore.BackdropStyle.allCases) { Text($0.rawValue.capitalized).tag($0) }
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
        .navigationTitle("Settings")
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
        .navigationTitle("Blocked Accounts")
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
        .navigationTitle("Active Sessions")
    }
}
