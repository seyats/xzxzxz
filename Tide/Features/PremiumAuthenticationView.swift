import AuthenticationServices
import SwiftUI
import UIKit

struct PremiumAuthenticationView: View {
    @Environment(AppDependencies.self) private var dependencies
    @FocusState private var focusedField: Field?
    @State private var stage: AuthStage = .landing
    @State private var identifier = ""
    @State private var password = ""
    @State private var passwordVisible = false
    @State private var isLoading = false
    @State private var alertMessage: String?

    private enum AuthStage { case landing, credentials }
    private enum Field { case identifier, password }

    var body: some View {
        ZStack {
            AuthBlackBackdrop()

            Group {
                switch stage {
                case .landing:
                    landingScreen
                case .credentials:
                    credentialsScreen
                }
            }
            .padding(.horizontal, 28)
            .animation(.smooth(duration: 0.42), value: stage)
        }
        .preferredColorScheme(.dark)
        .ignoresSafeArea()
        .alert("Sign in", isPresented: Binding(get: { alertMessage != nil }, set: { if !$0 { alertMessage = nil } })) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(alertMessage ?? "")
        }
    }

    private var landingScreen: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 58)

            AuthChromeLogo(size: 142)
                .padding(.bottom, 10)

            VStack(spacing: 8) {
                Text("Welcome back")
                    .font(TideTypography.brand(32))
                    .foregroundStyle(.white)
                Text("Sign in to continue")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.white.opacity(0.48))
            }
            .padding(.top, 20)

            HStack(spacing: 12) {
                AuthSocialGlassButton(kind: .github, svgName: "github") {
                    setPlaceholder("Вход через GitHub пока работает как заглушка.")
                }
                AuthSocialGlassButton(kind: .google, svgName: "google") {
                    setPlaceholder("Вход через Google пока работает как заглушка.")
                }
                AppleAuthGlassButton(svgName: "apple", completion: handleAppleSignIn)
            }
            .padding(.top, 34)

            AuthDivider(title: "or")
                .frame(maxWidth: 210)
                .padding(.top, 30)

            VStack(spacing: 12) {
                AuthCompactButton(title: "Continue with Email", systemImage: "arrow.right") {
                    showCredentials()
                }
                AuthCompactButton(title: "Continue with Username", systemImage: "arrow.right") {
                    showCredentials()
                }
            }
            .padding(.top, 26)

            Spacer()

            AuthFooter(prefix: "Don’t have an account?", action: "Sign up") {
                setPlaceholder("Регистрация появится после приватного preview.")
            }
            .padding(.bottom, 34)
        }
    }

    private var credentialsScreen: some View {
        VStack(spacing: 0) {
            HStack {
                Button {
                    withAnimation(.smooth(duration: 0.38)) { stage = .landing }
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.82))
                        .frame(width: 38, height: 38)
                        .background(AuthGlassBackground(cornerRadius: 13, interactive: true))
                }
                Spacer()
            }
            .padding(.top, 58)

            Spacer(minLength: 50)

            VStack(spacing: 8) {
                Text("Welcome back")
                    .font(TideTypography.brand(33))
                    .foregroundStyle(.white)
                Text("Sign in to continue")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.white.opacity(0.48))
            }
            .padding(.bottom, 34)

            VStack(spacing: 14) {
                AuthInputField(
                    placeholder: "Email or username",
                    text: $identifier,
                    icon: "at",
                    isSecure: false,
                    isVisible: .constant(true)
                )
                .focused($focusedField, equals: .identifier)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .keyboardType(.emailAddress)
                .textContentType(.username)

                AuthInputField(
                    placeholder: "Password",
                    text: $password,
                    icon: "eye",
                    isSecure: true,
                    isVisible: $passwordVisible
                )
                .focused($focusedField, equals: .password)
                .textContentType(.password)
            }
            .frame(maxWidth: 330)

            HStack {
                Spacer()
                Button("Forgot password?") {
                    setPlaceholder("Сброс пароля пока работает как заглушка.")
                }
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.white.opacity(0.55))
            }
            .frame(maxWidth: 330)
            .padding(.top, 10)

            Button(action: submitCredentials) {
                HStack(spacing: 8) {
                    if isLoading {
                        ProgressView().tint(.black)
                    }
                    Text("Sign in")
                        .font(.system(size: 15, weight: .semibold))
                }
                .foregroundStyle(.black)
                .frame(width: 154, height: 48)
                .background(.white, in: Capsule())
                .shadow(color: .white.opacity(0.18), radius: 18, y: 8)
            }
            .disabled(isLoading)
            .padding(.top, 26)

            AuthDivider(title: "or continue with")
                .frame(maxWidth: 250)
                .padding(.top, 34)

            HStack(spacing: 13) {
                AuthSocialGlassButton(kind: .github, svgName: "github", shape: .circle) {
                    setPlaceholder("Вход через GitHub пока работает как заглушка.")
                }
                AuthSocialGlassButton(kind: .google, svgName: "google", shape: .circle) {
                    setPlaceholder("Вход через Google пока работает как заглушка.")
                }
                AppleAuthGlassButton(svgName: "apple", shape: .circle, completion: handleAppleSignIn)
            }
            .padding(.top, 22)

            Spacer()

            AuthFooter(prefix: "No account?", action: "Sign up") {
                setPlaceholder("Регистрация появится после приватного preview.")
            }
            .padding(.bottom, 34)
        }
    }

    private func showCredentials() {
        withAnimation(.smooth(duration: 0.42)) {
            stage = .credentials
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.44) {
            focusedField = .identifier
        }
    }

    private func submitCredentials() {
        guard !isLoading else { return }
        isLoading = true
        Task {
            await dependencies.session.signInIdentifier(identifier, password: password)
            let message = dependencies.session.errorMessage
            await MainActor.run {
                isLoading = false
                alertMessage = message
            }
        }
    }

    private func setPlaceholder(_ message: String) {
        alertMessage = message
    }

    private func handleAppleSignIn(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let authorization):
            guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else {
                alertMessage = "Apple did not return account details."
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

struct AuthProfileSetupView: View {
    @Environment(AppDependencies.self) private var dependencies
    @FocusState private var focusedField: Field?
    @State private var step: Step = .name
    @State private var firstName = ""
    @State private var lastName = ""
    @State private var username = ""

    private enum Step { case name, username }
    private enum Field { case firstName, lastName, username }

    var body: some View {
        ZStack {
            AuthBlackBackdrop()

            VStack(spacing: 0) {
                Spacer()

                AuthChromeLogo(size: 112)
                    .padding(.bottom, 30)

                VStack(spacing: 8) {
                    Text(step == .name ? "Complete your name" : "Choose username")
                        .font(.system(size: 30, weight: .semibold))
                        .foregroundStyle(.white)
                    Text(step == .name ? "A clean profile for Tide." : "This is how people find you.")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.white.opacity(0.48))
                }
                .padding(.bottom, 30)

                Group {
                    if step == .name {
                        VStack(spacing: 14) {
                            AuthInputField(placeholder: "First name", text: $firstName, icon: "person", isSecure: false, isVisible: .constant(true))
                                .focused($focusedField, equals: .firstName)
                            AuthInputField(placeholder: "Last name", text: $lastName, icon: "person.text.rectangle", isSecure: false, isVisible: .constant(true))
                                .focused($focusedField, equals: .lastName)
                        }
                    } else {
                        AuthInputField(placeholder: "Username", text: $username, icon: "at", isSecure: false, isVisible: .constant(true))
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .focused($focusedField, equals: .username)
                    }
                }
                .frame(maxWidth: 330)
                .animation(.smooth(duration: 0.32), value: step)

                Button(action: continueSetup) {
                    Text(step == .name ? "Continue" : "Enter Tide")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.black)
                        .frame(width: 154, height: 48)
                        .background(.white, in: Capsule())
                        .shadow(color: .white.opacity(0.18), radius: 18, y: 8)
                }
                .padding(.top, 28)

                Spacer()

                if dependencies.session.currentUser?.isVerified == true {
                    HStack(spacing: 8) {
                        TideBrandLogoView(size: 18, style: .circle)
                        Text("аккаунт верифицирован")
                            .font(.caption.weight(.medium))
                    }
                    .foregroundStyle(.white.opacity(0.48))
                    .padding(.bottom, 34)
                }
            }
            .padding(.horizontal, 28)
        }
        .preferredColorScheme(.dark)
        .ignoresSafeArea()
        .onAppear {
            let user = dependencies.session.currentUser
            let parts = (user?.name ?? "").split(separator: " ", maxSplits: 1).map(String.init)
            firstName = parts.first ?? ""
            lastName = parts.dropFirst().first ?? ""
            username = user?.username ?? ""
            focusedField = .firstName
        }
    }

    private func continueSetup() {
        switch step {
        case .name:
            withAnimation(.smooth(duration: 0.36)) {
                step = .username
                focusedField = .username
            }
        case .username:
            let fullName = [firstName, lastName]
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
                .joined(separator: " ")
            dependencies.session.completeProfileSetup(name: fullName, username: username)
            dependencies.router.selectedTab = .chats
        }
    }
}

