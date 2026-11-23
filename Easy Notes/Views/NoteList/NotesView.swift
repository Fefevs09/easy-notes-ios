import AppKit
import SwiftUI
import CoreData
import PDFKit
import UniformTypeIdentifiers

struct NotesView: View {
    private struct NoteActionAlert: Identifiable {
        let id = UUID()
        let title: String
        let message: String
    }

    @EnvironmentObject var viewModel: NoteViewModel

    @AppStorage("easyNotes.libraryIsGridView") private var isGridView = true
    @FocusState private var isSearchFocused: Bool
    @FocusState private var focusedMenuTriggerNoteID: UUID?
    @State private var activeMenuNoteID: UUID?
    @State private var pendingPanelFocusRestoreNoteID: UUID?
    @State private var suppressNextFocusRestore = false
    @State private var actionAlert: NoteActionAlert?

    // 3-column adaptive grid
    private let columns = [
        GridItem(.adaptive(minimum: 220, maximum: 300), spacing: 20)
    ]

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // MARK: - Editorial Header
                    editorialHeader

                    // MARK: - Search Bar & View Toggle
                    searchAndToggleRow

                    // MARK: - Quick-Filter Notebook Chips
                    if viewModel.selectedFilter != .trash && !viewModel.notebooks.isEmpty {
                        notebookChipsRow
                    }

                    // MARK: - Section Header & Sort Menu
                    sectionHeaderRow

                    // MARK: - Notes Content (Empty / Grid / List)
                    if viewModel.notes.isEmpty {
                        emptyStateView
                    } else if isGridView {
                        LazyVGrid(columns: columns, spacing: 20) {
                            ForEach(viewModel.notes, id: \.self) { note in
                                NoteCardView(
                                    note: note,
                                    coverCache: viewModel.coverCache,
                                    isMenuPresented: menuPresentedBinding(for: note),
                                    focusedMenuTriggerNoteID: $focusedMenuTriggerNoteID,
                                    onOpenNote: { openNote(note) },
                                    onToggleMenu: { toggleMenu(for: note) },
                                    onOpenMenu: { openMenu(for: note) }
                                ) {
                                    actionMenuPopover(for: note)
                                }
                            }
                        }
                    } else {
                        LazyVStack(spacing: 10) {
                            ForEach(viewModel.notes, id: \.self) { note in
                                NoteListRowCardView(
                                    note: note,
                                    coverCache: viewModel.coverCache,
                                    isMenuPresented: menuPresentedBinding(for: note),
                                    focusedMenuTriggerNoteID: $focusedMenuTriggerNoteID,
                                    onOpenNote: { openNote(note) },
                                    onToggleMenu: { toggleMenu(for: note) },
                                    onOpenMenu: { openMenu(for: note) }
                                ) {
                                    actionMenuPopover(for: note)
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 32)
                .padding(.top, 36)
                .padding(.bottom, 32)
            }
            .background(PixelTheme.surface)

            // MARK: - Subtle Bottom Status Footer
            Rectangle()
                .fill(PixelTheme.border)
                .frame(height: 1)

            HStack {
                Text(statusCountText())
                    .font(PixelTheme.uiFont(size: 11.5, weight: .medium))
                    .foregroundColor(PixelTheme.muted)
                    .monospacedDigit()

                Spacer()

                Text("Suas ideias ficam salvas automaticamente.")
                    .font(PixelTheme.uiFont(size: 11.5))
                    .foregroundColor(PixelTheme.muted)
            }
            .padding(.horizontal, 32)
            .padding(.vertical, 10)
            .background(PixelTheme.surface)
        }
        .background(PixelTheme.surface)
        .onChange(of: viewModel.selectedFilter) { _, _ in
            closeMenu(restoreFocus: false)
        }
        .onChange(of: viewModel.searchQuery) { _, _ in
            closeMenu(restoreFocus: false)
        }
        .onChange(of: viewModel.selectedNote) { _, _ in
            closeMenu(restoreFocus: false)
        }
        .onChange(of: isGridView) { _, _ in
            closeMenu(restoreFocus: false)
        }
        .onChange(of: isSearchFocused) { _, focused in
            if focused {
                closeMenu(restoreFocus: false)
            }
        }
        .onChange(of: viewModel.notes) { _, notes in
            if let activeID = activeMenuNoteID,
               !notes.contains(where: { $0.id == activeID }) {
                closeMenu(restoreFocus: false)
            }
        }
        .onChange(of: activeMenuNoteID) { oldID, newID in
            let shouldSuppress = suppressNextFocusRestore
            suppressNextFocusRestore = false
            guard !shouldSuppress,
                  newID == nil,
                  let closedNoteID = oldID,
                  pendingPanelFocusRestoreNoteID != closedNoteID else {
                return
            }
            restoreFocusToTrigger(for: closedNoteID)
        }
        .alert(item: $actionAlert) { alert in
            Alert(
                title: Text(alert.title),
                message: Text(alert.message),
                dismissButton: .default(Text("OK"))
            )
        }
    }

