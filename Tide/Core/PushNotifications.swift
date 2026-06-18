import Foundation
import Observation
import UIKit
import UserNotifications

extension Notification.Name {
    static let tideDeviceTokenReceived = Notification.Name("TideDeviceTokenReceived")
    static let tidePushRegistrationFailed = Notification.Name("TidePushRegistrationFailed")
}

final class TideAppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        let token = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
        NotificationCenter.default.post(name: .tideDeviceTokenReceived, object: token)
    }

    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        NotificationCenter.default.post(name: .tidePushRegistrationFailed, object: error.localizedDescription)
    }

    func application(
        _ application: UIApplication,
        didReceiveRemoteNotification userInfo: [AnyHashable: Any],
        fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
    ) {
        completionHandler(.newData)
    }
}

@MainActor
@Observable
final class PushNotificationService {
    private let database: LocalDatabase
    private let delegateProxy = NotificationDelegateProxy()
    private var observers: [NSObjectProtocol] = []
    private(set) var authorizationStatus: UNAuthorizationStatus = .notDetermined
    private(set) var deviceToken: String?
    private(set) var lastError: String?

    init(database: LocalDatabase) {
        self.database = database
        delegateProxy.onResponse = { response in
            NotificationCenter.default.post(name: Notification.Name("TideNotificationResponse"), object: response.notification.request.content.userInfo)
        }
        UNUserNotificationCenter.current().delegate = delegateProxy
        observers.append(NotificationCenter.default.addObserver(forName: .tideDeviceTokenReceived, object: nil, queue: .main) { [weak self] notification in
            guard let token = notification.object as? String else { return }
            Task { @MainActor in
                self?.deviceToken = token
                self?.database.saveDeviceToken(token, environment: Self.environmentName)
            }
        })
        observers.append(NotificationCenter.default.addObserver(forName: .tidePushRegistrationFailed, object: nil, queue: .main) { [weak self] notification in
            Task { @MainActor in self?.lastError = notification.object as? String }
        })
        Task { await refreshAuthorizationStatus() }
    }

    func requestAuthorization() async {
        do {
            let granted = try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound, .provisional])
            await refreshAuthorizationStatus()
            if granted { UIApplication.shared.registerForRemoteNotifications() }
        } catch {
            lastError = error.localizedDescription
        }
    }

    func refreshAuthorizationStatus() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        authorizationStatus = settings.authorizationStatus
    }

    func scheduleLocal(title: String, body: String, deepLink: URL? = nil, after seconds: TimeInterval = 1) async {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        if let deepLink { content.userInfo["deepLink"] = deepLink.absoluteString }
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(1, seconds), repeats: false)
        do {
            try await UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger))
        } catch {
            lastError = error.localizedDescription
        }
    }

    func clearBadge() async {
        try? await UNUserNotificationCenter.current().setBadgeCount(0)
    }

    private static var environmentName: String {
        #if DEBUG
        "sandbox"
        #else
        "production"
        #endif
    }
}

private final class NotificationDelegateProxy: NSObject, UNUserNotificationCenterDelegate {
    var onResponse: ((UNNotificationResponse) -> Void)?

    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        [.banner, .list, .sound, .badge]
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse) async {
        onResponse?(response)
    }
}