struct AuthBlackBackdrop: View {
    var body: some View {
        ZStack {
            Color.black
            LinearGradient(
                colors: [
                    .black,
                    .white.opacity(0.06),
                    .black,
                    .white.opacity(0.03)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .blur(radius: 30)
            .opacity(0.8)
        }
    }
}

struct AuthChromeLogo: View {
    let size: CGFloat

    var body: some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [.white.opacity(0.18), .black, .white.opacity(0.32), .black.opacity(0.9)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: size, height: size)
                .shadow(color: .white.opacity(0.14), radius: 28, y: -10)
                .shadow(color: .black.opacity(0.75), radius: 30, y: 18)

            TideBrandLogoView(size: size * 0.74, style: .rounded(size * 0.18))
                .overlay {
                    RoundedRectangle(cornerRadius: size * 0.18, style: .continuous)
                        .stroke(.white.opacity(0.18), lineWidth: 0.7)
                }
                .shadow(color: .white.opacity(0.16), radius: 18, y: -4)

            Circle()
                .stroke(
                    LinearGradient(colors: [.white.opacity(0.65), .white.opacity(0.05), .white.opacity(0.32)], startPoint: .topLeading, endPoint: .bottomTrailing),
                    lineWidth: 0.8
                )
                .frame(width: size, height: size)
        }
    }
}

