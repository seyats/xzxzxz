import AuthenticationServices
import SwiftUI
import UIKit

struct AppRootView: View {
    @Environment(AppDependencies.self) private var dependencies

    var body: some View {
        ZStack {
            if dependencies.session.isAuthenticated, dependencies.session.needsProfileSetup {
                AuthProfileSetupView()
                    .transition(.opacity.combined(with: .scale(scale: 0.98)))
            } else if dependencies.session.isAuthenticated {
                MainTabView()
                    .transition(.opacity.combined(with: .scale(scale: 1.02)))
            } else {
                PremiumAuthenticationView()
                    .transition(.opacity.combined(with: .scale(scale: 0.98)))
            }
        }
        .animation(.easeInOut(duration: 0.62), value: dependencies.session.isAuthenticated)
        .animation(.easeInOut(duration: 0.62), value: dependencies.session.needsProfileSetup)
        .onChange(of: dependencies.session.currentUser?.id) { _, _ in
            dependencies.handleSessionUserChanged(dependencies.session.currentUser)
        }
    }
}

struct MainTabView: View {
    @Environment(AppDependencies.self) private var dependencies

    init() {
        let appearance = UITabBarAppearance()
        appearance.configureWithTransparentBackground()
        appearance.backgroundEffect = UIBlurEffect(style: .systemChromeMaterial)
        appearance.stackedLayoutAppearance.normal.titleTextAttributes = [.font: UIFont.systemFont(ofSize: 10, weight: .semibold)]
        appearance.stackedLayoutAppearance.selected.titleTextAttributes = [.font: UIFont.systemFont(ofSize: 10, weight: .semibold)]
        appearance.inlineLayoutAppearance.normal.titleTextAttributes = [.font: UIFont.systemFont(ofSize: 10, weight: .semibold)]
        appearance.inlineLayoutAppearance.selected.titleTextAttributes = [.font: UIFont.systemFont(ofSize: 10, weight: .semibold)]
        UITabBar.appearance().itemPositioning = .automatic
        UITabBar.appearance().itemWidth = 72
        UITabBar.appearance().itemSpacing = 10
        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }

    var body: some View {
        @Bindable var router = dependencies.router
        TabView(selection: $router.selectedTab) {
            ForEach(AppTab.allCases) { tab in
                NavigationStack(path: router.path(for: tab)) {
                    tabRoot(tab)
                        .navigationDestination(for: AppRoute.self, destination: destination)
                }
                .tabItem { Label(tab.title, systemImage: tab.symbol) }
                .tag(tab)
            }
        }
        .animation(.easeInOut(duration: 0.42), value: router.selectedTab)
        .sheet(item: $router.sheet, content: sheet)
        .onOpenURL { router.handle($0) }
    }

    @ViewBuilder
    private func tabRoot(_ tab: AppTab) -> some View {
        switch tab {
        case .home:
            FeedView()
        case .chats:
            ChatListView()
        case .notifications:
            NotificationsView()
        case .profile:
            if let user = dependencies.session.currentUser {
                ProfileView(user: user)
            } else {
                EmptyStateView(
                    symbol: "person.crop.circle",
                    title: "Профиль не выбран",
                    message: "Войдите в аккаунт, чтобы продолжить."
                )
            }
        }
    }

    @ViewBuilder
    private func destination(_ route: AppRoute) -> some View {
        switch route {
        case .post(let id): PostDetailView(postID: id)
        case .profile(let user): ProfileView(user: user)
        case .chat(let id): ConversationView(chatID: id)
        case .settings: SettingsView()
        case .appearance: AppearanceView()
        case .storage: StorageView()
        case .dataManagement: DataManagementView()
        case .storageFiles: StorageFilesView()
        case .stories(let id): StoryViewer(storyID: id)
        case .live: LiveHubView()
        case .browser(let url): BrowserView(url: url)
        case .admin: AdminView()
        case .notifications: NotificationsView()
        case .moderation(let id): ModerationDetailView(reportID: id)
        case .call(let chatID, let video): CallView(chatID: chatID, isVideo: video)
        case .botPlatform: BotPlatformView()
        }
    }

    @ViewBuilder
    private func sheet(_ sheet: AppSheet) -> some View {
        switch sheet {
        case .composer: ComposerView()
        case .newMessage: NewMessageView()
        case .editProfile: EditProfileView()
        case .share(let url): ShareView(url: url)
        case .report(let targetID, let targetType): ReportView(targetID: targetID, targetType: targetType)
        case .createStory: StoryComposerView()
        case .adminAccess: AdminAccessView()
        }
    }
}

struct AuthenticationView: View {
    @Environment(AppDependencies.self) private var dependencies
    @State private var alertMessage: String?

    var body: some View {
        LoginView()
            .alert("Проблема входа", isPresented: Binding(get: { alertMessage != nil }, set: { if !$0 { alertMessage = nil } })) {
                Button("ОК", role: .cancel) {}
            } message: {
                Text(alertMessage ?? "")
            }
    }

    private func handleAppleSignIn(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let authorization):
            guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else {
                alertMessage = "Не удалось получить данные Apple."
                return
            }
            let name = [credential.fullName?.givenName, credential.fullName?.familyName].compactMap { $0 }.joined(separator: " ")
            Task {
                await dependencies.session.signInApple(
                    userIdentifier: credential.user,
                    email: credential.email,
                    displayName: name.isEmpty ? nil : name
                )
                let message = dependencies.session.errorMessage
                await MainActor.run {
                    alertMessage = message
                }
            }
        case .failure(let error):
            alertMessage = error.localizedDescription
        }
    }
}