    // MARK: - Editorial Header
    private var editorialHeader: some View {
        HStack(alignment: .bottom, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text("CADA IDEIA É UM COMEÇO")
                    .studioSectionHeader()

                Text(viewModel.selectedFilter == .all ? "Seu próximo grande rascunho." : headerTitle())
                    .font(PixelTheme.displayFont(size: 26, weight: .bold))
                    .foregroundColor(PixelTheme.ink)
                    .tracking(-0.4)
                    .lineLimit(2)
            }

            Spacer(minLength: 16)

            if viewModel.selectedFilter != .trash {
                HStack(spacing: 10) {
                    Button(action: {
                        importPDFFile()
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.down.doc")
                                .font(.system(size: 12.5, weight: .medium))
                            Text("Importar PDF")
                                .font(PixelTheme.uiFont(size: 13, weight: .medium))
                        }
                        .foregroundColor(PixelTheme.ink)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 9)
                        .background(
                            RoundedRectangle(cornerRadius: 9, style: .continuous)
                                .fill(PixelTheme.paper)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 9, style: .continuous)
                                .strokeBorder(PixelTheme.border, lineWidth: 1)
                        )
                        .shadow(color: Color.black.opacity(0.03), radius: 3, x: 0, y: 1)
                    }
                    .buttonStyle(.plain)

                    Button(action: {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                            viewModel.addNote()
                        }
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: "plus")
                                .font(.system(size: 12.5, weight: .bold))
                            Text("Nova nota")
                                .font(PixelTheme.uiFont(size: 13, weight: .semibold))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 9)
                        .background(
                            RoundedRectangle(cornerRadius: 9, style: .continuous)
                                .fill(PixelTheme.accent)
                        )
                        .shadow(color: PixelTheme.accent.opacity(0.25), radius: 6, x: 0, y: 2)
                    }
                    .buttonStyle(.plain)
                }
            } else if !viewModel.notes.isEmpty {
                Button(action: {
                    viewModel.emptyTrash()
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "trash")
                            .font(.system(size: 12.5, weight: .semibold))
                        Text("Esvaziar Lixeira")
                            .font(PixelTheme.uiFont(size: 13, weight: .semibold))
                    }
                    .foregroundColor(PixelTheme.danger)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 9)
                    .background(
                        RoundedRectangle(cornerRadius: 9, style: .continuous)
                            .fill(PixelTheme.dangerSoft)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 9, style: .continuous)
                            .strokeBorder(PixelTheme.danger.opacity(0.25), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Search & View Toggle Row
    private var searchAndToggleRow: some View {
        HStack(spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 13.5, weight: .medium))
                    .foregroundColor(PixelTheme.muted)

                TextField("Buscar por título...", text: $viewModel.searchQuery)
                    .textFieldStyle(.plain)
                    .font(PixelTheme.uiFont(size: 13.5))
                    .foregroundColor(PixelTheme.ink)
                    .focused($isSearchFocused)

                if !viewModel.searchQuery.isEmpty {
                    Button(action: {
                        viewModel.searchQuery = ""
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 13))
                            .foregroundColor(PixelTheme.muted)
                    }
                    .buttonStyle(.plain)
                }

                Text("⌘K")
                    .font(PixelTheme.displayFont(size: 10.5, weight: .medium))
                    .foregroundColor(PixelTheme.muted)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(
                        RoundedRectangle(cornerRadius: 5, style: .continuous)
                            .fill(PixelTheme.surface)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 5, style: .continuous)
                            .strokeBorder(PixelTheme.border, lineWidth: 1)
                    )
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(PixelTheme.paper)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(isSearchFocused ? PixelTheme.accentBorder : PixelTheme.border, lineWidth: isSearchFocused ? 1.5 : 1)
            )
            .shadow(color: Color.black.opacity(0.025), radius: 3, x: 0, y: 1)

            // Hidden shortcut button so ⌘K focuses search cleanly
            Button("") {
                isSearchFocused = true
            }
            .keyboardShortcut("k", modifiers: .command)
            .frame(width: 0, height: 0)
            .opacity(0)
            .accessibilityHidden(true)

            // Grid / List toggle pill
            HStack(spacing: 2) {
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.16)) {
                        isGridView = true
                    }
                }) {
                    Image(systemName: "square.grid.2x2")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(isGridView ? PixelTheme.accent : PixelTheme.muted)
                        .frame(width: 30, height: 28)
                        .background(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(isGridView ? PixelTheme.accentSoft : Color.clear)
                        )
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help("Visualização em Grade")

                Button(action: {
                    withAnimation(.easeInOut(duration: 0.16)) {
                        isGridView = false
                    }
                }) {
                    Image(systemName: "list.bullet")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(!isGridView ? PixelTheme.accent : PixelTheme.muted)
                        .frame(width: 30, height: 28)
                        .background(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(!isGridView ? PixelTheme.accentSoft : Color.clear)
                        )
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help("Visualização em Lista")
            }
            .padding(3)
            .background(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(PixelTheme.paper)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .strokeBorder(PixelTheme.border, lineWidth: 1)
            )
        }
    }

    // MARK: - Quick-Filter Notebook Chips
    private var notebookChipsRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                if viewModel.selectedFilter != .all {
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.16)) {
                            viewModel.selectedFilter = .all
                        }
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: "square.stack")
                                .font(.system(size: 11.5, weight: .medium))
                                .foregroundColor(PixelTheme.inkSecondary)
                            Text("Todas")
                                .font(PixelTheme.uiFont(size: 12.5, weight: .medium))
                                .foregroundColor(PixelTheme.ink)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(
                            RoundedRectangle(cornerRadius: 9, style: .continuous)
                                .fill(PixelTheme.paper)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 9, style: .continuous)
                                .strokeBorder(PixelTheme.border, lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                }

                ForEach(viewModel.notebooks, id: \.self) { notebook in
                    let isActive = isNotebookActive(notebook)

                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.16)) {
                            viewModel.selectedFilter = .notebook(notebook)
                        }
                    }) {
                        HStack(spacing: 7) {
                            Image(systemName: "folder.fill")
                                .font(.system(size: 11.5))
                                .foregroundColor(PixelTheme.notebookColor(for: notebook.name))

                            Text(notebook.name)
                                .font(PixelTheme.uiFont(size: 12.5, weight: isActive ? .semibold : .medium))
                                .foregroundColor(isActive ? PixelTheme.accent : PixelTheme.ink)
                                .lineLimit(1)

                            Text("\(notebook.activeNotesCount)")
                                .font(PixelTheme.uiFont(size: 11.5, weight: .medium))
                                .foregroundColor(isActive ? PixelTheme.accent.opacity(0.85) : PixelTheme.muted)
                                .monospacedDigit()
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(
                            RoundedRectangle(cornerRadius: 9, style: .continuous)
                                .fill(isActive ? PixelTheme.accentSoft : PixelTheme.paper)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 9, style: .continuous)
                                .strokeBorder(isActive ? PixelTheme.accentBorder : PixelTheme.border, lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 1)
        }
    }

    // MARK: - Section Header & Sort Menu
    private var sectionHeaderRow: some View {
        HStack(alignment: .center, spacing: 8) {
            Text(headerTitle())
                .font(PixelTheme.uiFont(size: 14, weight: .semibold))
                .foregroundColor(PixelTheme.ink)

            Text("\(viewModel.notes.count)")
                .font(PixelTheme.uiFont(size: 11.5, weight: .semibold))
                .foregroundColor(PixelTheme.muted)
                .monospacedDigit()
                .padding(.horizontal, 7)
                .padding(.vertical, 2)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(PixelTheme.sidebar)
                )

            Spacer()

            Menu {
                Picker("Ordenar por", selection: $viewModel.sortOption) {
                    ForEach(SortOption.allCases) { option in
                        Text(sortOptionMenuLabel(option)).tag(option)
                    }
                }
            } label: {
                HStack(spacing: 5) {
                    Text(sortOptionShortLabel(viewModel.sortOption))
                        .font(PixelTheme.uiFont(size: 12.5, weight: .medium))
                        .foregroundColor(PixelTheme.inkSecondary)

                    Image(systemName: "chevron.down")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(PixelTheme.muted)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(PixelTheme.paper)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .strokeBorder(PixelTheme.border, lineWidth: 1)
                )
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
        }
        .padding(.top, 2)
    }

    // MARK: - Empty State
    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Spacer()
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(PixelTheme.sidebar)
                    .frame(width: 56, height: 56)
                Image(systemName: "doc.text.magnifyingglass")
                    .font(.system(size: 24, weight: .medium))
                    .foregroundColor(PixelTheme.muted)
            }

            Text(emptyStateTitle())
                .font(PixelTheme.displayFont(size: 16, weight: .bold))
                .foregroundColor(PixelTheme.ink)

            Text(emptyStateSubtitle())
                .font(PixelTheme.uiFont(size: 13))
                .foregroundColor(PixelTheme.muted)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 48)
            Spacer()
        }
        .frame(maxWidth: .infinity, minHeight: 280)
    }

    // MARK: - Helpers
    private func isNotebookActive(_ notebook: Notebook) -> Bool {
        if case .notebook(let current) = viewModel.selectedFilter, current == notebook {
            return true
        }
        return false
    }

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

    private func sortOptionShortLabel(_ option: SortOption) -> String {
        switch option {
        case .dateModifiedDescending, .dateModifiedAscending:
            return "Última edição"
        case .dateCreatedDescending, .dateCreatedAscending:
            return "Data de criação"
        case .titleAscending, .titleDescending:
            return "Título"
        }
    }

    private func sortOptionMenuLabel(_ option: SortOption) -> String {
        switch option {
        case .dateModifiedDescending:
            return "Última edição (mais recente)"
        case .dateModifiedAscending:
            return "Última edição (mais antiga)"
        case .dateCreatedDescending:
            return "Data de criação (mais recente)"
        case .dateCreatedAscending:
            return "Data de criação (mais antiga)"
        case .titleAscending:
            return "Título (A–Z)"
        case .titleDescending:
            return "Título (Z–A)"
        }
    }

    private func statusCountText() -> String {
        let shown = viewModel.notes.count
        let total = viewModel.selectedFilter == .trash
            ? viewModel.countTrashedNotes()
            : viewModel.countAllNotes()
        return "\(shown) de \(total) \(total == 1 ? "nota" : "notas")"
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
            return "Crie uma nova nota clicando em \"+ Nova nota\" acima."
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

        presentPanel(openPanel) { response in
            if response == .OK, let url = openPanel.url {
                viewModel.importPDF(url: url)
            }
        }
    }

    private func openNote(_ note: Note) {
        closeMenu(restoreFocus: false)
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
            viewModel.selectedNote = note
        }
    }

    private func toggleMenu(for note: Note) {
        guard pendingPanelFocusRestoreNoteID == nil else { return }
        let noteID = note.id
        if activeMenuNoteID == noteID {
            closeMenu(restoreFocus: true)
        } else {
            suppressNextFocusRestore = false
            activeMenuNoteID = noteID
        }
    }

    private func openMenu(for note: Note) {
        guard pendingPanelFocusRestoreNoteID == nil else { return }
        suppressNextFocusRestore = false
        activeMenuNoteID = note.id
    }

    private func closeMenu(restoreFocus: Bool) {
        guard activeMenuNoteID != nil else { return }
        suppressNextFocusRestore = !restoreFocus
        activeMenuNoteID = nil
    }

    private func menuPresentedBinding(for note: Note) -> Binding<Bool> {
        let noteID = note.id
        return Binding(
            get: { activeMenuNoteID == noteID },
            set: { isPresented in
                if isPresented {
                    guard pendingPanelFocusRestoreNoteID == nil else { return }
                    suppressNextFocusRestore = false
                    activeMenuNoteID = noteID
                } else if activeMenuNoteID == noteID {
                    activeMenuNoteID = nil
                }
            }
        )
    }

    private func restoreFocusToTrigger(for noteID: UUID) {
        DispatchQueue.main.async {
            guard activeMenuNoteID == nil,
                  pendingPanelFocusRestoreNoteID == nil,
                  !isSearchFocused,
                  viewModel.selectedNote == nil,
                  viewModel.notes.contains(where: { $0.id == noteID }) else {
                return
            }
            focusedMenuTriggerNoteID = noteID
        }
    }

    @ViewBuilder
    private func actionMenuPopover(for note: Note) -> some View {
        let noteID = note.id
        NoteActionMenuPopoverView(
            note: note,
            notebooks: viewModel.notebooks,
            filter: viewModel.selectedFilter,
            onRename: { newTitle in
                try viewModel.renameNote(note, to: newTitle)
            },
            onSetEmoji: { emoji in
                try viewModel.setEmoji(emoji, for: note)
            },
            onChooseCover: {
                chooseCoverImage(for: note)
            },
            onRemoveCover: {
                removeCoverImage(for: note)
            },
            onExportPDF: {
                exportPDF(for: note)
            },
            onMoveToNotebook: { notebookID in
                if let notebookID {
                    if let targetNotebook = viewModel.notebooks.first(where: { $0.id == notebookID }) {
                        viewModel.moveNote(note, to: targetNotebook)
                    }
                } else {
                    viewModel.moveNote(note, to: nil)
                }
            },
            onRestore: {
                viewModel.restoreNote(note)
            },
            onDelete: {
                viewModel.deleteNote(note)
            },
            onClose: {
                if activeMenuNoteID == noteID {
                    closeMenu(restoreFocus: true)
                }
            }
        )
    }

    private func presentPanel(_ panel: NSSavePanel, completion: @escaping (NSApplication.ModalResponse) -> Void) {
        if let hostWindow = NSApp.keyWindow ?? NSApp.mainWindow {
            panel.beginSheetModal(for: hostWindow, completionHandler: completion)
        } else {
            panel.begin(completionHandler: completion)
        }
    }

    private func chooseCoverImage(for note: Note) {
        guard pendingPanelFocusRestoreNoteID == nil else { return }
        let noteID = note.id
        pendingPanelFocusRestoreNoteID = noteID
        closeMenu(restoreFocus: false)

        let openPanel = NSOpenPanel()
        openPanel.allowedContentTypes = NoteCoverMedia.supportedStaticImageTypes
        openPanel.allowsMultipleSelection = false
        openPanel.canChooseDirectories = false
        openPanel.canChooseFiles = true
        openPanel.prompt = "Escolher Capa"

        presentPanel(openPanel) { response in
            defer {
                pendingPanelFocusRestoreNoteID = nil
                restoreFocusToTrigger(for: noteID)
            }
            guard response == .OK, let url = openPanel.url else { return }
            do {
                try viewModel.setCover(for: note, from: url)
            } catch {
                actionAlert = NoteActionAlert(
                    title: "Não foi possível atualizar a capa",
                    message: error.localizedDescription
                )
            }
        }
    }

    private func removeCoverImage(for note: Note) {
        closeMenu(restoreFocus: true)
        do {
            try viewModel.removeCover(for: note)
        } catch {
            actionAlert = NoteActionAlert(
                title: "Não foi possível atualizar a capa",
                message: error.localizedDescription
            )
        }
    }

    private func exportPDF(for note: Note) {
        guard pendingPanelFocusRestoreNoteID == nil else { return }
        let noteID = note.id
        pendingPanelFocusRestoreNoteID = noteID
        closeMenu(restoreFocus: false)

        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [.pdf]
        savePanel.canCreateDirectories = true
        savePanel.nameFieldStringValue = note.suggestedPDFName

        presentPanel(savePanel) { response in
            defer {
                pendingPanelFocusRestoreNoteID = nil
                restoreFocusToTrigger(for: noteID)
            }
            guard response == .OK, let url = savePanel.url else { return }
            do {
                try viewModel.exportPDF(for: note, to: url)
            } catch {
                actionAlert = NoteActionAlert(
                    title: "Falha ao exportar PDF",
                    message: error.localizedDescription
                )
            }
        }
    }
}

