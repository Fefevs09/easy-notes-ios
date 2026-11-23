import AppKit
import CoreData
import PDFKit
import SwiftUI
import XCTest

class ShapePickerTests: XCTestCase {
    var inMemoryContext: NSManagedObjectContext!
    var viewModel: NoteViewModel!

    override func setUp() {
        super.setUp()
        (viewModel, inMemoryContext) = TestSupport.makeInMemoryViewModel()
    }

    override func tearDown() {
        viewModel = nil
        inMemoryContext = nil
        super.tearDown()
    }

    func testSelectShapeActivatesShapeToolForAllDrawableKindsAndPreservesState() {
        let canvasVM = CanvasViewModel()

        // Configure distinct settings on .shape and .fountainPen
        canvasVM.selectTool(.shape)
        canvasVM.strokeWidth = 7.0
        let customTeal = PenColorComponents.fromHex("#2B7A8C")!.swiftUIColor
        canvasVM.applyStrokeColor(customTeal)
        canvasVM.shapeFillEnabled = true

        canvasVM.selectTool(.fountainPen)
        canvasVM.strokeWidth = 4.0
        canvasVM.applyStrokeColor(PixelTheme.inkViolet)

        for kind in ShapeKind.drawable {
            canvasVM.selectTool(.select)
            canvasVM.selectedShapeID = UUID()
            canvasVM.enableReadingMode()
            XCTAssertFalse(canvasVM.isDrawingMode)

            canvasVM.selectShape(kind)

            XCTAssertEqual(canvasVM.activeShapeKind, kind)
            XCTAssertEqual(canvasVM.activeTool, .shape)
            XCTAssertTrue(canvasVM.isDrawingMode)
            XCTAssertNil(canvasVM.selectedShapeID)
            XCTAssertTrue(canvasVM.shapeFillEnabled)
            XCTAssertEqual(canvasVM.strokeWidth, 7.0, accuracy: 0.001)
            XCTAssertEqual(PenColorComponents.from(canvasVM.strokeColor).hex6, "#2B7A8C")
        }

        // Also verify shapeFillEnabled = false is preserved when leaving reading mode via selectShape
        canvasVM.shapeFillEnabled = false
        canvasVM.enableReadingMode()
        XCTAssertFalse(canvasVM.isDrawingMode)

        canvasVM.selectShape(.ellipse)
        XCTAssertEqual(canvasVM.activeShapeKind, .ellipse)
        XCTAssertEqual(canvasVM.activeTool, .shape)
        XCTAssertTrue(canvasVM.isDrawingMode)
        XCTAssertFalse(canvasVM.shapeFillEnabled)

        // Switching back to pen retains pen settings
        canvasVM.selectTool(.fountainPen)
        XCTAssertEqual(canvasVM.strokeWidth, 4.0, accuracy: 0.001)
        XCTAssertEqual(PenColorComponents.from(canvasVM.strokeColor).hex6, "#6F52E0")
    }

