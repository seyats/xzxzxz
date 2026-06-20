import SwiftUI

/// Экран входа по Email в стиле Apple 2026 с автодополнением доменов.
@available(iOS 17.0, *)
struct EmailLoginView: View {
    @Environment(AppDependencies.self) private var dependencies
    @Environment(\.dismiss) private var dismiss
    
    @State private var email = ""
    @State private var password = ""
    @State private var displayName = ""
    @State private var isPasswordVisible = false
    @State private var isSignUp = false
    @State private var showEmailSuggestions = false
    @Namespace private var glassNamespace
    
    var emailSuggestions: [String] {
        EmailSuggestions.suggestions(for: email)
    }
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            VStack(spacing: 0) {
                HeaderSection(dismiss: dismiss)
                    .padding(.bottom, 40)
                
                if isSignUp {
                    DisplayNameField(displayName: $displayName)
                        .padding(.bottom, 20)
                }
                
                EmailInputSection(email: $email, suggestions: emailSuggestions, onSelectSuggestion: { suggestion in
                    email = suggestion
                    showEmailSuggestions = false
                })
                    .padding(.bottom, 24)
                
                InputField(title: "Password", text: $password, icon: "lock", isSecure: true, isVisible: $isPasswordVisible)
                    .padding(.bottom, 24)
                
                if !isSignUp {
                    ForgotPasswordSection()
                        .padding(.bottom, 40)
                }
                
                SignInButtonSection(
                    action: handleSignIn,
                    isLoading: dependencies.session.isWorking,
                    title: isSignUp ? "Create Account" : "Sign in"
                )
                    .padding(.bottom, 48)
                
                if let error = dependencies.session.errorMessage {
                    ErrorMessageSection(message: error)
                        .padding(.bottom, 24)
                }
                
                SocialSection(namespace: glassNamespace)
                
                Spacer()
                
                FooterSection(isSignUp: isSignUp, action: { isSignUp.toggle() })
            }
            .padding(.horizontal, 28)
        }
        .navigationBarHidden(true)
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

@available(iOS 17.0, *)
private struct HeaderSection: View {
    let dismiss: DismissAction
    
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            Button(action: { dismiss() }) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.white)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Welcome back")
                    .font(TideTypography.display)
                    .foregroundColor(.white)
                
                Text("Sign in to continue")
                    .font(.system(size: 16, weight: .regular))
                    .foregroundColor(.gray)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 20)
    }
}

@available(iOS 17.0, *)
private struct DisplayNameField: View {
    @Binding var displayName: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Display Name")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.gray)
            
            TextField("John Doe", text: $displayName)
                .foregroundColor(.white)
                .padding(.horizontal, 16)
                .frame(height: 56)
                .background(Color(white: 0.05))
                .cornerRadius(12)
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(white: 0.15), lineWidth: 1))
        }
    }
}

@available(iOS 17.0, *)
private struct EmailInputSection: View {
    @Binding var email: String
    let suggestions: [String]
    let onSelectSuggestion: (String) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Email")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.gray)
            
            VStack(spacing: 0) {
                TextField("name@example.com", text: $email)
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .frame(height: 56)
                    .background(Color(white: 0.05))
                    .cornerRadius(12)
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(white: 0.15), lineWidth: 1))
                
                if !suggestions.isEmpty {
                    VStack(spacing: 8) {
                        Divider().background(Color(white: 0.15))
                        
                        ForEach(suggestions, id: \.self) { suggestion in
                            Button(action: { onSelectSuggestion(suggestion) }) {
                                HStack {
                                    Image(systemName: "envelope")
                                        .foregroundColor(.gray)
                                    Text(suggestion)
                                        .foregroundColor(.white)
                                    Spacer()
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)
                            }
                        }
                    }
                    .background(Color(white: 0.08))
                    .cornerRadius(12)
                    .padding(.top, 8)
                }
            }
        }
    }
}

