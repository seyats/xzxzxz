import SwiftUI

@available(iOS 17.0, *)
struct LoginView: View {
    @State private var showEmailLogin = false

    var body: some View {
        NavigationStack {
            ZStack {
                // Чёрный фон
                Color.black.ignoresSafeArea()

                VStack(spacing: 0) {
                    Spacer()
                        .frame(height: 60)

                    // Логотип - металлический чёрно-хромовый
                    ZStack {
                        // Внешний градиент для хрома
                        Circle()
                            .fill(
                                LinearGradient(
                                    gradient: Gradient(stops: [
                                        .init(color: Color(white: 0.3), location: 0),
                                        .init(color: Color(white: 0.8), location: 0.3),
                                        .init(color: Color(white: 0.2), location: 0.7),
                                        .init(color: Color(white: 0.5), location: 1)
                                    ]),
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 100, height: 100)

                        // Внутренний блеск
                        Circle()
                            .fill(
                                RadialGradient(
                                    gradient: Gradient(colors: [
                                        Color.white.opacity(0.4),
                                        Color.white.opacity(0.1),
                                        Color.clear
                                    ]),
                                    center: .init(x: 0.35, y: 0.35),
                                    radius: 0.6
                                )
                            )
                            .frame(width: 100, height: 100)

                        // Логотип "T" (Tide)
                        Text("T")
                            .font(.system(size: 48, weight: .bold, design: .default))
                            .foregroundColor(.black)
                    }
                    .shadow(color: Color.black.opacity(0.6), radius: 20, x: 0, y: 10)
                    .padding(.bottom, 32)

                    // Текст приветствия
                    VStack(spacing: 8) {
                        Text("Welcome back")
                            .font(.system(size: 32, weight: .bold, design: .default))
                            .foregroundColor(.white)

                        Text("Sign in to continue")
                            .font(.system(size: 14, weight: .regular, design: .default))
                            .foregroundColor(Color(white: 0.6))
                    }
                    .padding(.bottom, 40)

                    // Кнопки социальных сетей (54×54)
                    HStack(spacing: 16) {
                        Spacer()
                        SocialIconButton(icon: "github", size: 54)
                        SocialIconButton(icon: "g.circle.fill", size: 54) // Google placeholder
                        SocialIconButton(icon: "apple.logo", size: 54)
                        Spacer()
                    }
                    .padding(.bottom, 24)

                    // Разделитель "or"
                    Text("or")
                        .font(.system(size: 12, weight: .regular, design: .default))
                        .foregroundColor(Color(white: 0.5))
                        .padding(.bottom, 24)

                    // Компактные кнопки продолжения
                    VStack(spacing: 12) {
                        NavigationLink(destination: EmailLoginView()) {
                            CompactAuthButton(
                                icon: "envelope.fill",
                                text: "Continue with Email"
                            )
                        }

                        CompactAuthButton(
                            icon: "person.fill",
                            text: "Continue with Username"
                        )
                    }
                    .padding(.bottom, 40)

                    Spacer()

                    // Текст регистрации внизу
                    HStack(spacing: 4) {
                        Text("Don't have an account?")
                            .font(.system(size: 13, weight: .regular, design: .default))
                            .foregroundColor(Color(white: 0.6))

                        Button(action: {}) {
                            Text("Sign up")
                                .font(.system(size: 13, weight: .semibold, design: .default))
                                .foregroundColor(.white)
                        }
                    }
                    .padding(.bottom, 40)
                }
                .padding(.horizontal, 24)
            }
            .navigationBarHidden(true)
        }
    }
}

@available(iOS 17.0, *)
struct SocialIconButton: View {
    let icon: String
    let size: CGFloat

    var body: some View {
        Button(action: {}) {
            Image(systemName: icon)
                .font(.system(size: size * 0.4, weight: .semibold))
                .foregroundColor(.white)
                .frame(width: size, height: size)
                .background(
                    ZStack {
                        // Glassmorphism фон
                        RoundedRectangle(cornerRadius: size * 0.25)
                            .fill(Color(white: 0.15).opacity(0.5))

                        // Тонкая граница
                        RoundedRectangle(cornerRadius: size * 0.25)
                            .stroke(Color(white: 0.3).opacity(0.4), lineWidth: 0.5)
                    }
                )
                .shadow(color: Color.black.opacity(0.4), radius: 8, x: 0, y: 4)
        }
    }
}

@available(iOS 17.0, *)
struct CompactAuthButton: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.white)

            Text(text)
                .font(.system(size: 15, weight: .medium, design: .default))
                .foregroundColor(.white)

            Spacer()

            Image(systemName: "arrow.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(Color(white: 0.6))
        }
        .frame(height: 48)
        .padding(.horizontal, 16)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(white: 0.12).opacity(0.6))

                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color(white: 0.25).opacity(0.3), lineWidth: 0.5)
            }
        )
        .shadow(color: Color.black.opacity(0.3), radius: 6, x: 0, y: 3)
    }
}

@available(iOS 17.0, *)
#Preview {
    LoginView()
}
