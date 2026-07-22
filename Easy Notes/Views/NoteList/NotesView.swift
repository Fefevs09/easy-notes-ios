import SwiftUI
import CoreData
import PDFKit
import UniformTypeIdentifiers

/// Rasterized first-page covers keyed by note id + freshness. Shared across all
/// cards so re-renders (every `loadNotes()`) reuse work instead of re-rasterizing.
private let noteCoverCache = NSCache<NSString, NSImage>()

struct NotesView: View {
    @EnvironmentObject var viewModel: NoteViewModel
    
    // Grid configuration
    private let columns = [
        GridItem(.adaptive(minimum: 150, maximum: 200), spacing: 24)
    ]
    
    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    
                    // MARK: - Sort Indicator & Options
                    HStack(spacing: 4) {
                        Menu {
                            Picker("Ordenar por", selection: $viewModel.sortOption) {
                                ForEach(SortOption.allCases) { option in
                                    Text(option.rawValue).tag(option)
                                }
                            }
                        } label: {
                            HStack(spacing: 4) {
                                Text(viewModel.sortOption.localizedName)
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .foregroundColor(.secondary)
                                
                                Image(systemName: viewModel.sortOption.isAscending ? "arrow.up" : "arrow.down")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .menuStyle(.borderlessButton)
                        
                        Spacer()
                    }
                    .padding(.horizontal, 32)
                    .padding(.top, 8)
                    
                    // MARK: - Grid of Notes
                    if viewModel.notes.isEmpty {
                        VStack(spacing: 16) {
                            Spacer()
                            Image(systemName: "doc.text.magnifyingglass")
                                .font(.system(size: 48))
                                .foregroundColor(.secondary.opacity(0.35))
                            
                            Text(emptyStateTitle())
                                .font(.title3)
                                .fontWeight(.semibold)
                                .foregroundColor(.secondary)
                            
                            Text(emptyStateSubtitle())
                                .font(.subheadline)
                                .foregroundColor(.secondary.opacity(0.7))
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 48)
                            Spacer()
                        }
                        .frame(maxWidth: .infinity, minHeight: 300)
                    } else {
                        LazyVGrid(columns: columns, spacing: 28) {
                            ForEach(viewModel.notes, id: \.self) { note in
                                Button(action: {
                                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                        viewModel.selectedNote = note
                                    }
                                }) {
                                    NoteCardView(note: note)
                                }
                                .buttonStyle(.plain)
                                .contextMenu {
                                    contextMenuContent(for: note)
                                }
                            }
                        }
                        .padding(.horizontal, 32)
                        .padding(.bottom, 80) // Leave space for FAB
                    }
                }
                .padding(.top, 16)
            }
            .background(Color(NSColor.windowBackgroundColor).opacity(0.4))
            
            // MARK: - Floating Action Button (FAB)
            if viewModel.selectedFilter != .trash {
                Button(action: {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        viewModel.addNote()
                    }
                }) {
                    Image(systemName: "pencil")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(Color(red: 0.91, green: 0.35, blue: 0.14))
                        .frame(width: 56, height: 56)
                        .background(Color.white)
                        .cornerRadius(28)
                        .shadow(color: .black.opacity(0.15), radius: 6, x: 0, y: 3)
                }
                .buttonStyle(.plain)
                .padding(24)
                .transition(.scale.combined(with: .opacity))
            }
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            // MARK: - Header & Toolbar
            VStack(spacing: 0) {
                HStack(spacing: 16) {
                    Text(headerTitle())
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    // Search Bar
                    HStack(spacing: 6) {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.secondary)
                            .font(.body)
                        
                        TextField("Search", text: $viewModel.searchQuery)
                            .textFieldStyle(.plain)
                            .font(.body)
                        
                        if !viewModel.searchQuery.isEmpty {
                            Button(action: {
                                viewModel.searchQuery = ""
                            }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.secondary)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .frame(width: 220)
                    .background(Color(NSColor.controlBackgroundColor).opacity(0.8))
                    .cornerRadius(18)
                    .shadow(color: .black.opacity(0.03), radius: 2, x: 0, y: 1)
                    
                    // Import PDF Button (Hidden in trash)
                    if viewModel.selectedFilter != .trash {
                        Button(action: {
                            importPDFFile()
                        }) {
                            HStack(spacing: 6) {
                                Image(systemName: "doc.badge.plus")
                                Text("Import PDF")
                                    .fontWeight(.medium)
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 6)
                            .background(Color(NSColor.controlBackgroundColor).opacity(0.8))
                            .cornerRadius(18)
                            .shadow(color: .black.opacity(0.03), radius: 2, x: 0, y: 1)
                        }
                        .buttonStyle(.plain)
                    }
                    
                    // Empty Trash (Only in trash filter)
                    if viewModel.selectedFilter == .trash && !viewModel.notes.isEmpty {
                        Button(action: {
                            viewModel.emptyTrash()
                        }) {
                            Text("Esvaziar Lixeira")
                                .foregroundColor(.red)
                                .fontWeight(.semibold)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 6)
                                .background(Color.red.opacity(0.08))
                                .cornerRadius(18)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 32)
                .padding(.top, 52)
                .padding(.bottom, 16)
                
                Divider()
            }
            .background(Color(NSColor.windowBackgroundColor).opacity(0.95))
        }
    }
    
    // MARK: - Header & Empty States Helpers
    private func headerTitle() -> String {
        switch viewModel.selectedFilter {
        case .all:
            return "All notes"
        case .uncategorized:
            return "Notas Soltas"
        case .notebook(let notebook):
            return notebook.name
        case .trash:
            return "Lixeira"
        }
    }
    
    private func emptyStateTitle() -> String {
        if !viewModel.searchQuery.isEmpty {
            return "Nenhum resultado encontrado"
        }
        switch viewModel.selectedFilter {
        case .all:
            return "Nenhuma nota aqui"
        case .uncategorized:
            return "Nenhuma nota solta"
        case .notebook:
            return "Caderno Vazio"
        case .trash:
            return "Lixeira Vazia"
        }
    }
    
    private func emptyStateSubtitle() -> String {
        if !viewModel.searchQuery.isEmpty {
            return "Tente buscar por termos diferentes."
        }
        switch viewModel.selectedFilter {
        case .all, .uncategorized, .notebook:
            return "Adicione uma nova nota clicando no lápis no canto inferior."
        case .trash:
            return "Notas excluídas ficarão guardadas aqui."
        }
    }
    
    private func importPDFFile() {
        let openPanel = NSOpenPanel()
        openPanel.allowedContentTypes = [.pdf]
        openPanel.allowsMultipleSelection = false
        openPanel.canChooseDirectories = false
        openPanel.canChooseFiles = true
        
        openPanel.begin { response in
            if response == .OK, let url = openPanel.url {
                viewModel.importPDF(url: url)
            }
        }
    }
    
    // MARK: - Context Menu builder
    @ViewBuilder
    private func contextMenuContent(for note: Note) -> some View {
        if viewModel.selectedFilter == .trash {
            Button("Restaurar Nota") {
                viewModel.restoreNote(note)
            }
            Divider()
            Button("Excluir Definitivamente", role: .destructive) {
                viewModel.deleteNote(note)
            }
        } else {
            Menu("Mover para...") {
                Button("Notas Soltas") {
                    viewModel.moveNote(note, to: nil)
                }
                .disabled(note.notebook == nil)
                
                if !viewModel.notebooks.isEmpty {
                    Divider()
                    ForEach(viewModel.notebooks, id: \.self) { notebook in
                        Button(notebook.name) {
                            viewModel.moveNote(note, to: notebook)
                        }
                        .disabled(note.notebook == notebook)
                    }
                }
            }
            Divider()
            Button("Excluir Nota", role: .destructive) {
                viewModel.deleteNote(note)
            }
        }
    }
}

