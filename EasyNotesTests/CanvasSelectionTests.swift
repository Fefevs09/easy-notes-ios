import AppKit
import CoreData
import ImageIO
import PDFKit
import SwiftUI
import UniformTypeIdentifiers
import XCTest

@MainActor
final class CanvasSelectionTests: XCTestCase {
    var context: NSManagedObjectContext!
    var viewModel: NoteViewModel!
    var canvasVM: CanvasViewModel!

    override func setUp() {
        super.setUp()
        (viewModel, context) = TestSupport.makeInMemoryViewModel()
        canvasVM = CanvasViewModel()
    }

    override func tearDown() {
        canvasVM = nil
        viewModel = nil
        context = nil
        super.tearDown()
    }

    // MARK: - Helpers

    private func makeNote(title: String = "Selection Note") throws -> Note {
        viewModel.addNote(title: title, content: "")
        let note = try XCTUnwrap(viewModel.selectedNote)
        try context.save()
        return note
    }

    private func makePNGData(width: Int = 120, height: Int = 80) throws -> Data {
        let bitmap = try XCTUnwrap(CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
        ))
        bitmap.setFillColor(NSColor.systemBlue.cgColor)
        bitmap.fill(CGRect(x: 0, y: 0, width: width, height: height))
        let data = NSMutableData()
        let destination = try XCTUnwrap(CGImageDestinationCreateWithData(data, UTType.png.identifier as CFString, 1, nil))
        CGImageDestinationAddImage(destination, try XCTUnwrap(bitmap.makeImage()), nil)
        XCTAssertTrue(CGImageDestinationFinalize(destination))
        return data as Data
    }

    @discardableResult
    private func addStroke(
        to note: Note,
        points: String,
        width: Float = 4.0,
        pageIndex: Int16 = 0,
        createdAt: Date = Date()
    ) -> Stroke {
        let stroke = Stroke(context: context)
        stroke.id = UUID()
        stroke.points = points
        stroke.color = "#112233"
        stroke.width = width
        stroke.createdAt = createdAt
        stroke.pageIndex = pageIndex
        stroke.note = note
        return stroke
    }

    @discardableResult
    private func addShape(
        to note: Note,
        kind: ShapeKind = .rectangle,
        points: String,
        fillColor: String? = nil,
        pageIndex: Int16 = 0,
        createdAt: Date = Date()
    ) -> ShapeObject {
        let shape = ShapeObject(context: context)
        shape.id = UUID()
        shape.kind = kind.rawValue
        shape.points = points
        shape.strokeColor = "#000000"
        shape.strokeWidth = 3.0
        shape.fillColor = fillColor
        shape.createdAt = createdAt
        shape.pageIndex = pageIndex
        shape.note = note
        return shape
    }

    @discardableResult
    private func addImage(
        to note: Note,
        frame: CGRect,
        pageIndex: Int16 = 0,
        createdAt: Date = Date()
    ) throws -> EditorImage {
        let image = EditorImage(context: context)
        image.id = UUID()
        image.createdAt = createdAt
        image.pageIndex = pageIndex
        image.data = try makePNGData()
        image.x = frame.origin.x
        image.y = frame.origin.y
        image.width = frame.width
        image.height = frame.height
        image.note = note
        return image
    }

    private func makeHostedCanvas(pageIndex: Int = 0) -> (canvas: PageDrawingCanvas, window: NSWindow) {
        _ = NSApplication.shared
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 612, height: 792),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        let canvas = PageDrawingCanvas(pageIndex: pageIndex, noteVM: viewModel, canvasVM: canvasVM)
        canvas.frame = NSRect(x: 0, y: 0, width: 612, height: 792)
        window.contentView = canvas
        return (canvas, window)
    }

    private func mouseEvent(
        type: NSEvent.EventType,
        point: CGPoint,
        window: NSWindow,
        modifiers: NSEvent.ModifierFlags = []
    ) throws -> NSEvent {
        try XCTUnwrap(NSEvent.mouseEvent(
            with: type,
            location: point,
            modifierFlags: modifiers,
            timestamp: 0,
            windowNumber: window.windowNumber,
            context: nil,
            eventNumber: 1,
            clickCount: 1,
            pressure: 1
        ))
    }

    private func drag(
        on canvas: PageDrawingCanvas,
        in window: NSWindow,
        from start: CGPoint,
        to end: CGPoint,
        modifiers: NSEvent.ModifierFlags = []
    ) throws {
        canvas.mouseDown(with: try mouseEvent(type: .leftMouseDown, point: start, window: window, modifiers: modifiers))
        canvas.mouseDragged(with: try mouseEvent(type: .leftMouseDragged, point: end, window: window, modifiers: modifiers))
        canvas.mouseUp(with: try mouseEvent(type: .leftMouseUp, point: end, window: window, modifiers: modifiers))
    }

    private func keyEvent(
        keyCode: UInt16,
        characters: String = "",
        modifiers: NSEvent.ModifierFlags = [],
        window: NSWindow
    ) throws -> NSEvent {
        try XCTUnwrap(NSEvent.keyEvent(
            with: .keyDown,
            location: .zero,
            modifierFlags: modifiers,
            timestamp: 0,
            windowNumber: window.windowNumber,
            context: nil,
            characters: characters,
            charactersIgnoringModifiers: characters,
            isARepeat: false,
            keyCode: keyCode
        ))
    }

    // MARK: - Tests

    func testHitTestAndSingleSelectionAcrossStrokeShapeAndImage() throws {
        let note = try makeNote()
        let stroke = addStroke(to: note, points: "50.0,50.0;150.0,50.0")
        let shape = addShape(to: note, kind: .rectangle, points: "200.0,200.0;300.0,280.0", fillColor: "#FF000033")
        let image = try addImage(to: note, frame: CGRect(x: 350, y: 100, width: 120, height: 80))
        try context.save()

        let (canvas, window) = makeHostedCanvas()
        canvasVM.selectTool(.select)

        // Click on Stroke
        canvas.mouseDown(with: try mouseEvent(type: .leftMouseDown, point: CGPoint(x: 100, y: 52), window: window))
        canvas.mouseUp(with: try mouseEvent(type: .leftMouseUp, point: CGPoint(x: 100, y: 52), window: window))
        XCTAssertEqual(canvasVM.selectedObjects, [.stroke(stroke.id)])
        XCTAssertEqual(canvasVM.selectedPageIndexForSelection, 0)

        // Click on ShapeObject
        canvas.mouseDown(with: try mouseEvent(type: .leftMouseDown, point: CGPoint(x: 250, y: 240), window: window))
        canvas.mouseUp(with: try mouseEvent(type: .leftMouseUp, point: CGPoint(x: 250, y: 240), window: window))
        XCTAssertEqual(canvasVM.selectedObjects, [.shape(shape.id)])
        XCTAssertEqual(canvasVM.selectedShapeID, shape.id)

        // Click on EditorImage
        canvas.mouseDown(with: try mouseEvent(type: .leftMouseDown, point: CGPoint(x: 400, y: 140), window: window))
        canvas.mouseUp(with: try mouseEvent(type: .leftMouseUp, point: CGPoint(x: 400, y: 140), window: window))
        XCTAssertEqual(canvasVM.selectedObjects, [.image(image.id)])
        XCTAssertNil(canvasVM.selectedShapeID)
    }

    func testHitTestPicksMostRecentWhenOverlapping() throws {
        let note = try makeNote()
        let t1 = Date(timeIntervalSince1970: 100)
        let t2 = Date(timeIntervalSince1970: 200)
        let olderImage = try addImage(to: note, frame: CGRect(x: 100, y: 100, width: 120, height: 120), createdAt: t1)
        let newerImage = try addImage(to: note, frame: CGRect(x: 120, y: 120, width: 120, height: 120), createdAt: t2)
        try context.save()

        let (canvas, window) = makeHostedCanvas()
        canvasVM.selectTool(.select)

        // Overlap region (150, 150) selects newerImage
        canvas.mouseDown(with: try mouseEvent(type: .leftMouseDown, point: CGPoint(x: 150, y: 150), window: window))
        canvas.mouseUp(with: try mouseEvent(type: .leftMouseUp, point: CGPoint(x: 150, y: 150), window: window))
        XCTAssertEqual(canvasVM.selectedObjects, [.image(newerImage.id)])
        XCTAssertNotEqual(canvasVM.selectedObjects, [.image(olderImage.id)])
    }

    func testShiftClickTogglesAndMarqueeSelectsAndMovesGroupTogether() throws {
        let note = try makeNote()
        let stroke = addStroke(to: note, points: "60.0,60.0;140.0,60.0")
        let shape = addShape(to: note, kind: .rectangle, points: "80.0,100.0;160.0,160.0")
        let image = try addImage(to: note, frame: CGRect(x: 100, y: 200, width: 80, height: 60))
        let outsideStroke = addStroke(to: note, points: "400.0,500.0;460.0,500.0")
        try context.save()
        let initialUpdatedAt = note.updatedAt

        let (canvas, window) = makeHostedCanvas()
        canvasVM.selectTool(.select)

        // Marquee drag covering stroke, shape, and image (excluding outsideStroke)
        try drag(on: canvas, in: window, from: CGPoint(x: 40, y: 40), to: CGPoint(x: 200, y: 280))
        XCTAssertEqual(canvasVM.selectedObjects, [.stroke(stroke.id), .shape(shape.id), .image(image.id)])
        XCTAssertFalse(canvasVM.selectedObjects.contains(.stroke(outsideStroke.id)))

        // Shift+Click removes shape, then Shift+Click adds it back
        canvas.mouseDown(with: try mouseEvent(type: .leftMouseDown, point: CGPoint(x: 80, y: 130), window: window, modifiers: .shift))
        canvas.mouseUp(with: try mouseEvent(type: .leftMouseUp, point: CGPoint(x: 80, y: 130), window: window, modifiers: .shift))
        XCTAssertEqual(canvasVM.selectedObjects, [.stroke(stroke.id), .image(image.id)])

        canvas.mouseDown(with: try mouseEvent(type: .leftMouseDown, point: CGPoint(x: 80, y: 130), window: window, modifiers: .shift))
        canvas.mouseUp(with: try mouseEvent(type: .leftMouseUp, point: CGPoint(x: 80, y: 130), window: window, modifiers: .shift))
        XCTAssertEqual(canvasVM.selectedObjects, [.stroke(stroke.id), .shape(shape.id), .image(image.id)])

        // Drag from inside the group bounding box moves all three items by (+50, +30)
        try drag(on: canvas, in: window, from: CGPoint(x: 120, y: 180), to: CGPoint(x: 170, y: 210))

        let movedStrokePts = deserializeStrokePoints(stroke.points)
        XCTAssertEqual(movedStrokePts[0].x, 110.0, accuracy: 0.2)
        XCTAssertEqual(movedStrokePts[0].y, 90.0, accuracy: 0.2)

        let movedShapePts = deserializeStrokePoints(shape.points)
        XCTAssertEqual(movedShapePts[0].x, 130.0, accuracy: 0.2)
        XCTAssertEqual(movedShapePts[0].y, 130.0, accuracy: 0.2)
        XCTAssertEqual(movedShapePts[1].x, 210.0, accuracy: 0.2)
        XCTAssertEqual(movedShapePts[1].y, 190.0, accuracy: 0.2)

        XCTAssertEqual(image.x, 150.0, accuracy: 0.2)
        XCTAssertEqual(image.y, 230.0, accuracy: 0.2)
        XCTAssertEqual(image.width, 80.0, accuracy: 0.2)
        XCTAssertEqual(image.height, 60.0, accuracy: 0.2)

        // Unselected object stayed in place
        let untouchedPts = deserializeStrokePoints(outsideStroke.points)
        XCTAssertEqual(untouchedPts[0].x, 400.0, accuracy: 0.2)
        XCTAssertEqual(untouchedPts[0].y, 500.0, accuracy: 0.2)

        // Core Data persistence and updatedAt bump
        XCTAssertFalse(context.hasChanges)
        XCTAssertGreaterThan(note.updatedAt, initialUpdatedAt)
    }

    func testPenToolsPreserveSelectionAndMoveWhenDraggingInsideButDrawWhenDraggingOutside() throws {
        let note = try makeNote()
        let image = try addImage(to: note, frame: CGRect(x: 100, y: 100, width: 120, height: 80))
        try context.save()

        let (canvas, window) = makeHostedCanvas()
        canvasVM.selectTool(.select)
        canvas.mouseDown(with: try mouseEvent(type: .leftMouseDown, point: CGPoint(x: 150, y: 140), window: window))
        canvas.mouseUp(with: try mouseEvent(type: .leftMouseUp, point: CGPoint(x: 150, y: 140), window: window))
        XCTAssertEqual(canvasVM.selectedObjects, [.image(image.id)])

        // Switching to each pen tool preserves the active selection
        for penTool in [ToolType.fountainPen, .calligraphy, .pencil, .highlighter] {
            canvasVM.selectTool(penTool)
            XCTAssertEqual(canvasVM.selectedObjects, [.image(image.id)], "Selection must stay active for \(penTool)")
        }

        // Cursor reports openHand when hovering inside active selection with pen
        canvasVM.selectTool(.fountainPen)
        XCTAssertEqual(canvas.selectionCursor(at: CGPoint(x: 150, y: 140)), NSCursor.openHand)
        XCTAssertNil(canvas.selectionCursor(at: CGPoint(x: 400, y: 400)))

        // Drag starting inside active selection moves the image without creating a stroke
        let initialUpdatedAt = note.updatedAt
        canvas.mouseDown(with: try mouseEvent(type: .leftMouseDown, point: CGPoint(x: 150, y: 140), window: window))
        XCTAssertNil(canvasVM.activeStroke)
        XCTAssertEqual(canvas.selectionCursor(at: CGPoint(x: 150, y: 140)), NSCursor.closedHand)
        canvas.mouseDragged(with: try mouseEvent(type: .leftMouseDragged, point: CGPoint(x: 210, y: 190), window: window))
        canvas.mouseUp(with: try mouseEvent(type: .leftMouseUp, point: CGPoint(x: 210, y: 190), window: window))

        XCTAssertEqual(note.strokesArray.count, 0)
        XCTAssertEqual(image.x, 160.0, accuracy: 0.2)
        XCTAssertEqual(image.y, 150.0, accuracy: 0.2)
        XCTAssertEqual(canvasVM.selectedObjects, [.image(image.id)])
        XCTAssertGreaterThan(note.updatedAt, initialUpdatedAt)

        // Drag starting outside active selection clears selection and draws a normal stroke
        try drag(on: canvas, in: window, from: CGPoint(x: 400, y: 400), to: CGPoint(x: 480, y: 420))
        XCTAssertTrue(canvasVM.selectedObjects.isEmpty)
        XCTAssertEqual(note.strokesArray.count, 1)
    }

    func testToolTransitionsAndReadingModeClearSelectionWhenExpected() throws {
        let note = try makeNote()
        let stroke = addStroke(to: note, points: "50.0,50.0;120.0,50.0")
        try context.save()

        canvasVM.selectTool(.select)
        canvasVM.setSelection([.stroke(stroke.id)], pageIndex: 0)

        canvasVM.selectTool(.eraser)
        XCTAssertTrue(canvasVM.selectedObjects.isEmpty)

        canvasVM.selectTool(.select)
        canvasVM.setSelection([.stroke(stroke.id)], pageIndex: 0)
        canvasVM.selectTool(.shape)
        XCTAssertTrue(canvasVM.selectedObjects.isEmpty)

        canvasVM.selectTool(.select)
        canvasVM.setSelection([.stroke(stroke.id)], pageIndex: 0)
        canvasVM.enableReadingMode()
        XCTAssertTrue(canvasVM.selectedObjects.isEmpty)
    }

    func testSingleShapeHandleResizeAndImageAspectPreservingCornerResize() throws {
        let note = try makeNote()
        let shape = addShape(to: note, kind: .line, points: "100.0,100.0;200.0,100.0")
        let image = try addImage(to: note, frame: CGRect(x: 250, y: 200, width: 120, height: 60))
        try context.save()

        let (canvas, window) = makeHostedCanvas()
        canvasVM.selectTool(.select)

        // Select shape and drag second control point handle
        canvas.mouseDown(with: try mouseEvent(type: .leftMouseDown, point: CGPoint(x: 150, y: 100), window: window))
        canvas.mouseUp(with: try mouseEvent(type: .leftMouseUp, point: CGPoint(x: 150, y: 100), window: window))
        XCTAssertEqual(canvasVM.selectedShapeID, shape.id)

        try drag(on: canvas, in: window, from: CGPoint(x: 200, y: 100), to: CGPoint(x: 240, y: 140))
        let resizedShapePts = deserializeStrokePoints(shape.points)
        XCTAssertEqual(resizedShapePts[0].x, 100.0, accuracy: 0.2)
        XCTAssertEqual(resizedShapePts[0].y, 100.0, accuracy: 0.2)
        XCTAssertEqual(resizedShapePts[1].x, 240.0, accuracy: 0.2)
        XCTAssertEqual(resizedShapePts[1].y, 140.0, accuracy: 0.2)

        // Select image and shrink below minimum via topRight corner -> clamped >= 24pt while keeping 2:1 aspect
        canvas.mouseDown(with: try mouseEvent(type: .leftMouseDown, point: CGPoint(x: 300, y: 230), window: window))
        canvas.mouseUp(with: try mouseEvent(type: .leftMouseUp, point: CGPoint(x: 300, y: 230), window: window))
        XCTAssertEqual(canvasVM.selectedObjects, [.image(image.id)])

        try drag(on: canvas, in: window, from: CGPoint(x: 370, y: 260), to: CGPoint(x: 252, y: 202))
        XCTAssertGreaterThanOrEqual(image.width, 24.0)
        XCTAssertGreaterThanOrEqual(image.height, 24.0)
        XCTAssertEqual(image.width / image.height, 2.0, accuracy: 0.01)
    }

    func testKeyboardNudgeEscapeAndDeletePersistence() throws {
        let note = try makeNote()
        let stroke = addStroke(to: note, points: "100.0,100.0;140.0,100.0")
        let image = try addImage(to: note, frame: CGRect(x: 110, y: 120, width: 60, height: 40))
        try context.save()

        let (canvas, window) = makeHostedCanvas()
        canvasVM.selectTool(.select)
        canvasVM.setSelection([.stroke(stroke.id), .image(image.id)], pageIndex: 0)

        // Right arrow -> +1 pt
        canvas.keyDown(with: try keyEvent(keyCode: 124, window: window))
        XCTAssertEqual(deserializeStrokePoints(stroke.points)[0].x, 101.0, accuracy: 0.2)
        XCTAssertEqual(image.x, 111.0, accuracy: 0.2)

        // Shift + Up arrow -> +10 pt
        canvas.keyDown(with: try keyEvent(keyCode: 126, modifiers: .shift, window: window))
        XCTAssertEqual(deserializeStrokePoints(stroke.points)[0].y, 110.0, accuracy: 0.2)
        XCTAssertEqual(image.y, 130.0, accuracy: 0.2)

        // Escape clears selection without deleting
        canvas.keyDown(with: try keyEvent(keyCode: 53, window: window))
        XCTAssertTrue(canvasVM.selectedObjects.isEmpty)
        XCTAssertEqual(note.strokesArray.count, 1)
        XCTAssertEqual((note.editorImages as? Set<EditorImage> ?? []).count, 1)

        // Re-select and press Delete -> removes both from Core Data & bumps updatedAt
        let beforeDelete = note.updatedAt
        canvasVM.setSelection([.stroke(stroke.id), .image(image.id)], pageIndex: 0)
        canvas.keyDown(with: try keyEvent(keyCode: 51, window: window))

        XCTAssertTrue(canvasVM.selectedObjects.isEmpty)
        XCTAssertEqual(note.strokesArray.count, 0)
        XCTAssertEqual((note.editorImages as? Set<EditorImage> ?? []).count, 0)
        XCTAssertFalse(context.hasChanges)
        XCTAssertGreaterThan(note.updatedAt, beforeDelete)
    }

    func testMovedImagePersistsInCoreDataAndReflectsInPDFExport() throws {
        let note = try makeNote()
        let image = try addImage(to: note, frame: CGRect(x: 80, y: 80, width: 100, height: 80))
        try context.save()

        let (canvas, window) = makeHostedCanvas()
        canvasVM.selectTool(.select)
        canvas.mouseDown(with: try mouseEvent(type: .leftMouseDown, point: CGPoint(x: 120, y: 120), window: window))
        canvas.mouseUp(with: try mouseEvent(type: .leftMouseUp, point: CGPoint(x: 120, y: 120), window: window))

        // Switch to pen and move image by (+200, +200)
        canvasVM.selectTool(.fountainPen)
        try drag(on: canvas, in: window, from: CGPoint(x: 120, y: 120), to: CGPoint(x: 320, y: 320))

        // Re-fetch from context to verify persistence
        let request = NSFetchRequest<EditorImage>(entityName: "EditorImage")
        let fetched = try XCTUnwrap(context.fetch(request).first)
        XCTAssertEqual(fetched.id, image.id)
        XCTAssertEqual(fetched.x, 280.0, accuracy: 0.2)
        XCTAssertEqual(fetched.y, 280.0, accuracy: 0.2)

        // Verify exportPDF produces a valid PDF reflecting the moved image
        let exportURL = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).pdf")
        defer { try? FileManager.default.removeItem(at: exportURL) }
        try viewModel.exportPDF(for: note, to: exportURL)
        let exported = try XCTUnwrap(PDFDocument(url: exportURL))
        XCTAssertEqual(exported.pageCount, 1)
    }

    func testRotatedOffsetMediaBoxMoveReflectsPixelsInExportedPDF() throws {
        let data = NSMutableData()
        let consumer = try XCTUnwrap(CGDataConsumer(data: data))
        let pdf = try XCTUnwrap(CGContext(consumer: consumer, mediaBox: nil, nil))
        var box = CGRect(x: 40, y: 70, width: 400, height: 500)
        for _ in 0..<2 {
            pdf.beginPage(mediaBox: &box)
            pdf.setFillColor(NSColor.white.cgColor)
            pdf.fill(box)
            pdf.endPage()
        }
        pdf.closePDF()

        let sourceDoc = try XCTUnwrap(PDFDocument(data: data as Data))
        sourceDoc.page(at: 1)?.rotation = 90
        let rotatedPDFData = try XCTUnwrap(sourceDoc.dataRepresentation())

        let note = try makeNote(title: "Rotated MediaBox Note")
        note.pdfData = rotatedPDFData
        note.pageCount = 2
        let image = try addImage(to: note, frame: CGRect(x: 80, y: 80, width: 100, height: 80), pageIndex: 1)
        try context.save()

        _ = NSApplication.shared
        let doc = try XCTUnwrap(viewModel.getPDFDocument(for: note))
        let page = try XCTUnwrap(doc.page(at: 1))

        let window = NSWindow(
            contentRect: CGRect(x: 0, y: 0, width: 720, height: 600),
            styleMask: [.titled],
            backing: .buffered,
            defer: false
        )
        let pdfView = NSPDFAnnotationView()
        let provider = AnnotatedPDFOverlayProvider(noteVM: viewModel, canvasVM: canvasVM)
        pdfView.displayMode = .singlePageContinuous
        pdfView.displayBox = .mediaBox
        pdfView.minScaleFactor = 0.25
        pdfView.maxScaleFactor = 4.0
        pdfView.pageOverlayViewProvider = provider
        pdfView.overlayProvider = provider
        pdfView.canvasVM = canvasVM
        window.contentView = pdfView
        pdfView.document = doc
        pdfView.go(to: page)
        pdfView.scaleFactor = 1.0
        pdfView.layoutDocumentView()
        window.displayIfNeeded()

        let overlay = try XCTUnwrap(provider.pdfView(pdfView, overlayViewFor: page) as? PageDrawingCanvas)
        XCTAssertNotNil(overlay.superview)
        XCTAssertNotNil(overlay.window)

        func windowPoint(forPagePoint pagePoint: CGPoint) -> CGPoint {
            let local = overlay.convert(pdfView.convert(pagePoint, from: page), from: pdfView)
            return overlay.convert(local, to: nil)
        }

        // Select the image on page 1 at its old center (130, 120)
        canvasVM.selectTool(.select)
        overlay.mouseDown(with: try mouseEvent(type: .leftMouseDown, point: windowPoint(forPagePoint: CGPoint(x: 130, y: 120)), window: window))
        overlay.mouseUp(with: try mouseEvent(type: .leftMouseUp, point: windowPoint(forPagePoint: CGPoint(x: 130, y: 120)), window: window))
        XCTAssertEqual(canvasVM.selectedObjects, [.image(image.id)])
        XCTAssertEqual(canvasVM.selectedPageIndexForSelection, 1)

        // Move image by (+200, +200) in PDF page coordinates using the Pen tool
        canvasVM.selectTool(.fountainPen)
        let startWin = windowPoint(forPagePoint: CGPoint(x: 130, y: 120))
        let endWin = windowPoint(forPagePoint: CGPoint(x: 330, y: 320))
        overlay.mouseDown(with: try mouseEvent(type: .leftMouseDown, point: startWin, window: window))
        overlay.mouseDragged(with: try mouseEvent(type: .leftMouseDragged, point: endWin, window: window))
        overlay.mouseUp(with: try mouseEvent(type: .leftMouseUp, point: endWin, window: window))

        XCTAssertEqual(image.x, 280.0, accuracy: 1.0)
        XCTAssertEqual(image.y, 280.0, accuracy: 1.0)

        // Export PDF and sample pixels at old center (130, 120) vs new center (330, 320)
        let exportURL = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).pdf")
        defer { try? FileManager.default.removeItem(at: exportURL) }
        try viewModel.exportPDF(for: note, to: exportURL, options: PDFExportOptions(includeGrid: false))

        let exportedDoc = try XCTUnwrap(PDFDocument(url: exportURL))
        let exportedPage = try XCTUnwrap(exportedDoc.page(at: 1))
        let rendered = exportedPage.thumbnail(of: CGSize(width: 500, height: 400), for: .mediaBox)
        let cgImage = try XCTUnwrap(rendered.cgImage(forProposedRect: nil, context: nil, hints: nil))
        let bitmap = NSBitmapImageRep(cgImage: cgImage)
        let transform = page.transform(for: .mediaBox)

        func samplePagePixel(_ pagePt: CGPoint) throws -> NSColor {
            let rotatedPt = pagePt.applying(transform)
            let px = Int(rotatedPt.x / 500.0 * CGFloat(bitmap.pixelsWide))
            let py = Int((1.0 - rotatedPt.y / 400.0) * CGFloat(bitmap.pixelsHigh))
            return try XCTUnwrap(bitmap.colorAt(x: px, y: py)?.usingColorSpace(.deviceRGB))
        }

        let oldColor = try samplePagePixel(CGPoint(x: 130, y: 120))
        let newColor = try samplePagePixel(CGPoint(x: 330, y: 320))
        // Old position should now be white paper; new position should be systemBlue image
        XCTAssertGreaterThan(oldColor.redComponent, 0.9)
        XCTAssertGreaterThan(oldColor.greenComponent, 0.9)
        XCTAssertGreaterThan(newColor.blueComponent - newColor.redComponent, 0.35)
    }

    func testKeyDownRejectsCommandOptionControlModifiersAndNSTextFirstResponder() throws {
        let note = try makeNote()
        let stroke = addStroke(to: note, points: "100.0,100.0;150.0,100.0")
        try context.save()

        let (canvas, window) = makeHostedCanvas()
        canvasVM.selectTool(.select)
        canvasVM.setSelection([.stroke(stroke.id)], pageIndex: 0)

        for mod in [NSEvent.ModifierFlags.command, .option, .control] {
            // Arrow, Delete, Escape with modifier must all be ignored
            canvas.keyDown(with: try keyEvent(keyCode: 124, modifiers: mod, window: window))
            canvas.keyDown(with: try keyEvent(keyCode: 51, modifiers: mod, window: window))
            canvas.keyDown(with: try keyEvent(keyCode: 53, modifiers: mod, window: window))
            XCTAssertEqual(canvasVM.selectedObjects, [.stroke(stroke.id)])
            XCTAssertEqual(note.strokesArray.count, 1)
            XCTAssertEqual(deserializeStrokePoints(stroke.points)[0].x, 100.0, accuracy: 0.1)
        }

        // When an NSTextField is first responder, selection keyDown must also be ignored
        let textField = NSTextField(string: "Título")
        textField.frame = NSRect(x: 0, y: 0, width: 120, height: 24)
        window.contentView?.addSubview(textField)
        XCTAssertTrue(window.makeFirstResponder(textField))
        XCTAssertTrue(window.firstResponder is NSText)

        canvas.keyDown(with: try keyEvent(keyCode: 51, window: window))
        XCTAssertEqual(canvasVM.selectedObjects, [.stroke(stroke.id)])
        XCTAssertEqual(note.strokesArray.count, 1)
    }

    func testDrawingWithPenOnAnotherPageClearsPreviousSelection() throws {
        let note = try makeNote()
        note.pdfData = viewModel.createBlankPDF(pageCount: 2)
        note.pageCount = 2
        let imageOnPage0 = try addImage(to: note, frame: CGRect(x: 100, y: 100, width: 120, height: 80), pageIndex: 0)
        try context.save()

        let (_, window0) = makeHostedCanvas(pageIndex: 0)
        let (canvas1, window1) = makeHostedCanvas(pageIndex: 1)

        // Select image on page 0
        canvasVM.selectTool(.select)
        canvasVM.setSelection([.image(imageOnPage0.id)], pageIndex: 0)

        // Switch to pen and draw on page 1 at the exact same (150, 140) coordinates
        canvasVM.selectTool(.fountainPen)
        try drag(on: canvas1, in: window1, from: CGPoint(x: 150, y: 140), to: CGPoint(x: 200, y: 180))

        _ = window0
        XCTAssertTrue(canvasVM.selectedObjects.isEmpty)
        XCTAssertNil(canvasVM.selectedPageIndexForSelection)
        XCTAssertEqual(imageOnPage0.x, 100.0, accuracy: 0.1)
        XCTAssertEqual(imageOnPage0.y, 100.0, accuracy: 0.1)
        XCTAssertEqual(note.strokesArray.filter { $0.pageIndex == 1 }.count, 1)
    }

    func testEscapeDuringMoveDragRestoresCoordinatesWithoutDirtyingContext() throws {
        let note = try makeNote()
        let stroke = addStroke(to: note, points: "60.0,60.0;140.0,60.0")
        let shape = addShape(to: note, kind: .rectangle, points: "80.0,100.0;160.0,160.0")
        let image = try addImage(to: note, frame: CGRect(x: 100, y: 200, width: 80, height: 60))
        try context.save()
        XCTAssertFalse(context.hasChanges)

        let (canvas, window) = makeHostedCanvas()
        canvasVM.selectTool(.select)
        canvasVM.setSelection([.stroke(stroke.id), .shape(shape.id), .image(image.id)], pageIndex: 0)

        // Start drag without mouseUp
        canvas.mouseDown(with: try mouseEvent(type: .leftMouseDown, point: CGPoint(x: 120, y: 180), window: window))
        canvas.mouseDragged(with: try mouseEvent(type: .leftMouseDragged, point: CGPoint(x: 200, y: 260), window: window))

        // Mid-drag coordinates moved
        XCTAssertEqual(image.x, 180.0, accuracy: 0.2)
        XCTAssertTrue(context.hasChanges)

        // Cancel drag with Escape
        canvas.keyDown(with: try keyEvent(keyCode: 53, window: window))

        XCTAssertTrue(canvasVM.selectedObjects.isEmpty)
        XCTAssertFalse(canvas.selectionController.isDragging)
        XCTAssertEqual(deserializeStrokePoints(stroke.points)[0].x, 60.0, accuracy: 0.1)
        XCTAssertEqual(deserializeStrokePoints(shape.points)[0].x, 80.0, accuracy: 0.1)
        XCTAssertEqual(image.x, 100.0, accuracy: 0.1)
        XCTAssertEqual(image.y, 200.0, accuracy: 0.1)
        XCTAssertTrue(context.updatedObjects.isEmpty)
        XCTAssertFalse(context.hasChanges)
    }

    func testCursorReturnsToArrowWhenLeavingSelectionOrCancelling() throws {
        let note = try makeNote()
        let image = try addImage(to: note, frame: CGRect(x: 100, y: 100, width: 120, height: 80))
        try context.save()

        let (canvas, window) = makeHostedCanvas()
        window.acceptsMouseMovedEvents = true
        canvasVM.selectTool(.select)
        canvasVM.setSelection([.image(image.id)], pageIndex: 0)

        // Moving inside selection sets openHand
        canvas.mouseMoved(with: try mouseEvent(type: .mouseMoved, point: CGPoint(x: 150, y: 140), window: window))
        XCTAssertEqual(NSCursor.current, NSCursor.openHand)

        // Moving outside selection in .select restores arrow
        canvas.mouseMoved(with: try mouseEvent(type: .mouseMoved, point: CGPoint(x: 400, y: 400), window: window))
        XCTAssertEqual(NSCursor.current, NSCursor.arrow)

        // Cancelling selection via Escape while inside bounds restores arrow
        canvas.mouseMoved(with: try mouseEvent(type: .mouseMoved, point: CGPoint(x: 150, y: 140), window: window))
        XCTAssertEqual(NSCursor.current, NSCursor.openHand)
        canvas.keyDown(with: try keyEvent(keyCode: 53, window: window))
        canvas.mouseMoved(with: try mouseEvent(type: .mouseMoved, point: CGPoint(x: 150, y: 140), window: window))
        XCTAssertEqual(NSCursor.current, NSCursor.arrow)
    }
}