// MARK: - Shared Menu Trigger Button
private struct NoteMenuTriggerButton<PopoverContent: View>: View {
    let noteID: UUID
    let displayTitle: String
    let isParentHovered: Bool
    @Binding var isMenuPresented: Bool
    var focusedMenuTriggerNoteID: FocusState<UUID?>.Binding
    let onToggleMenu: () -> Void
    @ViewBuilder let popoverContent: () -> PopoverContent

    @State private var isHovered = false

    private var isFocused: Bool {
        focusedMenuTriggerNoteID.wrappedValue == noteID
    }

    var body: some View {
        Button(action: onToggleMenu) {
            Image(systemName: "ellipsis")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(
                    isMenuPresented || isHovered || isFocused
                        ? PixelTheme.ink
                        : PixelTheme.muted.opacity(isParentHovered ? 0.9 : 0.45)
                )
                .frame(width: 26, height: 22)
                .background(
                    RoundedRectangle(cornerRadius: PixelTheme.compactRadius, style: .continuous)
                        .fill(
                            isMenuPresented
                                ? PixelTheme.accentSoft
                                : (isHovered ? PixelTheme.surface : Color.clear)
                        )
                )
                .overlay {
                    if isFocused {
                        RoundedRectangle(cornerRadius: PixelTheme.compactRadius, style: .continuous)
                            .strokeBorder(PixelTheme.accentBorder, lineWidth: 1.5)
                    }
                }
                .contentShape(RoundedRectangle(cornerRadius: PixelTheme.compactRadius, style: .continuous))
        }
        .buttonStyle(.plain)
        .focusable()
        .focused(focusedMenuTriggerNoteID, equals: noteID)
        .focusEffectDisabled()
        .onHover { isHovered = $0 }
        .onKeyPress(.return) {
            onToggleMenu()
            return .handled
        }
        .accessibilityLabel("Ações da nota \(displayTitle)")
        .accessibilityAddTraits(isMenuPresented ? .isSelected : [])
        .help("Opções da nota")
        .popover(isPresented: $isMenuPresented, arrowEdge: .bottom) {
            popoverContent()
                .presentationBackground(PixelTheme.paper)
        }
    }
}

