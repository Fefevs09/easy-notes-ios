import Foundation
import CoreData
import Combine
import SwiftUI
import PDFKit
import UniformTypeIdentifiers

public enum FilterType: Hashable {
    case all
    case uncategorized
    case notebook(Notebook)
    case trash
}


public enum NoteOrientation: String, CaseIterable {
    case portrait = "Vertical"
    case landscape = "Horizontal"

    var pageCenter: CGPoint { CGPoint(x: pageSize.width / 2, y: pageSize.height / 2) }

    var pageSize: CGSize {
        switch self {
        case .portrait: CGSize(width: 612, height: 792)
        case .landscape: CGSize(width: 792, height: 612)
        }
    }
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
    private var cachedPDFDocument: PDFDocument? = nil
    private var cachedPDFDocumentNoteId: UUID? = nil
    public let coverCache: NoteCoverCache
    
    @Published public var notebooks: [Notebook] = []
    @Published public var notes: [Note] = [] // Loaded notes based on the active filter
    
    @Published public var selectedFilter: FilterType = .all {
        didSet {
            loadNotes()
        }
    }
    
    private var pendingTitleSave: DispatchWorkItem?
    @Published private(set) var hasPendingTitle = false
    @Published var titleSaveError: String?

    @Published public var selectedNote: Note? = nil {
        didSet {
            if oldValue !== selectedNote { flushTitleEdits() }
        }
    }
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
    
    public init(context: NSManagedObjectContext, coverCache: NoteCoverCache = .shared) {
        self.context = context
        self.coverCache = coverCache
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
    public func addNotebook(name: String, parent: Notebook? = nil) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        
        let notebook = Notebook(context: context)
        notebook.id = UUID()
        notebook.parent = parent
        notebook.colorIndex = NSNumber(value: PixelTheme.defaultNotebookIndex(trimmed))
        notebook.name = trimmed
        
        save()
        loadNotebooks()
        selectedFilter = .notebook(notebook)
    }
    
