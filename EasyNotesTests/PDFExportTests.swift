import XCTest
import CoreData
import PDFKit
import AppKit

class PDFExportTests: XCTestCase {
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

    private func makeTempPDFURL() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).pdf")
    }

    private func addStroke(to note: Note, points: String, color: String, width: Float, pageIndex: Int16) {
        let stroke = Stroke(context: inMemoryContext)
        stroke.id = UUID()
        stroke.points = points
        stroke.color = color
        stroke.width = width
        stroke.createdAt = Date()
        stroke.pageIndex = pageIndex
        stroke.note = note
        try? inMemoryContext.save()
    }

    /// Samples the average color in a small window around `point` (in PDF
    /// mediaBox coordinates, bottom-left origin) by rendering `page` to a
    /// raster thumbnail and reading back pixels.
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
        let normalizedY = (point.y - mediaBox.minY) / mediaBox.height // PDF: bottom-left origin

        let pixelX = Int(normalizedX * CGFloat(imageWidth))
        let pixelY = Int((1 - normalizedY) * CGFloat(imageHeight)) // raster: top-left origin

        var totalR: CGFloat = 0, totalG: CGFloat = 0, totalB: CGFloat = 0
        var count = 0
        for dx in -sampleRadius...sampleRadius {
            for dy in -sampleRadius...sampleRadius {
                let x = pixelX + dx
                let y = pixelY + dy
                guard x >= 0, x < imageWidth, y >= 0, y < imageHeight,
                      let color = rep.colorAt(x: x, y: y) else { continue }
                totalR += color.redComponent
                totalG += color.greenComponent
                totalB += color.blueComponent
                count += 1
            }
        }
        guard count > 0 else { return nil }
        return (totalR / CGFloat(count), totalG / CGFloat(count), totalB / CGFloat(count))
    }

    func testExportPDFThrowsWhenDocumentUnavailable() {
        // Given a note whose pdfData is not a valid PDF, forcing a 0-page document
        let note = Note(context: inMemoryContext)
        note.id = UUID()
        note.title = "Corrupt"
        note.content = ""
        note.createdAt = Date()
        note.updatedAt = Date()
        note.isTrashed = false
        note.pdfData = Data([0x00, 0x01, 0x02])
        note.pageCount = 0
        try? inMemoryContext.save()

        let destination = makeTempPDFURL()

        // When / Then
        XCTAssertThrowsError(try viewModel.exportPDF(for: note, to: destination)) { error in
            XCTAssertEqual(error as? PDFExportError, .documentUnavailable)
        }
        XCTAssertFalse(FileManager.default.fileExists(atPath: destination.path))
    }

    func testExportPDFWritesValidPDFToDestinationURL() throws {
        // Given
        viewModel.addNote(title: "Export Me", content: "")
        guard let note = viewModel.notes.first else {
            XCTFail("Failed to add note")
            return
        }
        let destination = makeTempPDFURL()

        // When
        try viewModel.exportPDF(for: note, to: destination)

        // Then
        XCTAssertTrue(FileManager.default.fileExists(atPath: destination.path))
        let exportedDoc = PDFDocument(url: destination)
        XCTAssertNotNil(exportedDoc)
        XCTAssertEqual(exportedDoc?.pageCount, 1)
    }

    func testExportPDFPreservesPageCount() throws {
        // Given
        viewModel.addNote(title: "Multi Page", content: "")
        guard let note = viewModel.notes.first else {
            XCTFail("Failed to add note")
            return
        }
        viewModel.selectedNote = note
        viewModel.addBlankPage()
        let destination = makeTempPDFURL()

        // When
        try viewModel.exportPDF(for: note, to: destination)

        // Then
        let exportedDoc = PDFDocument(url: destination)
        XCTAssertEqual(exportedDoc?.pageCount, 2)
    }

    func testExportPDFBakesStrokesIntoOutputBytes() throws {
        // Given a note with a bright red stroke drawn on page 0
        viewModel.addNote(title: "Drawing", content: "")
        guard let note = viewModel.notes.first else {
            XCTFail("Failed to add note")
            return
        }
        let strokePoint = CGPoint(x: 300, y: 400)
        addStroke(
            to: note,
            points: "260.0,400.0;340.0,400.0",
            color: "#FF0000",
            width: 24,
            pageIndex: 0
        )
        let destination = makeTempPDFURL()

        // When
        try viewModel.exportPDF(for: note, to: destination)

        // Then
        guard let exportedDoc = PDFDocument(url: destination),
              let page = exportedDoc.page(at: 0) else {
            XCTFail("Failed to reload exported PDF")
            return
        }
        guard let sampled = averageColor(on: page, at: strokePoint) else {
            XCTFail("Failed to sample pixel color")
            return
        }
        XCTAssertGreaterThan(sampled.r, 0.6, "Expected dominant red channel at stroke location")
        XCTAssertLessThan(sampled.g, 0.4, "Expected suppressed green channel at stroke location")
        XCTAssertLessThan(sampled.b, 0.4, "Expected suppressed blue channel at stroke location")
    }

    func testExportedPressureStrokeVariesInWidthAndLegacyStrokeStaysConstant() throws {
        viewModel.addNote(title: "Pressão", content: "")
        let note = try XCTUnwrap(viewModel.notes.first)
        addStroke(
            to: note,
            points: StrokePressure.storing([0.2, 1], in: "100,400;500,400"),
            color: "#FF0000",
            width: 32,
            pageIndex: 0
        )
        addStroke(to: note, points: "100,300;500,300", color: "#FF0000", width: 32, pageIndex: 0)
        let destination = makeTempPDFURL()
        defer { try? FileManager.default.removeItem(at: destination) }
        try viewModel.exportPDF(for: note, to: destination, options: PDFExportOptions(includeGrid: false))
        let page = try XCTUnwrap(PDFDocument(url: destination)?.page(at: 0))

        // Both strokes should cover their centerline. Nine points away, only
        // the wide end of the pressure stroke and the legacy stroke cover ink.
        for point in [CGPoint(x: 125, y: 400), CGPoint(x: 475, y: 409),
                      CGPoint(x: 125, y: 309), CGPoint(x: 475, y: 309)] {
            let ink = try XCTUnwrap(averageColor(on: page, at: point))
            XCTAssertLessThan(ink.g, 0.4, "Expected ink at \(point)")
        }
        let paper = try XCTUnwrap(averageColor(on: page, at: CGPoint(x: 125, y: 409)))
        XCTAssertGreaterThan(paper.g, 0.8)
    }

    func testExportPDFOmitsStrokesFromOtherPages() throws {
        // Given a 2-page note with a stroke only on page 1 (0-indexed)
        viewModel.addNote(title: "Two Pages", content: "")
        guard let note = viewModel.notes.first else {
            XCTFail("Failed to add note")
            return
        }
        viewModel.selectedNote = note
        viewModel.addBlankPage()

        let strokePoint = CGPoint(x: 300, y: 400)
        addStroke(
            to: note,
            points: "260.0,400.0;340.0,400.0",
            color: "#FF0000",
            width: 24,
            pageIndex: 1
        )
        let destination = makeTempPDFURL()

        // When
        try viewModel.exportPDF(for: note, to: destination)

        // Then: page 0 (no stroke) should remain background-white at the same coordinate
        guard let exportedDoc = PDFDocument(url: destination),
              let firstPage = exportedDoc.page(at: 0) else {
            XCTFail("Failed to reload exported PDF")
            return
        }
        guard let sampled = averageColor(on: firstPage, at: strokePoint) else {
            XCTFail("Failed to sample pixel color")
            return
        }
        XCTAssertGreaterThan(sampled.r, 0.9, "Expected page without strokes to remain white")
        XCTAssertGreaterThan(sampled.g, 0.9, "Expected page without strokes to remain white")
        XCTAssertGreaterThan(sampled.b, 0.9, "Expected page without strokes to remain white")
    }

    private func addShape(to note: Note, kind: String, points: String,
                          strokeColor: String, width: Float,
                          fillColor: String?, pageIndex: Int16) {
        let shape = ShapeObject(context: inMemoryContext)
        shape.id = UUID()
        shape.kind = kind
        shape.points = points
        shape.strokeColor = strokeColor
        shape.strokeWidth = width
        shape.fillColor = fillColor
        shape.createdAt = Date()
        shape.pageIndex = pageIndex
        shape.note = note
        try? inMemoryContext.save()
    }

    func testExportPDFBakesFilledShapeIntoOutputBytes() throws {
        // Given a note with a solid red rectangle centered around (300, 400)
        viewModel.addNote(title: "Shape Drawing", content: "")
        guard let note = viewModel.notes.first else {
            XCTFail("Failed to add note")
            return
        }
        let center = CGPoint(x: 300, y: 400)
        addShape(
            to: note,
            kind: "rectangle",
            points: "260.0,360.0;340.0,440.0",
            strokeColor: "#FF0000",
            width: 4,
            fillColor: "#FF0000",
            pageIndex: 0
        )
        let destination = makeTempPDFURL()

        // When
        try viewModel.exportPDF(for: note, to: destination)

        // Then
        guard let exportedDoc = PDFDocument(url: destination),
              let page = exportedDoc.page(at: 0),
              let sampled = averageColor(on: page, at: center) else {
            XCTFail("Failed to reload/sample exported PDF")
            return
        }
        XCTAssertGreaterThan(sampled.r, 0.6, "Expected dominant red channel inside filled rectangle")
        XCTAssertLessThan(sampled.g, 0.4, "Expected suppressed green channel inside filled rectangle")
        XCTAssertLessThan(sampled.b, 0.4, "Expected suppressed blue channel inside filled rectangle")
    }

    func testExportPDFWithGridDoesNotThrowAndKeepsPageCount() throws {
        // Given a note with the cartesian grid enabled
        viewModel.addNote(title: "Grid Note", content: "")
        guard let note = viewModel.notes.first else {
            XCTFail("Failed to add note")
            return
        }
        viewModel.setGridStyle(.grid, for: note)
        let destination = makeTempPDFURL()

        // When / Then: export succeeds and preserves the page count
        try viewModel.exportPDF(for: note, to: destination)
        let exportedDoc = PDFDocument(url: destination)
        XCTAssertEqual(exportedDoc?.pageCount, 1)
    }

    func testExportPDFThrowsOnUnwritableDestination() {
        // Given
        viewModel.addNote(title: "Bad Destination", content: "")
        guard let note = viewModel.notes.first else {
            XCTFail("Failed to add note")
            return
        }
        let destination = URL(fileURLWithPath: "/nonexistent-easy-notes-test-dir-\(UUID().uuidString)/out.pdf")

        // When / Then
        XCTAssertThrowsError(try viewModel.exportPDF(for: note, to: destination))
    }

    func testExportPDFIncludeGridOptionTrueVsFalse() throws {
        viewModel.addNote(title: "Grid Compare Note", content: "")
        guard let note = viewModel.notes.first else {
            XCTFail("Failed to add note")
            return
        }
        viewModel.setGridStyle(.grid, for: note)
        viewModel.setGridColor(.black, for: note)

        let destWithGrid = makeTempPDFURL()
        let destWithoutGrid = makeTempPDFURL()

        try viewModel.exportPDF(for: note, to: destWithGrid, options: PDFExportOptions(includeGrid: true))
        try viewModel.exportPDF(for: note, to: destWithoutGrid, options: PDFExportOptions(includeGrid: false))

        let dataWithGrid = try Data(contentsOf: destWithGrid)
        let dataWithoutGrid = try Data(contentsOf: destWithoutGrid)

        XCTAssertTrue(FileManager.default.fileExists(atPath: destWithGrid.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: destWithoutGrid.path))
        XCTAssertGreaterThan(dataWithGrid.count, dataWithoutGrid.count, "PDF with grid should have additional drawing operators")
    }

    func testExportPDFWithPageRangePreservesPageCountAndStrokes() throws {
        // Given a 2-page note with a red stroke on page 1 (0-based)
        viewModel.addNote(title: "Two Pages Range", content: "")
        guard let note = viewModel.notes.first else {
            XCTFail("Failed to add note")
            return
        }
        viewModel.selectedNote = note
        viewModel.addBlankPage()
        XCTAssertEqual(note.pageCount, 2)

        let strokePoint = CGPoint(x: 300, y: 400)
        addStroke(
            to: note,
            points: "260.0,400.0;340.0,400.0",
            color: "#FF0000",
            width: 24,
            pageIndex: 1
        )

        // Export only page 1 (second page, 0-based index 1...1)
        let destination = makeTempPDFURL()
        let options = PDFExportOptions(includeGrid: false, pageRange: 1...1)
        try viewModel.exportPDF(for: note, to: destination, options: options)

        // Then: exported document has pageCount == 1, and contains the red stroke
        guard let exportedDoc = PDFDocument(url: destination) else {
            XCTFail("Failed to load exported PDF")
            return
        }
        XCTAssertEqual(exportedDoc.pageCount, 1)

        guard let exportedPage = exportedDoc.page(at: 0),
              let sampled = averageColor(on: exportedPage, at: strokePoint) else {
            XCTFail("Failed to sample exported page color")
            return
        }
        XCTAssertGreaterThan(sampled.r, 0.6, "Expected red stroke on exported page")
        XCTAssertLessThan(sampled.g, 0.4)
        XCTAssertLessThan(sampled.b, 0.4)

        // And exporting page 0 (index 0...0) should have pageCount == 1 without stroke
        let destPage0 = makeTempPDFURL()
        try viewModel.exportPDF(for: note, to: destPage0, options: PDFExportOptions(includeGrid: false, pageRange: 0...0))
        guard let docPage0 = PDFDocument(url: destPage0),
              let page0 = docPage0.page(at: 0),
              let sampled0 = averageColor(on: page0, at: strokePoint) else {
            XCTFail("Failed to sample page 0")
            return
        }
        XCTAssertEqual(docPage0.pageCount, 1)
        XCTAssertGreaterThan(sampled0.r, 0.9, "Page 0 should remain white")
        XCTAssertGreaterThan(sampled0.g, 0.9)
        XCTAssertGreaterThan(sampled0.b, 0.9)
    }

    func testExportPDFInvalidPageRangeThrowsAndDoesNotCreateFile() {
        viewModel.addNote(title: "Invalid Range Note", content: "")
        guard let note = viewModel.notes.first else {
            XCTFail("Failed to add note")
            return
        }
        let destination = makeTempPDFURL()

        // Page count is 1 (index 0), so range 0...1 is out of bounds
        let invalidOptions = PDFExportOptions(includeGrid: true, pageRange: 0...1)
        XCTAssertThrowsError(try viewModel.exportPDF(for: note, to: destination, options: invalidOptions)) { error in
            XCTAssertEqual(error as? PDFExportError, .invalidPageRange)
        }
        XCTAssertFalse(FileManager.default.fileExists(atPath: destination.path), "Invalid page range must not write file")

        // Inverted range or negative indices
        let negativeDestination = makeTempPDFURL()
        let negativeOptions = PDFExportOptions(includeGrid: true, pageRange: -1...0)
        XCTAssertThrowsError(try viewModel.exportPDF(for: note, to: negativeDestination, options: negativeOptions)) { error in
            XCTAssertEqual(error as? PDFExportError, .invalidPageRange)
        }
        XCTAssertFalse(FileManager.default.fileExists(atPath: negativeDestination.path))
    }

    func testFlushTitleEditsEnsuresUpdatedSuggestedPDFName() {
        viewModel.addNote(title: "Initial Title", content: "Content")
        guard let note = viewModel.notes.first else {
            XCTFail("Failed to add note")
            return
        }
        XCTAssertEqual(note.suggestedPDFName, "Initial Title.pdf")

        viewModel.editTitle(of: note, to: "Updated Title By User")
        XCTAssertTrue(viewModel.hasPendingTitle)

        viewModel.flushTitleEdits()

        XCTAssertFalse(viewModel.hasPendingTitle)
        XCTAssertEqual(note.title, "Updated Title By User")
        XCTAssertEqual(note.suggestedPDFName, "Updated Title By User.pdf")
    }

    func testParsePageRangeValidAndInvalid() throws {
        // Valid
        XCTAssertEqual(try PDFExportOptions.parsePageRange("1-3", pageCount: 5), 0...2)
        XCTAssertEqual(try PDFExportOptions.parsePageRange("2", pageCount: 4), 1...1)
        XCTAssertEqual(try PDFExportOptions.parsePageRange("  1 - 2  ", pageCount: 2), 0...1)

        // Invalid
        XCTAssertThrowsError(try PDFExportOptions.parsePageRange("0-2", pageCount: 3)) {
            XCTAssertEqual($0 as? PDFExportError, .invalidPageRange)
        }
        XCTAssertThrowsError(try PDFExportOptions.parsePageRange("1-5", pageCount: 3)) {
            XCTAssertEqual($0 as? PDFExportError, .invalidPageRange)
        }
        XCTAssertThrowsError(try PDFExportOptions.parsePageRange("3-1", pageCount: 3)) {
            XCTAssertEqual($0 as? PDFExportError, .invalidPageRange)
        }
        XCTAssertThrowsError(try PDFExportOptions.parsePageRange("abc", pageCount: 3)) {
            XCTAssertEqual($0 as? PDFExportError, .invalidPageRange)
        }
        XCTAssertThrowsError(try PDFExportOptions.parsePageRange("", pageCount: 3)) {
            XCTAssertEqual($0 as? PDFExportError, .invalidPageRange)
        }
    }

    @MainActor
    func testPDFExportAccessoryViewOptionsResolution() throws {
        let accessory = PDFExportAccessoryView(pageCount: 3, initialIncludeGrid: true)
        let defaultOptions = try accessory.resolveOptions()
        XCTAssertTrue(defaultOptions.includeGrid)
        XCTAssertNil(defaultOptions.pageRange) // "Todas" is selected

        // Toggle checkbox
        accessory.gridCheckbox.state = .off
        let noGridOptions = try accessory.resolveOptions()
        XCTAssertFalse(noGridOptions.includeGrid)

        // Select interval
        accessory.rangeRadio.state = .on
        accessory.allPagesRadio.state = .off
        accessory.updateControlsState()
        accessory.fromField.stringValue = "2"
        accessory.toField.stringValue = "3"

        let rangeOptions = try accessory.resolveOptions()
        XCTAssertEqual(rangeOptions.pageRange, 1...2)

        // Invalid range in fields
        accessory.fromField.stringValue = "3"
        accessory.toField.stringValue = "1"
        XCTAssertThrowsError(try accessory.resolveOptions()) {
            XCTAssertEqual($0 as? PDFExportError, .invalidPageRange)
        }
    }

    func testPDFExportErrorLocalizedDescriptions() {
        XCTAssertEqual(
            PDFExportError.documentUnavailable.localizedDescription,
            "O documento PDF da nota não está disponível para exportação."
        )
        XCTAssertEqual(
            PDFExportError.contextCreationFailed.localizedDescription,
            "Não foi possível criar o contexto de renderização do PDF."
        )
        XCTAssertEqual(
            PDFExportError.invalidPageRange.localizedDescription,
            "O intervalo de páginas especificado é inválido."
        )
    }
}