    func testShapePickerNavigationCyclicWrapAroundAndTriggerPresentation() {
        XCTAssertEqual(ShapeKind.drawable, [.line, .rectangle, .ellipse, .arrow])

        // Forward wrap-around
        XCTAssertEqual(ShapePickerNavigation.steppedShape(from: .line, direction: .next), .rectangle)
        XCTAssertEqual(ShapePickerNavigation.steppedShape(from: .rectangle, direction: .next), .ellipse)
        XCTAssertEqual(ShapePickerNavigation.steppedShape(from: .ellipse, direction: .next), .arrow)
        XCTAssertEqual(ShapePickerNavigation.steppedShape(from: .arrow, direction: .next), .line)

        // Backward wrap-around
        XCTAssertEqual(ShapePickerNavigation.steppedShape(from: .line, direction: .previous), .arrow)
        XCTAssertEqual(ShapePickerNavigation.steppedShape(from: .arrow, direction: .previous), .ellipse)
        XCTAssertEqual(ShapePickerNavigation.steppedShape(from: .ellipse, direction: .previous), .rectangle)
        XCTAssertEqual(ShapePickerNavigation.steppedShape(from: .rectangle, direction: .previous), .line)

        // Nil and non-drawable fallbacks
        XCTAssertEqual(ShapePickerNavigation.steppedShape(from: nil, direction: .next), .line)
        XCTAssertEqual(ShapePickerNavigation.steppedShape(from: nil, direction: .previous), .arrow)
        XCTAssertEqual(ShapePickerNavigation.steppedShape(from: .polygon, direction: .next), .line)
        XCTAssertEqual(ShapePickerNavigation.steppedShape(from: .polygon, direction: .previous), .arrow)

        // Empty options
        XCTAssertNil(ShapePickerNavigation.steppedShape(from: .line, direction: .next, in: []))
        XCTAssertNil(ShapePickerNavigation.initialFocusedShape(activeShape: .line, in: []))

        // Initial focused shape
        for kind in ShapeKind.drawable {
            XCTAssertEqual(ShapePickerNavigation.initialFocusedShape(activeShape: kind), kind)
        }
        XCTAssertEqual(ShapePickerNavigation.initialFocusedShape(activeShape: .polygon), .line)

        // Trigger icon & accessibility value
        XCTAssertEqual(
            ShapePickerNavigation.triggerIconName(isShapeToolActive: false, activeShape: .rectangle),
            "square.on.circle"
        )
        XCTAssertEqual(
            ShapePickerNavigation.triggerAccessibilityValue(isShapeToolActive: false, activeShape: .rectangle),
            "Inativa"
        )
        for kind in ShapeKind.drawable {
            XCTAssertEqual(
                ShapePickerNavigation.triggerIconName(isShapeToolActive: true, activeShape: kind),
                kind.systemImage
            )
            XCTAssertEqual(
                ShapePickerNavigation.triggerAccessibilityValue(isShapeToolActive: true, activeShape: kind),
                kind.displayName
            )
        }
    }

    func testDrawingAllDrawableShapesAcrossPagesPersistsOnReopenAndRendersInExportedPDF() throws {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("EasyNotesShapePickerTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let storeURL = tempDir.appendingPathComponent("ShapesStore.sqlite")
        let exportedPDFURL = tempDir.appendingPathComponent("ExportedShapes.pdf")

        // Container #1: create note with 2 pages and draw all drawable shapes via PageDrawingCanvas
        let container1 = try TestSupport.makeSQLiteContainer(at: storeURL)
        let context1 = container1.viewContext
        let noteVM1 = NoteViewModel(context: context1)

        noteVM1.addNote(title: "Formas FEAT-01", content: "")
        guard let note = noteVM1.notes.first else {
            XCTFail("Expected created note")
            return
        }
        let noteID = note.id
        noteVM1.selectedNote = note
        noteVM1.addBlankPage()
        XCTAssertEqual(note.pageCount, 2)

        let canvasVM = CanvasViewModel()
        canvasVM.selectTool(.shape)
        canvasVM.strokeWidth = 14.0
        canvasVM.applyStrokeColor(PenColorComponents.fromHex("#FF0000")!.swiftUIColor)

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 612, height: 792),
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )
        let containerView = NSView(frame: NSRect(x: 0, y: 0, width: 612, height: 792))
        window.contentView = containerView

        let page0Canvas = PageDrawingCanvas(pageIndex: 0, noteVM: noteVM1, canvasVM: canvasVM)
        page0Canvas.frame = containerView.bounds
        let page1Canvas = PageDrawingCanvas(pageIndex: 1, noteVM: noteVM1, canvasVM: canvasVM)
        page1Canvas.frame = containerView.bounds
        containerView.addSubview(page0Canvas)
        containerView.addSubview(page1Canvas)

