import CoreData

public enum CoreDataStorageError: LocalizedError, Equatable {
    case storeUnavailable
    case invalidDestinationDirectory(String)
    case destinationAlreadyExists(URL)
    case verificationFailed(URL)

    public var errorDescription: String? {
        switch self {
        case .storeUnavailable:
            return "Não foi possível localizar o arquivo de banco de dados atual."
        case .invalidDestinationDirectory(let path):
            return "A pasta de destino não é um diretório acessível: \(path)"
        case .destinationAlreadyExists(let url):
            return "Já existe um banco de dados do Easy Notes na pasta selecionada (\(url.lastPathComponent)). Escolha uma pasta vazia para evitar sobrescrever dados."
        case .verificationFailed(let url):
            return "A verificação do arquivo copiado falhou em \(url.path). Os dados originais foram preservados."
        }
    }
}

public class CoreDataStack {
    public static let shared = CoreDataStack()
    public static let storeFileName = "EasyNotesModel.sqlite"
    
    public let container: NSPersistentContainer
    
    public var viewContext: NSManagedObjectContext {
        return container.viewContext
    }

    public var currentStoreURL: URL? {
        container.persistentStoreCoordinator.persistentStores.first?.url
            ?? container.persistentStoreDescriptions.first?.url
    }

    public static var defaultStoreDirectoryURL: URL {
        NSPersistentContainer.defaultDirectoryURL()
    }
    
