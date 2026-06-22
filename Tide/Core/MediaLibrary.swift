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
    var attachmentKind: MessageAttachmentKind = .photo
    var filename: String? = nil
    var byteCount: Int64 = 0
}

enum MediaStorageCategory: String, CaseIterable, Identifiable, Sendable {
    case images
    case videos
    case audio
    case files

    var id: String { rawValue }

    var title: String {
        switch self {
        case .images: "Изображения"
        case .videos: "Видео"
        case .audio: "Качество звука"
        case .files: "Документы"
        }
    }
}

struct MediaStoredFile: Identifiable, Hashable, Sendable {
    let id: URL
    let url: URL
    let name: String
    let category: MediaStorageCategory
    let byteCount: Int64
    let createdAt: Date
}

struct MediaStorageSnapshot: Hashable, Sendable {
    var files: [MediaStoredFile]

    var totalBytes: Int64 { files.reduce(0) { $0 + $1.byteCount } }
    var imageBytes: Int64 { bytes(for: .images) }
    var videoBytes: Int64 { bytes(for: .videos) }
    var audioBytes: Int64 { bytes(for: .audio) }
    var documentBytes: Int64 { bytes(for: .files) }

    func bytes(for category: MediaStorageCategory) -> Int64 {
        files.filter { $0.category == category }.reduce(0) { $0 + $1.byteCount }
    }
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
            media.append(ComposerMedia(
                id: UUID(),
                url: url,
                kind: isVideo ? .video : .photo,
                aspectRatio: aspectRatio,
                attachmentKind: isVideo ? .video : .photo,
                filename: url.lastPathComponent,
                byteCount: fileSize(url)
            ))
        }
        return media
    }

    func importImageData(_ data: Data, preferredName: String = "camera.jpg") throws -> ComposerMedia {
        let url = try persist(data: data, extension: "jpg", preferredName: preferredName)
        return ComposerMedia(
            id: UUID(),
            url: url,
            kind: .photo,
            aspectRatio: imageAspectRatio(data: data),
            attachmentKind: .photo,
            filename: url.lastPathComponent,
            byteCount: fileSize(url)
        )
    }

    func importFile(_ sourceURL: URL) throws -> ComposerMedia {
        let didAccess = sourceURL.startAccessingSecurityScopedResource()
        defer {
            if didAccess { sourceURL.stopAccessingSecurityScopedResource() }
        }
        let data = try Data(contentsOf: sourceURL)
        let fileExtension = sourceURL.pathExtension.isEmpty ? "dat" : sourceURL.pathExtension
        let url = try persist(data: data, extension: fileExtension, preferredName: sourceURL.lastPathComponent)
        let attachmentKind = Self.attachmentKind(for: url)
        let mediaKind: MediaKind = attachmentKind == .video ? .video : attachmentKind == .photo ? .photo : .link
        let aspectRatio = attachmentKind == .video ? 16.0 / 9.0 : attachmentKind == .photo ? imageAspectRatio(data: data) : 1
        return ComposerMedia(
            id: UUID(),
            url: url,
            kind: mediaKind,
            aspectRatio: aspectRatio,
            attachmentKind: attachmentKind,
            filename: sourceURL.lastPathComponent,
            byteCount: fileSize(url)
        )
    }

    func voiceRecordingURL() throws -> URL {
        let directory = try mediaDirectory()
        return directory.appendingPathComponent("voice-\(UUID().uuidString)").appendingPathExtension("m4a")
    }

    func remove(_ media: ComposerMedia) {
        try? FileManager.default.removeItem(at: media.url)
    }

    func storageSnapshot() throws -> MediaStorageSnapshot {
        let directory = try mediaDirectory()
        let urls = (try? FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.creationDateKey, .fileSizeKey],
            options: [.skipsHiddenFiles]
        )) ?? []
        let files = urls
            .filter { !$0.hasDirectoryPath }
            .map { url in
                let values = try? url.resourceValues(forKeys: [.creationDateKey, .fileSizeKey])
                return MediaStoredFile(
                    id: url,
                    url: url,
                    name: url.lastPathComponent,
                    category: Self.storageCategory(for: url),
                    byteCount: Int64(values?.fileSize ?? fileSize(url)),
                    createdAt: values?.creationDate ?? .distantPast
                )
            }
        return MediaStorageSnapshot(files: files.sorted { $0.createdAt > $1.createdAt })
    }

    func clearCache(protecting protectedURLs: Set<URL>) throws {
        let snapshot = try storageSnapshot()
        let protectedPaths = Set(protectedURLs.map { $0.standardizedFileURL.path })
        for file in snapshot.files where !protectedPaths.contains(file.url.standardizedFileURL.path) {
            try? FileManager.default.removeItem(at: file.url)
        }
    }

    private func mediaDirectory() throws -> URL {
        let root = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        let directory = root.appendingPathComponent("TideMedia", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    private func persist(data: Data, extension fileExtension: String, preferredName: String? = nil) throws -> URL {
        let directory = try mediaDirectory()
        let sanitizedName = preferredName?
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: "\\", with: "-")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let baseName = sanitizedName?.isEmpty == false ? sanitizedName! : UUID().uuidString
        let nameWithoutExtension = (baseName as NSString).deletingPathExtension
        let finalExtension = fileExtension.isEmpty ? "dat" : fileExtension
        let url = directory
            .appendingPathComponent("\(nameWithoutExtension)-\(UUID().uuidString.prefix(6))")
            .appendingPathExtension(finalExtension)
        try data.write(to: url, options: [.atomic, .completeFileProtection])
        return url
    }

    private func fileSize(_ url: URL) -> Int64 {
        let size = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
        return Int64(size)
    }

    private static func attachmentKind(for url: URL) -> MessageAttachmentKind {
        let ext = url.pathExtension.lowercased()
        if ["jpg", "jpeg", "png", "heic", "webp", "gif"].contains(ext) { return .photo }
        if ["mov", "mp4", "m4v", "avi"].contains(ext) { return .video }
        if ["m4a", "mp3", "wav", "aac"].contains(ext) { return .audio }
        return .file
    }

    private static func storageCategory(for url: URL) -> MediaStorageCategory {
        switch attachmentKind(for: url) {
        case .photo: .images
        case .video: .videos
        case .audio: .audio
        case .file, .none: .files
        }
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
