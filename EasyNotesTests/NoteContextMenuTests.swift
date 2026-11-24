import AppKit
import CoreData
import ImageIO
import PDFKit
import UniformTypeIdentifiers
import XCTest

final class NoteContextMenuTests: XCTestCase {
    private var tempDirectories: [URL] = []

    override func tearDown() {
        for directory in tempDirectories {
            try? FileManager.default.removeItem(at: directory)
        }
        tempDirectories.removeAll()
        super.tearDown()
    }

    // MARK: - Helpers

    private func makeTempDirectory() throws -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("EasyNotesContextMenuTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        tempDirectories.append(dir)
        return dir
    }

    private func makeImageData(type: UTType, width: Int = 24, height: Int = 24, color: CGColor) throws -> Data {
        guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB),
              let cgContext = CGContext(
                  data: nil,
                  width: width,
                  height: height,
                  bitsPerComponent: 8,
                  bytesPerRow: width * 4,
                  space: colorSpace,
                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
              ) else {
            throw NSError(domain: "NoteContextMenuTests", code: 1)
        }
        cgContext.setFillColor(color)
        cgContext.fill(CGRect(x: 0, y: 0, width: width, height: height))
        guard let cgImage = cgContext.makeImage() else {
            throw NSError(domain: "NoteContextMenuTests", code: 2)
        }

        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(
            data as CFMutableData,
            type.identifier as CFString,
            1,
            nil
        ) else {
            throw NSError(domain: "NoteContextMenuTests", code: 3)
        }
        CGImageDestinationAddImage(destination, cgImage, nil)
        guard CGImageDestinationFinalize(destination) else {
            throw NSError(domain: "NoteContextMenuTests", code: 4)
        }
        return data as Data
    }

    private func makePDFData() throws -> Data {
        let doc = PDFDocument()
        doc.insert(PDFPage(), at: 0)
        guard let data = doc.dataRepresentation() else {
            throw NSError(domain: "NoteContextMenuTests", code: 5)
        }
        return data
    }

    private func closeSQLiteContainer(_ container: NSPersistentContainer) throws {
        for store in container.persistentStoreCoordinator.persistentStores {
            try container.persistentStoreCoordinator.remove(store)
        }
    }

    /// Exact copy of the pre-FEAT-02 managed object model (commit 53fce25: includes FEAT-03 cover attributes, without `emoji`).
    /// Uses generic `NSManagedObject` class names so XCTest avoids duplicate-class entity ambiguity warnings.
    private func makePreEmojiLegacyModel() -> NSManagedObjectModel {
        let model = NSManagedObjectModel()

        let notebookEntity = NSEntityDescription()
        notebookEntity.name = "Notebook"
        notebookEntity.managedObjectClassName = NSStringFromClass(NSManagedObject.self)

        let notebookId = NSAttributeDescription()
        notebookId.name = "id"
        notebookId.attributeType = .UUIDAttributeType
        notebookId.isOptional = false

        let notebookName = NSAttributeDescription()
        notebookName.name = "name"
        notebookName.attributeType = .stringAttributeType
        notebookName.isOptional = false

        notebookEntity.properties = [notebookId, notebookName]

        let noteEntity = NSEntityDescription()
        noteEntity.name = "Note"
        noteEntity.managedObjectClassName = NSStringFromClass(NSManagedObject.self)

        let noteId = NSAttributeDescription()
        noteId.name = "id"
        noteId.attributeType = .UUIDAttributeType
        noteId.isOptional = false

        let noteTitle = NSAttributeDescription()
        noteTitle.name = "title"
        noteTitle.attributeType = .stringAttributeType
        noteTitle.isOptional = false

        let noteContent = NSAttributeDescription()
        noteContent.name = "content"
        noteContent.attributeType = .stringAttributeType
        noteContent.isOptional = false

        let noteCreatedAt = NSAttributeDescription()
        noteCreatedAt.name = "createdAt"
        noteCreatedAt.attributeType = .dateAttributeType
        noteCreatedAt.isOptional = false

        let noteUpdatedAt = NSAttributeDescription()
        noteUpdatedAt.name = "updatedAt"
        noteUpdatedAt.attributeType = .dateAttributeType
        noteUpdatedAt.isOptional = false

        let noteIsTrashed = NSAttributeDescription()
        noteIsTrashed.name = "isTrashed"
        noteIsTrashed.attributeType = .booleanAttributeType
        noteIsTrashed.isOptional = false
        noteIsTrashed.defaultValue = false

        let notePdfData = NSAttributeDescription()
        notePdfData.name = "pdfData"
        notePdfData.attributeType = .binaryDataAttributeType
        notePdfData.isOptional = true

        let notePageCount = NSAttributeDescription()
        notePageCount.name = "pageCount"
        notePageCount.attributeType = .integer16AttributeType
        notePageCount.isOptional = false
        notePageCount.defaultValue = 1

        let noteGridStyle = NSAttributeDescription()
        noteGridStyle.name = "gridStyle"
        noteGridStyle.attributeType = .stringAttributeType
        noteGridStyle.isOptional = false
        noteGridStyle.defaultValue = "none"

        let noteGridSpacing = NSAttributeDescription()
        noteGridSpacing.name = "gridSpacing"
        noteGridSpacing.attributeType = .floatAttributeType
        noteGridSpacing.isOptional = false
        noteGridSpacing.defaultValue = 24.0

        let noteGridOriginX = NSAttributeDescription()
        noteGridOriginX.name = "gridOriginX"
        noteGridOriginX.attributeType = .floatAttributeType
        noteGridOriginX.isOptional = false
        noteGridOriginX.defaultValue = 0.0

        let noteGridOriginY = NSAttributeDescription()
        noteGridOriginY.name = "gridOriginY"
        noteGridOriginY.attributeType = .floatAttributeType
        noteGridOriginY.isOptional = false
        noteGridOriginY.defaultValue = 0.0

        let noteCoverMediaData = NSAttributeDescription()
        noteCoverMediaData.name = "coverMediaData"
        noteCoverMediaData.attributeType = .binaryDataAttributeType
        noteCoverMediaData.isOptional = true
        noteCoverMediaData.allowsExternalBinaryDataStorage = true

        let noteCoverMediaType = NSAttributeDescription()
        noteCoverMediaType.name = "coverMediaType"
        noteCoverMediaType.attributeType = .stringAttributeType
        noteCoverMediaType.isOptional = true

        let noteCoverUpdatedAt = NSAttributeDescription()
        noteCoverUpdatedAt.name = "coverUpdatedAt"
        noteCoverUpdatedAt.attributeType = .dateAttributeType
        noteCoverUpdatedAt.isOptional = true

        noteEntity.properties = [
            noteId,
            noteTitle,
            noteContent,
            noteCreatedAt,
            noteUpdatedAt,
            noteIsTrashed,
            notePdfData,
            notePageCount,
            noteGridStyle,
            noteGridSpacing,
            noteGridOriginX,
            noteGridOriginY,
            noteCoverMediaData,
            noteCoverMediaType,
            noteCoverUpdatedAt
        ]

        let strokeEntity = NSEntityDescription()
        strokeEntity.name = "Stroke"
        strokeEntity.managedObjectClassName = NSStringFromClass(NSManagedObject.self)

        let strokeId = NSAttributeDescription()
        strokeId.name = "id"
        strokeId.attributeType = .UUIDAttributeType
        strokeId.isOptional = false

        let strokePoints = NSAttributeDescription()
        strokePoints.name = "points"
        strokePoints.attributeType = .stringAttributeType
        strokePoints.isOptional = false

        let strokeColor = NSAttributeDescription()
        strokeColor.name = "color"
        strokeColor.attributeType = .stringAttributeType
        strokeColor.isOptional = false

        let strokeWidth = NSAttributeDescription()
        strokeWidth.name = "width"
        strokeWidth.attributeType = .floatAttributeType
        strokeWidth.isOptional = false

        let strokeCreatedAt = NSAttributeDescription()
        strokeCreatedAt.name = "createdAt"
        strokeCreatedAt.attributeType = .dateAttributeType
        strokeCreatedAt.isOptional = false

        let strokePageIndex = NSAttributeDescription()
        strokePageIndex.name = "pageIndex"
        strokePageIndex.attributeType = .integer16AttributeType
        strokePageIndex.isOptional = false
        strokePageIndex.defaultValue = 0

        strokeEntity.properties = [
            strokeId,
            strokePoints,
            strokeColor,
            strokeWidth,
            strokeCreatedAt,
            strokePageIndex
        ]

        let shapeEntity = NSEntityDescription()
        shapeEntity.name = "ShapeObject"
        shapeEntity.managedObjectClassName = NSStringFromClass(NSManagedObject.self)

        let shapeId = NSAttributeDescription()
        shapeId.name = "id"
        shapeId.attributeType = .UUIDAttributeType
        shapeId.isOptional = false

        let shapeKind = NSAttributeDescription()
        shapeKind.name = "kind"
        shapeKind.attributeType = .stringAttributeType
        shapeKind.isOptional = false

        let shapePoints = NSAttributeDescription()
        shapePoints.name = "points"
        shapePoints.attributeType = .stringAttributeType
        shapePoints.isOptional = false

        let shapeStrokeColor = NSAttributeDescription()
        shapeStrokeColor.name = "strokeColor"
        shapeStrokeColor.attributeType = .stringAttributeType
        shapeStrokeColor.isOptional = false

        let shapeStrokeWidth = NSAttributeDescription()
        shapeStrokeWidth.name = "strokeWidth"
        shapeStrokeWidth.attributeType = .floatAttributeType
        shapeStrokeWidth.isOptional = false

        let shapeFillColor = NSAttributeDescription()
        shapeFillColor.name = "fillColor"
        shapeFillColor.attributeType = .stringAttributeType
        shapeFillColor.isOptional = true

        let shapeCreatedAt = NSAttributeDescription()
        shapeCreatedAt.name = "createdAt"
        shapeCreatedAt.attributeType = .dateAttributeType
        shapeCreatedAt.isOptional = false

        let shapePageIndex = NSAttributeDescription()
        shapePageIndex.name = "pageIndex"
        shapePageIndex.attributeType = .integer16AttributeType
        shapePageIndex.isOptional = false
        shapePageIndex.defaultValue = 0

        shapeEntity.properties = [
            shapeId,
            shapeKind,
            shapePoints,
            shapeStrokeColor,
            shapeStrokeWidth,
            shapeFillColor,
            shapeCreatedAt,
            shapePageIndex
        ]

        let notebookToNotes = NSRelationshipDescription()
        notebookToNotes.name = "notes"
        notebookToNotes.destinationEntity = noteEntity
        notebookToNotes.minCount = 0
        notebookToNotes.maxCount = 0
        notebookToNotes.deleteRule = .cascadeDeleteRule

        let noteToNotebook = NSRelationshipDescription()
        noteToNotebook.name = "notebook"
        noteToNotebook.destinationEntity = notebookEntity
        noteToNotebook.minCount = 0
        noteToNotebook.maxCount = 1
        noteToNotebook.deleteRule = .nullifyDeleteRule

        notebookToNotes.inverseRelationship = noteToNotebook
        noteToNotebook.inverseRelationship = notebookToNotes

        let noteToStrokes = NSRelationshipDescription()
        noteToStrokes.name = "strokes"
        noteToStrokes.destinationEntity = strokeEntity
        noteToStrokes.minCount = 0
        noteToStrokes.maxCount = 0
        noteToStrokes.deleteRule = .cascadeDeleteRule

        let strokeToNote = NSRelationshipDescription()
        strokeToNote.name = "note"
        strokeToNote.destinationEntity = noteEntity
        strokeToNote.minCount = 0
        strokeToNote.maxCount = 1
        strokeToNote.deleteRule = .nullifyDeleteRule

        noteToStrokes.inverseRelationship = strokeToNote
        strokeToNote.inverseRelationship = noteToStrokes

        let noteToShapes = NSRelationshipDescription()
        noteToShapes.name = "shapes"
        noteToShapes.destinationEntity = shapeEntity
        noteToShapes.minCount = 0
        noteToShapes.maxCount = 0
        noteToShapes.deleteRule = .cascadeDeleteRule

        let shapeToNote = NSRelationshipDescription()
        shapeToNote.name = "note"
        shapeToNote.destinationEntity = noteEntity
        shapeToNote.minCount = 0
        shapeToNote.maxCount = 1
        shapeToNote.deleteRule = .nullifyDeleteRule

        noteToShapes.inverseRelationship = shapeToNote
        shapeToNote.inverseRelationship = noteToShapes

        notebookEntity.properties.append(notebookToNotes)
        noteEntity.properties.append(noteToNotebook)
        noteEntity.properties.append(noteToStrokes)
        noteEntity.properties.append(noteToShapes)
        strokeEntity.properties.append(strokeToNote)
        shapeEntity.properties.append(shapeToNote)

        model.entities = [notebookEntity, noteEntity, strokeEntity, shapeEntity]
        return model
    }

    // MARK: - 1. Legacy Pre-Emoji SQLite Migration

    func testLegacyPreEmojiSQLiteStoreMigratesAndPreservesCoverAndEntities() throws {
        let dir = try makeTempDirectory()
        let storeURL = dir.appendingPathComponent("PreEmojiEasyNotes.sqlite")
        let pngCover = try makeImageData(type: .png, color: CGColor(red: 0.435, green: 0.322, blue: 0.878, alpha: 1.0))
        let pdfBytes = try makePDFData()

        let notebookUUID = UUID()
        let noteUUID = UUID()
        let strokeUUID = UUID()
        let shapeUUID = UUID()
        let timestamp = Date(timeIntervalSince1970: 1_710_000_000)

        let legacyModel = makePreEmojiLegacyModel()
        let legacyContainer = NSPersistentContainer(name: "PreEmojiEasyNotes", managedObjectModel: legacyModel)
        let legacyDescription = NSPersistentStoreDescription(url: storeURL)
        legacyDescription.type = NSSQLiteStoreType
        legacyContainer.persistentStoreDescriptions = [legacyDescription]

        var legacyLoadError: Error?
        legacyContainer.loadPersistentStores { _, error in
            legacyLoadError = error
        }
        XCTAssertNil(legacyLoadError)

        let legacyContext = legacyContainer.viewContext
        let notebook = NSEntityDescription.insertNewObject(forEntityName: "Notebook", into: legacyContext)
        notebook.setValue(notebookUUID, forKey: "id")
        notebook.setValue("Caderno 53fce25", forKey: "name")

        let note = NSEntityDescription.insertNewObject(forEntityName: "Note", into: legacyContext)
        note.setValue(noteUUID, forKey: "id")
        note.setValue("Nota com Capa e PDF", forKey: "title")
        note.setValue("Conteúdo pré-emoji", forKey: "content")
        note.setValue(timestamp, forKey: "createdAt")
        note.setValue(timestamp, forKey: "updatedAt")
        note.setValue(false, forKey: "isTrashed")
        note.setValue(pdfBytes, forKey: "pdfData")
        note.setValue(Int16(1), forKey: "pageCount")
        note.setValue("dots", forKey: "gridStyle")
        note.setValue(Float(24.0), forKey: "gridSpacing")
        note.setValue(Float(100.0), forKey: "gridOriginX")
        note.setValue(Float(200.0), forKey: "gridOriginY")
        note.setValue(pngCover, forKey: "coverMediaData")
        note.setValue(UTType.png.identifier, forKey: "coverMediaType")
        note.setValue(timestamp, forKey: "coverUpdatedAt")
        note.setValue(notebook, forKey: "notebook")

        let stroke = NSEntityDescription.insertNewObject(forEntityName: "Stroke", into: legacyContext)
        stroke.setValue(strokeUUID, forKey: "id")
        stroke.setValue("15.0,25.0;60.0,90.0", forKey: "points")
        stroke.setValue("#2B2A33", forKey: "color")
        stroke.setValue(Float(3.0), forKey: "width")
        stroke.setValue(timestamp, forKey: "createdAt")
        stroke.setValue(Int16(0), forKey: "pageIndex")
        stroke.setValue(note, forKey: "note")

        let shape = NSEntityDescription.insertNewObject(forEntityName: "ShapeObject", into: legacyContext)
        shape.setValue(shapeUUID, forKey: "id")
        shape.setValue("ellipse", forKey: "kind")
        shape.setValue("40.0,40.0;140.0,120.0", forKey: "points")
        shape.setValue("#6F52E0", forKey: "strokeColor")
        shape.setValue(Float(2.0), forKey: "strokeWidth")
        shape.setValue(nil, forKey: "fillColor")
        shape.setValue(timestamp, forKey: "createdAt")
        shape.setValue(Int16(0), forKey: "pageIndex")
        shape.setValue(note, forKey: "note")

        try legacyContext.save()
        try closeSQLiteContainer(legacyContainer)

        let preMigrationMetadata = try NSPersistentStoreCoordinator.metadataForPersistentStore(
            ofType: NSSQLiteStoreType,
            at: storeURL,
            options: nil
        )
        XCTAssertFalse(
            TestSupport.sharedModel.isConfiguration(withName: nil, compatibleWithStoreMetadata: preMigrationMetadata)
        )

        let migratedContainer = try TestSupport.makeSQLiteContainer(at: storeURL)
        let migratedMetadata = try NSPersistentStoreCoordinator.metadataForPersistentStore(
            ofType: NSSQLiteStoreType,
            at: storeURL,
            options: nil
        )
        XCTAssertTrue(
            TestSupport.sharedModel.isConfiguration(withName: nil, compatibleWithStoreMetadata: migratedMetadata)
        )

        let viewModel = NoteViewModel(context: migratedContainer.viewContext, coverCache: NoteCoverCache())
        XCTAssertEqual(viewModel.notebooks.count, 1)
        XCTAssertEqual(viewModel.notes.count, 1)

        let migratedNote = try XCTUnwrap(viewModel.notes.first { $0.id == noteUUID })
        XCTAssertNil(migratedNote.emoji)
        XCTAssertNil(migratedNote.displayEmoji)
        XCTAssertEqual(migratedNote.title, "Nota com Capa e PDF")
        XCTAssertEqual(migratedNote.content, "Conteúdo pré-emoji")
        XCTAssertEqual(migratedNote.notebook?.id, notebookUUID)
        XCTAssertEqual(migratedNote.pdfData, pdfBytes)
        XCTAssertTrue(migratedNote.hasCustomCover)
        XCTAssertEqual(migratedNote.coverMediaData, pngCover)
        XCTAssertEqual(migratedNote.coverMediaType, UTType.png.identifier)
        XCTAssertEqual(migratedNote.coverUpdatedAt, timestamp)
        XCTAssertEqual(migratedNote.strokesArray.first?.id, strokeUUID)
        XCTAssertEqual(migratedNote.shapesArray.first?.id, shapeUUID)

        // Apply emoji via setEmoji, reopen SQLite again, and validate persistence.
        try viewModel.setEmoji("🚀", for: migratedNote)
        try closeSQLiteContainer(migratedContainer)

        let reopenedContainer = try TestSupport.makeSQLiteContainer(at: storeURL)
        let reopenedViewModel = NoteViewModel(context: reopenedContainer.viewContext, coverCache: NoteCoverCache())
        let reopenedNote = try XCTUnwrap(reopenedViewModel.notes.first { $0.id == noteUUID })

        XCTAssertEqual(reopenedNote.emoji, "🚀")
        XCTAssertEqual(reopenedNote.displayEmoji, "🚀")
        XCTAssertEqual(reopenedNote.title, "Nota com Capa e PDF")
        XCTAssertEqual(reopenedNote.coverMediaData, pngCover)
        XCTAssertEqual(reopenedNote.pdfData, pdfBytes)
        XCTAssertEqual(reopenedNote.strokesArray.first?.id, strokeUUID)
        XCTAssertEqual(reopenedNote.shapesArray.first?.id, shapeUUID)

        try closeSQLiteContainer(reopenedContainer)
    }

    // MARK: - 2. Emoji Contract: Normalization, Idempotency, Target Isolation & Rollback

    func testSetEmojiNormalizationIdempotencyTargetIsolationAndRollback() throws {
        let (viewModel, context) = TestSupport.makeInMemoryViewModel()
        let pngCover = try makeImageData(type: .png, color: CGColor(red: 0.2, green: 0.6, blue: 0.4, alpha: 1.0))

        viewModel.addNote(title: "Nota A", content: "A")
        let noteA = try XCTUnwrap(viewModel.selectedNote)
        viewModel.addNote(title: "Nota B", content: "B")
        let noteB = try XCTUnwrap(viewModel.selectedNote)
        try viewModel.setCover(for: noteB, data: pngCover, contentType: .png)

        let stroke = Stroke(context: context)
        stroke.id = UUID()
        stroke.points = "0.0,0.0;10.0,10.0"
        stroke.color = "#000000"
        stroke.width = 2.0
        stroke.createdAt = Date()
        stroke.pageIndex = 0
        stroke.note = noteB

        let shape = ShapeObject(context: context)
        shape.id = UUID()
        shape.kind = "line"
        shape.points = "10.0,10.0;30.0,30.0"
        shape.strokeColor = "#6F52E0"
        shape.strokeWidth = 2.0
        shape.createdAt = Date()
        shape.pageIndex = 0
        shape.note = noteB
        try context.save()

        let expectedPDF = noteB.pdfData
        let expectedNotebook = noteB.notebook

        // Keep noteA selected while mutating unselected noteB.
        viewModel.selectedNote = noteA

        try viewModel.setEmoji("📝", for: noteB)
        XCTAssertEqual(noteB.emoji, "📝")
        XCTAssertEqual(noteB.displayEmoji, "📝")
        XCTAssertNil(noteA.emoji)
        XCTAssertTrue(viewModel.selectedNote === noteA)

        // Multi-character string with leading/trailing spaces -> keeps only first grapheme cluster.
        try viewModel.setEmoji("  🔥extra  ", for: noteB)
        XCTAssertEqual(noteB.emoji, "🔥")

        // Composite ZWJ emoji preserved intact as single Character.
        let zwjEmoji = "👨‍💻"
        try viewModel.setEmoji("  \(zwjEmoji)🎨  ", for: noteB)
        XCTAssertEqual(noteB.emoji, zwjEmoji)
        XCTAssertEqual(noteB.displayEmoji, zwjEmoji)

        // Flag (regional indicator pair) preserved intact.
        try viewModel.setEmoji("🇧🇷🇺🇸", for: noteB)
        XCTAssertEqual(noteB.emoji, "🇧🇷")

        // Variation selector emoji preserved intact.
        try viewModel.setEmoji("🗓️📌", for: noteB)
        XCTAssertEqual(noteB.emoji, "🗓️")

        // Idempotent call does not change updatedAt.
        let timestampBeforeNoOp = noteB.updatedAt
        try viewModel.setEmoji(" 🗓️ ", for: noteB)
        XCTAssertEqual(noteB.updatedAt, timestampBeforeNoOp)

        // Whitespace-only clears to nil.
        try viewModel.setEmoji("  \n\t ", for: noteB)
        XCTAssertNil(noteB.emoji)
        XCTAssertNil(noteB.displayEmoji)

        // Clearing an already-nil emoji is an idempotent no-op preserving updatedAt.
        let timestampAfterClear = noteB.updatedAt
        try viewModel.setEmoji(nil, for: noteB)
        XCTAssertNil(noteB.emoji)
        XCTAssertEqual(noteB.updatedAt, timestampAfterClear)

        // Verify noteB's unrelated fields remained completely untouched.
        XCTAssertEqual(noteB.title, "Nota B")
        XCTAssertEqual(noteB.content, "B")
        XCTAssertEqual(noteB.pdfData, expectedPDF)
        XCTAssertEqual(noteB.coverMediaData, pngCover)
        XCTAssertEqual(noteB.strokesArray.count, 1)
        XCTAssertEqual(noteB.shapesArray.count, 1)
        XCTAssertEqual(noteB.notebook, expectedNotebook)

        // Foreign-context note and deleted note throw referential integrity error.
        let foreignContext = TestSupport.makeInMemoryContext()
        let foreignNote = Note(context: foreignContext)
        foreignNote.id = UUID()
        foreignNote.title = "Externa"
        foreignNote.content = ""
        foreignNote.createdAt = Date()
        foreignNote.updatedAt = Date()
        foreignNote.isTrashed = false
        foreignNote.pageCount = 1

        XCTAssertThrowsError(try viewModel.setEmoji("🎯", for: foreignNote)) { error in
            XCTAssertEqual((error as? CocoaError)?.code, .managedObjectReferentialIntegrity)
        }

        let deletedNote = Note(context: context)
        deletedNote.id = UUID()
        deletedNote.title = "Apagada"
        deletedNote.content = ""
        deletedNote.createdAt = Date()
        deletedNote.updatedAt = Date()
        deletedNote.isTrashed = false
        deletedNote.pageCount = 1
        try context.save()
        context.delete(deletedNote)
        XCTAssertTrue(deletedNote.isDeleted)

        XCTAssertThrowsError(try viewModel.setEmoji("🎯", for: deletedNote)) { error in
            XCTAssertEqual((error as? CocoaError)?.code, .managedObjectReferentialIntegrity)
        }
        try context.save()

        // Persist baseline emoji before simulating context.save() failure.
        try viewModel.setEmoji("🎨", for: noteB)
        let persistedUpdatedAt = noteB.updatedAt
        let noteBObjectID = noteB.objectID

        let invalidNotebook = Notebook(context: context)
        XCTAssertThrowsError(try viewModel.setEmoji("✅", for: noteB))
        XCTAssertEqual(noteB.emoji, "🎨")
        XCTAssertEqual(noteB.updatedAt, persistedUpdatedAt)

        XCTAssertThrowsError(try viewModel.setEmoji(nil, for: noteB))
        XCTAssertEqual(noteB.emoji, "🎨")
        XCTAssertEqual(noteB.updatedAt, persistedUpdatedAt)

        context.delete(invalidNotebook)
        context.reset()
        let refetchedB = try XCTUnwrap(context.existingObject(with: noteBObjectID) as? Note)
        XCTAssertEqual(refetchedB.emoji, "🎨")
    }

    // MARK: - 3. Menu Contract Integration Across Unselected Note & Reopen

    func testMenuContractIntegrationAcrossUnselectedNoteAndReopen() throws {
        let dir = try makeTempDirectory()
        let (viewModel, context) = TestSupport.makeInMemoryViewModel()

        viewModel.addNotebook(name: "Caderno Origem")
        let sourceNotebook = try XCTUnwrap(viewModel.notebooks.first { $0.name == "Caderno Origem" })
        viewModel.addNotebook(name: "Caderno Destino")
        let destinationNotebook = try XCTUnwrap(viewModel.notebooks.first { $0.name == "Caderno Destino" })

        viewModel.selectedFilter = .notebook(sourceNotebook)
        viewModel.addNote(title: "Nota Selecionada", content: "Texto A")
        let noteA = try XCTUnwrap(viewModel.selectedNote)

        let sourcePDF = try makePDFData()
        let sourcePDFURL = dir.appendingPathComponent("OriginalMenu.pdf")
        try sourcePDF.write(to: sourcePDFURL)
        viewModel.importPDF(url: sourcePDFURL)
        let noteB = try XCTUnwrap(viewModel.selectedNote)
        noteB.content = "Resumo de estudo"

        let stroke = Stroke(context: context)
        stroke.id = UUID()
        stroke.points = "5.0,5.0;25.0,25.0"
        stroke.color = "#2B2A33"
        stroke.width = 2.0
        stroke.createdAt = Date()
        stroke.pageIndex = 0
        stroke.note = noteB

        let shape = ShapeObject(context: context)
        shape.id = UUID()
        shape.kind = "rectangle"
        shape.points = "10.0,10.0;80.0,60.0"
        shape.strokeColor = "#6F52E0"
        shape.strokeWidth = 2.0
        shape.createdAt = Date()
        shape.pageIndex = 0
        shape.note = noteB
        try context.save()

        // Keep noteA selected in editor/library while driving menu contract on unselected noteB.
        viewModel.selectedNote = noteA
        let noteAID = noteA.objectID
        let noteBID = noteB.objectID
        let noteBInitialDate = noteB.updatedAt

        // Simulated draft cancel: no renameNote call -> noteB title & date unchanged.
        let _ = "Rascunho Cancelado"
        XCTAssertEqual(noteB.title, "OriginalMenu")
        XCTAssertEqual(noteB.updatedAt, noteBInitialDate)

        // 1. Rename via FIX-01 contract.
        try viewModel.renameNote(noteB, to: "Resumo de Cálculo")
        XCTAssertTrue(viewModel.selectedNote === noteA)
        XCTAssertEqual(noteB.suggestedPDFName, "Resumo de Cálculo.pdf")

        // 2. Apply emoji via FEAT-02 contract.
        try viewModel.setEmoji("🧠", for: noteB)
        XCTAssertEqual(noteB.displayEmoji, "🧠")
        XCTAssertEqual(noteB.suggestedPDFName, "Resumo de Cálculo.pdf")

        // 3. Apply cover from disk URL via FEAT-03 contract.
        let pngBytes = try makeImageData(type: .png, color: CGColor(red: 0.898, green: 0.722, blue: 0.294, alpha: 1.0))
        let pngURL = dir.appendingPathComponent("cover.png")
        try pngBytes.write(to: pngURL)
        try viewModel.setCover(for: noteB, from: pngURL)
        XCTAssertTrue(noteB.hasCustomCover)

        // 4. Export PDF using suggestedPDFName (FIX-01 contract) for unselected noteB.
        let exportURL = dir.appendingPathComponent(noteB.suggestedPDFName)
        try viewModel.exportPDF(for: noteB, to: exportURL)
        XCTAssertTrue(FileManager.default.fileExists(atPath: exportURL.path))
        XCTAssertEqual(PDFDocument(url: exportURL)?.pageCount, 1)

        // 5. Remove cover then apply JPEG cover (FEAT-03 contract), preserving emoji.
        try viewModel.removeCover(for: noteB)
        XCTAssertFalse(noteB.hasCustomCover)
        XCTAssertEqual(noteB.displayEmoji, "🧠")

        let jpegBytes = try makeImageData(type: .jpeg, color: CGColor(red: 0.325, green: 0.490, blue: 0.400, alpha: 1.0))
        try viewModel.setCover(for: noteB, data: jpegBytes, contentType: .jpeg)

        // 6. Move noteB to destinationNotebook.
        viewModel.moveNote(noteB, to: destinationNotebook)

        // Reset Core Data context and verify noteA intact + noteB persisted all updates.
        let sourceNotebookID = sourceNotebook.objectID
        let destinationNotebookID = destinationNotebook.objectID
        context.reset()

        let reopenedA = try XCTUnwrap(context.existingObject(with: noteAID) as? Note)
        XCTAssertEqual(reopenedA.title, "Nota Selecionada")
        XCTAssertNil(reopenedA.emoji)
        XCTAssertFalse(reopenedA.hasCustomCover)
        XCTAssertEqual(reopenedA.notebook?.objectID, sourceNotebookID)

        let reopenedB = try XCTUnwrap(context.existingObject(with: noteBID) as? Note)
        XCTAssertEqual(reopenedB.title, "Resumo de Cálculo")
        XCTAssertEqual(reopenedB.emoji, "🧠")
        XCTAssertEqual(reopenedB.displayEmoji, "🧠")
        XCTAssertEqual(reopenedB.suggestedPDFName, "Resumo de Cálculo.pdf")
        XCTAssertTrue(reopenedB.hasCustomCover)
        XCTAssertEqual(reopenedB.coverMediaData, jpegBytes)
        XCTAssertEqual(reopenedB.coverMediaType, UTType.jpeg.identifier)
        XCTAssertEqual(reopenedB.notebook?.objectID, destinationNotebookID)
        XCTAssertEqual(reopenedB.content, "Resumo de estudo")
        XCTAssertEqual(reopenedB.pdfData, sourcePDF)
        XCTAssertEqual(reopenedB.strokesArray.count, 1)
        XCTAssertEqual(reopenedB.shapesArray.count, 1)
    }

    // MARK: - 4. NoteActionMenuModel Presentation Rules

    func testNoteActionMenuModelRulesForLibraryAndTrash() throws {
        let (viewModel, _) = TestSupport.makeInMemoryViewModel()
        viewModel.addNotebook(name: "Caderno Alpha")
        let alpha = try XCTUnwrap(viewModel.notebooks.first { $0.name == "Caderno Alpha" })
        viewModel.addNotebook(name: "Caderno Beta")
        let beta = try XCTUnwrap(viewModel.notebooks.first { $0.name == "Caderno Beta" })

        viewModel.selectedFilter = .uncategorized
        viewModel.addNote(title: "Solta", content: "")
        let looseNote = try XCTUnwrap(viewModel.selectedNote)

        let looseModel = NoteActionMenuModel(note: looseNote, notebooks: [alpha, beta], filter: .all)
        let originalName = beta.name
        beta.name = alpha.name
        let duplicateMenu = NoteActionMenuModel(note: looseNote, notebooks: [alpha, beta], filter: .all)
        XCTAssertEqual(Set(duplicateMenu.moveDestinations.map(\.title)).count, 3)
        XCTAssertEqual(duplicateMenu.moveDestinations.compactMap(\.notebookID), [alpha.id, beta.id])
        beta.name = originalName
        XCTAssertFalse(looseModel.isTrashContext)
        XCTAssertEqual(looseModel.displayTitle, "Solta")
        XCTAssertNil(looseModel.displayEmoji)
        XCTAssertTrue(looseModel.showsRenameAndEmojiSection)
        XCTAssertTrue(looseModel.showsCoverSection)
        XCTAssertFalse(looseModel.showsRemoveCoverAction)
        XCTAssertTrue(looseModel.showsExportPDFAction)
        XCTAssertTrue(looseModel.showsMoveSection)
        XCTAssertEqual(looseModel.coverActionTitle, "Escolher capa…")
        XCTAssertEqual(looseModel.deleteActionTitle, "Excluir Nota")
        XCTAssertEqual(looseModel.actions, [.chooseCover, .exportPDF, .moveTo, .deleteToTrash])

        XCTAssertEqual(looseModel.moveDestinations.count, 3)
        XCTAssertEqual(looseModel.moveDestinations[0].title, "Notas Soltas")
        XCTAssertTrue(looseModel.moveDestinations[0].isCurrent)
        XCTAssertTrue(looseModel.moveDestinations[0].isDisabled)
        XCTAssertEqual(looseModel.moveDestinations[1].title, "Caderno Alpha")
        XCTAssertFalse(looseModel.moveDestinations[1].isCurrent)
        XCTAssertFalse(looseModel.moveDestinations[1].isDisabled)
        XCTAssertEqual(looseModel.moveDestinations[2].title, "Caderno Beta")
        XCTAssertFalse(looseModel.moveDestinations[2].isDisabled)

        // Categorized note with custom cover, emoji, and empty title.
        let pngBytes = try makeImageData(type: .png, color: CGColor(red: 0.435, green: 0.322, blue: 0.878, alpha: 1.0))
        viewModel.moveNote(looseNote, to: alpha)
        try viewModel.renameNote(looseNote, to: "")
        try viewModel.setEmoji("🎯", for: looseNote)
        try viewModel.setCover(for: looseNote, data: pngBytes, contentType: .png)

        let coveredModel = NoteActionMenuModel(note: looseNote, notebooks: [alpha, beta], filter: .notebook(alpha))
        XCTAssertEqual(coveredModel.displayTitle, "Sem título")
        XCTAssertEqual(coveredModel.displayEmoji, "🎯")
        XCTAssertTrue(coveredModel.hasCustomCover)
        XCTAssertTrue(coveredModel.showsRemoveCoverAction)
        XCTAssertEqual(coveredModel.coverActionTitle, "Trocar capa…")
        XCTAssertEqual(coveredModel.actions, [.replaceCover, .removeCover, .exportPDF, .moveTo, .deleteToTrash])
        XCTAssertFalse(coveredModel.moveDestinations[0].isCurrent)
        XCTAssertFalse(coveredModel.moveDestinations[0].isDisabled)
        XCTAssertTrue(coveredModel.moveDestinations[1].isCurrent)
        XCTAssertTrue(coveredModel.moveDestinations[1].isDisabled)
        XCTAssertFalse(coveredModel.moveDestinations[2].isCurrent)
        XCTAssertFalse(coveredModel.moveDestinations[2].isDisabled)

        // Trash context exposes only restore and permanent delete.
        let trashModel = NoteActionMenuModel(note: looseNote, notebooks: [alpha, beta], filter: .trash)
        XCTAssertTrue(trashModel.isTrashContext)
        XCTAssertFalse(trashModel.showsRenameAndEmojiSection)
        XCTAssertFalse(trashModel.showsCoverSection)
        XCTAssertFalse(trashModel.showsRemoveCoverAction)
        XCTAssertFalse(trashModel.showsExportPDFAction)
        XCTAssertFalse(trashModel.showsMoveSection)
        XCTAssertEqual(trashModel.deleteActionTitle, "Excluir Definitivamente")
        XCTAssertEqual(trashModel.actions, [.restore, .deletePermanently])
        XCTAssertTrue(trashModel.moveDestinations.isEmpty)
    }

    // MARK: - 5. Secondary Click Detector Lifecycle & Occlusion

    func testSecondaryClickDetectorLifecycleAndOcclusion() throws {
        let registry = SecondaryClickMonitorRegistry.shared
        let initialCount = registry.activeDetectorCount

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 420, height: 320),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        let rootView = NSView(frame: NSRect(x: 0, y: 0, width: 420, height: 320))
        window.contentView = rootView

        let cardHost = NSView(frame: NSRect(x: 20, y: 20, width: 200, height: 260))
        rootView.addSubview(cardHost)

        let detector = SecondaryClickDetectorView(frame: cardHost.bounds)
        cardHost.addSubview(detector)

        // Sibling overlay covering the right half of cardHost (simulates titlebar/sidebar overlap).
        let occludingOverlay = NSView(frame: NSRect(x: 120, y: 20, width: 160, height: 260))
        rootView.addSubview(occludingOverlay)

        rootView.layoutSubtreeIfNeeded()

        XCTAssertEqual(registry.activeDetectorCount, initialCount + 1)
        XCTAssertTrue(registry.hasInstalledMonitor)

        func makeMouseEvent(
            type: NSEvent.EventType,
            modifiers: NSEvent.ModifierFlags = [],
            windowPoint: NSPoint
        ) throws -> NSEvent {
            try XCTUnwrap(
                NSEvent.mouseEvent(
                    with: type,
                    location: windowPoint,
                    modifierFlags: modifiers,
                    timestamp: 0,
                    windowNumber: window.windowNumber,
                    context: nil,
                    eventNumber: 0,
                    clickCount: 1,
                    pressure: 1
                )
            )
        }

        let clearPoint = NSPoint(x: 60, y: 100)
        XCTAssertTrue(detector.shouldInterceptSecondaryClick(for: try makeMouseEvent(type: .rightMouseDown, windowPoint: clearPoint)))
        XCTAssertTrue(detector.shouldInterceptSecondaryClick(for: try makeMouseEvent(type: .leftMouseDown, modifiers: [.control], windowPoint: clearPoint)))
        XCTAssertFalse(detector.shouldInterceptSecondaryClick(for: try makeMouseEvent(type: .leftMouseDown, windowPoint: clearPoint)))

        let occludedPoint = NSPoint(x: 160, y: 100)
        XCTAssertFalse(detector.shouldInterceptSecondaryClick(for: try makeMouseEvent(type: .rightMouseDown, windowPoint: occludedPoint)))

        detector.isHidden = true
        XCTAssertFalse(detector.shouldInterceptSecondaryClick(for: try makeMouseEvent(type: .rightMouseDown, windowPoint: clearPoint)))
        detector.isHidden = false

        detector.removeFromSuperview()
        XCTAssertEqual(registry.activeDetectorCount, initialCount)

        do {
            let orphan = SecondaryClickDetectorView(frame: NSRect(x: 0, y: 0, width: 40, height: 40))
            registry.register(orphan)
            XCTAssertEqual(registry.activeDetectorCount, initialCount + 1)
        }

        XCTAssertEqual(registry.activeDetectorCount, initialCount)
        if initialCount == 0 {
            XCTAssertFalse(registry.hasInstalledMonitor)
        }
    }
}

