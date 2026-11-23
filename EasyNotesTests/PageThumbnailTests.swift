import AppKit
import CoreData
import PDFKit
import XCTest

final class PageThumbnailTests: XCTestCase {
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
        let storedPage = try XCTUnwrap(document.page(at: 0))
        let page = AnnotatedPDFPage()
        page.setBounds(storedPage.bounds(for: .mediaBox), for: .mediaBox)
        page.note = note
        XCTAssertEqual(page.bounds(for: .mediaBox).size, CGSize(width: 792, height: 612))
        let thumbnail = PageThumbnail.renderThumbnail(for: page)
        let bitmap = try XCTUnwrap(thumbnail.cgImage(forProposedRect: nil, context: nil, hints: nil))
        let pixels = NSBitmapImageRep(cgImage: bitmap)

        XCTAssertEqual(page.bounds(for: .mediaBox).width, 792)

        // x=700 on a 792-point page maps near pixel 198 in the 224-pixel thumbnail.
        // Sample a small area around the stroke, away from the paper's left side.
        var darkestPixel = 1.0
        for x in 193..<205 {
            for y in 144..<151 {
                guard let color = pixels.colorAt(x: x, y: y)?.usingColorSpace(.deviceRGB) else { continue }
                darkestPixel = min(darkestPixel, Double(max(color.redComponent, color.greenComponent, color.blueComponent)))
            }
        }
        XCTAssertLessThan(darkestPixel, 0.25, "Expected the stroke at x=700 to appear in the right side of the landscape thumbnail")
    }
}
