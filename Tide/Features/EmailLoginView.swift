import SwiftUI

@available(iOS 17.0, *)
struct EmailLoginView: View {
    @Environment(\.dismiss) var dismiss
    @State private var email: String = ""
    @State private var password: String = ""
    @State private var showPassword: Bool = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {
                // Кнопка Back
                HStack {
                    Button(action: { dismiss() }) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                    }
                    Spacer()
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 16)

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 0) {
                        // Заголовок
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Welcome back")
                                .font(.system(size: 32, weight: .bold, design: .default))
                                .foregroundColor(.white)

                            Text("Sign in to continue")
                                .font(.system(size: 14, weight: .regular, design: .default))
                                .foregroundColor(Color(white: 0.6))
                        }
                        .padding(.bottom, 32)

                        // Email поле
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Email")
                                .font(.system(size: 13, weight: .semibold, design: .default))
                                .foregroundColor(.white)

                            HStack(spacing: 12) {
                                TextField("name@example.com", text: $email)
                                    .font(.system(size: 15, weight: .regular, design: .default))
                                    .foregroundColor(.white)
                                    .accentColor(.white)
                                    .keyboardType(.emailAddress)
                                    .autocapitalization(.none)
                                    .disableAutocorrection(true)

                                Image(systemName: "envelope.fill")
                                    .font(.system(size: 14, weight: .regular))
                                    .foregroundColor(Color(white: 0.5))
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
                        .padding(.bottom, 16)

                        // Password поле
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Password")
                                .font(.system(size: 13, weight: .semibold, design: .default))
                                .foregroundColor(.white)

                            HStack(spacing: 12) {
                                if showPassword {
                                    TextField("Password", text: $password)
                                        .font(.system(size: 15, weight: .regular, design: .default))
                                        .foregroundColor(.white)
                                        .accentColor(.white)
                                } else {
                                    SecureField("Password", text: $password)
                                        .font(.system(size: 15, weight: .regular, design: .default))
                                        .foregroundColor(.white)
                                        .accentColor(.white)
                                }

                                Button(action: { showPassword.toggle() }) {
                                    Image(systemName: showPassword ? "eye.fill" : "eye.slash.fill")
                                        .font(.system(size: 14, weight: .regular))
                                        .foregroundColor(Color(white: 0.5))
                                }
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
                        .padding(.bottom, 12)

                        // Forgot password ссылка
                        HStack {
                            Spacer()
                            Button(action: {}) {
                                Text("Forgot password?")
                                    .font(.system(size: 12, weight: .medium, design: .default))
                                    .foregroundColor(Color(white: 0.6))
                            }
                        }
                        .padding(.bottom, 32)

                        // Кнопка Sign in
                        Button(action: {}) {
                            HStack(spacing: 8) {
                                Text("Sign in")
                                    .font(.system(size: 15, weight: .semibold, design: .default))
                                    .foregroundColor(.white)

                                Image(systemName: "arrow.right")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(.white)
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 48)
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
                        .padding(.bottom, 28)

                        // Разделитель
                        HStack(spacing: 12) {
                            Rectangle()
                                .frame(height: 0.5)
                                .foregroundColor(Color(white: 0.25).opacity(0.5))

                            Text("or continue with")
                                .font(.system(size: 12, weight: .regular, design: .default))
                                .foregroundColor(Color(white: 0.5))

                            Rectangle()
                                .frame(height: 0.5)
                                .foregroundColor(Color(white: 0.25).opacity(0.5))
                        }
                        .padding(.bottom, 28)

                        // Социальные кнопки (круглые, маленькие)
                        HStack(spacing: 16) {
                            Spacer()
                            SocialIconButton(icon: "github", size: 44)
                            SocialIconButton(icon: "g.circle.fill", size: 44)
                            SocialIconButton(icon: "apple.logo", size: 44)
                            Spacer()
                        }
                        .padding(.bottom, 40)

                        // Текст регистрации
                        HStack(spacing: 4) {
                            Text("No account?")
                                .font(.system(size: 13, weight: .regular, design: .default))
                                .foregroundColor(Color(white: 0.6))

                            Button(action: {}) {
                                Text("Sign up")
                                    .font(.system(size: 13, weight: .semibold, design: .default))
                                    .foregroundColor(.white)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.bottom, 40)
                    }
                    .padding(.horizontal, 24)
                }
            }
        }
        .navigationBarHidden(true)
    }
}

@available(iOS 17.0, *)
#Preview {
    EmailLoginView()
}
