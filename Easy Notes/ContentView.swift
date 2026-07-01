import SwiftUI

struct ContentView: View {
    @EnvironmentObject var viewModel: NoteViewModel
    @StateObject private var canvasVM = CanvasViewModel()
    
    @State private var activeTitle: String = ""
    @State private var loadingNoteId: UUID? = nil
    
    @State private var saveTask: Task<Void, Never>? = nil
    
    @State private var zoomScale: CGFloat = 2.0
    @State private var isSidebarOpen: Bool = true
    @State private var selectedPageIndex: Int = 0
    
    var body: some View {
        NavigationSplitView {
            SidebarView()
                .frame(minWidth: 180, idealWidth: 200, maxWidth: 300)
        } content: {
            NoteListView()
                .frame(minWidth: 220, idealWidth: 250, maxWidth: 350)
        } detail: {
            if let note = viewModel.selectedNote {
                VStack(spacing: 0) {
                    // MARK: - Title Input
                    TextField("Sem título", text: $activeTitle)
                        .textFieldStyle(.plain)
                        .font(.system(size: 26, weight: .bold, design: .rounded))
                        .padding(.horizontal, 24)
                        .padding(.top, 52)
                        .padding(.bottom, 12)
                        .foregroundColor(.primary)
                    
                    // MARK: - Writing Toolbar (Samsung Notes style)
                    EditorToolbarView(canvasVM: canvasVM, isSidebarOpen: $isSidebarOpen)
                    
                    Divider()
                    
                    // MARK: - Drawing Canvas & Sidebar Layer
                    HStack(spacing: 0) {
                        ZStack(alignment: .bottomTrailing) {
                            PDFAnnotationCanvasView(canvasVM: canvasVM, noteVM: viewModel, noteId: note.id, zoomScale: $zoomScale, selectedPageIndex: $selectedPageIndex)
                                .background(Color.clear)
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                                .pointerStyle(drawingPointerStyle)
                            
                            // Floating Zoom Controls
                            HStack(spacing: 8) {
                                Button(action: {
                                    zoomScale = max(0.5, zoomScale - 0.1)
                                }) {
                                    Image(systemName: "minus.magnifyingglass")
                                        .padding(6)
                                        .background(Color(NSColor.controlBackgroundColor).opacity(0.8))
                                        .cornerRadius(4)
                                }
                                .buttonStyle(PlainButtonStyle())
                                .help("Zoom Out")
                                
                                Text("\(Int(zoomScale * 100))%")
                                    .font(.system(.body, design: .monospaced))
                                    .padding(.horizontal, 4)
                                
                                Button(action: {
                                    zoomScale = min(4.0, zoomScale + 0.1)
                                }) {
                                    Image(systemName: "plus.magnifyingglass")
                                        .padding(6)
                                        .background(Color(NSColor.controlBackgroundColor).opacity(0.8))
                                        .cornerRadius(4)
                                }
                                .buttonStyle(PlainButtonStyle())
                                .help("Zoom In")
                                
                                Button(action: {
                                    zoomScale = 1.0
                                }) {
                                    Image(systemName: "arrow.counterclockwise")
                                        .padding(6)
                                        .background(Color(NSColor.controlBackgroundColor).opacity(0.8))
                                        .cornerRadius(4)
                                }
                                .buttonStyle(PlainButtonStyle())
                                .help("Ajustar Zoom")
                            }
                            .padding(8)
                            .background(Color(NSColor.windowBackgroundColor).opacity(0.9))
                            .cornerRadius(6)
                            .shadow(color: .black.opacity(0.15), radius: 3, x: 0, y: 2)
                            .padding(16)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        
                        if isSidebarOpen {
                            Divider()
                            ThumbnailBarView(noteVM: viewModel, pdfDocument: viewModel.selectedNote.flatMap { viewModel.getPDFDocument(for: $0) }, selectedPageIndex: $selectedPageIndex)
                        }
                    }
                }
                .background(Color(NSColor.textBackgroundColor))
            } else {
                // MARK: - Empty State Placeholder
                VStack(spacing: 16) {
                    Image(systemName: "note.text")
                        .font(.system(size: 64))
                        .foregroundColor(.secondary.opacity(0.35))
                    
                    Text("Nenhuma Nota Selecionada")
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)
                    
                    Text("Selecione um caderno na barra lateral e escolha uma nota, ou crie uma nova para começar a escrever.")
                        .font(.subheadline)
                        .foregroundColor(.secondary.opacity(0.7))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 48)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(NSColor.windowBackgroundColor))
            }
        }
        .onAppear {
            handleNoteChange(to: viewModel.selectedNote)
        }
        .onChange(of: viewModel.selectedNote) { newNote in
            handleNoteChange(to: newNote)
        }
        .onChange(of: activeTitle) { newTitle in
            if let note = viewModel.selectedNote, note.title != newTitle {
                scheduleSave()
            }
        }
    }
    
    // MARK: - Sync State logic
    private func handleNoteChange(to newNote: Note?) {
        // Cancel any pending save tasks from previous note editing
        saveTask?.cancel()
        
        if let note = newNote {
            let noteChanged = loadingNoteId != note.id
            Swift.print("DEBUG: handleNoteChange. loadingNoteId: \(String(describing: loadingNoteId)), note.id: \(note.id), noteChanged: \(noteChanged)")
            
            activeTitle = note.title
            loadingNoteId = note.id
            
            if noteChanged {
                Swift.print("DEBUG: Resetting zoomScale and selectedPageIndex to default!")
                zoomScale = 1.0
                selectedPageIndex = 0
            }
        } else {
            activeTitle = ""
            loadingNoteId = nil
//            zoomScale = 1.0
            selectedPageIndex = 0
        }
    }
    
    // MARK: - Debounced Database Persistence
    private func scheduleSave() {
        saveTask?.cancel()
        saveTask = Task {
            // Wait for 500ms of inactivity before saving to Core Data (typing lag avoidance)
            try? await Task.sleep(nanoseconds: 500_000_000)
            if Task.isCancelled { return }
            
            await MainActor.run {
                if let note = viewModel.selectedNote {
                    viewModel.updateNoteContent(note: note, title: activeTitle, content: note.content)
                }
            }
        }
    }
    
    // MARK: - Pointer Style Preview
    private var drawingPointerStyle: PointerStyle? {
//        guard canvasVM.isDrawingMode else { return nil }
        
        let cursorImage: NSImage
        if canvasVM.activeTool == .eraser {
            cursorImage = createEraserCursorImage()
        } else {
            let activeColor = NSColor(canvasVM.strokeColor)
            cursorImage = createCircleCursorImage(color: activeColor, diameter: canvasVM.strokeWidth)
        }
        
        return .image(Image(nsImage: cursorImage), hotSpot: .center)
    }
    
    private func createCircleCursorImage(color: NSColor, diameter: CGFloat) -> NSImage {
        let size = max(4.0, diameter)
        let imageSize = NSSize(width: size + 4, height: size + 4)
        let image = NSImage(size: imageSize)
        
        image.lockFocus()
        let rect = NSRect(x: 2, y: 2, width: size, height: size)
        let path = NSBezierPath(ovalIn: rect)
        
        color.setFill()
        path.fill()
        
        NSColor.white.setStroke()
        path.lineWidth = 1.0
        path.stroke()
        
        let outerRect = rect.insetBy(dx: -0.5, dy: -0.5)
        let outerPath = NSBezierPath(ovalIn: outerRect)
        NSColor.black.withAlphaComponent(0.25).setStroke()
        outerPath.lineWidth = 0.5
        outerPath.stroke()
        
        image.unlockFocus()
        return image
    }
    
    private func createEraserCursorImage() -> NSImage {
        let diameter: CGFloat = 36.0
        let imageSize = NSSize(width: diameter + 4, height: diameter + 4)
        let image = NSImage(size: imageSize)
        
        image.lockFocus()
        let rect = NSRect(x: 2, y: 2, width: diameter, height: diameter)
        let path = NSBezierPath(ovalIn: rect)
        
        NSColor.secondaryLabelColor.withAlphaComponent(0.6).setStroke()
        path.lineWidth = 1.0
        let pattern: [CGFloat] = [4.0, 4.0]
        path.setLineDash(pattern, count: 2, phase: 0.0)
        path.stroke()
        
        image.unlockFocus()
        return image
    }
}