// MARK: - Shared Date Formatters (Cached to avoid per-render allocation)
private enum PortugueseDateFormatters {
    static let today: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "pt_BR")
        f.dateFormat = "'Hoje, às' HH:mm"
        return f
    }()

    static let yesterday: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "pt_BR")
        f.dateFormat = "'Ontem, às' HH:mm"
        return f
    }()

    static let standard: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "pt_BR")
        f.dateFormat = "dd MMM, HH:mm"
        return f
    }()
}

private func formatPortugueseRelativeDate(_ date: Date) -> String {
    let calendar = Calendar.current
    if calendar.isDateInToday(date) {
        return PortugueseDateFormatters.today.string(from: date)
    } else if calendar.isDateInYesterday(date) {
        return PortugueseDateFormatters.yesterday.string(from: date)
    } else {
        return PortugueseDateFormatters.standard.string(from: date)
    }
}

// MARK: - Note Card Component View (Grid)
struct NoteCardView<PopoverContent: View>: View {
    @ObservedObject var note: Note
    var coverCache: NoteCoverCache = .shared
    @Binding var isMenuPresented: Bool
    var focusedMenuTriggerNoteID: FocusState<UUID?>.Binding
    let onOpenNote: () -> Void
    let onToggleMenu: () -> Void
    let onOpenMenu: () -> Void
    @ViewBuilder let popoverContent: () -> PopoverContent

