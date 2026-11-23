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
        draft.create(in: model)
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
