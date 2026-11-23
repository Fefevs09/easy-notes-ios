import SwiftUI
import AppKit

/// Editorial Paper Studio / Soft-Pixel design system for Easy Notes.
/// Keeps the `PixelTheme` namespace for full compatibility with existing views.
enum PixelTheme {
    // MARK: - Core Surfaces
    static let paper = Color.white
    static let surface = Color(red: 0.980, green: 0.976, blue: 0.961)          // #FAF9F5
    static let background = Color(red: 0.957, green: 0.953, blue: 0.933)       // #F4F3EE
    static let canvas = Color(red: 0.945, green: 0.937, blue: 0.914)           // #F1EFE9
    static let sidebar = Color(red: 0.949, green: 0.941, blue: 0.910)          // #F2F0E8
    static let sidebarElevated = Color(red: 0.929, green: 0.918, blue: 0.882)  // #EDEAE1

    // MARK: - Borders & Dividers
    static let border = Color(red: 0.902, green: 0.890, blue: 0.855)           // #E6E3DA
    static let borderStrong = Color(red: 0.835, green: 0.820, blue: 0.776)     // #D5D1C6

    // MARK: - Text / Ink
    static let ink = Color(red: 0.137, green: 0.133, blue: 0.165)              // #23222A
    static let inkSecondary = Color(red: 0.353, green: 0.345, blue: 0.388)     // #5A5863
    static let muted = Color(red: 0.549, green: 0.537, blue: 0.580)            // #8C8994
    static let popoverMuted = Color(red: 0.424, green: 0.412, blue: 0.455)     // #6C6974

    // MARK: - Brand & Semantic Accents
    static let accent = Color(red: 0.435, green: 0.322, blue: 0.878)           // #6F52E0
    static let accentDeep = Color(red: 0.357, green: 0.247, blue: 0.820)       // #5B3FD1
    static let accentSoft = Color(red: 0.925, green: 0.906, blue: 0.988)       // #ECE7FC
    static let accentBorder = Color(red: 0.678, green: 0.600, blue: 0.945)     // #AD99F1

    static let success = Color(red: 0.180, green: 0.490, blue: 0.357)          // #2E7D5B
    static let successSoft = Color(red: 0.918, green: 0.961, blue: 0.937)      // #EAF5EF
    static let danger = Color(red: 0.780, green: 0.275, blue: 0.255)           // #C74641
    static let dangerSoft = Color(red: 0.980, green: 0.922, blue: 0.918)       // #FAEBEA

    static let highlight = Color(red: 0.949, green: 0.816, blue: 0.420)        // #F2D06B

    // MARK: - Studio Ink Preset Swatches (5-dot palette from mockups)
    static let inkCharcoal = Color(red: 0.169, green: 0.165, blue: 0.200)      // #2B2A33
    static let inkViolet = accent                                              // #6F52E0
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
        ("Lavanda", inkViolet, Color(red: 0.914, green: 0.890, blue: 0.980)),             // Lavender
        ("Sálvia", inkSage, Color(red: 0.878, green: 0.918, blue: 0.859)),               // Sage
        ("Terracota", inkTerracotta, Color(red: 0.945, green: 0.894, blue: 0.863)),         // Clay / Peach
        ("Areia", inkOchre, Color(red: 0.941, green: 0.914, blue: 0.843)),              // Warm Sand
        ("Ardósia", Color(red: 0.427, green: 0.498, blue: 0.600), Color(red: 0.894, green: 0.922, blue: 0.949)) // Slate Mist
    ]

    static func defaultNotebookIndex(_ name: String) -> Int {
        stableHash(name) % notebookSwatches.count
    }

    static func notebookColor(for notebook: Notebook?) -> Color {
        notebook.map { notebookSwatches[$0.swatchIndex].dot } ?? muted
    }

    static func notebookBannerTint(for notebook: Notebook?) -> Color {
        notebook.map { notebookSwatches[$0.swatchIndex].banner } ?? Color(red: 0.929, green: 0.922, blue: 0.894)
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
        NSColor(calibratedRed: 0.945, green: 0.937, blue: 0.914, alpha: 1.0)
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
