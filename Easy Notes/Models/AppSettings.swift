import AppKit
import Combine
import Foundation
import Observation
import SwiftUI

@Observable
final class ThemeAppearanceState {
    static let shared = ThemeAppearanceState()

    var themePreset: AppThemePreset = .editorial
    var surfaceOpacity: Double = 1.0
    var interfaceContrast: Double = 1.0
}

public enum AppAppearanceMode: String, CaseIterable, Identifiable, Codable {
    case system
    case light
    case dark

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .system: return "Sistema"
        case .light: return "Claro"
        case .dark: return "Escuro"
        }
    }

    public var preferredColorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}

public enum AppThemePreset: String, CaseIterable, Identifiable, Codable {
    case editorial
    case sage
    case terracotta
    case ocean
    case amber
    case lavender
    case graphite
    case raspberry

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .editorial: return "Editorial Paper"
        case .sage: return "Sálvia"
        case .terracotta: return "Terracota"
        case .ocean: return "Oceano"
        case .amber: return "Âmbar"
        case .lavender: return "Lavanda"
        case .graphite: return "Grafite"
        case .raspberry: return "Framboesa"
        }
    }

    public var lightAccentNSColor: NSColor {
        switch self {
        case .editorial:
            return NSColor(srgbRed: 0.435, green: 0.322, blue: 0.878, alpha: 1.0) // #6F52E0
        case .sage:
            return NSColor(srgbRed: 0.278, green: 0.478, blue: 0.376, alpha: 1.0) // #477A60
        case .terracotta:
            return NSColor(srgbRed: 0.745, green: 0.380, blue: 0.275, alpha: 1.0) // #BE6146
        case .ocean:
            return NSColor(srgbRed: 0.176, green: 0.463, blue: 0.678, alpha: 1.0) // #2D76AD
        case .amber:
            return NSColor(srgbRed: 0.761, green: 0.506, blue: 0.141, alpha: 1.0) // #C28124
        case .lavender:
            return NSColor(srgbRed: 0.502, green: 0.333, blue: 0.651, alpha: 1.0)
        case .graphite:
            return NSColor(srgbRed: 0.329, green: 0.361, blue: 0.404, alpha: 1.0)
        case .raspberry:
            return NSColor(srgbRed: 0.663, green: 0.220, blue: 0.384, alpha: 1.0)
        }
    }

    public var darkAccentNSColor: NSColor {
        switch self {
        case .editorial:
            return NSColor(srgbRed: 0.620, green: 0.533, blue: 0.961, alpha: 1.0) // #9E88F5
        case .sage:
            return NSColor(srgbRed: 0.467, green: 0.722, blue: 0.592, alpha: 1.0) // #77B897
        case .terracotta:
            return NSColor(srgbRed: 0.886, green: 0.553, blue: 0.443, alpha: 1.0) // #E28D71
        case .ocean:
            return NSColor(srgbRed: 0.420, green: 0.690, blue: 0.890, alpha: 1.0) // #6BB0E3
        case .amber:
            return NSColor(srgbRed: 0.929, green: 0.710, blue: 0.345, alpha: 1.0) // #EDB558
        case .lavender:
            return NSColor(srgbRed: 0.765, green: 0.620, blue: 0.875, alpha: 1.0)
        case .graphite:
            return NSColor(srgbRed: 0.690, green: 0.729, blue: 0.784, alpha: 1.0)
        case .raspberry:
            return NSColor(srgbRed: 0.925, green: 0.545, blue: 0.678, alpha: 1.0)
        }
    }

    public var lightAccentDeepNSColor: NSColor {
        switch self {
        case .editorial:
            return NSColor(srgbRed: 0.357, green: 0.247, blue: 0.820, alpha: 1.0) // #5B3FD1
        case .sage:
            return NSColor(srgbRed: 0.212, green: 0.384, blue: 0.298, alpha: 1.0) // #36624C
        case .terracotta:
            return NSColor(srgbRed: 0.620, green: 0.298, blue: 0.208, alpha: 1.0) // #9E4C35
        case .ocean:
            return NSColor(srgbRed: 0.129, green: 0.369, blue: 0.557, alpha: 1.0) // #215E8E
        case .amber:
            return NSColor(srgbRed: 0.627, green: 0.404, blue: 0.098, alpha: 1.0) // #A06719
        case .lavender:
            return NSColor(srgbRed: 0.404, green: 0.247, blue: 0.537, alpha: 1.0)
        case .graphite:
            return NSColor(srgbRed: 0.259, green: 0.286, blue: 0.329, alpha: 1.0)
        case .raspberry:
            return NSColor(srgbRed: 0.545, green: 0.161, blue: 0.306, alpha: 1.0)
        }
    }

    public var darkAccentDeepNSColor: NSColor {
        switch self {
        case .editorial:
            return NSColor(srgbRed: 0.710, green: 0.635, blue: 0.980, alpha: 1.0)
        case .sage:
            return NSColor(srgbRed: 0.580, green: 0.812, blue: 0.694, alpha: 1.0)
        case .terracotta:
            return NSColor(srgbRed: 0.933, green: 0.659, blue: 0.569, alpha: 1.0)
        case .ocean:
            return NSColor(srgbRed: 0.549, green: 0.780, blue: 0.945, alpha: 1.0)
        case .amber:
            return NSColor(srgbRed: 0.961, green: 0.792, blue: 0.490, alpha: 1.0)
        case .lavender:
            return NSColor(srgbRed: 0.831, green: 0.710, blue: 0.922, alpha: 1.0)
        case .graphite:
            return NSColor(srgbRed: 0.784, green: 0.812, blue: 0.847, alpha: 1.0)
        case .raspberry:
            return NSColor(srgbRed: 0.961, green: 0.667, blue: 0.765, alpha: 1.0)
        }
    }

    public var lightAccentSoftNSColor: NSColor {
        switch self {
        case .editorial:
            return NSColor(srgbRed: 0.925, green: 0.906, blue: 0.988, alpha: 1.0) // #ECE7FC
        case .sage:
            return NSColor(srgbRed: 0.902, green: 0.949, blue: 0.925, alpha: 1.0) // #E6F2EC
        case .terracotta:
            return NSColor(srgbRed: 0.976, green: 0.922, blue: 0.902, alpha: 1.0) // #F9EBE6
        case .ocean:
            return NSColor(srgbRed: 0.898, green: 0.941, blue: 0.976, alpha: 1.0) // #E5F0F9
        case .amber:
            return NSColor(srgbRed: 0.980, green: 0.945, blue: 0.882, alpha: 1.0) // #FAF1E1
        case .lavender:
            return NSColor(srgbRed: 0.941, green: 0.906, blue: 0.965, alpha: 1.0)
        case .graphite:
            return NSColor(srgbRed: 0.914, green: 0.925, blue: 0.941, alpha: 1.0)
        case .raspberry:
            return NSColor(srgbRed: 0.980, green: 0.902, blue: 0.933, alpha: 1.0)
        }
    }

    public var darkAccentSoftNSColor: NSColor {
        switch self {
        case .editorial:
            return NSColor(srgbRed: 0.220, green: 0.184, blue: 0.345, alpha: 1.0)
        case .sage:
            return NSColor(srgbRed: 0.161, green: 0.251, blue: 0.208, alpha: 1.0)
        case .terracotta:
            return NSColor(srgbRed: 0.302, green: 0.184, blue: 0.153, alpha: 1.0)
        case .ocean:
            return NSColor(srgbRed: 0.145, green: 0.235, blue: 0.314, alpha: 1.0)
        case .amber:
            return NSColor(srgbRed: 0.298, green: 0.235, blue: 0.133, alpha: 1.0)
        case .lavender:
            return NSColor(srgbRed: 0.239, green: 0.169, blue: 0.310, alpha: 1.0)
        case .graphite:
            return NSColor(srgbRed: 0.180, green: 0.200, blue: 0.231, alpha: 1.0)
        case .raspberry:
            return NSColor(srgbRed: 0.322, green: 0.149, blue: 0.220, alpha: 1.0)
        }
    }

    public var lightAccentBorderNSColor: NSColor {
        switch self {
        case .editorial:
            return NSColor(srgbRed: 0.678, green: 0.600, blue: 0.945, alpha: 1.0) // #AD99F1
        case .sage:
            return NSColor(srgbRed: 0.569, green: 0.745, blue: 0.655, alpha: 1.0)
        case .terracotta:
            return NSColor(srgbRed: 0.875, green: 0.643, blue: 0.569, alpha: 1.0)
        case .ocean:
            return NSColor(srgbRed: 0.541, green: 0.725, blue: 0.871, alpha: 1.0)
        case .amber:
            return NSColor(srgbRed: 0.878, green: 0.710, blue: 0.447, alpha: 1.0)
        case .lavender:
            return NSColor(srgbRed: 0.741, green: 0.620, blue: 0.820, alpha: 1.0)
        case .graphite:
            return NSColor(srgbRed: 0.663, green: 0.698, blue: 0.749, alpha: 1.0)
        case .raspberry:
            return NSColor(srgbRed: 0.851, green: 0.565, blue: 0.682, alpha: 1.0)
        }
    }

    public var darkAccentBorderNSColor: NSColor {
        switch self {
        case .editorial:
            return NSColor(srgbRed: 0.451, green: 0.376, blue: 0.749, alpha: 1.0)
        case .sage:
            return NSColor(srgbRed: 0.337, green: 0.545, blue: 0.439, alpha: 1.0)
        case .terracotta:
            return NSColor(srgbRed: 0.671, green: 0.388, blue: 0.306, alpha: 1.0)
        case .ocean:
            return NSColor(srgbRed: 0.298, green: 0.525, blue: 0.706, alpha: 1.0)
        case .amber:
            return NSColor(srgbRed: 0.698, green: 0.514, blue: 0.239, alpha: 1.0)
        case .lavender:
            return NSColor(srgbRed: 0.580, green: 0.424, blue: 0.698, alpha: 1.0)
        case .graphite:
            return NSColor(srgbRed: 0.455, green: 0.502, blue: 0.569, alpha: 1.0)
        case .raspberry:
            return NSColor(srgbRed: 0.722, green: 0.349, blue: 0.494, alpha: 1.0)
        }
    }

    public var lightSwatchColor: Color { Color(nsColor: lightAccentNSColor) }
    public var darkSwatchColor: Color { Color(nsColor: darkAccentNSColor) }
}

