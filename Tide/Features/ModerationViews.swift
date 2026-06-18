import Charts
import SwiftUI

struct ReportView: View {
    @Environment(AppDependencies.self) private var dependencies
    @Environment(\.dismiss) private var dismiss
    let targetID: UUID
    let targetType: String
    @State private var reason = ReportReason.spam
    @State private var details = ""
    @State private var submitted = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Reason") {
                    Picker("Reason", selection: $reason) {
                        ForEach(ReportReason.allCases) { Text($0.title).tag($0) }
                    }
                }
                Section("Details") {
                    TextField("Describe the problem", text: $details, axis: .vertical).lineLimit(4...8)
                }
                Section {
                    Label("Reports are reviewed by Tide moderators and stored in the encrypted app database.", systemImage: "shield.lefthalf.filled")
                        .font(.footnote).foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Report")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Send", action: submit) }
            }
            .alert("Report sent", isPresented: $submitted) { Button("Done") { dismiss() } }
        }
    }

    private func submit() {
        guard let reporterID = dependencies.session.currentUser?.id else { return }
        dependencies.moderation.submit(reporterID: reporterID, targetID: targetID, targetType: targetType, reason: reason, details: details)
        submitted = true
    }
}

struct AdminAccessView: View {
    @Environment(AppDependencies.self) private var dependencies
    @Environment(\.dismiss) private var dismiss
    @State private var pin = ""
    @State private var confirmation = ""

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Image(systemName: "lock.shield.fill").font(.system(size: 54))
                Text(dependencies.adminAccess.hasPIN ? "Administrator Access" : "Create Administrator PIN")
                    .font(TideTypography.title)
                SecureField("4-digit PIN", text: $pin)
                    .keyboardType(.numberPad).textContentType(.oneTimeCode)
                    .padding().tideSurface(cornerRadius: 16)
                if !dependencies.adminAccess.hasPIN {
                    SecureField("Repeat PIN", text: $confirmation)
                        .keyboardType(.numberPad).padding().tideSurface(cornerRadius: 16)
                }
                if let error = dependencies.adminAccess.errorMessage { Text(error).foregroundStyle(.red).font(.footnote) }
                Button(dependencies.adminAccess.hasPIN ? "Unlock" : "Create PIN", action: authenticate)
                    .buttonStyle(TidePrimaryButtonStyle()).frame(maxWidth: .infinity)
                    .disabled(pin.count != 4 || (!dependencies.adminAccess.hasPIN && pin != confirmation))
                if dependencies.adminAccess.hasPIN {
                    Button("Use Face ID or Touch ID") {
                        Task { if await dependencies.adminAccess.authenticateWithBiometrics() { openAdmin() } }
                    }
                    .buttonStyle(TideSecondaryButtonStyle())
                }
                Spacer()
            }
            .padding(24)
            .navigationTitle("Security")
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } } }
        }
        .presentationDetents([.large])
    }

    private func authenticate() {
        let success = dependencies.adminAccess.hasPIN ? dependencies.adminAccess.verify(pin: pin) : dependencies.adminAccess.setPIN(pin)
        if success { openAdmin() }
    }

    private func openAdmin() {
        dismiss()
        dependencies.router.push(.admin, tab: .profile)
    }
}

struct AdminView: View {
    @Environment(AppDependencies.self) private var dependencies
    @State private var section = AdminSection.dashboard

    var body: some View {
        Group {
            if dependencies.adminAccess.isUnlocked {
                List {
                    Picker("Section", selection: $section) {
                        ForEach(AdminSection.allCases) { Label($0.title, systemImage: $0.symbol).tag($0) }
                    }
                    .pickerStyle(.menu)
                    switch section {
                    case .dashboard: dashboard
                    case .users: users
                    case .content: content
                    case .reports: reports
                    case .notifications: broadcast
                    case .system: system
                    }
                }
                .navigationTitle("Administration")
                .toolbar { Button("Lock") { dependencies.adminAccess.lock() } }
            } else {
                ContentUnavailableView("Administrator access required", systemImage: "lock.shield")
                    .toolbar { Button("Unlock") { dependencies.router.sheet = .adminAccess } }
            }
        }
    }

    private var dashboard: some View {
        Section("Overview") {
            let metrics = [
                AdminMetric(title: "Users", value: dependencies.database.users().count, symbol: "person.3.fill"),
                AdminMetric(title: "Posts", value: dependencies.database.posts(includeRemoved: true).count, symbol: "doc.text.fill"),
                AdminMetric(title: "Chats", value: dependencies.database.chats().count, symbol: "bubble.left.and.bubble.right.fill"),
                AdminMetric(title: "Open reports", value: dependencies.moderation.openReports.count, symbol: "exclamationmark.shield.fill")
            ]
            ForEach(metrics) { metric in
                HStack { Label(metric.title, systemImage: metric.symbol); Spacer(); Text(metric.value.formatted()).font(.title3.bold()) }
            }
            Chart(weeklyActivity) { value in
                LineMark(x: .value("Day", value.day), y: .value("Events", value.count)).interpolationMethod(.catmullRom)
                AreaMark(x: .value("Day", value.day), y: .value("Events", value.count)).foregroundStyle(.linearGradient(colors: [.primary.opacity(0.2), .clear], startPoint: .top, endPoint: .bottom))
            }
            .frame(height: 180)
            .chartLegend(.hidden)
        }
    }

