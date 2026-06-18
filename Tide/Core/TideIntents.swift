import AppIntents
import Foundation

enum IntentHandoff {
    private static let key = "tide.pending.intent.url"

    static func store(_ url: URL) {
        UserDefaults.standard.set(url.absoluteString, forKey: key)
    }

    static func consume() -> URL? {
        guard let value = UserDefaults.standard.string(forKey: key) else { return nil }
        UserDefaults.standard.removeObject(forKey: key)
        return URL(string: value)
    }
}

struct OpenTideIntent: AppIntent {
    static let title: LocalizedStringResource = "Open Tide"
    static let description = IntentDescription("Open the Tide feed.")
    static let openAppWhenRun = true

    func perform() async throws -> some IntentResult {
        IntentHandoff.store(URL(string: "tide://home")!)
        return .result()
    }
}

struct ComposeTidePostIntent: AppIntent {
    static let title: LocalizedStringResource = "Create Tide Post"
    static let description = IntentDescription("Open Tide directly in the post composer.")
    static let openAppWhenRun = true

    func perform() async throws -> some IntentResult {
        IntentHandoff.store(URL(string: "tide://compose")!)
        return .result()
    }
}

struct OpenTideChatsIntent: AppIntent {
    static let title: LocalizedStringResource = "Open Tide Chats"
    static let description = IntentDescription("Open your Tide conversations.")
    static let openAppWhenRun = true

    func perform() async throws -> some IntentResult {
        IntentHandoff.store(URL(string: "tide://chats")!)
        return .result()
    }
}

struct OpenTideActivityIntent: AppIntent {
    static let title: LocalizedStringResource = "Open Tide Activity"
    static let description = IntentDescription("Open notifications and social activity in Tide.")
    static let openAppWhenRun = true

    func perform() async throws -> some IntentResult {
        IntentHandoff.store(URL(string: "tide://notifications")!)
        return .result()
    }
}

struct TideAppShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: ComposeTidePostIntent(),
            phrases: ["Create a post in \(.applicationName)", "Compose in \(.applicationName)"],
            shortTitle: "Create Post",
            systemImageName: "square.and.pencil"
        )
        AppShortcut(
            intent: OpenTideChatsIntent(),
            phrases: ["Open chats in \(.applicationName)", "Show my \(.applicationName) chats"],
            shortTitle: "Open Chats",
            systemImageName: "bubble.left.and.bubble.right"
        )
        AppShortcut(
            intent: OpenTideActivityIntent(),
            phrases: ["Show \(.applicationName) activity", "Open \(.applicationName) notifications"],
            shortTitle: "Open Activity",
            systemImageName: "bell"
        )
    }
}