public struct PenPresetColor: Identifiable, Codable, Equatable {
    public let id: String
    public var name: String
    public var hex: String

    public init(id: String, name: String, hex: String) {
        self.id = id
        self.name = name
        self.hex = PenColorComponents.normalizeHex(hex) ?? "#2B2A33"
    }

    public var color: Color {
        PenColorComponents.fromHex(hex)?.opaqueColor ?? PixelTheme.inkCharcoal
    }

    public static let defaults: [PenPresetColor] = [
        PenPresetColor(id: "preset-1", name: "Carvão", hex: "#2B2A33"),
        PenPresetColor(id: "preset-2", name: "Violeta", hex: "#6F52E0"),
        PenPresetColor(id: "preset-3", name: "Sálvia", hex: "#537D66"),
        PenPresetColor(id: "preset-4", name: "Ocre", hex: "#E5B84B"),
        PenPresetColor(id: "preset-5", name: "Terracota", hex: "#C38467")
    ]
}

public enum AppSettingsError: LocalizedError, Equatable {
    case invalidStorageDirectory(String)
    case unwritableStorageDirectory(String)

    public var errorDescription: String? {
        switch self {
        case .invalidStorageDirectory(let path):
            return "A pasta selecionada não existe ou não é um diretório válido: \(path)"
        case .unwritableStorageDirectory(let path):
            return "Não há permissão de escrita na pasta selecionada: \(path)"
        }
    }
}

