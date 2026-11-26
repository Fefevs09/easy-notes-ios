import CoreData

public enum CoreDataStorageError: LocalizedError, Equatable {
    case storeUnavailable
    case invalidDestinationDirectory(String)
    case destinationMatchesSource(URL)
    case destinationAlreadyExists(URL)
    case verificationFailed(URL)

    public var errorDescription: String? {
        switch self {
        case .storeUnavailable:
            return "Não foi possível localizar o arquivo de banco de dados atual."
        case .invalidDestinationDirectory(let path):
            return "A pasta de destino não é um diretório acessível: \(path)"
        case .destinationMatchesSource:
            return "A pasta selecionada já é o local atual do banco de dados."
        case .destinationAlreadyExists(let url):
            return "Já existe um banco de dados do Easy Notes na pasta selecionada (\(url.lastPathComponent)). Escolha uma pasta vazia para evitar sobrescrever dados."
        case .verificationFailed(let url):
            return "A verificação do arquivo copiado falhou em \(url.path). Os dados originais foram preservados."
        }
    }
}

public class CoreDataStack {
    public static let shared = CoreDataStack(welcome: .shared)
    public static let storeFileName = "EasyNotesModel.sqlite"
    
    public let container: NSPersistentContainer
    public private(set) var storageLoadWarning: String?
    public var didFallbackToDefaultStore: Bool { storageLoadWarning != nil }

    private var accessedSecurityScopedDirectoryURL: URL?

    deinit {
        accessedSecurityScopedDirectoryURL?.stopAccessingSecurityScopedResource()
    }
    
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
    
