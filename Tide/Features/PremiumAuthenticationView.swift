import AuthenticationServices
import SwiftUI

struct PremiumAuthenticationView: View {
    @Environment(AppDependencies.self) private var dependencies
    @FocusState private var focusedField: Field?
    @State private var stage: AuthStage = .landing
    @State private var identifier = ""
    @State private var usernamePassword = ""
    @State private var usernamePasswordVisible = false
    @State private var email = ""
    @State private var isLoading = false
    @State private var alertMessage: String?
    @State private var showProviderSheet = false

    private enum AuthStage { case landing, username, email }
    private enum Field { case identifier, usernamePassword, email }

    var body: some View {
        ZStack {
            AuthBlackBackdrop()

            Group {
                switch stage {
                case .landing: landingScreen
                case .username: usernameScreen
                case .email: emailScreen
                }
            }
            .padding(.horizontal, 28)
            .animation(.easeInOut(duration: 0.58), value: stage)
        }
        .preferredColorScheme(.dark)
        .ignoresSafeArea()
        .alert("Вход", isPresented: Binding(get: { alertMessage != nil }, set: { if !$0 { alertMessage = nil } })) {
            Button("ОК", role: .cancel) {}
        } message: {
            Text(alertMessage ?? "")
        }
        .sheet(isPresented: $showProviderSheet) {
            providerSheet
                .presentationDetents([.height(420)])
                .presentationDragIndicator(.visible)
                .presentationBackground(.black)
                .preferredColorScheme(.dark)
        }
    }

