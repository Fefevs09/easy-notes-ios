import SwiftUI
import AppKit

/// Editorial Paper Studio / Soft-Pixel design system for Easy Notes.
/// Keeps the `PixelTheme` namespace for full compatibility with existing views.
enum PixelTheme {
    // MARK: - Dynamic Color Helper
    private static func dynamicNSColor(light: NSColor, dark: NSColor) -> NSColor {
        NSColor(name: nil) { appearance in
            let isDark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            return isDark ? dark : light
        }
    }

    private static func dynamicColor(light: NSColor, dark: NSColor) -> Color {
        Color(nsColor: dynamicNSColor(light: light, dark: dark))
    }

    private static func srgb(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1.0) -> NSColor {
        NSColor(srgbRed: r, green: g, blue: b, alpha: a)
    }

    // MARK: - Core Surfaces
    static let paper = dynamicColor(
        light: srgb(1.0, 1.0, 1.0),                                   // #FFFFFF
        dark: srgb(0.145, 0.141, 0.161)                               // #252429
    )
    private static let surfaceBase = dynamicColor(
        light: srgb(0.980, 0.976, 0.961),                             // #FAF9F5
        dark: srgb(0.169, 0.165, 0.188)                               // #2B2A30
    )
    static var surface: Color {
        surfaceBase.opacity(ThemeAppearanceState.shared.surfaceOpacity)
    }
    static let background = dynamicColor(
        light: srgb(0.957, 0.953, 0.933),                             // #F4F3EE
        dark: srgb(0.114, 0.110, 0.129)                               // #1D1C21
    )
    static let canvas = dynamicColor(
        light: srgb(0.945, 0.937, 0.914),                             // #F1EFE9
        dark: srgb(0.098, 0.094, 0.114)                               // #19181D
    )
    private static let sidebarBase = dynamicColor(
        light: srgb(0.949, 0.941, 0.910),                             // #F2F0E8
        dark: srgb(0.125, 0.122, 0.141)                               // #201F24
    )
    static var sidebar: Color {
        sidebarBase.opacity(ThemeAppearanceState.shared.surfaceOpacity)
    }
    private static let sidebarElevatedBase = dynamicColor(
        light: srgb(0.929, 0.918, 0.882),                             // #EDEAE1
        dark: srgb(0.188, 0.184, 0.212)                               // #302F36
    )
    static var sidebarElevated: Color {
        sidebarElevatedBase.opacity(ThemeAppearanceState.shared.surfaceOpacity)
    }

    // MARK: - Borders & Dividers
    static let border = dynamicColor(
        light: srgb(0.902, 0.890, 0.855),                             // #E6E3DA
        dark: srgb(0.243, 0.239, 0.275)                               // #3E3D46
    )
    static let borderStrong = dynamicColor(
        light: srgb(0.835, 0.820, 0.776),                             // #D5D1C6
        dark: srgb(0.325, 0.318, 0.365)                               // #53515D
    )

    // MARK: - Text / Ink
    static let ink = dynamicColor(
        light: srgb(0.137, 0.133, 0.165),                             // #23222A
        dark: srgb(0.945, 0.941, 0.961)                               // #F1F0F5
    )
    static let inkSecondary = dynamicColor(
        light: srgb(0.353, 0.345, 0.388),                             // #5A5863
        dark: srgb(0.757, 0.749, 0.796)                               // #C1BFCB
    )
    static let muted = dynamicColor(
        light: srgb(0.549, 0.537, 0.580),                             // #8C8994
        dark: srgb(0.580, 0.573, 0.624)                               // #94929F
    )
    static let popoverMuted = dynamicColor(
        light: srgb(0.424, 0.412, 0.455),                             // #6C6974
        dark: srgb(0.678, 0.671, 0.722)                               // #ADABB8
    )

    // MARK: - Brand & Semantic Accents (Dynamic with AppThemePreset via @Observable ThemeAppearanceState)
    static var onAccent: Color {
        let light: NSColor = switch ThemeAppearanceState.shared.themePreset {
        case .amber, .terracotta: .black
        default: .white
        }
        return dynamicColor(light: light, dark: .black)
    }

    static var accent: Color {
        let preset = ThemeAppearanceState.shared.themePreset
        return dynamicColor(light: preset.lightAccentNSColor, dark: preset.darkAccentNSColor)
    }

    static var accentDeep: Color {
        let preset = ThemeAppearanceState.shared.themePreset
        return dynamicColor(light: preset.lightAccentDeepNSColor, dark: preset.darkAccentDeepNSColor)
    }

