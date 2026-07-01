import Foundation
import CoreData

@objc(Notebook)
public class Notebook: NSManagedObject {
    @NSManaged public var id: UUID
    @NSManaged public var name: String
    @NSManaged public var notes: NSSet?
    
    public var notesArray: [Note] {
        let set = notes as? Set<Note> ?? []
        return set.sorted { $0.createdAt < $1.createdAt }
    }
    
    public var activeNotesCount: Int {
        let set = notes as? Set<Note> ?? []
        return set.filter { !$0.isTrashed }.count
    }
}