    private var landingScreen: some View {
        VStack(spacing: 0) {
            topBackButton
                .opacity(0.9)
                .padding(.top, 56)

            Spacer(minLength: 190)

            AuthChromeLogo(size: 96)
                .padding(.bottom, 26)

            Text("Создать аккаунт")
                .font(.system(size: 39, weight: .black, design: .rounded))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.82)
                .multilineTextAlignment(.center)

            Spacer(minLength: 126)

            HStack(spacing: 28) {
                AuthSocialGlassButton(kind: .google, imageName: "GoogleLogo", shape: .circle) {
                    withAnimation(.easeInOut(duration: 0.42)) {
                        showProviderSheet = true
                    }
                }
                AppleAuthGlassButton(shape: .circle) { result in
                    handleAppleSignIn(result)
                }
                AuthCircleIconButton(systemImage: "envelope") { showEmail() }
            }

            AuthDivider(title: "или")
                .padding(.top, 28)

            Button {
                setPlaceholder("Вход по телефону пока работает как заглушка.")
            } label: {
                HStack(spacing: 14) {
                    Image(systemName: "phone")
                        .font(.system(size: 20, weight: .heavy))
                    Text("Создать аккаунт по номеру телефона")
                        .font(.system(size: 19, weight: .black, design: .rounded))
                        .lineLimit(2)
                        .minimumScaleFactor(0.82)
                        .multilineTextAlignment(.leading)
                }
                .foregroundStyle(.black)
                .frame(maxWidth: .infinity)
                .frame(height: 66)
                .padding(.horizontal, 8)
                .background(.white, in: Capsule())
            }
            .padding(.top, 22)

            Text("Продолжая, ты соглашаешься с нашими\nУсловиями, Политикой конфиденциальности и\nПолитикой использования файлов cookie.")
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundStyle(.white.opacity(0.42))
                .multilineTextAlignment(.center)
                .lineSpacing(3)
                .padding(.top, 24)

            Button { showUsername() } label: {
                Text("Войти с именем пользователя")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.44))
            }
            .padding(.top, 18)
            .padding(.bottom, 22)
        }
    }

    private var usernameScreen: some View {
        VStack(spacing: 0) {
            authTopBar(trailing: "Утеряно имя пользователя")
                .padding(.top, 56)

            VStack(alignment: .leading, spacing: 32) {
                Text("Введи имя\nпользователя")
                    .font(.system(size: 38, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                    .lineSpacing(7)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    Text("@")
                        .font(.system(size: 42, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                    TextField("имя пользователя", text: $identifier)
                        .font(.system(size: 34, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                        .tint(.white)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .focused($focusedField, equals: .identifier)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    Image(systemName: "lock")
                        .font(.system(size: 30, weight: .black))
                        .foregroundStyle(.white)
                    Group {
                        if usernamePasswordVisible {
                            TextField("Пароль", text: $usernamePassword)
                        } else {
                            SecureField("Пароль", text: $usernamePassword)
                        }
                    }
                    .font(.system(size: 30, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                    .tint(.white)
                    .focused($focusedField, equals: .usernamePassword)

                    Button {
                        usernamePasswordVisible.toggle()
                    } label: {
                        Image(systemName: usernamePasswordVisible ? "eye.slash" : "eye")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundStyle(.white.opacity(0.56))
                    }
                    .buttonStyle(AuthSmoothButtonStyle())
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 76)

            Spacer()

            primaryAuthButton(title: "Продолжить", enabled: canContinueUsername, action: submitUsername)
                .padding(.bottom, 42)
        }
    }

    private var emailScreen: some View {
        VStack(spacing: 0) {
            authTopBar(trailing: "Указать номер телефона")
                .padding(.top, 56)

            VStack(alignment: .leading, spacing: 20) {
                Text("Укажите свой\nадрес эл. почты")
                    .font(.system(size: 38, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                    .lineSpacing(7)
                Text("Мы отправим тебе код подтверждения")
                    .font(.system(size: 20, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white.opacity(0.42))
                TextField("почта@пример.ру", text: $email)
                    .font(.system(size: 33, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                    .tint(.white)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .focused($focusedField, equals: .email)
                    .padding(.top, 12)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 76)

            Spacer()

            primaryAuthButton(title: "Продолжить", enabled: canContinueEmail, action: submitEmail)

            Text("Продолжая, ты соглашаешься получать\nслужебные уведомления об аккаунте.")
                .font(.system(size: 18, weight: .heavy, design: .rounded))
                .foregroundStyle(.white.opacity(0.42))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 22)
                .padding(.bottom, 42)
        }
    }

    private var providerSheet: some View {
        VStack(spacing: 18) {
            Text("Войди в свою учётную запись")
                .font(.system(size: 24, weight: .black, design: .rounded))
                .foregroundStyle(.white)
                .padding(.top, 28)

            AuthProviderPill(imageName: "GoogleLogo", title: "Продолжить с Google") {
                setPlaceholder("Вход через Google пока работает как заглушка.")
            }
            AuthProviderPill(systemImage: "apple.logo", title: "Продолжить с Apple") {
                showProviderSheet = false
                alertMessage = "Нажми кнопку Apple на главном экране."
            }
            AuthProviderPill(systemImage: "envelope", title: "Продолжить с электронной почтой") {
                showProviderSheet = false
                showEmail()
            }
            AuthProviderPill(systemImage: "phone", title: "Продолжить с телефоном") {
                setPlaceholder("Вход по телефону пока работает как заглушка.")
            }

            Spacer()
        }
        .padding(.horizontal, 34)
        .background(Color.black.ignoresSafeArea())
    }

    private var topBackButton: some View {
        HStack {
            Button {
                setPlaceholder("Вернуться назад сейчас некуда.")
            } label: {
                Image(systemName: "arrow.left")
                    .font(.system(size: 31, weight: .bold))
                    .foregroundStyle(.white)
            }
            Spacer()
        }
    }

    private func authTopBar(trailing: String) -> some View {
        HStack(alignment: .top) {
            Button {
                withAnimation(.easeInOut(duration: 0.58)) { stage = .landing }
            } label: {
                Image(systemName: "arrow.left")
                    .font(.system(size: 31, weight: .bold))
                    .foregroundStyle(.white)
            }

            Spacer()

            Button {
                setPlaceholder("Восстановление аккаунта появится позже.")
            } label: {
                Text(trailing)
                    .font(.system(size: 18, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.trailing)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
            }
        }
    }

    private func primaryAuthButton(title: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 23, weight: .black, design: .rounded))
                .foregroundStyle(enabled ? .black : .white.opacity(0.34))
                .frame(maxWidth: .infinity)
                .frame(height: 64)
                .background(enabled ? .white : .white.opacity(0.14), in: Capsule())
        }
        .disabled(!enabled || isLoading)
        .buttonStyle(AuthSmoothButtonStyle())
    }

    private var canContinueUsername: Bool {
        !identifier.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && usernamePassword.trimmingCharacters(in: .whitespacesAndNewlines).count >= 8
    }

    private var canContinueEmail: Bool {
        email.contains("@") && email.contains(".")
    }

    private func showUsername() {
        withAnimation(.easeInOut(duration: 0.58)) { stage = .username }
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(180))
            focusedField = .identifier
        }
    }

    private func showEmail() {
        withAnimation(.easeInOut(duration: 0.58)) { stage = .email }
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(180))
            focusedField = .email
        }
    }

    private func submitUsername() {
        guard canContinueUsername else { return }
        Task {
            isLoading = true
            defer { isLoading = false }
            await dependencies.session.signInIdentifier(identifier, password: usernamePassword)
        }
    }

    private func submitEmail() {
        guard canContinueEmail else { return }
        Task {
            isLoading = true
            defer { isLoading = false }
            await dependencies.session.signInEmail(email: email, password: "TidePreview2026", createsAccount: true)
        }
    }

    private func setPlaceholder(_ message: String) {
        alertMessage = message
    }

    private func handleAppleSignIn(_ result: Result<ASAuthorization, Error>) {
        Task {
            switch result {
            case .success(let authorization):
                guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else {
                    alertMessage = "Apple не вернул данные аккаунта."
                    return
                }
                let fallbackEmail = credential.email ?? "\(credential.user)@apple.local"
                let name = [credential.fullName?.givenName, credential.fullName?.familyName].compactMap { $0 }.joined(separator: " ")
                await dependencies.session.signInApple(
                    userIdentifier: credential.user,
                    email: fallbackEmail,
                    displayName: name.isEmpty ? nil : name
                )
            case .failure(let error):
                alertMessage = error.localizedDescription
            }
        }
    }
}

struct AuthProfileSetupView: View {
    @Environment(AppDependencies.self) private var dependencies
    @FocusState private var focusedField: OnboardingField?
    @State private var step: OnboardingStep = .name
    @State private var fullName = ""
    @State private var birthday = Calendar.current.date(from: DateComponents(year: 1993, month: 6, day: 22)) ?? .now
    @State private var username = ""
    @State private var password = ""
    @State private var passwordVisible = false
    @State private var showFindFriends = false
    @State private var userEditedUsername = false

    private enum OnboardingStep { case name, birthday, username, password }
    private enum OnboardingField { case name, username, password }

    var body: some View {
        ZStack {
            AuthBlackBackdrop()

            VStack(spacing: 0) {
                if step != .name {
                    onboardingBackButton
                        .padding(.top, 56)
                }

                switch step {
                case .name: nameStep
                case .birthday: birthdayStep
                case .username: usernameStep
                case .password: passwordStep
                }
            }
            .padding(.horizontal, 28)
        }
        .preferredColorScheme(.dark)
        .ignoresSafeArea()
        .sheet(isPresented: $showFindFriends) {
            FindFriendsSheet(
                skip: {
                    showFindFriends = false
                    advanceToUsername()
                },
                allow: {
                    showFindFriends = false
                    advanceToUsername()
                }
            )
            .presentationDetents([.height(560)])
            .presentationDragIndicator(.visible)
            .presentationBackground(.black)
            .preferredColorScheme(.dark)
        }
        .onAppear {
            fullName = dependencies.session.currentUser?.name ?? ""
            username = generatedUsernames.first ?? ""
            focusedField = .name
        }
        .onChange(of: fullName) { _, _ in refreshGeneratedUsername() }
    }

    private var nameStep: some View {
        VStack(alignment: .leading, spacing: 0) {
            onboardingBackButton
                .padding(.top, 56)

            Spacer(minLength: 186)

            Text("Как тебя зовут?")
                .font(.system(size: 40, weight: .black, design: .rounded))
                .foregroundStyle(.white)
                .padding(.bottom, 34)

            ZStack(alignment: .leading) {
                if fullName.isEmpty {
                    Text("Имя и фамилия")
                        .font(.system(size: 34, weight: .black, design: .rounded))
                        .foregroundStyle(.white.opacity(0.22))
                }
                TextField("", text: $fullName)
                    .font(.system(size: 34, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                    .tint(.white)
                    .textInputAutocapitalization(.words)
                    .autocorrectionDisabled()
                    .focused($focusedField, equals: .name)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(height: 52)
            .padding(.bottom, 20)

            if !canContinueName {
                HStack(spacing: 10) {
                    Image(systemName: "xmark")
                        .font(.system(size: 16, weight: .bold))
                    Text("Заполните обязательные поля")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                }
                .foregroundStyle(TidePalette.danger)
                .padding(.bottom, 46)
            } else {
                Spacer(minLength: 26)
            }

            primaryWideButton(title: "Продолжить", enabled: canContinueName) {
                withAnimation(.easeInOut(duration: 0.58)) {
                    step = .birthday
                    focusedField = nil
                }
            }

            Spacer()

            Text("аккаунт верифицирован")
                .font(.system(size: 14, weight: .heavy, design: .rounded))
                .foregroundStyle(.white.opacity(0.42))
                .padding(.bottom, 34)
        }
    }

    private var birthdayStep: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 24) {
                Text("Когда у тебя день\nрождения?")
                    .font(.system(size: 39, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                    .lineSpacing(6)
                Text("Дата твоего рождения останется строго\nмежду нами")
                    .font(.system(size: 20, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white.opacity(0.42))
            }
            .padding(.top, 74)

            Spacer()

            DatePicker("Дата рождения", selection: $birthday, displayedComponents: .date)
                .datePickerStyle(.wheel)
                .labelsHidden()
                .colorScheme(.dark)
                .frame(maxWidth: .infinity)
                .clipped()
                .padding(.bottom, 28)

            primaryWideButton(title: "Продолжить", enabled: true) {
                showFindFriends = true
            }
            .padding(.bottom, 42)
        }
    }

    private var usernameStep: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Придумайте имя\nпользователя")
                .font(.system(size: 39, weight: .black, design: .rounded))
                .foregroundStyle(.white)
                .lineSpacing(6)
                .padding(.top, 74)

            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text("@")
                    .font(.system(size: 42, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                TextField("Имя пользователя", text: Binding(
                    get: { username },
                    set: {
                        username = $0
                        userEditedUsername = true
                    }
                ))
                .font(.system(size: 34, weight: .black, design: .rounded))
                .foregroundStyle(.white)
                .tint(.white)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .focused($focusedField, equals: .username)
            }
            .padding(.top, 42)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(generatedUsernames, id: \.self) { suggestion in
                        Button {
                            username = suggestion
                            userEditedUsername = true
                        } label: {
                            Text(suggestion)
                                .font(.system(size: 15, weight: .black, design: .rounded))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 18)
                                .frame(height: 38)
                                .tideGlass(interactive: true, cornerRadius: 19)
                        }
                    }
                }
            }
            .padding(.top, 18)

            Spacer()

            primaryWideButton(title: "Продолжить", enabled: canContinueUsername) {
                withAnimation(.easeInOut(duration: 0.58)) {
                    step = .password
                    focusedField = .password
                }
            }
            .padding(.bottom, 42)
        }
    }

    private var passwordStep: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Выбери пароль")
                .font(.system(size: 42, weight: .black, design: .rounded))
                .foregroundStyle(.white)
                .padding(.top, 74)

            Text("Пароли должны быть сложными для\nугадывания и содержать не менее 8\nсимволов")
                .font(.system(size: 20, weight: .heavy, design: .rounded))
                .foregroundStyle(.white.opacity(0.42))
                .padding(.top, 28)

            HStack(spacing: 12) {
                Group {
                    if passwordVisible {
                        TextField("Пароль", text: $password)
                    } else {
                        SecureField("Пароль", text: $password)
                    }
                }
                .font(.system(size: 34, weight: .black, design: .rounded))
                .foregroundStyle(.white)
                .tint(.white)
                .focused($focusedField, equals: .password)

                Button { passwordVisible.toggle() } label: {
                    Image(systemName: passwordVisible ? "eye.slash" : "eye")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundStyle(.white.opacity(0.62))
                }
            }
            .padding(.top, 72)

            Spacer()

            primaryWideButton(title: "Продолжить", enabled: canContinuePassword) {
                completeSetup()
            }
            .padding(.bottom, 42)
        }
    }

    private var onboardingBackButton: some View {
        HStack {
            Button {
                withAnimation(.easeInOut(duration: 0.58)) {
                    switch step {
                    case .name: break
                    case .birthday: step = .name
                    case .username: step = .birthday
                    case .password: step = .username
                    }
                }
            } label: {
                Image(systemName: "arrow.left")
                    .font(.system(size: 31, weight: .bold))
                    .foregroundStyle(.white)
            }
            Spacer()
        }
    }

    private func compactContinueButton(enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text("Продолжить")
                .font(.system(size: 18, weight: .black, design: .rounded))
                .foregroundStyle(.black)
                .frame(width: 188, height: 58)
                .background(.white, in: Capsule())
                .shadow(color: enabled ? .white.opacity(0.22) : .clear, radius: 22, y: 8)
        }
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.38)
        .frame(maxWidth: .infinity)
        .buttonStyle(AuthSmoothButtonStyle())
    }

    private func primaryWideButton(title: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 23, weight: .black, design: .rounded))
                .foregroundStyle(enabled ? .black : .white.opacity(0.34))
                .frame(maxWidth: .infinity)
                .frame(height: 64)
                .background(enabled ? .white : .white.opacity(0.14), in: Capsule())
        }
        .disabled(!enabled)
        .buttonStyle(AuthSmoothButtonStyle())
    }

    private var canContinueName: Bool {
        !fullName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var canContinueUsername: Bool {
        username.trimmingCharacters(in: .whitespacesAndNewlines).count >= 3
    }

    private var canContinuePassword: Bool {
        password.count >= 8
    }

    private var generatedUsernames: [String] {
        let base = usernameBase
        return [
            base + suffix(1),
            base + suffix(2),
            base + suffix(3)
        ]
    }

    private var usernameBase: String {
        let source = fullName
        let latin = source.applyingTransform(.toLatin, reverse: false) ?? source
        let compact = latin
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .filter { $0.isLetter || $0.isNumber }
        return compact.isEmpty ? "TideUser" : String(compact.prefix(12)).capitalized
    }

    private func suffix(_ seed: Int) -> String {
        let value = abs((fullName + "\(seed)").hashValue % 899) + 100
        let letters = ["yv", "wt", "gw", "lz", "io"]
        return letters[seed % letters.count] + String(value)
    }

    private func refreshGeneratedUsername() {
        guard !userEditedUsername else { return }
        username = generatedUsernames.first ?? username
    }

    private func advanceToUsername() {
        withAnimation(.easeInOut(duration: 0.58)) {
            if username.isEmpty { username = generatedUsernames.first ?? "" }
            step = .username
            focusedField = .username
        }
    }

    private func completeSetup() {
        let trimmedName = fullName.trimmingCharacters(in: .whitespacesAndNewlines)
        dependencies.session.completeProfileSetup(name: trimmedName, username: username, password: password)
        dependencies.router.selectedTab = .chats
    }
}