struct AuthDivider: View {
    let title: String

    var body: some View {
        HStack(spacing: 12) {
            Rectangle().fill(.white.opacity(0.13)).frame(height: 0.7)
            Text(title)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.white.opacity(0.38))
            Rectangle().fill(.white.opacity(0.13)).frame(height: 0.7)
        }
    }
}

struct AuthCompactButton: View {
    let title: String
    let systemImage: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Text(title)
                Image(systemName: systemImage)
                    .font(.system(size: 12, weight: .bold))
            }
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(.white.opacity(0.9))
            .padding(.horizontal, 18)
            .frame(height: 44)
            .background(AuthGlassBackground(cornerRadius: 16, interactive: true))
        }
        .buttonStyle(.plain)
    }
}

struct AuthInputField: View {
    let placeholder: String
    @Binding var text: String
    let icon: String
    let isSecure: Bool
    @Binding var isVisible: Bool

    var body: some View {
        HStack(spacing: 12) {
            Group {
                if isSecure && !isVisible {
                    SecureField(placeholder, text: $text)
                } else {
                    TextField(placeholder, text: $text)
                }
            }
            .font(.system(size: 15, weight: .medium))
            .foregroundStyle(.white)
            .tint(.white)

            Button {
                if isSecure {
                    isVisible.toggle()
                }
            } label: {
                Image(systemName: isSecure ? (isVisible ? "eye.slash" : icon) : icon)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.white.opacity(0.44))
                    .frame(width: 24, height: 24)
            }
            .buttonStyle(.plain)
            .disabled(!isSecure)
        }
        .padding(.horizontal, 16)
        .frame(height: 54)
        .background(AuthGlassBackground(cornerRadius: 18, interactive: true))
    }
}

