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
    @NSManaged public var pdfData: Data?
    @NSManaged public var pageCount: Int16
    
    public var strokesArray: [Stroke] {
        let set = strokes as? Set<Stroke> ?? []
        return Array(set)
    }
}
