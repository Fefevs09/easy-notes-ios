import CoreData

extension CoreDataStack {
    static func makeModel() -> NSManagedObjectModel {
        let model = makeEditorImageModel()
        addTextBlockEntity(to: model)
        return model
    }

    static func makeEditorImageModel() -> NSManagedObjectModel {
        let model = makeBaseModel()
        let note = model.entitiesByName["Note"]!
        let image = NSEntityDescription()
        image.name = "EditorImage"
        image.managedObjectClassName = "EditorImage"

        func attribute(_ name: String, type: NSAttributeType) -> NSAttributeDescription {
            let attribute = NSAttributeDescription()
            attribute.name = name
            attribute.attributeType = type
            attribute.isOptional = false
            return attribute
        }

        let images = NSRelationshipDescription()
        images.name = "editorImages"
        images.destinationEntity = image
        images.isOptional = true
        images.maxCount = 0
        images.deleteRule = .cascadeDeleteRule

        let owner = NSRelationshipDescription()
        owner.name = "note"
        owner.destinationEntity = note
        owner.isOptional = false
        owner.minCount = 1
        owner.maxCount = 1
        owner.deleteRule = .nullifyDeleteRule
        owner.inverseRelationship = images
        images.inverseRelationship = owner

        let data = attribute("data", type: .binaryDataAttributeType)
        data.allowsExternalBinaryDataStorage = true
        image.properties = [
            attribute("id", type: .UUIDAttributeType),
            attribute("createdAt", type: .dateAttributeType),
            attribute("pageIndex", type: .integer16AttributeType),
            data,
            attribute("x", type: .doubleAttributeType),
            attribute("y", type: .doubleAttributeType),
            attribute("width", type: .doubleAttributeType),
            attribute("height", type: .doubleAttributeType),
            owner
        ]
        note.properties.append(images)
        model.entities.append(image)
        return model
    }

    static func loadSQLiteStore(at url: URL, into container: NSPersistentContainer) throws {
        try migrateBaseStoreIfNeeded(at: url, to: container.managedObjectModel)
        let description = NSPersistentStoreDescription(url: url)
        description.type = NSSQLiteStoreType
        description.shouldMigrateStoreAutomatically = false
        description.shouldInferMappingModelAutomatically = false
        container.persistentStoreDescriptions = [description]

        var loadError: Error?
        container.loadPersistentStores { _, error in loadError = error }
        if let loadError { throw loadError }
    }

    private static func makeHistoricalSource(missingNoteFields: Set<String> = [],
                                             missingNotebookFields: Set<String> = []) -> NSManagedObjectModel {
        let model = makeBaseModel()
        model.entitiesByName["Note"]?.properties.removeAll { missingNoteFields.contains($0.name) }
        model.entitiesByName["Notebook"]?.properties.removeAll { missingNotebookFields.contains($0.name) }
        // Migration accesses fields dynamically. Avoid registering duplicate
        // managed object subclass descriptions alongside the live schema.
        for entity in model.entities {
            entity.managedObjectClassName = NSStringFromClass(NSManagedObject.self)
        }
        return model
    }

    private static func makeEditorImageSource() -> NSManagedObjectModel {
        let model = makeEditorImageModel()
        for entity in model.entities {
            entity.managedObjectClassName = NSStringFromClass(NSManagedObject.self)
        }
        return model
    }

    private static func migrateBaseStoreIfNeeded(at url: URL, to destination: NSManagedObjectModel) throws {
        let files = FileManager.default
        guard files.fileExists(atPath: url.path) else { return }
        let metadata = try NSPersistentStoreCoordinator.metadataForPersistentStore(
            ofType: NSSQLiteStoreType, at: url, options: [NSReadOnlyPersistentStoreOption: true]
        )
        guard !destination.isConfiguration(withName: nil, compatibleWithStoreMetadata: metadata) else { return }

        let beforeGrid: Set = ["gridColorHex"]
        let beforeEmoji = beforeGrid.union(["emoji"])
        let beforeCover = beforeEmoji.union(["coverMediaData", "coverMediaType", "coverUpdatedAt"])
        let beforeNotebookColor: Set = ["colorHex"]
        let beforeNotebookHierarchy = beforeNotebookColor.union(["colorIndex", "parent", "children"])
        let supportedSources = [
            makeEditorImageSource(),
            makeHistoricalSource(),
            makeHistoricalSource(missingNotebookFields: beforeNotebookColor),
            makeHistoricalSource(missingNoteFields: beforeGrid),
            makeHistoricalSource(missingNoteFields: beforeGrid, missingNotebookFields: beforeNotebookColor),
            makeHistoricalSource(missingNoteFields: beforeGrid, missingNotebookFields: beforeNotebookHierarchy),
            makeHistoricalSource(missingNoteFields: beforeEmoji, missingNotebookFields: beforeNotebookHierarchy),
            makeHistoricalSource(missingNoteFields: beforeCover, missingNotebookFields: beforeNotebookHierarchy)
        ]
        guard let source = supportedSources.first(where: {
            $0.isConfiguration(withName: nil, compatibleWithStoreMetadata: metadata)
        }) else {
            throw NSError(domain: NSCocoaErrorDomain, code: NSPersistentStoreIncompatibleVersionHashError)
        }
        let mapping = try NSMappingModel.inferredMappingModel(forSourceModel: source, destinationModel: destination)
        let directory = url.deletingLastPathComponent().appendingPathComponent(".migration-\(UUID().uuidString)")
        try files.createDirectory(at: directory, withIntermediateDirectories: false)
        defer { try? files.removeItem(at: directory) }
        let stagedStore = directory.appendingPathComponent(url.lastPathComponent)
        let manager = NSMigrationManager(sourceModel: source, destinationModel: destination)
        try manager.migrateStore(
            from: url, sourceType: NSSQLiteStoreType, options: [NSReadOnlyPersistentStoreOption: true],
            with: mapping, toDestinationURL: stagedStore, destinationType: NSSQLiteStoreType,
            destinationOptions: nil
        )

        // Core Data replaces the whole store, including SQLite and external binary storage.
        let coordinator = NSPersistentStoreCoordinator(managedObjectModel: destination)
        try coordinator.replacePersistentStore(
            at: url, destinationOptions: nil,
            withPersistentStoreFrom: stagedStore, sourceOptions: nil, ofType: NSSQLiteStoreType
        )
    }
}
