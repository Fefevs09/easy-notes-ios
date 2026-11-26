import CoreData

enum TestSupport {
    static let sharedModel = CoreDataStack.makeModel()

    static func makeInMemoryContext() -> NSManagedObjectContext {
        let container = NSPersistentContainer(name: "EasyNotesModelTests", managedObjectModel: sharedModel)
        let description = NSPersistentStoreDescription()
        description.type = NSInMemoryStoreType
        container.persistentStoreDescriptions = [description]

        container.loadPersistentStores { (storeDescription, error) in
            if let error = error {
                fatalError("Failed to load in-memory store: \(error)")
            }
        }

        return container.viewContext
    }

    static func makeSQLiteContainer(at url: URL) throws -> NSPersistentContainer {
        let container = NSPersistentContainer(name: "EasyNotesModelSQLiteTests", managedObjectModel: sharedModel)
        try CoreDataStack.loadSQLiteStore(at: url, into: container)
        return container
    }

    /// Convenience for tests that need both a fresh in-memory context and a
    /// NoteViewModel wired to it.
    static func makeInMemoryViewModel() -> (viewModel: NoteViewModel, context: NSManagedObjectContext) {
        let context = makeInMemoryContext()
        let viewModel = NoteViewModel(context: context, coverCache: NoteCoverCache())
        return (viewModel, context)
    }
}
