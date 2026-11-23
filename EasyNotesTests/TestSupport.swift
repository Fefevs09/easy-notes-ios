import CoreData

enum TestSupport {
    private static let model = CoreDataStack.makeModel()

    static func makeInMemoryContext() -> NSManagedObjectContext {
        let container = NSPersistentContainer(name: "EasyNotesModelTests", managedObjectModel: model)
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

    static func makeSQLiteContainer(at storeURL: URL) throws -> NSPersistentContainer {
        let container = NSPersistentContainer(name: "EasyNotesModelSQLiteTests", managedObjectModel: model)
        let description = NSPersistentStoreDescription(url: storeURL)
        description.type = NSSQLiteStoreType
        container.persistentStoreDescriptions = [description]

        var loadError: Error?
        container.loadPersistentStores { _, error in
            loadError = error
        }
        if let loadError {
            throw loadError
        }
        return container
    }

    /// Convenience for tests that need both a fresh in-memory context and a
    /// NoteViewModel wired to it.
    static func makeInMemoryViewModel() -> (viewModel: NoteViewModel, context: NSManagedObjectContext) {
        let context = makeInMemoryContext()
        let viewModel = NoteViewModel(context: context)
        return (viewModel, context)
    }
}
