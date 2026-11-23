import XCTest
import CoreData
import PDFKit

class NoteViewModelTests: XCTestCase {
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
    
    func testAddNote() {
        // Given
        let initialCount = viewModel.notes.count
        
        // When
        viewModel.addNote(title: "Test Note", content: "Test Content")
        
        // Then
        XCTAssertEqual(viewModel.notes.count, initialCount + 1)
        XCTAssertEqual(viewModel.notes.first?.title, "Test Note")
        XCTAssertEqual(viewModel.notes.first?.content, "Test Content")
    }
    
    func testSelectNote() {
        // Given
        viewModel.addNote(title: "Select Me", content: "Select Content")
        guard let addedNote = viewModel.notes.first else {
            XCTFail("Failed to add note for testing selection")
            return
        }
        
        // When
        viewModel.selectedNote = addedNote
        
        // Then
        XCTAssertNotNil(viewModel.selectedNote)
        XCTAssertEqual(viewModel.selectedNote?.id, addedNote.id)
    }
    
    func testDeleteNoteMovesToTrash() {
        // Given
        viewModel.addNote(title: "Trash Me", content: "Trash Content")
        guard let addedNote = viewModel.notes.first else {
            XCTFail("Failed to add note for testing deletion")
            return
        }
        
        // When
        viewModel.deleteNote(addedNote)
        
        // Then
        XCTAssertNil(viewModel.selectedNote)
        XCTAssertTrue(addedNote.isTrashed)
    }
    
    func testSelectedNoteOptionalMatching() {
        // Given
        viewModel.addNote(title: "Optional Match", content: "Content")
        guard let note = viewModel.notes.first else {
            XCTFail("Failed to add note")
            return
        }
        
        // When
        let optionalNote: Note? = note
        viewModel.selectedNote = optionalNote
        
        // Then
        XCTAssertEqual(viewModel.selectedNote, note)
        XCTAssertTrue(viewModel.selectedNote as Note? == optionalNote)
    }
    
    func testAddNoteSelection() {
        // Given
        viewModel.selectedNote = nil
        XCTAssertNil(viewModel.selectedNote)
        
        // When
        viewModel.addNote(title: "New Created Note", content: "Some content")
        
        // Then
        XCTAssertNotNil(viewModel.selectedNote)
        XCTAssertEqual(viewModel.selectedNote?.title, "New Created Note")
    }
    
    func testSelectionOfNoteInNotebookFilter() {
        // Given
        let notebook = Notebook(context: inMemoryContext)
        notebook.id = UUID()
        notebook.name = "Work Notebook"
        
        viewModel.addNote(title: "Work Note", content: "Work content")
        guard let note = viewModel.notes.first else {
            XCTFail("Failed to add note")
            return
        }
        note.notebook = notebook
        viewModel.selectedFilter = .notebook(notebook)
        
        // When
        viewModel.selectedNote = note
        
        // Then
        XCTAssertEqual(viewModel.selectedNote, note)
        XCTAssertEqual(viewModel.selectedNote?.notebook, notebook)
    }
    
    func testImportPDF() {
        // Given
        let pdfData = Data([0x25, 0x50, 0x44, 0x46]) // %PDF header
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("test.pdf")
        try? pdfData.write(to: tempURL)
        defer { try? FileManager.default.removeItem(at: tempURL) }
        
        // When
        viewModel.importPDF(url: tempURL, title: "My imported PDF")
        
        // Then
        XCTAssertNotNil(viewModel.selectedNote)
        XCTAssertEqual(viewModel.selectedNote?.title, "My imported PDF")
        XCTAssertEqual(viewModel.selectedNote?.pdfData, pdfData)
    }
    
    func testAddBlankPage() {
        // Given
        viewModel.addNote(title: "Page Test", content: "")
        guard let note = viewModel.notes.first else {
            XCTFail("Failed to add note")
            return
        }
        viewModel.selectedNote = note
        note.pageCount = 1
        
        // When
        viewModel.addBlankPage()
        
        // Then
        XCTAssertEqual(note.pageCount, 2)
    }
    
    func testAddStrokeToPage() {
        // Given
        viewModel.addNote(title: "Drawing Test", content: "")
        guard let note = viewModel.notes.first else {
            XCTFail("Failed to add note")
            return
        }
        
        let stroke = Stroke(context: inMemoryContext)
        stroke.id = UUID()
        stroke.points = "10.0,20.0;30.0,40.0"
        stroke.width = 3.0
        stroke.color = "#000000"
        stroke.createdAt = Date()
        stroke.pageIndex = 2 // Page 2
        stroke.note = note
        
        try? inMemoryContext.save()
        
        // When
        viewModel.loadNotes()
        
        // Then
        let fetchedNote = viewModel.notes.first
        XCTAssertNotNil(fetchedNote)
        let strokes = fetchedNote?.strokes as? Set<Stroke> ?? []
        XCTAssertEqual(strokes.count, 1)
        XCTAssertEqual(strokes.first?.pageIndex, 2)
        XCTAssertEqual(strokes.first?.points, "10.0,20.0;30.0,40.0")
    }

