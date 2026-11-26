import SwiftUI

struct NewNoteDraft {
    var title = ""
    var paper: GridStyle = .none
    var orientation: NoteOrientation = .portrait
    var template: NoteTemplate = .blank
    var month = Calendar(identifier: .gregorian).component(.month, from: .now)
    var year = String(Calendar(identifier: .gregorian).component(.year, from: .now))

    var calendarYear: Int? { Int(year.trimmingCharacters(in: .whitespacesAndNewlines)) }

    static func fromSettings(_ settings: AppSettingsStore = .shared) -> NewNoteDraft {
        NewNoteDraft(
            title: "",
            paper: settings.defaultPaperStyle,
            orientation: settings.defaultNoteOrientation
        )
    }

    func create(in model: NoteViewModel, locale: Locale = .current) throws {
        let name = title.trimmingCharacters(in: .whitespacesAndNewlines)
        try model.addNote(title: name.isEmpty ? "Nova Nota" : name, paper: paper, orientation: orientation,
                          template: template, month: month, year: calendarYear, locale: locale)
    }
}

struct NewNoteSheet: View {
    @EnvironmentObject private var viewModel: NoteViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale
    @State private var creationError = ""
    @State private var showsCreationError = false
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

            Picker("Modelo", selection: $draft.template) {
                ForEach(NoteTemplate.allCases, id: \.self) { Text($0.rawValue).tag($0) }
            }

            if draft.template == .monthlyCalendar {
                let months = MonthlyCalendarLayout.calendar(for: locale).standaloneMonthSymbols
                HStack {
                    Picker("Mês", selection: $draft.month) {
                        ForEach(1...12, id: \.self) { Text(months[$0 - 1]).tag($0) }
                    }
                    LabeledContent("Ano") {
                        TextField("Ano", text: $draft.year)
                            .labelsHidden()
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 70)
                    }
                }
            }

            Picker("Papel", selection: $draft.paper) {
                ForEach(GridStyle.allCases, id: \.self) { Text($0.paperName).tag($0) }
            }
            Picker("Orientação", selection: $draft.orientation) {
                ForEach(NoteOrientation.allCases, id: \.self) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)

            preview

            HStack {
                Spacer()
                Button("Cancelar") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("Criar nota") {
                    do {
                        try draft.create(in: viewModel, locale: locale)
                        dismiss()
                    } catch {
                        creationError = error.localizedDescription
                        showsCreationError = true
                    }
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
        .alert("Falha ao criar nota", isPresented: $showsCreationError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(creationError)
        }
    }

    private var preview: some View {
        let pdf = try? NoteTemplatePDF.make(draft.template, month: draft.month, year: draft.calendarYear,
                                            orientation: draft.orientation, locale: locale)
        let page = pdf?.document.page(at: 1)
        let description = "\(draft.template.rawValue), \(draft.paper.paperName), \(draft.orientation.rawValue)"
        return VStack {
            if let page {
                Canvas { context, size in
                    let pageSize = draft.orientation.pageSize
                    context.withCGContext { cg in
                        cg.translateBy(x: 0, y: size.height)
                        cg.scaleBy(x: size.width / pageSize.width, y: -size.height / pageSize.height)
                        cg.drawPDFPage(page)
                        renderGrid(style: draft.paper, spacing: 24, origin: draft.orientation.pageCenter,
                                   in: CGRect(origin: .zero, size: pageSize), into: cg)
                    }
                }
                .aspectRatio(draft.orientation.pageSize, contentMode: .fit)
                .background(.white)
                .border(PixelTheme.border)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Prévia da nota")
                .accessibilityValue(previewAccessibilityValue(description))
            } else {
                Text("Prévia indisponível")
                    .foregroundStyle(PixelTheme.inkSecondary)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 196)
        .padding(12)
        .background(PixelTheme.surface, in: RoundedRectangle(cornerRadius: 8))
    }

    private func previewAccessibilityValue(_ description: String) -> String {
        guard draft.template == .monthlyCalendar, let year = draft.calendarYear,
              let layout = try? MonthlyCalendarLayout(month: draft.month, year: year, locale: locale) else {
            return description
        }
        return "\(description), \(layout.title)"
    }
}