        func drawShape(on canvas: PageDrawingCanvas, kind: ShapeKind, fill: Bool, from start: NSPoint, to end: NSPoint) {
            canvasVM.shapeFillEnabled = fill
            canvasVM.selectShape(kind)

            let down = NSEvent.mouseEvent(
                with: .leftMouseDown,
                location: start,
                modifierFlags: [],
                timestamp: 1.0,
                windowNumber: window.windowNumber,
                context: nil,
                eventNumber: 1,
                clickCount: 1,
                pressure: 1.0
            )!
            let drag = NSEvent.mouseEvent(
                with: .leftMouseDragged,
                location: end,
                modifierFlags: [],
                timestamp: 1.1,
                windowNumber: window.windowNumber,
                context: nil,
                eventNumber: 2,
                clickCount: 1,
                pressure: 1.0
            )!
            let up = NSEvent.mouseEvent(
                with: .leftMouseUp,
                location: end,
                modifierFlags: [],
                timestamp: 1.2,
                windowNumber: window.windowNumber,
                context: nil,
                eventNumber: 3,
                clickCount: 1,
                pressure: 0.0
            )!

            canvas.mouseDown(with: down)
            canvas.mouseDragged(with: drag)
            canvas.mouseUp(with: up)
        }

        drawShape(on: page0Canvas, kind: .line, fill: false, from: NSPoint(x: 100, y: 620), to: NSPoint(x: 300, y: 620))
        drawShape(on: page0Canvas, kind: .rectangle, fill: true, from: NSPoint(x: 100, y: 320), to: NSPoint(x: 300, y: 480))
        drawShape(on: page1Canvas, kind: .ellipse, fill: false, from: NSPoint(x: 100, y: 520), to: NSPoint(x: 300, y: 680))
        drawShape(on: page1Canvas, kind: .arrow, fill: false, from: NSPoint(x: 100, y: 240), to: NSPoint(x: 320, y: 240))

        if context1.hasChanges {
            try context1.save()
        }
        for store in container1.persistentStoreCoordinator.persistentStores {
            try container1.persistentStoreCoordinator.remove(store)
        }

        // Container #2: fresh NSManagedObjectContext reopening the persisted SQLite store
        let container2 = try TestSupport.makeSQLiteContainer(at: storeURL)
        defer {
            for store in container2.persistentStoreCoordinator.persistentStores {
                try? container2.persistentStoreCoordinator.remove(store)
            }
        }
        let context2 = container2.viewContext
        let reopenedVM = NoteViewModel(context: context2)

        let fetchRequest = NSFetchRequest<Note>(entityName: "Note")
        fetchRequest.predicate = NSPredicate(format: "id == %@", noteID as CVarArg)
        guard let reopenedNote = try context2.fetch(fetchRequest).first else {
            XCTFail("Expected persisted note after reopening context")
            return
        }

        XCTAssertEqual(reopenedNote.pageCount, 2)
        let persistedShapes = reopenedNote.shapes as? Set<ShapeObject> ?? []
        XCTAssertEqual(persistedShapes.count, ShapeKind.drawable.count)

        let shapeByKind = Dictionary(uniqueKeysWithValues: persistedShapes.map { ($0.kind, $0) })
        XCTAssertEqual(shapeByKind[ShapeKind.line.rawValue]?.pageIndex, 0)
        XCTAssertEqual(shapeByKind[ShapeKind.rectangle.rawValue]?.pageIndex, 0)
        XCTAssertEqual(shapeByKind[ShapeKind.ellipse.rawValue]?.pageIndex, 1)
        XCTAssertEqual(shapeByKind[ShapeKind.arrow.rawValue]?.pageIndex, 1)
        XCTAssertNil(shapeByKind[ShapeKind.line.rawValue]?.fillColor)
        XCTAssertNotNil(shapeByKind[ShapeKind.rectangle.rawValue]?.fillColor)

        // Export PDF and verify pixel rendering across both pages
        try reopenedVM.exportPDF(for: reopenedNote, to: exportedPDFURL)
        guard let exportedDoc = PDFDocument(url: exportedPDFURL) else {
            XCTFail("Failed to load exported PDF")
            return
        }
        XCTAssertEqual(exportedDoc.pageCount, 2)

        guard let page0 = exportedDoc.page(at: 0),
              let page1 = exportedDoc.page(at: 1) else {
            XCTFail("Missing exported PDF pages")
            return
        }

