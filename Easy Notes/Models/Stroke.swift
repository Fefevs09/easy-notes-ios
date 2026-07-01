import Foundation
import CoreData

@objc(Stroke)
public class Stroke: NSManagedObject {
    @NSManaged public var id: UUID
    @NSManaged public var points: String
    @NSManaged public var color: String
    @NSManaged public var width: Float
    @NSManaged public var createdAt: Date
    @NSManaged public var note: Note?
    @NSManaged public var pageIndex: Int16
}