public final class AppSettingsStore: ObservableObject {
    public static let shared = AppSettingsStore(defaults: .standard, syncsGlobalTheme: true)

    public enum Keys {
        public static let appearanceMode = "easyNotes.settings.appearanceMode"
        public static let themePreset = "easyNotes.settings.themePreset"
        public static let interfaceContrast = "easyNotes.settings.interfaceContrast"
        public static let surfaceOpacity = "easyNotes.settings.surfaceOpacity"
        public static let confirmBeforeDeletingNotebook = "easyNotes.settings.confirmBeforeDeletingNotebook"
        public static let confirmBeforeEmptyingTrash = "easyNotes.settings.confirmBeforeEmptyingTrash"
        public static let defaultPenColorHex = "easyNotes.settings.defaultPenColorHex"
        public static let defaultHighlighterColorHex = "easyNotes.settings.defaultHighlighterColorHex"
        public static let defaultPenWidth = "easyNotes.settings.defaultPenWidth"
        public static let defaultEraserWidth = "easyNotes.settings.defaultEraserWidth"
        public static let penPresets = "easyNotes.settings.penPresets"
        public static let defaultPaperStyle = "easyNotes.settings.defaultPaperStyle"
        public static let defaultNoteOrientation = "easyNotes.settings.defaultNoteOrientation"
        public static let customStoragePath = "easyNotes.settings.customStoragePath"
        public static let storageDirectoryBookmark = "easyNotes.settings.storageDirectoryBookmark"
        public static let defaultExportDirectoryPath = "easyNotes.settings.defaultExportDirectoryPath"
        public static let defaultExportDirectoryBookmark = "easyNotes.settings.defaultExportDirectoryBookmark"
        public static let includePaperGridInExport = "easyNotes.settings.includePaperGridInExport"
    }

