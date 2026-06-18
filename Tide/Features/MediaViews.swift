import AVKit
import SwiftUI

struct PostMediaGrid: View {
    let media: [MediaAttachment]

    var body: some View {
        Group {
            if media.count == 1, let first = media.first {
                PostMediaCell(media: first)
                    .aspectRatio(first.aspectRatio, contentMode: .fit)
            } else {
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 2), GridItem(.flexible(), spacing: 2)], spacing: 2) {
                    ForEach(media.prefix(4)) { item in
                        PostMediaCell(media: item)
                            .aspectRatio(1, contentMode: .fill)
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
        Group {
            if let url = media.url {
                switch media.kind {
                case .photo:
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image): image.resizable().scaledToFill()
                        case .failure: MediaPlaceholder(symbol: "photo.badge.exclamationmark")
                        default: ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity).background(TidePalette.subtle)
                        }
                    }
                case .video:
                    VideoPlayer(player: AVPlayer(url: url))
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
            Text(url.host() ?? "Link").font(.headline)
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
