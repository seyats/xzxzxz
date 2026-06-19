import SwiftUI

/// Заголовок профиля пользователя с логотипом верификации для верифицированных аккаунтов.
@available(iOS 17.0, *)
struct UserProfileHeaderView: View {
    let user: User
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Text(user.name)
                    .font(.system(size: 20, weight: .semibold, design: .default))
                    .foregroundColor(.white)
                
                if user.isVerified {
                    VerificationBadge()
                }
                
                Spacer()
            }
            
            if user.isVerified {
                Text("Account verified")
                    .font(.system(size: 12, weight: .regular, design: .default))
                    .foregroundColor(.gray)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

@available(iOS 17.0, *)
private struct VerificationBadge: View {
    var body: some View {
        Image("verified_badge")
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(width: 20, height: 20)
            .shadow(color: Color.blue.opacity(0.3), radius: 4, x: 0, y: 2)
    }
}

#Preview {
    UserProfileHeaderView(user: User(
        id: UUID(),
        name: "Pavel Durov",
        username: "durov",
        biography: "Founder of Telegram",
        avatarSymbol: "person.fill",
        isVerified: true,
        isAdministrator: true,
        followers: 1000000,
        following: 100,
        joinedAt: Date()
    ))
    .background(Color.black)
}
