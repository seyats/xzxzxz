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
                    inputBlock(title: "\u{0418}\u{043c}\u{044f}") {
                        TextField("\u{0418}\u{043c}\u{044f} \u{0424}\u{0430}\u{043c}\u{0438}\u{043b}\u{0438}\u{044f}", text: $displayName)
                            .textContentType(.name)
                    }
                    .padding(.bottom, 20)
                }

                emailBlock.padding(.bottom, 24)

                inputBlock(title: "\u{041f}\u{0430}\u{0440}\u{043e}\u{043b}\u{044c}") {
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
                        Button("\u{0417}\u{0430}\u{0431}\u{044b}\u{043b}\u{0438} \u{043f}\u{0430}\u{0440}\u{043e}\u{043b}\u{044c}?") { }
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
                            Text(isSignUp ? "\u{0421}\u{043e}\u{0437}\u{0434}\u{0430}\u{0442}\u{044c} \u{0430}\u{043a}\u{043a}\u{0430}\u{0443}\u{043d}\u{0442}" : "\u{0412}\u{043e}\u{0439}\u{0442}\u{0438}")
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
                    Text(isSignUp ? "\u{0423}\u{0436}\u{0435} \u{0435}\u{0441}\u{0442}\u{044c} \u{0430}\u{043a}\u{043a}\u{0430}\u{0443}\u{043d}\u{0442}?" : "\u{041d}\u{0435}\u{0442} \u{0430}\u{043a}\u{043a}\u{0430}\u{0443}\u{043d}\u{0442}\u{0430}?")
                        .foregroundColor(.gray)
                    Button(isSignUp ? "\u{0412}\u{043e}\u{0439}\u{0442}\u{0438}" : "\u{0420}\u{0435}\u{0433}\u{0438}\u{0441}\u{0442}\u{0440}\u{0430}\u{0446}\u{0438}\u{044f}") { isSignUp.toggle() }
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
                Text("\u{0421} \u{0432}\u{043e}\u{0437}\u{0432}\u{0440}\u{0430}\u{0449}\u{0435}\u{043d}\u{0438}\u{0435}\u{043c}")
                    .font(TideTypography.display)
                    .foregroundColor(.white)

                Text("\u{0412}\u{043e}\u{0439}\u{0434}\u{0438}\u{0442}\u{0435}, \u{0447}\u{0442}\u{043e}\u{0431}\u{044b} \u{043f}\u{0440}\u{043e}\u{0434}\u{043e}\u{043b}\u{0436}\u{0438}\u{0442}\u{044c}")
                    .font(.system(size: 16, weight: .regular))
                    .foregroundColor(.gray)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 20)
    }

    private var emailBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            inputBlock(title: "\u{042d}\u{043b}. \u{043f}\u{043e}\u{0447}\u{0442}\u{0430}") {
                TextField("\u{043f}\u{043e}\u{0447}\u{0442}\u{0430}@\u{043f}\u{0440}\u{0438}\u{043c}\u{0435}\u{0440}.\u{0440}\u{0443}", text: $email)
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
                Text("\u{0438}\u{043b}\u{0438} \u{0432}\u{043e}\u{0439}\u{0434}\u{0438}\u{0442}\u{0435} \u{0447}\u{0435}\u{0440}\u{0435}\u{0437}")
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
