import SwiftUI

struct NamePromptView: View {
    let title: LocalizedStringKey
    let fieldLabel: LocalizedStringKey
    let confirmationLabel: LocalizedStringKey
    let onConfirm: (String) -> Void

    var initialName = ""
    var notebookColor: Binding<Color>? = nil

    @Environment(\.dismiss) private var dismiss
    @FocusState private var isNameFocused: Bool
    @State private var name = ""

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text(title)
                .font(PixelTheme.displayFont(size: 18, weight: .bold))
                .foregroundColor(PixelTheme.ink)
                .accessibilityAddTraits(.isHeader)

            TextField(fieldLabel, text: $name)
                .textFieldStyle(.plain)
                .font(PixelTheme.uiFont(size: 13.5))
                .foregroundColor(PixelTheme.ink)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: PixelTheme.controlRadius, style: .continuous)
                        .fill(PixelTheme.paper)
                )
                .overlay {
                    RoundedRectangle(cornerRadius: PixelTheme.controlRadius, style: .continuous)
                        .strokeBorder(
                            isNameFocused ? PixelTheme.accentBorder : PixelTheme.border,
                            lineWidth: isNameFocused ? 1.5 : 1
                        )
                        .allowsHitTesting(false)
                }
                .focused($isNameFocused)

            if let notebookColor {
                ColorPicker("Cor da pasta", selection: notebookColor, supportsOpacity: false)
            }

            HStack(spacing: 10) {
                Spacer()
                Button("Cancelar", role: .cancel) { dismiss() }
                    .buttonStyle(StudioPromptButtonStyle(variant: .secondary))
                    .keyboardShortcut(.cancelAction)

                Button(confirmationLabel, action: confirm)
                    .buttonStyle(StudioPromptButtonStyle(variant: .primary))
                    .keyboardShortcut(.defaultAction)
                    .disabled(trimmedName.isEmpty)
            }
            .padding(.top, 2)
        }
        .padding(24)
        .frame(minWidth: 340)
        .foregroundStyle(PixelTheme.ink)
        .tint(PixelTheme.accent)
        .studioCard(fill: PixelTheme.paper, radius: 14)
        .padding(14)
        .background(PixelTheme.surface)
        .environment(\.colorScheme, .light)
        .onAppear {
            name = initialName
            isNameFocused = true
        }
    }

    private func confirm() {
        let value = trimmedName
        guard !value.isEmpty else { return }
        onConfirm(value)
        dismiss()
    }
}

private struct StudioPromptButtonStyle: ButtonStyle {
    enum Variant {
        case primary
        case secondary
    }

    let variant: Variant

    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(PixelTheme.uiFont(size: 13, weight: variant == .primary ? .semibold : .medium))
            .foregroundColor(variant == .primary ? .white : PixelTheme.ink)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: PixelTheme.controlRadius, style: .continuous)
                    .fill(backgroundColor(isPressed: configuration.isPressed))
            )
            .overlay(
                RoundedRectangle(cornerRadius: PixelTheme.controlRadius, style: .continuous)
                    .strokeBorder(variant == .secondary ? PixelTheme.border : Color.clear, lineWidth: 1)
            )
            .opacity(isEnabled ? 1 : 0.45)
    }

    private func backgroundColor(isPressed: Bool) -> Color {
        switch variant {
        case .primary:
            return isPressed ? PixelTheme.accentDeep : PixelTheme.accent
        case .secondary:
            return isPressed ? PixelTheme.sidebar : PixelTheme.paper
        }
    }
}