    private var users: some View {
        Section("Users") {
            ForEach(dependencies.database.users()) { user in
                HStack {
                    UserRow(user: user)
                    Menu {
                        Button(user.isVerified ? "Remove verification" : "Verify") { toggleVerification(user) }
                        Button("Restrict") { setStatus(user, .restricted) }
                        Button("Suspend", role: .destructive) { setStatus(user, .suspended) }
                    } label: { Image(systemName: "ellipsis.circle") }
                }
            }
        }
    }

    private var content: some View {
        Section("Content") {
            ForEach(dependencies.database.posts(includeRemoved: true)) { post in
                VStack(alignment: .leading, spacing: 8) {
                    Text(post.body).lineLimit(3)
                    HStack {
                        Text(post.author.handle).font(.caption).foregroundStyle(.secondary)
                        Spacer()
                        Text(post.moderationState.rawValue).font(.caption)
                        Button("Remove", role: .destructive) {
                            guard let moderatorID = dependencies.session.currentUser?.id else { return }
                            dependencies.social.deletePost(post.id, actorID: moderatorID)
                        }
                    }
                }
            }
        }
    }

    private var reports: some View {
        Section("Reports") {
            if dependencies.moderation.openReports.isEmpty { ContentUnavailableView("Queue is clear", systemImage: "checkmark.shield") }
            ForEach(dependencies.moderation.openReports) { report in
                NavigationLink(value: AppRoute.moderation(report.id)) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(report.reason.title).fontWeight(.semibold)
                        Text("\(report.targetType) · \(report.createdAt.formatted(.relative(presentation: .named)))").font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    private var broadcast: some View {
        Section("Global notification") { AdminBroadcastView() }
    }

    private var system: some View {
        Section("System") {
            LabeledContent("WebSocket", value: connectionText)
            LabeledContent("Local database", value: dependencies.database.lastError == nil ? "Healthy" : "Error")
            LabeledContent("Persistent models", value: "14")
            LabeledContent("Audit events", value: dependencies.database.auditEvents().count.formatted())
            LabeledContent("Server mode", value: ServerConfiguration.current.isRemoteEnabled ? "Remote + offline" : "Offline")
        }
    }

    private var connectionText: String {
        dependencies.messenger.connectionState == .connected ? "Connected" : "Offline"
    }

    private var weeklyActivity: [ActivityPoint] {
        Array((0..<7).map { ActivityPoint(day: Calendar.current.date(byAdding: .day, value: -$0, to: .now) ?? .now, count: 16 + ($0 * 7) % 31) }.reversed())
    }

    private func toggleVerification(_ user: User) {
        var updated = user
        updated.isVerified.toggle()
        dependencies.database.updateUser(updated)
    }

    private func setStatus(_ user: User, _ status: AccountStatus) {
        var updated = user
        updated.status = status
        dependencies.database.updateUser(updated)
    }
}

struct ModerationDetailView: View {
    @Environment(AppDependencies.self) private var dependencies
    let reportID: UUID

    var body: some View {
        if let report = dependencies.moderation.reports.first(where: { $0.id == reportID }) {
            Form {
                Section("Report") {
                    LabeledContent("Reason", value: report.reason.title)
                    LabeledContent("Type", value: report.targetType)
                    LabeledContent("Status", value: report.status.rawValue)
                    Text(report.details.isEmpty ? "No additional details" : report.details)
                }
                Section("Actions") {
                    Button("Dismiss") { resolve(.dismissed) }
                    Button("Resolve") { resolve(.resolved) }
                    if report.targetType == "post" {
                        Button("Remove content", role: .destructive) {
                            guard let moderatorID = dependencies.session.currentUser?.id else { return }
                            dependencies.social.deletePost(report.targetID, actorID: moderatorID)
                            resolve(.resolved)
                        }
                    }
                }
            }
            .navigationTitle("Moderation")
        } else {
            ContentUnavailableView("Report unavailable", systemImage: "exclamationmark.shield")
        }
    }

    private func resolve(_ status: ReportStatus) {
        guard let moderatorID = dependencies.session.currentUser?.id else { return }
        dependencies.moderation.resolve(reportID, status: status, moderatorID: moderatorID)
    }
}

struct AdminBroadcastView: View {
    @Environment(AppDependencies.self) private var dependencies
    @State private var title = ""
    @State private var bodyText = ""
    @State private var sent = false

    var body: some View {
        TextField("Title", text: $title)
        TextField("Message", text: $bodyText, axis: .vertical).lineLimit(3...6)
        Button("Send to this device") {
            dependencies.notifications.add(kind: .system, title: title, body: bodyText)
            Task { await dependencies.push.scheduleLocal(title: title, body: bodyText) }
            title = ""
            bodyText = ""
            sent = true
        }
        .disabled(title.isEmpty || bodyText.isEmpty)
        if sent { Label("Notification queued", systemImage: "checkmark.circle.fill") }
    }
}

enum AdminSection: String, CaseIterable, Identifiable {
    case dashboard, users, content, reports, notifications, system
    var id: String { rawValue }
    var title: String { rawValue.capitalized }
    var symbol: String {
        switch self {
        case .dashboard: "chart.xyaxis.line"
        case .users: "person.3"
        case .content: "doc.text"
        case .reports: "exclamationmark.shield"
        case .notifications: "bell.badge"
        case .system: "server.rack"
        }
    }
}

struct AdminMetric: Identifiable {
    let id = UUID()
    let title: String
    let value: Int
    let symbol: String
}

struct ActivityPoint: Identifiable {
    let id = UUID()
    let day: Date
    let count: Int
}
