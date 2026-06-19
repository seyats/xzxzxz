import SwiftUI

/// Первый экран авторизации в стиле Apple 2026.
/// Использует стандарты ios-dev-plugin: Liquid Glass UI и декомпозицию View.
@available(iOS 17.0, *)
struct LoginView: View {
    // MARK: - Environment
    @Environment(AppDependencies.self) private var dependencies
    
    // MARK: - State
    @Namespace private var glassNamespace
    
    // MARK: - Body
    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    Spacer()
                    
                    HeaderSection()
                        .padding(.bottom, 48)
                    
                    SocialAuthSection(namespace: glassNamespace)
                        .padding(.bottom, 32)
                    
                    DividerSection()
                        .padding(.bottom, 32)
                    
                    ActionButtonsSection()
                        .padding(.bottom, 64)
                    
                    Spacer()
                    
                    FooterSection()
                }
                .padding(.horizontal, 28)
            }
            .navigationBarHidden(true)
        }
    }
}

// MARK: - Subviews

@available(iOS 17.0, *)
private struct HeaderSection: View {
    var body: some View {
        VStack(spacing: 24) {
            // Официальный логотип TideIcon
            Image("TideIcon")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 120, height: 120)
                .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                .shadow(color: .white.opacity(0.1), radius: 20, x: 0, y: 10)
            
            VStack(spacing: 8) {
                Text("Welcome back")
                    .font(.system(size: 34, weight: .bold, design: .default))
                    .foregroundColor(.white)
                
                Text("Sign in to continue")
                    .font(.system(size: 16, weight: .regular, design: .default))
                    .foregroundColor(.gray)
            }
        }
    }
}

@available(iOS 17.0, *)
private struct SocialAuthSection: View {
    let namespace: Namespace.ID
    
    var body: some View {
        Group {
            if #available(iOS 26.0, *) {
                GlassEffectContainer(spacing: 16) {
                    HStack(spacing: 16) {
                        SocialButton(icon: .github, namespace: namespace)
                        SocialButton(icon: .google, namespace: namespace)
                        SocialButton(icon: .apple, namespace: namespace)
                    }
                }
            } else {
                HStack(spacing: 16) {
                    SocialButtonFallback(icon: .github)
                    SocialButtonFallback(icon: .google)
                    SocialButtonFallback(icon: .apple)
                }
            }
        }
    }
}

enum SocialBrand {
    case google, github, apple
}

@available(iOS 17.0, *)
private struct SocialButton: View {
    let icon: SocialBrand
    let namespace: Namespace.ID
    
    var body: some View {
        Button(action: {}) {
            BrandIcon(brand: icon)
                .frame(width: 24, height: 24)
                .frame(width: 54, height: 54)
        }
        .buttonStyle(.plain)
        .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 14))
        .glassEffectID("\(icon)", in: namespace)
    }
}

@available(iOS 17.0, *)
private struct SocialButtonFallback: View {
    let icon: SocialBrand
    
    var body: some View {
        Button(action: {}) {
            BrandIcon(brand: icon)
                .frame(width: 24, height: 24)
                .frame(width: 54, height: 54)
                .background(Color(white: 0.1).opacity(0.8))
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Color(white: 0.2), lineWidth: 0.5)
                )
        }
    }
}

@available(iOS 17.0, *)
private struct BrandIcon: View {
    let brand: SocialBrand
    
    var body: some View {
        switch brand {
        case .google:
            // Google Logo (G)
            ZStack {
                Circle().fill(.white).frame(width: 24, height: 24)
                Image(systemName: "g.circle.fill")
                    .resizable()
                    .foregroundColor(.blue)
            }
        case .github:
            Image(systemName: "github.logo") // Fallback to SF Symbols if SVG fails, but let's use a custom shape
                .resizable()
                .foregroundColor(.white)
        case .apple:
            Image(systemName: "apple.logo")
                .resizable()
                .foregroundColor(.white)
        }
    }
}

@available(iOS 17.0, *)
private struct DividerSection: View {
    var body: some View {
        HStack {
            Rectangle()
                .fill(Color.gray.opacity(0.2))
                .frame(height: 0.5)
            Text("or")
                .font(.system(size: 14))
                .foregroundColor(.gray)
                .padding(.horizontal, 12)
            Rectangle()
                .fill(Color.gray.opacity(0.2))
                .frame(height: 0.5)
        }
    }
}

@available(iOS 17.0, *)
private struct ActionButtonsSection: View {
    var body: some View {
        VStack(spacing: 12) {
            NavigationLink(destination: EmailLoginView()) {
                CompactButton(text: "Continue with Email", icon: "envelope.fill")
            }
            
            CompactButton(text: "Continue with Username", icon: "person.fill")
        }
    }
}

@available(iOS 17.0, *)
private struct CompactButton: View {
    let text: String
    let icon: String
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .font(.system(size: 14))
            Text(text)
                .font(.system(size: 15, weight: .medium))
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .opacity(0.5)
        }
        .foregroundColor(.white)
        .padding(.horizontal, 20)
        .frame(height: 52)
        .background(
            Group {
                if #available(iOS 26.0, *) {
                    EmptyView().glassEffect(.regular.interactive(), in: .rect(cornerRadius: 12))
                } else {
                    Color(white: 0.1).opacity(0.8).clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(white: 0.2), lineWidth: 0.5)
        )
    }
}

@available(iOS 17.0, *)
private struct FooterSection: View {
    var body: some View {
        HStack(spacing: 4) {
            Text("Don't have an account?")
                .foregroundColor(.gray)
            Button("Sign up") { }
                .foregroundColor(.white)
                .fontWeight(.semibold)
        }
        .font(.system(size: 14))
        .padding(.bottom, 32)
    }
}
