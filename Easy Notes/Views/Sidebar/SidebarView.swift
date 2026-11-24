import SwiftUI
import UniformTypeIdentifiers

struct SidebarView: View {
    @EnvironmentObject var viewModel: NoteViewModel
    @ObservedObject private var settings = AppSettingsStore.shared
    @Environment(\.openSettings) private var openSettings

    @State private var isCreatingNotebook = false

    @State private var newParent: Notebook?
    @State private var collapsed: Set<UUID> = []
    @State private var editColor = Color.clear
    @State private var notebookToRename: Notebook? = nil
    private var visibleNotebooks: [Notebook] {
        func rows(_ siblings: [Notebook]) -> [Notebook] {
            siblings.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
                .flatMap { notebook in
                    [notebook] + (collapsed.contains(notebook.id) ? [] : rows(Array(notebook.children ?? [])))
                }
        }
        return rows(viewModel.notebooks.filter { $0.parent == nil })
    }

    @State private var isConfirmingDeleteNotebook = false
    @State private var isConfirmingEmptyTrash = false
    @State private var notebookToDelete: Notebook? = nil

    @State private var hoveredItem: String? = nil

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // MARK: - Biblioteca Section
                    VStack(alignment: .leading, spacing: 4) {
                        Text("BIBLIOTECA")
                            .studioSectionHeader()
                            .padding(.horizontal, 10)
                            .padding(.bottom, 4)

                        libraryRow(
                            id: "filter-all",
                            title: "Todas as notas",
                            icon: "doc.text",
                            badge: viewModel.countAllNotes(),
                            isSelected: viewModel.selectedFilter == .all,
                            action: { viewModel.selectedFilter = .all }
                        )

                        libraryRow(
                            id: "filter-uncategorized",
                            title: "Notas Soltas",
                            icon: "doc",
                            badge: viewModel.countUncategorizedNotes(),
                            isSelected: viewModel.selectedFilter == .uncategorized,
                            action: { viewModel.selectedFilter = .uncategorized }
                        )
                        .onDrop(of: [UTType.text], isTargeted: nil) { providers in
                            handleDrop(providers: providers) { uuid in
                                viewModel.moveNote(id: uuid, to: nil)
                            }
                        }

                        libraryRow(
                            id: "filter-trash",
                            title: "Lixeira",
                            icon: "trash",
                            badge: viewModel.countTrashedNotes(),
                            isSelected: viewModel.selectedFilter == .trash,
                            action: { viewModel.selectedFilter = .trash }
                        )
                        .contextMenu {
                            Button("Esvaziar Lixeira", role: .destructive) {
                                if settings.confirmBeforeEmptyingTrash {
                                    isConfirmingEmptyTrash = true
                                } else {
                                    viewModel.emptyTrash()
                                }
                            }
                            .disabled(viewModel.countTrashedNotes() == 0)
                        }
                        .onDrop(of: [UTType.text], isTargeted: nil) { providers in
                            handleDrop(providers: providers) { uuid in
                                viewModel.trashNote(id: uuid)
                            }
                        }
                    }

                    // MARK: - Seus Cadernos Section
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("SEUS CADERNOS")
                                .studioSectionHeader()

                            Spacer()

                            Button(action: {
                                newParent = nil
                                isCreatingNotebook = true
                            }) {
                                Image(systemName: "plus")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundColor(hoveredItem == "add-notebook" ? PixelTheme.accent : PixelTheme.muted)
                                    .frame(width: 22, height: 22)
                                    .background(
                                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                                            .fill(hoveredItem == "add-notebook" ? PixelTheme.sidebarElevated : Color.clear)
                                    )
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .help("Novo Caderno")
                            .onHover { hovering in
                                hoveredItem = hovering ? "add-notebook" : (hoveredItem == "add-notebook" ? nil : hoveredItem)
                            }
                        }
                        .padding(.horizontal, 10)
                        .padding(.bottom, 2)

