import UIKit
import SwiftUI

enum TidePalette {
    static let ink = Color.primary
    static let paper = Color(uiColor: .systemBackground)
    static let elevated = Color(uiColor: .secondarySystemBackground)
    static let subtle = Color.primary.opacity(0.07)
    static let separator = Color.primary.opacity(0.13)
    static let inverse = Color(uiColor: .systemBackground)
    static let graphite = Color(uiColor: .tertiarySystemFill)
    static let graphiteStrong = Color.primary.opacity(0.18)
    static let glassStroke = Color.white.opacity(0.14)
    static let destructive = Color.red
    static let success = Color.primary.opacity(0.72)
    static let positive = Color.green
    static let danger = Color.red
}

enum TideTypography {
    static let hero = Font.system(size: 42, weight: .black, design: .rounded)
    static let display = Font.system(size: 30, weight: .bold, design: .rounded)
    static let title = Font.system(size: 22, weight: .bold, design: .rounded)
    static let headline = Font.system(size: 17, weight: .semibold, design: .rounded)
    static let body = Font.system(size: 16, weight: .regular, design: .rounded)
    static let metadata = Font.system(size: 12, weight: .medium, design: .rounded)

    static func brand(_ size: CGFloat) -> Font {
        Font.custom("Days One", size: size)
    }
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
                TideBrandLogoView(size: size, style: .circle)
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
        .accessibilityLabel("\(user.name) аватар")
    }
}

struct VerifiedName: View {
    let user: User

    var body: some View {
        HStack(spacing: 4) {
            Text(user.name).fontWeight(.semibold)
            if user.isVerified {
                TideBrandLogoView(size: 16, style: .circle)
                    .overlay(Circle().stroke(.primary.opacity(0.18), lineWidth: 0.5))
                    .accessibilityLabel("Верифицирован")
            }
        }
    }
}

struct TideBrandLogoView: View {
    enum Style {
        case circle
        case rounded(CGFloat)
    }

    let size: CGFloat
    var style: Style = .circle

    var body: some View {
        switch style {
        case .circle:
            brandImage
                .frame(width: size, height: size)
                .clipShape(Circle())
        case .rounded(let radius):
            brandImage
                .frame(width: size, height: size)
                .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
        }
    }

    @ViewBuilder
    private var brandImage: some View {
        if let image = resolvedImage {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
        } else {
            Image("TideAuthLogo")
                .resizable()
                .scaledToFill()
        }
    }

    private var resolvedImage: UIImage? {
        guard let url = Bundle.main.url(forResource: "TideIcon", withExtension: "png") else { return nil }
        return UIImage(contentsOfFile: url.path)
    }
}

struct GlassCardModifier: ViewModifier {
    let interactive: Bool
    var cornerRadius: CGFloat = 22
    var tint: Color? = nil

    func body(content: Content) -> some View {
        if #available(iOS 26, *) {
            content.glassEffect(
                glass,
                in: .rect(cornerRadius: cornerRadius)
            )
        } else {
            content
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .stroke(.white.opacity(0.12), lineWidth: 0.7)
                }
        }
    }

    @available(iOS 26, *)
    private var glass: Glass {
        var effect = Glass.regular
        if let tint {
            effect = effect.tint(tint)
        }
        return interactive ? effect.interactive() : effect
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

struct TideGlassButtonStyle: ButtonStyle {
    var tint: Color? = nil
    var cornerRadius: CGFloat = 18
    var minHeight: CGFloat = 44

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(TideTypography.headline)
            .foregroundStyle(.primary)
            .padding(.horizontal, 14)
            .frame(minHeight: minHeight)
            .tideGlass(interactive: true, cornerRadius: cornerRadius, tint: (tint ?? Color.primary).opacity(0.08))
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .opacity(configuration.isPressed ? 0.78 : 1)
            .animation(.easeInOut(duration: 0.24), value: configuration.isPressed)
    }

}

struct TideGlassIconButton: View {
    let symbol: String
    var tint: Color = .primary
    var size: CGFloat = 38
    var isDestructive = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: size * 0.42, weight: .semibold))
                .foregroundStyle(isDestructive ? TidePalette.danger : tint)
                .frame(width: size, height: size)
                .tideGlass(interactive: true, cornerRadius: size / 2, tint: tint.opacity(0.08))
        }
        .buttonStyle(TideGlassIconButtonStyle())
    }
}

struct TideGlassIconButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.94 : 1)
            .opacity(configuration.isPressed ? 0.76 : 1)
            .animation(.easeInOut(duration: 0.22), value: configuration.isPressed)
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
        .accessibilityLabel("Связь чата: \(label)")
    }

    private var label: String {
        switch state {
        case .connected: "Подключено"
        case .connecting: "Подключение"
        case .reconnecting: "Восстановление связи"
        case .failed: "Нет связи"
        case .disconnected: "Нет связи"
        }
    }
}

extension View {
    func tideGlass(interactive: Bool = false, cornerRadius: CGFloat = 22, tint: Color? = nil) -> some View {
        modifier(GlassCardModifier(interactive: interactive, cornerRadius: cornerRadius, tint: tint))
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