// MARK: - Note Card Component View
struct NoteCardView: View {
    let note: Note
    @State private var isHovered = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            
            // White Card preview container
            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.white)
                    .shadow(color: isHovered ? .black.opacity(0.12) : .black.opacity(0.06),
                            radius: isHovered ? 8 : 4,
                            x: 0,
                            y: isHovered ? 4 : 2)
                
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isHovered ? Color.secondary.opacity(0.2) : Color.secondary.opacity(0.1), lineWidth: 1)
                
                // Inside content preview
                NoteThumbnailView(note: note)
                    .clipShape(RoundedRectangle(cornerRadius: 15))
            }
            .aspectRatio(1.0 / 1.35, contentMode: .fit)
            .scaleEffect(isHovered ? 1.02 : 1.0)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: isHovered)
            
            // Title & Subtitle Below the Card
            VStack(alignment: .center, spacing: 2) {
                Text(note.title.isEmpty ? "Sem título" : note.title)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                    .multilineTextAlignment(.center)
                
                Text(formatCardDate(note.updatedAt))
                    .font(.system(size: 11, design: .rounded))
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.top, 4)
        }
        .onHover { hovering in
            isHovered = hovering
        }
        .onDrag {
            NSItemProvider(object: note.id.uuidString as NSString)
        }
    }
    
    // MARK: - Date Formatting Helper
    private func formatCardDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy"
        formatter.locale = Locale(identifier: "en_US")
        return formatter.string(from: date)
    }
}