    public func editTitle(of note: Note, to title: String) {
        guard note.managedObjectContext === context, !note.isDeleted, note.title != title else { return }
        note.title = title
        note.updatedAt = Date()
        hasPendingTitle = true
        pendingTitleSave?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.flushTitleEdits() }
        pendingTitleSave = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: work)
    }

    public func flushTitleEdits() {
        guard hasPendingTitle else { return }
        pendingTitleSave?.cancel()
        pendingTitleSave = nil
        do {
            if context.hasChanges { try context.save() }
            hasPendingTitle = false
            loadNotes()
        } catch {
            titleSaveError = error.localizedDescription
        }
    }

    public func renameNotebook(_ notebook: Notebook, to newName: String, colorIndex: Int? = nil, color: Color? = nil) {
        let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        
        if let color {
            let hex = PenColorComponents.from(color).hex6
            if hex != PenColorComponents.from(PixelTheme.notebookColor(for: notebook)).hex6 {
                notebook.colorHex = hex
            }
        } else if colorIndex != nil {
            notebook.colorHex = nil
        }
        notebook.colorIndex = NSNumber(value: colorIndex ?? notebook.swatchIndex)
        notebook.name = trimmed
        save()
        loadNotebooks()
    }
    
    // Smart Notebook Delete
    public func deleteNotebook(_ notebook: Notebook, keepNotes: Bool = true) {
        // If deleting the currently selected notebook, fall back to "All Notes"
        if case .notebook(let current) = selectedFilter, current == notebook {
            selectedFilter = .all
        }
        
        let notebookNotes = notebook.notes as? Set<Note> ?? []
        for note in notebookNotes {
            note.notebook = nil
            if !keepNotes {
                note.isTrashed = true
            }
        }
        
        for child in notebook.children ?? [] { child.parent = notebook.parent }
        context.delete(notebook)
        save()
        loadNotebooks()
        loadNotes()
    }
    
    public func addNote(title: String = "Nova Nota", content: String = "",
                        paper: GridStyle = .none, orientation: NoteOrientation = .portrait) {
        do {
            try addNote(title: title, content: content, paper: paper, orientation: orientation,
                        template: .blank, month: 1, year: nil, locale: .current)
        } catch {
            print("Note Creation Error: \(error)")
        }
    }

    func addNote(title: String, content: String = "", paper: GridStyle, orientation: NoteOrientation,
                 template: NoteTemplate, month: Int, year: Int?, locale: Locale) throws {
        let pdf = try NoteTemplatePDF.make(template, month: month, year: year,
                                           orientation: orientation, locale: locale)
        let note = Note(context: context)
        note.id = UUID()
        note.title = title
        note.content = content
        note.createdAt = Date()
        note.updatedAt = Date()
        note.isTrashed = false
        note.gridStyle = paper.rawValue
        if paper != .none {
            note.gridOriginX = Float(orientation.pageCenter.x)
            note.gridOriginY = Float(orientation.pageCenter.y)
        }
        note.pdfData = pdf.data
        note.pageCount = 1
        
        // Associate with notebook if active filter is notebook
        if case .notebook(let notebook) = selectedFilter {
            note.notebook = notebook
        } else {
            note.notebook = nil
        }
        
        do {
            try context.save()
        } catch {
            // Remove only this insertion, leaving other pending edits intact.
            context.delete(note)
            throw error
        }

        if selectedFilter == .trash {
            selectedFilter = .all
        } else {
            loadNotes()
        }
        selectedNote = note
    }
    
    public func deleteNote(_ note: Note) {
        var deletedNoteID: UUID?
        if note.isTrashed {
            // Delete DEFINITELY from database
            if selectedNote == note {
                selectedNote = nil
            }
            deletedNoteID = note.id
            context.delete(note)
        } else {
            // Move to Trash
            if selectedNote == note {
                selectedNote = nil
            }
            note.isTrashed = true
        }
        save()
        if let deletedNoteID {
            coverCache.invalidate(noteID: deletedNoteID)
        }
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
        let size = pdfDoc.page(at: 0)?.bounds(for: .mediaBox).size ?? NoteOrientation.portrait.pageSize
        guard let blankPage = PDFDocument(data: createBlankPDF(pageCount: 1, size: size))?.page(at: 0) else { return }
        pdfDoc.insert(blankPage, at: pdfDoc.pageCount)
        
        note.pdfData = pdfDoc.dataRepresentation()
        note.pageCount = Int16(pdfDoc.pageCount)
        note.updatedAt = Date()
        
        save()
        coverCache.invalidate(noteID: note.id)
        loadNotes()
        objectWillChange.send()
    }
    
    // MARK: - PDF Drawing and Document Helpers
    public func createBlankPDF(pageCount: Int) -> Data {
        createBlankPDF(pageCount: pageCount, size: NoteOrientation.portrait.pageSize)
    }

    private func createBlankPDF(pageCount: Int, size: CGSize) -> Data {
        let pdfData = NSMutableData()
        guard let consumer = CGDataConsumer(data: pdfData as CFMutableData),
              let context = CGContext(consumer: consumer, mediaBox: nil, nil) else {
            return Data()
        }
        
        var mediaBox = CGRect(origin: .zero, size: size)
        
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

        cachedPDFDocument = doc
        cachedPDFDocumentNoteId = note.id
        return doc
    }

    // MARK: - PDF Export
    public func exportPDF(for note: Note, to url: URL) throws {
        try exportPDF(for: note, to: url, options: .default)
    }

    public func exportPDF(for note: Note, to url: URL, options: PDFExportOptions) throws {
        // Start from the stored pages so the editor's drawing delegate cannot
        // paint the paper and annotations a second time during export.
        let data = note.pdfData ?? createBlankPDF(pageCount: Int(max(1, note.pageCount)))
        guard let sourceDoc = PDFDocument(data: data), sourceDoc.pageCount > 0 else {
            throw PDFExportError.documentUnavailable
        }

        let pagesToExport: [Int]
        if let range = options.pageRange {
            let validatedRange = try PDFExportOptions.validate(range: range, pageCount: sourceDoc.pageCount)
            pagesToExport = Array(validatedRange)
        } else {
            pagesToExport = Array(0..<sourceDoc.pageCount)
        }

        let outputData = NSMutableData()
        guard let consumer = CGDataConsumer(data: outputData as CFMutableData),
              let context = CGContext(consumer: consumer, mediaBox: nil, nil) else {
            throw PDFExportError.contextCreationFailed
        }

        for pageIndex in pagesToExport {
            guard let page = sourceDoc.page(at: pageIndex) else { continue }
            var mediaBox = page.bounds(for: .mediaBox)
            context.beginPage(mediaBox: &mediaBox)
            page.draw(with: .mediaBox, to: context)
            if options.includeGrid {
                renderGrid(for: note, in: mediaBox, into: context)
            }
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
            let deletedIDs = trashedNotes.map(\.id)
            for note in trashedNotes {
                context.delete(note)
            }
            save()
            for id in deletedIDs {
                coverCache.invalidate(noteID: id)
            }
            loadNotes()
        } catch {
            print("Failed to empty trash: \(error)")
        }
    }
    
    func setGridColor(_ color: NSColor, for note: Note) {
        let hex = PenColorComponents.from(Color(nsColor: color)).hex6
        guard hex != note.gridColorHex else { return }
        note.gridColorHex = hex
        note.updatedAt = Date()
        save()
        loadNotes()
    }

    /// Sets the cartesian grid style for a note. When enabling a real grid for
    /// the first time, phase-aligns its pattern to the center of the first page.
    public func setGridStyle(_ style: GridStyle, for note: Note) {
        note.gridStyle = style.rawValue
        note.updatedAt = Date()
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

    // MARK: - Note Emoji (FEAT-02 Contract)

    public static func normalizedEmoji(_ raw: String?) -> String? {
        guard let trimmed = raw?.trimmingCharacters(in: .whitespacesAndNewlines),
              !trimmed.isEmpty,
              let firstCharacter = trimmed.first else {
            return nil
        }
        return String(firstCharacter)
    }

    public func setEmoji(_ emoji: String?, for note: Note) throws {
        guard note.managedObjectContext === context, !note.isDeleted else {
            throw CocoaError(.managedObjectReferentialIntegrity)
        }

        let normalized = Self.normalizedEmoji(emoji)
        guard note.emoji != normalized else { return }

        let previousEmoji = note.emoji
        let previousUpdatedAt = note.updatedAt

        let now = Date()
        note.emoji = normalized
        note.updatedAt = max(now, previousUpdatedAt.addingTimeInterval(0.001))

        do {
            try context.save()
        } catch {
            note.emoji = previousEmoji
            note.updatedAt = previousUpdatedAt
            throw error
        }

        loadNotes()
    }

    // MARK: - Note Covers (FEAT-03 / FEAT-02 Contract)

    public func setCover(for note: Note, from url: URL) throws {
        guard note.managedObjectContext === context, !note.isDeleted else {
            throw NoteCoverError.invalidNote
        }

        let hasScopedAccess = url.startAccessingSecurityScopedResource()
        defer {
            if hasScopedAccess {
                url.stopAccessingSecurityScopedResource()
            }
        }

        let hintedType = Self.resolvedContentType(for: url)
        let genericTypes: Set<UTType> = [.data, .item, .content]
        if let hintedType, !genericTypes.contains(hintedType), !hintedType.conforms(to: .image) {
            throw NoteCoverError.unsupportedMediaType(hintedType.identifier)
        }

        let data: Data
        do {
            data = try Data(contentsOf: url)
        } catch {
            throw NoteCoverError.unreadableImage
        }

        try setCover(for: note, data: data, contentType: hintedType)
    }

    public func setCover(for note: Note, data: Data, contentType: UTType? = nil) throws {
        guard note.managedObjectContext === context, !note.isDeleted else {
            throw NoteCoverError.invalidNote
        }

        let media = try NoteCoverMedia.validated(data: data, contentType: contentType)

        let previousData = note.coverMediaData
        let previousType = note.coverMediaType
        let previousCoverUpdatedAt = note.coverUpdatedAt
        let previousUpdatedAt = note.updatedAt

        let now = Date()
        let coverTimestamp: Date
        if let previousCoverUpdatedAt {
            coverTimestamp = max(now, previousCoverUpdatedAt.addingTimeInterval(0.001))
        } else {
            coverTimestamp = now
        }

        note.coverMediaData = media.data
        note.coverMediaType = media.contentTypeIdentifier
        note.coverUpdatedAt = coverTimestamp
        note.updatedAt = max(now, previousUpdatedAt.addingTimeInterval(0.001))

        do {
            try context.save()
        } catch {
            note.coverMediaData = previousData
            note.coverMediaType = previousType
            note.coverUpdatedAt = previousCoverUpdatedAt
            note.updatedAt = previousUpdatedAt
            throw NoteCoverError.persistenceFailed(error.localizedDescription)
        }

        coverCache.invalidate(noteID: note.id)
        loadNotes()
    }

    public func removeCover(for note: Note) throws {
        guard note.managedObjectContext === context, !note.isDeleted else {
            throw NoteCoverError.invalidNote
        }

        guard note.coverMediaData != nil || note.coverMediaType != nil || note.coverUpdatedAt != nil else {
            coverCache.invalidate(noteID: note.id)
            return
        }

        let previousData = note.coverMediaData
        let previousType = note.coverMediaType
        let previousCoverUpdatedAt = note.coverUpdatedAt
        let previousUpdatedAt = note.updatedAt

        let now = Date()
        note.coverMediaData = nil
        note.coverMediaType = nil
        note.coverUpdatedAt = nil
        note.updatedAt = max(now, previousUpdatedAt.addingTimeInterval(0.001))

        do {
            try context.save()
        } catch {
            note.coverMediaData = previousData
            note.coverMediaType = previousType
            note.coverUpdatedAt = previousCoverUpdatedAt
            note.updatedAt = previousUpdatedAt
            throw NoteCoverError.persistenceFailed(error.localizedDescription)
        }

        coverCache.invalidate(noteID: note.id)
        loadNotes()
    }

    private static func resolvedContentType(for url: URL) -> UTType? {
        let genericTypes: Set<UTType> = [.data, .item, .content]
        if !url.pathExtension.isEmpty,
           let extType = UTType(filenameExtension: url.pathExtension),
           !genericTypes.contains(extType) {
            return extType
        }
        if let resourceType = try? url.resourceValues(forKeys: [.contentTypeKey]).contentType,
           !genericTypes.contains(resourceType) {
            return resourceType
        }
        return nil
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
