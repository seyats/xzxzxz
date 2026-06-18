import AuthenticationServices
import SwiftUI
import UIKit

struct AppRootView: View {
    @Environment(AppDependencies.self) private var dependencies

    var body: some View {
        if dependencies.session.isAuthenticated {
            MainTabView()
        } else {
            AuthenticationView()
        }
    }
}

struct MainTabView: View {
    @Environment(AppDependencies.self) private var dependencies

    init() {
        let appearance = UITabBarAppearance()
        appearance.configureWithTransparentBackground()
        appearance.backgroundEffect = UIBlurEffect(style: .systemChromeMaterial)
        appearance.stackedLayoutAppearance.normal.titleTextAttributes = [
            .font: UIFont.systemFont(ofSize: 10, weight: .semibold)
        ]
        appearance.stackedLayoutAppearance.selected.titleTextAttributes = [
            .font: UIFont.systemFont(ofSize: 10, weight: .semibold)
        ]
        appearance.inlineLayoutAppearance.normal.titleTextAttributes = [
            .font: UIFont.systemFont(ofSize: 10, weight: .semibold)
        ]
        appearance.inlineLayoutAppearance.selected.titleTextAttributes = [
            .font: UIFont.systemFont(ofSize: 10, weight: .semibold)
        ]
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
        .sheet(item: $router.sheet, content: sheet)
        .onOpenURL { router.handle($0) }
    }