extension NoteContextMenuTests {
    func testGridColorMigrationPreservesExistingNotebookColor() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("paper.sqlite")
        try autoreleasepool {
            let source = CoreDataStack.makeModel()
            let entity = try XCTUnwrap(source.entitiesByName["Note"])
            entity.properties.removeAll { $0.name == "gridColorHex" }
            for entity in source.entities {
                entity.managedObjectClassName = NSStringFromClass(NSManagedObject.self)
            }
            let coordinator = NSPersistentStoreCoordinator(managedObjectModel: source)
            let store = try coordinator.addPersistentStore(type: .sqlite, at: url)
            let context = NSManagedObjectContext(concurrencyType: .mainQueueConcurrencyType)
            context.persistentStoreCoordinator = coordinator
            let folder = NSEntityDescription.insertNewObject(forEntityName: "Notebook", into: context)
            folder.setValue(UUID(), forKey: "id")
            folder.setValue("Papel", forKey: "name")
            folder.setValue(3, forKey: "colorIndex")
            let note = NSEntityDescription.insertNewObject(forEntityName: "Note", into: context)
            note.setValue(UUID(), forKey: "id")
            note.setValue("Original", forKey: "title")
            note.setValue("Texto", forKey: "content")
            note.setValue(Date(), forKey: "createdAt")
            note.setValue(Date(), forKey: "updatedAt")
            note.setValue("lines", forKey: "gridStyle")
            note.setValue(folder, forKey: "notebook")
            try context.save()
            context.reset()
            try coordinator.remove(store)
        }
        let container = try TestSupport.makeSQLiteContainer(at: url)
        let note = try XCTUnwrap(container.viewContext.fetch(NSFetchRequest<Note>(entityName: "Note")).first)
        XCTAssertEqual(note.gridStyle, "lines")
        XCTAssertEqual(note.gridInk.hexString, "#000000")
        XCTAssertEqual(note.notebook?.value(forKey: "colorIndex") as? NSNumber, 3)
        try closeSQLiteContainer(container)
    }

    func testMigratingLegacySQLiteAndEditingHierarchy() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("legacy.sqlite")
        let notebookID = UUID()
        try autoreleasepool {
            let legacy = makePreEmojiLegacyModel()
            let emoji = NSAttributeDescription()
            emoji.name = "emoji"
            emoji.attributeType = .stringAttributeType
            emoji.isOptional = true
            try XCTUnwrap(legacy.entitiesByName["Note"]).properties.append(emoji)
            let coordinator = NSPersistentStoreCoordinator(managedObjectModel: legacy)
            let store = try coordinator.addPersistentStore(type: .sqlite, at: url)
            let context = NSManagedObjectContext(concurrencyType: .mainQueueConcurrencyType)
            context.persistentStoreCoordinator = coordinator
            let folder = NSEntityDescription.insertNewObject(forEntityName: "Notebook", into: context)
            folder.setValue(notebookID, forKey: "id")
            folder.setValue("Arquivo", forKey: "name")
            let note = NSEntityDescription.insertNewObject(forEntityName: "Note", into: context)
            note.setValue(UUID(), forKey: "id")
            note.setValue("Original", forKey: "title")
            note.setValue("Texto preservado", forKey: "content")
            note.setValue(Date(), forKey: "createdAt")
            note.setValue(Date(), forKey: "updatedAt")
            note.setValue(folder, forKey: "notebook")
            try context.save()
            context.reset()
            try coordinator.remove(store)
        }

        let container = try TestSupport.makeSQLiteContainer(at: url)
        let context = container.viewContext
        let vm = NoteViewModel(context: context, coverCache: NoteCoverCache())
        let root = try XCTUnwrap(vm.notebooks.first)
        let note = try XCTUnwrap(root.notesArray.first)
        XCTAssertEqual(root.id, notebookID)
        XCTAssertEqual(note.content, "Texto preservado")
        XCTAssertNil(root.parent)
        let originalColor = PixelTheme.defaultNotebookIndex("Arquivo")
        XCTAssertEqual(root.swatchIndex, originalColor)
        vm.renameNotebook(root, to: "Projetos")
        XCTAssertEqual(root.swatchIndex, originalColor)
        vm.addNotebook(name: "Arquivo", parent: root)
        let child = try XCTUnwrap(vm.selectedNotebook)
        vm.renameNotebook(child, to: "Ativos", colorIndex: 3)
        let reopened = try TestSupport.makeSQLiteContainer(at: url)
        let request = NSFetchRequest<Notebook>(entityName: "Notebook")
        request.predicate = NSPredicate(format: "id == %@", child.id as NSUUID)
        let persisted = try XCTUnwrap(reopened.viewContext.fetch(request).first)
        XCTAssertEqual(persisted.swatchIndex, 3)
        XCTAssertEqual(persisted.path, "Projetos / Ativos")
        try closeSQLiteContainer(reopened)
        let menu = NoteActionMenuModel(note: note, notebooks: vm.notebooks, filter: .all)
        let destination = try XCTUnwrap(menu.moveDestinations.first { $0.notebookID == child.id })
        XCTAssertEqual(destination.title, "Projetos / Ativos")
        XCTAssertEqual(destination.swatchIndex, 3)
        vm.deleteNotebook(root)
        XCTAssertNil(child.parent)
        XCTAssertNil(note.notebook)
        XCTAssertFalse(note.isDeleted)
        XCTAssertFalse(note.isTrashed)
        vm.moveNote(note, to: child)
        vm.deleteNotebook(child, keepNotes: false)
        XCTAssertTrue(note.isTrashed)
        XCTAssertNil(note.notebook)
        XCTAssertEqual(try context.count(for: NSFetchRequest<Note>(entityName: "Note")), 1)
    }
}