    static var accentSoft: Color {
        let preset = ThemeAppearanceState.shared.themePreset
        return dynamicColor(light: preset.lightAccentSoftNSColor, dark: preset.darkAccentSoftNSColor)
    }

    static var accentBorder: Color {
        let preset = ThemeAppearanceState.shared.themePreset
        return dynamicColor(light: preset.lightAccentBorderNSColor, dark: preset.darkAccentBorderNSColor)
    }

    static let success = dynamicColor(
        light: srgb(0.180, 0.490, 0.357),                             // #2E7D5B
        dark: srgb(0.373, 0.741, 0.573)                               // #5FBD92
    )
    static let successSoft = dynamicColor(
        light: srgb(0.918, 0.961, 0.937),                             // #EAF5EF
        dark: srgb(0.145, 0.243, 0.196)
    )
    static let danger = dynamicColor(
        light: srgb(0.780, 0.275, 0.255),                             // #C74641
        dark: srgb(0.937, 0.459, 0.439)                               // #EF7570
    )
    static let dangerSoft = dynamicColor(
        light: srgb(0.980, 0.922, 0.918),                             // #FAEBEA
        dark: srgb(0.302, 0.165, 0.165)
    )

    static let highlight = Color(red: 0.949, green: 0.816, blue: 0.420)        // #F2D06B

    // MARK: - Studio Ink Preset Swatches (5-dot palette from mockups)
    static let inkCharcoal = Color(red: 0.169, green: 0.165, blue: 0.200)      // #2B2A33
    static let inkViolet = Color(red: 0.435, green: 0.322, blue: 0.878)        // #6F52E0
    static let inkSage = Color(red: 0.325, green: 0.490, blue: 0.400)          // #537D66
    static let inkOchre = Color(red: 0.898, green: 0.722, blue: 0.294)         // #E5B84B
    static let inkTerracotta = Color(red: 0.765, green: 0.518, blue: 0.404)    // #C38467

    static let presetSwatches: [Color] = [
        inkCharcoal,
        inkViolet,
        inkSage,
        inkOchre,
        inkTerracotta
    ]

    static let presetSwatchDefinitions: [(name: String, color: Color)] = [
        ("Carvão", inkCharcoal),
        ("Violeta", inkViolet),
        ("Sálvia", inkSage),
        ("Ocre", inkOchre),
        ("Terracota", inkTerracotta)
    ]

    // MARK: - Notebook Deterministic Colors & Card Banner Tints
    static let notebookSwatches: [(name: String, dot: Color, banner: Color)] = [
        ("Lavanda", inkViolet, dynamicColor(
            light: srgb(0.914, 0.890, 0.980),
            dark: srgb(0.215, 0.185, 0.320)
        )),
        ("Sálvia", inkSage, dynamicColor(
            light: srgb(0.878, 0.918, 0.859),
            dark: srgb(0.165, 0.235, 0.200)
        )),
        ("Terracota", inkTerracotta, dynamicColor(
            light: srgb(0.945, 0.894, 0.863),
            dark: srgb(0.285, 0.195, 0.165)
        )),
        ("Areia", inkOchre, dynamicColor(
            light: srgb(0.941, 0.914, 0.843),
            dark: srgb(0.275, 0.235, 0.155)
        )),
        ("Ardósia", Color(red: 0.427, green: 0.498, blue: 0.600), dynamicColor(
            light: srgb(0.894, 0.922, 0.949),
            dark: srgb(0.175, 0.210, 0.265)
        ))
    ]

    static func defaultNotebookIndex(_ name: String) -> Int {
        stableHash(name) % notebookSwatches.count
    }

    static func notebookColor(for notebook: Notebook?) -> Color {
        notebook.map { $0.customColor?.opaqueColor ?? notebookSwatches[$0.swatchIndex].dot } ?? muted
    }

    static func notebookBannerTint(for notebook: Notebook?) -> Color {
        if let color = notebook?.customColor {
            // Blend with white in light mode and dark surface in dark mode to preserve contrast.
            let light = srgb(0.8 + 0.2 * color.red, 0.8 + 0.2 * color.green, 0.8 + 0.2 * color.blue)
            let dark = srgb(
                0.145 * 0.75 + color.red * 0.25,
                0.141 * 0.75 + color.green * 0.25,
                0.161 * 0.75 + color.blue * 0.25
            )
            return dynamicColor(light: light, dark: dark)
        }
        return notebook.map { notebookSwatches[$0.swatchIndex].banner } ?? dynamicColor(
            light: srgb(0.929, 0.922, 0.894),
            dark: srgb(0.180, 0.176, 0.204)
        )
    }

