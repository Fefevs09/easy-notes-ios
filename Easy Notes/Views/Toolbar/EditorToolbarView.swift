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
                readingModeButton
                toolButton(tool: .fountainPen, icon: "pencil.tip")
                toolButton(tool: .calligraphy, icon: "scribble.variable")
                toolButton(tool: .pencil, icon: "pencil")
                toolButton(tool: .highlighter, icon: "highlighter")
                toolButton(tool: .eraser, icon: "eraser.line.dashed")

                Divider().frame(height: 18)

                // Geometry: select/edit, shapes menu, grid menu
                toolButton(tool: .select, icon: "cursorarrow.square")
                shapesMenu
                gridMenu
            }

            Divider().frame(height: 18)
            
            // MARK: - Drawing Configuration (Color, Preset, Size)
            if canvasVM.isDrawingMode && canvasVM.activeTool != .eraser && canvasVM.activeTool != .select {
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

                    // Fill toggle (only meaningful for closed shapes)
                    if canvasVM.activeTool == .shape {
                        Divider().frame(height: 18)
                        Button(action: {
                            canvasVM.shapeFillEnabled.toggle()
                        }) {
                            Image(systemName: canvasVM.shapeFillEnabled
                                  ? "square.fill" : "square")
                                .font(.body)
                                .foregroundColor(canvasVM.shapeFillEnabled ? .accentColor : .primary)
                                .padding(6)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .help("Preencher forma")
                    }
                }
                .transition(.opacity)
            }
            
            Spacer()
            
            // MARK: - Undo, Export & Sidebar Toggle
            HStack(spacing: 12) {
                // Undo Button
                Button(action: {
                    viewModel.undoLastObject()
                }) {
                    Image(systemName: "arrow.uturn.backward")
                        .font(.body)
                        .foregroundColor(viewModel.drawnObjectCount(for: viewModel.selectedNote) > 0 ? .primary : .secondary.opacity(0.4))
                        .padding(6)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(viewModel.drawnObjectCount(for: viewModel.selectedNote) == 0)
                .help("Desfazer último objeto")
                
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
                do {
                    try viewModel.exportPDF(for: note, to: url)
                } catch {
                    let alert = NSAlert()
                    alert.messageText = "Falha ao exportar PDF"
                    alert.informativeText = "\(error)"
                    alert.alertStyle = .warning
                    alert.runModal()
                }
            }
        }
    }
    
    
    // Reading mode toggle: shows the PDF's default pointer/interactions and
    // suppresses the custom drawing cursor.
    private var readingModeButton: some View {
        let isSelected = !canvasVM.isDrawingMode
        return Button(action: {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                canvasVM.enableReadingMode()
            }
        }) {
            Image(systemName: "cursorarrow")
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
        .help("Leitura (cursor padrão)")
    }

    // Shapes menu: pick a geometric shape to draw by dragging.
    private var shapesMenu: some View {
        let isSelected = canvasVM.isDrawingMode && canvasVM.activeTool == .shape
        return Menu {
            ForEach(ShapeKind.drawable, id: \.self) { kind in
                Button(action: {
                    canvasVM.activeShapeKind = kind
                    canvasVM.selectTool(.shape)
                }) {
                    Label(kind.displayName, systemImage: kind.systemImage)
                }
            }
        } label: {
            Image(systemName: isSelected ? canvasVM.activeShapeKind.systemImage : "square.on.circle")
                .font(.body)
                .foregroundColor(isSelected ? .white : .primary)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(isSelected ? Color.accentColor : Color.clear)
                )
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
        .help("Formas geométricas")
    }

    // Grid menu: choose the cartesian graph-paper style for the current note.
    private var gridMenu: some View {
        let current = GridStyle(rawValue: viewModel.selectedNote?.gridStyle ?? "none") ?? .none
        let isActive = current != .none
        return Menu {
            ForEach(GridStyle.allCases, id: \.self) { style in
                Button(action: {
                    if let note = viewModel.selectedNote {
                        viewModel.setGridStyle(style, for: note)
                    }
                }) {
                    Label(style.displayName, systemImage: current == style ? "checkmark" : style.systemImage)
                }
            }
        } label: {
            Image(systemName: "grid")
                .font(.body)
                .foregroundColor(isActive ? .white : .primary)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(isActive ? Color.accentColor : Color.clear)
                )
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
        .disabled(viewModel.selectedNote == nil)
        .help("Grade / papel milimetrado")
    }

    // Tool selection button view helper
    private func toolButton(tool: ToolType, icon: String) -> some View {
        let isSelected = canvasVM.isDrawingMode && canvasVM.activeTool == tool
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
