import AppKit
import PDFKit
import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @EnvironmentObject var viewModel: NoteViewModel
    @StateObject private var canvasVM = CanvasViewModel()

    @State private var canvasFocus = CanvasFocusTarget()
    @State private var zoomScale: CGFloat = 1.0
    @State private var canvasViewportWidth: CGFloat = 0
    @State private var isSidebarOpen = true
    @State private var selectedPageIndex = 0
    @State private var imageImportError: String?

    var body: some View {
        Group {
            if let note = viewModel.selectedNote {
                editorWorkspace(for: note)
                    .ignoresSafeArea(.container, edges: .top)
            } else {
                NavigationSplitView {
                    SidebarView()
                        .frame(minWidth: 210, idealWidth: 230, maxWidth: 270)
                } detail: {
                    NotesView()
                }
            }
        }
        .onAppear {
            resetEditorPosition()
        }
        .onChange(of: viewModel.selectedNote) {
            resetEditorPosition()
        }
        .onChange(of: viewModel.selectedNote?.pageCount) { _, pageCount in
            selectedPageIndex = min(max(0, selectedPageIndex), max(1, Int(pageCount ?? 1)) - 1)
        }
        .onDisappear { viewModel.flushTitleEdits() }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.willTerminateNotification)) { _ in
            viewModel.flushTitleEdits()
        }
        .alert("Falha ao renomear nota", isPresented: Binding(
            get: { viewModel.titleSaveError != nil },
            set: { if !$0 { viewModel.titleSaveError = nil } }
        )) {
            Button("OK") { viewModel.titleSaveError = nil }
        } message: {
            Text(viewModel.titleSaveError ?? "")
        }
    }

    private func editorWorkspace(for note: Note) -> some View {
        let paperStyle = GridStyle(rawValue: note.gridStyle) ?? .none

        return VStack(spacing: 0) {
            editorHeader(for: note)
            EditorToolbarView(canvasVM: canvasVM, isSidebarOpen: $isSidebarOpen, onInsertImage: {
                chooseEditorImage(for: note, pageIndex: selectedPageIndex)
            }) {
                viewModel.selectedNote = nil
            }

            HStack(spacing: 0) {
                if isSidebarOpen {
                    editorSidebar(for: note)
                }

                GeometryReader { proxy in
                    PDFAnnotationCanvasView(
                        canvasVM: canvasVM,
                        noteVM: viewModel,
                        noteId: note.id,
                        focusTarget: canvasFocus,
                        zoomScale: $zoomScale,
                        selectedPageIndex: $selectedPageIndex
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(PixelTheme.canvas)
                    .onAppear { canvasViewportWidth = proxy.size.width }
                    .onChange(of: proxy.size.width) { _, width in
                        canvasViewportWidth = width
                    }
                }
            }

            EditorFooterBar(
                pageCount: max(1, Int(note.pageCount)),
                paperStyle: paperStyle,
                selectedPageIndex: $selectedPageIndex,
                zoomScale: $zoomScale,
                onFitToWidth: { fitCanvasToWidth(for: note) }
            )
        }
        .background(PixelTheme.paper)
        .alert("Falha ao inserir imagem", isPresented: Binding(
            get: { imageImportError != nil },
            set: { if !$0 { imageImportError = nil } }
        )) {
            Button("OK") { imageImportError = nil }
        } message: {
            Text(imageImportError ?? "")
        }
    }

    private func editorHeader(for note: Note) -> some View {
        HStack(spacing: 10) {
            Button {
                viewModel.selectedNote = nil
            } label: {
                EasyNotesBrandMark(compact: true)
            }
            .buttonStyle(.plain)
            .fixedSize()
            .accessibilityLabel("Voltar para Notas")
            .help("Voltar para Notas")

            Text("/")
                .foregroundStyle(PixelTheme.muted)
                .accessibilityHidden(true)

            Text(note.notebook?.path ?? "Notas Soltas")
                .foregroundStyle(PixelTheme.muted)
                .lineLimit(1)

            Image(systemName: "chevron.right")
                .font(PixelTheme.uiFont(size: 9, weight: .semibold))
                .foregroundStyle(PixelTheme.muted)
                .accessibilityHidden(true)

            TextField("Sem título", text: Binding(
                get: { note.title },
                set: { title in
                    viewModel.editTitle(of: note, to: title)
                }
            ))
                .id(note.objectID)
                .textFieldStyle(.plain)
                .font(PixelTheme.uiFont(size: 13.5, weight: .semibold))
                .foregroundStyle(PixelTheme.ink)
                .onSubmit {
                    viewModel.flushTitleEdits()
                    canvasFocus.focus()
                }
                .accessibilityLabel("Título da nota")

            Spacer(minLength: 8)

            Label(viewModel.hasPendingTitle ? "Salvando…" : "Salvo", systemImage: viewModel.hasPendingTitle ? "clock" : "checkmark")
                .foregroundStyle(PixelTheme.success)
                .fixedSize()

            Button {
                exportPDF(for: note)
            } label: {
                Label("Compartilhar", systemImage: "square.and.arrow.up")
                    .font(PixelTheme.uiFont(size: 12, weight: .semibold))
                    .foregroundStyle(PixelTheme.ink)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(PixelTheme.paper, in: RoundedRectangle(cornerRadius: 8))
                    .overlay {
                        RoundedRectangle(cornerRadius: 8)
                            .strokeBorder(PixelTheme.border, lineWidth: 1)
                    }
                    .contentShape(RoundedRectangle(cornerRadius: 8))
            }
            .buttonStyle(.plain)
            .fixedSize()
            .help("Exportar como PDF… (⇧⌘E)")
            .keyboardShortcut("e", modifiers: [.command, .shift])
        }
        .font(PixelTheme.uiFont(size: 12))
        .padding(.leading, 76)
        .padding(.trailing, 16)
        .frame(height: 48)
        .background(PixelTheme.paper)
        .overlay(alignment: .bottom) {
            Rectangle().fill(PixelTheme.border).frame(height: 1)
        }
    }

    private func editorSidebar(for note: Note) -> some View {
        ThumbnailBarView(
            noteVM: viewModel,
            pdfDocument: viewModel.getPDFDocument(for: note),
            selectedPageIndex: $selectedPageIndex
        )
        .frame(width: 220)
        .frame(maxHeight: .infinity)
        .background(PixelTheme.surface)
        .overlay(alignment: .trailing) {
            Rectangle().fill(PixelTheme.border).frame(width: 1)
        }
    }

    private func chooseEditorImage(for note: Note, pageIndex: Int) {
        let panel = NSOpenPanel()
        panel.title = "Inserir imagem"
        panel.prompt = "Inserir"
        panel.allowedContentTypes = [.png, .jpeg]
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        let completion: (NSApplication.ModalResponse) -> Void = { response in
            guard response == .OK, let url = panel.url else { return }
            do {
                let data = try EditorImageMedia.read(from: url)
                try viewModel.insertEditorImage(data: data, into: note, pageIndex: pageIndex)
            } catch {
                imageImportError = error.localizedDescription
            }
        }
        if let window = canvasFocus.view?.window {
            panel.beginSheetModal(for: window, completionHandler: completion)
        } else {
            panel.begin(completionHandler: completion)
        }
    }

    private func exportPDF(for note: Note) {
        PDFExportService.shared.exportPDF(for: note, viewModel: viewModel)
    }

    private func resetEditorPosition() {
        zoomScale = 1.0
        selectedPageIndex = 0
    }

    private func fitCanvasToWidth(for note: Note) {
        let availableWidth = max(200, canvasViewportWidth - 48)
        let pageWidth: CGFloat
        if let doc = viewModel.getPDFDocument(for: note),
           let page = doc.page(at: min(max(0, selectedPageIndex), max(0, doc.pageCount - 1))) {
            pageWidth = max(1, page.bounds(for: .mediaBox).width)
        } else {
            pageWidth = 612
        }
        let rawScale = availableWidth / pageWidth
        let rounded = (rawScale * 20).rounded() / 20
        zoomScale = min(4.0, max(0.5, rounded))
    }
}
