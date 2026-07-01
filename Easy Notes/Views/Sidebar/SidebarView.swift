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
    
    var body: some View {
        VStack(spacing: 0) {
            List {
                // MARK: - General Section
                Section(header: Text("Geral").font(.caption).foregroundColor(.secondary)) {
                    // All Active Notes
                    Button(action: {
                        viewModel.selectedFilter = .all
                    }) {
                        HStack {
                            Image(systemName: "tray.full.fill")
                                .foregroundColor(viewModel.selectedFilter == .all ? .white : .accentColor)
                                .frame(width: 18)
                            Text("Todas as Notas")
                                .fontWeight(viewModel.selectedFilter == .all ? .semibold : .regular)
                            Spacer()
                            Text("\(viewModel.countAllNotes())")
                                .font(.subheadline)
                                .foregroundColor(viewModel.selectedFilter == .all ? .white.opacity(0.8) : .secondary)
                        }
                        .padding(.vertical, 4)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .listRowBackground(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(viewModel.selectedFilter == .all ? Color.accentColor : Color.clear)
                    )
                    .foregroundColor(viewModel.selectedFilter == .all ? .white : .primary)
                    
                    // Uncategorized Notes (Notas Soltas)
                    Button(action: {
                        viewModel.selectedFilter = .uncategorized
                    }) {
                        HStack {
                            Image(systemName: "doc.fill")
                                .foregroundColor(viewModel.selectedFilter == .uncategorized ? .white : .accentColor)
                                .frame(width: 18)
                            Text("Notas Soltas")
                                .fontWeight(viewModel.selectedFilter == .uncategorized ? .semibold : .regular)
                            Spacer()
                            Text("\(viewModel.countUncategorizedNotes())")
                                .font(.subheadline)
                                .foregroundColor(viewModel.selectedFilter == .uncategorized ? .white.opacity(0.8) : .secondary)
                        }
                        .padding(.vertical, 4)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .listRowBackground(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(viewModel.selectedFilter == .uncategorized ? Color.accentColor : Color.clear)
                    )
                    .foregroundColor(viewModel.selectedFilter == .uncategorized ? .white : .primary)
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
                    
                    // Trash / Recycle Bin (Lixeira)
                    Button(action: {
                        viewModel.selectedFilter = .trash
                    }) {
                        HStack {
                            Image(systemName: "trash.fill")
                                .foregroundColor(viewModel.selectedFilter == .trash ? .white : .accentColor)
                                .frame(width: 18)
                            Text("Lixeira")
                                .fontWeight(viewModel.selectedFilter == .trash ? .semibold : .regular)
                            Spacer()
                            Text("\(viewModel.countTrashedNotes())")
                                .font(.subheadline)
                                .foregroundColor(viewModel.selectedFilter == .trash ? .white.opacity(0.8) : .secondary)
                        }
                        .padding(.vertical, 4)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .listRowBackground(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(viewModel.selectedFilter == .trash ? Color.accentColor : Color.clear)
                    )
                    .foregroundColor(viewModel.selectedFilter == .trash ? .white : .primary)
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
                }
                
                // MARK: - Notebooks Section
                Section(header:
                            HStack {
                    Text("Meus Cadernos")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    Button(action: {
                        isCreatingNotebook = true
                    }) {
                        Image(systemName: "plus")
                            .font(.caption)
                            .foregroundColor(.accentColor)
                    }
                    .buttonStyle(.plain)
                    .help("Novo Caderno")
                }
                ) {
                    ForEach(viewModel.notebooks, id: \.self) { notebook in
                        Button(action: {
                            viewModel.selectedFilter = .notebook(notebook)
                        }) {
                            HStack {
                                Image(systemName: "folder.fill")
                                    .foregroundColor(isNotebookSelected(notebook) ? .white : .accentColor)
                                    .frame(width: 18)
                                Text(notebook.name)
                                    .fontWeight(isNotebookSelected(notebook) ? .semibold : .regular)
                                Spacer()
                                Text("\(notebook.activeNotesCount)")
                                    .font(.subheadline)
                                    .foregroundColor(isNotebookSelected(notebook) ? .white.opacity(0.8) : .secondary)
                            }
                            .padding(.vertical, 4)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .listRowBackground(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(isNotebookSelected(notebook) ? Color.accentColor : Color.clear)
                        )
                        .foregroundColor(isNotebookSelected(notebook) ? .white : .primary)
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
            .listStyle(.sidebar)
                
                // MARK: - Bottom Bar
                Divider()
                HStack {
                    Button(action: {
                        isCreatingNotebook = true
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: "folder.badge.plus")
                            Text("Novo Caderno")
                        }
                        .foregroundColor(.accentColor)
                    }
                    .buttonStyle(.plain)
                    .padding(12)
                    Spacer()
                }
                .background(.ultraThinMaterial)
            }
            // Alerts for Dialog inputs
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
    }
    
    private func isNotebookSelected(_ notebook: Notebook) -> Bool {
        if case .notebook(let current) = viewModel.selectedFilter, current == notebook {
            return true
        }
        return false
    }
}
