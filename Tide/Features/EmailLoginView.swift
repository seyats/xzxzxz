import SwiftUI

/// Экран входа по Email в стиле Apple 2026.
/// Использует стандарты ios-dev-plugin: Liquid Glass UI и декомпозицию View.
@available(iOS 17.0, *)
struct EmailLoginView: View {
    // MARK: - Environment
    @Environment(\.dismiss) private var dismiss
    
    // MARK: - State
    @State private var email = ""
    @State private var password = ""
    @State private var isPasswordVisible = false
    @Namespace private var glassNamespace
    
    // MARK: - Body
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            VStack(alignment: .leading, spacing: 0) {
                BackButton(action: { dismiss() })
                    .padding(.top, 16)
                    .padding(.bottom, 32)
                
                HeaderSection()
                    .padding(.bottom, 40)
                
                InputSection(
                    email: $email,
                    password: $password,
                    isPasswordVisible: $isPasswordVisible
                )
                .padding(.bottom, 12)
                
                ForgotPasswordButton()
                    .padding(.bottom, 40)
                
                SignInButton(action: handleSignIn)
                    .padding(.bottom, 40)
                
                SocialContinueSection(namespace: glassNamespace)
                
                Spacer()
                
                FooterSection()
            }
            .padding(.horizontal, 28)
        }
        .navigationBarHidden(true)
    }
    
    // MARK: - Actions
    private func handleSignIn() {
        Task {
            await dependencies.session.signInEmail(email: email, password: password)
        }
    }
}

// MARK: - Subviews

@available(iOS 17.0, *)
private struct BackButton: View {
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Image(systemName: "chevron.left")
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(.white)
        }
    }
}

@available(iOS 17.0, *)
private struct HeaderSection: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Welcome back")
                .font(.system(size: 34, weight: .bold))
                .foregroundColor(.white)
            
            Text("Sign in to continue")
                .font(.system(size: 16))
                .foregroundColor(.gray)
        }
    }
}

@available(iOS 17.0, *)
private struct InputSection: View {
    @Binding var email: String
    @Binding var password: String
    @Binding var isPasswordVisible: Bool
    
    var body: some View {
        VStack(spacing: 20) {
            // Email Field
            VStack(alignment: .leading, spacing: 10) {
                Text("Email")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                
                HStack {
                    TextField("name@example.com", text: $email)
                        .font(.system(size: 16))
                        .foregroundColor(.white)
                        .accentColor(.white)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                    
                    Image(systemName: "envelope")
                        .foregroundColor(.gray)
                }
                .padding(.horizontal, 16)
                .frame(height: 54)
                .background(Color(white: 0.1).opacity(0.6))
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Color(white: 0.2), lineWidth: 0.5)
                )
            }
            
            // Password Field
            VStack(alignment: .leading, spacing: 10) {
                Text("Password")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                
                HStack {
                    if isPasswordVisible {
                        TextField("Password", text: $password)
                    } else {
                        SecureField("Password", text: $password)
                    }
                    
                    Button(action: { isPasswordVisible.toggle() }) {
                        Image(systemName: isPasswordVisible ? "eye" : "eye.slash")
                            .foregroundColor(.gray)
                    }
                }
                .font(.system(size: 16))
                .padding(.horizontal, 16)
                .frame(height: 54)
                .background(Color(white: 0.1).opacity(0.6))
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Color(white: 0.2), lineWidth: 0.5)
                )
            }
        }
    }
}

@available(iOS 17.0, *)
private struct ForgotPasswordButton: View {
    var body: some View {
        HStack {
            Spacer()
            Button("Forgot password?") { }
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.gray)
        }
    }
}

@available(iOS 17.0, *)
private struct SignInButton: View {
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Text("Sign in")
                    .font(.system(size: 16, weight: .semibold))
                Image(systemName: "arrow.right")
                    .font(.system(size: 14, weight: .bold))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .background(
                Group {
                    if #available(iOS 26.0, *) {
                        EmptyView().glassEffect(.regular.interactive(), in: .rect(cornerRadius: 14))
                    } else {
                        Color(white: 0.15).opacity(0.9).clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                }
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(Color(white: 0.3).opacity(0.5), lineWidth: 0.5)
            )
        }
    }
}

@available(iOS 17.0, *)
private struct SocialContinueSection: View {
    let namespace: Namespace.ID
    
    var body: some View {
        VStack(spacing: 24) {
            HStack {
                Rectangle().fill(Color.gray.opacity(0.2)).frame(height: 0.5)
                Text("or continue with")
                    .font(.system(size: 14))
                    .foregroundColor(.gray)
                    .padding(.horizontal, 12)
                Rectangle().fill(Color.gray.opacity(0.2)).frame(height: 0.5)
            }
            
            HStack(spacing: 20) {
                SocialIcon(icon: "github", namespace: namespace)
                SocialIcon(icon: "google", namespace: namespace)
                SocialIcon(icon: "apple.logo", namespace: namespace)
            }
        }
    }
}

@available(iOS 17.0, *)
private struct SocialIcon: View {
    let icon: String
    let namespace: Namespace.ID
    
    var iconURL: URL {
        let bundle = Bundle.main
        switch icon {
        case "github":
            return bundle.url(forResource: "github_logo", withExtension: "svg") ?? URL(string: "about:blank")!
        case "google":
            return bundle.url(forResource: "google_logo", withExtension: "svg") ?? URL(string: "about:blank")!
        case "apple.logo":
            return bundle.url(forResource: "apple_logo", withExtension: "svg") ?? URL(string: "about:blank")!
        default:
            return URL(string: "about:blank")!
        }
    }
    
    var body: some View {
        Button(action: {}) {
            SVGRemoteView(url: iconURL)
                .frame(width: 20, height: 20)
                .frame(width: 48, height: 48)
                .background(
                    Group {
                        if #available(iOS 26.0, *) {
                            EmptyView().glassEffect(.regular.interactive(), in: .circle)
                        } else {
                            Circle().fill(Color(white: 0.1))
                        }
                    }
                )
                .overlay(Circle().stroke(Color(white: 0.2), lineWidth: 0.5))
        }
        .buttonStyle(.plain)
    }
}

@available(iOS 17.0, *)
private struct FooterSection: View {
    var body: some View {
        HStack {
            Spacer()
            HStack(spacing: 4) {
                Text("No account?")
                    .foregroundColor(.gray)
                Button("Sign up") { }
                    .foregroundColor(.white)
                    .fontWeight(.semibold)
            }
            .font(.system(size: 14))
            Spacer()
        }
        .padding(.bottom, 32)
    }
}

#Preview {
    if #available(iOS 17.0, *) {
        EmailLoginView()
    }
}
