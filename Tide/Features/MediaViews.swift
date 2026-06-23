import AVFoundation
import AVKit
import SwiftUI
import UIKit

struct PostMediaGrid: View {
    let media: [MediaAttachment]
    var onOpen: ((Int) -> Void)? = nil

    var body: some View {
        Group {
            if media.count == 1, let first = media.first {
                PostMediaCell(media: first) { onOpen?(0) }
                    .aspectRatio(clampedAspectRatio(first.aspectRatio), contentMode: .fit)
                    .frame(maxWidth: .infinity)
                    .frame(maxHeight: 420)
            } else {
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 2), GridItem(.flexible(), spacing: 2)], spacing: 2) {
                    ForEach(Array(media.prefix(4).enumerated()), id: \.element.id) { index, item in
                        PostMediaCell(media: item) { onOpen?(index) }
                            .aspectRatio(1, contentMode: .fill)
                    }
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func clampedAspectRatio(_ ratio: Double) -> CGFloat {
        CGFloat(min(max(ratio, 0.78), 1.7))
    }
}

struct PostMediaCell: View {
    let media: MediaAttachment
    var onExpand: (() -> Void)?

    var body: some View {
        ZStack {
            if let url = media.url {
                switch media.kind {
                case .photo:
                    TideMediaImage(url: url, contentMode: .fill)
                        .contentShape(Rectangle())
                        .onTapGesture { onExpand?() }
                case .video:
                    PostInlineVideoView(url: url, expand: onExpand)
                case .link:
                    LinkPreviewCard(url: url)
                        .contentShape(Rectangle())
                        .onTapGesture { onExpand?() }
                }
            } else {
                MediaPlaceholder(symbol: media.kind == .video ? "play.rectangle.fill" : "photo.fill")
            }
        }
        .clipped()
    }
}

struct PostInlineVideoView: View {
    let url: URL
    var expand: (() -> Void)?
    @State private var player: AVPlayer?
    @State private var isPlaying = false
    @State private var isMuted = true

