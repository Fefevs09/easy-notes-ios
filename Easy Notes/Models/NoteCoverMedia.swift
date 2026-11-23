import AppKit
import Foundation
import ImageIO
import SwiftUI
import UniformTypeIdentifiers

// MARK: - Media Kind & Error Contracts

public enum NoteCoverMediaKind: String, Equatable, Sendable {
    case staticImage
    case animatedGIF

    nonisolated public static func classify(contentTypeIdentifier: String) -> NoteCoverMediaKind {
        if contentTypeIdentifier == UTType.gif.identifier {
            return .animatedGIF
        }
        if let type = UTType(contentTypeIdentifier), type.conforms(to: .gif) {
            return .animatedGIF
        }
        return .staticImage
    }
}

public enum NoteCoverError: LocalizedError, Equatable {
    case invalidNote
    case unreadableImage
    case unsupportedMediaType(String)
    case persistenceFailed(String)

    nonisolated public var errorDescription: String? {
        switch self {
        case .invalidNote:
            return "A nota selecionada não está mais disponível no repositório."
        case .unreadableImage:
            return "Não foi possível ler a imagem selecionada. Escolha um arquivo de imagem válido."
        case .unsupportedMediaType(let typeIdentifier):
            return "O formato de arquivo (\(typeIdentifier)) não é suportado como capa."
        case .persistenceFailed(let reason):
            return "Falha ao salvar a capa da nota: \(reason)"
        }
    }
}

// MARK: - Validated Cover Media Value

public struct NoteCoverMedia: Equatable, Sendable {
    public let data: Data
    public let contentTypeIdentifier: String
    public let kind: NoteCoverMediaKind

    nonisolated public var contentType: UTType? {
        UTType(contentTypeIdentifier)
    }

    nonisolated public static let supportedStaticImageTypes: [UTType] = [
        .png,
        .jpeg,
        .heic,
        .tiff,
        .bmp,
        .webP
    ]

    nonisolated public init(data: Data, contentTypeIdentifier: String, kind: NoteCoverMediaKind) {
        self.data = data
        self.contentTypeIdentifier = contentTypeIdentifier
        self.kind = kind
    }

    /// Validates raw cover bytes via ImageIO and classifies static images vs GIFs.
    nonisolated public static func validated(data: Data, contentType: UTType? = nil) throws -> NoteCoverMedia {
        guard !data.isEmpty else {
            throw NoteCoverError.unreadableImage
        }

        let genericTypes: Set<UTType> = [.data, .item, .content]
        if let contentType, !genericTypes.contains(contentType), !contentType.conforms(to: .image) {
            throw NoteCoverError.unsupportedMediaType(contentType.identifier)
        }

        var sourceOptions: [CFString: Any] = [
            kCGImageSourceShouldCache: false
        ]
        if let contentType, contentType.conforms(to: .image) {
            sourceOptions[kCGImageSourceTypeIdentifierHint] = contentType.identifier as CFString
        }

        guard let source = CGImageSourceCreateWithData(data as CFData, sourceOptions as CFDictionary) else {
            throw NoteCoverError.unreadableImage
        }

        let sourceIdentifier = CGImageSourceGetType(source) as String?
        let sourceUTType = sourceIdentifier.flatMap { UTType($0) }

        guard let sourceUTType else {
            if let sourceIdentifier {
                throw NoteCoverError.unsupportedMediaType(sourceIdentifier)
            }
            throw NoteCoverError.unreadableImage
        }

        guard sourceUTType.conforms(to: .image) else {
            throw NoteCoverError.unsupportedMediaType(sourceUTType.identifier)
        }

        guard CGImageSourceGetCount(source) > 0,
              let decodedFrame = CGImageSourceCreateImageAtIndex(source, 0, nil),
              decodedFrame.width > 0,
              decodedFrame.height > 0 else {
            throw NoteCoverError.unreadableImage
        }

        let isGIF = sourceUTType.conforms(to: .gif)
            || sourceIdentifier == UTType.gif.identifier

        let kind: NoteCoverMediaKind = isGIF ? .animatedGIF : .staticImage
        let finalIdentifier = kind == .animatedGIF ? UTType.gif.identifier : sourceUTType.identifier

        return NoteCoverMedia(
            data: data,
            contentTypeIdentifier: finalIdentifier,
            kind: kind
        )
    }
}

// MARK: - Extensible Rendering Architecture

@MainActor
public enum NoteCoverRenderedContent {
    case image(NSImage)
    case view(AnyView)
}

@MainActor
public protocol NoteCoverMediaRendering {
    var supportedKinds: Set<NoteCoverMediaKind> { get }
    func render(media: NoteCoverMedia, targetSize: CGSize) -> NoteCoverRenderedContent?
}

/// Default renderer for static cover images. Also decodes frame 0 as a safe
/// fallback for `.animatedGIF` media until an animated renderer is registered.
@MainActor
public struct StaticImageCoverRenderer: NoteCoverMediaRendering {
    public let supportedKinds: Set<NoteCoverMediaKind> = [.staticImage, .animatedGIF]

    public init() {}

    public func render(media: NoteCoverMedia, targetSize: CGSize) -> NoteCoverRenderedContent? {
        let sourceOptions: [CFString: Any] = [
            kCGImageSourceShouldCache: false,
            kCGImageSourceTypeIdentifierHint: media.contentTypeIdentifier as CFString
        ]
        guard let source = CGImageSourceCreateWithData(media.data as CFData, sourceOptions as CFDictionary),
              CGImageSourceGetCount(source) > 0 else {
            return nil
        }

        let cgImage: CGImage?
        let maxDimension = max(targetSize.width, targetSize.height)
        if maxDimension > 0 {
            let maxPixelSize = max(Int(ceil(maxDimension * 2.0)), 64)
            let thumbnailOptions: [CFString: Any] = [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceShouldCacheImmediately: true,
                kCGImageSourceThumbnailMaxPixelSize: maxPixelSize
            ]
            cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, thumbnailOptions as CFDictionary)
                ?? CGImageSourceCreateImageAtIndex(source, 0, nil)
        } else {
            cgImage = CGImageSourceCreateImageAtIndex(source, 0, nil)
        }

