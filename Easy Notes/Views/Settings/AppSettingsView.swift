import AppKit
import SwiftUI

enum SettingsTab: String, CaseIterable, Identifiable {
    case general
    case appearance
    case pensAndColors
    case paperAndNotes
    case storage
    case export
    case about

    var id: String { rawValue }

    var title: String {
        switch self {
        case .general: return "Geral"
        case .appearance: return "Aparência"
        case .pensAndColors: return "Canetas e Cores"
        case .paperAndNotes: return "Papel e Notas"
        case .storage: return "Armazenamento"
        case .export: return "Exportação"
        case .about: return "Sobre"
        }
    }

    var systemImage: String {
        switch self {
        case .general: return "slider.horizontal.3"
        case .appearance: return "paintpalette"
        case .pensAndColors: return "pencil.tip"
        case .paperAndNotes: return "doc.text"
        case .storage: return "externaldrive"
        case .export: return "square.and.arrow.up"
        case .about: return "info.circle"
        }
    }

    var sectionTitle: String? {
        switch self {
        case .general, .appearance: return nil
        case .pensAndColors, .paperAndNotes: return "CANETAS E DESENHO"
        case .storage, .export: return "DADOS E EXPORTAÇÃO"
        case .about: return "APLICATIVO"
        }
    }

    var searchKeywords: [String] {
        switch self {
        case .general:
            return ["geral", "comportamento", "excluir", "caderno", "lixeira", "confirmacao", "confirmação", "restaurar", "padroes", "padrões"]
        case .appearance:
            return ["aparencia", "aparência", "tema", "temas", "claro", "escuro", "sistema", "esquema", "cores", "contraste", "opacidade", "interface", "lavanda", "salvia", "sálvia", "terracota", "oceano", "ambar", "âmbar"]
        case .pensAndColors:
            return ["caneta", "canetas", "cor", "cores", "marca-texto", "marcador", "borracha", "espessura", "atalho", "presets", "paleta"]
        case .paperAndNotes:
            return ["papel", "notas", "grade", "linhas", "quadriculado", "pontos", "orientacao", "orientação", "vertical", "horizontal", "nova nota"]
        case .storage:
            return ["armazenamento", "pasta", "dados", "sqlite", "core data", "finder", "backup", "local", "migrar"]
        case .export:
            return ["exportacao", "exportação", "pdf", "pasta", "grade", "papel"]
        case .about:
            return ["sobre", "versao", "versão", "easy notes", "restaurar", "reset"]
        }
    }

    func matches(query: String) -> Bool {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return true }
        let normalized = trimmed.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
        if title.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current).contains(normalized) {
            return true
        }
        return searchKeywords.contains { keyword in
            keyword.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current).contains(normalized)
        }
    }
}

struct AppSettingsView: View {
    @EnvironmentObject var settings: AppSettingsStore
    @EnvironmentObject var viewModel: NoteViewModel

    @State private var selectedTab: SettingsTab = .appearance
    @State private var searchQuery: String = ""
    @State private var hoveredTab: SettingsTab? = nil
    @State private var isConfirmingResetAll = false
    @State private var storageFeedback: StorageFeedback? = nil
    @FocusState private var isSearchFocused: Bool

    private struct StorageFeedback: Equatable {
        let isError: Bool
        let message: String
    }

    private var filteredTabs: [SettingsTab] {
        SettingsTab.allCases.filter { $0.matches(query: searchQuery) }
    }

    private var groupedTabs: [(section: String?, tabs: [SettingsTab])] {
        var result: [(section: String?, tabs: [SettingsTab])] = []
        for tab in filteredTabs {
            if let last = result.last, last.section == tab.sectionTitle {
                result[result.count - 1].tabs.append(tab)
            } else {
                result.append((section: tab.sectionTitle, tabs: [tab]))
            }
        }
        return result
    }

