import XCTest
import CoreData
import PDFKit

class NoteViewModelTests: XCTestCase {
    var inMemoryContext: NSManagedObjectContext!
    var viewModel: NoteViewModel!
    
    override func setUp() {
        super.setUp()
        
        // Setup in-memory NSPersistentContainer using the same programmatic model from CoreDataStack
        let model = NSManagedObjectModel()
        
        // Entity definitions matching CoreDataStack.swift exactly
        let notebookEntity = NSEntityDescription()
        notebookEntity.name = "Notebook"
        notebookEntity.managedObjectClassName = "Notebook"
        
        let notebookIdAttribute = NSAttributeDescription()
        notebookIdAttribute.name = "id"
        notebookIdAttribute.attributeType = .UUIDAttributeType
        notebookIdAttribute.isOptional = false
        
        let notebookNameAttribute = NSAttributeDescription()
        notebookNameAttribute.name = "name"
        notebookNameAttribute.attributeType = .stringAttributeType
        notebookNameAttribute.isOptional = false
        notebookEntity.properties = [notebookIdAttribute, notebookNameAttribute]
        
        let noteEntity = NSEntityDescription()
        noteEntity.name = "Note"
        noteEntity.managedObjectClassName = "Note"
        
        let noteIdAttribute = NSAttributeDescription()
        noteIdAttribute.name = "id"
        noteIdAttribute.attributeType = .UUIDAttributeType
        noteIdAttribute.isOptional = false
        
        let noteTitleAttribute = NSAttributeDescription()
        noteTitleAttribute.name = "title"
        noteTitleAttribute.attributeType = .stringAttributeType
        noteTitleAttribute.isOptional = false
        
        let noteContentAttribute = NSAttributeDescription()
        noteContentAttribute.name = "content"
        noteContentAttribute.attributeType = .stringAttributeType
        noteContentAttribute.isOptional = false
        
        let noteCreatedAtAttribute = NSAttributeDescription()
        noteCreatedAtAttribute.name = "createdAt"
        noteCreatedAtAttribute.attributeType = .dateAttributeType
        noteCreatedAtAttribute.isOptional = false
        
        let noteUpdatedAtAttribute = NSAttributeDescription()
        noteUpdatedAtAttribute.name = "updatedAt"
        noteUpdatedAtAttribute.attributeType = .dateAttributeType
        noteUpdatedAtAttribute.isOptional = false
        
        let noteIsTrashedAttribute = NSAttributeDescription()
        noteIsTrashedAttribute.name = "isTrashed"
        noteIsTrashedAttribute.attributeType = .booleanAttributeType
        noteIsTrashedAttribute.isOptional = false
        noteIsTrashedAttribute.defaultValue = false
        
        let notePdfDataAttribute = NSAttributeDescription()
        notePdfDataAttribute.name = "pdfData"
        notePdfDataAttribute.attributeType = .binaryDataAttributeType
        notePdfDataAttribute.isOptional = true
        
        let notePageCountAttribute = NSAttributeDescription()
        notePageCountAttribute.name = "pageCount"
        notePageCountAttribute.attributeType = .integer16AttributeType
        notePageCountAttribute.isOptional = false
        notePageCountAttribute.defaultValue = 1
        
        noteEntity.properties = [
            noteIdAttribute,
            noteTitleAttribute,
            noteContentAttribute,
            noteCreatedAtAttribute,
            noteUpdatedAtAttribute,
            noteIsTrashedAttribute,
            notePdfDataAttribute,
            notePageCountAttribute
        ]
        
        let strokeEntity = NSEntityDescription()
        strokeEntity.name = "Stroke"
        strokeEntity.managedObjectClassName = "Stroke"
        
        let strokeIdAttribute = NSAttributeDescription()
        strokeIdAttribute.name = "id"
        strokeIdAttribute.attributeType = .UUIDAttributeType
        strokeIdAttribute.isOptional = false
        
        let strokePointsAttribute = NSAttributeDescription()
        strokePointsAttribute.name = "points"
        strokePointsAttribute.attributeType = .stringAttributeType
        strokePointsAttribute.isOptional = false
        
        let strokeColorAttribute = NSAttributeDescription()
        strokeColorAttribute.name = "color"
        strokeColorAttribute.attributeType = .stringAttributeType
        strokeColorAttribute.isOptional = false
        
        let strokeWidthAttribute = NSAttributeDescription()
        strokeWidthAttribute.name = "width"
        strokeWidthAttribute.attributeType = .floatAttributeType
        strokeWidthAttribute.isOptional = false
        
        let strokeCreatedAtAttribute = NSAttributeDescription()
        strokeCreatedAtAttribute.name = "createdAt"
        strokeCreatedAtAttribute.attributeType = .dateAttributeType
        strokeCreatedAtAttribute.isOptional = false
        
        let strokePageIndexAttribute = NSAttributeDescription()
        strokePageIndexAttribute.name = "pageIndex"
        strokePageIndexAttribute.attributeType = .integer16AttributeType
        strokePageIndexAttribute.isOptional = false
        strokePageIndexAttribute.defaultValue = 0
        
        strokeEntity.properties = [
            strokeIdAttribute,
            strokePointsAttribute,
            strokeColorAttribute,
            strokeWidthAttribute,
            strokeCreatedAtAttribute,
            strokePageIndexAttribute
        ]
        
        // Relationships
        let notebookToNotesRelation = NSRelationshipDescription()
        notebookToNotesRelation.name = "notes"
        notebookToNotesRelation.destinationEntity = noteEntity
        notebookToNotesRelation.minCount = 0
        notebookToNotesRelation.maxCount = 0
        notebookToNotesRelation.deleteRule = .cascadeDeleteRule
        
        let noteToNotebookRelation = NSRelationshipDescription()
        noteToNotebookRelation.name = "notebook"
        noteToNotebookRelation.destinationEntity = notebookEntity
        noteToNotebookRelation.minCount = 0
        noteToNotebookRelation.maxCount = 1
        noteToNotebookRelation.deleteRule = .nullifyDeleteRule
        
        notebookToNotesRelation.inverseRelationship = noteToNotebookRelation
        noteToNotebookRelation.inverseRelationship = notebookToNotesRelation
        
        let noteToStrokesRelation = NSRelationshipDescription()
        noteToStrokesRelation.name = "strokes"
        noteToStrokesRelation.destinationEntity = strokeEntity
        noteToStrokesRelation.minCount = 0
        noteToStrokesRelation.maxCount = 0
        noteToStrokesRelation.deleteRule = .cascadeDeleteRule
        
        let strokeToNoteRelation = NSRelationshipDescription()
        strokeToNoteRelation.name = "note"
        strokeToNoteRelation.destinationEntity = noteEntity
        strokeToNoteRelation.minCount = 0
        strokeToNoteRelation.maxCount = 1
        strokeToNoteRelation.deleteRule = .nullifyDeleteRule
        
        noteToStrokesRelation.inverseRelationship = strokeToNoteRelation
        strokeToNoteRelation.inverseRelationship = noteToStrokesRelation
        
        notebookEntity.properties.append(notebookToNotesRelation)
        noteEntity.properties.append(noteToNotebookRelation)
        noteEntity.properties.append(noteToStrokesRelation)
        strokeEntity.properties.append(strokeToNoteRelation)
        
        model.entities = [notebookEntity, noteEntity, strokeEntity]
        
        let container = NSPersistentContainer(name: "EasyNotesModelTests", managedObjectModel: model)
        let description = NSPersistentStoreDescription()
        description.type = NSInMemoryStoreType
        container.persistentStoreDescriptions = [description]
        
        container.loadPersistentStores { (storeDescription, error) in
            if let error = error {
                fatalError("Failed to load in-memory store: \(error)")
            }
        }
        
        inMemoryContext = container.viewContext
        viewModel = NoteViewModel(context: inMemoryContext)
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
}