// MARK: - Note Thumbnail View Renderer
struct NoteThumbnailView: View {
    let note: Note
    @State private var cover: NSImage?

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .topLeading) {

                // First PDF page as the card cover (white while it renders)
                if let cover = cover {
                    Image(nsImage: cover)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .clipped()
                }

                // If there's text, show a small preview block
                if !note.content.isEmpty {
                    Text(note.content)
                        .font(.system(size: 5, weight: .regular, design: .rounded))
                        .foregroundColor(Color.secondary.opacity(0.8))
                        .lineSpacing(2)
                        .multilineTextAlignment(.leading)
                        .lineLimit(18)
                        .padding(10)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                }
                
                // Draw vector paths if there are strokes
                if let strokesSet = note.strokes as? Set<Stroke>, !strokesSet.isEmpty {
                    let sortedStrokes = strokesSet.sorted { $0.createdAt < $1.createdAt }
                    
                    Canvas { context, size in
                        // Scaling factors based on US Letter target coordinate space (612 x 792)
                        let scaleX = size.width / 612.0
                        let scaleY = size.height / 792.0
                        
                        context.scaleBy(x: scaleX, y: scaleY)
                        
                        for stroke in sortedStrokes {
                            let points = deserializePoints(stroke.points)
                            guard !points.isEmpty else { continue }
                            
                            var path = Path()
                            path.move(to: points[0])
                            for i in 1..<points.count {
                                path.addLine(to: points[i])
                            }
                            
                            let strokeColor = Color(nsColor: NSColor(hex: stroke.color) ?? .black)
                            context.stroke(
                                path,
                                with: .color(strokeColor),
                                style: StrokeStyle(lineWidth: CGFloat(stroke.width), lineCap: .round, lineJoin: .round)
                            )
                        }
                    }
                    .background(Color.clear)
                }
            }
        }
        .task(id: note.updatedAt) {
            cover = Self.coverImage(for: note)
        }
    }

    // MARK: - First-page cover renderer
    private static func coverImage(for note: Note) -> NSImage? {
        let key = "\(note.id.uuidString)-\(note.updatedAt.timeIntervalSince1970)" as NSString
        if let cached = noteCoverCache.object(forKey: key) {
            return cached
        }
        guard let data = note.pdfData,
              let page = PDFDocument(data: data)?.page(at: 0) else {
            return nil
        }
        // 2× the card's ~150-point width keeps the raster crisp on Retina.
        let image = page.thumbnail(of: CGSize(width: 300, height: 405), for: .mediaBox)
        noteCoverCache.setObject(image, forKey: key)
        return image
    }

    // MARK: - Point Deserializer
    private func deserializePoints(_ string: String) -> [CGPoint] {
        guard !string.isEmpty else { return [] }
        let coordinatePairs = string.components(separatedBy: ";")
        return coordinatePairs.compactMap { pair in
            let components = pair.components(separatedBy: ",")
            if components.count == 2,
               let x = Double(components[0]),
               let y = Double(components[1]) {
                return CGPoint(x: x, y: y)
            }
            return nil
        }
    }
}