private struct FindFriendsSheet: View {
    let skip: () -> Void
    let allow: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Capsule()
                .fill(.white.opacity(0.28))
                .frame(width: 42, height: 5)
                .frame(maxWidth: .infinity)
                .padding(.top, 10)

            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(TidePalette.success)
                .padding(.top, 54)

            Text("Найди своих друзей")
                .font(.system(size: 36, weight: .black, design: .rounded))
                .foregroundStyle(.white)
                .padding(.top, 30)

            Text("Разреши находить твой аккаунт по адресу электронной почты и получай полезные письма о своей активности в Tide.")
                .font(.system(size: 20, weight: .black, design: .rounded))
                .foregroundStyle(.white)
                .lineSpacing(3)
                .padding(.top, 24)

            Text("Регистрируясь, ты соглашаешься с нашими Условиями, Политикой конфиденциальности и использованием файлов cookie. Tide может использовать твою контактную информацию, включая адрес электронной почты и номер телефона.")
                .font(.system(size: 17, weight: .heavy, design: .rounded))
                .foregroundStyle(.white.opacity(0.42))
                .lineSpacing(3)
                .padding(.top, 34)

            Spacer()

            Button(action: skip) {
                Text("Не сейчас")
                    .font(.system(size: 22, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 62)
                    .tideGlass(interactive: true, cornerRadius: 31)
            }

            Button(action: allow) {
                Text("Разрешить")
                    .font(.system(size: 22, weight: .black, design: .rounded))
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .frame(height: 62)
                    .background(.white, in: Capsule())
                    .shadow(color: .white.opacity(0.28), radius: 24, y: 8)
            }
            .padding(.top, 14)
            .padding(.bottom, 28)
        }
        .padding(.horizontal, 34)
        .background(Color.black.ignoresSafeArea())
    }
}

