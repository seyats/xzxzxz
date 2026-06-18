import SwiftUI

struct NotificationsView: View {
    @Environment(AppDependencies.self) private var dependencies
    @State private var filter: NotificationKind?

    var body: some View {
        List {
            Picker("Filter", selection: $filter) {
                Text("All").tag(NotificationKind?.none)
                Text("Mentions").tag(Optional(NotificationKind.mention))
                Text("Messages").tag(Optional(NotificationKind.message))
                Text("Social").tag(Optional(NotificationKind.like))
            }
            .pickerStyle(.segmented)
            .listRowSeparator(.hidden)
            if filtered.isEmpty {
                ContentUnavailableView("No activity", systemImage: "bell.slash", description: Text("New likes, replies and follows will appear here."))
            }
            ForEach(filtered) { notification in
                Button { open(notification) } label: {
                    HStack(alignment: .top, spacing: 13) {
                        Image(systemName: symbol(for: notification.kind))
                            .font(.title3).frame(width: 42, height: 42)
                            .background(TidePalette.subtle, in: Circle())
                        VStack(alignment: .leading, spacing: 4) {
                            Text(notification.title).fontWeight(notification.isRead ? .regular : .bold)
                            Text(notification.body).font(.subheadline).foregroundStyle(.secondary).lineLimit(2)
                            Text(notification.createdAt.formatted(.relative(presentation: .named))).font(.caption).foregroundStyle(.tertiary)
                        }
                        Spacer()
                        if !notification.isRead { Circle().frame(width: 8, height: 8) }
                    }
                    .padding(.vertical, 4)
                }
                .buttonStyle(.plain)
            }
        }
        .listStyle(.plain)
        .refreshable { dependencies.notifications.reload() }
        .navigationTitle("Activity")
        .toolbar {
            if dependencies.notifications.unreadCount > 0 {
                Button("Read All") { dependencies.notifications.markAllRead() }
            }
        }
    }

    private var filtered: [AppNotification] {
        guard let filter else { return dependencies.notifications.notifications }
        if filter == .like {
            return dependencies.notifications.notifications.filter { [.like, .comment, .follow, .repost].contains($0.kind) }
        }
        return dependencies.notifications.notifications.filter { $0.kind == filter }
    }

    private func open(_ notification: AppNotification) {
        dependencies.notifications.markRead(notification.id)
        guard let id = notification.targetID else { return }
        switch notification.kind {
        case .message: dependencies.router.push(.chat(id), tab: .chats)
        case .follow: if let user = dependencies.database.user(id: id) { dependencies.router.push(.profile(user), tab: .profile) }
        default: dependencies.router.push(.post(id), tab: .home)
        }
    }

    private func symbol(for kind: NotificationKind) -> String {
        switch kind {
        case .message: "bubble.left.fill"
        case .like: "heart.fill"
        case .repost: "arrow.2.squarepath"
        case .comment: "text.bubble.fill"
        case .mention: "at"
        case .follow: "person.badge.plus"
        case .storyReply: "circle.dashed"
        case .live: "dot.radiowaves.left.and.right"
        case .system: "water.waves"
        }
    }
}
