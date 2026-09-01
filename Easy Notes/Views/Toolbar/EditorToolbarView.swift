import SwiftUI
import PDFKit
import UniformTypeIdentifiers

struct EditorToolbarView: View {
    @EnvironmentObject var viewModel: NoteViewModel
    @ObservedObject var canvasVM: CanvasViewModel
    @Binding var isSidebarOpen: Bool
    @State private var isSizePopoverPresented = false

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
            if canvasVM.isDrawingMode && canvasVM.activeTool != .select {
                HStack(spacing: 12) {
                    // Quick Preset Colors (eraser has no color of its own)
                    if canvasVM.activeTool != .eraser {
                        HStack(spacing: 5) {
                            presetColorButton(color: .black)
                            presetColorButton(color: .blue)
                            presetColorButton(color: .red)
                            presetColorButton(color: .green)

                            // Custom Color Picker
                            ColorPicker("", selection: Binding(
                                get: { canvasVM.strokeColor },
                                set: { canvasVM.strokeColor = effectiveColor($0) }
                            ))
                                .labelsHidden()
                                .scaleEffect(0.85)
                                .help("Customizar Cor")
                        }

                        Divider().frame(height: 18)
                    }

                    // Width / Eraser Size Control — opens a popover with a
                    // richer size-picker (live preview, presets, fine slider).
                    Button(action: {
                        isSizePopoverPresented.toggle()
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: canvasVM.activeTool == .eraser ? "eraser" : "line.horizontal.3.decrease")
                                .font(.body)
                            Text("\(Int(canvasVM.strokeWidth))pt")
                                .font(.caption)
                                .monospacedDigit()
                        }
                        .foregroundColor(isSizePopoverPresented ? .white : .primary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(isSizePopoverPresented ? Color.accentColor : Color.clear)
                        )
                    }
                    .buttonStyle(.plain)
                    .help(canvasVM.activeTool == .eraser ? "Tamanho da borracha" : "Espessura do traço")
                    .popover(isPresented: $isSizePopoverPresented) {
                        strokeSizePopoverContent
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
    
    // Maps a preset/custom color to what actually gets painted for the active
    // tool — the highlighter always paints translucent, other tools opaque.
    private func effectiveColor(_ base: Color) -> Color {
        canvasVM.activeTool == .highlighter ? base.withAlpha(CanvasViewModel.highlighterOpacity) : base
    }

    // Preset color button view helper
    private func presetColorButton(color: Color) -> some View {
        let display = effectiveColor(color)
        return Button(action: {
            canvasVM.strokeColor = display
        }) {
            Circle()
                .fill(display)
                .frame(width: 14, height: 14)
                .overlay(
                    Circle()
                        .stroke(Color.white, lineWidth: canvasVM.strokeColor == display ? 1.5 : 0)
                )
                .shadow(color: .black.opacity(0.15), radius: 1, x: 0, y: 1)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Stroke / Eraser Size Popover

    /// Active min...max range for the width slider — wider for the eraser.
    private var activeWidthRange: ClosedRange<CGFloat> {
        canvasVM.activeTool == .eraser ? 4...40 : 1...16
    }

    /// Size presets computed proportionally (12% / 35% / 65% / 90%) across the
    /// active tool's range, so the eraser (4...40) and ink tools (1...16) each
    /// get sensible, distinct stops without hardcoding two parallel tables.
    private var sizePresets: [(label: String, value: CGFloat)] {
        let range = activeWidthRange
        let span = range.upperBound - range.lowerBound
        let fractions: [(String, CGFloat)] = [("P", 0.12), ("M", 0.35), ("G", 0.65), ("GG", 0.90)]
        return fractions.map { label, fraction in
            (label, (range.lowerBound + span * fraction).rounded())
        }
    }

    /// Maps the current stroke width into a fixed 8...56pt diameter so the
    /// preview scales visibly but never breaks the popover's layout, whether
    /// the active range is the narrow ink range or the wide eraser range.
    private func previewDiameter(for width: CGFloat) -> CGFloat {
        let range = activeWidthRange
        let clamped = min(max(width, range.lowerBound), range.upperBound)
        let fraction = (clamped - range.lowerBound) / (range.upperBound - range.lowerBound)
        return 8 + fraction * (56 - 8)
    }

    private var strokeSizePopoverContent: some View {
        VStack(spacing: 14) {
            Text(canvasVM.activeTool == .eraser ? "Tamanho da borracha" : "Espessura do traço")
                .font(.headline)

            // Live preview
            Group {
                if canvasVM.activeTool == .eraser {
                    Circle()
                        .fill(Color.secondary.opacity(0.12))
                        .overlay(Circle().stroke(Color.secondary, lineWidth: 1.5))
                } else {
                    Circle()
                        .fill(canvasVM.strokeColor)
                        .shadow(color: .black.opacity(0.15), radius: 1, x: 0, y: 1)
                }
            }
            .frame(width: previewDiameter(for: canvasVM.strokeWidth),
                   height: previewDiameter(for: canvasVM.strokeWidth))
            .frame(width: 64, height: 64)

            // Size presets
            HStack(spacing: 8) {
                ForEach(sizePresets, id: \.label) { preset in
                    let isActive = abs(canvasVM.strokeWidth - preset.value) < 0.75
                    Button(action: {
                        canvasVM.strokeWidth = preset.value
                    }) {
                        Text(preset.label)
                            .font(.caption.weight(.medium))
                            .foregroundColor(isActive ? .white : .primary)
                            .frame(width: 32, height: 24)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(isActive ? Color.accentColor : Color.secondary.opacity(0.15))
                            )
                    }
                    .buttonStyle(.plain)
                }
            }

            // Fine slider
            VStack(spacing: 4) {
                Slider(value: $canvasVM.strokeWidth, in: activeWidthRange)
                    .tint(Color.accentColor)
                Text("\(Int(canvasVM.strokeWidth))pt")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(16)
        .frame(width: 210)
    }
}
