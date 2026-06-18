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
                .tabItem { Label(tab.shortTitle, systemImage: tab.symbol) }
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
            LinearGradient(colors: [.black.opacity(0.72), .black.opacity(0.30), .clear], startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
            VStack(spacing: 28) {
                Spacer()
                if let logo = UIImage(named: dependencies.preferences.brandLogoResourceName) {
                    Image(uiImage: logo)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 120, height: 120)
                        .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
                        .shadow(color: .black.opacity(0.4), radius: 24, y: 10)
                } else {
                    Image(systemName: "water.waves")
                        .font(.system(size: 88, weight: .thin))
                        .frame(width: 120, height: 120)
                        .background(.black.opacity(0.25), in: RoundedRectangle(cornerRadius: 30, style: .continuous))
                }
                VStack(spacing: 8) {
                    Text("Tide").font(.system(size: 48, weight: .black, design: .rounded))
                    Text("auth_subtitle")
                        .foregroundStyle(.secondary)
                }
                VStack(spacing: 14) {
                    if isRegistering {
                        TextField("auth_display_name", text: $displayName)
                            .textInputAutocapitalization(.words)
                            .focused($focusedField, equals: .name)
                            .textFieldStyle(.roundedBorder)
                    }
                    TextField("auth_email", text: $email)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.emailAddress)
                        .textContentType(.username)
                        .focused($focusedField, equals: .email)
                        .textFieldStyle(.roundedBorder)
                    SecureField("auth_password", text: $password)
                        .textContentType(isRegistering ? .newPassword : .password)
                        .focused($focusedField, equals: .password)
                        .textFieldStyle(.roundedBorder)
                    Button(action: submitEmail) {
                        Text(isRegistering ? String(localized: "auth_create_account") : String(localized: "auth_continue_email"))
                    }
                    .buttonStyle(TidePrimaryButtonStyle())
                    .disabled(isLoading)
                    SignInWithAppleButton(.signIn, onRequest: { request in
                        request.requestedScopes = [.fullName, .email]
                    }, onCompletion: { result in
                        handleApple(result: result)
                    })
                    .signInWithAppleButtonStyle(.white)
                    .frame(height: 52)
                    Button("auth_google") { startGoogleSignIn() }
                        .buttonStyle(TideSecondaryButtonStyle())
                }
                .padding(20)
                .background(.black.opacity(0.32), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(.white.opacity(0.12), lineWidth: 0.6)
                }
                .overlay(alignment: .topTrailing) {
                    Button {
                        isRegistering.toggle()
                    } label: {
                        Text(isRegistering ? String(localized: "auth_switch_to_signin") : String(localized: "auth_switch_to_create"))
                    }
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.85))
                    .padding(.trailing, 16)
                    .padding(.top, 10)
                }
                Spacer()
                Text("auth_footer")
                    .font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.center)
            }
            .padding(24)
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
            _ = openURL(url)
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