    @ViewBuilder
    private func tabRoot(_ tab: AppTab) -> some View {
        switch tab {
        case .home: FeedView()
        case .chats: ChatListView()
        case .notifications: NotificationsView()
        case .profile:
            if let user = dependencies.session.currentUser {
                ProfileView(user: user)
            } else {
                EmptyStateView(symbol: "person.crop.circle", title: "profile_empty_title", message: "profile_empty_message")
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
    @Environment(\.openURL) private var openURL
    @FocusState private var focusedField: Field?
    @State private var email = ""
    @State private var password = ""
    @State private var displayName = ""
    @State private var isRegistering = true
    @State private var isLoading = false
    @State private var alertMessage: String?
    @State private var showGoogleInfo = false

    private enum Field {
        case name
        case email
        case password
    }

    var body: some View {
        ZStack {
            TideBackdropView(configuration: dependencies.preferences.backdropConfiguration(isAuthentication: true))
            LinearGradient(colors: [.black.opacity(0.88), .black.opacity(0.55), .clear], startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
            VStack(spacing: 24) {
                Spacer()
                authCard
                Spacer()
                Text(String(localized: "auth_footer"))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 16)
        }
        .alert("auth_error_title", isPresented: Binding(
            get: { alertMessage != nil },
            set: { if !$0 { alertMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(alertMessage ?? "")
        }
        .alert("auth_google_title", isPresented: $showGoogleInfo) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("auth_google_message")
        }
    }

    private var authCard: some View {
        VStack(spacing: 18) {
            HStack {
                VStack(alignment: .leading, spacing: 6) {
                    Text(String(localized: "auth_title"))
                        .font(.system(size: 42, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                    Text(String(localized: "auth_subtitle"))
                        .font(.callout.weight(.medium))
                        .foregroundStyle(.white.opacity(0.72))
                }
                Spacer()
                appLogo
            }

            HStack(spacing: 12) {
                authProviderButton(title: "auth_google", systemImage: "g.circle.fill", tint: .white)
                SignInWithAppleButton(.signIn, onRequest: { request in
                    request.requestedScopes = [.fullName, .email]
                }, onCompletion: { result in
                    handleApple(result: result)
                })
                .signInWithAppleButtonStyle(.whiteOutline)
                .frame(maxWidth: .infinity)
                .frame(height: 48)
            }

            Divider().overlay(.white.opacity(0.18))

            VStack(spacing: 12) {
                if isRegistering {
                    authField(title: "auth_display_name", text: $displayName, field: .name, autocapitalization: .words, contentType: .name)
                }
                authField(title: "auth_email", text: $email, field: .email, keyboard: .emailAddress, contentType: .username)
                SecureField(String(localized: "auth_password"), text: $password)
                    .textContentType(isRegistering ? .newPassword : .password)
                    .focused($focusedField, equals: .password)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 14)
                    .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(.white.opacity(0.10), lineWidth: 0.8))
                    .foregroundStyle(.white)
            }

            Button(action: submitEmail) {
                Text(isRegistering ? String(localized: "auth_create_account") : String(localized: "auth_continue_email"))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(TidePrimaryButtonStyle())
            .disabled(isLoading)

            Button {
                isRegistering.toggle()
            } label: {
                Text(isRegistering ? String(localized: "auth_switch_to_signin") : String(localized: "auth_switch_to_create"))
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.85))
            }
            .padding(.top, 2)
        }
        .padding(20)
        .background(.black.opacity(0.42), in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(.white.opacity(0.12), lineWidth: 0.7)
        }
        .shadow(color: .black.opacity(0.35), radius: 26, y: 12)
    }

    private var appLogo: some View {
        Group {
            if let logo = UIImage(named: dependencies.preferences.brandLogoResourceName) {
                Image(uiImage: logo)
                    .resizable()
                    .scaledToFit()
            } else {
                Image(systemName: "water.waves")
                    .font(.system(size: 46, weight: .thin))
                    .foregroundStyle(.white)
            }
        }
        .frame(width: 72, height: 72)
        .padding(12)
        .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(.white.opacity(0.14), lineWidth: 0.8))
        .shadow(color: .black.opacity(0.4), radius: 18, y: 8)
    }

    private func authProviderButton(title: String, systemImage: String, tint: Color) -> some View {
        Button {
            startGoogleSignIn()
        } label: {
            HStack(spacing: 10) {
                Image(systemName: systemImage)
                    .font(.system(size: 15, weight: .semibold))
                Text(LocalizedStringKey(title))
                    .font(.subheadline.weight(.semibold))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 13)
            .foregroundStyle(.white)
            .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(.white.opacity(0.12), lineWidth: 0.8))
        }
        .tint(tint)
    }

    private func authField(title: String, text: Binding<String>, field: Field, autocapitalization: TextInputAutocapitalization = .never, keyboard: UIKeyboardType = .default, contentType: UITextContentType? = nil) -> some View {
        TextField(LocalizedStringKey(title), text: text)
            .textInputAutocapitalization(autocapitalization)
            .keyboardType(keyboard)
            .textContentType(contentType)
            .focused($focusedField, equals: field)
            .padding(.horizontal, 14)
            .padding(.vertical, 14)
            .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(.white.opacity(0.10), lineWidth: 0.8))
            .foregroundStyle(.white)
    }

    private func submitEmail() {
        isLoading = true
        Task {
            await dependencies.session.signInEmail(email: email, password: password, displayName: displayName)
            isLoading = false
            alertMessage = dependencies.session.errorMessage
        }
    }

    private func handleApple(result: Result<ASAuthorization, Error>) {
        isLoading = true
        Task {
            defer { isLoading = false }
            switch result {
            case .success(let authorization):
                guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else {
                    alertMessage = String(localized: "auth_error_apple")
                    return
                }
                let fullName = [credential.fullName?.givenName, credential.fullName?.familyName]
                    .compactMap { $0 }
                    .joined(separator: " ")
                await dependencies.session.signInApple(
                    userIdentifier: credential.user,
                    email: credential.email,
                    displayName: fullName.isEmpty ? nil : fullName
                )
                alertMessage = dependencies.session.errorMessage
            case .failure(let error):
                alertMessage = error.localizedDescription
            }
        }
    }

    private func startGoogleSignIn() {
        if let baseURL = ServerConfiguration.current.apiBaseURL {
            let url = baseURL.appendingPathComponent("auth/google/start")
            openURL(url)
        } else {
            showGoogleInfo = true
        }
    }

    private func authButton(_ title: String, symbol: String) -> some View {
        Button {
            isLoading = true
            Task {
                await dependencies.session.signInEmail(email: email, password: password, displayName: displayName)
                isLoading = false
            }
        } label: {
            HStack {
                Image(systemName: symbol).frame(width: 24)
                Text(title).fontWeight(.semibold)
                Spacer()
                if isLoading { ProgressView() }
            }
            .padding()
            .frame(maxWidth: .infinity)
            .background(.primary, in: RoundedRectangle(cornerRadius: 14))
            .foregroundStyle(Color(uiColor: .systemBackground))
        }
        .disabled(isLoading)
    }
}