    // Frozen schema from 49aa070. Keep this definition available to migrate existing SQLite stores.
    static func makeBaseModel() -> NSManagedObjectModel {
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

    private struct CustomStoreResolution {
        let storeURL: URL?
        let accessedDirectoryURL: URL?
        let warning: String?
    }

    public convenience init(storeURL: URL? = nil, defaults: UserDefaults = .standard) {
        self.init(storeURL: storeURL, defaults: defaults, welcome: nil)
    }

    init(
        storeURL: URL? = nil,
        defaults: UserDefaults = .standard,
        welcome: WelcomeState?,
        defaultStoreDirectory: URL? = nil
    ) {
        let model = Self.makeModel()
        let persistentContainer = NSPersistentContainer(name: "EasyNotesModel", managedObjectModel: model)
        let defaultURL = defaultStoreDirectory?.appendingPathComponent(Self.storeFileName)
            ?? persistentContainer.persistentStoreDescriptions.first?.url
            ?? Self.defaultStoreDirectoryURL.appendingPathComponent(Self.storeFileName)

        let preferredURL: URL?
        var accessedDirectory: URL?
        var loadWarning: String?

        if let explicitStoreURL = storeURL {
            preferredURL = explicitStoreURL
        } else {
            let resolution = Self.resolveCustomStoreURL(from: defaults)
            preferredURL = resolution.storeURL
            accessedDirectory = resolution.accessedDirectoryURL
            loadWarning = resolution.warning
        }

        let targetURL = preferredURL ?? defaultURL
        welcome?.prepare(
            hasExistingInstallation: loadWarning != nil
                || (storeURL == nil && preferredURL != nil)
                || FileManager.default.fileExists(atPath: targetURL.path)
                || FileManager.default.fileExists(atPath: defaultURL.path)
        )

        do {
            try Self.loadSQLiteStore(at: targetURL, into: persistentContainer)
        } catch {
            if preferredURL != nil && targetURL.standardizedFileURL != defaultURL.standardizedFileURL {
                accessedDirectory?.stopAccessingSecurityScopedResource()
                accessedDirectory = nil
                loadWarning = "Não foi possível abrir o banco em \(targetURL.deletingLastPathComponent().path) (\(error.localizedDescription)). O Easy Notes abriu o banco padrão como fallback."

                do {
                    try Self.loadSQLiteStore(at: defaultURL, into: persistentContainer)
                } catch {
                    fatalError("Unresolved error \(error as NSError)")
                }
            } else {
                fatalError("Unresolved error \(error as NSError)")
            }
        }

        persistentContainer.viewContext.automaticallyMergesChangesFromParent = true
        self.container = persistentContainer
        self.accessedSecurityScopedDirectoryURL = accessedDirectory
        self.storageLoadWarning = loadWarning
    }

    private static func resolveCustomStoreURL(from defaults: UserDefaults) -> CustomStoreResolution {
        let rawPath = defaults.string(forKey: AppSettingsStore.Keys.customStoragePath)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedPath = (rawPath?.isEmpty == false) ? rawPath : nil
        let bookmarkData = defaults.data(forKey: AppSettingsStore.Keys.storageDirectoryBookmark)

        guard normalizedPath != nil || bookmarkData != nil else {
            return CustomStoreResolution(storeURL: nil, accessedDirectoryURL: nil, warning: nil)
        }

        var candidateDirectory: URL?
        var accessedDirectory: URL?

        if let bookmarkData {
            var isStale = false
            if let resolvedURL = try? URL(
                resolvingBookmarkData: bookmarkData,
                options: .withSecurityScope,
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            ) {
                if resolvedURL.startAccessingSecurityScopedResource() {
                    accessedDirectory = resolvedURL
                }
                if isStale, let refreshed = AppSettingsStore.makeSecurityScopedBookmark(for: resolvedURL) {
                    defaults.set(refreshed, forKey: AppSettingsStore.Keys.storageDirectoryBookmark)
                }
                candidateDirectory = resolvedURL.standardizedFileURL
            }
        }

        if candidateDirectory == nil, let normalizedPath {
            candidateDirectory = URL(fileURLWithPath: normalizedPath, isDirectory: true).standardizedFileURL
        }

        guard let directoryURL = candidateDirectory else {
            accessedDirectory?.stopAccessingSecurityScopedResource()
            return CustomStoreResolution(
                storeURL: nil,
                accessedDirectoryURL: nil,
                warning: "Não foi possível resolver a pasta de armazenamento configurada. O Easy Notes abriu o banco padrão como fallback."
            )
        }

        var isDirectory: ObjCBool = false
        let exists = FileManager.default.fileExists(atPath: directoryURL.path, isDirectory: &isDirectory)
        guard exists, isDirectory.boolValue, FileManager.default.isWritableFile(atPath: directoryURL.path) else {
            accessedDirectory?.stopAccessingSecurityScopedResource()
            return CustomStoreResolution(
                storeURL: nil,
                accessedDirectoryURL: nil,
                warning: "A pasta de armazenamento configurada (\(directoryURL.path)) não existe ou está sem permissão de escrita. O Easy Notes abriu o banco padrão como fallback."
            )
        }

        return CustomStoreResolution(
            storeURL: directoryURL.appendingPathComponent(storeFileName),
            accessedDirectoryURL: accessedDirectory,
            warning: nil
        )
    }

    /// Saves pending changes and safely copies the active SQLite database (including WAL checkpoint
    /// and external binary data storage) into `directoryURL/EasyNotesModel.sqlite` without modifying
    /// or deleting the original files.
    public func migrateStoreCopy(to directoryURL: URL) throws -> URL {
        if viewContext.hasChanges {
            try viewContext.save()
        }

        guard let sourceURL = currentStoreURL else {
            throw CoreDataStorageError.storeUnavailable
        }

        let didStartAccessing = directoryURL.startAccessingSecurityScopedResource()
        defer {
            if didStartAccessing {
                directoryURL.stopAccessingSecurityScopedResource()
            }
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
            throw CoreDataStorageError.destinationMatchesSource(destinationURL)
        }

        if fileManager.fileExists(atPath: destinationURL.path) {
            throw CoreDataStorageError.destinationAlreadyExists(destinationURL)
        }

        guard fileManager.fileExists(atPath: sourceURL.path) else {
            throw CoreDataStorageError.storeUnavailable
        }

        let storeOptions: [AnyHashable: Any] = [
            NSMigratePersistentStoresAutomaticallyOption: true,
            NSInferMappingModelAutomaticallyOption: true
        ]

        let supportDirName = "." + destinationURL.deletingPathExtension().lastPathComponent + "_SUPPORT"
        let destinationSupportDir = standardizedDirectory.appendingPathComponent(supportDirName, isDirectory: true)
        let supportDirExistedBefore = fileManager.fileExists(atPath: destinationSupportDir.path)

        do {
            try container.persistentStoreCoordinator.replacePersistentStore(
                at: destinationURL,
                destinationOptions: storeOptions,
                withPersistentStoreFrom: sourceURL,
                sourceOptions: storeOptions,
                ofType: NSSQLiteStoreType
            )

            let attributes = try fileManager.attributesOfItem(atPath: destinationURL.path)
            let fileSize = (attributes[.size] as? NSNumber)?.int64Value ?? 0
            guard fileSize > 0 else {
                throw CoreDataStorageError.verificationFailed(destinationURL)
            }

            // Validate the copied SQLite store (and external storage metadata) by opening it read-only.
            let verificationCoordinator = NSPersistentStoreCoordinator(managedObjectModel: container.managedObjectModel)
            do {
                let verifiedStore = try verificationCoordinator.addPersistentStore(
                    ofType: NSSQLiteStoreType,
                    configurationName: nil,
                    at: destinationURL,
                    options: [NSReadOnlyPersistentStoreOption: true]
                )
                try? verificationCoordinator.remove(verifiedStore)
            } catch {
                throw CoreDataStorageError.verificationFailed(destinationURL)
            }

            return destinationURL
        } catch {
            // Roll back only newly created files in the destination; never touch source files.
            try? fileManager.removeItem(at: destinationURL)
            try? fileManager.removeItem(atPath: destinationURL.path + "-wal")
            try? fileManager.removeItem(atPath: destinationURL.path + "-shm")
            if !supportDirExistedBefore {
                try? fileManager.removeItem(at: destinationSupportDir)
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