struct AuthBlackBackdrop: View {
    var body: some View {
        ZStack {
            Color.black
            LinearGradient(
                colors: [.black, .white.opacity(0.05), .black, .white.opacity(0.03)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .blur(radius: 30)
            .opacity(0.9)
        }
    }
}

struct AuthChromeLogo: View {
    let size: CGFloat

    var body: some View {
        Image("TideBubbleLogo")
            .renderingMode(.original)
            .resizable()
            .scaledToFit()
            .frame(width: size * 0.86, height: size * 0.86)
            .frame(width: size, height: size)
            .background(AuthGlassBackground(cornerRadius: size / 2, interactive: false))
            .clipShape(Circle())
            .shadow(color: .white.opacity(0.24), radius: 28, y: 8)
            .accessibilityLabel("Tide")
    }
}

struct AuthDivider: View {
    let title: String

    var body: some View {
        HStack(spacing: 12) {
            Rectangle().fill(.white.opacity(0.13)).frame(height: 0.7)
            Text(title)
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(.white.opacity(0.38))
            Rectangle().fill(.white.opacity(0.13)).frame(height: 0.7)
        }
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
                if isSecure { isVisible.toggle() }
            } label: {
                Image(systemName: isSecure ? (isVisible ? "eye.slash" : icon) : icon)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.white.opacity(0.44))
                    .frame(width: 24, height: 24)
            }
            .buttonStyle(AuthSmoothButtonStyle())
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
    let imageName: String
    var shape: ShapeMode = .roundedSquare
    let action: () -> Void

    private var size: CGFloat { shape == .circle ? 58 : 54 }
    private var cornerRadius: CGFloat { shape == .circle ? 29 : 17 }

    var body: some View {
        Button(action: action) {
            ZStack {
                AuthGlassBackground(cornerRadius: cornerRadius, interactive: true)
                Image(imageName)
                    .renderingMode(.original)
                    .resizable()
                    .scaledToFit()
                    .frame(width: size * 0.4, height: size * 0.4)
            }
            .frame(width: size, height: size)
        }
        .buttonStyle(AuthSmoothButtonStyle())
    }
}

struct AppleAuthGlassButton: View {
    enum ShapeMode { case roundedSquare, circle }

