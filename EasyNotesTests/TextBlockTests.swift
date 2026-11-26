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

    private func makePDFData(box: CGRect, pageCount: Int = 1) throws -> Data {
        let data = NSMutableData()
        let consumer = try XCTUnwrap(CGDataConsumer(data: data))
        let pdf = try XCTUnwrap(CGContext(consumer: consumer, mediaBox: nil, nil))
        var mediaBox = box
        for _ in 0..<pageCount {
            pdf.beginPage(mediaBox: &mediaBox)
            pdf.setFillColor(NSColor.white.cgColor)
            pdf.fill(mediaBox)
            pdf.endPage()
        }
        pdf.closePDF()
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

        let reopenedVM = NoteViewModel(context: reopened.viewContext, coverCache: NoteCoverCache())
        reopenedVM.deleteTextBlock(persistedBlock)
        XCTAssertEqual(persistedNote.textBlocksArray.count, 0)

        _ = reopenedVM.addTextBlock(to: persistedNote, pageIndex: 0, frame: frame, text: "Cascata")
        XCTAssertEqual(try reopened.viewContext.count(for: NSFetchRequest<TextBlock>(entityName: "TextBlock")), 1)
        persistedNote.isTrashed = true
        reopenedVM.deleteNote(persistedNote)
        XCTAssertEqual(try reopened.viewContext.count(for: NSFetchRequest<TextBlock>(entityName: "TextBlock")), 0)

        try close(reopened)
    }

    @MainActor
    func testMigratesHistoricalBaseAndEditorImageSQLiteStoresToTextBlockSchemaWithoutDataLoss() throws {
        let baseTimestamp = Date(timeIntervalSince1970: 1_700_000_000)

        // 1. Old historical schema before cover/emoji/gridColorHex and notebook hierarchy
        let oldestURL = try temporaryDirectory().appendingPathComponent("OldestLegacy.sqlite")
        let oldestModel = CoreDataStack.makeBaseModel()
        let beforeCoverFields: Set = ["gridColorHex", "emoji", "coverMediaData", "coverMediaType", "coverUpdatedAt"]
        let beforeHierarchyFields: Set = ["colorHex", "colorIndex", "parent", "children"]
        oldestModel.entitiesByName["Note"]?.properties.removeAll { beforeCoverFields.contains($0.name) }
        oldestModel.entitiesByName["Notebook"]?.properties.removeAll { beforeHierarchyFields.contains($0.name) }
        for entity in oldestModel.entities {
            entity.managedObjectClassName = NSStringFromClass(NSManagedObject.self)
        }
        let oldestContainer = NSPersistentContainer(name: "OldestLegacy", managedObjectModel: oldestModel)
        _ = try oldestContainer.persistentStoreCoordinator.addPersistentStore(
            ofType: NSSQLiteStoreType, configurationName: nil, at: oldestURL, options: nil
        )
        let oldestCtx = oldestContainer.viewContext
        let oldestNotebook = NSEntityDescription.insertNewObject(forEntityName: "Notebook", into: oldestCtx)
        oldestNotebook.setValuesForKeys(["id": UUID(), "name": "Antigo"])
        let oldestNote = NSEntityDescription.insertNewObject(forEntityName: "Note", into: oldestCtx)
        let oldestNoteID = UUID()
        oldestNote.setValuesForKeys([
            "id": oldestNoteID,
            "title": "Nota Muito Antiga",
            "content": "Conteúdo preservado",
            "createdAt": baseTimestamp,
            "updatedAt": baseTimestamp,
            "pageCount": Int16(1),
            "gridStyle": "lines",
            "notebook": oldestNotebook
        ])
        try oldestCtx.save()
        try close(oldestContainer)

        let migratedOldest = try TestSupport.makeSQLiteContainer(at: oldestURL)
        let restoredOldest = try XCTUnwrap(migratedOldest.viewContext.fetch(NSFetchRequest<Note>(entityName: "Note")).first)
        XCTAssertEqual(restoredOldest.id, oldestNoteID)
        XCTAssertEqual(restoredOldest.title, "Nota Muito Antiga")
        XCTAssertEqual(restoredOldest.notebook?.name, "Antigo")
        XCTAssertEqual(restoredOldest.textBlocksArray.count, 0)
        let oldestVM = NoteViewModel(context: migratedOldest.viewContext, coverCache: NoteCoverCache())
        _ = oldestVM.addTextBlock(to: restoredOldest, pageIndex: 0, frame: CGRect(x: 40, y: 500, width: 220, height: 72), text: "Migrado antigo")
        XCTAssertEqual(restoredOldest.textBlocksArray.first?.text, "Migrado antigo")
        try close(migratedOldest)

        // 2. Historical Base schema (with grid/cover/hierarchy, no EditorImage, no TextBlock)
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
        try close(migratedBase)

        // 3. EditorImage-generation schema (has EditorImage, no TextBlock)
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
    func testRenderAndExportPDFWithTextBlockIsUprightAndSkipsEmptyGhostCards() throws {
        let (vm, _) = TestSupport.makeInMemoryViewModel()
        vm.addNote(title: "Export TextBlock")
        let note = try XCTUnwrap(vm.selectedNote)

        let frame = CGRect(x: 100, y: 400, width: 240, height: 140)
        let block = try XCTUnwrap(vm.addTextBlock(
            to: note,
            pageIndex: 0,
            frame: frame,
            text: "MMMM",
            fontSize: 28,
            colorHex: "#FF0000"
        ))

        // Add an empty/whitespace block that must NOT render any phantom card border/fill
        let emptyFrame = CGRect(x: 100, y: 120, width: 200, height: 80)
        _ = try XCTUnwrap(vm.addTextBlock(
            to: note,
            pageIndex: 0,
            frame: emptyFrame,
            text: "   \n ",
            fontSize: 15,
            colorHex: "#000000"
        ))

        let dest = try temporaryDirectory().appendingPathComponent("TextBlockExport.pdf")
        try vm.exportPDF(for: note, to: dest, options: PDFExportOptions(includeGrid: false))

        let exportedDoc = try XCTUnwrap(PDFDocument(url: dest))
        XCTAssertEqual(exportedDoc.pageCount, 1)
        let page = try XCTUnwrap(exportedDoc.page(at: 0))
        XCTAssertTrue(page.string?.contains("MMMM") == true, "Expected exported PDF to contain vector text")

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

        // Verify empty/whitespace block draws no border/card into a pure white bitmap
        let emptyBitmap = try XCTUnwrap(CGContext(
            data: nil, width: 612, height: 792,
            bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ))
        emptyBitmap.setFillColor(NSColor.white.cgColor)
        emptyBitmap.fill(CGRect(origin: .zero, size: pageSize))
        renderTextBlocks(for: note, pageIndex: 0, into: emptyBitmap, excluding: block.id)
        let emptyRep = NSBitmapImageRep(cgImage: try XCTUnwrap(emptyBitmap.makeImage()))
        let borderPixel = try XCTUnwrap(emptyRep.colorAt(x: Int(emptyFrame.minX), y: Int(pageSize.height - emptyFrame.midY))?.usingColorSpace(.deviceRGB))
        XCTAssertGreaterThan(borderPixel.redComponent, 0.99)
        XCTAssertGreaterThan(borderPixel.greenComponent, 0.99)
        XCTAssertGreaterThan(borderPixel.blueComponent, 0.99)
    }

    @MainActor
    func testInlineDraftDoesNotPersistEmptyAndExistingBlockRestoresTextWhenEmptied() throws {
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

        // 1. Click empty area near top-right edge -> in-memory draft ONLY (not in Core Data yet)
        try click(at: NSPoint(x: 590, y: 770))
        let overlay = try XCTUnwrap(canvas.activeTextEditor)
        XCTAssertTrue(overlay.isNewDraft)
        XCTAssertNil(overlay.existingBlock)
        XCTAssertEqual(note.textBlocksArray.count, 0)
        XCTAssertTrue(window.firstResponder === overlay.textView)
        XCTAssertTrue(canvas.bounds.contains(overlay.currentPageFrame))
        XCTAssertEqual(canvasVM.editingTextBlockID, overlay.blockID)

        // 2. Leave whitespace only and press Escape -> discarded without touching Core Data
        overlay.textView.string = "   \n  "
        overlay.textView.cancelOperation(nil)
        XCTAssertNil(canvas.activeTextEditor)
        XCTAssertNil(canvasVM.editingTextBlockID)
        XCTAssertEqual(note.textBlocksArray.count, 0)

        // 3. Click empty area, type multiline text, press Escape -> persisted
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

        // 4. Click existing block, clear text completely, press Escape -> restores original text (does not delete)
        try click(at: NSPoint(x: savedBlock.frame.midX, y: savedBlock.frame.midY))
        let editor3 = try XCTUnwrap(canvas.activeTextEditor)
        XCTAssertFalse(editor3.isNewDraft)
        XCTAssertEqual(editor3.blockID, savedBlock.id)
        editor3.textView.string = ""
        editor3.textView.cancelOperation(nil)
        XCTAssertNil(canvas.activeTextEditor)
        XCTAssertEqual(note.textBlocksArray.count, 1)
        XCTAssertEqual(savedBlock.text, "Linha 1\nLinha 2 áéíóú")

        // 5. Click existing block, append text, click outside -> commits without creating another block
        try click(at: NSPoint(x: savedBlock.frame.midX, y: savedBlock.frame.midY))
        let editor4 = try XCTUnwrap(canvas.activeTextEditor)
        editor4.textView.insertText("!", replacementRange: editor4.textView.selectedRange())
        try click(at: NSPoint(x: 20, y: 20))
        XCTAssertNil(canvas.activeTextEditor)
        XCTAssertEqual(note.textBlocksArray.count, 1)
        XCTAssertEqual(savedBlock.text, "Linha 1\nLinha 2 áéíóú!")
    }

    @MainActor
    func testPDFViewScaledAndOffsetMediaBoxInlineTextBlockAlignmentAndCommitHook() throws {
        _ = NSApplication.shared
        let (vm, context) = TestSupport.makeInMemoryViewModel()
        vm.addNote(title: "Scaled Offset")
        let note = try XCTUnwrap(vm.selectedNote)
        let mediaBox = CGRect(x: 40, y: 70, width: 400, height: 500)
        note.pdfData = try makePDFData(box: mediaBox)
        note.pageCount = 1
        try context.save()

        let doc = try XCTUnwrap(vm.getPDFDocument(for: note))
        let page = try XCTUnwrap(doc.page(at: 0))

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 700, height: 700),
            styleMask: [.titled], backing: .buffered, defer: false
        )
        let canvasVM = CanvasViewModel()
        canvasVM.selectTool(.textBox)

        let representable = PDFAnnotationCanvasView(
            canvasVM: canvasVM,
            noteVM: vm,
            noteId: note.id,
            focusTarget: CanvasFocusTarget(),
            zoomScale: .constant(1.5),
            selectedPageIndex: .constant(0)
        )
        let coordinator = representable.makeCoordinator()
        let pdfView = NSPDFAnnotationView(frame: window.contentView!.bounds)
        pdfView.displayMode = .singlePageContinuous
        pdfView.displayBox = .mediaBox
        pdfView.autoScales = false
        pdfView.scaleFactor = 1.5
        pdfView.pageOverlayViewProvider = coordinator.provider
        pdfView.document = doc
        window.contentView = pdfView
        pdfView.go(to: page)
        pdfView.layoutDocumentView()
        window.displayIfNeeded()

        let overlay = try XCTUnwrap(coordinator.provider.pdfView(pdfView, overlayViewFor: page) as? PageDrawingCanvas)
        let targetPagePoint = CGPoint(x: 150, y: 360)
        let localPoint = overlay.convert(pdfView.convert(targetPagePoint, from: page), from: pdfView)
        let windowPoint = overlay.convert(localPoint, to: nil)

        let down = try XCTUnwrap(NSEvent.mouseEvent(
            with: .leftMouseDown,
            location: windowPoint,
            modifierFlags: [],
            timestamp: 0,
            windowNumber: window.windowNumber,
            context: nil,
            eventNumber: 1,
            clickCount: 1,
            pressure: 1
        ))
        overlay.mouseDown(with: down)

        let editor = try XCTUnwrap(overlay.activeTextEditor)
        XCTAssertTrue(mediaBox.contains(editor.currentPageFrame))
        XCTAssertEqual(editor.currentPageFrame.minX, 150, accuracy: 1.5)
        XCTAssertEqual(editor.currentPageFrame.maxY, 360, accuracy: 1.5)

        // Overlay subview frame in PageDrawingCanvas matches mediaBox projection
        let expectedOrigin = overlay.convert(pdfView.convert(editor.currentPageFrame.origin, from: page), from: pdfView)
        XCTAssertEqual(editor.frame.minX, expectedOrigin.x, accuracy: 1.5)
        XCTAssertEqual(editor.frame.minY, expectedOrigin.y, accuracy: 1.5)

        editor.textView.insertText("Texto em zoom 1.5x", replacementRange: editor.textView.selectedRange())

        // Commit deterministically through the CanvasViewModel hook (used by export/back/terminate)
        canvasVM.commitActiveTextEdits()
        XCTAssertNil(overlay.activeTextEditor)
        XCTAssertEqual(note.textBlocksArray.count, 1)
        XCTAssertEqual(note.textBlocksArray.first?.text, "Texto em zoom 1.5x")

        let dest = try temporaryDirectory().appendingPathComponent("OffsetExport.pdf")
        try vm.exportPDF(for: note, to: dest, options: PDFExportOptions(includeGrid: false))
        let exported = try XCTUnwrap(PDFDocument(url: dest))
        XCTAssertTrue(exported.page(at: 0)?.string?.contains("Texto em zoom 1.5x") == true)

        PDFAnnotationCanvasView.dismantleNSView(pdfView, coordinator: coordinator)
        XCTAssertNil(canvasVM.onCommitActiveTextEdits)
        XCTAssertTrue(coordinator.notificationObservers.isEmpty)
    }

    @MainActor
    func testVerticalAutoExpansionNearBottomMarginShiftsUpWithinMediaBox() throws {
        _ = NSApplication.shared
        let (vm, _) = TestSupport.makeInMemoryViewModel()
        vm.addNote(title: "Bottom Expansion")
        let note = try XCTUnwrap(vm.selectedNote)

        let canvasVM = CanvasViewModel()
        canvasVM.selectTool(.textBox)

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 612, height: 792),
            styleMask: [.titled], backing: .buffered, defer: false
        )
        let canvas = PageDrawingCanvas(pageIndex: 0, noteVM: vm, canvasVM: canvasVM)
        canvas.frame = NSRect(x: 0, y: 0, width: 612, height: 792)
        window.contentView = canvas

        // Click near the bottom edge so initial frame sits right above bottom margin
        let down = try XCTUnwrap(NSEvent.mouseEvent(
            with: .leftMouseDown,
            location: NSPoint(x: 100, y: 90),
            modifierFlags: [],
            timestamp: 0,
            windowNumber: window.windowNumber,
            context: nil,
            eventNumber: 1,
            clickCount: 1,
            pressure: 1
        ))
        canvas.mouseDown(with: down)

        let editor = try XCTUnwrap(canvas.activeTextEditor)
        let initialFrame = editor.currentPageFrame
        XCTAssertEqual(initialFrame.height, 72, accuracy: 0.5)

        let manyLines = (1...12).map { "Linha de teste \($0)" }.joined(separator: "\n")
        editor.textView.insertText(manyLines, replacementRange: editor.textView.selectedRange())

        let expanded = editor.currentPageFrame
        XCTAssertGreaterThan(expanded.height, initialFrame.height)
        XCTAssertGreaterThanOrEqual(expanded.minY, canvas.bounds.minY + TextBlockLayout.pageMargin - 0.1)
        XCTAssertLessThanOrEqual(expanded.maxY, canvas.bounds.maxY - TextBlockLayout.pageMargin + 0.1)
        XCTAssertGreaterThan(expanded.maxY, initialFrame.maxY, "Expected block near bottom margin to shift upward so it keeps growing")
        XCTAssertTrue(canvas.bounds.contains(expanded))
    }

    @MainActor
    func testStylePopoverKeepsInlineEditorOpenSyncsStyleAndRestoresFocus() throws {
        _ = NSApplication.shared
        let (vm, _) = TestSupport.makeInMemoryViewModel()
        vm.addNote(title: "Style Popover Sync")
        let note = try XCTUnwrap(vm.selectedNote)

        let canvasVM = CanvasViewModel()
        canvasVM.selectTool(.textBox)

        let representable = PDFAnnotationCanvasView(
            canvasVM: canvasVM,
            noteVM: vm,
            noteId: note.id,
            focusTarget: CanvasFocusTarget(),
            zoomScale: .constant(1.0),
            selectedPageIndex: .constant(0)
        )
        let coordinator = representable.makeCoordinator()
        let pdfView = NSPDFAnnotationView(frame: NSRect(x: 0, y: 0, width: 612, height: 792))
        pdfView.displayMode = .singlePageContinuous
        pdfView.displayBox = .mediaBox
        pdfView.pageOverlayViewProvider = coordinator.provider
        let doc = try XCTUnwrap(vm.getPDFDocument(for: note))
        let page = try XCTUnwrap(doc.page(at: 0))
        pdfView.document = doc

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 612, height: 792),
            styleMask: [.titled], backing: .buffered, defer: false
        )
        window.contentView = pdfView
        pdfView.layoutDocumentView()
        window.displayIfNeeded()

        let canvas = try XCTUnwrap(coordinator.provider.pdfView(pdfView, overlayViewFor: page) as? PageDrawingCanvas)
        let localPoint = canvas.convert(pdfView.convert(CGPoint(x: 120, y: 500), from: page), from: pdfView)
        let down = try XCTUnwrap(NSEvent.mouseEvent(
            with: .leftMouseDown,
            location: canvas.convert(localPoint, to: nil),
            modifierFlags: [],
            timestamp: 0,
            windowNumber: window.windowNumber,
            context: nil,
            eventNumber: 1,
            clickCount: 1,
            pressure: 1
        ))
        canvas.mouseDown(with: down)

        let editor = try XCTUnwrap(canvas.activeTextEditor)
        editor.textView.insertText("Estilo dinâmico", replacementRange: editor.textView.selectedRange())

        // Simulate toolbar style popover opening and stealing first responder
        canvasVM.isTextStylePopoverPresented = true
        let outsideField = NSTextField(frame: NSRect(x: 0, y: 0, width: 100, height: 24))
        window.contentView?.addSubview(outsideField)
        window.makeFirstResponder(outsideField)
        RunLoop.main.run(until: Date().addingTimeInterval(0.05))

        XCTAssertNotNil(canvas.activeTextEditor, "Opening style popover must not close active text editor")

        // Change font size and color while popover is open
        canvasVM.textFontSize = 26
        canvasVM.applyStrokeColor(Color(nsColor: NSColor(hex: "#FF0000")!))
        RunLoop.main.run(until: Date().addingTimeInterval(0.05))

        XCTAssertEqual(editor.currentFontSize, 26, accuracy: 0.001)
        XCTAssertEqual(editor.currentColorHex, "#FF0000")

        // Close popover and restore focus
        canvasVM.isTextStylePopoverPresented = false
        canvasVM.restoreTextEditorFocus()
        XCTAssertTrue(window.firstResponder === editor.textView)

        canvasVM.commitActiveTextEdits()
        let saved = try XCTUnwrap(note.textBlocksArray.first)
        XCTAssertEqual(saved.fontSize, 26, accuracy: 0.001)
        XCTAssertEqual(saved.colorHex, "#FF0000")

        PDFAnnotationCanvasView.dismantleNSView(pdfView, coordinator: coordinator)
    }

    @MainActor
    func testCommandShiftZRedoAndEscapeWithMarkedText() throws {
        _ = NSApplication.shared
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 200),
            styleMask: [.titled], backing: .buffered, defer: false
        )
        let textView = InlineTextBlockTextView(frame: NSRect(x: 0, y: 0, width: 300, height: 100))
        textView.allowsUndo = true
        window.contentView?.addSubview(textView)
        XCTAssertTrue(window.makeFirstResponder(textView))

        var escapeCount = 0
        textView.onEscape = { escapeCount += 1 }

        // Marked text (IME composition): Escape cancels composition and must NOT close editor
        textView.setMarkedText("´", selectedRange: NSRange(location: 1, length: 0), replacementRange: NSRange(location: NSNotFound, length: 0))
        XCTAssertTrue(textView.hasMarkedText())
        textView.cancelOperation(nil)
        XCTAssertEqual(escapeCount, 0)
        XCTAssertFalse(textView.hasMarkedText())

        textView.cancelOperation(nil)
        XCTAssertEqual(escapeCount, 1)

        // Undo (⌘Z) + Redo (⇧⌘Z) on clean undo stack
        textView.string = ""
        textView.undoManager?.removeAllActions()
        textView.insertText("Primeiro", replacementRange: NSRange(location: 0, length: 0))
        textView.breakUndoCoalescing()
        let undoEvent = try XCTUnwrap(NSEvent.keyEvent(
            with: .keyDown, location: .zero, modifierFlags: [.command],
            timestamp: 0, windowNumber: window.windowNumber, context: nil,
            characters: "z", charactersIgnoringModifiers: "z", isARepeat: false, keyCode: 6
        ))
        XCTAssertTrue(textView.performKeyEquivalent(with: undoEvent))
        XCTAssertEqual(textView.string, "")

        let redoEvent = try XCTUnwrap(NSEvent.keyEvent(
            with: .keyDown, location: .zero, modifierFlags: [.command, .shift],
            timestamp: 0, windowNumber: window.windowNumber, context: nil,
            characters: "Z", charactersIgnoringModifiers: "z", isARepeat: false, keyCode: 6
        ))
        XCTAssertTrue(textView.performKeyEquivalent(with: redoEvent))
        XCTAssertEqual(textView.string, "Primeiro")
    }

    func testDefaultFrameAndClampedFrameWithSmallMediaBox() {
        let mediaBox = CGRect(x: 40, y: 70, width: 300, height: 200)
        let edgeFrame = TextBlockLayout.defaultFrame(at: CGPoint(x: 335, y: 265), in: mediaBox)
        XCTAssertTrue(mediaBox.contains(edgeFrame))

        let tinyBox = CGRect(x: 10, y: 20, width: 24, height: 18)
        let tinyDefault = TextBlockLayout.defaultFrame(at: CGPoint(x: 20, y: 30), in: tinyBox)
        XCTAssertTrue(tinyBox.contains(tinyDefault))

        let oversized = CGRect(x: 0, y: 0, width: 500, height: 400)
        let clamped = TextBlockLayout.clampedFrame(oversized, in: tinyBox)
        XCTAssertLessThanOrEqual(clamped.width, tinyBox.width)
        XCTAssertLessThanOrEqual(clamped.height, tinyBox.height)
        XCTAssertTrue(tinyBox.contains(clamped))
    }
}
