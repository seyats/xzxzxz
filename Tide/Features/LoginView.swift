import SwiftUI

@available(iOS 17.0, *)
struct LoginView: View {
    @Namespace private var glassNamespace

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                VStack(spacing: 0) {
                    Spacer()

                    HeaderSection()
                        .padding(.bottom, 44)

                    SocialAuthSection(namespace: glassNamespace)
                        .padding(.bottom, 28)

                    DividerSection()
                        .padding(.bottom, 28)

                    ActionButtonsSection()
                        .padding(.bottom, 56)

                    Spacer()

                    FooterSection()
                }
                .padding(.horizontal, 28)
            }
            .navigationBarHidden(true)
        }
    }
}

enum SocialBrand: String, CaseIterable {
    case google, github, apple
}

@available(iOS 17.0, *)
private struct HeaderSection: View {
    var body: some View {
        VStack(spacing: 22) {
            Image("TideBubbleLogo")
                .renderingMode(.original)
                .resizable()
                .scaledToFit()
                .frame(width: 92, height: 92)
                .padding(8)
                .background(.white.opacity(0.08), in: Circle())
                .clipShape(Circle())
                .shadow(color: .white.opacity(0.18), radius: 20, y: 8)

            VStack(spacing: 8) {
                Text("Начать беседу")
                    .font(.system(size: 34, weight: .black, design: .rounded))
                    .foregroundColor(.white)

                Text("Войдите, чтобы продолжить")
                    .font(.system(size: 16, weight: .regular))
                    .foregroundColor(.gray)
            }
        }
    }
}

@available(iOS 17.0, *)
private struct SocialAuthSection: View {
    let namespace: Namespace.ID

    var body: some View {
        HStack(spacing: 16) {
            SocialButton(icon: .google, namespace: namespace)
            SocialButton(icon: .apple, namespace: namespace)
            SocialButton(icon: .github, namespace: namespace)
        }
    }
}

@available(iOS 17.0, *)
private struct SocialButton: View {
    let icon: SocialBrand
    let namespace: Namespace.ID

    var body: some View {
        Button(action: {}) {
            BrandIcon(brand: icon)
                .frame(width: 25, height: 25)
                .frame(width: 54, height: 54)
        }
        .buttonStyle(AuthSmoothButtonStyle())
        .tideGlass(interactive: true, cornerRadius: 18)
    }
}

@available(iOS 17.0, *)
private struct BrandIcon: View {
    let brand: SocialBrand

    var body: some View {
        if brand == .apple {
            Image(systemName: "apple.logo")
                .font(.system(size: 25, weight: .semibold))
                .foregroundStyle(.white)
        } else {
            Image(imageName)
                .renderingMode(.original)
                .resizable()
                .scaledToFit()
        }
    }

    private var imageName: String {
        switch brand {
        case .google: return "GoogleLogo"
        case .github: return "GitHubLogo"
        case .apple: return "AppleLogo"
        }
    }
}

@available(iOS 17.0, *)
private struct DividerSection: View {
    var body: some View {
        HStack {
            Rectangle()
                .fill(Color.gray.opacity(0.22))
                .frame(height: 0.5)
            Text("или")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.gray)
                .padding(.horizontal, 12)
            Rectangle()
                .fill(Color.gray.opacity(0.22))
                .frame(height: 0.5)
        }
    }
}

@available(iOS 17.0, *)
private struct ActionButtonsSection: View {
    var body: some View {
        VStack(spacing: 12) {
            NavigationLink(destination: EmailLoginView()) {
                CompactButton(text: "Продолжить с эл. почтой", icon: "envelope.fill")
            }

            CompactButton(text: "Войти с именем пользователя", icon: "person.fill")
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
        .padding(.horizontal, 18)
        .frame(height: 50)
        .background(Color(white: 0.1).opacity(0.8))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color(white: 0.22), lineWidth: 0.6)
        )
    }
}

@available(iOS 17.0, *)
private struct FooterSection: View {
    var body: some View {
        HStack(spacing: 4) {
            Text("Нет аккаунта?")
                .foregroundColor(.gray)
            Button("Регистрация") { }
                .foregroundColor(.white)
                .fontWeight(.semibold)
        }
        .font(.system(size: 14))
        .padding(.bottom, 32)
    }
}
