import Foundation
import CoreData
import Combine
import SwiftUI
import PDFKit

public enum FilterType: Hashable {
    case all
    case uncategorized
    case notebook(Notebook)
    case trash
}


enum PDFExportError: Error, Equatable {
    case documentUnavailable
    case contextCreationFailed
}

public enum SortOption: String, CaseIterable, Identifiable {
    case dateModifiedDescending = "Date modified (recent first)"
    case dateModifiedAscending = "Date modified (oldest first)"
    case dateCreatedDescending = "Date created (recent first)"
    case dateCreatedAscending = "Date created (oldest first)"
    case titleAscending = "Title (A-Z)"
    case titleDescending = "Title (Z-A)"
    
    public var id: String { self.rawValue }
    
    public var localizedName: String {
        switch self {
        case .dateModifiedDescending, .dateModifiedAscending:
            return "Date modified"
        case .dateCreatedDescending, .dateCreatedAscending:
            return "Date created"
        case .titleAscending, .titleDescending:
            return "Title"
        }
    }
    
    public var isAscending: Bool {
        switch self {
        case .dateModifiedAscending, .dateCreatedAscending, .titleAscending:
            return true
        default:
            return false
        }
    }
}

public class NoteViewModel: ObservableObject {
    private let context: NSManagedObjectContext
    private let pdfDelegate = AnnotatedPDFDelegate()
    private var cachedPDFDocument: PDFDocument? = nil
    private var cachedPDFDocumentNoteId: UUID? = nil
    
    @Published public var notebooks: [Notebook] = []
    @Published public var notes: [Note] = [] // Loaded notes based on the active filter
    
    @Published public var selectedFilter: FilterType = .all {
        didSet {
            loadNotes()
        }
    }
    
    @Published public var selectedNote: Note? = nil
    @Published public var searchQuery: String = "" {
        didSet {
            loadNotes()
        }
    }
    
    @Published public var sortOption: SortOption = .dateModifiedDescending {
        didSet {
            loadNotes()
        }
    }
    
    // Backward compatibility helper
    public var selectedNotebook: Notebook? {
        if case .notebook(let notebook) = selectedFilter {
            return notebook
        }
        return nil
    }
    
    public init(context: NSManagedObjectContext) {
        self.context = context
        loadNotebooks()
        loadNotes()
        
        // Setup initial data if database is empty
        if notebooks.isEmpty && countAllNotes() == 0 {
            createSampleData()
        }
    }
    
