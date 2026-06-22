import AuthenticationServices
import SwiftUI

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
                case .landing: landingScreen
                case .username: usernameScreen
                case .email: emailScreen
                }
            }
            .padding(.horizontal, 28)
            .animation(.easeInOut(duration: 0.28), value: stage)
        }
        .preferredColorScheme(.dark)
        .ignoresSafeArea()
        .alert("\u{0412}\u{0445}\u{043e}\u{0434}", isPresented: Binding(get: { alertMessage != nil }, set: { if !$0 { alertMessage = nil } })) {
            Button("\u{041e}\u{041a}", role: .cancel) {}
        } message: { Text(alertMessage ?? "") }
        .sheet(isPresented: $showProviderSheet) {
            providerSheet
                .presentationDetents([.height(440)])
                .presentationDragIndicator(.visible)
                .presentationBackground(.black)
                .preferredColorScheme(.dark)
        }
    }

    private var landingScreen: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 180)

            AuthChromeLogo(size: 88)
                .padding(.bottom, 28)

            Text("\u{041d}\u{0430}\u{0447}\u{0430}\u{0442}\u{044c} \u{0431}\u{0435}\u{0441}\u{0435}\u{0434}\u{0443}")
                .font(.system(size: 42, weight: .black, design: .rounded))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)

            Spacer(minLength: 32)

            HStack(spacing: 24) {
                AuthSocialGlassButton(kind: .google, imageName: "GoogleLogo", shape: .circle) {
                    showProviderSheet = true
                }
                AppleAuthGlassButton(imageName: "AppleLogo", shape: .circle) { result in
                    handleAppleSignIn(result)
                }
                AuthCircleIconButton(systemImage: "envelope") { showEmail() }
            }

            AuthDivider(title: "\u{0438}\u{043b}\u{0438}")
                .padding(.top, 30)

            Button {
                setPlaceholder("\u{0412}\u{0445}\u{043e}\u{0434} \u{043f}\u{043e} \u{0442}\u{0435}\u{043b}\u{0435}\u{0444}\u{043e}\u{043d}\u{0443} \u{043f}\u{043e}\u{043a}\u{0430} \u{0440}\u{0430}\u{0431}\u{043e}\u{0442}\u{0430}\u{0435}\u{0442} \u{043a}\u{0430}\u{043a} \u{0437}\u{0430}\u{0433}\u{043b}\u{0443}\u{0448}\u{043a}\u{0430}.")
            } label: {
                HStack(spacing: 14) {
                    Image(systemName: "phone")
                        .font(.system(size: 24, weight: .heavy))
                    Text("\u{041f}\u{0440}\u{043e}\u{0434}\u{043e}\u{043b}\u{0436}\u{0438}\u{0442}\u{044c} \u{0441} \u{0442}\u{0435}\u{043b}\u{0435}\u{0444}\u{043e}\u{043d}\u{043e}\u{043c}")
                        .font(.system(size: 24, weight: .black, design: .rounded))
                }
                .foregroundStyle(.black)
                .frame(maxWidth: .infinity)
                .frame(height: 72)
                .background(.white, in: Capsule())
            }
            .padding(.top, 24)

            Text("\u{041f}\u{0440}\u{043e}\u{0434}\u{043e}\u{043b}\u{0436}\u{0430}\u{044f}, \u{0442}\u{044b} \u{0441}\u{043e}\u{0433}\u{043b}\u{0430}\u{0448}\u{0430}\u{0435}\u{0448}\u{044c}\u{0441}\u{044f} \u{0441} \u{043d}\u{0430}\u{0448}\u{0438}\u{043c}\u{0438}\n\u{0423}\u{0441}\u{043b}\u{043e}\u{0432}\u{0438}\u{044f}\u{043c}\u{0438}, \u{041f}\u{043e}\u{043b}\u{0438}\u{0442}\u{0438}\u{043a}\u{043e}\u{0439} \u{043a}\u{043e}\u{043d}\u{0444}\u{0438}\u{0434}\u{0435}\u{043d}\u{0446}\u{0438}\u{0430}\u{043b}\u{044c}\u{043d}\u{043e}\u{0441}\u{0442}\u{0438} \u{0438}\n\u{041f}\u{043e}\u{043b}\u{0438}\u{0442}\u{0438}\u{043a}\u{043e}\u{0439} \u{0438}\u{0441}\u{043f}\u{043e}\u{043b}\u{044c}\u{0437}\u{043e}\u{0432}\u{0430}\u{043d}\u{0438}\u{044f} \u{0444}\u{0430}\u{0439}\u{043b}\u{043e}\u{0432 cookie.")
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(.white.opacity(0.42))
                .multilineTextAlignment(.center)
                .lineSpacing(3)
                .padding(.top, 26)

            Button {
                showUsername()
            } label: {
                HStack(spacing: 16) {
                    Image(systemName: "at")
                    Text("\u{0412}\u{043e}\u{0439}\u{0442}\u{0438} \u{0441} \u{0438}\u{043c}\u{0435}\u{043d}\u{0435}\u{043c} \u{043f}\u{043e}\u{043b}\u{044c}\u{0437}\u{043e}\u{0432}\u{0430}\u{0442}\u{0435}\u{043b}\u{044f}")
                    Spacer()
                    Image(systemName: "chevron.right")
                }
                .font(.system(size: 22, weight: .heavy, design: .rounded))
                .foregroundStyle(.white.opacity(0.46))
                .padding(.horizontal, 28)
                .frame(maxWidth: .infinity)
                .frame(height: 86)
                .background(Color.white.opacity(0.04))
            }
            .padding(.horizontal, -28)
            .padding(.top, 34)
        }
    }

    private var usernameScreen: some View {
        VStack(spacing: 0) {
            authTopBar(trailing: "\u{0423}\u{0442}\u{0435}\u{0440}\u{044f}\u{043d}\u{043e} \u{0438}\u{043c}\u{044f} \u{043f}\u{043e}\u{043b}\u{044c}\u{0437}\u{043e}\u{0432}\u{0430}\u{0442}\u{0435}\u{043b}\u{044f}")
                .padding(.top, 64)

            VStack(alignment: .leading, spacing: 38) {
                Text("\u{0412}\u{0432}\u{0435}\u{0434}\u{0438} \u{0438}\u{043c}\u{044f}\n\u{043f}\u{043e}\u{043b}\u{044c}\u{0437}\u{043e}\u{0432}\u{0430}\u{0442}\u{0435}\u{043b}\u{044f}")
                    .font(.system(size: 46, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                    .lineSpacing(8)

                HStack(spacing: 16) {
                    Text("@")
                        .font(.system(size: 46, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                    TextField("\u{043d}\u{0438}\u{043a}\u{043d}\u{0435}\u{0439}\u{043c}", text: $identifier)
                        .font(.system(size: 40, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                        .tint(.white)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .focused($focusedField, equals: .identifier)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 72)

            Spacer()

            Button(action: submitUsername) {
                Text("\u{041f}\u{0440}\u{043e}\u{0434}\u{043e}\u{043b}\u{0436}\u{0438}\u{0442}\u{044c}")
                    .font(.system(size: 27, weight: .black, design: .rounded))
                    .foregroundStyle(canContinueUsername ? .black : .white.opacity(0.36))
                    .frame(maxWidth: .infinity)
                    .frame(height: 72)
                    .background(canContinueUsername ? .white : .white.opacity(0.14), in: Capsule())
            }
            .disabled(!canContinueUsername || isLoading)
            .padding(.bottom, 42)
        }
    }

    private var emailScreen: some View {
        VStack(spacing: 0) {
            authTopBar(trailing: "\u{0423}\u{043a}\u{0430}\u{0437}\u{0430}\u{0442}\u{044c} \u{0430}\u{0434}\u{0440}\u{0435}\u{0441} \u{044d}\u{043b}. \u{043f}\u{043e}\u{0447}\u{0442}\u{044b}")
                .padding(.top, 64)

            VStack(alignment: .leading, spacing: 22) {
                Text("\u{0423}\u{043a}\u{0430}\u{0436}\u{0438}\u{0442}\u{0435} \u{0441}\u{0432}\u{043e}\u{0439}\n\u{0430}\u{0434}\u{0440}\u{0435}\u{0441} \u{044d}\u{043b}. \u{043f}\u{043e}\u{0447}\u{0442}\u{044b}")
                    .font(.system(size: 46, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                    .lineSpacing(8)
                Text("\u{041c}\u{044b} \u{043e}\u{0442}\u{043f}\u{0440}\u{0430}\u{0432}\u{0438}\u{043c} \u{0442}\u{0435}\u{0431}\u{0435} \u{043a}\u{043e}\u{0434} \u{043f}\u{043e}\u{0434}\u{0442}\u{0432}\u{0435}\u{0440}\u{0436}\u{0434}\u{0435}\u{043d}\u{0438}\u{044f}")
                    .font(.system(size: 22, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white.opacity(0.42))
                TextField("\u{043f}\u{043e}\u{0447}\u{0442}\u{0430}@\u{043f}\u{0440}\u{0438}\u{043c}\u{0435}\u{0440}.\u{0440}\u{0443}", text: $email)
                    .font(.system(size: 40, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                    .tint(.white)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .focused($focusedField, equals: .email)
                    .padding(.top, 12)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 72)

            Spacer()

            Button(action: submitEmail) {
                Text("\u{041f}\u{0440}\u{043e}\u{0434}\u{043e}\u{043b}\u{0436}\u{0438}\u{0442}\u{044c}")
                    .font(.system(size: 27, weight: .black, design: .rounded))
                    .foregroundStyle(canContinueEmail ? .black : .white.opacity(0.36))
                    .frame(maxWidth: .infinity)
                    .frame(height: 72)
                    .background(canContinueEmail ? .white : .white.opacity(0.14), in: Capsule())
            }
            .disabled(!canContinueEmail || isLoading)

            Text("\u{041f}\u{0440}\u{043e}\u{0434}\u{043e}\u{043b}\u{0436}\u{0430}\u{044f}, \u{0442}\u{044b} \u{0441}\u{043e}\u{0433}\u{043b}\u{0430}\u{0448}\u{0430}\u{0435}\u{0448}\u{044c}\u{0441}\u{044f} \u{043f}\u{043e}\u{043b}\u{0443}\u{0447}\u{0430}\u{0442}\u{044c}\n\u{0441}\u{043b}\u{0443}\u{0436}\u{0435}\u{0431}\u{043d}\u{044b}\u{0435} \u{0443}\u{0432}\u{0435}\u{0434}\u{043e}\u{043c}\u{043b}\u{0435}\u{043d}\u{0438}\u{044f} \u{043e}\u{0431} \u{0430}\u{043a}\u{043a}\u{0430}\u{0443}\u{043d}\u{0442}\u{0435}.")
                .font(.system(size: 19, weight: .heavy, design: .rounded))
                .foregroundStyle(.white.opacity(0.42))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 24)
                .padding(.bottom, 42)
        }
    }

    private var providerSheet: some View {
        VStack(spacing: 20) {
            Text("\u{0412}\u{043e}\u{0439}\u{0434}\u{0438} \u{0432} \u{0441}\u{0432}\u{043e}\u{044e} \u{0443}\u{0447}\u{0451}\u{0442}\u{043d}\u{0443}\u{044e} \u{0437}\u{0430}\u{043f}\u{0438}\u{0441}\u{044c}")
                .font(.system(size: 26, weight: .black, design: .rounded))
                .foregroundStyle(.white)
                .padding(.top, 28)

            AuthProviderPill(imageName: "GoogleLogo", title: "\u{041f}\u{0440}\u{043e}\u{0434}\u{043e}\u{043b}\u{0436}\u{0438}\u{0442}\u{044c} \u{0441} Google") {
                setPlaceholder("\u{0412}\u{0445}\u{043e}\u{0434} \u{0447}\u{0435}\u{0440}\u{0435}\u{0437} Google \u{043f}\u{043e}\u{043a}\u{0430} \u{0440}\u{0430}\u{0431}\u{043e}\u{0442}\u{0430}\u{0435}\u{0442} \u{043a}\u{0430}\u{043a} \u{0437}\u{0430}\u{0433}\u{043b}\u{0443}\u{0448}\u{043a}\u{0430}.")
            }
            AuthProviderPill(imageName: "AppleLogo", title: "\u{041f}\u{0440}\u{043e}\u{0434}\u{043e}\u{043b}\u{0436}\u{0438}\u{0442}\u{044c} \u{0441} Apple") {
                setPlaceholder("\u{0412}\u{0445}\u{043e}\u{0434} \u{0447}\u{0435}\u{0440}\u{0435}\u{0437} Apple \u{0434}\u{043e}\u{0441}\u{0442}\u{0443}\u{043f}\u{0435}\u{043d} \u{0447}\u{0435}\u{0440}\u{0435}\u{0437} \u{043a}\u{043d}\u{043e}\u{043f}\u{043a}\u{0443} Apple \u{043d}\u{0430} \u{0433}\u{043b}\u{0430}\u{0432}\u{043d}\u{043e}\u{043c} \u{044d}\u{043a}\u{0440}\u{0430}\u{043d}\u{0435}.")
            }
            AuthProviderPill(systemImage: "envelope", title: "\u{041f}\u{0440}\u{043e}\u{0434}\u{043e}\u{043b}\u{0436}\u{0438}\u{0442}\u{044c} \u{0441} \u{044d}\u{043b}\u{0435}\u{043a}\u{0442}\u{0440}\u{043e}\u{043d}\u{043d}\u{043e}\u{0439} \u{043f}\u{043e}\u{0447}\u{0442}\u{043e}\u{0439}") {
                showProviderSheet = false
                showEmail()
            }
            AuthProviderPill(systemImage: "phone", title: "\u{041f}\u{0440}\u{043e}\u{0434}\u{043e}\u{043b}\u{0436}\u{0438}\u{0442}\u{044c} \u{0441} \u{0442}\u{0435}\u{043b}\u{0435}\u{0444}\u{043e}\u{043d}\u{043e}\u{043c}") {
                setPlaceholder("\u{0412}\u{0445}\u{043e}\u{0434} \u{043f}\u{043e} \u{0442}\u{0435}\u{043b}\u{0435}\u{0444}\u{043e}\u{043d}\u{0443} \u{043f}\u{043e}\u{043a}\u{0430} \u{0440}\u{0430}\u{0431}\u{043e}\u{0442}\u{0430}\u{0435}\u{0442} \u{043a}\u{0430}\u{043a} \u{0437}\u{0430}\u{0433}\u{043b}\u{0443}\u{0448}\u{043a}\u{0430}.")
            }

            Spacer()
        }
        .padding(.horizontal, 34)
        .background(Color.black.ignoresSafeArea())
    }

    private func authTopBar(trailing: String) -> some View {
        HStack {
            Button {
                withAnimation(.easeInOut(duration: 0.28)) { stage = .landing }
            } label: {
                Image(systemName: "arrow.left")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundStyle(.white)
            }

            Spacer()

            Button {
                setPlaceholder("\u{0412}\u{043e}\u{0441}\u{0441}\u{0442}\u{0430}\u{043d}\u{043e}\u{0432}\u{043b}\u{0435}\u{043d}\u{0438}\u{0435} \u{0430}\u{043a}\u{043a}\u{0430}\u{0443}\u{043d}\u{0442}\u{0430} \u{043f}\u{043e}\u{044f}\u{0432}\u{0438}\u{0442}\u{0441}\u{044f} \u{043f}\u{043e}\u{0437}\u{0436}\u{0435}.")
            } label: {
                Text(trailing)
                    .font(.system(size: 20, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.trailing)
            }
        }
    }

    private var canContinueUsername: Bool { !identifier.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    private var canContinueEmail: Bool { email.contains("@") && email.contains(".") }

    private func showUsername() {
        withAnimation(.easeInOut(duration: 0.28)) { stage = .username }
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(180))
            focusedField = .identifier
        }
    }

    private func showEmail() {
        withAnimation(.easeInOut(duration: 0.28)) { stage = .email }
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
            await dependencies.session.signInIdentifier(identifier, password: "Sy3uki90.")
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
                    alertMessage = "\u{0410}\u{043f}\u{043f}\u{043b}\u{0435} \u{043d}\u{0435} \u{0432}\u{0435}\u{0440}\u{043d}\u{0443}\u{043b} \u{0434}\u{0430}\u{043d}\u{043d}\u{044b}\u{0435} \u{0430}\u{043a}\u{043a}\u{0430}\u{0443}\u{043d}\u{0442}\u{0430}."
                    return
                }
                let fallbackEmail = credential.email ?? "\(credential.user)@apple.local"
                let name = [credential.fullName?.givenName, credential.fullName?.familyName].compactMap { $0 }.joined(separator: " ")
                await dependencies.session.signInApple(userIdentifier: credential.user, email: fallbackEmail, displayName: name.isEmpty ? nil : name)
            case .failure(let error):
                alertMessage = error.localizedDescription
            }
        }
    }
}

struct AuthProfileSetupView: View {
    @Environment(AppDependencies.self) private var dependencies
    @FocusState private var focusedField: Field?
    @State private var step: Step = .name
    @State private var firstName = ""
    @State private var lastName = ""
    @State private var username = ""

    private enum Step { case name, username }
    private enum Field { case firstName, lastName, username }

    var body: some View {
        ZStack {
            AuthBlackBackdrop()

            VStack(spacing: 0) {
                Spacer()

                AuthChromeLogo(size: 112)
                    .padding(.bottom, 30)

                VStack(spacing: 8) {
                    Text(step == .name ? "\u{0417}\u{0430}\u{043f}\u{043e}\u{043b}\u{043d}\u{0438} \u{0438}\u{043c}\u{044f}" : "\u{0412}\u{044b}\u{0431}\u{0435}\u{0440}\u{0438} \u{0438}\u{043c}\u{044f} \u{043f}\u{043e}\u{043b}\u{044c}\u{0437}\u{043e}\u{0432}\u{0430}\u{0442}\u{0435}\u{043b}\u{044f}")
                        .font(.system(size: 30, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)

                    Text(step == .name ? "\u{0422}\u{0430}\u{043a} \u{0442}\u{0435}\u{0431}\u{044f} \u{0443}\u{0432}\u{0438}\u{0434}\u{044f}\u{0442} \u{0432} \u{043f}\u{0440}\u{0438}\u{043b}\u{043e}\u{0436}\u{0435}\u{043d}\u{0438}\u{0438}." : "\u{041f}\u{043e} \u{043d}\u{0435}\u{043c}\u{0443} \u{0442}\u{0435}\u{0431}\u{044f} \u{0431}\u{0443}\u{0434}\u{0443}\u{0442} \u{043d}\u{0430}\u{0445}\u{043e}\u{0434}\u{0438}\u{0442}\u{044c}.")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.48))
                }
                .padding(.bottom, 30)

                if step == .name {
                    VStack(spacing: 14) {
                        AuthInputField(placeholder: "\u{0418}\u{043c}\u{044f}", text: $firstName, icon: "person", isSecure: false, isVisible: .constant(true))
                            .focused($focusedField, equals: .firstName)
                        AuthInputField(placeholder: "\u{0424}\u{0430}\u{043c}\u{0438}\u{043b}\u{0438}\u{044f}", text: $lastName, icon: "person.text.rectangle", isSecure: false, isVisible: .constant(true))
                            .focused($focusedField, equals: .lastName)
                    }
                } else {
                    AuthInputField(placeholder: "\u{0418}\u{043c}\u{044f} \u{043f}\u{043e}\u{043b}\u{044c}\u{0437}\u{043e}\u{0432}\u{0430}\u{0442}\u{0435}\u{043b}\u{044f}", text: $username, icon: "at", isSecure: false, isVisible: .constant(true))
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .focused($focusedField, equals: .username)
                }

                Button(action: continueSetup) {
                    Text(step == .name ? "\u{041f}\u{0440}\u{043e}\u{0434}\u{043e}\u{043b}\u{0436}\u{0438}\u{0442}\u{044c}" : "\u{0412}\u{043e}\u{0439}\u{0442}\u{0438} \u{0432} \u{043f}\u{0440}\u{0438}\u{043b}\u{043e}\u{0436}\u{0435}\u{043d}\u{0438}\u{0435}")
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundStyle(.black)
                        .frame(width: 154, height: 48)
                        .background(.white, in: Capsule())
                        .shadow(color: .white.opacity(0.18), radius: 18, y: 8)
                }
                .padding(.top, 28)

                Spacer()

                if dependencies.session.currentUser?.isVerified == true {
                    HStack(spacing: 8) {
                        TideBrandLogoView(size: 18, style: .circle)
                        Text("\u{0430}\u{043a}\u{043a}\u{0430}\u{0443}\u{043d}\u{0442} \u{0432}\u{0435}\u{0440}\u{0438}\u{0444}\u{0438}\u{0446}\u{0438}\u{0440}\u{043e}\u{0432}\u{0430}\u{043d}")
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
            withAnimation(.easeInOut(duration: 0.28)) {
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
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [.white.opacity(0.18), .black, .white.opacity(0.34), .black.opacity(0.92)],
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
                    LinearGradient(
                        colors: [.white.opacity(0.65), .white.opacity(0.05), .white.opacity(0.32)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
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
                .font(.system(size: 12, weight: .medium, design: .rounded))
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
    let imageName: String
    var shape: ShapeMode = .roundedSquare
    let action: () -> Void

    private var size: CGFloat { shape == .circle ? 48 : 54 }
    private var cornerRadius: CGFloat { shape == .circle ? 24 : 17 }

    var body: some View {
        Button(action: action) {
            ZStack {
                AuthGlassBackground(cornerRadius: cornerRadius, interactive: true)
                Image(imageName)
                    .resizable()
                    .scaledToFit()
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

    let imageName: String
    var shape: ShapeMode = .roundedSquare
    let completion: (Result<ASAuthorization, Error>) -> Void

    private var size: CGFloat { shape == .circle ? 48 : 54 }
    private var cornerRadius: CGFloat { shape == .circle ? 24 : 17 }

    var body: some View {
        ZStack {
            AuthGlassBackground(cornerRadius: cornerRadius, interactive: true)
            Image(imageName)
                .resizable()
                .scaledToFit()
                .frame(width: size * 0.42, height: size * 0.42)
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
        .clipShape(shape == .circle ? AnyShape(Circle()) : AnyShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)))
        .buttonStyle(.plain)
    }
}

struct AuthCircleIconButton: View {
    let systemImage: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                AuthGlassBackground(cornerRadius: 24, interactive: true)
                Image(systemName: systemImage)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.88))
            }
            .frame(width: 48, height: 48)
        }
        .buttonStyle(.plain)
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
                        .resizable()
                        .scaledToFit()
                        .frame(width: 26, height: 26)
                } else if let systemImage {
                    Image(systemName: systemImage)
                        .font(.system(size: 20, weight: .semibold))
                }
                Text(title)
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                Spacer(minLength: 0)
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 18)
            .frame(maxWidth: .infinity, minHeight: 60, alignment: .leading)
            .background(AuthGlassBackground(cornerRadius: 20, interactive: true))
        }
        .buttonStyle(.plain)
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

struct AnyShape: Shape {
    private let builder: (CGRect) -> Path

    init<S: Shape>(_ shape: S) {
        builder = { rect in shape.path(in: rect) }
    }

    func path(in rect: CGRect) -> Path {
        builder(rect)
    }
}