    private static func stableHash(_ text: String) -> Int {
        text.unicodeScalars.reduce(5381) { acc, scalar in
            ((acc &<< 5) &+ acc) &+ Int(scalar.value)
        } & 0x7fffffff
    }

    // MARK: - Typography
    static func displayFont(size: CGFloat, weight: Font.Weight = .bold) -> Font {
        .system(size: size, weight: weight, design: .monospaced)
    }

    static func uiFont(size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .default)
    }

    static let sectionHeaderFont: Font = .system(size: 10.5, weight: .semibold, design: .default)

    // MARK: - Radii & Shadows
    static let cardRadius: CGFloat = 12
    static let controlRadius: CGFloat = 8
    static let pillRadius: CGFloat = 8
    static let compactRadius: CGFloat = 6

    static var nsCanvasBackground: NSColor {
        dynamicNSColor(
            light: srgb(0.945, 0.937, 0.914),
            dark: srgb(0.098, 0.094, 0.114)
        )
    }
}

// MARK: - Reusable Brand Mark
struct EasyNotesBrandMark: View {
    var compact: Bool = false

    var body: some View {
        HStack(spacing: compact ? 8 : 10) {
            ZStack {
                RoundedRectangle(cornerRadius: compact ? 6 : 7, style: .continuous)
                    .fill(PixelTheme.accent)
                    .frame(width: compact ? 24 : 26, height: compact ? 24 : 26)
                Image(systemName: "book.pages.fill")
                    .font(.system(size: compact ? 12 : 13, weight: .semibold))
                    .foregroundColor(.white)
            }

            Text("easy notes")
                .font(PixelTheme.displayFont(size: compact ? 15 : 16, weight: .bold))
                .foregroundColor(PixelTheme.ink)
                .tracking(-0.3)
        }
    }
}

// MARK: - Studio Surface Modifiers
struct StudioCardModifier: ViewModifier {
    var fill: Color = PixelTheme.paper
    var radius: CGFloat = PixelTheme.cardRadius
    var borderColor: Color = PixelTheme.border
    var isHovered: Bool = false

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(fill)
            )
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .strokeBorder(isHovered ? PixelTheme.accentBorder : borderColor, lineWidth: 1)
            )
            .shadow(
                color: Color.black.opacity(isHovered ? 0.08 : 0.04),
                radius: isHovered ? 10 : 5,
                x: 0,
                y: isHovered ? 4 : 2
            )
    }
}

/// Active tool button styling matching the lavender pill with subtle pixel corner brackets
/// seen on the selected Caneta / Marca-texto buttons in the Figma mockups.
struct StudioActiveToolModifier: ViewModifier {
    var isSelected: Bool

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: PixelTheme.controlRadius, style: .continuous)
                    .fill(isSelected ? PixelTheme.accentSoft : Color.clear)
            )
            .overlay(
                ZStack {
                    if isSelected {
                        RoundedRectangle(cornerRadius: PixelTheme.controlRadius, style: .continuous)
                            .strokeBorder(PixelTheme.accentBorder, lineWidth: 1.5)
                    }
                }
            )
    }
}

/// Softened replacement for the legacy `PixelPanel` modifier so existing callers
/// automatically adopt the new editorial card surface while staying source-compatible.
struct PixelPanel: ViewModifier {
    var fill: Color = PixelTheme.paper
    var radius: CGFloat = PixelTheme.controlRadius

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(fill)
            )
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .strokeBorder(PixelTheme.border, lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.04), radius: 4, x: 0, y: 1.5)
    }
}

extension View {
    func pixelPanel(_ fill: Color = PixelTheme.paper) -> some View {
        modifier(PixelPanel(fill: fill))
    }

    func studioCard(
        fill: Color = PixelTheme.paper,
        radius: CGFloat = PixelTheme.cardRadius,
        borderColor: Color = PixelTheme.border,
        isHovered: Bool = false
    ) -> some View {
        modifier(StudioCardModifier(fill: fill, radius: radius, borderColor: borderColor, isHovered: isHovered))
    }

    func studioActiveTool(_ isSelected: Bool) -> some View {
        modifier(StudioActiveToolModifier(isSelected: isSelected))
    }

    func studioSectionHeader() -> some View {
        self
            .font(PixelTheme.sectionHeaderFont)
            .foregroundColor(PixelTheme.muted)
            .tracking(0.8)
            .textCase(.uppercase)
    }
}
