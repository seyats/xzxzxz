import AVFoundation
import Foundation
import ImageIO
import PhotosUI
import UniformTypeIdentifiers
import SwiftUI

struct ComposerMedia: Identifiable, Hashable, Sendable {
    let id: UUID
    let url: URL
    let kind: MediaKind
    let aspectRatio: Double
}

actor MediaLibrary {
    static let shared = MediaLibrary()

    func importItems(_ items: [PhotosPickerItem]) async throws -> [ComposerMedia] {
        var media: [ComposerMedia] = []
        for item in items.prefix(10) {
            guard let data = try await item.loadTransferable(type: Data.self) else { continue }
            let isVideo = item.supportedContentTypes.contains { $0.conforms(to: .movie) }
            let url = try persist(data: data, extension: isVideo ? "mov" : "jpg")
            let aspectRatio = isVideo ? await videoAspectRatio(url: url) : imageAspectRatio(data: data)
            media.append(ComposerMedia(id: UUID(), url: url, kind: isVideo ? .video : .photo, aspectRatio: aspectRatio))
        }
        return media
    }

    func remove(_ media: ComposerMedia) {
        try? FileManager.default.removeItem(at: media.url)
    }

    private func persist(data: Data, extension fileExtension: String) throws -> URL {
        let root = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        let directory = root.appendingPathComponent("TideMedia", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appendingPathComponent(UUID().uuidString).appendingPathExtension(fileExtension)
        try data.write(to: url, options: [.atomic, .completeFileProtection])
        return url
    }

    private func videoAspectRatio(url: URL) async -> Double {
        let asset = AVURLAsset(url: url)
        guard let track = try? await asset.loadTracks(withMediaType: .video).first,
              let size = try? await track.load(.naturalSize),
              size.height > 0 else { return 16.0 / 9.0 }
        return abs(Double(size.width / size.height))
    }

    private func imageAspectRatio(data: Data) -> Double {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = properties[kCGImagePropertyPixelWidth] as? Double,
              let height = properties[kCGImagePropertyPixelHeight] as? Double,
              height > 0 else { return 1 }
        return width / height
    }
}
