import AppKit
import CoreData
import ImageIO
import PDFKit
import UniformTypeIdentifiers
import XCTest

final class EditorImageTests: XCTestCase {
    private func temporaryDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: false)
        addTeardownBlock { try FileManager.default.removeItem(at: url) }
        return url
    }

    private func imageData(type: UTType = .png, width: Int = 400, height: Int = 200) throws -> Data {
        let bitmap = try XCTUnwrap(CGContext(data: nil, width: width, height: height,
                                             bitsPerComponent: 8, bytesPerRow: 0,
                                             space: CGColorSpaceCreateDeviceRGB(),
                                             bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue))
        bitmap.setFillColor(NSColor.red.cgColor)
        bitmap.fill(CGRect(x: 0, y: 0, width: width, height: height))
        bitmap.setFillColor(NSColor.blue.cgColor)
        bitmap.fill(CGRect(x: 0, y: 0, width: width / 2, height: height / 2))
        let data = NSMutableData()
        let destination = try XCTUnwrap(CGImageDestinationCreateWithData(data, type.identifier as CFString, 1, nil))
        CGImageDestinationAddImage(destination, try XCTUnwrap(bitmap.makeImage()), nil)
        XCTAssertTrue(CGImageDestinationFinalize(destination))
        return data as Data
    }

    private func close(_ container: NSPersistentContainer) throws {
        container.viewContext.reset()
        let coordinator = container.persistentStoreCoordinator
        for store in coordinator.persistentStores { try coordinator.remove(store) }
    }

    private func pdfData(box: CGRect = CGRect(x: 40, y: 70, width: 400, height: 500),
                         rotation: Int = 90) throws -> Data {
        let data = NSMutableData()
        let consumer = try XCTUnwrap(CGDataConsumer(data: data))
        let pdf = try XCTUnwrap(CGContext(consumer: consumer, mediaBox: nil, nil))
        var box = box
        for _ in 0..<2 {
            pdf.beginPage(mediaBox: &box)
            pdf.setFillColor(NSColor.white.cgColor)
            pdf.fill(box)
            pdf.endPage()
        }
        pdf.closePDF()
        let document = try XCTUnwrap(PDFDocument(data: data as Data))
        document.page(at: 1)?.rotation = rotation
        return try XCTUnwrap(document.dataRepresentation())
    }

    @MainActor
    func testMigratesBaseSQLiteAndReopensImagesWithAllLegacyData() throws {
        let storeURL = try temporaryDirectory().appendingPathComponent("Base.sqlite")
        let base = CoreDataStack.makeBaseModel()
        let baseHashes = base.entityVersionHashesByName
        for entity in base.entities {
            entity.managedObjectClassName = NSStringFromClass(NSManagedObject.self)
        }
        let old = NSPersistentContainer(name: "Base", managedObjectModel: base)
        let coordinator = old.persistentStoreCoordinator
        _ = try coordinator.addPersistentStore(ofType: NSSQLiteStoreType, configurationName: nil,
                                               at: storeURL, options: nil)
        let context = old.viewContext
        let timestamp = Date(timeIntervalSince1970: 1_700_000_000)
        func seed(_ entity: String, _ properties: [String: Any]) -> NSManagedObject {
            let object = NSEntityDescription.insertNewObject(forEntityName: entity, into: context)
            object.setValuesForKeys(properties)
            return object
        }
        let parent = seed("Notebook", ["id": UUID(), "name": "Pai", "colorHex": "#ABCDEF"])
        let notebook = seed("Notebook", ["id": UUID(), "name": "Filho", "parent": parent])
        let noteID = UUID()
        let strokeID = UUID()
        let shapeID = UUID()
        let originalPDF = try pdfData()
        // Large enough that Core Data writes the cover as external binary data.
        let cover = Data((0..<512_000).map { _ in UInt8.random(in: .min ... .max) })
        let note = seed("Note", [
            "id": noteID, "notebook": notebook, "title": "Legado", "content": "Texto preservado",
            "createdAt": timestamp, "updatedAt": timestamp, "pdfData": originalPDF, "pageCount": 2,
            "gridStyle": "grid", "gridColorHex": "#123456", "emoji": "📓", "coverMediaData": cover,
            "coverMediaType": UTType.png.identifier, "coverUpdatedAt": timestamp
        ])
        _ = seed("Stroke", [
            "id": strokeID, "points": "1,2;3,4", "createdAt": timestamp, "width": 13,
            "color": "#112233", "pageIndex": 1, "note": note
        ])
        _ = seed("ShapeObject", [
            "id": shapeID, "kind": "line", "points": "5,6;7,8", "createdAt": timestamp,
            "strokeColor": "#ABCDEF", "strokeWidth": 5, "pageIndex": 1, "note": note
        ])
        try context.save()
        try close(old)

        let metadata = try NSPersistentStoreCoordinator.metadataForPersistentStore(
            ofType: NSSQLiteStoreType, at: storeURL
        )
        XCTAssertEqual(metadata[NSStoreModelVersionHashesKey] as? [String: Data], baseHashes)
        XCTAssertFalse(TestSupport.sharedModel.isConfiguration(withName: nil, compatibleWithStoreMetadata: metadata))
        let externalFiles = FileManager.default.enumerator(atPath: storeURL.deletingLastPathComponent().path)
        XCTAssertTrue(externalFiles?.allObjects.contains { ($0 as? String)?.contains("_EXTERNAL_DATA/") == true } == true)

        let bytes = try imageData(type: .jpeg)
        func checkLegacy(_ saved: Note) {
            XCTAssertEqual(saved.id, noteID)
            XCTAssertEqual(saved.title, "Legado")
            XCTAssertEqual(saved.content, "Texto preservado")
            XCTAssertEqual(saved.notebook?.name, "Filho")
            XCTAssertEqual(saved.notebook?.parent?.colorHex, "#ABCDEF")
            XCTAssertEqual(saved.createdAt, timestamp)
            XCTAssertEqual(saved.updatedAt, timestamp)
            XCTAssertEqual(saved.pageCount, 2)
            XCTAssertEqual(saved.pdfData, originalPDF)
            XCTAssertEqual(saved.coverMediaData, cover)
            XCTAssertEqual(saved.coverMediaType, UTType.png.identifier)
            XCTAssertEqual(saved.coverUpdatedAt, timestamp)
            XCTAssertEqual(saved.emoji, "📓")
            XCTAssertEqual(saved.gridStyle, "grid")
            XCTAssertEqual(saved.gridColorHex, "#123456")
            XCTAssertEqual(saved.strokesArray.first?.id, strokeID)
            XCTAssertEqual(saved.strokesArray.first?.points, "1,2;3,4")
            XCTAssertEqual(saved.shapesArray.first?.id, shapeID)
            XCTAssertEqual(saved.shapesArray.first?.points, "5,6;7,8")
        }
        let migrated = try TestSupport.makeSQLiteContainer(at: storeURL)
        let saved = try XCTUnwrap(migrated.viewContext.fetch(NSFetchRequest<Note>(entityName: "Note")).first)
        checkLegacy(saved)
        XCTAssertEqual(saved.editorImages?.count ?? 0, 0)
        let model = NoteViewModel(context: migrated.viewContext)
        try model.insertEditorImage(data: bytes, into: saved, pageIndex: 1)
        XCTAssertEqual(saved.editorImages?.count, 1)
        try close(migrated)

        let reopened = try TestSupport.makeSQLiteContainer(at: storeURL)
        let storedNote = try XCTUnwrap(reopened.viewContext.fetch(NSFetchRequest<Note>(entityName: "Note")).first)
        checkLegacy(storedNote)
        let entry = try XCTUnwrap(storedNote.editorImages?.anyObject() as? EditorImage)
        XCTAssertEqual(entry.note.id, noteID)
        XCTAssertEqual(entry.pageIndex, 1)
        XCTAssertEqual(entry.data, bytes)
        XCTAssertEqual(entry.frame.midX, 240, accuracy: 0.001)
        XCTAssertEqual(entry.frame.midY, 320, accuracy: 0.001)
        XCTAssertEqual(entry.frame.width, 280, accuracy: 0.001)
        XCTAssertEqual(entry.frame.height, 140, accuracy: 0.001)
        reopened.viewContext.delete(storedNote)
        try reopened.viewContext.save()
        XCTAssertEqual(try reopened.viewContext.count(for: NSFetchRequest<EditorImage>(entityName: "EditorImage")), 0)
        try close(reopened)
    }

    @MainActor
    func testValidationAndReadOnlySaveLeavePendingEditsAndStoreUntouched() throws {
        let url = try temporaryDirectory().appendingPathComponent("ReadOnly.sqlite")
        let writable = try TestSupport.makeSQLiteContainer(at: url)
        let original = NoteViewModel(context: writable.viewContext)
        original.addNote(title: "No disco")
        let id = try XCTUnwrap(original.selectedNote?.id)
        try close(writable)

        let coordinator = NSPersistentStoreCoordinator(managedObjectModel: TestSupport.sharedModel)
        _ = try coordinator.addPersistentStore(ofType: NSSQLiteStoreType, configurationName: nil, at: url,
                                               options: [NSReadOnlyPersistentStoreOption: true])
        let context = NSManagedObjectContext(concurrencyType: .mainQueueConcurrencyType)
        context.persistentStoreCoordinator = coordinator
        let model = NoteViewModel(context: context)
        let note = try XCTUnwrap(model.notes.first { $0.id == id })
        let related = try XCTUnwrap(model.notes.first { $0.id != id })
        let timestamp = note.updatedAt
        let pdf = note.pdfData
        note.title = "Edição pendente"
        related.content = "Outra edição pendente"
        let png = try imageData()
        let jpeg = try imageData(type: .jpeg)
        for invalid in [Data("PNG".utf8), png.prefix(png.count / 2), jpeg.dropLast(2),
                        try imageData(type: .tiff), try imageData(width: 8193, height: 1),
                        Data(count: EditorImageMedia.byteLimit + 1)] {
            XCTAssertThrowsError(try model.insertEditorImage(data: invalid, into: note, pageIndex: 0)) {
                XCTAssertTrue($0 is EditorImageImportError)
            }
        }
        XCTAssertThrowsError(try model.insertEditorImage(data: png, into: note, pageIndex: 1))
        XCTAssertThrowsError(try model.insertEditorImage(data: png, into: note, pageIndex: 0)) {
            XCTAssertFalse($0 is EditorImageImportError)
        }
        XCTAssertEqual(note.title, "Edição pendente")
        XCTAssertEqual(related.content, "Outra edição pendente")
        XCTAssertEqual(note.updatedAt, timestamp)
        XCTAssertEqual(note.pdfData, pdf)
        XCTAssertEqual(note.editorImages?.count ?? 0, 0)
        XCTAssertTrue(context.hasChanges)
        context.reset()
        let request = NSFetchRequest<Note>(entityName: "Note")
        XCTAssertEqual(try context.fetch(request).first { $0.id == id }?.title, "No disco")
        XCTAssertEqual(try context.count(for: NSFetchRequest<EditorImage>(entityName: "EditorImage")), 0)
        for store in coordinator.persistentStores { try coordinator.remove(store) }
    }

    @MainActor
    func testPageThumbnailAndExportKeepImageBelowStrokeOnRotatedOffsetPage() throws {
        let (model, context) = TestSupport.makeInMemoryViewModel()
        model.addNote(title: "Duas páginas")
        let note = try XCTUnwrap(model.selectedNote)
        note.pdfData = try pdfData()
        note.pageCount = 2
        note.gridStyle = "grid"
        let stroke = Stroke(context: context)
        stroke.id = UUID()
        stroke.points = "180,320;300,320"
        stroke.color = "#00FF00"
        stroke.width = 24
        stroke.createdAt = Date()
        stroke.pageIndex = 1
        stroke.note = note
        try context.save()
        note.title = "Edição ainda pendente"
        let png = try imageData()
        try model.insertEditorImage(data: png, into: note, pageIndex: 1)
        XCTAssertEqual(note.title, "Edição ainda pendente")
        XCTAssertTrue(context.hasChanges)
        let persisted = NSManagedObjectContext(concurrencyType: .mainQueueConcurrencyType)
        persisted.persistentStoreCoordinator = context.persistentStoreCoordinator
        XCTAssertEqual(try (persisted.existingObject(with: note.objectID) as? Note)?.title, "Duas páginas")

        let url = try temporaryDirectory().appendingPathComponent("Export.pdf")
        try model.exportPDF(for: note, to: url, options: PDFExportOptions(includeGrid: false))
        let export = try XCTUnwrap(PDFDocument(url: url))
        let source = try XCTUnwrap(model.getPDFDocument(for: note))
        let activePage = try XCTUnwrap(source.page(at: 1))
        let exportedPage = try XCTUnwrap(export.page(at: 1))
        XCTAssertEqual(exportedPage.bounds(for: .mediaBox).size, CGSize(width: 500, height: 400))
        let thumbnail = PageThumbnail.renderThumbnail(for: activePage, note: note, pageIndex: 1)
        let exported = exportedPage.thumbnail(of: CGSize(width: 224, height: 296), for: .mediaBox)
        let transform = activePage.transform(for: .mediaBox)
        for image in [thumbnail, exported] {
            let red = try pixel(in: image, at: CGPoint(x: 280, y: 360).applying(transform), width: 500, height: 400)
            let blue = try pixel(in: image, at: CGPoint(x: 200, y: 280).applying(transform), width: 500, height: 400)
            let green = try pixel(in: image, at: CGPoint(x: 240, y: 320).applying(transform), width: 500, height: 400)
            XCTAssertGreaterThan(red.redComponent - red.greenComponent, 0.8)
            XCTAssertGreaterThan(blue.blueComponent - blue.redComponent, 0.8)
            XCTAssertGreaterThan(green.greenComponent - green.redComponent, 0.7)
        }
        let otherPage = try XCTUnwrap(export.page(at: 0))
        let blank = otherPage.thumbnail(of: CGSize(width: 224, height: 296), for: .mediaBox)
        let center = try pixel(in: blank, at: CGPoint(x: 200, y: 250), width: 400, height: 500)
        XCTAssertGreaterThan(center.greenComponent, 0.95)
        XCTAssertGreaterThan(center.blueComponent, 0.95)
    }

    @MainActor
    func testPDFKitOverlayPaintsImageInPageCoordinatesAtZoom() throws {
        _ = NSApplication.shared
        let (model, context) = TestSupport.makeInMemoryViewModel()
        model.addNote(title: "Imagem no canvas")
        let note = try XCTUnwrap(model.selectedNote)
        note.pdfData = try pdfData()
        note.pageCount = 2
        try context.save()
        try model.insertEditorImage(data: imageData(), into: note, pageIndex: 1)
        let document = try XCTUnwrap(model.getPDFDocument(for: note))
        let page = try XCTUnwrap(document.page(at: 1))

        let window = NSWindow(contentRect: CGRect(x: 0, y: 0, width: 720, height: 600),
                              styleMask: [.titled], backing: .buffered, defer: false)
        let pdfView = PDFView()
        let tools = CanvasViewModel()
        let provider = AnnotatedPDFOverlayProvider(noteVM: model, canvasVM: tools)
        window.contentView = pdfView
        pdfView.displayMode = .singlePage
        pdfView.displayBox = .mediaBox
        pdfView.pageOverlayViewProvider = provider
        pdfView.document = document
        pdfView.go(to: page)
        pdfView.scaleFactor = 0.8
        pdfView.layoutDocumentView()
        window.displayIfNeeded()

        let overlay = try XCTUnwrap(provider.pdfView(pdfView, overlayViewFor: page) as? PageDrawingCanvas)
        XCTAssertTrue(overlay.window === window)
        let bitmap = try XCTUnwrap(overlay.bitmapImageRepForCachingDisplay(in: overlay.bounds))
        overlay.cacheDisplay(in: overlay.bounds, to: bitmap)
        let image = NSImage(size: overlay.bounds.size)
        image.addRepresentation(bitmap)
        let redPoint = overlay.convert(pdfView.convert(CGPoint(x: 280, y: 360), from: page), from: pdfView)
        let bluePoint = overlay.convert(pdfView.convert(CGPoint(x: 200, y: 280), from: page), from: pdfView)
        let red = try pixel(in: image, at: redPoint, width: overlay.bounds.width, height: overlay.bounds.height)
        let blue = try pixel(in: image, at: bluePoint, width: overlay.bounds.width, height: overlay.bounds.height)
        XCTAssertGreaterThan(red.redComponent - red.greenComponent, 0.8)
        XCTAssertGreaterThan(blue.blueComponent - blue.redComponent, 0.8)
    }

    private func pixel(in image: NSImage, at point: CGPoint, width: CGFloat, height: CGFloat) throws -> NSColor {
        let cgImage = try XCTUnwrap(image.cgImage(forProposedRect: nil, context: nil, hints: nil))
        let bitmap = NSBitmapImageRep(cgImage: cgImage)
        let x = Int(point.x / width * CGFloat(bitmap.pixelsWide))
        let y = Int((1 - point.y / height) * CGFloat(bitmap.pixelsHigh))
        return try XCTUnwrap(bitmap.colorAt(x: x, y: y)?.usingColorSpace(.deviceRGB))
    }
}