    var shape: ShapeMode = .roundedSquare
    let completion: (Result<ASAuthorization, Error>) -> Void

    private var size: CGFloat { shape == .circle ? 58 : 54 }
    private var cornerRadius: CGFloat { shape == .circle ? 29 : 17 }

    var body: some View {
        Group {
            if shape == .circle {
                content.contentShape(Circle())
            } else {
                content.contentShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            }
        }
        .buttonStyle(AuthSmoothButtonStyle())
    }

    private var content: some View {
        ZStack {
            AuthGlassBackground(cornerRadius: cornerRadius, interactive: true)
            Image(systemName: "apple.logo")
                .font(.system(size: size * 0.42, weight: .semibold))
                .foregroundStyle(.white)
        }
        .frame(width: size, height: size)
        .overlay {
            SignInWithAppleButton(.signIn) { request in
                request.requestedScopes = [.fullName, .email]
            } onCompletion: { result in
                completion(result)
            }
            .opacity(0.001)
            .allowsHitTesting(true)
        }
    }
}

struct AuthCircleIconButton: View {
    let systemImage: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                AuthGlassBackground(cornerRadius: 29, interactive: true)
                Image(systemName: systemImage)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.88))
            }
            .frame(width: 58, height: 58)
        }
        .buttonStyle(AuthSmoothButtonStyle())
    }
}

