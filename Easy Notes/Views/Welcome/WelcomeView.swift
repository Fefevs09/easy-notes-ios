import SwiftUI

struct WelcomeView: View {
    let onStart: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            EasyNotesBrandMark()
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Easy Notes")

            VStack(alignment: .leading, spacing: 12) {
                Text("Boas-vindas ao Easy Notes")
                    .font(PixelTheme.displayFont(size: 28))
                    .foregroundStyle(PixelTheme.ink)
                    .accessibilityAddTraits(.isHeader)

                Text("Escreva, desenhe e anote PDFs. Organize suas notas em cadernos na biblioteca.")
                    .font(PixelTheme.uiFont(size: 15))
                    .foregroundStyle(PixelTheme.inkSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Button("Começar", action: onStart)
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .keyboardShortcut(.defaultAction)
                .accessibilityHint("Abre a biblioteca")
        }
        .padding(40)
        .frame(maxWidth: 520, alignment: .leading)
        .studioCard()
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(PixelTheme.background)
    }
}
