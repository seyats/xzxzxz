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
                Section("Причина") {
                    Picker("Причина", selection: $reason) {
                        ForEach(ReportReason.allCases) { Text($0.title).tag($0) }
                    }
                }
                Section("Детали") {
                    TextField("Опишите проблему", text: $details, axis: .vertical)
                        .lineLimit(4...8)
                }
                Section {
                    Label("Жалобы проверяют модераторы Tide, а данные хранятся в зашифрованной базе приложения.", systemImage: "shield.lefthalf.filled")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Жалоба")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Отмена") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Отправить", action: submit) }
            }
            .alert("Жалоба отправлена", isPresented: $submitted) { Button("Готово") { dismiss() } }
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
                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 54))
                Text(dependencies.adminAccess.hasPIN ? "Доступ администратора" : "Создать PIN администратора")
                    .font(TideTypography.title)
                SecureField("4-значный PIN", text: $pin)
                    .keyboardType(.numberPad)
                    .textContentType(.oneTimeCode)
                    .padding()
                    .tideSurface(cornerRadius: 16)
                if !dependencies.adminAccess.hasPIN {
                    SecureField("Повторите PIN", text: $confirmation)
                        .keyboardType(.numberPad)
                        .padding()
                        .tideSurface(cornerRadius: 16)
                }
                if let error = dependencies.adminAccess.errorMessage {
                    Text(error)
                        .foregroundStyle(.red)
                        .font(.footnote)
                }
                Button(dependencies.adminAccess.hasPIN ? "Разблокировать" : "Создать PIN", action: authenticate)
                    .buttonStyle(TidePrimaryButtonStyle())
                    .frame(maxWidth: .infinity)
                    .disabled(pin.count != 4 || (!dependencies.adminAccess.hasPIN && pin != confirmation))
                if dependencies.adminAccess.hasPIN {
                    Button("Использовать Face ID или Touch ID") {
                        Task {
                            if await dependencies.adminAccess.authenticateWithBiometrics() {
                                openAdmin()
                            }
                        }
                    }
                    .buttonStyle(TideSecondaryButtonStyle())
                }
                Spacer()
            }
            .padding(24)
            .navigationTitle("Безопасность")
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Отмена") { dismiss() } } }
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
                    Picker("Раздел", selection: $section) {
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
                .navigationTitle("Администрирование")
                .toolbar { Button("Заблокировать") { dependencies.adminAccess.lock() } }
            } else {
                ContentUnavailableView("Требуется доступ администратора", systemImage: "lock.shield")
                    .toolbar { Button("Разблокировать") { dependencies.router.sheet = .adminAccess } }
            }
        }
    }

    private var dashboard: some View {
        Section("Обзор") {
            let metrics = [
                AdminMetric(title: "Пользователи", value: dependencies.database.users().count, symbol: "person.3.fill"),
                AdminMetric(title: "Посты", value: dependencies.database.posts(includeRemoved: true).count, symbol: "doc.text.fill"),
                AdminMetric(title: "Чаты", value: dependencies.database.chats().count, symbol: "bubble.left.and.bubble.right.fill"),
                AdminMetric(title: "Открытые жалобы", value: dependencies.moderation.openReports.count, symbol: "exclamationmark.shield.fill")
            ]
            ForEach(metrics) { metric in
                HStack {
                    Label(metric.title, systemImage: metric.symbol)
                    Spacer()
                    Text(metric.value.formatted()).font(.title3.bold())
                }
            }
            Chart(weeklyActivity) { value in
                LineMark(x: .value("День", value.day), y: .value("События", value.count)).interpolationMethod(.catmullRom)
                AreaMark(x: .value("День", value.day), y: .value("События", value.count))
                    .foregroundStyle(.linearGradient(colors: [.primary.opacity(0.2), .clear], startPoint: .top, endPoint: .bottom))
            }
            .frame(height: 180)
            .chartLegend(.hidden)
        }
    }

    private var users: some View {
        Section("Пользователи") {
            ForEach(dependencies.database.users()) { user in
                HStack {
                    UserRow(user: user)
                    Menu {
                        Button(user.isVerified ? "Снять верификацию" : "Верифицировать") { toggleVerification(user) }
                        Button("Ограничить") { setStatus(user, .restricted) }
                        Button("Заблокировать", role: .destructive) { setStatus(user, .suspended) }
                    } label: { Image(systemName: "ellipsis.circle") }
                }
            }
        }
    }

    private var content: some View {
        Section("Контент") {
            ForEach(dependencies.database.posts(includeRemoved: true)) { post in
                VStack(alignment: .leading, spacing: 8) {
                    Text(post.body).lineLimit(3)
                    HStack {
                        Text(post.author.handle).font(.caption).foregroundStyle(.secondary)
                        Spacer()
                        Text(post.moderationState.rawValue).font(.caption)
                        Button("Удалить", role: .destructive) {
                            guard let moderatorID = dependencies.session.currentUser?.id else { return }
                            dependencies.social.deletePost(post.id, actorID: moderatorID)
                        }
                    }
                }
            }
        }
    }

    private var reports: some View {
        Section("Жалобы") {
            if dependencies.moderation.openReports.isEmpty {
                ContentUnavailableView("Очередь пуста", systemImage: "checkmark.shield")
            }
            ForEach(dependencies.moderation.openReports) { report in
                NavigationLink(value: AppRoute.moderation(report.id)) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(report.reason.title).fontWeight(.semibold)
                        Text("\(report.targetType) · \(report.createdAt.formatted(.relative(presentation: .named)))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    private var broadcast: some View {
        Section("Глобальное уведомление") { AdminBroadcastView() }
    }

    private var system: some View {
        Section("Система") {
            LabeledContent("WebSocket", value: connectionText)
            LabeledContent("Локальная база", value: dependencies.database.lastError == nil ? "ОК" : "Ошибка")
            LabeledContent("Постоянные модели", value: "14")
            LabeledContent("События аудита", value: dependencies.database.auditEvents().count.formatted())
            LabeledContent("Режим сервера", value: ServerConfiguration.current.isRemoteEnabled ? "Удалённый" : "Локальный")
        }
    }

    private var connectionText: String {
        dependencies.messenger.connectionState == .connected ? "Подключено" : "Нет связи"
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
                Section("Жалоба") {
                    LabeledContent("Причина", value: report.reason.title)
                    LabeledContent("Тип", value: report.targetType)
                    LabeledContent("Статус", value: report.status.rawValue)
                    Text(report.details.isEmpty ? "Дополнительных деталей нет" : report.details)
                }
                Section("Действия") {
                    Button("Отклонить") { resolve(.dismissed) }
                    Button("Закрыть") { resolve(.resolved) }
                    if report.targetType == "post" {
                        Button("Удалить контент", role: .destructive) {
                            guard let moderatorID = dependencies.session.currentUser?.id else { return }
                            dependencies.social.deletePost(report.targetID, actorID: moderatorID)
                            resolve(.resolved)
                        }
                    }
                }
            }
            .navigationTitle("Модерация")
        } else {
            ContentUnavailableView("Жалоба недоступна", systemImage: "exclamationmark.shield")
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
        TextField("Заголовок", text: $title)
        TextField("Сообщение", text: $bodyText, axis: .vertical).lineLimit(3...6)
        Button("Отправить на это устройство") {
            dependencies.notifications.add(kind: .system, title: title, body: bodyText)
            Task { await dependencies.push.scheduleLocal(title: title, body: bodyText) }
            title = ""
            bodyText = ""
            sent = true
        }
        .disabled(title.isEmpty || bodyText.isEmpty)
        if sent { Label("Уведомление поставлено в очередь", systemImage: "checkmark.circle.fill") }
    }
}

enum AdminSection: String, CaseIterable, Identifiable {
    case dashboard, users, content, reports, notifications, system
    var id: String { rawValue }
    var title: String {
        switch self {
        case .dashboard: String(localized: "admin_section_dashboard")
        case .users: String(localized: "admin_section_users")
        case .content: String(localized: "admin_section_content")
        case .reports: String(localized: "admin_section_reports")
        case .notifications: String(localized: "admin_section_notifications")
        case .system: String(localized: "admin_section_system")
        }
    }
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
