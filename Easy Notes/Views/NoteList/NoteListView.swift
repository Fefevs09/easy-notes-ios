import SwiftUI
import UniformTypeIdentifiers

struct NoteListView: View {
    @EnvironmentObject var viewModel: NoteViewModel
    
    var body: some View {
        List(selection: $viewModel.selectedNote) {
            ForEach(viewModel.notes, id: \.self) { note in
                Button(action: {
                    viewModel.selectedNote = note
                }) {
                    NoteRowView(note: note, isSelected: viewModel.selectedNote == note)
                }
                .buttonStyle(.plain)
                .tag(note as Note?)
                    .listRowInsets(EdgeInsets(top: 4, leading: 12, bottom: 4, trailing: 12))
                    .listRowBackground(Color.clear)
                    .onDrag {
                        NSItemProvider(object: note.id.uuidString as NSString)
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        if viewModel.selectedFilter == .trash {
                            // Trashed Note actions
                            Button(role: .destructive) {
                                viewModel.deleteNote(note)
                            } label: {
                                Label("Apagar", systemImage: "trash")
                            }
                            
                            Button {
                                viewModel.restoreNote(note)
                            } label: {
                                Label("Restaurar", systemImage: "arrow.up.bin")
                            }
                            .tint(.green)
                        } else {
                            // Active Note actions
                            Button(role: .destructive) {
                                viewModel.deleteNote(note)
                            } label: {
                                Label("Lixeira", systemImage: "trash")
                            }
                        }
                    }
                    .contextMenu {
                        if viewModel.selectedFilter == .trash {
                            Button("Restaurar Nota") {
                                viewModel.restoreNote(note)
                            }
                            Divider()
                            Button("Excluir Definitivamente", role: .destructive) {
                                viewModel.deleteNote(note)
                            }
                        } else {
                            // Move Note Submenu
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
        }
        .listStyle(.inset)
        .scrollContentBackground(.hidden)
        .background(.ultraThinMaterial)
        .overlay {
            if viewModel.notes.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "doc.text.magnifyingglass")
                        .font(.system(size: 40))
                        .foregroundColor(.secondary.opacity(0.6))
                    Text(emptyStateTitle())
                        .font(.headline)
                        .foregroundColor(.secondary)
                    Text(emptyStateSubtitle())
                        .font(.caption)
                        .foregroundColor(.secondary.opacity(0.8))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }
            }
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            VStack(spacing: 0) {
                // MARK: - Header
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(headerTitle())
                            .font(.headline)
                            .fontWeight(.bold)
                        Text("\(viewModel.notes.count) \(viewModel.notes.count == 1 ? "nota" : "notas")")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    
                    // Empty Trash action if in Trash and has notes
                    if viewModel.selectedFilter == .trash && !viewModel.notes.isEmpty {
                        Button(action: {
                            viewModel.emptyTrash()
                        }) {
                            Text("Esvaziar Lixeira")
                                .foregroundColor(.red)
                                .font(.subheadline)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.red.opacity(0.08))
                                .cornerRadius(4)
                        }
                        .buttonStyle(.plain)
                    }
                    
                    // Add Note / Import PDF Buttons (Hidden when viewing Trash)
                    if viewModel.selectedFilter != .trash {
                        HStack(spacing: 8) {
                            Button(action: {
                                importPDFFile()
                            }) {
                                Image(systemName: "doc.badge.plus")
                                    .font(.title3)
                                    .foregroundColor(.accentColor)
                                    .padding(6)
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .help("Importar PDF")
                            
                            Button(action: {
                                viewModel.addNote()
                            }) {
                                Image(systemName: "square.and.pencil")
                                    .font(.title3)
                                    .foregroundColor(.accentColor)
                                    .padding(6)
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .help("Nova Nota")
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 52)
                .padding(.bottom, 12)
                
                // MARK: - Search Bar
                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                        .font(.footnote)
                    
                    TextField("Buscar nas notas...", text: $viewModel.searchQuery)
                        .textFieldStyle(.plain)
                        .font(.body)
                    
                    if !viewModel.searchQuery.isEmpty {
                        Button(action: {
                            viewModel.searchQuery = ""
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                                .font(.footnote)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color(NSColor.windowBackgroundColor).opacity(0.6))
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.secondary.opacity(0.15), lineWidth: 0.5)
                )
                .padding(.horizontal, 16)
                .padding(.bottom, 12)
                
                Divider()
            }
            .background(.ultraThinMaterial)
        }
    }
    
    // MARK: - Header helpers
    private func headerTitle() -> String {
        switch viewModel.selectedFilter {
        case .all:
            return "Todas as Notas"
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
            return "Adicione uma nova nota clicando no botão de lápis acima."
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
}

// MARK: - Row View Component
struct NoteRowView: View {
    let note: Note
    let isSelected: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(note.title.isEmpty ? "Nova Nota" : note.title)
                    .font(.body)
                    .fontWeight(.semibold)
                    .foregroundColor(isSelected ? .white : .primary)
                    .lineLimit(1)
                
                Spacer()
                
                Text(formatDate(note.updatedAt))
                    .font(.caption)
                    .foregroundColor(isSelected ? .white.opacity(0.8) : .secondary)
            }
            
            Text("\(note.strokes?.count ?? 0) \((note.strokes?.count ?? 0) == 1 ? "traço" : "traços")")
                .font(.subheadline)
                .foregroundColor(isSelected ? .white.opacity(0.7) : .secondary)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isSelected ? Color.accentColor : Color.secondary.opacity(0.08))
        )
        .contentShape(Rectangle())
    }
    
    // MARK: - Date Formatting Helper
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        if Calendar.current.isDateInToday(date) {
            formatter.dateFormat = "HH:mm"
        } else if Calendar.current.isDateInYesterday(date) {
            return "Ontem"
        } else {
            formatter.dateFormat = "dd/MM"
        }
        return formatter.string(from: date)
    }
    
}