struct AuthSocialGlassButton: View {
    enum Kind { case github, google }
    enum ShapeMode { case roundedSquare, circle }

    let kind: Kind
    let svgName: String
    var shape: ShapeMode = .roundedSquare
    let action: () -> Void

    private var size: CGFloat { shape == .circle ? 48 : 54 }
    private var cornerRadius: CGFloat { shape == .circle ? 24 : 17 }

    var body: some View {
        Button(action: action) {
            ZStack {
                AuthGlassBackground(cornerRadius: cornerRadius, interactive: true)
                BrandSVG(name: svgName)
                    .frame(width: size * 0.46, height: size * 0.46)
                    .padding(kind == .google ? 0 : 1)
            }
            .frame(width: size, height: size)
        }
        .buttonStyle(.plain)
    }
}

struct AppleAuthGlassButton: View {
    enum ShapeMode { case roundedSquare, circle }

    let svgName: String
    var shape: ShapeMode = .roundedSquare
    let completion: (Result<ASAuthorization, Error>) -> Void

    private var size: CGFloat { shape == .circle ? 48 : 54 }
    private var cornerRadius: CGFloat { shape == .circle ? 24 : 17 }

    var body: some View {
        ZStack {
            AuthGlassBackground(cornerRadius: cornerRadius, interactive: true)
            BrandSVG(name: svgName)
                .frame(width: size * 0.42, height: size * 0.42)
        }
        .frame(width: size, height: size)
        .overlay {
            if shape == .circle {
                SignInWithAppleButton(.signIn) { request in
                    request.requestedScopes = [.fullName, .email]
                } onCompletion: { result in
                    completion(result)
                }
                .signInWithAppleButtonStyle(.black)
                .clipShape(Circle())
                .opacity(0.02)
            } else {
                SignInWithAppleButton(.signIn) { request in
                    request.requestedScopes = [.fullName, .email]
                } onCompletion: { result in
                    completion(result)
                }
                .signInWithAppleButtonStyle(.black)
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                .opacity(0.02)
            }
        }
    }
}

struct BrandSVG: View {
    let name: String

    var body: some View {
        if let url = Bundle.main.url(forResource: name, withExtension: "svg") {
            SVGRemoteView(url: url)
                .allowsHitTesting(false)
        } else {
            Image(systemName: "circle.fill")
                .foregroundStyle(.white.opacity(0.5))
        }
    }
}

struct AuthFooter: View {
    let prefix: String
    let action: String
    let tap: () -> Void

    var body: some View {
        HStack(spacing: 4) {
            Text(prefix)
                .foregroundStyle(.white.opacity(0.42))
            Button(action: tap) {
                Text(action)
            }
            .foregroundStyle(.white.opacity(0.82))
        }
        .font(.system(size: 13, weight: .medium))
    }
}

struct AuthGlassBackground: View {
    let cornerRadius: CGFloat
    var interactive = false

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(.white.opacity(0.045))
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(
                        LinearGradient(colors: [.white.opacity(0.26), .white.opacity(0.06)], startPoint: .topLeading, endPoint: .bottomTrailing),
                        lineWidth: 0.7
                    )
            }
            .shadow(color: .black.opacity(0.35), radius: 18, y: 10)
            .authGlass(cornerRadius: cornerRadius, interactive: interactive)
    }
}

extension View {
    @ViewBuilder
    func authGlass(cornerRadius: CGFloat, interactive: Bool) -> some View {
        if #available(iOS 26, *) {
            self.glassEffect(
                interactive ? .regular.tint(.white.opacity(0.05)).interactive() : .regular.tint(.white.opacity(0.05)),
                in: .rect(cornerRadius: cornerRadius)
            )
        } else {
            self.background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        }
    }
}