    public static let contrastRange: ClosedRange<Double> = 0.80...1.20
    public static let surfaceOpacityRange: ClosedRange<Double> = 0.70...1.00
    public static let penWidthRange: ClosedRange<Double> = 1.0...16.0
    public static let eraserWidthRange: ClosedRange<Double> = 4.0...40.0

    public static let defaultPenColorHexValue = "#000000"
    public static let defaultHighlighterColorHexValue = "#F2D06B"
    public static let defaultPenWidthValue: Double = 3.0
    public static let defaultEraserWidthValue: Double = 18.0

    private let defaults: UserDefaults
    private let syncsGlobalTheme: Bool
    private var isReloading = false

    @Published public var appearanceMode: AppAppearanceMode {
        didSet { persist(appearanceMode.rawValue, forKey: Keys.appearanceMode) }
    }

    @Published public var themePreset: AppThemePreset {
        didSet {
            persist(themePreset.rawValue, forKey: Keys.themePreset)
            if syncsGlobalTheme {
                ThemeAppearanceState.shared.themePreset = themePreset
            }
        }
    }

    @Published public var interfaceContrast: Double {
        didSet {
            let clamped = Self.clamp(interfaceContrast, to: Self.contrastRange)
            if clamped != interfaceContrast {
                interfaceContrast = clamped
                return
            }
            persist(clamped, forKey: Keys.interfaceContrast)
            if syncsGlobalTheme {
                ThemeAppearanceState.shared.interfaceContrast = clamped
            }
        }
    }

    @Published public var surfaceOpacity: Double {
        didSet {
            let clamped = Self.clamp(surfaceOpacity, to: Self.surfaceOpacityRange)
            if clamped != surfaceOpacity {
                surfaceOpacity = clamped
                return
            }
            persist(clamped, forKey: Keys.surfaceOpacity)
            if syncsGlobalTheme {
                ThemeAppearanceState.shared.surfaceOpacity = clamped
            }
        }
    }

    @Published public var confirmBeforeDeletingNotebook: Bool {
        didSet { persist(confirmBeforeDeletingNotebook, forKey: Keys.confirmBeforeDeletingNotebook) }
    }

    @Published public var confirmBeforeEmptyingTrash: Bool {
        didSet { persist(confirmBeforeEmptyingTrash, forKey: Keys.confirmBeforeEmptyingTrash) }
    }

