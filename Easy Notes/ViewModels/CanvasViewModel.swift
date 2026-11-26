import Foundation
import SwiftUI
import Combine

public enum ToolType: String, CaseIterable {
    case fountainPen = "Caneta Tinteiro"
    case calligraphy = "Caligráfica"
    case pencil = "Lápis"
    case highlighter = "Marca-texto"
    case eraser = "Borracha"
    case shape = "Forma"      // draws the currently selected ShapeKind
    case textBox = "Texto"    // adds/edits free text blocks on the page
    case select = "Selecionar" // selects/moves/resizes existing shapes
}

/// Geometric shapes that can be drawn by dragging. `polygon`/`arc` require a
/// click sequence and are reserved for a later increment.
public enum ShapeKind: String, CaseIterable {
    case line
    case rectangle
    case ellipse
    case arrow
    case polygon
    case arc
    case functionPlot // reserved for future y = f(x) plotting
}

public extension ShapeKind {
    /// The shapes exposed in the toolbar today (drag-to-draw). Polygon/arc/
    /// functionPlot are reserved for later increments.
    static var drawable: [ShapeKind] { [.line, .rectangle, .ellipse, .arrow] }

    var displayName: String {
        switch self {
        case .line: return "Reta"
        case .rectangle: return "Retângulo"
        case .ellipse: return "Elipse / Círculo"
        case .arrow: return "Seta"
        case .polygon: return "Polígono"
        case .arc: return "Arco"
        case .functionPlot: return "Função"
        }
    }

    var systemImage: String {
        switch self {
        case .line: return "line.diagonal"
        case .rectangle: return "rectangle"
        case .ellipse: return "circle"
        case .arrow: return "arrow.up.right"
        case .polygon: return "pentagon"
        case .arc: return "angle"
        case .functionPlot: return "function"
        }
    }
}

/// Cartesian graph-paper style rendered behind drawings on every page.
public enum GridStyle: String, CaseIterable {
    case none
    case lines // horizontal + vertical ruled lines
    case grid  // full quadrille
    case dots  // dotted lattice

    var displayName: String {
        switch self {
        case .none: return "Nenhuma"
        case .lines: return "Linhas"
        case .grid: return "Quadriculado"
        case .dots: return "Pontos"
        }
    }

    var systemImage: String {
        switch self {
        case .none: return "square"
        case .lines: return "line.3.horizontal"
        case .grid: return "grid"
        case .dots: return "circle.grid.3x3"
        }
    }
}

public class CanvasViewModel: ObservableObject {
    public struct ActiveStroke {
        public var pageIndex: Int
        public var points: [CGPoint]
        
        public init(pageIndex: Int, points: [CGPoint]) {
            self.pageIndex = pageIndex
            self.points = points
        }
    }
    @Published public var activeStroke: ActiveStroke?
    
    @Published public var isDrawingMode = true // Active/true by default to focus on writing
    @Published public var activeTool: ToolType = .fountainPen {
        didSet {
            applyToolDefaults()
        }
    }
    
    @Published public var strokeColor = Color.black
    @Published public var strokeWidth: CGFloat = 3.0

    /// The alpha applied to any highlighter color so it reads as a translucent
    /// marker overlay rather than an opaque stroke.
    public static let highlighterOpacity: CGFloat = 0.3

    // Shape drawing / editing state
    @Published public var activeShapeKind: ShapeKind = .line
    @Published public var selectedShapeID: UUID?
    @Published public var shapeFillEnabled: Bool = false

    // Text block tool state
    @Published public var textFontSize: CGFloat = TextBlockLayout.defaultFontSize
    @Published public var editingTextBlockID: UUID?
    @Published public var isTextStylePopoverPresented: Bool = false

    /// Hooks registered by the active `PDFAnnotationCanvasView.Coordinator` so
    /// toolbar/navigation/export actions can synchronously commit inline text
    /// edits or restore focus after a style popover closes.
    public var onCommitActiveTextEdits: (() -> Void)?
    public var onRestoreTextEditorFocus: (() -> Void)?

