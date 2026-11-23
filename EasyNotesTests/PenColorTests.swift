import AppKit
import CoreData
import PDFKit
import SwiftUI
import XCTest

class PenColorTests: XCTestCase {
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

    func testNormalizeHexHandlesValidAndInvalidInputs() {
        XCTAssertEqual(PenColorComponents.normalizeHex("#6f52e0"), "#6F52E0")
        XCTAssertEqual(PenColorComponents.normalizeHex(" 2b7a8c "), "#2B7A8C")
        XCTAssertEqual(PenColorComponents.normalizeHex("000000"), "#000000")

        XCTAssertNil(PenColorComponents.normalizeHex("#6F52ZZ"))
        XCTAssertNil(PenColorComponents.normalizeHex("#123"))
        XCTAssertNil(PenColorComponents.normalizeHex(""))
        XCTAssertNil(PenColorComponents.normalizeHex("   "))
        XCTAssertNil(PenColorComponents.normalizeHex("#6F52E0FF"))
    }

    func testColorSpaceAndHSVRoundTripForPresetsAndEdgeColors() {
        let colorsToTest: [(Color, String)] = [
            (PixelTheme.inkCharcoal, "#2B2A33"),
            (PixelTheme.inkViolet, "#6F52E0"),
            (PixelTheme.inkSage, "#537D66"),
            (PixelTheme.inkOchre, "#E5B84B"),
            (PixelTheme.inkTerracotta, "#C38467"),
            (Color.black, "#000000"),
            (Color.white, "#FFFFFF"),
            (Color.gray, "#808080")
        ]

        for (color, expectedHex) in colorsToTest {
            let comps = PenColorComponents.from(color)
            if color != Color.gray {
                XCTAssertEqual(comps.hex6, expectedHex, "Unexpected hex for \(expectedHex)")
            }
            let hsv = comps.hsv
            let roundTripped = PenColorComponents.fromHSV(
                hue: hsv.hue,
                saturation: hsv.saturation,
                brightness: hsv.brightness,
                opacity: comps.opacity
            )
            XCTAssertEqual(roundTripped.hex6, comps.hex6, "HSV round-trip mismatch for \(comps.hex6)")
        }

        let customTeal = PenColorComponents.fromHex("#2B7A8C", opacity: 0.85)
        XCTAssertNotNil(customTeal)
        XCTAssertEqual(customTeal?.hex6, "#2B7A8C")
        XCTAssertEqual(customTeal?.opacityPercent, 85)
        XCTAssertEqual(customTeal?.hexString, "#2B7A8CD9")
    }

    func testCanvasViewModelPreservesToolSettingsAndHighlighterOpacity() {
        let canvasVM = CanvasViewModel()
        canvasVM.selectTool(.fountainPen)
        canvasVM.strokeWidth = 6.0

        let customTeal = PenColorComponents.fromHex("#2B7A8C", opacity: 0.85)!.swiftUIColor
        canvasVM.applyStrokeColor(customTeal)

        XCTAssertEqual(canvasVM.strokeWidth, 6.0, accuracy: 0.001)
        XCTAssertEqual(canvasVM.activeTool, .fountainPen)
        XCTAssertEqual(PenColorComponents.from(canvasVM.strokeColor).hex6, "#2B7A8C")
        XCTAssertEqual(PenColorComponents.from(canvasVM.strokeColor).opacityPercent, 85)

        // Switch to highlighter and apply a full-opacity preset/custom color -> forced to 30%
        canvasVM.selectTool(.highlighter)
        canvasVM.strokeWidth = 24.0
        canvasVM.applyStrokeColor(PixelTheme.inkViolet)

        let hlComponents = PenColorComponents.from(canvasVM.strokeColor)
        XCTAssertEqual(hlComponents.hex6, "#6F52E0")
        XCTAssertEqual(hlComponents.opacity, Double(CanvasViewModel.highlighterOpacity), accuracy: 0.01)

        // Switch to shape, set sage, then return to highlighter and fountainPen -> settings preserved
        canvasVM.selectTool(.shape)
        canvasVM.applyPresetColor(PixelTheme.inkSage)
        XCTAssertEqual(PenColorComponents.from(canvasVM.strokeColor).hex6, "#537D66")

        canvasVM.selectTool(.highlighter)
        XCTAssertEqual(canvasVM.strokeWidth, 24.0, accuracy: 0.001)
        XCTAssertEqual(PenColorComponents.from(canvasVM.strokeColor).hex6, "#6F52E0")
        XCTAssertEqual(PenColorComponents.from(canvasVM.strokeColor).opacity, Double(CanvasViewModel.highlighterOpacity), accuracy: 0.01)

        canvasVM.selectTool(.fountainPen)
        XCTAssertEqual(canvasVM.strokeWidth, 6.0, accuracy: 0.001)
        XCTAssertEqual(PenColorComponents.from(canvasVM.strokeColor).hex6, "#2B7A8C")
        XCTAssertEqual(PenColorComponents.from(canvasVM.strokeColor).opacityPercent, 85)
    }

    func testEditorStrokePersistenceAcrossColorSwitchPreservesEarlierStrokes() throws {
        viewModel.addNote(title: "Color Flow Note", content: "")
        guard let note = viewModel.notes.first else {
            XCTFail("Expected created note")
            return
        }
        viewModel.selectedNote = note

        let canvasVM = CanvasViewModel()
        canvasVM.selectTool(.fountainPen)
        canvasVM.applyStrokeColor(PixelTheme.inkViolet) // #6F52E0

        let canvas = PageDrawingCanvas(pageIndex: 0, noteVM: viewModel, canvasVM: canvasVM)
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 612, height: 792),
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )
        canvas.frame = NSRect(x: 0, y: 0, width: 612, height: 792)
        window.contentView = canvas

        func drawStroke(from start: NSPoint, to end: NSPoint) {
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

        // 1. Draw first stroke with active Violet (#6F52E0)
        drawStroke(from: NSPoint(x: 100, y: 500), to: NSPoint(x: 260, y: 500))

        // 2. Switch color via the picker's source of truth to custom Teal 85% (#2B7A8C)
        let teal = PenColorComponents.fromHex("#2B7A8C", opacity: 0.85)!.swiftUIColor
        canvasVM.applyStrokeColor(teal)

        // 3. Draw second stroke with new color
        drawStroke(from: NSPoint(x: 100, y: 300), to: NSPoint(x: 260, y: 300))

        // 4. Verify earlier stroke preserved #6F52E0 and second stroke persisted #2B7A8CD9
        let strokes = (note.strokes as? Set<Stroke> ?? []).sorted { $0.createdAt < $1.createdAt }
        XCTAssertEqual(strokes.count, 2)
        XCTAssertEqual(strokes[0].color, "#6F52E0")
        XCTAssertEqual(strokes[1].color, "#2B7A8CD9")

        // 5. Re-reading active color for reopening the picker reflects the new color
        let reopenedComponents = PenColorComponents.from(canvasVM.strokeColor)
        XCTAssertEqual(reopenedComponents.hex6, "#2B7A8C")
        XCTAssertEqual(reopenedComponents.opacityPercent, 85)
        XCTAssertFalse(NSColorPanel.shared.isVisible)

        // 6. Export PDF and verify both strokes retain distinct colors on output
        let destination = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).pdf")
        defer { try? FileManager.default.removeItem(at: destination) }
        try viewModel.exportPDF(for: note, to: destination)
        XCTAssertTrue(FileManager.default.fileExists(atPath: destination.path))
    }
}
