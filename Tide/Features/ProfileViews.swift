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
        ZStack {
            SettingsScreenBackground().ignoresSafeArea()
            ScrollView {
                LazyVStack(spacing: 14, pinnedViews: .sectionHeaders) {
                    profileHeader
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                        .padding(.bottom, 6)
                        .background(AuthGlassBackground(cornerRadius: 30, interactive: false))
                        .overlay {
                            RoundedRectangle(cornerRadius: 30, style: .continuous)
                                .stroke(.white.opacity(0.06), lineWidth: 0.8)
                        }
                        .padding(.horizontal, 16)

                    Section {
                        if visiblePosts.isEmpty {
                            ContentUnavailableView("������ ���", systemImage: "rectangle.stack", description: Text("�������������� ����� ����� ������������ �����."))
                                .padding(.top, 38)
                        }
                        ForEach(visiblePosts) { post in
                            PostCard(post: post)
                            Divider().padding(.leading, 68)
                        }
                    } header: {
                        Picker("������ �������", selection: $section) {
                            ForEach(sections, id: \.self) { Text($0.title).tag($0) }
                        }
                        .pickerStyle(.segmented)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(AuthGlassBackground(cornerRadius: 22, interactive: false))
                        .padding(.horizontal, 16)
                    }
                }
                .padding(.bottom, 20)
            }
        }
        .navigationTitle(profile.handle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if !isCurrentUser {
                Menu {
                    Button(profile.isBlocked ? "��������������" : "�������������", role: .destructive, action: toggleBlock)
                    Button("������������", role: .destructive) { dependencies.router.sheet = .report(profile.id, "user") }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .onAppear { profile = dependencies.database.user(id: user.id) ?? user }
    }

    private var profileHeader: some View {
        VStack(alignment: .leading, spacing: 14) {
            ZStack(alignment: .bottomLeading) {
                coverView
                    .frame(height: 184)
                    .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
                AvatarView(user: profile, size: 92)
                    .padding(4)
                    .background(.white.opacity(0.06), in: Circle())
                    .overlay {
                        Circle().stroke(.white.opacity(0.10), lineWidth: 0.7)
                    }
                    .offset(x: 18, y: 42)
            }
            .padding(.bottom, 22)

            VStack(alignment: .leading, spacing: 6) {
                VerifiedName(user: profile)
                    .font(.title2.weight(.semibold))
                Text(profile.handle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                if profile.isVerified {
                    HStack(spacing: 6) {
                        Image("TideAuthLogo")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 14, height: 14)
                            .clipShape(Circle())
                        Text("������� �������������")
                    }
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                }
                if !profile.biography.isEmpty {
                    Text(profile.biography)
                        .font(.subheadline)
                        .foregroundStyle(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                HStack(spacing: 8) {
                    if let location = profile.location, !location.isEmpty {
                        profileMetaChip(symbol: "mappin.and.ellipse", text: location)
                    }
                    if let website = profile.website, !website.isEmpty {
                        profileMetaChip(symbol: "link", text: website)
                    }
                    profileMetaChip(symbol: "calendar", text: "� ���� � \(profile.joinedAt.formatted(.dateTime.month(.wide).year()))")
                }
            }
            .padding(.horizontal, 18)

            if !isCurrentUser {
                HStack(spacing: 10) {
                    Button("���������", action: startMessage)
                        .buttonStyle(.plain)
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .background(.ultraThinMaterial, in: Capsule())
                        .overlay(Capsule().stroke(.white.opacity(0.10), lineWidth: 0.8))
                    Button(profile.isFollowing ? "�� ���������" : "�����������", action: toggleFollow)
                        .buttonStyle(.plain)
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .background(profile.isFollowing ? .white.opacity(0.10) : Color.primary.opacity(0.22), in: Capsule())
                        .overlay(Capsule().stroke(.white.opacity(0.10), lineWidth: 0.8))
                }
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 18)
            }

            HStack(spacing: 10) {
                profileStatChip(value: profile.following, title: "��������")
                profileStatChip(value: profile.followers, title: "����������")
                profileStatChip(value: authoredPosts.count, title: "�����")
            }
            .padding(.horizontal, 18)
        }
        .padding(.vertical, 4)
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
                    colors: [
                        Color(red: 0.03, green: 0.03, blue: 0.05),
                        Color(red: 0.12, green: 0.16, blue: 0.20)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
        }
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

    private func profileMetaChip(symbol: String, text: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: symbol)
                .font(.system(size: 12, weight: .semibold))
            Text(text)
                .font(.system(size: 13, weight: .medium))
                .lineLimit(1)
        }
        .foregroundStyle(.secondary)
        .padding(.horizontal, 10)
        .frame(height: 30)
        .background(.white.opacity(0.06), in: Capsule())
    }

    private func profileStatChip(value: Int, title: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value.formatted(.number.notation(.compactName)))
                .font(.system(size: 16, weight: .bold))
            Text(title)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(.white.opacity(0.08), lineWidth: 0.6)
        }
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
        case .posts: "�����"
        case .media: "�����"
        case .saved: "����������"
        case .likes: "�����"
        }
    }
}
