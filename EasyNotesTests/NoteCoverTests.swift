import AppKit
import CoreData
import ImageIO
import PDFKit
import SwiftUI
import UniformTypeIdentifiers
import XCTest

final class NoteCoverTests: XCTestCase {
    private var tempDirectories: [URL] = []

    override func tearDown() {
        for directory in tempDirectories {
            try? FileManager.default.removeItem(at: directory)
        }
        tempDirectories.removeAll()
        super.tearDown()
    }

    @MainActor
    func testGridCardRendersCustomImageAtBothSideEdges() throws {
        struct CardFixture: View {
            let note: Note
            @FocusState var focus: UUID?

            var body: some View {
                NoteCardView(
                    note: note, isMenuPresented: .constant(false),
                    focusedMenuTriggerNoteID: $focus, onOpenNote: {},
                    onToggleMenu: {}, onOpenMenu: {}
                ) { EmptyView() }
                .frame(width: 240)
            }
        }

        let viewModel = NoteViewModel(context: TestSupport.makeInMemoryContext())
        viewModel.addNote(title: "Capa panorâmica")
        let note = try XCTUnwrap(viewModel.selectedNote)
        try viewModel.setCover(for: note, data: makePNGData(width: 120, height: 40), contentType: .png)
        let host = NSHostingView(rootView: CardFixture(note: note))
        let window = NSWindow(contentRect: CGRect(origin: .zero, size: host.fittingSize),
                              styleMask: .borderless, backing: .buffered, defer: false)
        window.contentView = host
        window.displayIfNeeded()
        let deadline = Date().addingTimeInterval(2)
        repeat {
            RunLoop.main.run(until: Date().addingTimeInterval(0.03))
            host.layoutSubtreeIfNeeded()
            let bitmap = try XCTUnwrap(host.bitmapImageRepForCachingDisplay(in: host.bounds))
            host.cacheDisplay(in: host.bounds, to: bitmap)
            let samples = [0.06, 0.94].compactMap { fraction in
                bitmap.colorAt(x: Int(Double(bitmap.pixelsWide) * fraction), y: bitmap.pixelsHigh / 2)?
                    .usingColorSpace(.sRGB)
            }
            if samples.count == 2 && samples.allSatisfy({ $0.blueComponent - $0.greenComponent > 0.3 }) {
                return
            }
        } while Date() < deadline
        XCTFail("A imagem violeta deveria alcançar as duas laterais do cartão.")
    }

    // MARK: - Helpers

    private func makeTempDirectory() throws -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("EasyNotesCoverTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        tempDirectories.append(dir)
        return dir
    }

