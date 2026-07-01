import SwiftUI
import PDFKit
import UniformTypeIdentifiers

struct EditorToolbarView: View {
    @EnvironmentObject var viewModel: NoteViewModel
    @ObservedObject var canvasVM: CanvasViewModel
    @Binding var isSidebarOpen: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            // MARK: - Drawing Tool Icons
            HStack(spacing: 6) {
                toolButton(tool: .fountainPen, icon: "pencil.tip")
                toolButton(tool: .calligraphy, icon: "scribble.variable")
                toolButton(tool: .pencil, icon: "pencil")
                toolButton(tool: .highlighter, icon: "highlighter")
                toolButton(tool: .eraser, icon: "eraser.line.dashed")
            }
            
            Divider().frame(height: 18)
            
            // MARK: - Drawing Configuration (Color, Preset, Size)
            if canvasVM.activeTool != .eraser {
                HStack(spacing: 12) {
                    // Quick Preset Colors
                    HStack(spacing: 5) {
                        presetColorButton(color: .black)
                        presetColorButton(color: .blue)
                        presetColorButton(color: .red)
                        presetColorButton(color: .green)
                        
                        // Custom Color Picker
                        ColorPicker("", selection: $canvasVM.strokeColor)
                            .labelsHidden()
                            .scaleEffect(0.85)
                            .help("Customizar Cor")
                    }
                    
                    Divider().frame(height: 18)
                    
                    // Width Control
                    HStack(spacing: 6) {
                        Image(systemName: "line.horizontal.3.decrease")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Slider(value: $canvasVM.strokeWidth, in: 1...16)
                            .frame(width: 70)
                        Text("\(Int(canvasVM.strokeWidth))pt")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .frame(width: 32, alignment: .leading)
                    }
                }
                .transition(.opacity)
            }
            
            Spacer()
            
            // MARK: - Undo, Export & Sidebar Toggle
            HStack(spacing: 12) {
                // Undo Button
                Button(action: {
                    viewModel.undoLastStroke()
                }) {
                    Image(systemName: "arrow.uturn.backward")
                        .font(.body)
                        .foregroundColor((viewModel.selectedNote?.strokes?.count ?? 0) > 0 ? .primary : .secondary.opacity(0.4))
                        .padding(6)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled((viewModel.selectedNote?.strokes?.count ?? 0) == 0)
                .help("Desfazer último traço")
                
                Divider().frame(height: 18)
                
                // Export PDF Button
                Button(action: {
                    exportPDF()
                }) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.body)
                        .foregroundColor(.primary)
                        .padding(6)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help("Exportar Nota como PDF")
                
                // Toggle Sidebar Button
                Button(action: {
                    withAnimation {
                        isSidebarOpen.toggle()
                    }
                }) {
                    Image(systemName: isSidebarOpen ? "sidebar.right" : "sidebar.right")
                        .font(.body)
                        .foregroundColor(isSidebarOpen ? .accentColor : .primary)
                        .padding(6)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help(isSidebarOpen ? "Ocultar miniaturas" : "Mostrar miniaturas")
            }
        }
        .padding(.horizontal, 16)
        .frame(height: 44)
        .background(Color(NSColor.windowBackgroundColor).opacity(0.85))
    }
    
    private func exportPDF() {
        guard let note = viewModel.selectedNote else { return }
        
        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [.pdf]
        savePanel.nameFieldStringValue = "\(note.title).pdf"
        savePanel.canCreateDirectories = true
        
        savePanel.begin { response in
            if response == .OK, let url = savePanel.url {
                if let doc = viewModel.getPDFDocument(for: note) {
                    doc.write(to: url)
                }
            }
        }
    }
    
    // Tool selection button view helper
    private func toolButton(tool: ToolType, icon: String) -> some View {
        let isSelected = canvasVM.activeTool == tool
        return Button(action: {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                canvasVM.selectTool(tool)
            }
        }) {
            Image(systemName: icon)
                .font(.body)
                .foregroundColor(isSelected ? .white : .primary)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(isSelected ? Color.accentColor : Color.clear)
                )
        }
        .buttonStyle(.plain)
        .help(tool.rawValue)
    }
    
    // Preset color button view helper
    private func presetColorButton(color: Color) -> some View {
        Button(action: {
            canvasVM.strokeColor = color
        }) {
            Circle()
                .fill(color)
                .frame(width: 14, height: 14)
                .overlay(
                    Circle()
                        .stroke(Color.white, lineWidth: canvasVM.strokeColor == color ? 1.5 : 0)
                )
                .shadow(color: .black.opacity(0.15), radius: 1, x: 0, y: 1)
        }
        .buttonStyle(.plain)
    }
}