    @Published public var defaultPenColorHex: String {
        didSet {
            guard let normalized = PenColorComponents.normalizeHex(defaultPenColorHex) else {
                defaultPenColorHex = oldValue
                return
            }
            if normalized != defaultPenColorHex {
                defaultPenColorHex = normalized
                return
            }
            persist(normalized, forKey: Keys.defaultPenColorHex)
        }
    }

    @Published public var defaultHighlighterColorHex: String {
        didSet {
            guard let normalized = PenColorComponents.normalizeHex(defaultHighlighterColorHex) else {
                defaultHighlighterColorHex = oldValue
                return
            }
            if normalized != defaultHighlighterColorHex {
                defaultHighlighterColorHex = normalized
                return
            }
            persist(normalized, forKey: Keys.defaultHighlighterColorHex)
        }
    }

    @Published public var defaultPenWidth: Double {
        didSet {
            let clamped = Self.clamp(defaultPenWidth, to: Self.penWidthRange)
            if clamped != defaultPenWidth {
                defaultPenWidth = clamped
                return
            }
            persist(clamped, forKey: Keys.defaultPenWidth)
        }
    }

    @Published public var defaultEraserWidth: Double {
        didSet {
            let clamped = Self.clamp(defaultEraserWidth, to: Self.eraserWidthRange)
            if clamped != defaultEraserWidth {
                defaultEraserWidth = clamped
                return
            }
            persist(clamped, forKey: Keys.defaultEraserWidth)
        }
    }

    @Published public var penPresets: [PenPresetColor] {
        didSet { persistPenPresets(penPresets) }
    }

    @Published public var defaultPaperStyle: GridStyle {
        didSet { persist(defaultPaperStyle.rawValue, forKey: Keys.defaultPaperStyle) }
    }

    @Published public var defaultNoteOrientation: NoteOrientation {
        didSet { persist(defaultNoteOrientation.rawValue, forKey: Keys.defaultNoteOrientation) }
    }

    @Published public var customStoragePath: String? {
        didSet { persistOptionalString(customStoragePath, forKey: Keys.customStoragePath) }
    }

    @Published public var storageDirectoryBookmark: Data? {
        didSet { persistOptionalData(storageDirectoryBookmark, forKey: Keys.storageDirectoryBookmark) }
    }

    @Published public var defaultExportDirectoryPath: String? {
        didSet { persistOptionalString(defaultExportDirectoryPath, forKey: Keys.defaultExportDirectoryPath) }
    }

    @Published public var defaultExportDirectoryBookmark: Data? {
        didSet { persistOptionalData(defaultExportDirectoryBookmark, forKey: Keys.defaultExportDirectoryBookmark) }
    }

    @Published public var includePaperGridInExport: Bool {
        didSet { persist(includePaperGridInExport, forKey: Keys.includePaperGridInExport) }
    }

