import AuthenticationServices
import SwiftUI
import UIKit

struct PremiumAuthenticationView: View {
    @Environment(AppDependencies.self) private var dependencies
    @FocusState private var focusedField: Field?
    @State private var stage: AuthStage = .landing
    @State private var identifier = ""
    @State private var email = ""
    @State private var isLoading = false
    @State private var alertMessage: String?
    @State private var showProviderSheet = false

    private enum AuthStage { case landing, username, email }
    private enum Field { case identifier, email }

    var body: some View {
        ZStack {
            AuthBlackBackdrop()

            Group {
                switch stage {
                case .landing:
                    landingScreen
                case .username:
                    usernameScreen
                case .email:
                    emailScreen
                }
            }
            .padding(.horizontal, 28)
            .animation(.smooth(duration: 0.42), value: stage)
        }
        .preferredColorScheme(.dark)
        .ignoresSafeArea()
        .alert("Вход", isPresented: Binding(get: { alertMessage != nil }, set: { if !$0 { alertMessage = nil } })) {
            Button("ОК", role: .cancel) { }
        } message: {
            Text(alertMessage ?? "")
        }
        .sheet(isPresented: $showProviderSheet) {
            providerSheet
                .presentationDetents([.height(430)])
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(42)
                .preferredColorScheme(.dark)
        }
    }

    private var landingScreen: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 230)

            AuthChromeLogo(size: 86)
                .padding(.bottom, 24)

            Text("??????? ?????????????")
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

            Image("TideBubbleLogo")
                .resizable()
                .scaledToFit()
                .frame(width: size * 0.92, height: size * 0.92)
                .clipShape(Circle())
                .shadow(color: .white.opacity(0.18), radius: 18, y: -4)

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
        if let imageName = assetName {
            Image(imageName)
                .resizable()
                .scaledToFit()
        } else if let url = Bundle.main.url(forResource: name, withExtension: "svg") {
            SVGRemoteView(url: url)
                .allowsHitTesting(false)
        } else {
            Image(systemName: "circle.fill")
                .foregroundStyle(.white.opacity(0.5))
        }
    }

    private var assetName: String? {
        switch name {
        case "google": return "GoogleLogo"
        case "apple": return "AppleLogo"
        case "github": return "GitHubLogo"
        default: return nil
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