    @State private var isHovered = false

    private var displayTitle: String {
        note.title.isEmpty ? "Sem título" : note.title
    }

    private var cardAccessibilityLabel: String {
        let base = note.displayEmoji.map { "\($0) \(displayTitle)" } ?? displayTitle
        let folder = note.notebook?.name ?? "Notas Soltas"
        return "\(base), \(folder), \(formatPortugueseRelativeDate(note.updatedAt))"
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Button(action: onOpenNote) {
                VStack(alignment: .leading, spacing: 0) {
                    // Top preview banner
                    ZStack(alignment: .topLeading) {
                        PixelTheme.notebookBannerTint(for: note.notebook?.name)

                        // Inset crisp white page thumbnail
                        NoteThumbnailView(note: note, coverCache: coverCache)
                            .background(PixelTheme.paper)
                            .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 4, style: .continuous)
                                    .strokeBorder(Color.black.opacity(0.06), lineWidth: 0.5)
                            )
                            .shadow(color: Color.black.opacity(0.08), radius: 5, x: 0, y: 2)
                            .aspectRatio(1.0 / 1.32, contentMode: .fit)
                            .padding(.vertical, 14)
                            .padding(.horizontal, 18)
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)

                        if note.pageCount > 1 {
                            Text("PDF")
                                .font(PixelTheme.displayFont(size: 9.5, weight: .bold))
                                .foregroundColor(PixelTheme.ink)
                                .padding(.horizontal, 7)
                                .padding(.vertical, 3)
                                .background(
                                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                                        .fill(PixelTheme.paper)
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                                        .strokeBorder(PixelTheme.border, lineWidth: 0.75)
                                )
                                .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
                                .padding(10)
                        }
                    }
                    .frame(height: 150)
                    .clipped()

