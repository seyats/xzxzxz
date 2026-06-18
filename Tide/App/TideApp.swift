import Combine
import SwiftData
import SwiftUI
import UIKit

@main
@MainActor
struct TideApp: App {
    @UIApplicationDelegateAdaptor(TideAppDelegate.self) private var appDelegate
    @Environment(\.scenePhase) private var scenePhase
    @State private var dependencies: AppDependencies

    init() {
        UITableView.appearance().backgroundColor = .clear
        UICollectionView.appearance().backgroundColor = .clear
        let navigationAppearance = UINavigationBarAppearance()
        navigationAppearance.configureWithTransparentBackground()
        UINavigationBar.appearance().scrollEdgeAppearance = navigationAppearance
        UINavigationBar.appearance().standardAppearance = navigationAppearance
        let database = LocalDatabase()
        _dependencies = State(initialValue: AppDependencies(database: database))
    }

    var body: some Scene {
        WindowGroup {
            ZStack {
                TideBackdropView(configuration: dependencies.preferences.backdropConfiguration())
                AppRootView()
            }
            .environment(dependencies)
            .modelContainer(dependencies.database.container)
            .preferredColorScheme(dependencies.preferences.colorScheme)
            .tint(.primary)
            .task { dependencies.messenger.connect() }
            .task {
                if let url = IntentHandoff.consume() { dependencies.router.handle(url) }
            }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active, let url = IntentHandoff.consume() { dependencies.router.handle(url) }
            }
            .onReceive(NotificationCenter.default.publisher(for: Notification.Name("TideNotificationResponse"))) { notification in
                guard let userInfo = notification.object as? [AnyHashable: Any],
                      let deepLink = userInfo["deepLink"] as? String,
                      let url = URL(string: deepLink) else { return }
                dependencies.router.handle(url)
            }
        }
    }
}
}

@MainActor
@Observable
final class AppDependencies {
    let database: LocalDatabase
    let session: SessionStore
    let social: SocialStore
    let messenger: MessengerStore
    let notifications: NotificationStore
    let moderation: ModerationStore
    let preferences: PreferencesStore
    let push: PushNotificationService
    let adminAccess: AdminAccessStore
    let api: APIClient
    let socket: ChatSocketClient
    let router: AppRouter

    init(database: LocalDatabase) {
        let socket = ChatSocketClient()
        self.database = database
        self.socket = socket
        api = APIClient()
        session = SessionStore(database: database)
        social = SocialStore(database: database)
        messenger = MessengerStore(database: database, socket: socket)
        notifications = NotificationStore(database: database)
        moderation = ModerationStore(database: database)
        preferences = PreferencesStore()
        push = PushNotificationService(database: database)
        adminAccess = AdminAccessStore()
        router = AppRouter(database: database)
    }
}