    var body: some View {
        HStack(spacing: 0) {
            sidebarColumn
                .frame(width: 224)

            Rectangle()
                .fill(PixelTheme.border)
                .frame(width: 1)

            detailColumn
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(minWidth: 740, idealWidth: 820, minHeight: 520, idealHeight: 600)
        .background(PixelTheme.background)
        .preferredColorScheme(settings.appearanceMode.preferredColorScheme)
        .tint(PixelTheme.accent)
        .onChange(of: searchQuery) { _, _ in
            if !filteredTabs.contains(selectedTab), let first = filteredTabs.first {
                selectedTab = first
            }
        }
        .onKeyPress(characters: CharacterSet(charactersIn: "/")) { _ in
            guard !isSearchFocused, !isEditingTextInKeyWindow() else {
                return .ignored
            }
            isSearchFocused = true
            return .handled
        }
        .alert("Restaurar todas as configurações?", isPresented: $isConfirmingResetAll) {
            Button("Restaurar padrões", role: .destructive) {
                settings.resetAll()
                storageFeedback = nil
            }
            Button("Cancelar", role: .cancel) {}
        } message: {
            Text("Todas as preferências de aparência, canetas, papel, armazenamento e exportação voltarão aos valores originais. Suas notas não serão apagadas.")
        }
    }

    // MARK: - Left Navigation Column

    private var sidebarColumn: some View {
        VStack(spacing: 0) {
            searchField
                .padding(.horizontal, 12)
                .padding(.top, 14)
                .padding(.bottom, 10)

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    if groupedTabs.isEmpty {
                        VStack(spacing: 6) {
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 16))
                                .foregroundStyle(PixelTheme.muted)
                            Text("Nenhuma opção encontrada")
                                .font(PixelTheme.uiFont(size: 12))
                                .foregroundStyle(PixelTheme.muted)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.top, 24)
                    } else {
                        ForEach(Array(groupedTabs.enumerated()), id: \.offset) { _, group in
                            VStack(alignment: .leading, spacing: 3) {
                                if let sectionTitle = group.section {
                                    Text(sectionTitle)
                                        .studioSectionHeader()
                                        .padding(.horizontal, 10)
                                        .padding(.bottom, 3)
                                }

                                ForEach(group.tabs) { tab in
                                    sidebarRow(for: tab)
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 10)
                .padding(.bottom, 16)
            }
            .scrollIndicators(.hidden)
        }
        .background(PixelTheme.sidebar)
    }

    private var searchField: some View {
        HStack(spacing: 7) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(PixelTheme.muted)
                .accessibilityHidden(true)

            TextField("Buscar…", text: $searchQuery)
                .textFieldStyle(.plain)
                .font(PixelTheme.uiFont(size: 12.5))
                .foregroundStyle(PixelTheme.ink)
                .focused($isSearchFocused)
                .accessibilityLabel("Buscar configurações")

            if !searchQuery.isEmpty {
                Button {
                    searchQuery = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(PixelTheme.muted)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Limpar busca")
            } else {
                Text("/")
                    .font(PixelTheme.displayFont(size: 10, weight: .semibold))
                    .foregroundStyle(PixelTheme.muted)
                    .frame(width: 18, height: 18)
                    .background(
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .fill(PixelTheme.surface)
                    )
                    .overlay {
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .strokeBorder(PixelTheme.border, lineWidth: 1)
                    }
                    .accessibilityHidden(true)
            }
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: PixelTheme.controlRadius, style: .continuous)
                .fill(PixelTheme.paper)
        )
        .overlay {
            RoundedRectangle(cornerRadius: PixelTheme.controlRadius, style: .continuous)
                .strokeBorder(isSearchFocused ? PixelTheme.accentBorder : PixelTheme.border, lineWidth: isSearchFocused ? 1.5 : 1)
        }
    }

    private func sidebarRow(for tab: SettingsTab) -> some View {
        let isSelected = selectedTab == tab
        let isHovered = hoveredTab == tab

        return Button {
            withAnimation(.easeInOut(duration: 0.14)) {
                selectedTab = tab
            }
        } label: {
            HStack(spacing: 9) {
                Image(systemName: tab.systemImage)
                    .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
                    .foregroundStyle(isSelected ? PixelTheme.accent : PixelTheme.inkSecondary)
                    .frame(width: 18)

                Text(tab.title)
                    .font(PixelTheme.uiFont(size: 13, weight: isSelected ? .semibold : .medium))
                    .foregroundStyle(isSelected ? PixelTheme.accent : PixelTheme.ink)
                    .lineLimit(1)

                Spacer(minLength: 4)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: PixelTheme.pillRadius, style: .continuous)
                    .fill(isSelected ? PixelTheme.accentSoft : (isHovered ? PixelTheme.sidebarElevated : Color.clear))
            )
            .contentShape(RoundedRectangle(cornerRadius: PixelTheme.pillRadius, style: .continuous))
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            hoveredTab = hovering ? tab : (hoveredTab == tab ? nil : hoveredTab)
        }
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    // MARK: - Right Content Column