    // MARK: - Fetching Data
    public func loadNotebooks() {
        let request = NSFetchRequest<Notebook>(entityName: "Notebook")
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Notebook.name, ascending: true)]
        do {
            self.notebooks = try context.fetch(request)
        } catch {
            print("Failed to fetch notebooks: \(error)")
        }
    }
    
    public func loadNotes() {
        let request = NSFetchRequest<Note>(entityName: "Note")
        
        let sortDescriptor: NSSortDescriptor
        switch sortOption {
        case .dateModifiedDescending:
            sortDescriptor = NSSortDescriptor(keyPath: \Note.updatedAt, ascending: false)
        case .dateModifiedAscending:
            sortDescriptor = NSSortDescriptor(keyPath: \Note.updatedAt, ascending: true)
        case .dateCreatedDescending:
            sortDescriptor = NSSortDescriptor(keyPath: \Note.createdAt, ascending: false)
        case .dateCreatedAscending:
            sortDescriptor = NSSortDescriptor(keyPath: \Note.createdAt, ascending: true)
        case .titleAscending:
            sortDescriptor = NSSortDescriptor(keyPath: \Note.title, ascending: true)
        case .titleDescending:
            sortDescriptor = NSSortDescriptor(keyPath: \Note.title, ascending: false)
        }
        request.sortDescriptors = [sortDescriptor]
        
        var predicates: [NSPredicate] = []
        
        // Apply FilterType
        switch selectedFilter {
        case .all:
            predicates.append(NSPredicate(format: "isTrashed == false"))
        case .uncategorized:
            predicates.append(NSPredicate(format: "notebook == nil AND isTrashed == false"))
        case .notebook(let notebook):
            predicates.append(NSPredicate(format: "notebook == %@ AND isTrashed == false", notebook))
        case .trash:
            predicates.append(NSPredicate(format: "isTrashed == true"))
        }
        
        // Apply Search Query
        if !searchQuery.isEmpty {
            predicates.append(NSPredicate(format: "title CONTAINS[cd] %@ OR content CONTAINS[cd] %@", searchQuery, searchQuery))
        }
        
        if !predicates.isEmpty {
            request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
        }
        
        do {
            self.notes = try context.fetch(request)
        } catch {
            print("Failed to fetch notes: \(error)")
        }
    }
    
    // MARK: - Database Size/Count Helpers
    public func countAllNotes() -> Int {
        let request = NSFetchRequest<NSNumber>(entityName: "Note")
        request.resultType = .countResultType
        request.predicate = NSPredicate(format: "isTrashed == false")
        do {
            let countResult = try context.fetch(request)
            return countResult.first?.intValue ?? 0
        } catch {
            print("Failed to count notes: \(error)")
            return 0
        }
    }
    
    public func countUncategorizedNotes() -> Int {
        let request = NSFetchRequest<NSNumber>(entityName: "Note")
        request.resultType = .countResultType
        request.predicate = NSPredicate(format: "notebook == nil AND isTrashed == false")
        do {
            let countResult = try context.fetch(request)
            return countResult.first?.intValue ?? 0
        } catch {
            print("Failed to count notes: \(error)")
            return 0
        }
    }
    
    public func countTrashedNotes() -> Int {
        let request = NSFetchRequest<NSNumber>(entityName: "Note")
        request.resultType = .countResultType
        request.predicate = NSPredicate(format: "isTrashed == true")
        do {
            let countResult = try context.fetch(request)
            return countResult.first?.intValue ?? 0
        } catch {
            print("Failed to count notes: \(error)")
            return 0
        }
    }
    
    // MARK: - Notebook CRUD
    public func addNotebook(name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        
        let notebook = Notebook(context: context)
        notebook.id = UUID()
        notebook.name = trimmed
        
        save()
        loadNotebooks()
        selectedFilter = .notebook(notebook)
    }
    
    public func renameNotebook(_ notebook: Notebook, to newName: String) {
        let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        
        notebook.name = trimmed
        save()
        loadNotebooks()
    }
    
    // Smart Notebook Delete
    public func deleteNotebook(_ notebook: Notebook, keepNotes: Bool = false) {
        // If deleting the currently selected notebook, fall back to "All Notes"
        if case .notebook(let current) = selectedFilter, current == notebook {
            selectedFilter = .all
        }
        
        let notebookNotes = notebook.notes as? Set<Note> ?? []
        for note in notebookNotes {
            if keepNotes {
                note.notebook = nil
            } else {
                note.isTrashed = true
            }
        }
        
        context.delete(notebook)
        save()
        loadNotebooks()
        loadNotes()
    }
    
    public func addNote(title: String = "Nova Nota", content: String = "") {
        // Prevent note creation when in Trash view
        if selectedFilter == .trash {
            selectedFilter = .all
        }
        
        let note = Note(context: context)
        note.id = UUID()
        note.title = title
        note.content = content
        note.createdAt = Date()
        note.updatedAt = Date()
        note.isTrashed = false
        note.pdfData = createBlankPDF(pageCount: 1)
        note.pageCount = 1
        
        // Associate with notebook if active filter is notebook
        if case .notebook(let notebook) = selectedFilter {
            note.notebook = notebook
        } else {
            note.notebook = nil
        }
        
        save()
        loadNotes()
        selectedNote = note
    }
    
    public func deleteNote(_ note: Note) {
        if note.isTrashed {
            // Delete DEFINITELY from database
            if selectedNote == note {
                selectedNote = nil
            }
            context.delete(note)
        } else {
            // Move to Trash
            if selectedNote == note {
                selectedNote = nil
            }
            note.isTrashed = true
        }
        save()
        loadNotes()
        loadNotebooks()
    }
    
    public func restoreNote(_ note: Note) {
        note.isTrashed = false
        note.updatedAt = Date()
        save()
        loadNotes()
        loadNotebooks()
    }
    
    // MARK: - PDF Import & Page Management
    public func importPDF(url: URL, title: String? = nil) {
        guard let data = try? Data(contentsOf: url) else {
            print("Failed to read PDF data from \(url)")
            return
        }
        
        if selectedFilter == .trash {
            selectedFilter = .all
        }
        
        let note = Note(context: context)
        note.id = UUID()
        note.title = title ?? url.deletingPathExtension().lastPathComponent
        note.content = ""
        note.createdAt = Date()
        note.updatedAt = Date()
        note.isTrashed = false
        note.pdfData = data
        
        if let pdfDoc = PDFDocument(data: data) {
            note.pageCount = Int16(pdfDoc.pageCount)
        } else {
            note.pageCount = 1
        }
        
        if case .notebook(let notebook) = selectedFilter {
            note.notebook = notebook
        } else {
            note.notebook = nil
        }
        
        cachedPDFDocument = nil
        cachedPDFDocumentNoteId = nil
        
        save()
        loadNotes()
        selectedNote = note
    }
    
    public func addBlankPage() {
        guard let note = selectedNote else { return }
        
        cachedPDFDocument = nil
        cachedPDFDocumentNoteId = nil
        
        let pdfDoc: PDFDocument
        if let data = note.pdfData {
            pdfDoc = PDFDocument(data: data) ?? PDFDocument()
        } else {
            pdfDoc = PDFDocument(data: createBlankPDF(pageCount: Int(max(1, note.pageCount)))) ?? PDFDocument()
        }
        pdfDoc.delegate = pdfDelegate
        
        let blankPage = AnnotatedPDFPage()
        blankPage.note = note
        let size = pdfDoc.pageCount > 0 ? (pdfDoc.page(at: 0)?.bounds(for: .mediaBox).size ?? CGSize(width: 612, height: 792)) : CGSize(width: 612, height: 792)
        blankPage.setBounds(CGRect(origin: .zero, size: size), for: .mediaBox)
        pdfDoc.insert(blankPage, at: pdfDoc.pageCount)
        
        note.pdfData = pdfDoc.dataRepresentation()
        note.pageCount = Int16(pdfDoc.pageCount)
        note.updatedAt = Date()
        
        save()
        loadNotes()
        objectWillChange.send()
    }
    
    // MARK: - PDF Drawing and Document Helpers
    public func createBlankPDF(pageCount: Int) -> Data {
        let pdfData = NSMutableData()
        guard let consumer = CGDataConsumer(data: pdfData as CFMutableData),
              let context = CGContext(consumer: consumer, mediaBox: nil, nil) else {
            return Data()
        }
        
        var mediaBox = CGRect(x: 0, y: 0, width: 612, height: 792) // Letter size
        
        for _ in 0..<pageCount {
            context.beginPage(mediaBox: &mediaBox)
            context.setFillColor(CGColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 1.0))
            context.fill(mediaBox)
            context.endPage()
        }
        
        context.closePDF()
        return pdfData as Data
    }
    
    public func getPDFDocument(for note: Note) -> PDFDocument? {
        if let cached = cachedPDFDocument, cachedPDFDocumentNoteId == note.id {
            return cached
        }
        
        let doc: PDFDocument
        if let data = note.pdfData {
            doc = PDFDocument(data: data) ?? PDFDocument()
        } else {
            let blankData = createBlankPDF(pageCount: Int(max(1, note.pageCount)))
            doc = PDFDocument(data: blankData) ?? PDFDocument()
        }
        doc.delegate = pdfDelegate
        for pageIndex in 0..<doc.pageCount {
            (doc.page(at: pageIndex) as? AnnotatedPDFPage)?.note = note
        }

        cachedPDFDocument = doc
        cachedPDFDocumentNoteId = note.id
        return doc
    }

    // MARK: - PDF Export
    public func exportPDF(for note: Note, to url: URL) throws {
        guard let sourceDoc = getPDFDocument(for: note), sourceDoc.pageCount > 0 else {
            throw PDFExportError.documentUnavailable
        }

        let outputData = NSMutableData()
        guard let consumer = CGDataConsumer(data: outputData as CFMutableData),
              let context = CGContext(consumer: consumer, mediaBox: nil, nil) else {
            throw PDFExportError.contextCreationFailed
        }

        for pageIndex in 0..<sourceDoc.pageCount {
            guard let page = sourceDoc.page(at: pageIndex) else { continue }
            var mediaBox = page.bounds(for: .mediaBox)
            context.beginPage(mediaBox: &mediaBox)
            page.draw(with: .mediaBox, to: context)
            renderGrid(for: note, in: mediaBox, into: context)
            renderShapes(for: note, pageIndex: pageIndex, into: context)
            renderStrokes(for: note, pageIndex: pageIndex, into: context)
            context.endPage()
        }
        context.closePDF()

        try (outputData as Data).write(to: url, options: .atomic)
    }
    
    public func emptyTrash() {
        let request = NSFetchRequest<Note>(entityName: "Note")
        request.predicate = NSPredicate(format: "isTrashed == true")
        do {
            let trashedNotes = try context.fetch(request)
            for note in trashedNotes {
                context.delete(note)
            }
            save()
            loadNotes()
        } catch {
            print("Failed to empty trash: \(error)")
        }
    }
    
    /// Sets the cartesian grid style for a note. When enabling a real grid for
    /// the first time, centers the plane origin on the first page so the axes
    /// land in a natural place.
    public func setGridStyle(_ style: GridStyle, for note: Note) {
        note.gridStyle = style.rawValue
        if style != .none, note.gridOriginX == 0, note.gridOriginY == 0,
           let doc = getPDFDocument(for: note), let page = doc.page(at: 0) {
            let b = page.bounds(for: .mediaBox)
            note.gridOriginX = Float(b.midX)
            note.gridOriginY = Float(b.midY)
        }
        save()
        loadNotes()
    }

    /// Number of undoable drawing objects (strokes + shapes) on a note.
    public func drawnObjectCount(for note: Note?) -> Int {
        guard let note = note else { return 0 }
        let strokes = note.strokes as? Set<Stroke> ?? []
        let shapes = note.shapes as? Set<ShapeObject> ?? []
        return strokes.count + shapes.count
    }

    /// Removes the most recently created drawing object, whether it is a
    /// freehand stroke or a geometric shape.
    public func undoLastObject() {
        guard let note = selectedNote else { return }
        let latestStroke = (note.strokes as? Set<Stroke> ?? [])
            .max(by: { $0.createdAt < $1.createdAt })
        let latestShape = (note.shapes as? Set<ShapeObject> ?? [])
            .max(by: { $0.createdAt < $1.createdAt })

        let target: NSManagedObject?
        switch (latestStroke, latestShape) {
        case let (s?, sh?): target = s.createdAt >= sh.createdAt ? s : sh
        case let (s?, nil): target = s
        case let (nil, sh?): target = sh
        default: target = nil
        }

        if let target = target {
            context.delete(target)
            save()
            loadNotes()
        }
    }
    
    public func moveNote(_ note: Note, to notebook: Notebook?) {
        note.notebook = notebook
        // Restore if it was trashed
        if note.isTrashed {
            note.isTrashed = false
        }
        note.updatedAt = Date()
        save()
        loadNotes()
        loadNotebooks()
    }
    
    public func moveNote(id: UUID, to notebook: Notebook?) {
        let request = NSFetchRequest<Note>(entityName: "Note")
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        do {
            if let note = try context.fetch(request).first {
                moveNote(note, to: notebook)
            }
        } catch {
            print("Failed to find note to move: \(error)")
        }
    }
    
    public func trashNote(id: UUID) {
        let request = NSFetchRequest<Note>(entityName: "Note")
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        do {
            if let note = try context.fetch(request).first {
                deleteNote(note)
            }
        } catch {
            print("Failed to find note to trash: \(error)")
        }
    }
    
    public func renameNote(_ note: Note, to title: String) throws {
        guard note.managedObjectContext === context, !note.isDeleted else {
            throw CocoaError(.managedObjectReferentialIntegrity)
        }
        guard note.title != title else { return }

        let previousTitle = note.title
        let previousDate = note.updatedAt
        note.title = title
        note.updatedAt = Date()
        do {
            try context.save()
        } catch {
            note.title = previousTitle
            note.updatedAt = previousDate
            throw error
        }
        loadNotes()
    }

    public func updateNoteContent(note: Note, title: String, content: String) {
        if note.title != title || note.content != content {
            note.title = title
            note.content = content
            note.updatedAt = Date()
            save()
            loadNotes()
        }
    }
    
    public func save() {
        if context.hasChanges {
            do {
                try context.save()
            } catch {
                print("Core Data Save Error: \(error)")
            }
        }
    }
    
    // MARK: - Onboarding sample data
    private func createSampleData() {
        let personal = Notebook(context: context)
        personal.id = UUID()
        personal.name = "Pessoal 🏠"
        
        let work = Notebook(context: context)
        work.id = UUID()
        work.name = "Trabalho 💼"
        
        let ideas = Notebook(context: context)
        ideas.id = UUID()
        ideas.name = "Ideias Criativas 💡"
        
        let note1 = Note(context: context)
        note1.id = UUID()
        note1.title = "Lista de Compras"
        note1.content = "- Maçãs 🍎\n- Leite de aveia 🥛\n- Pão integral 🍞\n- Café especial ☕️"
        note1.createdAt = Date().addingTimeInterval(-86400 * 2)
        note1.updatedAt = Date().addingTimeInterval(-86400 * 2)
        note1.notebook = personal
        note1.isTrashed = false
        note1.pdfData = createBlankPDF(pageCount: 1)
        note1.pageCount = 1
        
        let note2 = Note(context: context)
        note2.id = UUID()
        note2.title = "Reunião de Alinhamento"
        note2.content = "Pautas:\n1. Revisão do cronograma do projeto\n2. Aprovação do layout da sidebar\n3. Definição do sistema de desenho livre e Core Data stack programático."
        note2.createdAt = Date().addingTimeInterval(-3600 * 4)
        note2.updatedAt = Date().addingTimeInterval(-3600 * 4)
        note2.notebook = work
        note2.isTrashed = false
        note2.pdfData = createBlankPDF(pageCount: 1)
        note2.pageCount = 1
        
        let note3 = Note(context: context)
        note3.id = UUID()
        note3.title = "Easy Notes App"
        note3.content = "Este aplicativo de notas possui um editor de texto super fluido e uma tela de desenho livre com vetorização de caminhos Bézier em tempo real. Tudo persistido de forma robusta e limpa no Core Data!"
        note3.createdAt = Date()
        note3.updatedAt = Date()
        note3.notebook = ideas
        note3.isTrashed = false
        note3.pdfData = createBlankPDF(pageCount: 1)
        note3.pageCount = 1
        
        let noteTrashed = Note(context: context)
        noteTrashed.id = UUID()
        noteTrashed.title = "Nota Antiga Descartada"
        noteTrashed.content = "Esta nota foi enviada para a lixeira. Você pode restaurá-la ou excluí-la permanentemente clicando com o botão direito nela na Lixeira."
        noteTrashed.createdAt = Date().addingTimeInterval(-86400 * 5)
        noteTrashed.updatedAt = Date().addingTimeInterval(-86400 * 5)
        noteTrashed.notebook = nil
        noteTrashed.isTrashed = true
        noteTrashed.pdfData = createBlankPDF(pageCount: 1)
        noteTrashed.pageCount = 1
        
        save()
        loadNotebooks()
        loadNotes()
        
        selectedFilter = .all
        selectedNote = note3
    }
}
