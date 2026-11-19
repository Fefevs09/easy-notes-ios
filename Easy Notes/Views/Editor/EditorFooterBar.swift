import SwiftUI

struct EditorFooterBar: View {
    let pageCount: Int
    let paperStyle: GridStyle
    @Binding var selectedPageIndex: Int
    @Binding var zoomScale: CGFloat
    var onFitToWidth: (() -> Void)? = nil

    private var currentPageIndex: Int {
        min(max(0, selectedPageIndex), pageCount - 1)
    }

    private var displayPercent: Int {
        Int((zoomScale * 100).rounded())
    }

    private func steppedZoom(_ delta: CGFloat) -> CGFloat {
        let raw = zoomScale + delta
        let rounded = (raw * 10).rounded() / 10
        return min(4.0, max(0.5, rounded))
    }

    var body: some View {
        HStack(spacing: 8) {
            if pageCount > 1 {
                iconButton("chevron.left", label: "Página anterior", isDisabled: currentPageIndex == 0) {
                    selectedPageIndex = max(0, currentPageIndex - 1)
                }
            }

            Text("Página \(currentPageIndex + 1) de \(pageCount)")
                .monospacedDigit()
                .fixedSize()

            if pageCount > 1 {
                iconButton("chevron.right", label: "Próxima página", isDisabled: currentPageIndex == pageCount - 1) {
                    selectedPageIndex = min(pageCount - 1, currentPageIndex + 1)
                }
            }

            Spacer(minLength: 8)

            Text("Papel \(paperStyle.paperName.lowercased())")
                .foregroundStyle(PixelTheme.muted)
                .lineLimit(1)

            Rectangle()
                .fill(PixelTheme.border)
                .frame(width: 1, height: 14)
                .padding(.horizontal, 4)

            iconButton("minus", label: "Diminuir zoom", isDisabled: zoomScale <= 0.501) {
                zoomScale = steppedZoom(-0.1)
            }

            Text("\(displayPercent)%")
                .monospacedDigit()
                .frame(minWidth: 38)
                .accessibilityLabel("Zoom de \(displayPercent) por cento")

            iconButton("plus", label: "Aumentar zoom", isDisabled: zoomScale >= 3.999) {
                zoomScale = steppedZoom(0.1)
            }

            Button {
                if let onFitToWidth {
                    onFitToWidth()
                } else {
                    zoomScale = 1.0
                }
            } label: {
                Text("Ajustar à largura")
                    .font(PixelTheme.uiFont(size: 11, weight: .semibold))
                    .foregroundStyle(PixelTheme.accent)
                    .padding(.vertical, 4)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .fixedSize()
        }
        .font(PixelTheme.uiFont(size: 11, weight: .medium))
        .foregroundStyle(PixelTheme.inkSecondary)
        .padding(.horizontal, 14)
        .frame(height: 36)
        .background(PixelTheme.paper)
        .overlay(alignment: .top) {
            Rectangle().fill(PixelTheme.border).frame(height: 1)
        }
    }

    private func iconButton(
        _ symbol: String,
        label: String,
        isDisabled: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(PixelTheme.uiFont(size: 10, weight: .semibold))
                .foregroundStyle(isDisabled ? PixelTheme.muted : PixelTheme.ink)
                .frame(width: 22, height: 22)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .accessibilityLabel(label)
        .help(label)
    }
}