    private var detailColumn: some View {
        VStack(spacing: 0) {
            HStack(spacing: 6) {
                Text("Configurações")
                    .font(PixelTheme.uiFont(size: 13, weight: .medium))
                    .foregroundStyle(PixelTheme.muted)

                Text("/")
                    .font(PixelTheme.uiFont(size: 13))
                    .foregroundStyle(PixelTheme.muted.opacity(0.7))
                    .accessibilityHidden(true)

                Text(selectedTab.title)
                    .font(PixelTheme.uiFont(size: 13.5, weight: .semibold))
                    .foregroundStyle(PixelTheme.ink)
                    .accessibilityAddTraits(.isHeader)

                Spacer()
            }
            .padding(.horizontal, 24)
            .frame(height: 46)
            .background(PixelTheme.paper)

            Rectangle()
                .fill(PixelTheme.border)
                .frame(height: 1)

            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    switch selectedTab {
                    case .general:
                        generalSection
                    case .appearance:
                        appearanceSection
                    case .pensAndColors:
                        pensAndColorsSection
                    case .paperAndNotes:
                        paperAndNotesSection
                    case .storage:
                        storageSection
                    case .export:
                        exportSection
                    case .about:
                        aboutSection
                    }
                }
                .padding(24)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(PixelTheme.background)
        }
    }

    // MARK: - 1. Geral

    private var generalSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            settingsSection(title: "Confirmações de segurança", subtitle: "Evite ações destrutivas acidentais ao organizar sua biblioteca.") {
                VStack(spacing: 0) {
                    toggleRow(
                        title: "Confirmar ao excluir caderno",
                        subtitle: "Exibe um alerta perguntando se deseja manter ou mover as notas para a Lixeira.",
                        isOn: $settings.confirmBeforeDeletingNotebook
                    )

                    divider

                    toggleRow(
                        title: "Confirmar ao esvaziar a lixeira",
                        subtitle: "Solicita confirmação antes de remover permanentemente as notas na Lixeira.",
                        isOn: $settings.confirmBeforeEmptyingTrash
                    )
                }
            }

            settingsSection(title: "Redefinição", subtitle: "Volte todas as preferências para os valores padrão sem afetar suas notas.") {
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Restaurar padrões")
                            .font(PixelTheme.uiFont(size: 13, weight: .semibold))
                            .foregroundStyle(PixelTheme.ink)
                        Text("Reinicia aparência, cores de caneta, papel padrão e pasta de exportação.")
                            .font(PixelTheme.uiFont(size: 11.5))
                            .foregroundStyle(PixelTheme.muted)
                    }
                    Spacer(minLength: 12)
                    Button("Restaurar padrões…", role: .destructive) {
                        isConfirmingResetAll = true
                    }
                    .buttonStyle(.bordered)
                }
                .padding(14)
            }
        }
    }

    // MARK: - 2. Aparência

    private var appearanceSection: some View {
        VStack(alignment: .leading, spacing: 22) {
            settingsSection(title: "Esquema de cores", subtitle: "Escolha como o Easy Notes se adapta ao tema do macOS.") {
                HStack(spacing: 12) {
                    ForEach(AppAppearanceMode.allCases) { mode in
                        appearanceModeCard(mode)
                    }
                }
                .padding(14)
            }

            settingsSection(title: "Temas", subtitle: "Defina a cor de destaque editorial da interface em modo claro e escuro.") {
                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: 148, maximum: 200), spacing: 10)],
                    spacing: 10
                ) {
                    ForEach(AppThemePreset.allCases) { preset in
                        themePresetCard(preset)
                    }
                }
                .padding(14)
            }

            settingsSection(title: "Interface", subtitle: "Ajuste o conforto visual e a translucidez das superfícies.") {
                VStack(spacing: 0) {
                    sliderRow(
                        title: "Contraste",
                        subtitle: "Ajusta o contraste visual dos controles da interface.",
                        value: $settings.interfaceContrast,
                        range: AppSettingsStore.contrastRange,
                        step: 0.05,
                        badge: "\(Int(round(settings.interfaceContrast * 100)))%"
                    )

                    divider

                    sliderRow(
                        title: "Opacidade de superfícies",
                        subtitle: "Controla a solidez dos painéis e barras auxiliares.",
                        value: $settings.surfaceOpacity,
                        range: AppSettingsStore.surfaceOpacityRange,
                        step: 0.05,
                        badge: "\(Int(round(settings.surfaceOpacity * 100)))%"
                    )
                }
            }
        }
    }

    private func appearanceModeCard(_ mode: AppAppearanceMode) -> some View {
        let isSelected = settings.appearanceMode == mode

        return Button {
            withAnimation(.easeInOut(duration: 0.16)) {
                settings.appearanceMode = mode
            }
        } label: {
            VStack(spacing: 8) {
                appearanceThumbnail(for: mode)
                    .frame(height: 68)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .strokeBorder(isSelected ? PixelTheme.accent : PixelTheme.border, lineWidth: isSelected ? 2 : 1)
                    }

                HStack(spacing: 5) {
                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 11))
                            .foregroundStyle(PixelTheme.accent)
                    }
                    Text(mode.displayName)
                        .font(PixelTheme.uiFont(size: 12.5, weight: isSelected ? .semibold : .medium))
                        .foregroundStyle(isSelected ? PixelTheme.accent : PixelTheme.ink)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(8)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(isSelected ? PixelTheme.accentSoft.opacity(0.65) : PixelTheme.surface)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(isSelected ? PixelTheme.accentBorder : PixelTheme.border, lineWidth: 1)
            }
            .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Esquema \(mode.displayName)")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    @ViewBuilder
    private func appearanceThumbnail(for mode: AppAppearanceMode) -> some View {
        switch mode {
        case .light:
            miniWindowPreview(isDark: false)
        case .dark:
            miniWindowPreview(isDark: true)
        case .system:
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    miniWindowPreview(isDark: true)
                    miniWindowPreview(isDark: false)
                        .mask(
                            Rectangle()
                                .frame(width: geo.size.width / 2)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        )
                    Rectangle()
                        .fill(PixelTheme.borderStrong)
                        .frame(width: 1)
                        .offset(x: geo.size.width / 2)
                }
            }
        }
    }

    private func miniWindowPreview(isDark: Bool) -> some View {
        let bg = isDark ? Color(red: 0.12, green: 0.12, blue: 0.14) : Color(red: 0.96, green: 0.95, blue: 0.93)
        let side = isDark ? Color(red: 0.16, green: 0.16, blue: 0.19) : Color(red: 0.92, green: 0.91, blue: 0.88)
        let card = isDark ? Color(red: 0.21, green: 0.21, blue: 0.25) : Color.white
        let line = isDark ? Color.white.opacity(0.22) : Color.black.opacity(0.16)
        let accent = isDark ? settings.themePreset.darkSwatchColor : settings.themePreset.lightSwatchColor

        return HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 3) {
                    Circle().fill(Color.red.opacity(0.75)).frame(width: 4.5, height: 4.5)
                    Circle().fill(Color.yellow.opacity(0.75)).frame(width: 4.5, height: 4.5)
                    Circle().fill(Color.green.opacity(0.75)).frame(width: 4.5, height: 4.5)
                }
                RoundedRectangle(cornerRadius: 2).fill(accent).frame(width: 24, height: 5)
                RoundedRectangle(cornerRadius: 2).fill(line).frame(width: 20, height: 4)
                RoundedRectangle(cornerRadius: 2).fill(line).frame(width: 16, height: 4)
                Spacer(minLength: 0)
            }
            .padding(7)
            .frame(width: 42)
            .background(side)

            VStack(alignment: .leading, spacing: 6) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(card)
                    .overlay(alignment: .topLeading) {
                        VStack(alignment: .leading, spacing: 4) {
                            RoundedRectangle(cornerRadius: 1.5).fill(accent.opacity(0.85)).frame(width: 34, height: 4)
                            RoundedRectangle(cornerRadius: 1.5).fill(line).frame(width: 52, height: 3.5)
                            RoundedRectangle(cornerRadius: 1.5).fill(line).frame(width: 40, height: 3.5)
                        }
                        .padding(6)
                    }
            }
            .padding(7)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(bg)
        }
    }

    private func themePresetCard(_ preset: AppThemePreset) -> some View {
        let isSelected = settings.themePreset == preset

        return Button {
            withAnimation(.easeInOut(duration: 0.14)) {
                settings.themePreset = preset
            }
        } label: {
            HStack(spacing: 10) {
                HStack(spacing: -5) {
                    Circle()
                        .fill(preset.lightSwatchColor)
                        .frame(width: 18, height: 18)
                        .overlay {
                            Circle().strokeBorder(PixelTheme.paper, lineWidth: 1.5)
                        }
                    Circle()
                        .fill(preset.darkSwatchColor)
                        .frame(width: 18, height: 18)
                        .overlay {
                            Circle().strokeBorder(PixelTheme.paper, lineWidth: 1.5)
                        }
                }
                .accessibilityHidden(true)

                Text(preset.displayName)
                    .font(PixelTheme.uiFont(size: 12.5, weight: isSelected ? .semibold : .medium))
                    .foregroundStyle(isSelected ? PixelTheme.accent : PixelTheme.ink)
                    .lineLimit(1)

                Spacer(minLength: 0)

                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 10.5, weight: .bold))
                        .foregroundStyle(PixelTheme.accent)
                }
            }
            .padding(.horizontal, 11)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(isSelected ? PixelTheme.accentSoft : PixelTheme.surface)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .strokeBorder(isSelected ? PixelTheme.accent : PixelTheme.border, lineWidth: isSelected ? 1.5 : 1)
            }
            .contentShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Tema \(preset.displayName)")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    // MARK: - 3. Canetas e Cores

    private var pensAndColorsSection: some View {
        VStack(alignment: .leading, spacing: 22) {
            settingsSection(title: "Padrões iniciais das ferramentas", subtitle: "Aplicados automaticamente ao abrir novas sessões de desenho.") {
                VStack(spacing: 0) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Cor padrão da caneta")
                                .font(PixelTheme.uiFont(size: 13, weight: .medium))
                                .foregroundStyle(PixelTheme.ink)
                            Text(settings.defaultPenColorHex)
                                .font(PixelTheme.displayFont(size: 11, weight: .regular))
                                .foregroundStyle(PixelTheme.muted)
                        }
                        Spacer()
                        ColorPicker(
                            "Cor padrão da caneta",
                            selection: Binding(
                                get: { settings.defaultPenColor },
                                set: { newColor in
                                    settings.defaultPenColorHex = PenColorComponents.from(newColor).hex6
                                }
                            ),
                            supportsOpacity: false
                        )
                        .labelsHidden()
                    }
                    .padding(14)

                    divider

                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Cor padrão do marca-texto")
                                .font(PixelTheme.uiFont(size: 13, weight: .medium))
                                .foregroundStyle(PixelTheme.ink)
                            Text(settings.defaultHighlighterColorHex)
                                .font(PixelTheme.displayFont(size: 11, weight: .regular))
                                .foregroundStyle(PixelTheme.muted)
                        }
                        Spacer()
                        ColorPicker(
                            "Cor padrão do marca-texto",
                            selection: Binding(
                                get: {
                                    PenColorComponents.fromHex(settings.defaultHighlighterColorHex)?.opaqueColor ?? PixelTheme.highlight
                                },
                                set: { newColor in
                                    settings.defaultHighlighterColorHex = PenColorComponents.from(newColor).hex6
                                }
                            ),
                            supportsOpacity: false
                        )
                        .labelsHidden()
                    }
                    .padding(14)

                    divider

                    sliderRow(
                        title: "Espessura padrão da caneta",
                        subtitle: "Espessura inicial para caneta tinteiro e formas.",
                        value: $settings.defaultPenWidth,
                        range: AppSettingsStore.penWidthRange,
                        step: 1.0,
                        badge: "\(Int(round(settings.defaultPenWidth))) pt"
                    )

                    divider

                    sliderRow(
                        title: "Tamanho padrão da borracha",
                        subtitle: "Diâmetro inicial da borracha de traços.",
                        value: $settings.defaultEraserWidth,
                        range: AppSettingsStore.eraserWidthRange,
                        step: 1.0,
                        badge: "\(Int(round(settings.defaultEraserWidth))) pt"
                    )
                }
            }

            settingsSection(title: "Cores de atalho da barra de ferramentas", subtitle: "Personalize os 5 presets exibidos no editor para troca rápida de tinta.") {
                VStack(spacing: 0) {
                    ForEach(Array(settings.penPresets.enumerated()), id: \.element.id) { index, preset in
                        HStack(spacing: 12) {
                            Circle()
                                .fill(preset.color)
                                .frame(width: 20, height: 20)
                                .overlay {
                                    Circle().strokeBorder(PixelTheme.borderStrong, lineWidth: 1)
                                }

                            VStack(alignment: .leading, spacing: 2) {
                                Text(preset.name)
                                    .font(PixelTheme.uiFont(size: 13, weight: .medium))
                                    .foregroundStyle(PixelTheme.ink)
                                Text(preset.hex)
                                    .font(PixelTheme.displayFont(size: 11, weight: .regular))
                                    .foregroundStyle(PixelTheme.muted)
                            }

                            Spacer()

                            ColorPicker(
                                "Escolher cor para \(preset.name)",
                                selection: Binding(
                                    get: { preset.color },
                                    set: { newColor in
                                        let hex = PenColorComponents.from(newColor).hex6
                                        settings.updatePenPreset(at: index, hex: hex)
                                    }
                                ),
                                supportsOpacity: false
                            )
                            .labelsHidden()
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)

                        if index < settings.penPresets.count - 1 {
                            divider
                        }
                    }

                    divider

                    HStack {
                        Spacer()
                        Button("Restaurar cores padrão") {
                            settings.resetPenPresets()
                        }
                        .buttonStyle(.bordered)
                    }
                    .padding(12)
                }
            }
        }
    }

    // MARK: - 4. Papel e Notas

    private var paperAndNotesSection: some View {
        VStack(alignment: .leading, spacing: 22) {
            settingsSection(title: "Estilo de papel padrão", subtitle: "Pré-selecionado automaticamente ao abrir \"Nova nota\".") {
                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: 120, maximum: 160), spacing: 10)],
                    spacing: 10
                ) {
                    ForEach(GridStyle.allCases, id: \.self) { style in
                        let isSelected = settings.defaultPaperStyle == style
                        Button {
                            settings.defaultPaperStyle = style
                        } label: {
                            VStack(spacing: 8) {
                                Canvas { context, size in
                                    let rect = CGRect(origin: .zero, size: size)
                                    context.withCGContext { cg in
                                        renderGrid(
                                            style: style,
                                            spacing: 12,
                                            origin: CGPoint(x: size.width / 2, y: size.height / 2),
                                            in: rect,
                                            into: cg
                                        )
                                    }
                                }
                                .frame(height: 54)
                                .background(Color.white)
                                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                                .overlay {
                                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                                        .strokeBorder(isSelected ? PixelTheme.accent : PixelTheme.border, lineWidth: isSelected ? 2 : 1)
                                }

                                Text(style.paperName)
                                    .font(PixelTheme.uiFont(size: 12, weight: isSelected ? .semibold : .medium))
                                    .foregroundStyle(isSelected ? PixelTheme.accent : PixelTheme.ink)
                                    .lineLimit(1)
                            }
                            .padding(8)
                            .frame(maxWidth: .infinity)
                            .background(
                                RoundedRectangle(cornerRadius: 9, style: .continuous)
                                    .fill(isSelected ? PixelTheme.accentSoft.opacity(0.65) : PixelTheme.surface)
                            )
                            .overlay {
                                RoundedRectangle(cornerRadius: 9, style: .continuous)
                                    .strokeBorder(isSelected ? PixelTheme.accentBorder : PixelTheme.border, lineWidth: 1)
                            }
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Papel \(style.paperName)")
                        .accessibilityAddTraits(isSelected ? .isSelected : [])
                    }
                }
                .padding(14)
            }

            settingsSection(title: "Orientação padrão da página", subtitle: "Define o formato inicial de novas notas criadas na biblioteca.") {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Orientação")
                            .font(PixelTheme.uiFont(size: 13, weight: .medium))
                            .foregroundStyle(PixelTheme.ink)
                        Text("Pode ser alterada individualmente ao criar cada nota.")
                            .font(PixelTheme.uiFont(size: 11.5))
                            .foregroundStyle(PixelTheme.muted)
                    }

                    Spacer(minLength: 16)

                    Picker("Orientação padrão", selection: $settings.defaultNoteOrientation) {
                        ForEach(NoteOrientation.allCases, id: \.self) { orientation in
                            Text(orientation.rawValue).tag(orientation)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.segmented)
                    .frame(width: 210)
                }
                .padding(14)
            }
        }
    }

    // MARK: - 5. Armazenamento

    private var storageSection: some View {
        let activeStoreURL = CoreDataStack.shared.currentStoreURL
        let activeDirectoryPath = activeStoreURL?.deletingLastPathComponent().path
            ?? CoreDataStack.defaultStoreDirectoryURL.path
        let totalNotes = viewModel.countAllNotes() + viewModel.countTrashedNotes()
        let totalNotebooks = viewModel.notebooks.count

        return VStack(alignment: .leading, spacing: 22) {
            settingsSection(title: "Resumo da biblioteca", subtitle: "Dados armazenados localmente via Core Data (SQLite).") {
                HStack(spacing: 14) {
                    statBadge(title: "Notas", value: "\(totalNotes)", icon: "doc.text")
                    statBadge(title: "Cadernos", value: "\(totalNotebooks)", icon: "folder")
                    statBadge(title: "Na lixeira", value: "\(viewModel.countTrashedNotes())", icon: "trash")
                }
                .padding(14)
            }

            settingsSection(title: "Local dos arquivos", subtitle: "Ao alterar a pasta, o banco atual é copiado e verificado; os arquivos originais são mantidos como backup.") {
                VStack(alignment: .leading, spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Pasta atual em uso")
                            .font(PixelTheme.uiFont(size: 11.5, weight: .semibold))
                            .foregroundStyle(PixelTheme.muted)

                        Text(activeDirectoryPath)
                            .font(PixelTheme.displayFont(size: 11.5, weight: .regular))
                            .foregroundStyle(PixelTheme.ink)
                            .textSelection(.enabled)
                            .padding(9)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(
                                RoundedRectangle(cornerRadius: 7, style: .continuous)
                                    .fill(PixelTheme.surface)
                            )
                            .overlay {
                                RoundedRectangle(cornerRadius: 7, style: .continuous)
                                    .strokeBorder(PixelTheme.border, lineWidth: 1)
                            }
                    }

                    if let pendingCustomPath = settings.customStoragePath,
                       pendingCustomPath != activeDirectoryPath {
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "info.circle.fill")
                                .foregroundStyle(PixelTheme.accent)
                            Text("Nova pasta configurada (\(pendingCustomPath)). Reabra o Easy Notes para passar a usar este local.")
                                .font(PixelTheme.uiFont(size: 12))
                                .foregroundStyle(PixelTheme.inkSecondary)
                        }
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(PixelTheme.accentSoft)
                        )
                    }

                    if let feedback = storageFeedback {
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: feedback.isError ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                                .foregroundStyle(feedback.isError ? PixelTheme.danger : PixelTheme.success)
                            Text(feedback.message)
                                .font(PixelTheme.uiFont(size: 12))
                                .foregroundStyle(feedback.isError ? PixelTheme.danger : PixelTheme.ink)
                        }
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(feedback.isError ? PixelTheme.dangerSoft : PixelTheme.successSoft)
                        )
                    }

                    HStack(spacing: 10) {
                        Button {
                            revealStoreInFinder()
                        } label: {
                            Label("Mostrar no Finder", systemImage: "folder")
                        }
                        .buttonStyle(.bordered)

                        Button {
                            chooseNewStorageDirectory()
                        } label: {
                            Label("Alterar pasta…", systemImage: "folder.badge.gearshape")
                        }
                        .buttonStyle(.borderedProminent)

                        Spacer()

                        Button("Restaurar local padrão") {
                            settings.resetStorageLocation()
                            storageFeedback = StorageFeedback(
                                isError: false,
                                message: "Local padrão restaurado. Reabra o Easy Notes para carregar o banco padrão. Nenhum arquivo foi apagado."
                            )
                        }
                        .buttonStyle(.bordered)
                        .disabled(settings.customStoragePath == nil)
                    }
                }
                .padding(14)
            }
        }
    }

    private func statBadge(title: String, value: String, icon: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(PixelTheme.accent)
                .frame(width: 28, height: 28)
                .background(PixelTheme.accentSoft, in: RoundedRectangle(cornerRadius: 7, style: .continuous))

            VStack(alignment: .leading, spacing: 1) {
                Text(value)
                    .font(PixelTheme.uiFont(size: 16, weight: .bold))
                    .foregroundStyle(PixelTheme.ink)
                    .monospacedDigit()
                Text(title)
                    .font(PixelTheme.uiFont(size: 11.5))
                    .foregroundStyle(PixelTheme.muted)
            }

            Spacer(minLength: 0)
        }
        .padding(10)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(PixelTheme.surface)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .strokeBorder(PixelTheme.border, lineWidth: 1)
        }
    }

    // MARK: - 6. Exportação

    private var exportSection: some View {
        VStack(alignment: .leading, spacing: 22) {
            settingsSection(title: "Exportação de PDF", subtitle: "Defina a pasta sugerida e as opções padrão ao exportar suas notas.") {
                VStack(spacing: 0) {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Pasta padrão de exportação")
                                    .font(PixelTheme.uiFont(size: 13, weight: .medium))
                                    .foregroundStyle(PixelTheme.ink)
                                Text(settings.defaultExportDirectoryPath ?? "Perguntar sempre ao exportar")
                                    .font(PixelTheme.displayFont(size: 11.5, weight: .regular))
                                    .foregroundStyle(PixelTheme.muted)
                                    .lineLimit(2)
                                    .truncationMode(.middle)
                            }
                            Spacer(minLength: 12)

                            Button("Escolher pasta…") {
                                chooseDefaultExportDirectory()
                            }
                            .buttonStyle(.bordered)

                            if settings.defaultExportDirectoryPath != nil {
                                Button("Limpar") {
                                    settings.setDefaultExportDirectory(nil)
                                }
                                .buttonStyle(.bordered)
                            }
                        }
                    }
                    .padding(14)

                    divider

                    toggleRow(
                        title: "Incluir grade de papel por padrão",
                        subtitle: "Mantém linhas, quadriculado ou pontos visíveis no PDF exportado.",
                        isOn: $settings.includePaperGridInExport
                    )
                }
            }
        }
    }

    // MARK: - 7. Sobre

    private var aboutSection: some View {
        let shortVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
        let buildNumber = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"

        return VStack(alignment: .leading, spacing: 22) {
            settingsSection(title: "Aplicativo", subtitle: nil) {
                VStack(alignment: .leading, spacing: 14) {
                    HStack(spacing: 14) {
                        EasyNotesBrandMark(compact: false)
                        Spacer()
                        Text("Versão \(shortVersion) (\(buildNumber))")
                            .font(PixelTheme.displayFont(size: 11.5, weight: .medium))
                            .foregroundStyle(PixelTheme.muted)
                            .padding(.horizontal, 9)
                            .padding(.vertical, 4)
                            .background(PixelTheme.surface, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                            .overlay {
                                RoundedRectangle(cornerRadius: 6, style: .continuous)
                                    .strokeBorder(PixelTheme.border, lineWidth: 1)
                            }
                    }

                    Text("Cadernos digitais, anotações manuscritas e organização editorial nativa para macOS.")
                        .font(PixelTheme.uiFont(size: 12.5))
                        .foregroundStyle(PixelTheme.inkSecondary)

                    divider

                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Restaurar todas as configurações")
                                .font(PixelTheme.uiFont(size: 13, weight: .semibold))
                                .foregroundStyle(PixelTheme.ink)
                            Text("Volta o aplicativo para as preferências originais mantendo todas as notas salvas.")
                                .font(PixelTheme.uiFont(size: 11.5))
                                .foregroundStyle(PixelTheme.muted)
                        }

                        Spacer(minLength: 12)

                        Button("Restaurar todas as configurações", role: .destructive) {
                            isConfirmingResetAll = true
                        }
                        .buttonStyle(.bordered)
                    }
                }
                .padding(16)
            }
        }
    }

    // MARK: - Shared Section & Row Components

    private func settingsSection<Content: View>(
        title: String,
        subtitle: String?,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(PixelTheme.uiFont(size: 14, weight: .semibold))
                    .foregroundStyle(PixelTheme.ink)
                    .accessibilityAddTraits(.isHeader)

                if let subtitle {
                    Text(subtitle)
                        .font(PixelTheme.uiFont(size: 12))
                        .foregroundStyle(PixelTheme.muted)
                }
            }

            content()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: PixelTheme.cardRadius, style: .continuous)
                        .fill(PixelTheme.paper)
                )
                .overlay {
                    RoundedRectangle(cornerRadius: PixelTheme.cardRadius, style: .continuous)
                        .strokeBorder(PixelTheme.border, lineWidth: 1)
                }
        }
    }

    private func toggleRow(title: String, subtitle: String, isOn: Binding<Bool>) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(PixelTheme.uiFont(size: 13, weight: .medium))
                    .foregroundStyle(PixelTheme.ink)
                Text(subtitle)
                    .font(PixelTheme.uiFont(size: 11.5))
                    .foregroundStyle(PixelTheme.muted)
            }
            Spacer(minLength: 12)
            Toggle(title, isOn: isOn)
                .labelsHidden()
                .toggleStyle(.switch)
        }
        .padding(14)
    }

    private func sliderRow(
        title: String,
        subtitle: String,
        value: Binding<Double>,
        range: ClosedRange<Double>,
        step: Double,
        badge: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(PixelTheme.uiFont(size: 13, weight: .medium))
                        .foregroundStyle(PixelTheme.ink)
                    Text(subtitle)
                        .font(PixelTheme.uiFont(size: 11.5))
                        .foregroundStyle(PixelTheme.muted)
                }
                Spacer(minLength: 12)
                Text(badge)
                    .font(PixelTheme.displayFont(size: 11.5, weight: .semibold))
                    .foregroundStyle(PixelTheme.accent)
                    .monospacedDigit()
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(PixelTheme.accentSoft, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
            }

            Slider(value: value, in: range, step: step) {
                Text(title)
            }
            .labelsHidden()
            .accessibilityValue(badge)
        }
        .padding(14)
    }

    private var divider: some View {
        Rectangle()
            .fill(PixelTheme.border)
            .frame(height: 1)
    }

    // MARK: - Actions

    private func revealStoreInFinder() {
        if let storeURL = CoreDataStack.shared.currentStoreURL,
           FileManager.default.fileExists(atPath: storeURL.path) {
            NSWorkspace.shared.activateFileViewerSelecting([storeURL])
        } else {
            NSWorkspace.shared.open(CoreDataStack.defaultStoreDirectoryURL)
        }
    }

    private func chooseNewStorageDirectory() {
        let panel = NSOpenPanel()
        panel.title = "Escolher pasta de armazenamento"
        panel.message = "O banco atual será copiado com segurança para a pasta escolhida. Os arquivos anteriores serão mantidos como backup."
        panel.prompt = "Selecionar pasta"
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false

        if panel.runModal() == .OK, let directoryURL = panel.url {
            do {
                _ = try CoreDataStack.shared.migrateStoreCopy(to: directoryURL)
                try settings.setCustomStorageURL(directoryURL)
                storageFeedback = StorageFeedback(
                    isError: false,
                    message: "Cópia verificada em \(directoryURL.path). Os arquivos anteriores foram preservados como backup. Reabra o Easy Notes para aplicar a mudança."
                )
            } catch {
                storageFeedback = StorageFeedback(
                    isError: true,
                    message: error.localizedDescription
                )
            }
        }
    }

    private func chooseDefaultExportDirectory() {
        let panel = NSOpenPanel()
        panel.title = "Escolher pasta padrão de exportação"
        panel.prompt = "Selecionar pasta"
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false

        if panel.runModal() == .OK, let directoryURL = panel.url {
            settings.setDefaultExportDirectory(directoryURL)
        }
    }

    private func isEditingTextInKeyWindow() -> Bool {
        guard let responder = NSApp.keyWindow?.firstResponder else { return false }
        return responder is NSTextView || responder is NSTextField
    }
}