        guard let cgImage else { return nil }
        let image = NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
        return .image(image)
    }
}

/// Central registry that dispatches cover rendering by `NoteCoverMediaKind`.
///
/// To plug in animated GIF playback later without touching Core Data,
/// `NoteViewModel`, or note cards, implement `NoteCoverMediaRendering`
/// (e.g., `AnimatedGIFCoverRenderer`) returning `.view(AnyView(...))` and
/// register it during startup:
///
///     NoteCoverRendererRegistry.shared.register(
///         AnimatedGIFCoverRenderer(),
///         for: .animatedGIF
///     )
@MainActor
public final class NoteCoverRendererRegistry {
    public static let shared = NoteCoverRendererRegistry()

    private let defaultRenderer: any NoteCoverMediaRendering
    private var renderersByKind: [NoteCoverMediaKind: any NoteCoverMediaRendering]

    public init(defaultRenderer: (any NoteCoverMediaRendering)? = nil) {
        let resolvedDefault = defaultRenderer ?? StaticImageCoverRenderer()
        self.defaultRenderer = resolvedDefault
        self.renderersByKind = [
            .staticImage: resolvedDefault,
            .animatedGIF: resolvedDefault
        ]
    }

    public func register(_ renderer: any NoteCoverMediaRendering, for kind: NoteCoverMediaKind) {
        renderersByKind[kind] = renderer
    }

    public func register(_ renderer: any NoteCoverMediaRendering) {
        for kind in renderer.supportedKinds {
            renderersByKind[kind] = renderer
        }
    }

    public func resetToDefaults() {
        renderersByKind = [
            .staticImage: defaultRenderer,
            .animatedGIF: defaultRenderer
        ]
    }

    public func renderer(for kind: NoteCoverMediaKind) -> any NoteCoverMediaRendering {
        renderersByKind[kind] ?? defaultRenderer
    }

    public func render(media: NoteCoverMedia, targetSize: CGSize) -> NoteCoverRenderedContent? {
        let activeRenderer = renderer(for: media.kind)
        if let rendered = activeRenderer.render(media: media, targetSize: targetSize) {
            return rendered
        }
        return defaultRenderer.render(media: media, targetSize: targetSize)
    }
}

// MARK: - Invalidatable Thumbnail & Cover Cache

public final class NoteCoverCache: @unchecked Sendable {
    nonisolated public static let shared = NoteCoverCache()

    public enum EntryKind: String, Sendable {
        case customCover
        case pdfFallback
    }

    private struct CacheEntry {
        let image: NSImage
        let noteID: UUID
    }

    private let lock = NSLock()
    private let capacity: Int
    private var entries: [String: CacheEntry] = [:]
    private var accessOrder: [String] = []
    private var keysByNoteID: [UUID: Set<String>] = [:]

    nonisolated public init(capacity: Int = 128) {
        self.capacity = max(1, capacity)
    }

    nonisolated public static func cacheKey(
        noteID: UUID,
        kind: EntryKind,
        token: String,
        variant: String = "default"
    ) -> String {
        "\(noteID.uuidString)::\(kind.rawValue)::\(variant)::\(token)"
    }

    nonisolated public func image(forKey key: String) -> NSImage? {
        lock.lock()
        defer { lock.unlock() }
        guard let entry = entries[key] else { return nil }
        if let index = accessOrder.firstIndex(of: key) {
            accessOrder.remove(at: index)
        }
        accessOrder.append(key)
        return entry.image
    }

    nonisolated public func setImage(_ image: NSImage, forKey key: String, noteID: UUID) {
        lock.lock()
        defer { lock.unlock() }

        if let existing = entries[key] {
            removeTrackedKey(key, for: existing.noteID)
            if let index = accessOrder.firstIndex(of: key) {
                accessOrder.remove(at: index)
            }
        }

        entries[key] = CacheEntry(image: image, noteID: noteID)
        keysByNoteID[noteID, default: []].insert(key)
        accessOrder.append(key)

        while entries.count > capacity, !accessOrder.isEmpty {
            let evictedKey = accessOrder.removeFirst()
            if let evicted = entries.removeValue(forKey: evictedKey) {
                removeTrackedKey(evictedKey, for: evicted.noteID)
            }
        }
    }

    nonisolated public func invalidate(noteID: UUID) {
        lock.lock()
        defer { lock.unlock() }
        guard let keys = keysByNoteID.removeValue(forKey: noteID) else { return }
        for key in keys {
            entries.removeValue(forKey: key)
        }
        accessOrder.removeAll { keys.contains($0) }
    }

    nonisolated public func invalidateAll() {
        lock.lock()
        defer { lock.unlock() }
        entries.removeAll()
        accessOrder.removeAll()
        keysByNoteID.removeAll()
    }

    nonisolated public func hasCachedEntries(for noteID: UUID) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return !(keysByNoteID[noteID]?.isEmpty ?? true)
    }

    nonisolated public var cachedEntryCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return entries.count
    }

    private func removeTrackedKey(_ key: String, for noteID: UUID) {
        guard var keys = keysByNoteID[noteID] else { return }
        keys.remove(key)
        if keys.isEmpty {
            keysByNoteID.removeValue(forKey: noteID)
        } else {
            keysByNoteID[noteID] = keys
        }
    }
}
