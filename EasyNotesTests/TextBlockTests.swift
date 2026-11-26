import AppKit
import CoreData
import PDFKit
import SwiftUI
import XCTest

final class TextBlockTests: XCTestCase {
    private func temporaryDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: false)
        addTeardownBlock { try? FileManager.default.removeItem(at: url) }
        return url
    }

    private func close(_ container: NSPersistentContainer) throws {
        container.viewContext.reset()
        let coordinator = container.persistentStoreCoordinator
        for store in coordinator.persistentStores {
            try coordinator.remove(store)
        }
    }

    private func samplePNGData() throws -> Data {
        let bitmap = try XCTUnwrap(CGContext(
            data: nil, width: 120, height: 80,
            bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
        ))
        bitmap.setFillColor(NSColor.blue.cgColor)
        bitmap.fill(CGRect(x: 0, y: 0, width: 120, height: 80))
        let data = NSMutableData()
        let dest = try XCTUnwrap(CGImageDestinationCreateWithData(data, "public.png" as CFString, 1, nil))
        CGImageDestinationAddImage(dest, try XCTUnwrap(bitmap.makeImage()), nil)
        XCTAssertTrue(CGImageDestinationFinalize(dest))
        return data as Data
    }

    @MainActor
    func testTextBlockCRUDPersistenceAndCascadeDelete() throws {
        let storeURL = try temporaryDirectory().appendingPathComponent("TextBlockCRUD.sqlite")
        let container = try TestSupport.makeSQLiteContainer(at: storeURL)
        let vm = NoteViewModel(context: container.viewContext, coverCache: NoteCoverCache())
        vm.addNote(title: "Nota com Texto")
        let note = try XCTUnwrap(vm.selectedNote)
        let noteID = note.id

        let frame = CGRect(x: 80, y: 520, width: 220, height: 72)
        let block = try XCTUnwrap(vm.addTextBlock(
            to: note,
            pageIndex: 0,
            frame: frame,
            text: "Anotação inicial",
            fontSize: 18,
            colorHex: "#2B7A8C"
        ))
        let blockID = block.id
        XCTAssertEqual(note.textBlocksArray.count, 1)
        XCTAssertEqual(block.frame, frame)

        let beforeUpdate = block.updatedAt
        Thread.sleep(forTimeInterval: 0.01)
        vm.updateTextBlock(block, text: "Texto atualizado", fontSize: 22, colorHex: "#FF0000")
        XCTAssertGreaterThan(block.updatedAt, beforeUpdate)

        try close(container)

        // Reopen store and verify persistence
        let reopened = try TestSupport.makeSQLiteContainer(at: storeURL)
        let fetch = NSFetchRequest<Note>(entityName: "Note")
        fetch.predicate = NSPredicate(format: "id == %@", noteID as CVarArg)
        let persistedNote = try XCTUnwrap(reopened.viewContext.fetch(fetch).first)
        let persistedBlock = try XCTUnwrap(persistedNote.textBlocksArray.first)
        XCTAssertEqual(persistedBlock.id, blockID)
        XCTAssertEqual(persistedBlock.text, "Texto atualizado")
        XCTAssertEqual(persistedBlock.fontSize, 22, accuracy: 0.001)
        XCTAssertEqual(persistedBlock.colorHex, "#FF0000")
        XCTAssertEqual(persistedBlock.frame, frame)

        // Delete single block
        let reopenedVM = NoteViewModel(context: reopened.viewContext, coverCache: NoteCoverCache())
        reopenedVM.deleteTextBlock(persistedBlock)
        XCTAssertEqual(persistedNote.textBlocksArray.count, 0)

        // Cascade delete when deleting Note permanently
        _ = reopenedVM.addTextBlock(to: persistedNote, pageIndex: 0, frame: frame, text: "Cascata")
        XCTAssertEqual(try reopened.viewContext.count(for: NSFetchRequest<TextBlock>(entityName: "TextBlock")), 1)
        persistedNote.isTrashed = true
        reopenedVM.deleteNote(persistedNote)
        XCTAssertEqual(try reopened.viewContext.count(for: NSFetchRequest<TextBlock>(entityName: "TextBlock")), 0)

        try close(reopened)
    }

    @MainActor
    func testMigratesBaseAndEditorImageSQLiteStoresToTextBlockSchemaWithoutDataLoss() throws {
        // 1. Historical Base schema (no EditorImage, no TextBlock)
        let baseURL = try temporaryDirectory().appendingPathComponent("BaseLegacy.sqlite")
        let baseModel = CoreDataStack.makeBaseModel()
        for entity in baseModel.entities {
            entity.managedObjectClassName = NSStringFromClass(NSManagedObject.self)
        }
        let baseContainer = NSPersistentContainer(name: "BaseLegacy", managedObjectModel: baseModel)
        _ = try baseContainer.persistentStoreCoordinator.addPersistentStore(
            ofType: NSSQLiteStoreType, configurationName: nil, at: baseURL, options: nil
        )
        let baseCtx = baseContainer.viewContext
        let baseTimestamp = Date(timeIntervalSince1970: 1_700_000_000)
        let baseNote = NSEntityDescription.insertNewObject(forEntityName: "Note", into: baseCtx)
        let baseNoteID = UUID()
        baseNote.setValuesForKeys([
            "id": baseNoteID,
            "title": "Nota Base",
            "content": "Conteúdo Base",
            "createdAt": baseTimestamp,
            "updatedAt": baseTimestamp,
            "pageCount": Int16(1),
            "gridStyle": "none"
        ])
        try baseCtx.save()
        try close(baseContainer)

        let migratedBase = try TestSupport.makeSQLiteContainer(at: baseURL)
        let migratedBaseNote = try XCTUnwrap(migratedBase.viewContext.fetch(NSFetchRequest<Note>(entityName: "Note")).first)
        XCTAssertEqual(migratedBaseNote.id, baseNoteID)
        XCTAssertEqual(migratedBaseNote.title, "Nota Base")
        XCTAssertEqual(migratedBaseNote.textBlocksArray.count, 0)
        let baseVM = NoteViewModel(context: migratedBase.viewContext, coverCache: NoteCoverCache())
        _ = baseVM.addTextBlock(to: migratedBaseNote, pageIndex: 0, frame: CGRect(x: 50, y: 500, width: 220, height: 72), text: "Migrado Base")
        XCTAssertEqual(migratedBaseNote.textBlocksArray.count, 1)
        try close(migratedBase)

        // 2. EditorImage-generation schema (has EditorImage, no TextBlock)
        let imageGenURL = try temporaryDirectory().appendingPathComponent("EditorImageGen.sqlite")
        let imageGenModel = CoreDataStack.makeEditorImageModel()
        for entity in imageGenModel.entities {
            entity.managedObjectClassName = NSStringFromClass(NSManagedObject.self)
        }
        let imageGenContainer = NSPersistentContainer(name: "ImageGen", managedObjectModel: imageGenModel)
        _ = try imageGenContainer.persistentStoreCoordinator.addPersistentStore(
            ofType: NSSQLiteStoreType, configurationName: nil, at: imageGenURL, options: nil
        )
        let imgCtx = imageGenContainer.viewContext
        let imgNoteID = UUID()
        let imgID = UUID()
        let png = try samplePNGData()

        let imgNote = NSEntityDescription.insertNewObject(forEntityName: "Note", into: imgCtx)
        imgNote.setValuesForKeys([
            "id": imgNoteID,
            "title": "Nota com Imagem",
            "content": "Texto preservado",
            "createdAt": baseTimestamp,
            "updatedAt": baseTimestamp,
            "pageCount": Int16(1),
            "gridStyle": "grid"
        ])
        let imgObj = NSEntityDescription.insertNewObject(forEntityName: "EditorImage", into: imgCtx)
        imgObj.setValuesForKeys([
            "id": imgID,
            "createdAt": baseTimestamp,
            "pageIndex": Int16(0),
            "data": png,
            "x": 100.0,
            "y": 200.0,
            "width": 120.0,
            "height": 80.0,
            "note": imgNote
        ])
        try imgCtx.save()
        try close(imageGenContainer)

        let migratedImg = try TestSupport.makeSQLiteContainer(at: imageGenURL)
        let restoredNote = try XCTUnwrap(migratedImg.viewContext.fetch(NSFetchRequest<Note>(entityName: "Note")).first)
        XCTAssertEqual(restoredNote.id, imgNoteID)
        XCTAssertEqual(restoredNote.title, "Nota com Imagem")
        let restoredImg = try XCTUnwrap(restoredNote.editorImages?.anyObject() as? EditorImage)
        XCTAssertEqual(restoredImg.id, imgID)
        XCTAssertEqual(restoredImg.data, png)
        XCTAssertEqual(restoredNote.textBlocksArray.count, 0)

        let imgVM = NoteViewModel(context: migratedImg.viewContext, coverCache: NoteCoverCache())
        _ = imgVM.addTextBlock(to: restoredNote, pageIndex: 0, frame: CGRect(x: 120, y: 400, width: 220, height: 72), text: "Novo bloco")
        try close(migratedImg)

        let reopenedImg = try TestSupport.makeSQLiteContainer(at: imageGenURL)
        let finalNote = try XCTUnwrap(reopenedImg.viewContext.fetch(NSFetchRequest<Note>(entityName: "Note")).first)
        XCTAssertEqual(finalNote.textBlocksArray.first?.text, "Novo bloco")
        XCTAssertEqual((finalNote.editorImages?.anyObject() as? EditorImage)?.id, imgID)
        try close(reopenedImg)
    }

    @MainActor
    func testDrawnObjectCountAndUndoIncludesTextBlockInChronologicalOrder() throws {
        let (vm, context) = TestSupport.makeInMemoryViewModel()
        vm.addNote(title: "Undo TextBlock")
        let note = try XCTUnwrap(vm.selectedNote)

        let stroke = Stroke(context: context)
        stroke.id = UUID()
        stroke.points = "0,0;10,10"
        stroke.width = 3
        stroke.color = "#000000"
        stroke.createdAt = Date(timeIntervalSince1970: 1000)
        stroke.pageIndex = 0
        stroke.note = note

        let shape = ShapeObject(context: context)
        shape.id = UUID()
        shape.kind = "rectangle"
        shape.points = "0,0;20,20"
        shape.strokeColor = "#000000"
        shape.strokeWidth = 3
        shape.createdAt = Date(timeIntervalSince1970: 2000)
        shape.pageIndex = 0
        shape.note = note

        let block = try XCTUnwrap(vm.addTextBlock(
            to: note,
            pageIndex: 0,
            frame: CGRect(x: 60, y: 500, width: 220, height: 72),
            text: "Mais recente"
        ))
        block.createdAt = Date(timeIntervalSince1970: 3000)
        try context.save()

        XCTAssertEqual(vm.drawnObjectCount(for: note), 3)

        vm.undoLastObject()
        XCTAssertEqual(note.textBlocksArray.count, 0)
        XCTAssertEqual(vm.drawnObjectCount(for: note), 2)

        vm.undoLastObject()
        XCTAssertEqual(note.shapesArray.count, 0)
        XCTAssertEqual(vm.drawnObjectCount(for: note), 1)

        vm.undoLastObject()
        XCTAssertEqual(note.strokesArray.count, 0)
        XCTAssertEqual(vm.drawnObjectCount(for: note), 0)
    }

    @MainActor
    func testRenderAndExportPDFWithTextBlockIsUprightAndValid() throws {
        let (vm, _) = TestSupport.makeInMemoryViewModel()
        vm.addNote(title: "Export TextBlock")
        let note = try XCTUnwrap(vm.selectedNote)

        // Tall block with a short line of bright red text so upright CoreText renders
        // glyphs in the TOP half of the block and leaves the bottom half white.
        let frame = CGRect(x: 100, y: 400, width: 240, height: 140)
        let block = try XCTUnwrap(vm.addTextBlock(
            to: note,
            pageIndex: 0,
            frame: frame,
            text: "MMMM",
            fontSize: 28,
            colorHex: "#FF0000"
        ))

        let dest = try temporaryDirectory().appendingPathComponent("TextBlockExport.pdf")
        try vm.exportPDF(for: note, to: dest, options: PDFExportOptions(includeGrid: false))

        let exportedDoc = try XCTUnwrap(PDFDocument(url: dest))
        XCTAssertEqual(exportedDoc.pageCount, 1)
        let page = try XCTUnwrap(exportedDoc.page(at: 0))
        XCTAssertTrue(page.string?.contains("MMMM") == true, "Expected exported PDF to contain vector text")

        // Verify upright orientation on exported page AND thumbnail
        let sourcePage = try XCTUnwrap(vm.getPDFDocument(for: note)?.page(at: 0))
        let thumbImage = PageThumbnail.renderThumbnail(for: sourcePage, note: note, pageIndex: 0)
        let exportedImage = page.thumbnail(of: CGSize(width: 612, height: 792), for: .mediaBox)

        func hasRedPixels(in image: NSImage, mediaBoxRect: CGRect, pageSize: CGSize) throws -> Bool {
            let cg = try XCTUnwrap(image.cgImage(forProposedRect: nil, context: nil, hints: nil))
            let rep = NSBitmapImageRep(cgImage: cg)
            let minX = max(0, Int(mediaBoxRect.minX / pageSize.width * CGFloat(rep.pixelsWide)))
            let maxX = min(rep.pixelsWide - 1, Int(mediaBoxRect.maxX / pageSize.width * CGFloat(rep.pixelsWide)))
            let minRasterY = max(0, Int((1 - mediaBoxRect.maxY / pageSize.height) * CGFloat(rep.pixelsHigh)))
            let maxRasterY = min(rep.pixelsHigh - 1, Int((1 - mediaBoxRect.minY / pageSize.height) * CGFloat(rep.pixelsHigh)))

            for x in minX...maxX {
                for y in minRasterY...maxRasterY {
                    guard let c = rep.colorAt(x: x, y: y)?.usingColorSpace(.deviceRGB) else { continue }
                    if c.redComponent - c.greenComponent > 0.35 {
                        return true
                    }
                }
            }
            return false
        }

        let topBand = CGRect(x: frame.minX + 8, y: frame.maxY - 48, width: 120, height: 42)
        let bottomBand = CGRect(x: frame.minX + 8, y: frame.minY + 6, width: 120, height: 42)
        let pageSize = page.bounds(for: .mediaBox).size

        XCTAssertTrue(try hasRedPixels(in: exportedImage, mediaBoxRect: topBand, pageSize: pageSize))
        XCTAssertFalse(try hasRedPixels(in: exportedImage, mediaBoxRect: bottomBand, pageSize: pageSize))
        XCTAssertTrue(try hasRedPixels(in: thumbImage, mediaBoxRect: topBand, pageSize: pageSize))
        XCTAssertFalse(try hasRedPixels(in: thumbImage, mediaBoxRect: bottomBand, pageSize: pageSize))

        // Verify excluding parameter hides the active editing block
        let bitmap = try XCTUnwrap(CGContext(
            data: nil, width: 612, height: 792,
            bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ))
        bitmap.setFillColor(NSColor.white.cgColor)
        bitmap.fill(CGRect(origin: .zero, size: pageSize))
        renderTextBlocks(for: note, pageIndex: 0, into: bitmap, excluding: block.id)
        let excludedImage = NSImage(cgImage: try XCTUnwrap(bitmap.makeImage()), size: pageSize)
        XCTAssertFalse(try hasRedPixels(in: excludedImage, mediaBoxRect: topBand, pageSize: pageSize))
    }

    @MainActor
    func testInlineTextBlockCreationEditingEscapeAndEmptyCleanup() throws {
        _ = NSApplication.shared
        let (vm, _) = TestSupport.makeInMemoryViewModel()
        vm.addNote(title: "Inline Editor")
        let note = try XCTUnwrap(vm.selectedNote)

        let canvasVM = CanvasViewModel()
        canvasVM.selectTool(.textBox)
        canvasVM.textFontSize = 18
        canvasVM.applyStrokeColor(Color(nsColor: NSColor(hex: "#2B7A8C")!))

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 612, height: 792),
            styleMask: [.titled], backing: .buffered, defer: false
        )
        let canvas = PageDrawingCanvas(pageIndex: 0, noteVM: vm, canvasVM: canvasVM)
        canvas.frame = NSRect(x: 0, y: 0, width: 612, height: 792)
        window.contentView = canvas

        func click(at point: NSPoint) throws {
            let event = try XCTUnwrap(NSEvent.mouseEvent(
                with: .leftMouseDown,
                location: point,
                modifierFlags: [],
                timestamp: 0,
                windowNumber: window.windowNumber,
                context: nil,
                eventNumber: 1,
                clickCount: 1,
                pressure: 1
            ))
            canvas.mouseDown(with: event)
        }

        // 1. Click empty area near top-right edge -> clamped inside page & focused
        try click(at: NSPoint(x: 590, y: 770))
        let overlay = try XCTUnwrap(canvas.activeTextEditor)
        XCTAssertTrue(window.firstResponder === overlay.textView)
        XCTAssertTrue(canvas.bounds.contains(overlay.block.frame))
        XCTAssertEqual(canvasVM.editingTextBlockID, overlay.block.id)

        // 2. Leave whitespace only and press Escape -> auto-deleted, no ghost block
        overlay.textView.string = "   \n  "
        overlay.textView.cancelOperation(nil)
        XCTAssertNil(canvas.activeTextEditor)
        XCTAssertNil(canvasVM.editingTextBlockID)
        XCTAssertEqual(note.textBlocksArray.count, 0)

        // 3. Click empty area, type multiline text, press Escape -> saved
        try click(at: NSPoint(x: 120, y: 500))
        let editor2 = try XCTUnwrap(canvas.activeTextEditor)
        editor2.textView.insertText("Linha 1\nLinha 2 áéíóú", replacementRange: editor2.textView.selectedRange())
        editor2.textView.cancelOperation(nil)
        XCTAssertNil(canvas.activeTextEditor)
        XCTAssertEqual(note.textBlocksArray.count, 1)
        let savedBlock = try XCTUnwrap(note.textBlocksArray.first)
        XCTAssertEqual(savedBlock.text, "Linha 1\nLinha 2 áéíóú")
        XCTAssertEqual(savedBlock.fontSize, 18, accuracy: 0.001)
        XCTAssertEqual(savedBlock.colorHex, "#2B7A8C")

        // 4. Click existing block -> opens editor with existing text; click outside -> commits without creating new block
        try click(at: NSPoint(x: savedBlock.frame.midX, y: savedBlock.frame.midY))
        let editor3 = try XCTUnwrap(canvas.activeTextEditor)
        XCTAssertEqual(editor3.block.id, savedBlock.id)
        editor3.textView.insertText("!", replacementRange: editor3.textView.selectedRange())
        try click(at: NSPoint(x: 20, y: 20))
        XCTAssertNil(canvas.activeTextEditor)
        XCTAssertEqual(note.textBlocksArray.count, 1)
        XCTAssertEqual(savedBlock.text, "Linha 1\nLinha 2 áéíóú!")
    }

    func testDefaultFrameClampsInsideMediaBox() {
        let mediaBox = CGRect(x: 40, y: 70, width: 300, height: 200)
        let edgeFrame = TextBlockLayout.defaultFrame(at: CGPoint(x: 335, y: 265), in: mediaBox)
        XCTAssertTrue(mediaBox.contains(edgeFrame))

        let tinyBox = CGRect(x: 0, y: 0, width: 100, height: 50)
        let tinyFrame = TextBlockLayout.defaultFrame(at: CGPoint(x: 80, y: 40), in: tinyBox)
        XCTAssertTrue(tinyBox.contains(tinyFrame))
    }
}
