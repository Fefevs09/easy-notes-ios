import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct EditorToolbarView: View {
    @EnvironmentObject var viewModel: NoteViewModel
    @ObservedObject var canvasVM: CanvasViewModel
    @Binding var isSidebarOpen: Bool
    var onBackToLibrary: (() -> Void)? = nil

    @Environment(\.displayScale) private var displayScale
    @State private var isSizePopoverPresented = false
    @State private var isNoteSettingsPresented = false
    @State private var isColorPopoverPresented = false
    @State private var hoveredPresetName: String? = nil

    private var isPenTool: Bool {
        switch canvasVM.activeTool {
        case .fountainPen, .calligraphy, .pencil: true
        default: false
        }
    }

    private var contextualTool: ToolType {
        canvasVM.isDrawingMode ? canvasVM.activeTool : .select
    }

    private var strokeSizeTitle: String {
        canvasVM.activeTool == .eraser ? "Tamanho da borracha" : "Espessura do traço"
    }

    var body: some View {
        VStack(spacing: 0) {
            primaryBar
            contextualBar
        }
        .onChange(of: contextualTool) { _, _ in
            isSizePopoverPresented = false
            isColorPopoverPresented = false
        }
        .onChange(of: viewModel.selectedNote?.id) { _, _ in
            isNoteSettingsPresented = false
        }
    }

    private var primaryBar: some View {
        let canUndo = viewModel.drawnObjectCount(for: viewModel.selectedNote) > 0

        return HStack(spacing: 6) {
            Button {
                if let onBackToLibrary {
                    onBackToLibrary()
                } else {
                    viewModel.selectedNote = nil
                }
            } label: {
                primaryLabel("Biblioteca", icon: "arrow.left")
            }
            .buttonStyle(.plain)

            separator

            primaryTool("Seleção", icon: "cursorarrow", isSelected: contextualTool == .select) {
                canvasVM.enableReadingMode()
            }

            primaryTool("Caneta", icon: "pencil.tip", isSelected: canvasVM.isDrawingMode && isPenTool) {
                if !canvasVM.isDrawingMode || !isPenTool {
                    canvasVM.selectTool(isPenTool ? canvasVM.activeTool : .fountainPen)
                }
            }

            primaryTool("Marca-texto", icon: "highlighter", isSelected: contextualTool == .highlighter) {
                if contextualTool != .highlighter {
                    canvasVM.selectTool(.highlighter)
                }
            }

            primaryTool("Borracha", icon: "eraser", isSelected: contextualTool == .eraser) {
                if contextualTool != .eraser {
                    canvasVM.selectTool(.eraser)
                }
            }

            shapesMenu
            separator

            Button {
                viewModel.undoLastObject()
            } label: {
                iconLabel("arrow.uturn.backward", color: canUndo ? PixelTheme.inkSecondary : PixelTheme.muted.opacity(0.5))
            }
            .buttonStyle(.plain)
            .disabled(!canUndo)
            .accessibilityLabel("Desfazer último objeto")
            .help("Desfazer último objeto")

            Spacer()

            Button {
                withAnimation {
                    isSidebarOpen.toggle()
                }
            } label: {
                iconLabel(
                    isSidebarOpen ? "sidebar.squares.left" : "sidebar.left",
                    color: isSidebarOpen ? PixelTheme.accent : PixelTheme.inkSecondary
                )
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isSidebarOpen ? "Ocultar painel lateral" : "Mostrar painel lateral")
            .help(isSidebarOpen ? "Ocultar painel lateral" : "Mostrar painel lateral")

            noteSettingsButton
            optionsMenu
        }
        .modifier(ToolbarRow(height: 46, fill: PixelTheme.paper, hairline: 1 / displayScale))
    }

    private var shapesMenu: some View {
        Menu {
            ForEach(ShapeKind.drawable, id: \.self) { kind in
                Button {
                    canvasVM.activeShapeKind = kind
                    canvasVM.selectTool(.shape)
                } label: {
                    Label(kind.displayName, systemImage: kind.systemImage)
                }
            }
        } label: {
            primaryLabel("Formas", icon: "square.on.circle", isSelected: contextualTool == .shape)
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
        .help("Formas geométricas")
    }

    private var noteSettingsButton: some View {
        Button {
            isNoteSettingsPresented.toggle()
        } label: {
            iconLabel("gearshape", color: isNoteSettingsPresented ? PixelTheme.accent : PixelTheme.inkSecondary)
        }
        .buttonStyle(.plain)
        .disabled(viewModel.selectedNote == nil)
        .accessibilityLabel("Configurações da nota")
        .help("Configurações da nota")
        .popover(isPresented: $isNoteSettingsPresented, arrowEdge: .top) {
            if let note = viewModel.selectedNote {
                NoteSettingsPopover(note: note) { style in
                    guard viewModel.selectedNote === note,
                          style != (GridStyle(rawValue: note.gridStyle) ?? .none) else { return }
                    viewModel.setGridStyle(style, for: note)
                }
            }
        }
    }

    private var optionsMenu: some View {
        Menu {
            Button("Exportar como PDF", action: exportPDF)
                .disabled(viewModel.selectedNote == nil)
        } label: {
            iconLabel("ellipsis")
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
        .accessibilityLabel("Mais opções")
        .help("Mais opções")
    }

    private var contextualBar: some View {
        HStack(spacing: 10) {
            switch contextualTool {
            case .fountainPen, .calligraphy, .pencil:
                Text("CANETA").studioSectionHeader().fixedSize()
                penOptions
                separator
                colorOptions
                separator
                sizeOptions("Espessura")
                Spacer(minLength: 0)
                hint("Escreva do seu jeito")

            case .highlighter:
                Text("MARCA-TEXTO").studioSectionHeader().fixedSize()
                colorOptions
                separator
                sizeOptions("Espessura")
                separator
                HStack(spacing: 6) {
                    optionLabel("Opacidade")
                    Text("\(Int(CanvasViewModel.highlighterOpacity * 100))%")
                        .monospacedDigit()
                        .modifier(OptionPill())
                        .fixedSize()
                }
                Spacer(minLength: 0)
                hint("Anote e destaque sem alterar o original")

            case .eraser:
                Text("BORRACHA").studioSectionHeader().fixedSize()
                sizeOptions("Tamanho")
                Spacer(minLength: 0)
                hint("Apague traços livres")

            case .shape:
                Text("FORMAS").studioSectionHeader().fixedSize()
                colorOptions
                separator
                sizeOptions("Espessura")
                separator
                segmentButton("Preencher", isSelected: canvasVM.shapeFillEnabled) {
                    canvasVM.shapeFillEnabled.toggle()
                }
                segmentButton("Selecionar formas", isSelected: false) {
                    canvasVM.selectTool(.select)
                }
                Spacer(minLength: 0)

            case .select:
                Text("SELEÇÃO").studioSectionHeader().fixedSize()
                selectionOptions
                Spacer(minLength: 0)
                hint("Navegue no documento ou mova formas")
            }
        }
        .modifier(ToolbarRow(height: 40, fill: PixelTheme.surface, hairline: 1 / displayScale))
    }

    private var penOptions: some View {
        HStack(spacing: 2) {
            penButton("Tinteiro", tool: .fountainPen)
            penButton("Caligráfica", tool: .calligraphy)
            penButton("Lápis", tool: .pencil)
        }
        .padding(2)
        .modifier(OptionBorder())
        .fixedSize()
    }

    private func penButton(_ title: LocalizedStringKey, tool: ToolType) -> some View {
        segmentButton(title, isSelected: canvasVM.activeTool == tool) {
            if canvasVM.activeTool != tool {
                canvasVM.selectTool(tool)
            }
        }
    }

    private var selectionOptions: some View {
        HStack(spacing: 2) {
            segmentButton("Leitura", isSelected: !canvasVM.isDrawingMode) {
                canvasVM.enableReadingMode()
            }
            segmentButton("Selecionar formas", isSelected: canvasVM.isDrawingMode) {
                canvasVM.selectTool(.select)
            }
        }
        .padding(2)
        .modifier(OptionBorder())
        .fixedSize()
    }

    private var colorOptions: some View {
        HStack(spacing: 6) {
            optionLabel("Cor")
            ForEach(PixelTheme.presetSwatchDefinitions, id: \.name) { swatch in
                presetColorButton(swatch.color, name: swatch.name)
            }

            PenColorTriggerButton(
                color: canvasVM.strokeColor,
                toolContext: canvasVM.colorToolContext,
                isOpen: isColorPopoverPresented
            ) {
                isSizePopoverPresented = false
                isColorPopoverPresented.toggle()
            }
            .popover(isPresented: $isColorPopoverPresented, arrowEdge: .bottom) {
                PenColorPopoverView(
                    color: Binding(
                        get: { canvasVM.strokeColor },
                        set: { canvasVM.applyStrokeColor($0) }
                    ),
                    toolContext: canvasVM.colorToolContext,
                    onClose: { isColorPopoverPresented = false }
                )
                .presentationBackground(PixelTheme.paper)
            }
        }
        .fixedSize()
    }

    private func presetColorButton(_ color: Color, name: String) -> some View {
        let activeComponents = PenColorComponents.from(canvasVM.strokeColor)
        let displayOpacity = canvasVM.activeTool == .highlighter
            ? Double(CanvasViewModel.highlighterOpacity)
            : PenColorComponents.clampedOpacity(activeComponents.opacity, for: canvasVM.colorToolContext)
        let display = PenColorComponents.from(color).withOpacity(displayOpacity).swiftUIColor
        let isSelected = activeComponents.matchesPreset(color)
        let isHovered = hoveredPresetName == name
        let borderColor: Color = isSelected
            ? PixelTheme.accent
            : (isHovered ? PixelTheme.inkSecondary : PixelTheme.borderStrong)

        return Button {
            canvasVM.applyPresetColor(color)
        } label: {
            ZStack {
                Circle()
                    .fill(PixelTheme.paper)

                Circle()
                    .fill(display)
                    .frame(width: 16, height: 16)

                Circle()
                    .strokeBorder(borderColor, lineWidth: isSelected ? 1.5 : 1)

                if isSelected {
                    Image(systemName: "checkmark")
                        .font(PixelTheme.uiFont(size: 7.5, weight: .bold))
                        .foregroundStyle(PixelTheme.ink)
                        .frame(width: 12, height: 12)
                        .background(PixelTheme.paper.opacity(0.90), in: Circle())
                }
            }
            .frame(width: 22, height: 22)
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            hoveredPresetName = hovering ? name : (hoveredPresetName == name ? nil : hoveredPresetName)
        }
        .accessibilityLabel(Text("Cor \(name)"))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .help("\(name) (\(PenColorComponents.from(color).hex6))")
    }

    private func sizeOptions(_ title: LocalizedStringKey) -> some View {
        HStack(spacing: 6) {
            optionLabel(title)
            Button {
                isColorPopoverPresented = false
                isSizePopoverPresented.toggle()
            } label: {
                HStack(spacing: 5) {
                    Text("\(Int(canvasVM.strokeWidth)) pt")
                        .monospacedDigit()
                    Image(systemName: "chevron.down")
                        .font(PixelTheme.uiFont(size: 9, weight: .semibold))
                }
                .modifier(OptionPill())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(strokeSizeTitle)
            .accessibilityValue("\(Int(canvasVM.strokeWidth)) pt")
            .help(strokeSizeTitle)
            .popover(isPresented: $isSizePopoverPresented) {
                strokeSizePopoverContent
            }
        }
        .fixedSize()
    }

    private var separator: some View {
        Rectangle()
            .fill(PixelTheme.border)
            .frame(width: 1 / displayScale, height: 20)
            .accessibilityHidden(true)
    }

    private func primaryTool(
        _ title: LocalizedStringKey, icon: String, isSelected: Bool, action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            primaryLabel(title, icon: icon, isSelected: isSelected)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private func primaryLabel(_ title: LocalizedStringKey, icon: String, isSelected: Bool = false) -> some View {
        Label(title, systemImage: icon)
            .labelStyle(.titleAndIcon)
            .font(PixelTheme.uiFont(size: 12, weight: .medium))
            .foregroundStyle(isSelected ? PixelTheme.accent : PixelTheme.inkSecondary)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .studioActiveTool(isSelected)
            .contentShape(Rectangle())
            .fixedSize()
    }

    private func iconLabel(_ icon: String, color: Color = PixelTheme.inkSecondary) -> some View {
        Image(systemName: icon)
            .font(PixelTheme.uiFont(size: 13, weight: .medium))
            .foregroundStyle(color)
            .frame(width: 26, height: 26)
            .contentShape(Rectangle())
    }

    private func segmentButton(_ title: LocalizedStringKey, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(PixelTheme.uiFont(size: 11, weight: .medium))
                .foregroundStyle(isSelected ? PixelTheme.accent : PixelTheme.inkSecondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    isSelected ? PixelTheme.accentSoft : PixelTheme.paper,
                    in: RoundedRectangle(cornerRadius: PixelTheme.pillRadius)
                )
                .contentShape(Rectangle())
                .fixedSize()
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private func optionLabel(_ title: LocalizedStringKey) -> some View {
        Text(title)
            .font(PixelTheme.uiFont(size: 11, weight: .medium))
            .foregroundStyle(PixelTheme.muted)
    }

    private func hint(_ title: LocalizedStringKey) -> some View {
        Text(title)
            .font(PixelTheme.uiFont(size: 11.5))
            .foregroundStyle(PixelTheme.muted)
            .lineLimit(1)
            .truncationMode(.tail)
            .layoutPriority(-1)
    }

    private func exportPDF() {
        guard let note = viewModel.selectedNote else { return }

        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [.pdf]
        savePanel.nameFieldStringValue = note.suggestedPDFName
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

    // MARK: - Stroke / Eraser Size Popover

    /// Active min...max range for the width slider — wider for the eraser and highlighter.
    private var activeWidthRange: ClosedRange<CGFloat> {
        switch canvasVM.activeTool {
        case .eraser: return 4...40
        case .highlighter: return 8...36
        default: return 1...16
        }
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
            Text(strokeSizeTitle)
                .font(PixelTheme.uiFont(size: 13, weight: .semibold))
                .foregroundStyle(PixelTheme.ink)

            let diameter = previewDiameter(for: canvasVM.strokeWidth)
            Circle()
                .fill(canvasVM.activeTool == .eraser ? PixelTheme.border : canvasVM.strokeColor)
                .overlay {
                    if canvasVM.activeTool == .eraser {
                        Circle().strokeBorder(PixelTheme.muted, lineWidth: 1.5)
                    }
                }
                .frame(width: diameter, height: diameter)
                .frame(width: 64, height: 64)
                .accessibilityHidden(true)

            HStack(spacing: 6) {
                ForEach(sizePresets, id: \.label) { preset in
                    segmentButton(
                        LocalizedStringKey(preset.label),
                        isSelected: abs(canvasVM.strokeWidth - preset.value) < 0.75
                    ) {
                        canvasVM.strokeWidth = preset.value
                    }
                }
            }
            .padding(2)
            .modifier(OptionBorder())

            VStack(spacing: 4) {
                Slider(value: $canvasVM.strokeWidth, in: activeWidthRange) {
                    Text(strokeSizeTitle)
                }
                .labelsHidden()
                .tint(PixelTheme.accent)

                Text("\(Int(canvasVM.strokeWidth)) pt")
                    .font(PixelTheme.uiFont(size: 11))
                    .monospacedDigit()
                    .foregroundStyle(PixelTheme.muted)
            }
        }
        .padding(16)
        .frame(width: 210)
        .studioCard()
        .background(PixelTheme.paper)
    }

    private struct ToolbarRow: ViewModifier {
        let height: CGFloat
        let fill: Color
        let hairline: CGFloat

        func body(content: Content) -> some View {
            content
                .padding(.horizontal, 16)
                .frame(height: height)
                .background(fill)
                .overlay(alignment: .bottom) {
                    Rectangle().fill(PixelTheme.border).frame(height: hairline)
                }
        }
    }

    private struct OptionBorder: ViewModifier {
        func body(content: Content) -> some View {
            let outline = RoundedRectangle(cornerRadius: PixelTheme.controlRadius)
            content
                .background(PixelTheme.paper, in: outline)
                .overlay {
                    outline.strokeBorder(PixelTheme.border)
                        .allowsHitTesting(false)
                }
        }
    }

    private struct OptionPill: ViewModifier {
        func body(content: Content) -> some View {
            content
                .font(PixelTheme.uiFont(size: 11, weight: .medium))
                .foregroundStyle(PixelTheme.inkSecondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .modifier(OptionBorder())
        }
    }
}
