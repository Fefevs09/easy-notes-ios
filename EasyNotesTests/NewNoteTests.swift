import CoreData
import PDFKit
import XCTest

final class NewNoteTests: XCTestCase {
    func testEditingAndDiscardingDraftLeavesLibraryUnchanged() throws {
        let (model, context) = TestSupport.makeInMemoryViewModel()
        let request = NSFetchRequest<Note>(entityName: "Note")
        let originalCount = try context.count(for: request)
        let selected = model.selectedNote
        var draft = NewNoteDraft()
        draft.title = "Descartar"
        draft.paper = .grid
        draft.orientation = .landscape
        draft = NewNoteDraft()
        XCTAssertEqual(try context.count(for: request), originalCount)
        XCTAssertEqual(model.selectedNote, selected)
        try draft.create(in: model)
        XCTAssertEqual(try context.count(for: request), originalCount + 1)
        XCTAssertEqual(model.selectedNote?.title, "Nova Nota")
        XCTAssertNil(model.selectedNote?.notebook)
    }

    func testPaperChoicesPersistAndExportWithRequestedDimensions() throws {
        let (model, context) = TestSupport.makeInMemoryViewModel()
        let notebook = try XCTUnwrap(model.notebooks.first)
        model.selectedFilter = .notebook(notebook)
        for orientation in NoteOrientation.allCases {
            let expected = orientation == .portrait
                ? CGSize(width: 612, height: 792) : CGSize(width: 792, height: 612)
            for paper in GridStyle.allCases {
                model.addNote(title: "Teste", paper: paper, orientation: orientation)
                let note = try XCTUnwrap(model.selectedNote)
                XCTAssertEqual(note.notebook, notebook)
                XCTAssertEqual(note.pageCount, 1)
                if paper == .grid {
                    let center = CGPoint(x: CGFloat(note.gridOriginX), y: CGFloat(note.gridOriginY))
                    XCTAssertEqual(center, orientation.pageCenter)
                    model.setGridStyle(.none, for: note)
                    model.setGridStyle(.grid, for: note)
                    XCTAssertEqual(CGPoint(x: CGFloat(note.gridOriginX), y: CGFloat(note.gridOriginY)), center)
                }
                model.addBlankPage()
                context.refresh(note, mergeChanges: false)
                XCTAssertEqual(note.gridStyle, paper.rawValue)
                let stored = try XCTUnwrap(note.pdfData.flatMap(PDFDocument.init(data:)))
                let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
                defer { try? FileManager.default.removeItem(at: url) }
                try model.exportPDF(for: note, to: url)
                let exported = try XCTUnwrap(PDFDocument(url: url))
                for document in [stored, exported] {
                    XCTAssertEqual(document.pageCount, 2)
                    for index in 0..<2 {
                        XCTAssertEqual(document.page(at: index)?.bounds(for: .mediaBox).size, expected)
                    }
                }
            }
        }
    }
}

extension NewNoteTests {
    func testCalendarRespectsLeapYearsAndLocalizedWeekOrder() throws {
        let us = try MonthlyCalendarLayout(month: 2, year: 2024, locale: Locale(identifier: "en_US"))
        let uk = try MonthlyCalendarLayout(month: 2, year: 2024, locale: Locale(identifier: "en_GB"))
        let brazil = try MonthlyCalendarLayout(month: 2, year: 2023, locale: Locale(identifier: "pt_BR"))

        XCTAssertEqual(us.dayCount, 29)
        XCTAssertEqual(us.weekdays.first, "Sun")
        XCTAssertEqual(us.position(of: 1).column, 4)
        XCTAssertEqual(us.position(of: 29).row, 4)
        XCTAssertEqual(us.position(of: 29).column, 4)
        XCTAssertEqual(uk.weekdays.first, "Mon")
        XCTAssertEqual(uk.position(of: 1).column, 3)
        XCTAssertEqual(uk.position(of: 29).column, 3)
        XCTAssertEqual(brazil.dayCount, 28)
        XCTAssertTrue(brazil.title.localizedCaseInsensitiveContains("fevereiro"))

        let sixWeeks = try MonthlyCalendarLayout(month: 8, year: 2020, locale: Locale(identifier: "en_US"))
        XCTAssertEqual(sixWeeks.rowCount, 6)
        XCTAssertEqual(sixWeeks.position(of: 31).row, 5)
        XCTAssertEqual(sixWeeks.position(of: 31).column, 1)
    }

