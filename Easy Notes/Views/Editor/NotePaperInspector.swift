import SwiftUI

struct NotePaperInspector: View {
    @ObservedObject var note: Note
    let title: String

    private var relativeEditDate: String {
        note.updatedAt.formatted(.relative(presentation: .named).locale(Locale(identifier: "pt_BR")))
    }

    var body: some View {
        VStack(spacing: 12) {
            ScrollView {
                VStack(alignment: .leading, spacing: 6) {
                    Text("SUA NOTA")
                        .studioSectionHeader()
                    Text(title.isEmpty ? "Sem título" : title)
                        .font(PixelTheme.uiFont(size: 14, weight: .semibold))
                        .foregroundStyle(PixelTheme.ink)
                        .lineLimit(2)
                    Text("Caderno · \(note.notebook?.path ?? "Notas Soltas")")
                        .foregroundStyle(PixelTheme.accent)
                        .lineLimit(1)
                    Text("Editada \(relativeEditDate)")
                        .foregroundStyle(PixelTheme.muted)
                }
                .font(PixelTheme.uiFont(size: 12))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Seu traço, suas ideias.")
                    .font(PixelTheme.uiFont(size: 12, weight: .semibold))
                    .foregroundStyle(PixelTheme.ink)
                Text("Use a caneta ou a mesa digitalizadora.")
                    .font(PixelTheme.uiFont(size: 11))
                    .foregroundStyle(PixelTheme.inkSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(PixelTheme.sidebar, in: RoundedRectangle(cornerRadius: 10))
            .padding(.horizontal, 14)
            .padding(.bottom, 14)
        }
    }
}

struct NoteSettingsPopover: View {
    @ObservedObject var note: Note
    @State private var hexInput = ""
    let selectColor: (NSColor) -> Void
    let selectPaper: (GridStyle) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Configurações da nota")
                .font(PixelTheme.uiFont(size: 13, weight: .semibold))
                .foregroundStyle(PixelTheme.ink)
                .accessibilityAddTraits(.isHeader)
                .padding(.bottom, 4)

            Text("PAPEL")
                .studioSectionHeader()

            ForEach(GridStyle.allCases, id: \.self) { style in
                paperCard(style)
            }

            if let style = GridStyle(rawValue: note.gridStyle), style != .none {
                ColorPicker("Cor da grade", selection: Binding(
                    get: { Color(nsColor: note.gridInk) },
                    set: { selectColor(NSColor($0)) }
                ), supportsOpacity: false)
                .accessibilityValue(note.gridInk.hexString)

                TextField("Hexadecimal", text: $hexInput)
                    .textFieldStyle(.roundedBorder)
                    .accessibilityLabel("Cor da grade em hexadecimal")
                    .onChange(of: note.gridInk.hexString, initial: true) { _, hex in
                        hexInput = hex
                    }
                    .onSubmit {
                        if let components = PenColorComponents.fromHex(hexInput) {
                            selectColor(NSColor(components.opaqueColor))
                        }
                        hexInput = note.gridInk.hexString
                    }
            }
        }
        .padding(16)
        .frame(width: 248)
        .background(PixelTheme.paper)
    }

    private func paperCard(_ style: GridStyle) -> some View {
        let isSelected = style == (GridStyle(rawValue: note.gridStyle) ?? .none)

        return Button {
            selectPaper(style)
        } label: {
            HStack(spacing: 8) {
                PaperStylePreview(style: style, color: Color(nsColor: note.gridInk))
                    .accessibilityHidden(true)

                Text(style.paperName)
                    .font(PixelTheme.uiFont(size: 12, weight: isSelected ? .semibold : .medium))
                    .foregroundStyle(PixelTheme.ink)

                Spacer(minLength: 0)

                if isSelected {
                    Image(systemName: "checkmark")
                        .font(PixelTheme.uiFont(size: 11, weight: .semibold))
                        .foregroundStyle(PixelTheme.accent)
                        .accessibilityHidden(true)
                }
            }
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .contentShape(Rectangle())
            .studioCard(
                fill: isSelected ? PixelTheme.accentSoft : PixelTheme.paper,
                radius: 8,
                borderColor: isSelected ? PixelTheme.accentBorder : PixelTheme.border
            )
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

private struct PaperStylePreview: View {
    let style: GridStyle
    let color: Color

    var body: some View {
        Canvas { context, _ in
            let ink = GraphicsContext.Shading.color(color)

            switch style {
            case .none:
                break
            case .lines, .grid:
                for y in stride(from: 6.0, through: 22.0, by: 4.0) {
                    context.fill(Path(CGRect(x: 4, y: y, width: 16, height: 0.5)), with: ink)
                }
                if style == .grid {
                    for x in stride(from: 4.0, through: 20.0, by: 4.0) {
                        context.fill(Path(CGRect(x: x, y: 6, width: 0.5, height: 16)), with: ink)
                    }
                }
            case .dots:
                for y in stride(from: 6.0, through: 22.0, by: 4.0) {
                    for x in stride(from: 5.0, through: 17.0, by: 4.0) {
                        context.fill(Path(ellipseIn: CGRect(x: x, y: y, width: 1, height: 1)), with: ink)
                    }
                }
            }
        }
        .frame(width: 24, height: 28)
        .background(PixelTheme.paper, in: RoundedRectangle(cornerRadius: 3))
        .overlay {
            RoundedRectangle(cornerRadius: 3)
                .strokeBorder(PixelTheme.border, lineWidth: 1)
        }
    }
}

extension GridStyle {
    var paperName: String {
        switch self {
        case .none: "Liso"
        case .lines: "Pautado"
        case .grid: "Quadriculado"
        case .dots: "Pontilhado"
        }
    }
}
