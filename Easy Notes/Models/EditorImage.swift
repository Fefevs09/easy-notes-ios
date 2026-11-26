import CoreData
import ImageIO
import UniformTypeIdentifiers

@objc(EditorImage)
final class EditorImage: NSManagedObject {
    @NSManaged var id: UUID
    @NSManaged var createdAt: Date
    @NSManaged var pageIndex: Int16
    @NSManaged var data: Data
    @NSManaged var x: Double
    @NSManaged var y: Double
    @NSManaged var width: Double
    @NSManaged var height: Double
    @NSManaged var note: Note

    var frame: CGRect { CGRect(x: x, y: y, width: width, height: height) }

    private static let imageCache: NSCache<NSUUID, CGImage> = {
        let cache = NSCache<NSUUID, CGImage>()
        cache.totalCostLimit = 64 * 1024 * 1024
        return cache
    }()

    var image: CGImage? {
        let key = id as NSUUID
        if let cached = Self.imageCache.object(forKey: key) { return cached }
        guard let decoded = try? EditorImageMedia.decode(data) else { return nil }
        Self.imageCache.setObject(decoded.image, forKey: key, cost: decoded.image.bytesPerRow * decoded.image.height)
        return decoded.image
    }
}

enum EditorImageImportError: LocalizedError {
    case invalidPage
    case invalidImage
    case fileTooLarge
    case dimensionsTooLarge

    var errorDescription: String? {
        switch self {
        case .invalidPage: "A página selecionada não está disponível."
        case .invalidImage: "Selecione uma imagem PNG ou JPEG válida."
        case .fileTooLarge: "A imagem deve ter no máximo 20 MB."
        case .dimensionsTooLarge: "A imagem deve ter no máximo 8192 pixels por lado e 24 megapixels."
        }
    }
}

enum EditorImageMedia {
    static let byteLimit = 20_000_000
    static let edgeLimit = 8192
    static let pixelLimit = 24_000_000

    static func read(from url: URL) throws -> Data {
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        guard try url.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile == true else {
            throw EditorImageImportError.invalidImage
        }
        let file = try FileHandle(forReadingFrom: url)
        defer { try? file.close() }
        let data = try file.read(upToCount: byteLimit + 1) ?? Data()
        guard data.count <= byteLimit else { throw EditorImageImportError.fileTooLarge }
        return data
    }

    static func decode(_ data: Data) throws -> (image: CGImage, size: CGSize) {
        guard data.count <= byteLimit else { throw EditorImageImportError.fileTooLarge }
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let type = CGImageSourceGetType(source) as String?,
              hasCompleteContainer(data, type: type),
              CGImageSourceGetCount(source) == 1,
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = properties[kCGImagePropertyPixelWidth] as? Int,
              let height = properties[kCGImagePropertyPixelHeight] as? Int,
              width > 0, height > 0 else {
            throw EditorImageImportError.invalidImage
        }
        guard width <= edgeLimit, height <= edgeLimit, width * height <= pixelLimit else {
            throw EditorImageImportError.dimensionsTooLarge
        }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: 2048,
            kCGImageSourceShouldCacheImmediately: true
        ]
        guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary),
              CGImageSourceGetStatus(source) == .statusComplete,
              CGImageSourceGetStatusAtIndex(source, 0) == .statusComplete else {
            throw EditorImageImportError.invalidImage
        }
        let orientation = properties[kCGImagePropertyOrientation] as? Int ?? 1
        let size = (5...8).contains(orientation)
            ? CGSize(width: height, height: width)
            : CGSize(width: width, height: height)
        return (image, size)
    }

    private static func hasCompleteContainer(_ data: Data, type: String) -> Bool {
        // ImageIO can return a partial bitmap and report complete when a file
        // has lost its final bytes. Check the format's end marker as well.
        switch type {
        case UTType.png.identifier:
            return data.suffix(12).elementsEqual([0, 0, 0, 0, 0x49, 0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82])
        case UTType.jpeg.identifier:
            return data.suffix(2).elementsEqual([0xFF, 0xD9])
        default:
            return false
        }
    }

    static func placement(for size: CGSize, in page: CGRect) -> CGRect {
        let limit = CGSize(width: min(320, page.width * 0.7), height: min(320, page.height * 0.7))
        let scale = min(limit.width / size.width, limit.height / size.height, 1)
        let size = CGSize(width: size.width * scale, height: size.height * scale)
        return CGRect(x: page.midX - size.width / 2, y: page.midY - size.height / 2,
                      width: size.width, height: size.height)
    }
}

func renderEditorImages(for note: Note, pageIndex: Int, into context: CGContext) {
    let images = (note.editorImages as? Set<EditorImage> ?? [])
        .filter { Int($0.pageIndex) == pageIndex }
        .sorted { ($0.createdAt, $0.id.uuidString) < ($1.createdAt, $1.id.uuidString) }
    for entry in images {
        if let image = entry.image {
            context.draw(image, in: entry.frame)
        }
    }
}