    func testUndoRemovesMostRecentObjectAcrossStrokesAndShapes() {
        // Given a note with an older stroke and a newer shape
        viewModel.addNote(title: "Undo Test", content: "")
        guard let note = viewModel.notes.first else {
            XCTFail("Failed to add note")
            return
        }
        viewModel.selectedNote = note

        let stroke = Stroke(context: inMemoryContext)
        stroke.id = UUID()
        stroke.points = "0.0,0.0;10.0,10.0"
        stroke.width = 3.0
        stroke.color = "#000000"
        stroke.createdAt = Date(timeIntervalSince1970: 1000)
        stroke.pageIndex = 0
        stroke.note = note

        let shape = ShapeObject(context: inMemoryContext)
        shape.id = UUID()
        shape.kind = "rectangle"
        shape.points = "0.0,0.0;20.0,20.0"
        shape.strokeColor = "#000000"
        shape.strokeWidth = 3.0
        shape.createdAt = Date(timeIntervalSince1970: 2000) // newer
        shape.pageIndex = 0
        shape.note = note
        try? inMemoryContext.save()
        viewModel.loadNotes()

        // When: undo once -> removes the newer shape, keeps the stroke
        viewModel.undoLastObject()

        // Then
        XCTAssertEqual((note.shapes as? Set<ShapeObject> ?? []).count, 0)
        XCTAssertEqual((note.strokes as? Set<Stroke> ?? []).count, 1)

        // When: undo again -> removes the stroke
        viewModel.undoLastObject()
        XCTAssertEqual(viewModel.drawnObjectCount(for: note), 0)
    }

    func testSetGridStylePersistsAndCentersOrigin() {
        // Given a blank note (single generated PDF page)
        viewModel.addNote(title: "Grid Note", content: "")
        guard let note = viewModel.notes.first else {
            XCTFail("Failed to add note")
            return
        }

        // When enabling the full grid
        viewModel.setGridStyle(.grid, for: note)

        // Then the style persists and the origin is centered on the page
        XCTAssertEqual(note.gridStyle, "grid")
        XCTAssertGreaterThan(note.gridOriginX, 0)
        XCTAssertGreaterThan(note.gridOriginY, 0)
    }

    func testRenameTargetsOriginalNoteAcrossSelectionAndEditorClose() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let source = folder.appendingPathComponent("Origem.pdf")
        let document = PDFDocument()
        document.insert(PDFPage(), at: 0)
        XCTAssertTrue(document.write(to: source))
        let notebook = try XCTUnwrap(viewModel.notebooks.first)
        viewModel.selectedFilter = .notebook(notebook)
        viewModel.addNote(title: "Comum", content: "Texto")
        let common = try XCTUnwrap(viewModel.selectedNote)
        viewModel.importPDF(url: source)
        let imported = try XCTUnwrap(viewModel.selectedNote)
        XCTAssertEqual(common.suggestedPDFName, "Comum.pdf")
        XCTAssertEqual(imported.suggestedPDFName, "Origem.pdf")
        try viewModel.renameNote(common, to: "Comum editada")
        XCTAssertEqual(viewModel.selectedNote, imported)
        XCTAssertEqual(imported.title, "Origem")

        try viewModel.renameNote(imported, to: "PDF editado")
        viewModel.selectedNote = nil
        let commonID = common.objectID
        let importedID = imported.objectID
        let notebookID = notebook.objectID
        inMemoryContext.reset()
        for (id, expected) in [(commonID, "Comum editada"), (importedID, "PDF editado")] {
            let reopened = try XCTUnwrap(inMemoryContext.existingObject(with: id) as? Note)
            XCTAssertEqual(reopened.title, expected)
            XCTAssertEqual(reopened.notebook?.objectID, notebookID)
            XCTAssertEqual(reopened.suggestedPDFName, expected + ".pdf")
            let destination = folder.appendingPathComponent(reopened.suggestedPDFName)
            try viewModel.exportPDF(for: reopened, to: destination)
            XCTAssertEqual(PDFDocument(url: destination)?.pageCount, 1)
            if id == commonID {
                XCTAssertEqual(reopened.content, "Texto")
            } else {
                XCTAssertEqual(reopened.pdfData, try Data(contentsOf: source))
            }
        }
    }

    func testEditorBatchesTitleEditsAndFlushesOnSelectionChange() throws {
        viewModel.addNote(title: "Primeira")
        let first = try XCTUnwrap(viewModel.selectedNote)
        viewModel.addNote(title: "Segunda")
        let second = try XCTUnwrap(viewModel.selectedNote)
        let id = second.objectID
        for title in ["N", "No", "Novo"] {
            viewModel.editTitle(of: second, to: title)
            XCTAssertEqual(second.suggestedPDFName, title + ".pdf")
            XCTAssertEqual(second.committedValues(forKeys: ["title"])["title"] as? String, "Segunda")
        }
        viewModel.selectedNote = first
        XCTAssertFalse(viewModel.hasPendingTitle)
        XCTAssertEqual(first.title, "Primeira")
        inMemoryContext.reset()
        XCTAssertEqual((try inMemoryContext.existingObject(with: id) as? Note)?.title, "Novo")
    }

    func testRenameEmptyTitleAndUnchangedTitle() throws {
        viewModel.addNote(title: "Título")
        let note = try XCTUnwrap(viewModel.selectedNote)
        try viewModel.renameNote(note, to: "")
        let date = note.updatedAt
        try viewModel.renameNote(note, to: "")
        XCTAssertEqual(note.title, "")
        XCTAssertEqual(note.suggestedPDFName, "Sem título.pdf")
        XCTAssertEqual(note.updatedAt, date)
    }
}
