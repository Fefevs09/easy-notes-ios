import AppKit
import SwiftUI

struct NoteCoverView: View {
    @ObservedObject var note: Note
    var cache: NoteCoverCache = .shared
    var registry: NoteCoverRendererRegistry = .shared

    @State private var renderedContent: NoteCoverRenderedContent?

    private struct RenderTaskID: Equatable {
        let noteID: UUID
        let coverUpdatedAt: Date?
        let coverMediaType: String?
        let dataByteCount: Int
        let sizeBucket: String
    }

    var body: some View {
        GeometryReader { geometry in
            let size = geometry.size
            let sizeBucket = max(size.width, size.height) <= 80 ? "compact" : "card"
            let taskID = RenderTaskID(
                noteID: note.id,
                coverUpdatedAt: note.coverUpdatedAt,
                coverMediaType: note.coverMediaType,
                dataByteCount: note.coverMediaData?.count ?? 0,
                sizeBucket: sizeBucket
            )

            Group {
                if let renderedContent {
                    switch renderedContent {
                    case .image(let image):
                        Image(nsImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: size.width, height: size.height)
                            .clipped()
                    case .view(let customView):
                        customView
                            .frame(width: size.width, height: size.height)
                            .clipped()
                    }
                } else {
                    PixelTheme.paper
                }
            }
            .frame(width: size.width, height: size.height)
            .clipped()
            .task(id: taskID) {
                renderedContent = resolveContent(targetSize: size, sizeBucket: sizeBucket)
            }
        }
    }

    private func resolveContent(targetSize: CGSize, sizeBucket: String) -> NoteCoverRenderedContent? {
        guard let media = note.coverMedia else { return nil }

        let activeRenderer = registry.renderer(for: media.kind)
        let rendererVariant = "\(sizeBucket)::\(String(describing: type(of: activeRenderer)))"
        let token = "\(note.coverUpdatedAt?.timeIntervalSince1970 ?? 0)::\(media.contentTypeIdentifier)::\(media.data.count)"
        let key = NoteCoverCache.cacheKey(
            noteID: note.id,
            kind: .customCover,
            token: token,
            variant: rendererVariant
        )

        if let cached = cache.image(forKey: key) {
            return .image(cached)
        }

        let effectiveTargetSize = (targetSize.width > 0 && targetSize.height > 0)
            ? targetSize
            : CGSize(width: 300, height: 405)

        guard let rendered = registry.render(media: media, targetSize: effectiveTargetSize) else {
            return nil
        }

        if case .image(let image) = rendered {
            cache.setImage(image, forKey: key, noteID: note.id)
        }
        return rendered
    }
}