    var body: some View {
        ZStack {
            if isPlaying {
                VideoPlayer(player: player)
                    .onAppear { ensurePlayer().play() }
            } else {
                TideVideoThumbnailView(url: url)
                    .overlay(.black.opacity(0.16))
            }

            if !isPlaying {
                Image(systemName: "play.fill")
                    .font(.system(size: 18, weight: .black))
                    .foregroundStyle(.white)
                    .frame(width: 48, height: 48)
                    .background(.black.opacity(0.42), in: Circle())
            }

            VStack {
                Spacer()
                HStack(spacing: 10) {
                    Button {
                        isMuted.toggle()
                        player?.isMuted = isMuted
                    } label: {
                        Image(systemName: isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                            .font(.system(size: 14, weight: .bold))
                            .frame(width: 36, height: 36)
                            .background(.ultraThinMaterial, in: Circle())
                    }
                    .buttonStyle(TideGlassIconButtonStyle())

                    Spacer()

                    Button {
                        expand?()
                    } label: {
                        Image(systemName: "arrow.up.left.and.arrow.down.right")
                            .font(.system(size: 14, weight: .bold))
                            .frame(width: 36, height: 36)
                            .background(.ultraThinMaterial, in: Circle())
                    }
                    .buttonStyle(TideGlassIconButtonStyle())
                }
                .foregroundStyle(.white)
                .padding(10)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { togglePlayback() }
        .onDisappear {
            player?.pause()
            isPlaying = false
        }
    }

    @discardableResult
    private func ensurePlayer() -> AVPlayer {
        if let player { return player }
        let newPlayer = AVPlayer(url: url)
        newPlayer.isMuted = isMuted
        player = newPlayer
        return newPlayer
    }

    private func togglePlayback() {
        let player = ensurePlayer()
        withAnimation(.easeInOut(duration: 0.28)) {
            isPlaying.toggle()
        }
        isPlaying ? player.play() : player.pause()
    }
}

struct TideMediaImage: View {
    enum ContentMode {
        case fill
        case fit
    }

    let url: URL
    var contentMode: ContentMode = .fill

    var body: some View {
        Group {
            if url.isFileURL {
                if let image = UIImage(contentsOfFile: url.path) {
                    rendered(Image(uiImage: image))
                } else {
                    MediaPlaceholder(symbol: "photo.badge.exclamationmark", title: "Медиа недоступно")
                }
            } else {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        rendered(image)
                    case .failure:
                        MediaPlaceholder(symbol: "photo.badge.exclamationmark", title: "Медиа недоступно")
                    default:
                        ZStack {
                            TidePalette.subtle
                            ProgressView().tint(.white)
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func rendered(_ image: Image) -> some View {
        switch contentMode {
        case .fill:
            image.resizable().scaledToFill()
        case .fit:
            image.resizable().scaledToFit()
        }
    }
}

struct TideVideoThumbnailView: View {
    let url: URL
    @State private var thumbnail: UIImage?

    var body: some View {
        ZStack {
            if let thumbnail {
                Image(uiImage: thumbnail)
                    .resizable()
                    .scaledToFill()
            } else {
                MediaPlaceholder(symbol: "play.rectangle.fill")
            }
        }
        .task(id: url) {
            if let data = await Self.generateThumbnailData(url: url) {
                thumbnail = UIImage(data: data)
            }
        }
    }

    private static func generateThumbnailData(url: URL) async -> Data? {
        await Task.detached(priority: .utility) {
            let asset = AVURLAsset(url: url)
            let generator = AVAssetImageGenerator(asset: asset)
            generator.appliesPreferredTrackTransform = true
            generator.maximumSize = CGSize(width: 900, height: 900)
            let time = CMTime(seconds: 0.2, preferredTimescale: 600)
            guard let image = try? generator.copyCGImage(at: time, actualTime: nil) else { return nil }
            return UIImage(cgImage: image).jpegData(compressionQuality: 0.82)
        }.value
    }
}

struct MediaViewerView: View {
    @Environment(\.dismiss) private var dismiss
    let media: [MediaAttachment]
    @State private var index: Int
    @State private var alertText: String?
    @State private var dragOffset: CGSize = .zero
    @State private var currentPageScale: CGFloat = 1

    init(media: [MediaAttachment], index: Int) {
        self.media = media
        _index = State(initialValue: index)
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            TabView(selection: $index) {
                ForEach(Array(media.enumerated()), id: \.element.id) { itemIndex, item in
                    MediaViewerPage(media: item) { scale in
                        if itemIndex == index { currentPageScale = scale }
                    }
                        .tag(itemIndex)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: media.count > 1 ? .automatic : .never))
            .offset(y: dragOffset.height)
            .gesture(
                DragGesture()
                    .onChanged { value in
                        guard currentPageScale <= 1.01 else { return }
                        guard abs(value.translation.height) > abs(value.translation.width) else { return }
                        dragOffset = value.translation
                    }
                    .onEnded { value in
                        guard currentPageScale <= 1.01 else { return }
                        if abs(value.translation.height) > 180 {
                            dismiss()
                        } else {
                            withAnimation(.easeInOut(duration: 0.32)) {
                                dragOffset = .zero
                            }
                        }
                    }
            )
            .animation(.easeInOut(duration: 0.22), value: dragOffset)
            .onChange(of: index) { _, _ in
                currentPageScale = 1
                dragOffset = .zero
            }

            VStack {
                HStack {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 34, weight: .semibold))
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(.white)
                            .frame(width: 54, height: 54)
                            .contentShape(Circle())
                    }
                    .buttonStyle(.plain)
                    Spacer()
                    if let item = media[safe: index], let url = item.url {
                        ShareLink(item: url) {
                            Image(systemName: "square.and.arrow.up")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundStyle(.white)
                                .frame(width: 42, height: 42)
                                .background(.ultraThinMaterial, in: Circle())
                        }
                        Button { Task { await saveCurrent() } } label: {
                            Image(systemName: "square.and.arrow.down")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundStyle(.white)
                                .frame(width: 42, height: 42)
                                .background(.ultraThinMaterial, in: Circle())
                        }
                        .buttonStyle(TideGlassIconButtonStyle())
                        .disabled(item.kind == .link)
                    }
                }
                .padding(.horizontal, 18)
                .padding(.top, 18)
                Spacer()
            }
            .zIndex(10)
            .allowsHitTesting(true)
        }
        .alert("Медиа", isPresented: Binding(get: { alertText != nil }, set: { if !$0 { alertText = nil } })) {
            Button("ОК", role: .cancel) {}
        } message: {
            Text(alertText ?? "")
        }
    }

    @MainActor
    private func saveCurrent() async {
        guard let item = media[safe: index], let url = item.url else { return }
        switch item.kind {
        case .photo:
            guard let image = await loadImageForSaving(url) else {
                alertText = "Не удалось сохранить фото."
                return
            }
            UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
            alertText = "Фото сохранено."
        case .video:
            guard url.isFileURL else {
                alertText = "Удалённое видео можно отправить через кнопку поделиться."
                return
            }
            UISaveVideoAtPathToSavedPhotosAlbum(url.path, nil, nil, nil)
            alertText = "Видео сохранено."
        case .link:
            alertText = "Ссылку можно отправить через кнопку поделиться."
        }
    }

    private func loadImageForSaving(_ url: URL) async -> UIImage? {
        if url.isFileURL { return UIImage(contentsOfFile: url.path) }
        guard let (data, _) = try? await URLSession.shared.data(from: url) else { return nil }
        return UIImage(data: data)
    }
}

private struct MediaViewerPage: View {
    let media: MediaAttachment
    var onScaleChange: (CGFloat) -> Void = { _ in }
    @State private var scale: CGFloat = 1
    @State private var offset: CGSize = .zero
    @State private var player: AVPlayer?
    @State private var muted = false
    @State private var playing = true

    var body: some View {
        ZStack {
            if let url = media.url {
                switch media.kind {
                case .photo:
                    TideMediaImage(url: url, contentMode: .fit)
                        .scaleEffect(scale)
                        .offset(offset)
                        .gesture(
                            MagnificationGesture()
                                .onChanged {
                                    scale = max(1, min($0, 5))
                                    onScaleChange(scale)
                                }
                                .onEnded { value in
                                    withAnimation(.easeInOut(duration: 0.28)) {
                                        scale = max(1, min(value, 5))
                                        if scale == 1 { offset = .zero }
                                    }
                                    onScaleChange(scale)
                                }
                        )
                        .simultaneousGesture(
                            DragGesture()
                                .onChanged { value in
                                    guard scale > 1 else { return }
                                    offset = value.translation
                                }
                                .onEnded { value in
                                    guard scale > 1 else { return }
                                    withAnimation(.easeInOut(duration: 0.28)) {
                                        offset = value.translation
                                    }
                                }
                        )
                        .onTapGesture(count: 2) {
                            withAnimation(.easeInOut(duration: 0.28)) {
                                scale = 1
                                offset = .zero
                            }
                            onScaleChange(scale)
                        }
                case .video:
                    ZStack(alignment: .bottom) {
                        VideoPlayer(player: player)
                            .onAppear {
                                let newPlayer = AVPlayer(url: url)
                                newPlayer.isMuted = muted
                                player = newPlayer
                                player?.play()
                            }
                            .onDisappear { player?.pause() }
                        HStack(spacing: 14) {
                            Button {
                                playing.toggle()
                                playing ? player?.play() : player?.pause()
                            } label: {
                                Image(systemName: playing ? "pause.fill" : "play.fill")
                            }
                            Button {
                                muted.toggle()
                                player?.isMuted = muted
                            } label: {
                                Image(systemName: muted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                            }
                        }
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 18)
                        .frame(height: 50)
                        .background(.ultraThinMaterial, in: Capsule())
                        .padding(.bottom, 38)
                    }
                case .link:
                    LinkPreviewCard(url: url).padding()
                }
            } else {
                MediaPlaceholder(symbol: media.kind == .video ? "play.rectangle.fill" : "photo.fill")
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

struct MediaPlaceholder: View {
    let symbol: String
    var title: String?

    var body: some View {
        ZStack {
            LinearGradient(colors: [TidePalette.subtle, TidePalette.ink.opacity(0.14)], startPoint: .topLeading, endPoint: .bottomTrailing)
            VStack(spacing: 8) {
                Image(systemName: symbol)
                    .font(.system(size: 38, weight: .light))
                if let title {
                    Text(title)
                        .font(.caption.weight(.semibold))
                }
            }
            .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct LinkPreviewCard: View {
    let url: URL

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: "link").font(.title)
            Text(url.host() ?? "Ссылка").font(.headline)
            Text(url.absoluteString).font(.caption).foregroundStyle(.secondary).lineLimit(2)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .background(TidePalette.subtle)
    }
}

struct ComposerMediaStrip: View {
    let media: [ComposerMedia]
    let remove: (ComposerMedia) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(media) { item in
                    ZStack(alignment: .topTrailing) {
                        PostMediaCell(media: MediaAttachment(id: item.id, kind: item.kind, url: item.url, aspectRatio: item.aspectRatio))
                            .frame(width: 120, height: 120)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                        Button { remove(item) } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.title2)
                                .symbolRenderingMode(.palette)
                                .foregroundStyle(TidePalette.inverse, TidePalette.ink)
                        }
                        .padding(6)
                    }
                }
            }
            .padding(.vertical, 4)
        }
    }
}