    public init(defaults: UserDefaults = .standard, syncsGlobalTheme: Bool = false) {
        self.defaults = defaults
        self.syncsGlobalTheme = syncsGlobalTheme
        self.isReloading = true

        self.appearanceMode = defaults.string(forKey: Keys.appearanceMode)
            .flatMap(AppAppearanceMode.init(rawValue:)) ?? .system

        self.themePreset = defaults.string(forKey: Keys.themePreset)
            .flatMap(AppThemePreset.init(rawValue:)) ?? .editorial

        let storedContrast = defaults.object(forKey: Keys.interfaceContrast) as? Double ?? 1.0
        self.interfaceContrast = Self.clamp(storedContrast, to: Self.contrastRange)

        let storedOpacity = defaults.object(forKey: Keys.surfaceOpacity) as? Double ?? 1.0
        self.surfaceOpacity = Self.clamp(storedOpacity, to: Self.surfaceOpacityRange)

        self.confirmBeforeDeletingNotebook = defaults.object(forKey: Keys.confirmBeforeDeletingNotebook) as? Bool ?? true
        self.confirmBeforeEmptyingTrash = defaults.object(forKey: Keys.confirmBeforeEmptyingTrash) as? Bool ?? true

        self.defaultPenColorHex = defaults.string(forKey: Keys.defaultPenColorHex)
            .flatMap(PenColorComponents.normalizeHex) ?? Self.defaultPenColorHexValue

        self.defaultHighlighterColorHex = defaults.string(forKey: Keys.defaultHighlighterColorHex)
            .flatMap(PenColorComponents.normalizeHex) ?? Self.defaultHighlighterColorHexValue

        let storedPenWidth = defaults.object(forKey: Keys.defaultPenWidth) as? Double ?? Self.defaultPenWidthValue
        self.defaultPenWidth = Self.clamp(storedPenWidth, to: Self.penWidthRange)

        let storedEraserWidth = defaults.object(forKey: Keys.defaultEraserWidth) as? Double ?? Self.defaultEraserWidthValue
        self.defaultEraserWidth = Self.clamp(storedEraserWidth, to: Self.eraserWidthRange)

        if let data = defaults.data(forKey: Keys.penPresets),
           let decoded = try? JSONDecoder().decode([PenPresetColor].self, from: data),
           decoded.count == PenPresetColor.defaults.count {
            self.penPresets = decoded.map { preset in
                PenPresetColor(id: preset.id, name: preset.name, hex: preset.hex)
            }
        } else {
            self.penPresets = PenPresetColor.defaults
        }

        self.defaultPaperStyle = defaults.string(forKey: Keys.defaultPaperStyle)
            .flatMap(GridStyle.init(rawValue:)) ?? .none

        self.defaultNoteOrientation = defaults.string(forKey: Keys.defaultNoteOrientation)
            .flatMap(NoteOrientation.init(rawValue:)) ?? .portrait

        self.customStoragePath = Self.normalizedOptionalPath(defaults.string(forKey: Keys.customStoragePath))
        self.storageDirectoryBookmark = defaults.data(forKey: Keys.storageDirectoryBookmark)
        self.defaultExportDirectoryPath = Self.normalizedOptionalPath(defaults.string(forKey: Keys.defaultExportDirectoryPath))
        self.defaultExportDirectoryBookmark = defaults.data(forKey: Keys.defaultExportDirectoryBookmark)
        self.includePaperGridInExport = defaults.object(forKey: Keys.includePaperGridInExport) as? Bool ?? true

        self.isReloading = false

        if syncsGlobalTheme {
            ThemeAppearanceState.shared.themePreset = self.themePreset
            ThemeAppearanceState.shared.interfaceContrast = self.interfaceContrast
            ThemeAppearanceState.shared.surfaceOpacity = self.surfaceOpacity
        }
    }

    // MARK: - Computed Helpers

    public var defaultPenColor: Color {
        PenColorComponents.fromHex(defaultPenColorHex)?.opaqueColor ?? .black
    }

    public var defaultHighlighterColor: Color {
        PenColorComponents.fromHex(defaultHighlighterColorHex, opacity: Double(CanvasViewModel.highlighterOpacity))?.swiftUIColor
            ?? Color.yellow.opacity(CanvasViewModel.highlighterOpacity)
    }

    public var customStorageURL: URL? {
        customStoragePath.map { URL(fileURLWithPath: $0, isDirectory: true) }
    }

    public var defaultExportDirectoryURL: URL? {
        defaultExportDirectoryPath.map { URL(fileURLWithPath: $0, isDirectory: true) }
    }

    // MARK: - Mutations

    @discardableResult
    public func updatePenPreset(at index: Int, hex: String, name: String? = nil) -> Bool {
        guard penPresets.indices.contains(index),
              let normalized = PenColorComponents.normalizeHex(hex) else {
            return false
        }
        var updated = penPresets
        let trimmedName = name?.trimmingCharacters(in: .whitespacesAndNewlines)
        let resolvedName = (trimmedName?.isEmpty == false) ? trimmedName! : updated[index].name
        updated[index] = PenPresetColor(id: updated[index].id, name: resolvedName, hex: normalized)
        penPresets = updated
        return true
    }

