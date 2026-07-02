import SwiftUI
import UniformTypeIdentifiers

struct SidebarView: View {
    @EnvironmentObject var viewModel: NoteViewModel
    
    @State private var isCreatingNotebook = false
    @State private var newNotebookName = ""
    
    @State private var isRenamingNotebook = false
    @State private var notebookToRename: Notebook? = nil
    @State private var renameNotebookName = ""
    
    @State private var isConfirmingDeleteNotebook = false
    @State private var notebookToDelete: Notebook? = nil
    
    @State private var hoveredItem: String? = nil
    
    var body: some View {
        VStack(spacing: 0) {
            
            // MARK: - Top Menu Button
            HStack {
                Button(action: {
                    // Menu actions or toggle sidebar
                }) {
                    Image(systemName: "line.3.horizontal")
                        .font(.system(size: 18, weight: .regular))
                        .foregroundColor(.primary)
                        .padding(8)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help("Menu")
                
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 8)
            
            // MARK: - Sidebar Items List
            List {
                // All Notes
                sidebarRow(
                    title: "All notes",
                    icon: "doc.text",
                    badge: viewModel.countAllNotes(),
                    isSelected: viewModel.selectedFilter == .all,
                    action: { viewModel.selectedFilter = .all }
                )
                .listRowInsets(EdgeInsets(top: 2, leading: 12, bottom: 2, trailing: 12))
                .listRowBackground(Color.clear)
                
                // Trash
                sidebarRow(
                    title: "Trash",
                    icon: "trash",
                    badge: viewModel.countTrashedNotes(),
                    isSelected: viewModel.selectedFilter == .trash,
                    action: { viewModel.selectedFilter = .trash }
                )
                .contextMenu {
                    Button("Esvaziar Lixeira", role: .destructive) {
                        viewModel.emptyTrash()
                    }
                    .disabled(viewModel.countTrashedNotes() == 0)
                }
                .onDrop(of: [UTType.text], isTargeted: nil) { providers in
                    guard let provider = providers.first else { return false }
                    provider.loadObject(ofClass: NSString.self) { uuidString, _ in
                        if let uuidString = uuidString as? String, let uuid = UUID(uuidString: uuidString) {
                            DispatchQueue.main.async {
                                viewModel.trashNote(id: uuid)
                            }
                        }
                    }
                    return true
                }
                .listRowInsets(EdgeInsets(top: 2, leading: 12, bottom: 2, trailing: 12))
                .listRowBackground(Color.clear)
                
                // Folders / Notebooks Section
                Section(
                    header: HStack {
                        Text("Folders")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        Button(action: {
                            isCreatingNotebook = true
                        }) {
                            Image(systemName: "plus")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 8)
                    .padding(.top, 16)
                    .padding(.bottom, 4)
                ) {
                    // Uncategorized Notes (Notas Soltas)
                    sidebarRow(
                        title: "Notas Soltas",
                        icon: "doc",
                        badge: viewModel.countUncategorizedNotes(),
                        isSelected: viewModel.selectedFilter == .uncategorized,
                        action: { viewModel.selectedFilter = .uncategorized }
                    )
                    .onDrop(of: [UTType.text], isTargeted: nil) { providers in
                        guard let provider = providers.first else { return false }
                        provider.loadObject(ofClass: NSString.self) { uuidString, _ in
                            if let uuidString = uuidString as? String, let uuid = UUID(uuidString: uuidString) {
                                DispatchQueue.main.async {
                                    viewModel.moveNote(id: uuid, to: nil)
                                }
                            }
                        }
                        return true
                    }
                    
                    // User Notebooks
                    ForEach(viewModel.notebooks, id: \.self) { notebook in
                        sidebarRow(
                            title: notebook.name,
                            icon: "folder",
                            badge: Int(notebook.activeNotesCount),
                            isSelected: isNotebookSelected(notebook),
                            action: { viewModel.selectedFilter = .notebook(notebook) }
                        )
                        .contextMenu {
                            Button("Renomear...") {
                                notebookToRename = notebook
                                renameNotebookName = notebook.name
                                isRenamingNotebook = true
                            }
                            Divider()
                            Button("Excluir Caderno...", role: .destructive) {
                                notebookToDelete = notebook
                                isConfirmingDeleteNotebook = true
                            }
                        }
                        .onDrop(of: [UTType.text], isTargeted: nil) { providers in
                            guard let provider = providers.first else { return false }
                            provider.loadObject(ofClass: NSString.self) { uuidString, _ in
                                if let uuidString = uuidString as? String, let uuid = UUID(uuidString: uuidString) {
                                    DispatchQueue.main.async {
                                        viewModel.moveNote(id: uuid, to: notebook)
                                    }
                                }
                            }
                            return true
                        }
                    }
                }
                .listRowInsets(EdgeInsets(top: 2, leading: 12, bottom: 2, trailing: 12))
                .listRowBackground(Color.clear)
            }
            .listStyle(.sidebar)
            .scrollContentBackground(.hidden)
            
            Spacer()
            
            // MARK: - Bottom Settings Bar
            Divider()
            HStack {
                Button(action: {
                    // Open Settings Dialogue / Action
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "gearshape")
                            .font(.system(size: 16))
                            .foregroundColor(.primary)
                        Text("Settings")
                            .font(.system(size: 13, weight: .regular, design: .rounded))
                            .foregroundColor(.primary)
                    }
                    .padding(12)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                
                Spacer()
                
                // Extra New Folder quick button
                Button(action: {
                    isCreatingNotebook = true
                }) {
                    Image(systemName: "folder.badge.plus")
                        .font(.system(size: 15))
                        .foregroundColor(.secondary)
                        .padding(12)
                }
                .buttonStyle(.plain)
                .help("Novo Caderno")
            }
            .background(Color(NSColor.windowBackgroundColor).opacity(0.8))
        }
        // Dialogue overlays
        .alert("Novo Caderno", isPresented: $isCreatingNotebook) {
            TextField("Nome do caderno", text: $newNotebookName)
            Button("Cancelar", role: .cancel) {
                newNotebookName = ""
            }
            Button("Criar") {
                viewModel.addNotebook(name: newNotebookName)
                newNotebookName = ""
            }
        } message: {
            Text("Insira o nome para o novo caderno de notas.")
        }
        .alert("Renomear Caderno", isPresented: $isRenamingNotebook) {
            TextField("Nome do caderno", text: $renameNotebookName)
            Button("Cancelar", role: .cancel) {
                notebookToRename = nil
                renameNotebookName = ""
            }
            Button("Salvar") {
                if let notebook = notebookToRename {
                    viewModel.renameNotebook(notebook, to: renameNotebookName)
                }
                notebookToRename = nil
                renameNotebookName = ""
            }
        } message: {
            Text("Insira o novo nome para este caderno.")
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
            Text("As notas contidas neste caderno serão enviadas para a Lixeira, a menos que escolha manter as notas como Notas Soltas.")
        }
    }
    
    // MARK: - Row builder
    private func sidebarRow(title: String, icon: String, badge: Int, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                action()
            }
        }) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .regular))
                    .foregroundColor(isSelected ? .white : Color(red: 0.91, green: 0.35, blue: 0.14))
                    .frame(width: 18)
                
                Text(title)
                    .font(.system(size: 13, weight: isSelected ? .semibold : .regular, design: .rounded))
                    .foregroundColor(isSelected ? .white : .primary)
                    .lineLimit(1)
                
                Spacer()
                
                if badge > 0 {
                    Text("\(badge)")
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundColor(isSelected ? .white.opacity(0.8) : .secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(isSelected ? .white.opacity(0.15) : Color.primary.opacity(0.04))
                        )
                }
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 10)
            .contentShape(Rectangle())
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isSelected ? Color(red: 0.91, green: 0.35, blue: 0.14) : (hoveredItem == title ? Color.primary.opacity(0.04) : Color.clear))
            )
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            hoveredItem = hovering ? title : nil
        }
    }
    
    private func isNotebookSelected(_ notebook: Notebook) -> Bool {
        if case .notebook(let current) = viewModel.selectedFilter, current == notebook {
            return true
        }
        return false
    }
}