    public func commitActiveTextEdits() {
        onCommitActiveTextEdits?()
    }

    public func restoreTextEditorFocus() {
        onRestoreTextEditorFocus?()
    }

    // Store configurations for each tool for premium persistence during toggle
    private var toolWidths: [ToolType: CGFloat] = [
        .fountainPen: 3.0,
        .calligraphy: 5.0,
        .pencil: 2.0,
        .highlighter: 20.0,
        .eraser: 18.0,
        .shape: 3.0
    ]

    private var toolColors: [ToolType: Color] = [
        .fountainPen: .black,
        .calligraphy: .blue,
        .pencil: .gray,
        .highlighter: .yellow.opacity(CanvasViewModel.highlighterOpacity),
        .shape: .black,
        .textBox: Color(nsColor: TextBlockLayout.resolvedTextColor(from: TextBlockLayout.defaultColorHex))
    ]
    
    public var colorToolContext: PenColorToolContext {
        PenColorToolContext(tool: activeTool)
    }

    public init(settings: AppSettingsStore = .shared) {
        let defaultPenWidth = CGFloat(settings.defaultPenWidth)
        let defaultEraserWidth = CGFloat(settings.defaultEraserWidth)
        let defaultPenColor = settings.defaultPenColor
        let defaultHighlighterColor = settings.defaultHighlighterColor

        toolWidths[.fountainPen] = defaultPenWidth
        toolWidths[.eraser] = defaultEraserWidth
        toolWidths[.shape] = defaultPenWidth

        toolColors[.fountainPen] = defaultPenColor
        toolColors[.highlighter] = defaultHighlighterColor
        toolColors[.shape] = defaultPenColor

        applyToolDefaults()
    }

    public func effectiveColor(_ color: Color, for tool: ToolType? = nil) -> Color {
        let targetTool = tool ?? activeTool
        let components = PenColorComponents.from(color)
        if targetTool == .highlighter {
            return components.withOpacity(Double(CanvasViewModel.highlighterOpacity)).swiftUIColor
        }
        return components.swiftUIColor
    }

    public func applyStrokeColor(_ color: Color) {
        let resolved = effectiveColor(color)
        strokeColor = resolved
        if activeTool != .eraser && activeTool != .select {
            toolColors[activeTool] = resolved
        }
    }

    public func applyPresetColor(_ preset: Color) {
        let targetOpacity = PenColorComponents.clampedOpacity(
            PenColorComponents.from(strokeColor).opacity,
            for: colorToolContext
        )
        let presetComponents = PenColorComponents.from(preset).withOpacity(targetOpacity)
        applyStrokeColor(presetComponents.swiftUIColor)
    }
    
    public func selectTool(_ tool: ToolType) {
        // Save current configurations before switching (select carries no
        // width/color of its own; eraser has a size but no color; textBox uses textFontSize).
        if activeTool != .select {
            if activeTool != .textBox {
                toolWidths[activeTool] = strokeWidth
            }
            if activeTool != .eraser {
                toolColors[activeTool] = effectiveColor(strokeColor, for: activeTool)
            }
        }

        // Clear any active selection when leaving the select tool.
        if tool != .select {
            selectedShapeID = nil
        }

        activeTool = tool
        isDrawingMode = true
    }

    public func selectShape(_ kind: ShapeKind) {
        activeShapeKind = kind
        selectTool(.shape)
    }

    /// Switches to reading mode: the PDF's default pointer/interactions take
    /// over and the custom drawing cursor is no longer shown.
    public func enableReadingMode() {
        isDrawingMode = false
        selectedShapeID = nil
    }
    
    private func applyToolDefaults() {
        if let width = toolWidths[activeTool] {
            strokeWidth = width
        }
        if let color = toolColors[activeTool] {
            strokeColor = color
        }
    }
}