                    Rectangle()
                        .fill(PixelTheme.border.opacity(0.6))
                        .frame(height: 1)

                    // Bottom metadata area
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(alignment: .center, spacing: 6) {
                            if let emoji = note.displayEmoji {
                                Text(emoji)
                                    .font(.system(size: 13.5))
                                    .accessibilityHidden(true)
                            }

                            Text(displayTitle)
                                .font(PixelTheme.uiFont(size: 14, weight: .semibold))
                                .foregroundColor(PixelTheme.ink)
                                .lineLimit(1)

                            Spacer(minLength: 4)

                            // Reserves space for the sibling ellipsis button without nesting Buttons.
                            Color.clear
                                .frame(width: 26, height: 22)
                                .accessibilityHidden(true)
                        }

                        HStack(alignment: .center, spacing: 8) {
                            Text(formatPortugueseRelativeDate(note.updatedAt))
                                .font(PixelTheme.uiFont(size: 11.5))
                                .foregroundColor(PixelTheme.muted)
                                .lineLimit(1)

                            Spacer(minLength: 6)

                            Text(note.notebook?.name ?? "Notas Soltas")
                                .font(PixelTheme.uiFont(size: 11.5, weight: .medium))
                                .foregroundColor(PixelTheme.muted)
                                .lineLimit(1)
                        }
                    }
                    .padding(14)
                    .background(PixelTheme.paper)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(cardAccessibilityLabel)
            .accessibilityAction(named: "Opções da nota") {
                onOpenMenu()
            }

            NoteMenuTriggerButton(
                noteID: note.id,
                displayTitle: displayTitle,
                isParentHovered: isHovered,
                isMenuPresented: $isMenuPresented,
                focusedMenuTriggerNoteID: focusedMenuTriggerNoteID,
                onToggleMenu: onToggleMenu,
                popoverContent: popoverContent
            )
            .padding(.top, 162)
            .padding(.trailing, 10)
        }
        .clipShape(RoundedRectangle(cornerRadius: PixelTheme.cardRadius, style: .continuous))
        .studioCard(isHovered: isHovered || isMenuPresented)
        .scaleEffect(isHovered ? 1.01 : 1.0)
        .animation(.spring(response: 0.25, dampingFraction: 0.75), value: isHovered)
        .onHover { hovering in
            isHovered = hovering
        }
        .background(
            SecondaryClickOverlay(onSecondaryClick: onOpenMenu)
        )
        .onDrag {
            NSItemProvider(object: note.id.uuidString as NSString)
        }
    }
}

