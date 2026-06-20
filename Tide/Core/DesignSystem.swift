import UIKit
import SwiftUI

enum TidePalette {
    static let ink = Color.primary
    static let paper = Color(uiColor: .systemBackground)
    static let elevated = Color(uiColor: .secondarySystemBackground)
    static let subtle = Color.primary.opacity(0.07)
    static let separator = Color.primary.opacity(0.13)
    static let inverse = Color(uiColor: .systemBackground)
    static let destructive = Color.red
    static let success = Color.green
    static let danger = Color.red
}

enum TideTypography {
    static let hero = Font.system(size: 42, weight: .black, design: .rounded)
    static let display = Font.system(size: 30, weight: .bold, design: .rounded)
    static let title = Font.system(size: 22, weight: .bold, design: .rounded)
    static let headline = Font.system(size: 17, weight: .semibold, design: .rounded)
    static let body = Font.system(size: 16, weight: .regular, design: .rounded)
    static let metadata = Font.system(size: 12, weight: .medium, design: .rounded)
}

enum TideSpacing {
    static let tiny: CGFloat = 4
    static let small: CGFloat = 8
    static let medium: CGFloat = 16
    static let large: CGFloat = 24
    static let huge: CGFloat = 36
}

struct AvatarView: View {
    let user: User
    var size: CGFloat = 44

    var body: some View {
        ZStack {
            Circle().fill(.primary.opacity(0.08))
            if user.username.caseInsensitiveCompare("durov") == .orderedSame {
                Image("TideAuthLogo")
                    .resizable()
                    .scaledToFill()
                    .frame(width: size, height: size)
                    .clipShape(Circle())
            } else if let url = user.avatarImageURL,
               let image = UIImage(contentsOfFile: url.path) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: size, height: size)
                    .clipShape(Circle())
            } else {
                Image(systemName: user.avatarSymbol)
                    .font(.system(size: size * 0.44, weight: .medium))
            }
        }
        .frame(width: size, height: size)
        .overlay(Circle().stroke(.primary.opacity(0.16), lineWidth: 0.5))
        .accessibilityLabel("\(user.name) avatar")
    }
}

struct VerifiedName: View {
    let user: User

    var body: some View {
        HStack(spacing: 4) {
            Text(user.name).fontWeight(.semibold)
            if user.isVerified {
                Image("TideAuthLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 16, height: 16)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(.primary.opacity(0.18), lineWidth: 0.5))
                    .accessibilityLabel("Verified")
            }
        }
    }
}

struct GlassCardModifier: ViewModifier {
    let interactive: Bool

    func body(content: Content) -> some View {
        if #available(iOS 26, *) {
            content.glassEffect(
                interactive ? .regular.interactive() : .regular,
                in: .rect(cornerRadius: 22)
            )
        } else {
            content.background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 22))
        }
    }
}

struct TideSurfaceModifier: ViewModifier {
    let cornerRadius: CGFloat

    func body(content: Content) -> some View {
        content
            .background(TidePalette.elevated, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(TidePalette.separator, lineWidth: 0.5)
            }
    }
}

struct TidePrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(TideTypography.headline)
            .padding(.horizontal, 18)
            .frame(minHeight: 48)
            .foregroundStyle(TidePalette.inverse)
            .background(TidePalette.ink, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .opacity(configuration.isPressed ? 0.72 : 1)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.snappy(duration: 0.18), value: configuration.isPressed)
    }
}

struct TideSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(TideTypography.headline)
            .padding(.horizontal, 18)
            .frame(minHeight: 46)
            .foregroundStyle(TidePalette.ink)
            .background(TidePalette.subtle, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(TidePalette.separator, lineWidth: 0.5)
            }
            .opacity(configuration.isPressed ? 0.65 : 1)
    }
}

struct TideSectionHeader: View {
    let title: String
    var subtitle: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title).font(TideTypography.title)
            if let subtitle { Text(subtitle).font(.subheadline).foregroundStyle(.secondary) }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityAddTraits(.isHeader)
    }
}

struct TideConnectionBadge: View {
    let state: SocketConnectionState

    var body: some View {
        HStack(spacing: 6) {
            Circle().fill(state == .connected ? TidePalette.success : .secondary)
                .frame(width: 7, height: 7)
            Text(label).font(TideTypography.metadata)
        }
        .foregroundStyle(state == .connected ? TidePalette.success : .secondary)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(TidePalette.subtle, in: Capsule())
        .accessibilityLabel("Chat connection: \(label)")
    }

    private var label: String {
        switch state {
        case .connected: "Online"
        case .connecting: "Connecting"
        case .reconnecting: "Reconnecting"
        case .failed: "Offline"
        case .disconnected: "Offline"
        }
    }
}

extension View {
    func tideGlass(interactive: Bool = false) -> some View {
        modifier(GlassCardModifier(interactive: interactive))
    }

    func tideSurface(cornerRadius: CGFloat = 20) -> some View {
        modifier(TideSurfaceModifier(cornerRadius: cornerRadius))
    }
}

struct EmptyStateView: View {
    let symbol: String
    let title: LocalizedStringKey
    let message: LocalizedStringKey

    var body: some View {
        ContentUnavailableView(title, systemImage: symbol, description: Text(message))
    }
}

struct UserRow: View {
    let user: User

    var body: some View {
        HStack(spacing: 12) {
            AvatarView(user: user)
            VStack(alignment: .leading, spacing: 2) {
                VerifiedName(user: user)
                Text(user.handle).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
        }
    }
}

extension String {
    func ifEmpty(_ replacement: String) -> String {
        isEmpty ? replacement : self
    }
}
