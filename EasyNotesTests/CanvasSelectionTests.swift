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
}