    func testTemplatesCreateAnnotatedExportInSelectedNotebookForBothOrientations() throws {
        let (model, context) = TestSupport.makeInMemoryViewModel()
        let notebook = try XCTUnwrap(model.notebooks.first)
        model.selectedFilter = .notebook(notebook)

        for orientation in NoteOrientation.allCases {
            for template in [NoteTemplate.monthlyCalendar, .taskList] {
                var draft = NewNoteDraft(title: "  Planejamento  ", paper: .dots, orientation: orientation)
                draft.template = template
                draft.month = 2
                draft.year = "2024"
                try draft.create(in: model, locale: Locale(identifier: "pt_BR"))

                let note = try XCTUnwrap(model.selectedNote)
                context.refresh(note, mergeChanges: false)
                XCTAssertEqual(note.title, "Planejamento")
                XCTAssertEqual(note.notebook, notebook)
                XCTAssertEqual(note.gridStyle, GridStyle.dots.rawValue)
                XCTAssertEqual(note.pageCount, 1)
                let editorDocument = try XCTUnwrap(model.getPDFDocument(for: note))
                let editorPage = try XCTUnwrap(editorDocument.page(at: 0))

                let stroke = Stroke(context: context)
                stroke.id = UUID()
                stroke.note = note
                stroke.pageIndex = 0
                stroke.points = "38.0,40.0;50.0,52.0"
                stroke.color = "#FF0000"
                stroke.width = 6
                stroke.createdAt = Date()
                try context.save()
                XCTAssertTrue((note.strokes as? Set<Stroke>)?.contains(stroke) == true)

                let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
                defer { try? FileManager.default.removeItem(at: url) }
                try model.exportPDF(for: note, to: url, options: PDFExportOptions(includeGrid: false))
                let exported = try XCTUnwrap(PDFDocument(url: url))
                XCTAssertEqual(exported.pageCount, 1)
                let exportedPage = try XCTUnwrap(exported.page(at: 0))
                let annotation = try pixel(on: exportedPage, x: 44, y: 46)
                XCTAssertGreaterThan(annotation[0], 200)
                XCTAssertLessThan(annotation[1], 40)
                for page in [editorPage, exportedPage] {
                    XCTAssertEqual(page.bounds(for: .mediaBox).size, orientation.pageSize)
                    let text = try XCTUnwrap(page.string)
                    if template == .monthlyCalendar {
                        XCTAssertTrue(text.localizedCaseInsensitiveContains("fevereiro"))
                        let days = text.split(whereSeparator: \.isWhitespace).compactMap { Int($0) }.filter { $0 <= 31 }
                        XCTAssertEqual(days, Array(1...29))
                    } else {
                        XCTAssertTrue(text.contains("Lista de tarefas"))
                        let y = orientation.pageSize.height - 110
                        let edge = try pixel(on: page, x: 36, y: y)
                        let interior = try pixel(on: page, x: 45, y: y)
                        XCTAssertLessThan(edge[0], 225)
                        XCTAssertGreaterThan(interior[0], 245)
                    }
                }
            }
        }
    }

    private func pixel(on page: PDFPage, x: CGFloat, y: CGFloat) throws -> [UInt8] {
        let context = try XCTUnwrap(CGContext(data: nil, width: 1, height: 1, bitsPerComponent: 8,
                                             bytesPerRow: 4, space: CGColorSpaceCreateDeviceRGB(),
                                             bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue))
        context.translateBy(x: 0.5 - x, y: 0.5 - y)
        page.draw(with: .mediaBox, to: context)
        let bytes = try XCTUnwrap(context.data).assumingMemoryBound(to: UInt8.self)
        return Array(UnsafeBufferPointer(start: bytes, count: 3))
    }

    func testInvalidCalendarLeavesSelectionAndStoreUnchanged() throws {
        let (model, context) = TestSupport.makeInMemoryViewModel()
        model.selectedFilter = .trash
        let selectedNote = model.notes.first
        model.selectedNote = selectedNote
        let request = NSFetchRequest<Note>(entityName: "Note")
        let count = try context.count(for: request)
        let draft = NewNoteDraft(template: .monthlyCalendar, month: 2, year: "0")

        XCTAssertThrowsError(try draft.create(in: model))
        XCTAssertEqual(model.selectedFilter, .trash)
        XCTAssertEqual(model.selectedNote, selectedNote)
        XCTAssertEqual(try context.count(for: request), count)
        XCTAssertFalse(context.hasChanges)
    }

    func testSaveFailureDiscardsOnlyTheNewNote() throws {
        let (model, context) = TestSupport.makeInMemoryViewModel()
        let notebook = try XCTUnwrap(model.notebooks.first)
        model.selectedFilter = .notebook(notebook)
        let previous = model.notes.first
        model.selectedNote = previous
        let request = NSFetchRequest<Note>(entityName: "Note")
        let count = try context.count(for: request)
        let notebookNotes = notebook.notes

        // A pending unrelated insertion missing its required ID and name fails validation.
        let unrelated = Notebook(context: context)
        context.processPendingChanges()
        XCTAssertThrowsError(try NewNoteDraft(template: .taskList).create(in: model))
        context.processPendingChanges()

        XCTAssertEqual(model.selectedNote, previous)
        XCTAssertEqual(model.selectedFilter, .notebook(notebook))
        XCTAssertEqual(notebook.notes, notebookNotes)
        XCTAssertEqual(try context.count(for: request), count)
        XCTAssertEqual(context.insertedObjects, [unrelated])
    }
}
