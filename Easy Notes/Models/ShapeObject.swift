import Foundation
import CoreData

/// An editable geometric object (line, rectangle, ellipse, arrow, ...).
///
/// Unlike `Stroke` (a freehand polyline that is effectively immutable once
/// drawn), a `ShapeObject` is defined by a handful of *control points* — 2 for
/// line/rectangle/ellipse/arrow — so it can be selected, moved and resized
/// after creation. The control points are serialized with the exact same
/// `"x,y;x,y;..."` format used by `Stroke.points`, letting the shape reuse the
/// existing serialize/deserialize helpers.
@objc(ShapeObject)
public class ShapeObject: NSManagedObject {
    @NSManaged public var id: UUID
    @NSManaged public var kind: String          // raw value of ShapeKind
    @NSManaged public var points: String        // control points "x,y;x,y;..."
    @NSManaged public var strokeColor: String   // hex
    @NSManaged public var strokeWidth: Float
    @NSManaged public var fillColor: String?    // hex, optional
    @NSManaged public var createdAt: Date
    @NSManaged public var note: Note?
    @NSManaged public var pageIndex: Int16
}