        // Page 0: line + rectangle rendered; page 1's arrow spot remains white
        let page0Line = try XCTUnwrap(averageColor(on: page0, at: CGPoint(x: 200, y: 620)))
        XCTAssertGreaterThan(page0Line.r, 0.6)
        XCTAssertLessThan(page0Line.g, 0.4)
        XCTAssertLessThan(page0Line.b, 0.4)

        let page0RectEdge = try XCTUnwrap(averageColor(on: page0, at: CGPoint(x: 200, y: 480)))
        XCTAssertGreaterThan(page0RectEdge.r, 0.6)
        XCTAssertLessThan(page0RectEdge.g, 0.4)
        XCTAssertLessThan(page0RectEdge.b, 0.4)

        let page0ArrowSpot = try XCTUnwrap(averageColor(on: page0, at: CGPoint(x: 210, y: 240)))
        XCTAssertGreaterThan(page0ArrowSpot.r, 0.9)
        XCTAssertGreaterThan(page0ArrowSpot.g, 0.9)
        XCTAssertGreaterThan(page0ArrowSpot.b, 0.9)

        // Page 1: ellipse + arrow rendered; page 0's line spot remains white
        let page1EllipseTop = try XCTUnwrap(averageColor(on: page1, at: CGPoint(x: 200, y: 680)))
        XCTAssertGreaterThan(page1EllipseTop.r, 0.6)
        XCTAssertLessThan(page1EllipseTop.g, 0.4)
        XCTAssertLessThan(page1EllipseTop.b, 0.4)

        let page1ArrowShaft = try XCTUnwrap(averageColor(on: page1, at: CGPoint(x: 210, y: 240)))
        XCTAssertGreaterThan(page1ArrowShaft.r, 0.6)
        XCTAssertLessThan(page1ArrowShaft.g, 0.4)
        XCTAssertLessThan(page1ArrowShaft.b, 0.4)

        let page1LineSpot = try XCTUnwrap(averageColor(on: page1, at: CGPoint(x: 200, y: 620)))
        XCTAssertGreaterThan(page1LineSpot.r, 0.9)
        XCTAssertGreaterThan(page1LineSpot.g, 0.9)
        XCTAssertGreaterThan(page1LineSpot.b, 0.9)
    }

    private func averageColor(
        on page: PDFPage,
        at point: CGPoint,
        sampleRadius: Int = 4,
        scale: CGFloat = 3
    ) -> (r: CGFloat, g: CGFloat, b: CGFloat)? {
        let mediaBox = page.bounds(for: .mediaBox)
        let imageSize = CGSize(width: mediaBox.width * scale, height: mediaBox.height * scale)
        let image = page.thumbnail(of: imageSize, for: .mediaBox)

        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return nil
        }
        let rep = NSBitmapImageRep(cgImage: cgImage)
        let imageWidth = rep.pixelsWide
        let imageHeight = rep.pixelsHigh

        let normalizedX = (point.x - mediaBox.minX) / mediaBox.width
        let normalizedY = (point.y - mediaBox.minY) / mediaBox.height

        let pixelX = Int(normalizedX * CGFloat(imageWidth))
        let pixelY = Int((1 - normalizedY) * CGFloat(imageHeight))

        var totalR: CGFloat = 0, totalG: CGFloat = 0, totalB: CGFloat = 0
        var count = 0
        for dx in -sampleRadius...sampleRadius {
            for dy in -sampleRadius...sampleRadius {
                let x = pixelX + dx
                let y = pixelY + dy
                guard x >= 0, x < imageWidth, y >= 0, y < imageHeight,
                      let rawColor = rep.colorAt(x: x, y: y) else { continue }
                let color = rawColor.usingColorSpace(.sRGB) ?? rawColor
                totalR += color.redComponent
                totalG += color.greenComponent
                totalB += color.blueComponent
                count += 1
            }
        }
        guard count > 0 else { return nil }
        return (totalR / CGFloat(count), totalG / CGFloat(count), totalB / CGFloat(count))
    }
}
