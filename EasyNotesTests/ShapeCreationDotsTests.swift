import AppKit
import PDFKit
import XCTest

final class ShapeCreationDotsTests: XCTestCase {
    func testCursorPolarityFollowsEachPDFPage() throws {
        let data = NSMutableData()
        let consumer = try XCTUnwrap(CGDataConsumer(data: data))
        var bounds = CGRect(x: 0, y: 0, width: 100, height: 100)
        let pdf = try XCTUnwrap(CGContext(consumer: consumer, mediaBox: &bounds, nil))
        for gray: CGFloat in [1, 0] {
            pdf.beginPDFPage(nil)
            pdf.setFillColor(gray: gray, alpha: 1)
            pdf.fill(bounds)
            pdf.endPDFPage()
        }
        pdf.closePDF()
        let document = try XCTUnwrap(PDFDocument(data: data as Data))
        let light = try XCTUnwrap(document.page(at: 0))
        let dark = try XCTUnwrap(document.page(at: 1))
        XCTAssertFalse(shapePaperIsDark(light))
        XCTAssertTrue(shapePaperIsDark(dark))
        XCTAssertFalse(shapePaperIsDark(light))
    }

    // Render in screen coordinates so spacing and contrast are observable
    // independently of the page coordinate system.
    private func bitmap(kind: ShapeKind, zoom: CGFloat) throws -> CGContext {
        let context = try XCTUnwrap(CGContext(data: nil, width: 160, height: 120,
                                              bitsPerComponent: 8, bytesPerRow: 160,
                                              space: CGColorSpaceCreateDeviceGray(),
                                              bitmapInfo: CGImageAlphaInfo.none.rawValue))
        context.setFillColor(gray: 0.5, alpha: 1)
        context.fill(CGRect(x: 0, y: 0, width: 160, height: 120))
        context.scaleBy(x: zoom, y: zoom)
        let endY: CGFloat = kind == .ellipse || kind == .rectangle ? 90 : 30
        let path = makeShapeCGPath(kind: kind, points: [
            CGPoint(x: 20 / zoom, y: 30 / zoom), CGPoint(x: 140 / zoom, y: endY / zoom)
        ])
        drawShapeCreationDots(on: path, zoom: zoom, in: context)
        return context
    }

    func testLineHasDarkDotsLightRimsAndGapsAtEveryZoom() throws {
        for zoom: CGFloat in [0.25, 1, 4] {
            let image = try bitmap(kind: .line, zoom: zoom)
            let pixels = try XCTUnwrap(image.data).assumingMemoryBound(to: UInt8.self)
            // Bitmap rows start at the top.
            let row = (119 - 30) * image.bytesPerRow
            XCTAssertLessThan(pixels[row + 40], 55)
            XCTAssertGreaterThan(pixels[row + 41], 155)
            XCTAssertEqual(Int(pixels[row + 45]), 128, accuracy: 1)
        }
    }

    func testDotsReachBothArrowWingsAndOppositeSidesOfClosedForms() throws {
        for kind: ShapeKind in [.arrow, .rectangle, .ellipse] {
            let image = try bitmap(kind: kind, zoom: 1)
            let pixels = try XCTUnwrap(image.data).assumingMemoryBound(to: UInt8.self)
            func hasDot(_ xs: Range<Int>, _ ys: Range<Int>) -> Bool {
                ys.contains { y in
                    xs.contains { x in pixels[(119 - y) * image.bytesPerRow + x] < 64 }
                }
            }
            if kind == .arrow {
                XCTAssertTrue(hasDot(118..<135, 19..<28))
                XCTAssertTrue(hasDot(118..<135, 33..<42))
            } else {
                XCTAssertTrue(hasDot(66..<94, 28..<33))
                XCTAssertTrue(hasDot(66..<94, 87..<93))
                XCTAssertFalse(hasDot(60..<100, 50..<70))
            }
        }
    }
}
