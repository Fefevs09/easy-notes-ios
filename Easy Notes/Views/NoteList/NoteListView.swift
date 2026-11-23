import SwiftUI
import UniformTypeIdentifiers

struct NoteListView: View {
    @EnvironmentObject var viewModel: NoteViewModel
    @State private var isCreatingNote = false

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
                        .tint(PixelTheme.success)
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
        .sheet(isPresented: $isCreatingNote) { NewNoteSheet() }
        .listStyle(.inset)
        .scrollContentBackground(.hidden)
        .background(PixelTheme.surface)
        .overlay {
            if viewModel.notes.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "doc.text.magnifyingglass")
                        .font(.system(size: 36))
                        .foregroundColor(PixelTheme.muted.opacity(0.6))
                    Text(emptyStateTitle())
                        .font(PixelTheme.displayFont(size: 15, weight: .bold))
                        .foregroundColor(PixelTheme.ink)
                    Text(emptyStateSubtitle())
                        .font(PixelTheme.uiFont(size: 12.5))
                        .foregroundColor(PixelTheme.muted)
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
                            .font(PixelTheme.displayFont(size: 16, weight: .bold))
                            .foregroundColor(PixelTheme.ink)
                        Text("\(viewModel.notes.count) \(viewModel.notes.count == 1 ? "nota" : "notas")")
                            .font(PixelTheme.uiFont(size: 11.5, weight: .medium))
                            .foregroundColor(PixelTheme.muted)
                            .monospacedDigit()
                    }
                    Spacer()

                    // Empty Trash action if in Trash and has notes
                    if viewModel.selectedFilter == .trash && !viewModel.notes.isEmpty {
                        Button(action: {
                            viewModel.emptyTrash()
                        }) {
                            Text("Esvaziar Lixeira")
                                .foregroundColor(PixelTheme.danger)
                                .font(PixelTheme.uiFont(size: 12, weight: .semibold))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(
                                    RoundedRectangle(cornerRadius: PixelTheme.controlRadius, style: .continuous)
                                        .fill(PixelTheme.dangerSoft)
                                )
                        }
                        .buttonStyle(.plain)
                    }

                    // Add Note / Import PDF Buttons (Hidden when viewing Trash)
                    if viewModel.selectedFilter != .trash {
                        HStack(spacing: 6) {
                            Button(action: {
                                importPDFFile()
                            }) {
                                Image(systemName: "arrow.down.doc")
                                    .font(.system(size: 13.5, weight: .medium))
                                    .foregroundColor(PixelTheme.ink)
                                    .frame(width: 28, height: 28)
                                    .background(
                                        RoundedRectangle(cornerRadius: PixelTheme.controlRadius, style: .continuous)
                                            .fill(PixelTheme.paper)
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: PixelTheme.controlRadius, style: .continuous)
                                            .strokeBorder(PixelTheme.border, lineWidth: 1)
                                    )
                            }
                            .buttonStyle(.plain)
                            .help("Importar PDF")

                            Button(action: {
                                isCreatingNote = true
                            }) {
                                Image(systemName: "plus")
                                    .font(.system(size: 13.5, weight: .semibold))
                                    .foregroundColor(.white)
                                    .frame(width: 28, height: 28)
                                    .background(
                                        RoundedRectangle(cornerRadius: PixelTheme.controlRadius, style: .continuous)
                                            .fill(PixelTheme.accent)
                                    )
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Nova nota")
                            .help("Nova Nota")
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 36)
                .padding(.bottom, 12)

                // MARK: - Search Bar
                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(PixelTheme.muted)
                        .font(.system(size: 12.5))

                    TextField("Buscar nas notas...", text: $viewModel.searchQuery)
                        .textFieldStyle(.plain)
                        .font(PixelTheme.uiFont(size: 13))
                        .foregroundColor(PixelTheme.ink)

                    if !viewModel.searchQuery.isEmpty {
                        Button(action: {
                            viewModel.searchQuery = ""
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(PixelTheme.muted)
                                .font(.system(size: 12))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(
                    RoundedRectangle(cornerRadius: PixelTheme.controlRadius, style: .continuous)
                        .fill(PixelTheme.paper)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: PixelTheme.controlRadius, style: .continuous)
                        .strokeBorder(PixelTheme.border, lineWidth: 1)
                )
                .padding(.horizontal, 16)
                .padding(.bottom, 12)

                Rectangle()
                    .fill(PixelTheme.border)
                    .frame(height: 1)
            }
            .background(PixelTheme.surface)
        }
    }

    // MARK: - Header helpers
    private func headerTitle() -> String {
        switch viewModel.selectedFilter {
        case .all:
            return "Todas as notas"
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
            return "Caderno vazio"
        case .trash:
            return "Lixeira vazia"
        }
    }

    private func emptyStateSubtitle() -> String {
        if !viewModel.searchQuery.isEmpty {
            return "Tente buscar por termos diferentes."
        }
        switch viewModel.selectedFilter {
        case .all, .uncategorized, .notebook:
            return "Adicione uma nova nota clicando no botão + acima."
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
                    .font(PixelTheme.uiFont(size: 13.5, weight: .semibold))
                    .foregroundColor(isSelected ? PixelTheme.accent : PixelTheme.ink)
                    .lineLimit(1)

                Spacer()

                Text(formatDate(note.updatedAt))
                    .font(PixelTheme.uiFont(size: 11.5))
                    .foregroundColor(isSelected ? PixelTheme.accent.opacity(0.8) : PixelTheme.muted)
            }

            HStack(spacing: 6) {
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .fill(PixelTheme.notebookColor(for: note.notebook?.name))
                    .frame(width: 7, height: 7)

                Text(note.notebook?.name ?? "Notas Soltas")
                    .font(PixelTheme.uiFont(size: 11.5, weight: .medium))
                    .foregroundColor(isSelected ? PixelTheme.accent.opacity(0.85) : PixelTheme.muted)
                    .lineLimit(1)

                Spacer()

                Text("\(note.strokes?.count ?? 0) \((note.strokes?.count ?? 0) == 1 ? "traço" : "traços")")
                    .font(PixelTheme.uiFont(size: 11.5))
                    .foregroundColor(isSelected ? PixelTheme.accent.opacity(0.75) : PixelTheme.muted)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: PixelTheme.controlRadius, style: .continuous)
                .fill(isSelected ? PixelTheme.accentSoft : PixelTheme.paper)
        )
        .overlay(
            RoundedRectangle(cornerRadius: PixelTheme.controlRadius, style: .continuous)
                .strokeBorder(isSelected ? PixelTheme.accentBorder : PixelTheme.border, lineWidth: 1)
        )
        .contentShape(RoundedRectangle(cornerRadius: PixelTheme.controlRadius, style: .continuous))
    }

    // MARK: - Date Formatting Helper
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "pt_BR")
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