    static func makeModel() -> NSManagedObjectModel {
        let model = NSManagedObjectModel()
        
        // --- 1. Entity: Notebook ---
        let notebookEntity = NSEntityDescription()
        notebookEntity.name = "Notebook"
        notebookEntity.managedObjectClassName = "Notebook"
        
        let notebookIdAttribute = NSAttributeDescription()
        notebookIdAttribute.name = "id"
        notebookIdAttribute.attributeType = .UUIDAttributeType
        notebookIdAttribute.isOptional = false
        
        let notebookNameAttribute = NSAttributeDescription()
        notebookNameAttribute.name = "name"
        notebookNameAttribute.attributeType = .stringAttributeType
        notebookNameAttribute.isOptional = false
        
        notebookEntity.properties = [notebookIdAttribute, notebookNameAttribute]
        
        // --- 2. Entity: Note ---
        let noteEntity = NSEntityDescription()
        noteEntity.name = "Note"
        noteEntity.managedObjectClassName = "Note"
        
        let noteIdAttribute = NSAttributeDescription()
        noteIdAttribute.name = "id"
        noteIdAttribute.attributeType = .UUIDAttributeType
        noteIdAttribute.isOptional = false
        
        let noteTitleAttribute = NSAttributeDescription()
        noteTitleAttribute.name = "title"
        noteTitleAttribute.attributeType = .stringAttributeType
        noteTitleAttribute.isOptional = false
        
        let noteContentAttribute = NSAttributeDescription()
        noteContentAttribute.name = "content"
        noteContentAttribute.attributeType = .stringAttributeType
        noteContentAttribute.isOptional = false
        
        let noteCreatedAtAttribute = NSAttributeDescription()
        noteCreatedAtAttribute.name = "createdAt"
        noteCreatedAtAttribute.attributeType = .dateAttributeType
        noteCreatedAtAttribute.isOptional = false
        
        let noteUpdatedAtAttribute = NSAttributeDescription()
        noteUpdatedAtAttribute.name = "updatedAt"
        noteUpdatedAtAttribute.attributeType = .dateAttributeType
        noteUpdatedAtAttribute.isOptional = false
        
        let noteIsTrashedAttribute = NSAttributeDescription()
        noteIsTrashedAttribute.name = "isTrashed"
        noteIsTrashedAttribute.attributeType = .booleanAttributeType
        noteIsTrashedAttribute.isOptional = false
        noteIsTrashedAttribute.defaultValue = false
        
        let notePdfDataAttribute = NSAttributeDescription()
        notePdfDataAttribute.name = "pdfData"
        notePdfDataAttribute.attributeType = .binaryDataAttributeType
        notePdfDataAttribute.isOptional = true
        
        let notePageCountAttribute = NSAttributeDescription()
        notePageCountAttribute.name = "pageCount"
        notePageCountAttribute.attributeType = .integer16AttributeType
        notePageCountAttribute.isOptional = false
        notePageCountAttribute.defaultValue = 1

        let noteGridStyleAttribute = NSAttributeDescription()
        noteGridStyleAttribute.name = "gridStyle"
        noteGridStyleAttribute.attributeType = .stringAttributeType
        noteGridStyleAttribute.isOptional = false
        noteGridStyleAttribute.defaultValue = "none"

        let noteGridSpacingAttribute = NSAttributeDescription()
        noteGridSpacingAttribute.name = "gridSpacing"
        noteGridSpacingAttribute.attributeType = .floatAttributeType
        noteGridSpacingAttribute.isOptional = false
        noteGridSpacingAttribute.defaultValue = 24.0

        let noteGridOriginXAttribute = NSAttributeDescription()
        noteGridOriginXAttribute.name = "gridOriginX"
        noteGridOriginXAttribute.attributeType = .floatAttributeType
        noteGridOriginXAttribute.isOptional = false
        noteGridOriginXAttribute.defaultValue = 0.0

        let noteGridOriginYAttribute = NSAttributeDescription()
        noteGridOriginYAttribute.name = "gridOriginY"
        noteGridOriginYAttribute.attributeType = .floatAttributeType
        noteGridOriginYAttribute.isOptional = false
        noteGridOriginYAttribute.defaultValue = 0.0

        let noteCoverMediaDataAttribute = NSAttributeDescription()
        noteCoverMediaDataAttribute.name = "coverMediaData"
        noteCoverMediaDataAttribute.attributeType = .binaryDataAttributeType
        noteCoverMediaDataAttribute.isOptional = true
        noteCoverMediaDataAttribute.allowsExternalBinaryDataStorage = true

        let noteCoverMediaTypeAttribute = NSAttributeDescription()
        noteCoverMediaTypeAttribute.name = "coverMediaType"
        noteCoverMediaTypeAttribute.attributeType = .stringAttributeType
        noteCoverMediaTypeAttribute.isOptional = true

        let noteCoverUpdatedAtAttribute = NSAttributeDescription()
        noteCoverUpdatedAtAttribute.name = "coverUpdatedAt"
        noteCoverUpdatedAtAttribute.attributeType = .dateAttributeType
        noteCoverUpdatedAtAttribute.isOptional = true

        let noteEmojiAttribute = NSAttributeDescription()
        noteEmojiAttribute.name = "emoji"
        noteEmojiAttribute.attributeType = .stringAttributeType
        noteEmojiAttribute.isOptional = true

        noteEntity.properties = [
            noteIdAttribute,
            noteTitleAttribute,
            noteContentAttribute,
            noteCreatedAtAttribute,
            noteUpdatedAtAttribute,
            noteIsTrashedAttribute,
            notePdfDataAttribute,
            notePageCountAttribute,
            noteGridStyleAttribute,
            noteGridSpacingAttribute,
            noteGridOriginXAttribute,
            noteGridOriginYAttribute,
            noteCoverMediaDataAttribute,
            noteCoverMediaTypeAttribute,
            noteCoverUpdatedAtAttribute,
            noteEmojiAttribute
        ]
        
        let gridColor = NSAttributeDescription()
        gridColor.name = "gridColorHex"
        gridColor.attributeType = .stringAttributeType
        gridColor.isOptional = true
        noteEntity.properties.append(gridColor)

        // --- 3. Entity: Stroke ---
        let strokeEntity = NSEntityDescription()
        strokeEntity.name = "Stroke"
        strokeEntity.managedObjectClassName = "Stroke"
        
        let strokeIdAttribute = NSAttributeDescription()
        strokeIdAttribute.name = "id"
        strokeIdAttribute.attributeType = .UUIDAttributeType
        strokeIdAttribute.isOptional = false
        
        let strokePointsAttribute = NSAttributeDescription()
        strokePointsAttribute.name = "points"
        strokePointsAttribute.attributeType = .stringAttributeType
        strokePointsAttribute.isOptional = false
        
        let strokeColorAttribute = NSAttributeDescription()
        strokeColorAttribute.name = "color"
        strokeColorAttribute.attributeType = .stringAttributeType
        strokeColorAttribute.isOptional = false
        
        let strokeWidthAttribute = NSAttributeDescription()
        strokeWidthAttribute.name = "width"
        strokeWidthAttribute.attributeType = .floatAttributeType
        strokeWidthAttribute.isOptional = false
        
        let strokeCreatedAtAttribute = NSAttributeDescription()
        strokeCreatedAtAttribute.name = "createdAt"
        strokeCreatedAtAttribute.attributeType = .dateAttributeType
        strokeCreatedAtAttribute.isOptional = false
        
        let strokePageIndexAttribute = NSAttributeDescription()
        strokePageIndexAttribute.name = "pageIndex"
        strokePageIndexAttribute.attributeType = .integer16AttributeType
        strokePageIndexAttribute.isOptional = false
        strokePageIndexAttribute.defaultValue = 0
        
        strokeEntity.properties = [
            strokeIdAttribute,
            strokePointsAttribute,
            strokeColorAttribute,
            strokeWidthAttribute,
            strokeCreatedAtAttribute,
            strokePageIndexAttribute
        ]

        // --- 3b. Entity: ShapeObject ---
        let shapeEntity = NSEntityDescription()
        shapeEntity.name = "ShapeObject"
        shapeEntity.managedObjectClassName = "ShapeObject"

        let shapeIdAttribute = NSAttributeDescription()
        shapeIdAttribute.name = "id"
        shapeIdAttribute.attributeType = .UUIDAttributeType
        shapeIdAttribute.isOptional = false

        let shapeKindAttribute = NSAttributeDescription()
        shapeKindAttribute.name = "kind"
        shapeKindAttribute.attributeType = .stringAttributeType
        shapeKindAttribute.isOptional = false

        let shapePointsAttribute = NSAttributeDescription()
        shapePointsAttribute.name = "points"
        shapePointsAttribute.attributeType = .stringAttributeType
        shapePointsAttribute.isOptional = false

        let shapeStrokeColorAttribute = NSAttributeDescription()
        shapeStrokeColorAttribute.name = "strokeColor"
        shapeStrokeColorAttribute.attributeType = .stringAttributeType
        shapeStrokeColorAttribute.isOptional = false

        let shapeStrokeWidthAttribute = NSAttributeDescription()
        shapeStrokeWidthAttribute.name = "strokeWidth"
        shapeStrokeWidthAttribute.attributeType = .floatAttributeType
        shapeStrokeWidthAttribute.isOptional = false

        let shapeFillColorAttribute = NSAttributeDescription()
        shapeFillColorAttribute.name = "fillColor"
        shapeFillColorAttribute.attributeType = .stringAttributeType
        shapeFillColorAttribute.isOptional = true

        let shapeCreatedAtAttribute = NSAttributeDescription()
        shapeCreatedAtAttribute.name = "createdAt"
        shapeCreatedAtAttribute.attributeType = .dateAttributeType
        shapeCreatedAtAttribute.isOptional = false

        let shapePageIndexAttribute = NSAttributeDescription()
        shapePageIndexAttribute.name = "pageIndex"
        shapePageIndexAttribute.attributeType = .integer16AttributeType
        shapePageIndexAttribute.isOptional = false
        shapePageIndexAttribute.defaultValue = 0

        shapeEntity.properties = [
            shapeIdAttribute,
            shapeKindAttribute,
            shapePointsAttribute,
            shapeStrokeColorAttribute,
            shapeStrokeWidthAttribute,
            shapeFillColorAttribute,
            shapeCreatedAtAttribute,
            shapePageIndexAttribute
        ]

        // --- 4. Relationships ---
        // Notebook -> Note (One-to-Many, nullify delete)
        let notebookToNotesRelation = NSRelationshipDescription()
        notebookToNotesRelation.name = "notes"
        notebookToNotesRelation.destinationEntity = noteEntity
        notebookToNotesRelation.minCount = 0
        notebookToNotesRelation.maxCount = 0 // unlimited
        notebookToNotesRelation.deleteRule = .nullifyDeleteRule
        
        // Note -> Notebook (Many-to-One, nullify delete)
        let noteToNotebookRelation = NSRelationshipDescription()
        noteToNotebookRelation.name = "notebook"
        noteToNotebookRelation.destinationEntity = notebookEntity
        noteToNotebookRelation.minCount = 0
        noteToNotebookRelation.maxCount = 1
        noteToNotebookRelation.deleteRule = .nullifyDeleteRule
        
        notebookToNotesRelation.inverseRelationship = noteToNotebookRelation
        noteToNotebookRelation.inverseRelationship = notebookToNotesRelation
        
        // Note -> Stroke (One-to-Many, cascade delete)
        let noteToStrokesRelation = NSRelationshipDescription()
        noteToStrokesRelation.name = "strokes"
        noteToStrokesRelation.destinationEntity = strokeEntity
        noteToStrokesRelation.minCount = 0
        noteToStrokesRelation.maxCount = 0 // unlimited
        noteToStrokesRelation.deleteRule = .cascadeDeleteRule
        
        // Stroke -> Note (Many-to-One, nullify delete)
        let strokeToNoteRelation = NSRelationshipDescription()
        strokeToNoteRelation.name = "note"
        strokeToNoteRelation.destinationEntity = noteEntity
        strokeToNoteRelation.minCount = 0
        strokeToNoteRelation.maxCount = 1
        strokeToNoteRelation.deleteRule = .nullifyDeleteRule
        
        noteToStrokesRelation.inverseRelationship = strokeToNoteRelation
        strokeToNoteRelation.inverseRelationship = noteToStrokesRelation

        // Note -> ShapeObject (One-to-Many, cascade delete)
        let noteToShapesRelation = NSRelationshipDescription()
        noteToShapesRelation.name = "shapes"
        noteToShapesRelation.destinationEntity = shapeEntity
        noteToShapesRelation.minCount = 0
        noteToShapesRelation.maxCount = 0 // unlimited
        noteToShapesRelation.deleteRule = .cascadeDeleteRule

        // ShapeObject -> Note (Many-to-One, nullify delete)
        let shapeToNoteRelation = NSRelationshipDescription()
        shapeToNoteRelation.name = "note"
        shapeToNoteRelation.destinationEntity = noteEntity
        shapeToNoteRelation.minCount = 0
        shapeToNoteRelation.maxCount = 1
        shapeToNoteRelation.deleteRule = .nullifyDeleteRule

        noteToShapesRelation.inverseRelationship = shapeToNoteRelation
        shapeToNoteRelation.inverseRelationship = noteToShapesRelation

        // Add relationships to entities
        notebookEntity.properties.append(notebookToNotesRelation)
        noteEntity.properties.append(noteToNotebookRelation)
        noteEntity.properties.append(noteToStrokesRelation)
        noteEntity.properties.append(noteToShapesRelation)
        strokeEntity.properties.append(strokeToNoteRelation)
        shapeEntity.properties.append(shapeToNoteRelation)

        let color = NSAttributeDescription()
        color.name = "colorIndex"
        color.attributeType = .integer16AttributeType
        color.isOptional = true

        let colorHex = NSAttributeDescription()
        colorHex.name = "colorHex"
        colorHex.attributeType = .stringAttributeType
        colorHex.isOptional = true
        notebookEntity.properties.append(colorHex)

        let parent = NSRelationshipDescription()
        parent.name = "parent"
        parent.destinationEntity = notebookEntity
        parent.maxCount = 1
        parent.deleteRule = .nullifyDeleteRule

        let children = NSRelationshipDescription()
        children.name = "children"
        children.destinationEntity = notebookEntity
        children.maxCount = 0
        children.deleteRule = .nullifyDeleteRule
        parent.inverseRelationship = children
        children.inverseRelationship = parent
        notebookEntity.properties += [color, parent, children]

        // --- 5. Configure Model ---
        model.entities = [notebookEntity, noteEntity, strokeEntity, shapeEntity]
        
        return model
    }