                        if viewModel.notebooks.isEmpty {
                            Text("Nenhum caderno ainda")
                                .font(PixelTheme.uiFont(size: 12))
                                .foregroundColor(PixelTheme.muted)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                        } else {
                            ForEach(visibleNotebooks, id: \.self) { notebook in
                                HStack(spacing: 0) {
                                    if notebook.children?.isEmpty == false {
                                        Button {
                                            if !collapsed.insert(notebook.id).inserted { collapsed.remove(notebook.id) }
                                        } label: {
                                            Image(systemName: collapsed.contains(notebook.id) ? "chevron.right" : "chevron.down")
                                                .frame(width: 16)
                                        }
                                        .buttonStyle(.plain)
                                        .accessibilityLabel(collapsed.contains(notebook.id) ? "Expandir" : "Recolher")
                                    } else {
                                        Color.clear.frame(width: 16, height: 1)
                                    }
                                    notebookRow(notebook)
                                }
                                .padding(.leading, CGFloat(min(notebook.ancestors.count, 6)) * 10)
                                    .contextMenu {
                                        Button("Editar caderno…") {
                                            notebookToRename = notebook
                                            editColor = PixelTheme.notebookColor(for: notebook)
                                        }
                                        Button("Nova subpasta…") {
                                            newParent = notebook
                                            isCreatingNotebook = true
                                        }
                                        Divider()
                                        Button("Excluir Caderno...", role: .destructive) {
                                            if settings.confirmBeforeDeletingNotebook {
                                                notebookToDelete = notebook
                                                isConfirmingDeleteNotebook = true
                                            } else {
                                                viewModel.deleteNotebook(notebook, keepNotes: true)
                                            }
                                        }
                                    }
                                    .onDrop(of: [UTType.text], isTargeted: nil) { providers in
                                        handleDrop(providers: providers) { uuid in
                                            viewModel.moveNote(id: uuid, to: notebook)
                                        }
                                    }
                            }
                        }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.top, 36)
                .padding(.bottom, 16)
            }
            .scrollIndicators(.hidden)

            // MARK: - Bottom Brand Footer
            Rectangle()
                .fill(PixelTheme.border)
                .frame(height: 1)

            HStack {
                EasyNotesBrandMark(compact: true)
                Spacer()
                Button {
                    openSettings()
                } label: {
                    Image(systemName: "gearshape")
                        .font(.system(size: 13.5, weight: .medium))
                        .foregroundColor(hoveredItem == "app-settings" ? PixelTheme.accent : PixelTheme.muted)
                        .frame(width: 26, height: 26)
                        .background(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(hoveredItem == "app-settings" ? PixelTheme.sidebarElevated : Color.clear)
                        )
                        .contentShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                }
                .buttonStyle(.plain)
                .help("Configurações (⌘,)")
                .accessibilityLabel("Configurações")
                .onHover { hovering in
                    hoveredItem = hovering ? "app-settings" : (hoveredItem == "app-settings" ? nil : hoveredItem)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(PixelTheme.sidebar)
        }
        .background(PixelTheme.sidebar)
        .overlay(alignment: .trailing) {
            Rectangle()
                .fill(PixelTheme.border)
                .frame(width: 1)
        }
        // Dialogue overlays
        .sheet(isPresented: $isCreatingNotebook) {
            NamePromptView(
                title: newParent == nil ? "Novo Caderno" : "Nova subpasta",
                fieldLabel: "Nome do caderno",
                confirmationLabel: "Criar",
                onConfirm: { name in
                    if let newParent { collapsed.remove(newParent.id) }
                    viewModel.addNotebook(name: name, parent: newParent)
                }
            )
        }
        .sheet(item: $notebookToRename) { notebook in
            NamePromptView(title: "Editar caderno", fieldLabel: "Nome do caderno",
                           confirmationLabel: "Salvar", onConfirm: { name in
                viewModel.renameNotebook(notebook, to: name, color: editColor)
            }, initialName: notebook.name, notebookColor: $editColor)
        }
        .alert("Excluir Caderno", isPresented: $isConfirmingDeleteNotebook) {
            Button("Excluir Caderno e Notas", role: .destructive) {
                if let notebook = notebookToDelete {
                    viewModel.deleteNotebook(notebook, keepNotes: false)
                }
                notebookToDelete = nil
            }
            Button("Excluir Apenas Caderno", role: .none) {
                if let notebook = notebookToDelete {
                    viewModel.deleteNotebook(notebook, keepNotes: true)
                }
                notebookToDelete = nil
            }
            Button("Cancelar", role: .cancel) {
                notebookToDelete = nil
            }
        } message: {
            Text("As subpastas sobem um nível. Excluir apenas o caderno mantém suas notas em Notas Soltas. Excluir também as notas as envia para a Lixeira.")
        }
        .alert("Esvaziar Lixeira", isPresented: $isConfirmingEmptyTrash) {
            Button("Esvaziar Lixeira", role: .destructive) {
                viewModel.emptyTrash()
            }
            Button("Cancelar", role: .cancel) {}
        } message: {
            Text("Todas as notas na Lixeira serão excluídas permanentemente. Esta ação não pode ser desfeita.")
        }
    }

    // MARK: - Row Builders
    private func libraryRow(
        id: String,
        title: String,
        icon: String,
        badge: Int,
        isSelected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        let isHovered = hoveredItem == id

        return Button(action: {
            withAnimation(.easeInOut(duration: 0.16)) {
                action()
            }
        }) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 13.5, weight: isSelected ? .semibold : .regular))
                    .foregroundColor(isSelected ? PixelTheme.accent : PixelTheme.inkSecondary)
                    .frame(width: 18)

                Text(title)
                    .font(PixelTheme.uiFont(size: 13, weight: isSelected ? .semibold : .medium))
                    .foregroundColor(isSelected ? PixelTheme.accent : PixelTheme.ink)
                    .lineLimit(1)

                Spacer(minLength: 8)

                if badge > 0 {
                    Text("\(badge)")
                        .font(PixelTheme.uiFont(size: 11.5, weight: isSelected ? .semibold : .medium))
                        .foregroundColor(isSelected ? PixelTheme.accent : PixelTheme.muted)
                        .monospacedDigit()
                }
            }
            .padding(.vertical, 7)
            .padding(.horizontal, 10)
            .background(
                RoundedRectangle(cornerRadius: PixelTheme.pillRadius, style: .continuous)
                    .fill(isSelected ? PixelTheme.accentSoft : (isHovered ? PixelTheme.sidebarElevated : Color.clear))
            )
            .contentShape(RoundedRectangle(cornerRadius: PixelTheme.pillRadius, style: .continuous))
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            hoveredItem = hovering ? id : (hoveredItem == id ? nil : hoveredItem)
        }
    }

    private func notebookRow(_ notebook: Notebook) -> some View {
        let id = "notebook-\(notebook.id.uuidString)"
        let isSelected = isNotebookSelected(notebook)
        let isHovered = hoveredItem == id
        let count = Int(notebook.activeNotesCount)

        return Button(action: {
            withAnimation(.easeInOut(duration: 0.16)) {
                viewModel.selectedFilter = .notebook(notebook)
            }
        }) {
            HStack(spacing: 10) {
                RoundedRectangle(cornerRadius: 2.5, style: .continuous)
                    .fill(PixelTheme.notebookColor(for: notebook))
                    .frame(width: 8, height: 8)
                    .frame(width: 18)

                Text(notebook.name)
                    .font(PixelTheme.uiFont(size: 13, weight: isSelected ? .semibold : .medium))
                    .foregroundColor(isSelected ? PixelTheme.accent : PixelTheme.ink)
                    .lineLimit(1)

                Spacer(minLength: 8)

                if count > 0 {
                    Text("\(count)")
                        .font(PixelTheme.uiFont(size: 11.5, weight: isSelected ? .semibold : .medium))
                        .foregroundColor(isSelected ? PixelTheme.accent : PixelTheme.muted)
                        .monospacedDigit()
                }
            }
            .padding(.vertical, 7)
            .padding(.horizontal, 10)
            .background(
                RoundedRectangle(cornerRadius: PixelTheme.pillRadius, style: .continuous)
                    .fill(isSelected ? PixelTheme.accentSoft : (isHovered ? PixelTheme.sidebarElevated : Color.clear))
            )
            .contentShape(RoundedRectangle(cornerRadius: PixelTheme.pillRadius, style: .continuous))
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            hoveredItem = hovering ? id : (hoveredItem == id ? nil : hoveredItem)
        }
    }

    private func handleDrop(providers: [NSItemProvider], perform action: @escaping (UUID) -> Void) -> Bool {
        guard let provider = providers.first else { return false }
        provider.loadObject(ofClass: NSString.self) { uuidString, _ in
            if let uuidString = uuidString as? String, let uuid = UUID(uuidString: uuidString) {
                DispatchQueue.main.async {
                    action(uuid)
                }
            }
        }
        return true
    }

    private func isNotebookSelected(_ notebook: Notebook) -> Bool {
        if case .notebook(let current) = viewModel.selectedFilter, current == notebook {
            return true
        }
        return false
    }
}