    public func resetPenPresets() {
        penPresets = PenPresetColor.defaults
    }

    public func setCustomStorageURL(_ url: URL) throws {
        let didStartAccessing = url.startAccessingSecurityScopedResource()
        defer {
            if didStartAccessing {
                url.stopAccessingSecurityScopedResource()
            }
        }

        let standardized = url.standardizedFileURL
        var isDirectory: ObjCBool = false
        let exists = FileManager.default.fileExists(atPath: standardized.path, isDirectory: &isDirectory)
        guard exists, isDirectory.boolValue else {
            throw AppSettingsError.invalidStorageDirectory(standardized.path)
        }
        guard FileManager.default.isWritableFile(atPath: standardized.path) else {
            throw AppSettingsError.unwritableStorageDirectory(standardized.path)
        }
        customStoragePath = standardized.path
        storageDirectoryBookmark = Self.makeSecurityScopedBookmark(for: standardized)
    }

    public func resetStorageLocation() {
        customStoragePath = nil
        storageDirectoryBookmark = nil
    }

    public func setDefaultExportDirectory(_ url: URL?) {
        guard let url else {
            defaultExportDirectoryPath = nil
            defaultExportDirectoryBookmark = nil
            return
        }
        let standardized = url.standardizedFileURL
        defaultExportDirectoryPath = standardized.path
        defaultExportDirectoryBookmark = Self.makeSecurityScopedBookmark(for: standardized)
    }

    public static func makeSecurityScopedBookmark(for url: URL) -> Data? {
        try? url.bookmarkData(
            options: .withSecurityScope,
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        )
    }

    /// Resets UI, drawing, paper, and export preferences while deliberately preserving
    /// any configured custom storage location (`customStoragePath` / `storageDirectoryBookmark`)
    /// so user notes are never silently detached.
    public func resetAll() {
        appearanceMode = .system
        themePreset = .editorial
        interfaceContrast = 1.0
        surfaceOpacity = 1.0
        confirmBeforeDeletingNotebook = true
        confirmBeforeEmptyingTrash = true
        defaultPenColorHex = Self.defaultPenColorHexValue
        defaultHighlighterColorHex = Self.defaultHighlighterColorHexValue
        defaultPenWidth = Self.defaultPenWidthValue
        defaultEraserWidth = Self.defaultEraserWidthValue
        penPresets = PenPresetColor.defaults
        defaultPaperStyle = .none
        defaultNoteOrientation = .portrait
        defaultExportDirectoryPath = nil
        defaultExportDirectoryBookmark = nil
        includePaperGridInExport = true
    }

    // MARK: - Persistence Helpers

    private func persist(_ value: Any, forKey key: String) {
        guard !isReloading else { return }
        defaults.set(value, forKey: key)
    }

    private func persistOptionalString(_ value: String?, forKey key: String) {
        guard !isReloading else { return }
        if let normalized = Self.normalizedOptionalPath(value) {
            defaults.set(normalized, forKey: key)
        } else {
            defaults.removeObject(forKey: key)
        }
    }

    private func persistOptionalData(_ value: Data?, forKey key: String) {
        guard !isReloading else { return }
        if let value {
            defaults.set(value, forKey: key)
        } else {
            defaults.removeObject(forKey: key)
        }
    }

    private func persistPenPresets(_ presets: [PenPresetColor]) {
        guard !isReloading else { return }
        if let data = try? JSONEncoder().encode(presets) {
            defaults.set(data, forKey: Keys.penPresets)
        }
    }

    private static func clamp(_ value: Double, to range: ClosedRange<Double>) -> Double {
        min(max(value, range.lowerBound), range.upperBound)
    }

    private static func normalizedOptionalPath(_ raw: String?) -> String? {
        guard let trimmed = raw?.trimmingCharacters(in: .whitespacesAndNewlines),
              !trimmed.isEmpty else {
            return nil
        }
        return trimmed
    }
}