    public init(storeURL: URL? = nil, defaults: UserDefaults = .standard) {
        let model = Self.makeModel()
        let persistentContainer = NSPersistentContainer(name: "EasyNotesModel", managedObjectModel: model)
        let defaultURL = persistentContainer.persistentStoreDescriptions.first?.url
            ?? Self.defaultStoreDirectoryURL.appendingPathComponent(Self.storeFileName)

        let preferredURL = storeURL ?? Self.resolvedCustomStoreURL(from: defaults)
        let targetURL = preferredURL ?? defaultURL

        let description = Self.makeStoreDescription(url: targetURL)
        persistentContainer.persistentStoreDescriptions = [description]

        var initialError: NSError?
        persistentContainer.loadPersistentStores { _, error in
            initialError = error as NSError?
        }

        if let error = initialError {
            if preferredURL != nil && targetURL.standardizedFileURL != defaultURL.standardizedFileURL {
                // Safe fallback to the default store location if a custom directory fails to load.
                let fallbackDescription = Self.makeStoreDescription(url: defaultURL)
                persistentContainer.persistentStoreDescriptions = [fallbackDescription]
                persistentContainer.loadPersistentStores { _, fallbackError in
                    if let fallbackError = fallbackError as NSError? {
                        fatalError("Unresolved error \(fallbackError), \(fallbackError.userInfo)")
                    }
                }
            } else {
                fatalError("Unresolved error \(error), \(error.userInfo)")
            }
        }

        persistentContainer.viewContext.automaticallyMergesChangesFromParent = true
        self.container = persistentContainer
    }

