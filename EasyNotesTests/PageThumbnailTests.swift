import AppKit
import CoreData
import PDFKit
import XCTest

final class PageThumbnailTests: XCTestCase {
    func testGridOriginHasSameInkAsAdjacentLines() throws {
        let (model, _) = TestSupport.makeInMemoryViewModel()
        model.addNote(title: "Grade", paper: .grid)
        let note = try XCTUnwrap(model.selectedNote)
        XCTAssertEqual(note.gridInk.hexString, "#000000")
        let bounds = CGRect(x: 0, y: 0, width: 48, height: 48)
        let bitmap = try XCTUnwrap(CGContext(data: nil, width: 192, height: 192,
                                             bitsPerComponent: 8, bytesPerRow: 0,
                                             space: CGColorSpaceCreateDeviceRGB(),
                                             bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        bitmap.scaleBy(x: 4, y: 4)
        bitmap.setFillColor(NSColor.white.cgColor)
        bitmap.fill(bounds)
        // The new-note preview calls this renderer without a color override.
        renderGrid(style: .grid, spacing: 12, origin: CGPoint(x: 24, y: 24), in: bounds, into: bitmap)
        let pixels = NSBitmapImageRep(cgImage: try XCTUnwrap(bitmap.makeImage()))
        let originX = try XCTUnwrap(pixels.colorAt(x: 96, y: 30)?.usingColorSpace(.deviceRGB))
        XCTAssertLessThan(originX.redComponent, 1)
        XCTAssertGreaterThan(originX.redComponent, 0.75)
        XCTAssertEqual(originX.redComponent, originX.blueComponent, accuracy: 0.01)
        XCTAssertEqual(pixels.colorAt(x: 96, y: 30), pixels.colorAt(x: 48, y: 30))
        XCTAssertEqual(pixels.colorAt(x: 30, y: 96), pixels.colorAt(x: 30, y: 48))
    }

    func testCustomGridInkReachesThumbnailsAndExport() throws {
        let (model, _) = TestSupport.makeInMemoryViewModel()
        model.addNote(title: "Grade", paper: .grid)
        let note = try XCTUnwrap(model.selectedNote)
        let page = try XCTUnwrap(model.getPDFDocument(for: note)?.page(at: 0))
        let cache = NoteCoverCache()
        _ = NoteThumbnailView.pdfFallbackImage(for: note, cache: cache)
        model.setGridColor(.red, for: note)
        let sidebar = PageThumbnail.renderThumbnail(for: page, note: note, pageIndex: 0)
        let library = try XCTUnwrap(NoteThumbnailView.pdfFallbackImage(for: note, cache: cache))
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: url) }
        try model.exportPDF(for: note, to: url)
        let exported = try XCTUnwrap(PDFDocument(url: url)?.page(at: 0))
        for image in [sidebar, library, exported.thumbnail(of: CGSize(width: 306, height: 396), for: .mediaBox)] {
            let cg = try XCTUnwrap(image.cgImage(forProposedRect: nil, context: nil, hints: nil))
            let bitmap = NSBitmapImageRep(cgImage: cg)
            var strongestRed: CGFloat = 0
            for x in 20..<64 {
                for y in 20..<64 {
                    let color = try XCTUnwrap(bitmap.colorAt(x: x, y: y)?.usingColorSpace(.deviceRGB))
                    strongestRed = max(strongestRed, color.redComponent - color.greenComponent)
                }
            }
            XCTAssertGreaterThan(strongestRed, 0.005)
        }
    }

    func testLandscapeThumbnailIncludesStrokeNearRightEdge() throws {
        let (viewModel, context) = TestSupport.makeInMemoryViewModel()
        viewModel.addNote(title: "Horizontal", orientation: .landscape)
        let note = try XCTUnwrap(viewModel.selectedNote)

        let stroke = Stroke(context: context)
        stroke.id = UUID()
        stroke.points = "700.0,306.0;720.0,306.0"
        stroke.color = "#000000"
        stroke.width = 8
        stroke.createdAt = Date()
        stroke.pageIndex = 0
        stroke.note = note
        try context.save()

        let document = try XCTUnwrap(viewModel.getPDFDocument(for: note))
        let page = try XCTUnwrap(document.page(at: 0))
        XCTAssertEqual(page.bounds(for: .mediaBox).size, CGSize(width: 792, height: 612))
        let thumbnail = PageThumbnail.renderThumbnail(for: page, note: note, pageIndex: 0)
        let bitmap = try XCTUnwrap(thumbnail.cgImage(forProposedRect: nil, context: nil, hints: nil))
        let pixels = NSBitmapImageRep(cgImage: bitmap)

        XCTAssertEqual(page.bounds(for: .mediaBox).width, 792)

        // x=700 on a 792-point page maps near pixel 198 in the 224-pixel thumbnail.
        // Sample a small area around the stroke, away from the paper's left side.
        var darkestPixel = 1.0
        for x in 193..<205 {
            for y in (pixels.pixelsHigh / 2 - 3)...(pixels.pixelsHigh / 2 + 3) {
                guard let color = pixels.colorAt(x: x, y: y)?.usingColorSpace(.deviceRGB) else { continue }
                darkestPixel = min(darkestPixel, Double(max(color.redComponent, color.greenComponent, color.blueComponent)))
            }
        }
        XCTAssertLessThan(darkestPixel, 0.25, "Expected the stroke at x=700 to appear in the right side of the landscape thumbnail")
    }
}
