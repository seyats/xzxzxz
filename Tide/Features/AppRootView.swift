import AuthenticationServices
import SwiftUI
import UIKit

struct AppRootView: View {
    @Environment(AppDependencies.self) private var dependencies

    var body: some View {
        if dependencies.session.isAuthenticated {
            MainTabView()
        } else {
            LoginView()
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

// struct AuthenticationView: View {
//     @Environment(AppDependencies.self) private var dependencies
//     @Environment(\.openURL) private var openURL
//     @FocusState private var focusedField: Field?
//     @State private var displayName = ""
//     @State private var email = ""
//     @State private var password = ""
//     @State private var mode: AuthMode = .signUp
//     @State private var isLoading = false
//     @State private var alertMessage: String?
//     @State private var showGoogleInfo = false
//     @State private var showGitHubInfo = false
//
//     private enum Field { case displayName, email, password }
//     private enum AuthMode: String, CaseIterable, Identifiable {
//         case signUp
//         case signIn
//
//         var id: String { rawValue }
//
//         var title: String {
//             switch self {
//             case .signUp: "Регистрация"
//             case .signIn: "Вход"
//             }
//         }
//
//         var headline: String {
//             switch self {
//             case .signUp: "Создайте аккаунт за минуту"
//             case .signIn: "С возвращением"
//             }
//         }
//
//         var subtitle: String {
//             switch self {
//             case .signUp: "Профиль, который ощущается как Telegram и X, но без шума."
//             case .signIn: "Введите почту и пароль, чтобы продолжить."
//             }
//         }
//
//         var primaryAction: String {
//             switch self {
//             case .signUp: "Создать аккаунт"
//             case .signIn: "Войти"
//             }
//         }
//     }
//
//     private let googleIconURL = URL(string: "https://cdn.jsdelivr.net/gh/glincker/thesvg@main/public/icons/google/default.svg")!
//     private let githubIconURL = URL(string: "https://cdn.jsdelivr.net/gh/glincker/thesvg@main/public/icons/github/light.svg")!
//
//     var body: some View {
//         ZStack {
//             authBackdrop
//             ScrollView(showsIndicators: false) {
//                 VStack(spacing: 18) {
//                     Spacer(minLength: 10)
//                     header
//                     card
//                     Spacer(minLength: 8)
//                     Text("Продолжая, вы принимаете условия использования и политику конфиденциальности.")
//                         .font(.caption2)
//                         .foregroundStyle(.white.opacity(0.66))
//                         .multilineTextAlignment(.center)
//                         .padding(.horizontal, 28)
//                 }
//                 .padding(.horizontal, 22)
//                 .padding(.vertical, 18)
//             }
//         }
//         .ignoresSafeArea()
//         .alert("Проблема входа", isPresented: Binding(get: { alertMessage != nil }, set: { if !$0 { alertMessage = nil } })) {
//             Button("ОК", role: .cancel) {}
//         } message: {
//             Text(alertMessage ?? "")
//         }
//         .alert("Вход через Google", isPresented: $showGoogleInfo) {
//             Button("ОК", role: .cancel) {}
//         } message: {
//             Text("Чтобы включить Google OAuth, настройте TIDE_API_BASE_URL. Для локального профиля используйте вход по почте или Apple.")
//         }
//         .alert("Вход через GitHub", isPresented: $showGitHubInfo) {
//             Button("ОК", role: .cancel) {}
//         } message: {
//             Text("Чтобы включить GitHub OAuth, настройте backend и маршрут auth/github/start.")
//         }
//     }
//
//     private var authBackdrop: some View {
//         ZStack {
//             LinearGradient(
//                 colors: [
//                     Color(red: 0.84, green: 0.46, blue: 1.0),
//                     Color(red: 0.36, green: 0.10, blue: 0.67),
//                     .black
//                 ],
//                 startPoint: .top,
//                 endPoint: .bottom
//             )
//             .ignoresSafeArea()
//
//             Circle()
//                 .fill(.white.opacity(0.14))
//                 .frame(width: 240, height: 240)
//                 .blur(radius: 52)
//                 .offset(x: 120, y: -260)
//
//             Circle()
//                 .fill(.black.opacity(0.34))
//                 .frame(width: 280, height: 280)
//                 .blur(radius: 72)
//                 .offset(x: -140, y: 280)
//         }
//     }
//
//     private var header: some View {
//         VStack(spacing: 22) {
//             ZStack {
//                 Circle()
//                     .fill(.white.opacity(0.14))
//                     .frame(width: 76, height: 76)
//                 Image(systemName: "bubble.left.and.bubble.right.fill")
//                     .font(.system(size: 30, weight: .semibold))
//                     .foregroundStyle(.white)
//             }
//
//             Text("OnlyPipe")
//                 .font(.system(size: 28, weight: .semibold, design: .rounded))
//                 .foregroundStyle(.white)
//
//             VStack(spacing: 10) {
//                 Text(mode.headline)
//                     .font(.system(size: 32, weight: .semibold, design: .rounded))
//                     .foregroundStyle(.white)
//                 Text(mode.subtitle)
//                     .font(.callout)
//                     .foregroundStyle(.white.opacity(0.82))
//                     .multilineTextAlignment(.center)
//             }
//             .padding(.top, 8)
//         }
//         .padding(.top, 24)
//     }
//
//     private var card: some View {
//         VStack(spacing: 18) {
//             Picker("", selection: $mode) {
//                 ForEach(AuthMode.allCases) { option in
//                     Text(option.title).tag(option)
//                 }
//             }
//             .pickerStyle(.segmented)
//
//             HStack(spacing: 14) {
//                 socialButton(title: "Google", iconURL: googleIconURL, action: startGoogleSignIn)
//                 socialButton(title: "GitHub", iconURL: githubIconURL, action: startGitHubSignIn)
//             }
//
//             SignInWithAppleButton(.signIn) { request in
//                 request.requestedScopes = [.fullName, .email]
//             } onCompletion: { result in
//                 handleAppleSignIn(result)
//             }
//             .signInWithAppleButtonStyle(.white)
//             .frame(height: 56)
//             .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
//             .overlay(
//                 RoundedRectangle(cornerRadius: 18, style: .continuous)
//                     .stroke(.white.opacity(0.14), lineWidth: 1)
//             )
//
//             divider
//
//             if mode == .signUp {
//                 field(title: "Имя", placeholder: "Иван Петров", text: $displayName, field: .displayName)
//             }
//
//             field(title: "Почта", placeholder: "idime@inbox.ru", text: $email, field: .email, keyboard: .emailAddress, contentType: .username)
//             field(title: "Пароль", placeholder: "••••••••", text: $password, field: .password, isSecure: true, contentType: mode == .signUp ? .newPassword : .password)
//
//             Button(action: submitEmail) {
//                 Text(mode.primaryAction)
//                     .frame(maxWidth: .infinity)
//                     .frame(height: 54)
//             }
//             .foregroundStyle(.black)
//             .background(
//                 LinearGradient(colors: [.white, .white.opacity(0.92)], startPoint: .top, endPoint: .bottom),
//                 in: RoundedRectangle(cornerRadius: 18, style: .continuous)
//             )
//             .disabled(isLoading)
//             .opacity(isLoading ? 0.75 : 1)
//
//             Button {
//                 mode = mode == .signUp ? .signIn : .signUp
//             } label: {
//                 Text(mode == .signUp ? "Уже есть аккаунт? Войти" : "Создать новый аккаунт")
//                     .font(.footnote.weight(.semibold))
//                     .foregroundStyle(.white.opacity(0.86))
//             }
//             .padding(.top, 2)
//         }
//         .padding(22)
//         .background(
//             LinearGradient(colors: [.black.opacity(0.92), .black.opacity(0.72)], startPoint: .top, endPoint: .bottom),
//             in: RoundedRectangle(cornerRadius: 30, style: .continuous)
//         )
//         .overlay {
//             RoundedRectangle(cornerRadius: 30, style: .continuous)
//                 .stroke(.white.opacity(0.14), lineWidth: 0.8)
//         }
//         .shadow(color: .black.opacity(0.45), radius: 28, y: 14)
//     }
//
//     private var divider: some View {
//         HStack(spacing: 14) {
//             Rectangle().fill(.white.opacity(0.16)).frame(height: 1)
//             Text("или")
//                 .font(.subheadline.weight(.medium))
//                 .foregroundStyle(.white.opacity(0.78))
//             Rectangle().fill(.white.opacity(0.16)).frame(height: 1)
//         }
//     }
//
//     private func socialButton(title: String, iconURL: URL, action: @escaping () -> Void) -> some View {
//         Button(action: action) {
//             HStack(spacing: 10) {
//                 SVGRemoteView(url: iconURL)
//                     .frame(width: 18, height: 18)
//                 Text(title)
//                     .font(.subheadline.weight(.semibold))
//             }
//             .frame(maxWidth: .infinity)
//             .frame(height: 58)
//             .foregroundStyle(.white)
//             .background(.white.opacity(0.03), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
//             .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(.white.opacity(0.16), lineWidth: 1))
//         }
//     }
//
//     private func field(
//         title: String,
//         placeholder: String,
//         text: Binding<String>,
//         field: Field,
//         keyboard: UIKeyboardType = .default,
//         isSecure: Bool = false,
//         contentType: UITextContentType? = nil
//     ) -> some View {
//         VStack(alignment: .leading, spacing: 10) {
//             Text(title)
//                 .font(.subheadline.weight(.semibold))
//                 .foregroundStyle(.white)
//             Group {
//                 if isSecure {
//                     SecureField(placeholder, text: text)
//                 } else {
//                     TextField(placeholder, text: text)
//                 }
//             }
//             .textInputAutocapitalization(.never)
//             .keyboardType(keyboard)
//             .textContentType(contentType)
//             .focused($focusedField, equals: field)
//             .padding(.horizontal, 18)
//             .padding(.vertical, 16)
//             .foregroundStyle(.white)
//             .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
//             .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(.white.opacity(0.12), lineWidth: 1))
//         }
//     }
//
//     private func submitEmail() {
//         guard !isLoading else { return }
//         isLoading = true
//         let creatingAccount = mode == .signUp
//         let trimmedName = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
//         Task {
//             await dependencies.session.signInEmail(
//                 email: email,
//                 password: password,
//                 displayName: trimmedName.isEmpty ? nil : trimmedName,
//                 createsAccount: creatingAccount
//             )
//             let message = dependencies.session.errorMessage
//             await MainActor.run {
//                 isLoading = false
//                 alertMessage = message
//             }
//         }
//     }
//
//     private func startGoogleSignIn() {
//         if let baseURL = ServerConfiguration.current.apiBaseURL {
//             openURL(baseURL.appendingPathComponent("auth/google/start"))
//         } else {
//             showGoogleInfo = true
//         }
//     }
//
//     private func startGitHubSignIn() {
//         if let baseURL = ServerConfiguration.current.apiBaseURL {
//             openURL(baseURL.appendingPathComponent("auth/github/start"))
//         } else {
//             showGitHubInfo = true
//         }
//     }
//
//     private func handleAppleSignIn(_ result: Result<ASAuthorization, Error>) {
//         switch result {
//         case .success(let authorization):
//             guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else {
//                 alertMessage = "Не удалось получить данные Apple."
//                 return
//             }
//             let name = [credential.fullName?.givenName, credential.fullName?.familyName].compactMap { $0 }.joined(separator: " ")
//             Task {
//                 await dependencies.session.signInApple(
//                     userIdentifier: credential.user,
//                     email: credential.email,
//                     displayName: name.isEmpty ? nil : name
//                 )
//                 let message = dependencies.session.errorMessage
//                 await MainActor.run {
//                     alertMessage = message
//                 }
//             }
//         case .failure(let error):
//             alertMessage = error.localizedDescription
//         }
//     }
// }
    @Environment(AppDependencies.self) private var dependencies
    @Environment(\.openURL) private var openURL
    @FocusState private var focusedField: Field?
    @State private var displayName = ""
    @State private var email = ""
    @State private var password = ""
    @State private var mode: AuthMode = .signUp
    @State private var isLoading = false
    @State private var alertMessage: String?
    @State private var showGoogleInfo = false
    @State private var showGitHubInfo = false

    private enum Field { case displayName, email, password }
    private enum AuthMode: String, CaseIterable, Identifiable {
        case signUp
        case signIn

        var id: String { rawValue }

        var title: String {
            switch self {
            case .signUp: "Регистрация"
            case .signIn: "Вход"
            }
        }

        var headline: String {
            switch self {
            case .signUp: "Создайте аккаунт за минуту"
            case .signIn: "С возвращением"
            }
        }

        var subtitle: String {
            switch self {
            case .signUp: "Профиль, который ощущается как Telegram и X, но без шума."
            case .signIn: "Введите почту и пароль, чтобы продолжить."
            }
        }

        var primaryAction: String {
            switch self {
            case .signUp: "Создать аккаунт"
            case .signIn: "Войти"
            }
        }
    }

    private let googleIconURL = URL(string: "https://cdn.jsdelivr.net/gh/glincker/thesvg@main/public/icons/google/default.svg")!
    private let githubIconURL = URL(string: "https://cdn.jsdelivr.net/gh/glincker/thesvg@main/public/icons/github/light.svg")!

    var body: some View {
        ZStack {
            authBackdrop
            ScrollView(showsIndicators: false) {
                VStack(spacing: 18) {
                    Spacer(minLength: 10)
                    header
                    card
                    Spacer(minLength: 8)
                    Text("Продолжая, вы принимаете условия использования и политику конфиденциальности.")
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.66))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 28)
                }
                .padding(.horizontal, 22)
                .padding(.vertical, 18)
            }
        }
        .ignoresSafeArea()
        .alert("Проблема входа", isPresented: Binding(get: { alertMessage != nil }, set: { if !$0 { alertMessage = nil } })) {
            Button("ОК", role: .cancel) {}
        } message: {
            Text(alertMessage ?? "")
        }
        .alert("Вход через Google", isPresented: $showGoogleInfo) {
            Button("ОК", role: .cancel) {}
        } message: {
            Text("Чтобы включить Google OAuth, настройте TIDE_API_BASE_URL. Для локального профиля используйте вход по почте или Apple.")
        }
        .alert("Вход через GitHub", isPresented: $showGitHubInfo) {
            Button("ОК", role: .cancel) {}
        } message: {
            Text("Чтобы включить GitHub OAuth, настройте backend и маршрут auth/github/start.")
        }
    }

    private var authBackdrop: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.84, green: 0.46, blue: 1.0),
                    Color(red: 0.36, green: 0.10, blue: 0.67),
                    .black
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            Circle()
                .fill(.white.opacity(0.14))
                .frame(width: 240, height: 240)
                .blur(radius: 52)
                .offset(x: 120, y: -260)

            Circle()
                .fill(.black.opacity(0.34))
                .frame(width: 280, height: 280)
                .blur(radius: 72)
                .offset(x: -140, y: 280)
        }
    }

    private var header: some View {
        VStack(spacing: 22) {
            ZStack {
                Circle()
                    .fill(.white.opacity(0.14))
                    .frame(width: 76, height: 76)
                Image(systemName: "bubble.left.and.bubble.right.fill")
                    .font(.system(size: 30, weight: .semibold))
                    .foregroundStyle(.white)
            }

            Text("OnlyPipe")
                .font(.system(size: 28, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)

            VStack(spacing: 10) {
                Text(mode.headline)
                    .font(.system(size: 32, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                Text(mode.subtitle)
                    .font(.callout)
                    .foregroundStyle(.white.opacity(0.82))
                    .multilineTextAlignment(.center)
            }
            .padding(.top, 8)
        }
        .padding(.top, 24)
    }

    private var card: some View {
        VStack(spacing: 18) {
            Picker("", selection: $mode) {
                ForEach(AuthMode.allCases) { option in
                    Text(option.title).tag(option)
                }
            }
            .pickerStyle(.segmented)

            HStack(spacing: 14) {
                socialButton(title: "Google", iconURL: googleIconURL, action: startGoogleSignIn)
                socialButton(title: "GitHub", iconURL: githubIconURL, action: startGitHubSignIn)
            }

            SignInWithAppleButton(.signIn) { request in
                request.requestedScopes = [.fullName, .email]
            } onCompletion: { result in
                handleAppleSignIn(result)
            }
            .signInWithAppleButtonStyle(.white)
            .frame(height: 56)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(.white.opacity(0.14), lineWidth: 1)
            )

            divider

            if mode == .signUp {
                field(title: "Имя", placeholder: "Иван Петров", text: $displayName, field: .displayName)
            }

            field(title: "Почта", placeholder: "idime@inbox.ru", text: $email, field: .email, keyboard: .emailAddress, contentType: .username)
            field(title: "Пароль", placeholder: "••••••••", text: $password, field: .password, isSecure: true, contentType: mode == .signUp ? .newPassword : .password)

            Button(action: submitEmail) {
                Text(mode.primaryAction)
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
            }
            .foregroundStyle(.black)
            .background(
                LinearGradient(colors: [.white, .white.opacity(0.92)], startPoint: .top, endPoint: .bottom),
                in: RoundedRectangle(cornerRadius: 18, style: .continuous)
            )
            .disabled(isLoading)
            .opacity(isLoading ? 0.75 : 1)

            Button {
                mode = mode == .signUp ? .signIn : .signUp
            } label: {
                Text(mode == .signUp ? "Уже есть аккаунт? Войти" : "Создать новый аккаунт")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.86))
            }
            .padding(.top, 2)
        }
        .padding(22)
        .background(
            LinearGradient(colors: [.black.opacity(0.92), .black.opacity(0.72)], startPoint: .top, endPoint: .bottom),
            in: RoundedRectangle(cornerRadius: 30, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .stroke(.white.opacity(0.14), lineWidth: 0.8)
        }
        .shadow(color: .black.opacity(0.45), radius: 28, y: 14)
    }

    private var divider: some View {
        HStack(spacing: 14) {
            Rectangle().fill(.white.opacity(0.16)).frame(height: 1)
            Text("или")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.white.opacity(0.78))
            Rectangle().fill(.white.opacity(0.16)).frame(height: 1)
        }
    }

    private func socialButton(title: String, iconURL: URL, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                SVGRemoteView(url: iconURL)
                    .frame(width: 18, height: 18)
                Text(title)
                    .font(.subheadline.weight(.semibold))
            }
            .frame(maxWidth: .infinity)
            .frame(height: 58)
            .foregroundStyle(.white)
            .background(.white.opacity(0.03), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(.white.opacity(0.16), lineWidth: 1))
        }
    }

    private func field(
        title: String,
        placeholder: String,
        text: Binding<String>,
        field: Field,
        keyboard: UIKeyboardType = .default,
        isSecure: Bool = false,
        contentType: UITextContentType? = nil
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)
            Group {
                if isSecure {
                    SecureField(placeholder, text: text)
                } else {
                    TextField(placeholder, text: text)
                }
            }
            .textInputAutocapitalization(.never)
            .keyboardType(keyboard)
            .textContentType(contentType)
            .focused($focusedField, equals: field)
            .padding(.horizontal, 18)
            .padding(.vertical, 16)
            .foregroundStyle(.white)
            .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(.white.opacity(0.12), lineWidth: 1))
        }
    }

    private func submitEmail() {
        guard !isLoading else { return }
        isLoading = true
        let creatingAccount = mode == .signUp
        let trimmedName = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        Task {
            await dependencies.session.signInEmail(
                email: email,
                password: password,
                displayName: trimmedName.isEmpty ? nil : trimmedName,
                createsAccount: creatingAccount
            )
            let message = dependencies.session.errorMessage
            await MainActor.run {
                isLoading = false
                alertMessage = message
            }
        }
    }

    private func startGoogleSignIn() {
        if let baseURL = ServerConfiguration.current.apiBaseURL {
            openURL(baseURL.appendingPathComponent("auth/google/start"))
        } else {
            showGoogleInfo = true
        }
    }

    private func startGitHubSignIn() {
        if let baseURL = ServerConfiguration.current.apiBaseURL {
            openURL(baseURL.appendingPathComponent("auth/github/start"))
        } else {
            showGitHubInfo = true
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
