import Foundation
import CoreData

@objc(Notebook)
public class Notebook: NSManagedObject, Identifiable {
    @NSManaged public var id: UUID
    @NSManaged public var name: String
    @NSManaged public var notes: NSSet?
    
    @NSManaged public var parent: Notebook?
    @NSManaged public var children: Set<Notebook>?
    @NSManaged public var colorIndex: NSNumber?

    var swatchIndex: Int {
        if let index = colorIndex?.intValue, PixelTheme.notebookSwatches.indices.contains(index) {
            return index
        }
        return PixelTheme.defaultNotebookIndex(name)
    }

    var ancestors: [Notebook] {
        var result: [Notebook] = []
        var node = parent
        while let ancestor = node {
            result.append(ancestor)
            node = ancestor.parent
        }
        return result.reversed()
    }

    var path: String { (ancestors + [self]).map(\.name).joined(separator: " / ") }

    public var notesArray: [Note] {
        let set = notes as? Set<Note> ?? []
        return set.sorted { $0.createdAt < $1.createdAt }
    }
    
    public var activeNotesCount: Int {
        let set = notes as? Set<Note> ?? []
        return set.filter { !$0.isTrashed }.count
    }
}
