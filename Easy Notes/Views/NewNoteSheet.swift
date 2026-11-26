import SwiftUI

struct NewNoteDraft {
    var title = ""
    var paper: GridStyle = .none
    var orientation: NoteOrientation = .portrait

    static func fromSettings(_ settings: AppSettingsStore = .shared) -> NewNoteDraft {
        NewNoteDraft(
            title: "",
            paper: settings.defaultPaperStyle,
            orientation: settings.defaultNoteOrientation
        )
    }

    @discardableResult
    func create(in model: NoteViewModel) -> Bool {
        let beforeID = model.selectedNote?.id
        let name = title.trimmingCharacters(in: .whitespacesAndNewlines)
        model.addNote(title: name.isEmpty ? "Nova Nota" : name, paper: paper, orientation: orientation)
        guard let created = model.selectedNote else { return false }
        return created.id != beforeID && !created.objectID.isTemporaryID
    }
}

struct NewNoteSheet: View {
    var onCreated: ((Bool) -> Void)? = nil

    @EnvironmentObject private var viewModel: NoteViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var draft = NewNoteDraft.fromSettings()

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Nova nota")
                .font(PixelTheme.uiFont(size: 22, weight: .bold))
                .accessibilityAddTraits(.isHeader)
            Text(viewModel.selectedNotebook?.name ?? "Notas Soltas")
                .foregroundStyle(PixelTheme.inkSecondary)
            TextField("Título", text: $draft.title, prompt: Text("Nova Nota"))
                .textFieldStyle(.roundedBorder)

            Picker("Papel", selection: $draft.paper) {
                ForEach(GridStyle.allCases, id: \.self) { Text($0.paperName).tag($0) }
            }
            Picker("Orientação", selection: $draft.orientation) {
                ForEach(NoteOrientation.allCases, id: \.self) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)

            Canvas { context, size in
                let page = draft.orientation.pageSize
                context.withCGContext { cg in
                    cg.scaleBy(x: size.width / page.width, y: size.height / page.height)
                    renderGrid(style: draft.paper, spacing: 24, origin: draft.orientation.pageCenter,
                               in: CGRect(origin: .zero, size: page), into: cg)
                }
            }
            .aspectRatio(draft.orientation.pageSize, contentMode: .fit)
            .background(.white)
            .border(PixelTheme.border)
            .frame(maxWidth: .infinity)
            .frame(height: 196)
            .padding(12)
            .background(PixelTheme.surface, in: RoundedRectangle(cornerRadius: 8))
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Prévia do papel")
            .accessibilityValue("\(draft.paper.paperName), \(draft.orientation.rawValue)")

            HStack {
                Spacer()
                Button("Cancelar") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("Criar nota") {
                    let created = draft.create(in: viewModel)
                    onCreated?(created)
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
            }
        }
        .font(PixelTheme.uiFont(size: 14))
        .foregroundStyle(PixelTheme.ink)
        .tint(PixelTheme.accent)
        .padding(24)
        .frame(width: 440)
        .background(PixelTheme.paper)
    }
}
