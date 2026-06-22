import AVKit
import SwiftUI
import UIKit

struct TideBackdropConfiguration: Equatable, Sendable {
    enum Style: String, CaseIterable, Identifiable, Sendable {
        case automatic
        case black
        case white
        case image
        case video

        var id: String { rawValue }
    }

    var style: Style
    var resourceName: String
    var videoURLString: String
    var opacity: Double
}

struct TideBackdropView: View {
    let configuration: TideBackdropConfiguration

    var body: some View {
        ZStack {
            switch configuration.style {
            case .black:
                Color.black
            case .white:
                Color.white
            case .image:
                backdropImage
            case .video:
                if let url = URL(string: configuration.videoURLString) {
                    BackdropVideoView(url: url)
                } else {
                    fallbackBackdrop
                }
            case .automatic:
                fallbackBackdrop
            }
        }
        .opacity(configuration.opacity)
        .ignoresSafeArea()
    }

    @ViewBuilder
    private var backdropImage: some View {
        if let image = UIImage(named: configuration.resourceName) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .ignoresSafeArea()
        } else {
            fallbackBackdrop
        }
    }

    private var fallbackBackdrop: some View {
        ZStack {
            LinearGradient(
                colors: [Color.black, Color.primary.opacity(0.12), Color(uiColor: .systemBackground).opacity(0.94)],
                startPoint: .top,
                endPoint: .bottom
            )
            LinearGradient(
                colors: [.white.opacity(0.08), .clear, .white.opacity(0.05)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .blur(radius: 18)
        }
    }
}

struct BackdropVideoView: View {
    @StateObject private var coordinator: BackdropVideoCoordinator

    init(url: URL) {
        _coordinator = StateObject(wrappedValue: BackdropVideoCoordinator(url: url))
    }

    var body: some View {
        VideoPlayer(player: coordinator.player)
            .ignoresSafeArea()
            .onAppear { coordinator.play() }
    }
}

@MainActor
final class BackdropVideoCoordinator: ObservableObject {
    let player: AVQueuePlayer
    private var looper: AVPlayerLooper?

    init(url: URL) {
        let asset = AVAsset(url: url)
        let item = AVPlayerItem(asset: asset)
        let queue = AVQueuePlayer(playerItem: item)
        queue.isMuted = true
        queue.actionAtItemEnd = .none
        player = queue
        looper = AVPlayerLooper(player: queue, templateItem: item)
    }

    func play() {
        player.play()
    }
}