@available(iOS 17.0, *)
private struct InputField: View {
    let title: String
    @Binding var text: String
    let icon: String
    let isSecure: Bool
    @Binding var isVisible: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.gray)
            
            HStack {
                if isSecure && !isVisible {
                    SecureField("••••••••", text: $text)
                } else {
                    TextField("••••••••", text: $text)
                }
                
                Spacer()
                
                if isSecure {
                    Button(action: { isVisible.toggle() }) {
                        Image(systemName: isVisible ? "eye.slash" : "eye")
                            .foregroundColor(.gray)
                    }
                } else {
                    Image(systemName: icon)
                        .foregroundColor(.gray)
                }
            }
            .foregroundColor(.white)
            .padding(.horizontal, 16)
            .frame(height: 56)
            .background(Color(white: 0.05))
            .cornerRadius(12)
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(white: 0.15), lineWidth: 1))
        }
    }
}

@available(iOS 17.0, *)
private struct ForgotPasswordSection: View {
    var body: some View {
        HStack {
            Spacer()
            Button("Forgot password?") { }
                .font(.system(size: 14))
                .foregroundColor(.gray)
        }
    }
}

@available(iOS 17.0, *)
private struct SignInButtonSection: View {
    let action: () -> Void
    let isLoading: Bool
    let title: String
    
    var body: some View {
        Button(action: action) {
            HStack {
                if isLoading {
                    ProgressView()
                        .tint(.black)
                } else {
                    Text(title)
                        .font(.system(size: 16, weight: .semibold))
                }
                Spacer()
                if !isLoading {
                    Image(systemName: "arrow.right")
                }
            }
            .foregroundColor(.black)
            .padding(.horizontal, 24)
            .frame(height: 52)
            .background(Color.white)
            .cornerRadius(12)
        }
        .disabled(isLoading)
    }
}

@available(iOS 17.0, *)
private struct ErrorMessageSection: View {
    let message: String
    
    var body: some View {
        HStack {
            Image(systemName: "exclamationmark.circle.fill")
                .foregroundColor(.red)
            Text(message)
                .font(.system(size: 13))
                .foregroundColor(.red)
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.red.opacity(0.1))
        .cornerRadius(8)
    }
}

@available(iOS 17.0, *)
private struct SocialSection: View {
    let namespace: Namespace.ID
    
    var body: some View {
        VStack(spacing: 24) {
            HStack {
                Rectangle().fill(Color(white: 0.15)).frame(height: 0.5)
                Text("or continue with").font(.system(size: 14)).foregroundColor(.gray).padding(.horizontal, 8)
                Rectangle().fill(Color(white: 0.15)).frame(height: 0.5)
            }
            
            HStack(spacing: 20) {
                SocialCircleButton(icon: .github)
                SocialCircleButton(icon: .google)
                SocialCircleButton(icon: .apple)
            }
        }
    }
}

// SocialBrand is defined in LoginView.swift

@available(iOS 17.0, *)
private struct SocialCircleButton: View {
    let icon: SocialBrand
    
    var body: some View {
        Button(action: {}) {
            BrandIcon(brand: icon)
                .frame(width: 24, height: 24)
                .frame(width: 54, height: 54)
                .background(Color(white: 0.1))
                .clipShape(Circle())
                .overlay(Circle().stroke(Color(white: 0.2), lineWidth: 0.5))
        }
    }
}

@available(iOS 17.0, *)
private struct BrandIcon: View {
    let brand: SocialBrand
    
    var body: some View {
        Group {
            switch brand {
            case .google:
                SVGRemoteView(url: Bundle.main.url(forResource: "google", withExtension: "svg")!)
            case .github:
                SVGRemoteView(url: Bundle.main.url(forResource: "github", withExtension: "svg")!)
            case .apple:
                SVGRemoteView(url: Bundle.main.url(forResource: "apple", withExtension: "svg")!)
            }
        }
    }
}

@available(iOS 17.0, *)
private struct FooterSection: View {
    let isSignUp: Bool
    let action: () -> Void
    
    var body: some View {
        HStack(spacing: 4) {
            Text(isSignUp ? "Already have an account?" : "No account?")
                .foregroundColor(.gray)
            Button(isSignUp ? "Sign in" : "Sign up", action: action)
                .foregroundColor(.white)
                .fontWeight(.semibold)
        }
        .font(.system(size: 14))
        .padding(.bottom, 32)
    }
}
