import CoreData
import XCTest

final class EditorImageHistoricalStoreTests: XCTestCase {
    @MainActor
    func testMigratesStoreWithGridColorBeforeNotebookColor() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("Historical.sqlite")

        // At 0d5a71e, Note.gridColorHex existed and Notebook.colorHex did not.
        let historicalModel = CoreDataStack.makeBaseModel()
        let notebookEntity = try XCTUnwrap(historicalModel.entitiesByName["Notebook"])
        notebookEntity.properties.removeAll { $0.name == "colorHex" }
        for entity in historicalModel.entities {
            entity.managedObjectClassName = NSStringFromClass(NSManagedObject.self)
        }

        let coordinator = NSPersistentStoreCoordinator(managedObjectModel: historicalModel)
        let store = try coordinator.addPersistentStore(ofType: NSSQLiteStoreType, configurationName: nil,
                                                      at: url, options: nil)
        let context = NSManagedObjectContext(concurrencyType: .mainQueueConcurrencyType)
        context.persistentStoreCoordinator = coordinator

        let notebook = NSManagedObject(entity: notebookEntity, insertInto: context)
        notebook.setValuesForKeys(["id": UUID(), "name": "Caderno legado"])
        let noteEntity = try XCTUnwrap(historicalModel.entitiesByName["Note"])
        let note = NSManagedObject(entity: noteEntity, insertInto: context)
        let noteID = UUID()
        let date = Date(timeIntervalSince1970: 1_700_000_000)
        note.setValuesForKeys([
            "id": noteID, "title": "Papel colorido", "content": "Texto preservado",
            "createdAt": date, "updatedAt": date, "notebook": notebook,
            "gridStyle": "grid", "gridColorHex": "#123456", "pageCount": 1
        ])
        try context.save()
        context.reset()
        try coordinator.remove(store)

        let migrated = try TestSupport.makeSQLiteContainer(at: url)
        let migratedCoordinator = migrated.persistentStoreCoordinator
        defer {
            migrated.viewContext.reset()
            for store in migratedCoordinator.persistentStores {
                try? migratedCoordinator.remove(store)
            }
        }
        let reopened = try XCTUnwrap(migrated.viewContext.fetch(NSFetchRequest<Note>(entityName: "Note")).first)
        XCTAssertEqual(reopened.id, noteID)
        XCTAssertEqual(reopened.content, "Texto preservado")
        XCTAssertEqual(reopened.gridColorHex, "#123456")
        XCTAssertEqual(reopened.notebook?.name, "Caderno legado")
        XCTAssertNil(reopened.notebook?.colorHex)
        XCTAssertEqual(reopened.editorImages?.count ?? 0, 0)
    }
}