// MARK: - Note List Row Card Component (List View)
struct NoteListRowCardView<PopoverContent: View>: View {
    @ObservedObject var note: Note
    var coverCache: NoteCoverCache = .shared
    @Binding var isMenuPresented: Bool
    var focusedMenuTriggerNoteID: FocusState<UUID?>.Binding
    let onOpenNote: () -> Void
    let onToggleMenu: () -> Void
    let onOpenMenu: () -> Void
    @ViewBuilder let popoverContent: () -> PopoverContent

    @State private var isHovered = false

    private var displayTitle: String {
        note.title.isEmpty ? "Sem título" : note.title
    }

    private var rowAccessibilityLabel: String {
        let base = note.displayEmoji.map { "\($0) \(displayTitle)" } ?? displayTitle
        let folder = note.notebook?.name ?? "Notas Soltas"
        return "\(base), \(folder), \(formatPortugueseRelativeDate(note.updatedAt))"
    }

    var body: some View {
        HStack(spacing: 10) {
            Button(action: onOpenNote) {
                HStack(spacing: 14) {
                    // Mini thumbnail
                    ZStack {
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(PixelTheme.notebookBannerTint(for: note.notebook?.name))

                        NoteThumbnailView(note: note, coverCache: coverCache)
                            .background(PixelTheme.paper)
                            .clipShape(RoundedRectangle(cornerRadius: 3, style: .continuous))
                            .shadow(color: Color.black.opacity(0.08), radius: 2, x: 0, y: 1)
                            .padding(4)
                    }
                    .frame(width: 44, height: 54)

                    // Title + notebook metadata
                    VStack(alignment: .leading, spacing: 5) {
                        HStack(spacing: 6) {
                            if let emoji = note.displayEmoji {
                                Text(emoji)
                                    .font(.system(size: 13.5))
                                    .accessibilityHidden(true)
                            }

                            Text(displayTitle)
                                .font(PixelTheme.uiFont(size: 14, weight: .semibold))
                                .foregroundColor(PixelTheme.ink)
                                .lineLimit(1)

                            if note.pageCount > 1 {
                                Text("PDF")
                                    .font(PixelTheme.displayFont(size: 9, weight: .bold))
                                    .foregroundColor(PixelTheme.inkSecondary)
                                    .padding(.horizontal, 5)
                                    .padding(.vertical, 2)
                                    .background(
                                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                                            .fill(PixelTheme.surface)
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                                            .strokeBorder(PixelTheme.border, lineWidth: 0.75)
                                    )
                            }
                        }

                        HStack(spacing: 6) {
                            RoundedRectangle(cornerRadius: 2.5, style: .continuous)
                                .fill(PixelTheme.notebookColor(for: note.notebook?.name))
                                .frame(width: 8, height: 8)

                            Text(note.notebook?.name ?? "Notas Soltas")
                                .font(PixelTheme.uiFont(size: 12, weight: .medium))
                                .foregroundColor(PixelTheme.muted)
                                .lineLimit(1)
                        }
                    }

                    Spacer(minLength: 12)

                    Text(formatPortugueseRelativeDate(note.updatedAt))
                        .font(PixelTheme.uiFont(size: 12))
                        .foregroundColor(PixelTheme.muted)
                        .lineLimit(1)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(rowAccessibilityLabel)
            .accessibilityAction(named: "Opções da nota") {
                onOpenMenu()
            }

            NoteMenuTriggerButton(
                noteID: note.id,
                displayTitle: displayTitle,
                isParentHovered: isHovered,
                isMenuPresented: $isMenuPresented,
                focusedMenuTriggerNoteID: focusedMenuTriggerNoteID,
                onToggleMenu: onToggleMenu,
                popoverContent: popoverContent
            )
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .studioCard(radius: 10, isHovered: isHovered || isMenuPresented)
        .animation(.easeInOut(duration: 0.15), value: isHovered)
        .onHover { hovering in
            isHovered = hovering
        }
        .background(
            SecondaryClickOverlay(onSecondaryClick: onOpenMenu)
        )
        .onDrag {
            NSItemProvider(object: note.id.uuidString as NSString)
        }
    }
}

// MARK: - Note Thumbnail View Renderer
struct NoteThumbnailView: View {
    @ObservedObject var note: Note
    var coverCache: NoteCoverCache = .shared
    @State private var cover: NSImage?

    private struct ThumbnailTaskID: Equatable {
        let noteID: UUID
        let updatedAt: Date
        let coverUpdatedAt: Date?
        let coverMediaType: String?
        let hasCustomCover: Bool
    }

    var body: some View {
        let taskID = ThumbnailTaskID(
            noteID: note.id,
            updatedAt: note.updatedAt,
            coverUpdatedAt: note.coverUpdatedAt,
            coverMediaType: note.coverMediaType,
            hasCustomCover: note.hasCustomCover
        )

        Group {
            if note.hasCustomCover {
                NoteCoverView(note: note, cache: coverCache)
            } else {
                fallbackThumbnailBody
            }
        }
        .task(id: taskID) {
            if note.hasCustomCover {
                cover = nil
            } else {
                cover = Self.pdfFallbackImage(for: note, cache: coverCache)
            }
        }
    }

    private var fallbackThumbnailBody: some View {
        let sortedStrokes: [Stroke] = (note.strokes as? Set<Stroke>)?
            .filter { $0.pageIndex == 0 }
            .sorted { $0.createdAt < $1.createdAt } ?? []

        return GeometryReader { _ in
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
                        .font(.system(size: 5, weight: .regular, design: .monospaced))
                        .foregroundColor(PixelTheme.muted.opacity(0.8))
                        .lineSpacing(2)
                        .multilineTextAlignment(.leading)
                        .lineLimit(18)
                        .padding(10)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                }

                // Draw vector paths if there are strokes on the first page
                if !sortedStrokes.isEmpty {
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

                // Clean placeholder when the note has no PDF page, text, or strokes
                if cover == nil && note.content.isEmpty && sortedStrokes.isEmpty {
                    Image(systemName: "doc.text")
                        .font(.system(size: 16, weight: .regular))
                        .foregroundColor(PixelTheme.muted.opacity(0.35))
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                }
            }
        }
    }

    // MARK: - First-page cover renderer
    private static func pdfFallbackImage(for note: Note, cache: NoteCoverCache) -> NSImage? {
        let token = "\(note.updatedAt.timeIntervalSince1970)::\(note.pdfData?.count ?? 0)"
        let key = NoteCoverCache.cacheKey(
            noteID: note.id,
            kind: .pdfFallback,
            token: token,
            variant: "page0"
        )
        if let cached = cache.image(forKey: key) {
            return cached
        }
        guard let data = note.pdfData,
              let page = PDFDocument(data: data)?.page(at: 0) else {
            return nil
        }
        // 2× the card's ~150-point width keeps the raster crisp on Retina.
        let image = page.thumbnail(of: CGSize(width: 300, height: 405), for: .mediaBox)
        cache.setImage(image, forKey: key, noteID: note.id)
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