    private func makeCGImage(width: Int = 32, height: Int = 32, color: CGColor) throws -> CGImage {
        guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB),
              let context = CGContext(
                  data: nil,
                  width: width,
                  height: height,
                  bitsPerComponent: 8,
                  bytesPerRow: width * 4,
                  space: colorSpace,
                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
              ) else {
            throw NSError(domain: "NoteCoverTests", code: 1)
        }
        context.setFillColor(color)
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        guard let cgImage = context.makeImage() else {
            throw NSError(domain: "NoteCoverTests", code: 2)
        }
        return cgImage
    }

    private func makePNGData(width: Int = 32, height: Int = 32) throws -> Data {
        try encodeImageData(
            type: UTType.png,
            width: width,
            height: height,
            color: CGColor(red: 0.435, green: 0.322, blue: 0.878, alpha: 1.0)
        )
    }

    private func makeJPEGData(width: Int = 32, height: Int = 32) throws -> Data {
        try encodeImageData(
            type: UTType.jpeg,
            width: width,
            height: height,
            color: CGColor(red: 0.325, green: 0.490, blue: 0.400, alpha: 1.0)
        )
    }

    private func encodeImageData(type: UTType, width: Int, height: Int, color: CGColor) throws -> Data {
        let cgImage = try makeCGImage(width: width, height: height, color: color)
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(
            data as CFMutableData,
            type.identifier as CFString,
            1,
            nil
        ) else {
            throw NSError(domain: "NoteCoverTests", code: 3)
        }
        CGImageDestinationAddImage(destination, cgImage, nil)
        guard CGImageDestinationFinalize(destination) else {
            throw NSError(domain: "NoteCoverTests", code: 4)
        }
        return data as Data
    }

    private func makeGIFData(frameCount: Int = 2, width: Int = 16, height: Int = 16) throws -> Data {
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(
            data as CFMutableData,
            UTType.gif.identifier as CFString,
            frameCount,
            nil
        ) else {
            throw NSError(domain: "NoteCoverTests", code: 5)
        }
        let gifProperties: [CFString: Any] = [
            kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFLoopCount: 0]
        ]
        CGImageDestinationSetProperties(destination, gifProperties as CFDictionary)
        let frameProperties: [CFString: Any] = [
            kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFDelayTime: 0.1]
        ]
        for index in 0..<frameCount {
            let color = index.isMultiple(of: 2)
                ? CGColor(red: 0.435, green: 0.322, blue: 0.878, alpha: 1.0)
                : CGColor(red: 0.898, green: 0.722, blue: 0.294, alpha: 1.0)
            let frame = try makeCGImage(width: width, height: height, color: color)
            CGImageDestinationAddImage(destination, frame, frameProperties as CFDictionary)
        }
        guard CGImageDestinationFinalize(destination) else {
            throw NSError(domain: "NoteCoverTests", code: 6)
        }
        return data as Data
    }

    private func makePDFData() throws -> Data {
        let doc = PDFDocument()
        doc.insert(PDFPage(), at: 0)
        guard let data = doc.dataRepresentation() else {
            throw NSError(domain: "NoteCoverTests", code: 7)
        }
        return data
    }

    private func makeSampleImage(width: Int = 10, height: Int = 10) throws -> NSImage {
        let cgImage = try makeCGImage(
            width: width,
            height: height,
            color: CGColor(red: 0.2, green: 0.2, blue: 0.2, alpha: 1.0)
        )
        return NSImage(cgImage: cgImage, size: NSSize(width: width, height: height))
    }

    /// Exact copy of the pre-FEAT-03 managed object model (commit 715f26d),
    /// using generic `NSManagedObject` class names so the test process does not
    /// trigger duplicate-class entity ambiguity warnings.
    private func makePreCoverLegacyModel() -> NSManagedObjectModel {
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
            noteGridOriginY
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

    private func closeSQLiteContainer(_ container: NSPersistentContainer) throws {
        for store in container.persistentStoreCoordinator.persistentStores {
            try container.persistentStoreCoordinator.remove(store)
        }
    }

    // MARK: - 1. Legacy SQLite Migration

    func testLegacySQLiteStoreMigratesAndPreservesAllEntities() throws {
        let dir = try makeTempDirectory()
        let storeURL = dir.appendingPathComponent("LegacyEasyNotes.sqlite")
        let importedPDFBytes = try makePDFData()

        let notebookUUID = UUID()
        let textNoteUUID = UUID()
        let pdfNoteUUID = UUID()
        let strokeUUID = UUID()
        let shapeUUID = UUID()
        let createdAt = Date(timeIntervalSince1970: 1_700_000_000)

        // Create and populate legacy store with the pre-FEAT-03 model.
        let legacyModel = makePreCoverLegacyModel()
        let legacyContainer = NSPersistentContainer(name: "LegacyEasyNotes", managedObjectModel: legacyModel)
        let legacyDesc = NSPersistentStoreDescription(url: storeURL)
        legacyDesc.type = NSSQLiteStoreType
        legacyContainer.persistentStoreDescriptions = [legacyDesc]

        var legacyLoadError: Error?
        legacyContainer.loadPersistentStores { _, error in
            legacyLoadError = error
        }
        XCTAssertNil(legacyLoadError)

        let legacyContext = legacyContainer.viewContext
        let notebook = NSEntityDescription.insertNewObject(forEntityName: "Notebook", into: legacyContext)
        notebook.setValue(notebookUUID, forKey: "id")
        notebook.setValue("Caderno Legado", forKey: "name")

        let textNote = NSEntityDescription.insertNewObject(forEntityName: "Note", into: legacyContext)
        textNote.setValue(textNoteUUID, forKey: "id")
        textNote.setValue("Nota Texto Legada", forKey: "title")
        textNote.setValue("Conteúdo preservado", forKey: "content")
        textNote.setValue(createdAt, forKey: "createdAt")
        textNote.setValue(createdAt, forKey: "updatedAt")
        textNote.setValue(false, forKey: "isTrashed")
        textNote.setValue(nil, forKey: "pdfData")
        textNote.setValue(Int16(1), forKey: "pageCount")
        textNote.setValue("none", forKey: "gridStyle")
        textNote.setValue(Float(24.0), forKey: "gridSpacing")
        textNote.setValue(Float(0.0), forKey: "gridOriginX")
        textNote.setValue(Float(0.0), forKey: "gridOriginY")
        textNote.setValue(notebook, forKey: "notebook")

        let pdfNote = NSEntityDescription.insertNewObject(forEntityName: "Note", into: legacyContext)
        pdfNote.setValue(pdfNoteUUID, forKey: "id")
        pdfNote.setValue("PDF Legado", forKey: "title")
        pdfNote.setValue("", forKey: "content")
        pdfNote.setValue(createdAt, forKey: "createdAt")
        pdfNote.setValue(createdAt.addingTimeInterval(60), forKey: "updatedAt")
        pdfNote.setValue(false, forKey: "isTrashed")
        pdfNote.setValue(importedPDFBytes, forKey: "pdfData")
        pdfNote.setValue(Int16(1), forKey: "pageCount")
        pdfNote.setValue("grid", forKey: "gridStyle")
        pdfNote.setValue(Float(24.0), forKey: "gridSpacing")
        pdfNote.setValue(Float(306.0), forKey: "gridOriginX")
        pdfNote.setValue(Float(396.0), forKey: "gridOriginY")
        pdfNote.setValue(notebook, forKey: "notebook")

        let stroke = NSEntityDescription.insertNewObject(forEntityName: "Stroke", into: legacyContext)
        stroke.setValue(strokeUUID, forKey: "id")
        stroke.setValue("12.0,24.0;48.0,96.0", forKey: "points")
        stroke.setValue("#6F52E0", forKey: "color")
        stroke.setValue(Float(4.0), forKey: "width")
        stroke.setValue(createdAt, forKey: "createdAt")
        stroke.setValue(Int16(0), forKey: "pageIndex")
        stroke.setValue(pdfNote, forKey: "note")

        let shape = NSEntityDescription.insertNewObject(forEntityName: "ShapeObject", into: legacyContext)
        shape.setValue(shapeUUID, forKey: "id")
        shape.setValue("rectangle", forKey: "kind")
        shape.setValue("20.0,20.0;120.0,80.0", forKey: "points")
        shape.setValue("#2B2A33", forKey: "strokeColor")
        shape.setValue(Float(2.5), forKey: "strokeWidth")
        shape.setValue(nil, forKey: "fillColor")
        shape.setValue(createdAt, forKey: "createdAt")
        shape.setValue(Int16(0), forKey: "pageIndex")
        shape.setValue(pdfNote, forKey: "note")

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

        // Reopen with current model + automatic lightweight migration.
        let migratedContainer = try TestSupport.makeSQLiteContainer(at: storeURL)
        let migratedMetadata = try NSPersistentStoreCoordinator.metadataForPersistentStore(
            ofType: NSSQLiteStoreType,
            at: storeURL,
            options: nil
        )
        XCTAssertTrue(
            TestSupport.sharedModel.isConfiguration(withName: nil, compatibleWithStoreMetadata: migratedMetadata)
        )

        let cache = NoteCoverCache()
        let viewModel = NoteViewModel(context: migratedContainer.viewContext, coverCache: cache)

        XCTAssertEqual(viewModel.notebooks.count, 1)
        XCTAssertEqual(viewModel.notebooks.first?.id, notebookUUID)
        XCTAssertEqual(viewModel.notebooks.first?.name, "Caderno Legado")
        XCTAssertEqual(viewModel.notes.count, 2)

        let migratedTextNote = try XCTUnwrap(viewModel.notes.first { $0.id == textNoteUUID })
        XCTAssertEqual(migratedTextNote.title, "Nota Texto Legada")
        XCTAssertEqual(migratedTextNote.content, "Conteúdo preservado")
        XCTAssertEqual(migratedTextNote.notebook?.id, notebookUUID)
        XCTAssertFalse(migratedTextNote.hasCustomCover)
        XCTAssertNil(migratedTextNote.coverMediaData)
        XCTAssertNil(migratedTextNote.coverMediaType)
        XCTAssertNil(migratedTextNote.coverUpdatedAt)

        let migratedPDFNote = try XCTUnwrap(viewModel.notes.first { $0.id == pdfNoteUUID })
        XCTAssertEqual(migratedPDFNote.title, "PDF Legado")
        XCTAssertEqual(migratedPDFNote.notebook?.id, notebookUUID)
        XCTAssertEqual(migratedPDFNote.pdfData, importedPDFBytes)
        XCTAssertEqual(migratedPDFNote.gridStyle, "grid")
        XCTAssertEqual(migratedPDFNote.strokesArray.count, 1)
        let migratedStroke = try XCTUnwrap(migratedPDFNote.strokesArray.first)
        XCTAssertEqual(migratedStroke.id, strokeUUID)
        XCTAssertEqual(migratedStroke.points, "12.0,24.0;48.0,96.0")
        XCTAssertEqual(migratedStroke.color, "#6F52E0")
        XCTAssertEqual(migratedStroke.width, 4.0)
        XCTAssertEqual(migratedStroke.pageIndex, 0)
        XCTAssertEqual(migratedPDFNote.shapesArray.count, 1)
        let migratedShape = try XCTUnwrap(migratedPDFNote.shapesArray.first)
        XCTAssertEqual(migratedShape.id, shapeUUID)
        XCTAssertEqual(migratedShape.kind, "rectangle")
        XCTAssertEqual(migratedShape.points, "20.0,20.0;120.0,80.0")
        XCTAssertEqual(migratedShape.strokeColor, "#2B2A33")
        XCTAssertEqual(migratedShape.strokeWidth, 2.5)
        XCTAssertEqual(migratedShape.pageIndex, 0)
        XCTAssertFalse(migratedPDFNote.hasCustomCover)

        // Apply a cover on the migrated store, reopen SQLite again, and verify persistence.
        let pngData = try makePNGData()
        try viewModel.setCover(for: migratedPDFNote, data: pngData, contentType: .png)
        try closeSQLiteContainer(migratedContainer)

        let reopenedContainer = try TestSupport.makeSQLiteContainer(at: storeURL)
        let reopenedViewModel = NoteViewModel(context: reopenedContainer.viewContext, coverCache: NoteCoverCache())
        let reopenedPDFNote = try XCTUnwrap(reopenedViewModel.notes.first { $0.id == pdfNoteUUID })

        XCTAssertTrue(reopenedPDFNote.hasCustomCover)
        XCTAssertEqual(reopenedPDFNote.coverMediaData, pngData)
        XCTAssertEqual(reopenedPDFNote.coverMediaType, UTType.png.identifier)
        XCTAssertNotNil(reopenedPDFNote.coverUpdatedAt)
        XCTAssertEqual(reopenedPDFNote.pdfData, importedPDFBytes)
        XCTAssertEqual(reopenedPDFNote.strokesArray.first?.id, strokeUUID)
        XCTAssertEqual(reopenedPDFNote.shapesArray.first?.id, shapeUUID)

        try closeSQLiteContainer(reopenedContainer)
    }

    // MARK: - 2. Apply, Replace, Remove & Cache Invalidation

    func testApplyReplaceRemoveCoverPersistsAndInvalidatesCache() throws {
        let dir = try makeTempDirectory()
        let context = TestSupport.makeInMemoryContext()
        let cache = NoteCoverCache()
        let viewModel = NoteViewModel(context: context, coverCache: cache)

        let pdfBytes = try makePDFData()
        let pdfURL = dir.appendingPathComponent("Base.pdf")
        try pdfBytes.write(to: pdfURL)
        viewModel.importPDF(url: pdfURL, title: "Nota com Capa")

        let note = try XCTUnwrap(viewModel.selectedNote)
        note.content = "Anotações importantes"
        let stroke = Stroke(context: context)
        stroke.id = UUID()
        stroke.points = "0.0,0.0;20.0,20.0"
        stroke.color = "#000000"
        stroke.width = 2.0
        stroke.createdAt = Date()
        stroke.pageIndex = 0
        stroke.note = note

        let shape = ShapeObject(context: context)
        shape.id = UUID()
        shape.kind = "line"
        shape.points = "10.0,10.0;50.0,50.0"
        shape.strokeColor = "#6F52E0"
        shape.strokeWidth = 3.0
        shape.createdAt = Date()
        shape.pageIndex = 0
        shape.note = note
        try context.save()

        let noteObjectID = note.objectID
        let noteUUID = note.id

        // Populate fallback thumbnail cache before setting custom cover.
        let fallbackKey = NoteCoverCache.cacheKey(noteID: noteUUID, kind: .pdfFallback, token: "initial")
        cache.setImage(try makeSampleImage(), forKey: fallbackKey, noteID: noteUUID)
        XCTAssertTrue(cache.hasCachedEntries(for: noteUUID))

        // Apply PNG from disk URL.
        let pngData = try makePNGData()
        let pngURL = dir.appendingPathComponent("cover.png")
        try pngData.write(to: pngURL)

        try viewModel.setCover(for: note, from: pngURL)

        XCTAssertFalse(cache.hasCachedEntries(for: noteUUID))
        XCTAssertNil(cache.image(forKey: fallbackKey))
        XCTAssertTrue(note.hasCustomCover)
        XCTAssertEqual(note.coverMedia?.kind, .staticImage)
        XCTAssertEqual(note.coverMediaType, UTType.png.identifier)

        let firstCoverTimestamp = try XCTUnwrap(note.coverUpdatedAt)

        // Reset Core Data context and refetch by objectID to prove persistence.
        context.reset()
        let refetchedAfterApply = try XCTUnwrap(context.existingObject(with: noteObjectID) as? Note)
        XCTAssertTrue(refetchedAfterApply.hasCustomCover)
        XCTAssertEqual(refetchedAfterApply.coverMediaData, pngData)
        XCTAssertEqual(refetchedAfterApply.coverMediaType, UTType.png.identifier)
        XCTAssertEqual(refetchedAfterApply.title, "Nota com Capa")
        XCTAssertEqual(refetchedAfterApply.content, "Anotações importantes")
        XCTAssertEqual(refetchedAfterApply.pdfData, pdfBytes)
        XCTAssertEqual(refetchedAfterApply.strokesArray.count, 1)
        XCTAssertEqual(refetchedAfterApply.shapesArray.count, 1)

        // Populate custom cover cache and replace with JPEG.
        let customKey = NoteCoverCache.cacheKey(noteID: noteUUID, kind: .customCover, token: "png")
        cache.setImage(try makeSampleImage(), forKey: customKey, noteID: noteUUID)
        XCTAssertTrue(cache.hasCachedEntries(for: noteUUID))

        let jpegData = try makeJPEGData()
        try viewModel.setCover(for: refetchedAfterApply, data: jpegData, contentType: .jpeg)

        XCTAssertFalse(cache.hasCachedEntries(for: noteUUID))
        XCTAssertNil(cache.image(forKey: customKey))
        XCTAssertGreaterThan(try XCTUnwrap(refetchedAfterApply.coverUpdatedAt), firstCoverTimestamp)
        XCTAssertEqual(refetchedAfterApply.coverMediaType, UTType.jpeg.identifier)

        context.reset()
        let refetchedAfterReplace = try XCTUnwrap(context.existingObject(with: noteObjectID) as? Note)
        XCTAssertEqual(refetchedAfterReplace.coverMediaData, jpegData)
        XCTAssertEqual(refetchedAfterReplace.coverMediaType, UTType.jpeg.identifier)

        // Populate cache again and remove cover -> returns to fallback with all note data intact.
        let replaceKey = NoteCoverCache.cacheKey(noteID: noteUUID, kind: .customCover, token: "jpeg")
        cache.setImage(try makeSampleImage(), forKey: replaceKey, noteID: noteUUID)

        try viewModel.removeCover(for: refetchedAfterReplace)
        XCTAssertFalse(cache.hasCachedEntries(for: noteUUID))
        XCTAssertFalse(refetchedAfterReplace.hasCustomCover)
        XCTAssertNil(refetchedAfterReplace.coverMedia)
        XCTAssertNil(refetchedAfterReplace.coverMediaData)
        XCTAssertNil(refetchedAfterReplace.coverMediaType)
        XCTAssertNil(refetchedAfterReplace.coverUpdatedAt)

        let dateAfterRemove = refetchedAfterReplace.updatedAt
        try viewModel.removeCover(for: refetchedAfterReplace)
        XCTAssertEqual(refetchedAfterReplace.updatedAt, dateAfterRemove)

        context.reset()
        let refetchedAfterRemove = try XCTUnwrap(context.existingObject(with: noteObjectID) as? Note)
        XCTAssertFalse(refetchedAfterRemove.hasCustomCover)
        XCTAssertEqual(refetchedAfterRemove.pdfData, pdfBytes)
        XCTAssertEqual(refetchedAfterRemove.content, "Anotações importantes")
        XCTAssertEqual(refetchedAfterRemove.strokesArray.count, 1)
        XCTAssertEqual(refetchedAfterRemove.shapesArray.count, 1)
    }

    // MARK: - 3. Invalid Media & Persistence Rollback

    func testInvalidMediaAndPersistenceFailurePreservePreviousCover() throws {
        let dir = try makeTempDirectory()
        let context = TestSupport.makeInMemoryContext()
        let cache = NoteCoverCache()
        let viewModel = NoteViewModel(context: context, coverCache: cache)

        viewModel.addNote(title: "Capa Protegida", content: "Texto")
        let note = try XCTUnwrap(viewModel.selectedNote)
        let originalPNG = try makePNGData()
        try viewModel.setCover(for: note, data: originalPNG, contentType: .png)
        let originalCoverUpdatedAt = try XCTUnwrap(note.coverUpdatedAt)
        let originalUpdatedAt = note.updatedAt
        let noteObjectID = note.objectID

        // Corrupt bytes -> unreadableImage
        XCTAssertThrowsError(try viewModel.setCover(for: note, data: Data([0x01, 0x02, 0x03, 0x04]), contentType: .png)) { error in
            XCTAssertEqual(error as? NoteCoverError, .unreadableImage)
        }

        // Empty data -> unreadableImage
        XCTAssertThrowsError(try viewModel.setCover(for: note, data: Data(), contentType: .png)) { error in
            XCTAssertEqual(error as? NoteCoverError, .unreadableImage)
        }

        // PDF bytes -> unsupportedMediaType
        let pdfData = try makePDFData()
        XCTAssertThrowsError(try viewModel.setCover(for: note, data: pdfData, contentType: nil)) { error in
            guard case .unsupportedMediaType = error as? NoteCoverError else {
                XCTFail("Expected unsupportedMediaType, got \(error)")
                return
            }
        }

        // Missing file URL -> unreadableImage
        let missingURL = dir.appendingPathComponent("nao-existe.png")
        XCTAssertThrowsError(try viewModel.setCover(for: note, from: missingURL)) { error in
            XCTAssertEqual(error as? NoteCoverError, .unreadableImage)
        }

        // Non-image file URL (.txt) -> unsupportedMediaType
        let textURL = dir.appendingPathComponent("arquivo.txt")
        try Data("not an image".utf8).write(to: textURL)
        XCTAssertThrowsError(try viewModel.setCover(for: note, from: textURL)) { error in
            guard case .unsupportedMediaType = error as? NoteCoverError else {
                XCTFail("Expected unsupportedMediaType, got \(error)")
                return
            }
        }

        // Verify previous cover stayed intact after every failed validation.
        XCTAssertEqual(note.coverMediaData, originalPNG)
        XCTAssertEqual(note.coverMediaType, UTType.png.identifier)
        XCTAssertEqual(note.coverUpdatedAt, originalCoverUpdatedAt)
        XCTAssertEqual(note.updatedAt, originalUpdatedAt)

        // Note from another context or deleted note -> invalidNote
        let foreignContext = TestSupport.makeInMemoryContext()
        let foreignNote = Note(context: foreignContext)
        foreignNote.id = UUID()
        foreignNote.title = "Externa"
        foreignNote.content = ""
        foreignNote.createdAt = Date()
        foreignNote.updatedAt = Date()
        foreignNote.isTrashed = false
        foreignNote.pageCount = 1

        XCTAssertThrowsError(try viewModel.setCover(for: foreignNote, data: originalPNG, contentType: .png)) { error in
            XCTAssertEqual(error as? NoteCoverError, .invalidNote)
        }
        XCTAssertThrowsError(try viewModel.removeCover(for: foreignNote)) { error in
            XCTAssertEqual(error as? NoteCoverError, .invalidNote)
        }

        // Force Core Data save() failure via an invalid pending Notebook in the context
        // and confirm cover fields roll back completely for both setCover and removeCover.
        let invalidNotebook = Notebook(context: context)
        let jpegData = try makeJPEGData()
        XCTAssertThrowsError(try viewModel.setCover(for: note, data: jpegData, contentType: .jpeg)) { error in
            guard case .persistenceFailed = error as? NoteCoverError else {
                XCTFail("Expected persistenceFailed, got \(error)")
                return
            }
        }

        XCTAssertEqual(note.coverMediaData, originalPNG)
        XCTAssertEqual(note.coverMediaType, UTType.png.identifier)
        XCTAssertEqual(note.coverUpdatedAt, originalCoverUpdatedAt)
        XCTAssertEqual(note.updatedAt, originalUpdatedAt)

        XCTAssertThrowsError(try viewModel.removeCover(for: note)) { error in
            guard case .persistenceFailed = error as? NoteCoverError else {
                XCTFail("Expected persistenceFailed, got \(error)")
                return
            }
        }

        XCTAssertEqual(note.coverMediaData, originalPNG)
        XCTAssertEqual(note.coverMediaType, UTType.png.identifier)
        XCTAssertEqual(note.coverUpdatedAt, originalCoverUpdatedAt)
        XCTAssertEqual(note.updatedAt, originalUpdatedAt)

        // Clean invalid object and verify persisted store still holds original PNG.
        context.delete(invalidNotebook)
        context.reset()
        let persistedNote = try XCTUnwrap(context.existingObject(with: noteObjectID) as? Note)
        XCTAssertEqual(persistedNote.coverMediaData, originalPNG)
        XCTAssertEqual(persistedNote.coverMediaType, UTType.png.identifier)
    }

    // MARK: - 4. GIF Classification & Extensible Renderer Registry

    func testGIFClassificationAndExtensibleRendererRegistry() throws {
        let pngData = try makePNGData()
        let jpegData = try makeJPEGData()
        let gifData = try makeGIFData()

        let pngMedia = try NoteCoverMedia.validated(data: pngData)
        let disguisedPNGMedia = try NoteCoverMedia.validated(data: pngData, contentType: .gif)
        let jpegMedia = try NoteCoverMedia.validated(data: jpegData)
        let gifMedia = try NoteCoverMedia.validated(data: gifData)

        XCTAssertEqual(pngMedia.kind, .staticImage)
        XCTAssertEqual(pngMedia.contentTypeIdentifier, UTType.png.identifier)
        XCTAssertEqual(disguisedPNGMedia.kind, .staticImage)
        XCTAssertEqual(disguisedPNGMedia.contentTypeIdentifier, UTType.png.identifier)
        XCTAssertEqual(jpegMedia.kind, .staticImage)
        XCTAssertEqual(jpegMedia.contentTypeIdentifier, UTType.jpeg.identifier)
        XCTAssertEqual(gifMedia.kind, .animatedGIF)
        XCTAssertEqual(gifMedia.contentTypeIdentifier, UTType.gif.identifier)

        // Default registry renders first frame safely for .animatedGIF.
        let registry = NoteCoverRendererRegistry()
        let fallbackRendered = registry.render(media: gifMedia, targetSize: CGSize(width: 240, height: 320))
        guard case .image(let frameZero)? = fallbackRendered else {
            XCTFail("Expected frame-0 static fallback image for GIF")
            return
        }
        XCTAssertGreaterThan(frameZero.size.width, 0)
        XCTAssertGreaterThan(frameZero.size.height, 0)

        // Register a mock animated GIF renderer and prove dispatch without changing persistence.
        let mockGIFRenderer = MockAnimatedGIFCoverRenderer()
        registry.register(mockGIFRenderer, for: .animatedGIF)

        let customGIFRendered = registry.render(media: gifMedia, targetSize: CGSize(width: 240, height: 320))
        XCTAssertEqual(mockGIFRenderer.renderCallCount, 1)
        XCTAssertEqual(mockGIFRenderer.lastMedia, gifMedia)
        if case .view? = customGIFRendered {
            // Expected custom view dispatch.
        } else {
            XCTFail("Expected .view rendered output from registered GIF renderer")
        }

        // Static images still route to StaticImageCoverRenderer.
        let staticRendered = registry.render(media: pngMedia, targetSize: CGSize(width: 240, height: 320))
        XCTAssertEqual(mockGIFRenderer.renderCallCount, 1)
        if case .image(let staticImage)? = staticRendered {
            XCTAssertGreaterThan(staticImage.size.width, 0)
        } else {
            XCTFail("Expected .image output for static PNG")
        }

        // Persist GIF media on a Note and confirm round-trip classification.
        let context = TestSupport.makeInMemoryContext()
        let viewModel = NoteViewModel(context: context, coverCache: NoteCoverCache())
        viewModel.addNote(title: "Nota GIF", content: "")
        let note = try XCTUnwrap(viewModel.selectedNote)
        let noteObjectID = note.objectID

        try viewModel.setCover(for: note, data: gifData, contentType: .gif)
        context.reset()

        let reopened = try XCTUnwrap(context.existingObject(with: noteObjectID) as? Note)
        XCTAssertTrue(reopened.hasCustomCover)
        XCTAssertEqual(reopened.coverMedia?.kind, .animatedGIF)
        XCTAssertEqual(reopened.coverMedia?.contentTypeIdentifier, UTType.gif.identifier)
        XCTAssertEqual(reopened.coverMedia?.data, gifData)
    }

    // MARK: - 5. Deterministic LRU Cache & Key Eviction

    func testCoverCacheEvictsLRUWithoutLeakingKeys() throws {
        let cache = NoteCoverCache(capacity: 2)
        let noteA = UUID()
        let noteB = UUID()
        let noteC = UUID()

        let keyA = NoteCoverCache.cacheKey(noteID: noteA, kind: .customCover, token: "1")
        let keyB = NoteCoverCache.cacheKey(noteID: noteB, kind: .customCover, token: "1")
        let keyC = NoteCoverCache.cacheKey(noteID: noteC, kind: .customCover, token: "1")

        cache.setImage(try makeSampleImage(), forKey: keyA, noteID: noteA)
        cache.setImage(try makeSampleImage(), forKey: keyB, noteID: noteB)
        XCTAssertEqual(cache.cachedEntryCount, 2)
        XCTAssertTrue(cache.hasCachedEntries(for: noteA))
        XCTAssertTrue(cache.hasCachedEntries(for: noteB))

        // Accessing keyA promotes it to MRU, so inserting keyC evicts keyB.
        XCTAssertNotNil(cache.image(forKey: keyA))
        cache.setImage(try makeSampleImage(), forKey: keyC, noteID: noteC)

        XCTAssertEqual(cache.cachedEntryCount, 2)
        XCTAssertFalse(cache.hasCachedEntries(for: noteB))
        XCTAssertNil(cache.image(forKey: keyB))
        XCTAssertTrue(cache.hasCachedEntries(for: noteA))
        XCTAssertNotNil(cache.image(forKey: keyA))
        XCTAssertTrue(cache.hasCachedEntries(for: noteC))
        XCTAssertNotNil(cache.image(forKey: keyC))

        cache.invalidate(noteID: noteA)
        XCTAssertEqual(cache.cachedEntryCount, 1)
        XCTAssertFalse(cache.hasCachedEntries(for: noteA))
        XCTAssertNil(cache.image(forKey: keyA))

        cache.invalidateAll()
        XCTAssertEqual(cache.cachedEntryCount, 0)
        XCTAssertFalse(cache.hasCachedEntries(for: noteC))
        XCTAssertNil(cache.image(forKey: keyC))
    }
}

@MainActor
private final class MockAnimatedGIFCoverRenderer: NoteCoverMediaRendering {
    let supportedKinds: Set<NoteCoverMediaKind> = [.animatedGIF]
    private(set) var renderCallCount = 0
    private(set) var lastMedia: NoteCoverMedia?

    func render(media: NoteCoverMedia, targetSize: CGSize) -> NoteCoverRenderedContent? {
        renderCallCount += 1
        lastMedia = media
        return .view(AnyView(Color.clear))
    }
}