struct AuthProviderPill: View {
    let imageName: String?
    let systemImage: String?
    let title: String
    let action: () -> Void

    init(imageName: String? = nil, systemImage: String? = nil, title: String, action: @escaping () -> Void) {
        self.imageName = imageName
        self.systemImage = systemImage
        self.title = title
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                if let imageName {
                    Image(imageName)
                        .renderingMode(.original)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 26, height: 26)
                } else if let systemImage {
                    Image(systemName: systemImage)
                        .font(.system(size: 21, weight: .semibold))
                }
                Text(title)
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                Spacer(minLength: 0)
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 18)
            .frame(maxWidth: .infinity, minHeight: 58, alignment: .leading)
            .background(AuthGlassBackground(cornerRadius: 20, interactive: true))
        }
        .buttonStyle(AuthSmoothButtonStyle())
    }
}

struct AuthGlassBackground: View {
    let cornerRadius: CGFloat
    let interactive: Bool

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(.white.opacity(interactive ? 0.08 : 0.06))
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(.white.opacity(interactive ? 0.16 : 0.12), lineWidth: 1)
            }
            .shadow(color: .black.opacity(interactive ? 0.35 : 0.22), radius: 24, y: 10)
    }
}

struct AuthSmoothButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.975 : 1)
            .opacity(configuration.isPressed ? 0.82 : 1)
            .animation(.easeInOut(duration: 0.22), value: configuration.isPressed)
    }
}