    private static func makeStoreDescription(url: URL) -> NSPersistentStoreDescription {
        let description = NSPersistentStoreDescription(url: url)
        description.type = NSSQLiteStoreType
        description.shouldMigrateStoreAutomatically = true
        description.shouldInferMappingModelAutomatically = true
        return description
    }

    private static func resolvedCustomStoreURL(from defaults: UserDefaults) -> URL? {
        guard let rawPath = defaults.string(forKey: AppSettingsStore.Keys.customStoragePath)?
            .trimmingCharacters(in: .whitespacesAndNewlines),
              !rawPath.isEmpty else {
            return nil
        }
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: rawPath, isDirectory: &isDirectory),
              isDirectory.boolValue else {
            return nil
        }
        return URL(fileURLWithPath: rawPath, isDirectory: true)
            .appendingPathComponent(storeFileName)
    }

    /// Saves pending changes and safely copies the active SQLite database (plus WAL/SHM sidecars
    /// if present) into `directoryURL/EasyNotesModel.sqlite` without ever deleting the original files.
    public func migrateStoreCopy(to directoryURL: URL) throws -> URL {
        saveContext()

        guard let sourceURL = currentStoreURL else {
            throw CoreDataStorageError.storeUnavailable
        }

        let fileManager = FileManager.default
        let standardizedDirectory = directoryURL.standardizedFileURL
        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: standardizedDirectory.path, isDirectory: &isDirectory),
              isDirectory.boolValue,
              fileManager.isWritableFile(atPath: standardizedDirectory.path) else {
            throw CoreDataStorageError.invalidDestinationDirectory(standardizedDirectory.path)
        }

        let destinationURL = standardizedDirectory.appendingPathComponent(Self.storeFileName)
        if sourceURL.standardizedFileURL == destinationURL.standardizedFileURL {
            return destinationURL
        }

        if fileManager.fileExists(atPath: destinationURL.path) {
            throw CoreDataStorageError.destinationAlreadyExists(destinationURL)
        }

        guard fileManager.fileExists(atPath: sourceURL.path) else {
            throw CoreDataStorageError.storeUnavailable
        }

        var copiedURLs: [URL] = []
        do {
            try fileManager.copyItem(at: sourceURL, to: destinationURL)
            copiedURLs.append(destinationURL)

            for suffix in ["-wal", "-shm"] {
                let sidecarSource = URL(fileURLWithPath: sourceURL.path + suffix)
                let sidecarDestination = URL(fileURLWithPath: destinationURL.path + suffix)
                if fileManager.fileExists(atPath: sidecarSource.path) {
                    if fileManager.fileExists(atPath: sidecarDestination.path) {
                        throw CoreDataStorageError.destinationAlreadyExists(sidecarDestination)
                    }
                    try fileManager.copyItem(at: sidecarSource, to: sidecarDestination)
                    copiedURLs.append(sidecarDestination)
                }
            }

            let attributes = try fileManager.attributesOfItem(atPath: destinationURL.path)
            let fileSize = (attributes[.size] as? NSNumber)?.int64Value ?? 0
            guard fileSize > 0 else {
                throw CoreDataStorageError.verificationFailed(destinationURL)
            }
            return destinationURL
        } catch {
            // Roll back only newly created files in the destination; never touch source files.
            for copied in copiedURLs {
                try? fileManager.removeItem(at: copied)
            }
            throw error
        }
    }
    
    public func saveContext() {
        let context = container.viewContext
        if context.hasChanges {
            do {
                try context.save()
            } catch {
                let nserror = error as NSError
                fatalError("Unresolved error \(nserror), \(nserror.userInfo)")
            }
        }
    }
}
