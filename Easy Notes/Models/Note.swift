import Foundation
import CoreData

@objc(Note)
public class Note: NSManagedObject {
    @NSManaged public var id: UUID
    @NSManaged public var title: String
    @NSManaged public var content: String
    @NSManaged public var createdAt: Date
    @NSManaged public var updatedAt: Date
    @NSManaged public var notebook: Notebook?
    @NSManaged public var isTrashed: Bool
    @NSManaged public var strokes: NSSet?
    @NSManaged public var shapes: NSSet?
    @NSManaged public var pdfData: Data?
    @NSManaged public var pageCount: Int16

    // Cartesian grid / graph-paper settings. `gridStyle` is the raw value of
    // GridStyle ("none"/"lines"/"grid"/"dots"). `gridOriginX/Y` mark the plane
    // origin in page points — reserved so future function plotting can map math
    // coordinates onto the page consistently with the visible grid.
    @NSManaged public var gridStyle: String
    @NSManaged public var gridSpacing: Float
    @NSManaged public var gridOriginX: Float
    @NSManaged public var gridOriginY: Float

    @NSManaged public var coverMediaData: Data?
    @NSManaged public var coverMediaType: String?
    @NSManaged public var coverUpdatedAt: Date?
    @NSManaged public var emoji: String?

    public var displayEmoji: String? {
        guard let trimmed = emoji?.trimmingCharacters(in: .whitespacesAndNewlines),
              !trimmed.isEmpty else {
            return nil
        }
        return trimmed
    }

    public var hasCustomCover: Bool {
        guard let data = coverMediaData else { return false }
        return !data.isEmpty
    }

    public var coverMedia: NoteCoverMedia? {
        guard let data = coverMediaData, !data.isEmpty else { return nil }
        if let typeIdentifier = coverMediaType, !typeIdentifier.isEmpty {
            return NoteCoverMedia(
                data: data,
                contentTypeIdentifier: typeIdentifier,
                kind: NoteCoverMediaKind.classify(contentTypeIdentifier: typeIdentifier)
            )
        }
        return try? NoteCoverMedia.validated(data: data)
    }

    public var suggestedPDFName: String {
        (title.isEmpty ? "Sem título" : title) + ".pdf"
    }

    public var strokesArray: [Stroke] {
        let set = strokes as? Set<Stroke> ?? []
        return Array(set)
    }

    public var shapesArray: [ShapeObject] {
        let set = shapes as? Set<ShapeObject> ?? []
        return Array(set)
    }
}
