import SwiftUI

@available(iOS 17.0, *)
struct EmailLoginView: View {
    @Environment(AppDependencies.self) private var dependencies
    @Environment(\.dismiss) private var dismiss

    @State private var email = ""
    @State private var password = ""
    @State private var displayName = ""
    @State private var isPasswordVisible = false
    @State private var isSignUp = false

    private var emailSuggestions: [String] { EmailSuggestions.suggestions(for: email) }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(spacing: 0) {
                header.padding(.bottom, 40)

                if isSignUp {
                    inputBlock(title: "Имя") {
                        TextField("Имя Фамилия", text: $displayName)
                            .textContentType(.name)
                    }
                    .padding(.bottom, 20)
                }

                emailBlock.padding(.bottom, 24)

                inputBlock(title: "Пароль") {
                    HStack {
                        Group {
                            if isPasswordVisible {
                                TextField("••••••••", text: $password)
                            } else {
                                SecureField("••••••••", text: $password)
                            }
                        }
                        Spacer()
                        Button { isPasswordVisible.toggle() } label: {
                            Image(systemName: isPasswordVisible ? "eye.slash" : "eye")
                                .foregroundColor(.gray)
                        }
                    }
                }
                .padding(.bottom, 24)

                if !isSignUp {
                    HStack {
                        Spacer()
                        Button("Забыли пароль?") { }
                            .font(.system(size: 14))
                            .foregroundColor(.gray)
                    }
                    .padding(.bottom, 40)
                }

                Button(action: handleSignIn) {
                    HStack {
                        if dependencies.session.isWorking {
                            ProgressView().tint(.black)
                        } else {
                            Text(isSignUp ? "Создать аккаунт" : "Войти")
                                .font(.system(size: 16, weight: .semibold))
                        }
                        Spacer()
                        if !dependencies.session.isWorking { Image(systemName: "arrow.right") }
                    }
                    .foregroundColor(.black)
                    .padding(.horizontal, 24)
                    .frame(height: 52)
                    .background(Color.white)
                    .cornerRadius(12)
                }
                .disabled(dependencies.session.isWorking)
                .padding(.bottom, 24)

                if let error = dependencies.session.errorMessage {
                    errorBlock(error).padding(.bottom, 24)
                }

                socialBlock

                Spacer()

                HStack(spacing: 4) {
                    Text(isSignUp ? "Уже есть аккаунт?" : "Нет аккаунта?")
                        .foregroundColor(.gray)
                    Button(isSignUp ? "Войти" : "Регистрация") { isSignUp.toggle() }
                        .foregroundColor(.white)
                        .fontWeight(.semibold)
                }
                .font(.system(size: 14))
                .padding(.bottom, 32)
            }
            .padding(.horizontal, 28)
        }
        .navigationBarHidden(true)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 24) {
            Button(action: { dismiss() }) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.white)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("С возвращением")
                    .font(TideTypography.display)
                    .foregroundColor(.white)

                Text("Войдите, чтобы продолжить")
                    .font(.system(size: 16, weight: .regular))
                    .foregroundColor(.gray)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 20)
    }

    private var emailBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            inputBlock(title: "Эл. почта") {
                TextField("почта@пример.ру", text: $email)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(.emailAddress)
            }

            if !emailSuggestions.isEmpty {
                VStack(spacing: 0) {
                    ForEach(emailSuggestions, id: \.self) { suggestion in
                        Button { email = suggestion } label: {
                            HStack {
                                Image(systemName: "envelope").foregroundColor(.gray)
                                Text(suggestion).foregroundColor(.white)
                                Spacer()
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                        }
                    }
                }
                .background(Color(white: 0.08))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
        }
    }

    private func inputBlock<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.gray)

            content()
                .foregroundColor(.white)
                .tint(.white)
                .padding(.horizontal, 16)
                .frame(height: 56)
                .background(Color(white: 0.05))
                .cornerRadius(12)
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(white: 0.15), lineWidth: 1))
        }
    }

    private func errorBlock(_ message: String) -> some View {
        HStack {
            Image(systemName: "exclamationmark.circle.fill").foregroundColor(.red)
            Text(message).font(.system(size: 13)).foregroundColor(.red)
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.red.opacity(0.1))
        .cornerRadius(8)
    }

    private var socialBlock: some View {
        VStack(spacing: 24) {
            HStack {
                Rectangle().fill(Color(white: 0.15)).frame(height: 0.5)
                Text("или войдите через")
                    .font(.system(size: 14))
                    .foregroundColor(.gray)
                    .padding(.horizontal, 8)
                Rectangle().fill(Color(white: 0.15)).frame(height: 0.5)
            }
            HStack(spacing: 20) {
                socialCircle(.google)
                socialCircle(.apple)
                socialCircle(.github)
            }
        }
    }

    private func socialCircle(_ brand: SocialBrand) -> some View {
        Button(action: {}) {
            socialIcon(for: brand)
                .frame(width: 54, height: 54)
                .background(AuthGlassBackground(cornerRadius: 27, interactive: true))
                .clipShape(Circle())
        }
        .buttonStyle(AuthSmoothButtonStyle())
    }

    @ViewBuilder
    private func socialIcon(for brand: SocialBrand) -> some View {
        if brand == .apple {
            Image(systemName: "apple.logo")
                .font(.system(size: 25, weight: .semibold))
                .foregroundStyle(.white)
        } else {
            Image(imageName(for: brand))
                .renderingMode(.original)
                .resizable()
                .scaledToFit()
                .frame(width: 24, height: 24)
        }
    }

    private func imageName(for brand: SocialBrand) -> String {
        switch brand {
        case .google: return "GoogleLogo"
        case .apple: return "AppleLogo"
        case .github: return "GitHubLogo"
        }
    }

    private func handleSignIn() {
        Task {
            if isSignUp {
                await dependencies.session.signUpEmail(email: email, password: password, displayName: displayName)
            } else {
                await dependencies.session.signInEmail(email: email, password: password)
            }
        }
    }
}
