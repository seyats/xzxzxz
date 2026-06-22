import AVKit
import SwiftUI
import UIKit

struct PostMediaGrid: View {
    let media: [MediaAttachment]
    var onOpen: ((Int) -> Void)? = nil

    var body: some View {
        Group {
            if media.count == 1, let first = media.first {
                PostMediaCell(media: first)
                    .aspectRatio(first.aspectRatio, contentMode: .fit)
                    .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .onTapGesture { onOpen?(0) }
            } else {
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 2), GridItem(.flexible(), spacing: 2)], spacing: 2) {
                    ForEach(Array(media.prefix(4).enumerated()), id: \.element.id) { index, item in
                        PostMediaCell(media: item)
                            .aspectRatio(1, contentMode: .fill)
                            .contentShape(Rectangle())
                            .onTapGesture { onOpen?(index) }
                    }
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(TidePalette.separator, lineWidth: 0.5)
        }
    }
}

struct PostMediaCell: View {
    let media: MediaAttachment

    var body: some View {
        ZStack {
            if let url = media.url {
                switch media.kind {
                case .photo:
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            image.resizable().scaledToFill()
                        case .failure:
                            MediaPlaceholder(symbol: "photo.badge.exclamationmark")
                        default:
                            ProgressView()
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                                .background(TidePalette.subtle)
                        }
                    }
                case .video:
                    MediaPlaceholder(symbol: "play.rectangle.fill")
                    Image(systemName: "play.fill")
                        .font(.system(size: 18, weight: .black))
                        .foregroundStyle(.white)
                        .frame(width: 48, height: 48)
                        .background(.black.opacity(0.42), in: Circle())
                        .overlay(Circle().stroke(.white.opacity(0.22), lineWidth: 0.7))
                case .link:
                    LinkPreviewCard(url: url)
                }
            } else {
                MediaPlaceholder(symbol: media.kind == .video ? "play.rectangle.fill" : "photo.fill")
            }
        }
        .clipped()
    }
}

struct MediaViewerView: View {
    @Environment(\.dismiss) private var dismiss
    let media: [MediaAttachment]
    @State private var index: Int
    @State private var alertText: String?
    @State private var dragOffset: CGSize = .zero

    init(media: [MediaAttachment], index: Int) {
        self.media = media
        _index = State(initialValue: index)
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            TabView(selection: $index) {
                ForEach(Array(media.enumerated()), id: \.element.id) { itemIndex, item in
                    MediaViewerPage(media: item)
                        .tag(itemIndex)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: media.count > 1 ? .automatic : .never))
            .offset(y: dragOffset.height)
            .gesture(
                DragGesture()
                    .onChanged { value in
                        guard abs(value.translation.height) > abs(value.translation.width) else { return }
                        dragOffset = value.translation
                    }
                    .onEnded { value in
                        if abs(value.translation.height) > 180 {
                            dismiss()
                        } else {
                            withAnimation(.easeInOut(duration: 0.32)) {
                                dragOffset = .zero
                            }
                        }
                    }
            )

            VStack {
                HStack {
                    TideGlassIconButton(symbol: "xmark", tint: .white, size: 42) { dismiss() }
                    Spacer()
                    if let item = media[safe: index], let url = item.url {
                        ShareLink(item: url) {
                            Image(systemName: "square.and.arrow.up")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundStyle(.white)
                                .frame(width: 42, height: 42)
                                .background(.ultraThinMaterial, in: Circle())
                                .overlay(Circle().stroke(.white.opacity(0.18), lineWidth: 0.7))
                        }
                        Button { saveCurrent() } label: {
                            Image(systemName: "square.and.arrow.down")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundStyle(.white)
                                .frame(width: 42, height: 42)
                                .background(.ultraThinMaterial, in: Circle())
                                .overlay(Circle().stroke(.white.opacity(0.18), lineWidth: 0.7))
                        }
                        .buttonStyle(TideGlassIconButtonStyle())
                        .disabled(item.kind == .link)
                    }
                }
                .padding(.horizontal, 18)
                .padding(.top, 18)
                Spacer()
            }
        }
        .alert("Медиа", isPresented: Binding(get: { alertText != nil }, set: { if !$0 { alertText = nil } })) {
            Button("ОК", role: .cancel) {}
        } message: {
            Text(alertText ?? "")
        }
    }

    private func saveCurrent() {
        guard let item = media[safe: index], let url = item.url else { return }
        switch item.kind {
        case .photo:
            guard let image = UIImage(contentsOfFile: url.path) else {
                alertText = "Не удалось сохранить фото."
                return
            }
            UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
            alertText = "Фото сохранено."
        case .video:
            UISaveVideoAtPathToSavedPhotosAlbum(url.path, nil, nil, nil)
            alertText = "Видео сохранено."
        case .link:
            alertText = "Ссылку можно отправить через кнопку поделиться."
        }
    }
}

private struct MediaViewerPage: View {
    let media: MediaAttachment
    @State private var scale: CGFloat = 1
    @State private var offset: CGSize = .zero
    @State private var player: AVPlayer?
    @State private var muted = true
    @State private var playing = true

    var body: some View {
        ZStack {
            if let url = media.url {
                switch media.kind {
                case .photo:
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .scaledToFit()
                                .scaleEffect(scale)
                                .offset(offset)
                                .gesture(MagnificationGesture().onChanged { scale = max(1, min($0, 5)) })
                                .simultaneousGesture(
                                    DragGesture()
                                        .onChanged { offset = $0.translation }
                                        .onEnded { value in
                                            withAnimation(.easeInOut(duration: 0.32)) {
                                                offset = abs(value.translation.height) > 160 ? value.translation : .zero
                                            }
                                        }
                                )
                        case .failure:
                            MediaPlaceholder(symbol: "photo.badge.exclamationmark")
                        default:
                            ProgressView().tint(.white)
                        }
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

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

struct MediaPlaceholder: View {
    let symbol: String

    var body: some View {
        ZStack {
            LinearGradient(colors: [TidePalette.subtle, TidePalette.ink.opacity(0.14)], startPoint: .topLeading, endPoint: .bottomTrailing)
            Image(systemName: symbol).font(.system(size: 38, weight: .light)).foregroundStyle(.secondary)
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
