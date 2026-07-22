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

    // Shape drawing / editing state
    @Published public var activeShapeKind: ShapeKind = .line
    @Published public var selectedShapeID: UUID?
    @Published public var shapeFillEnabled: Bool = false

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
        .highlighter: .yellow.opacity(0.3),
        .shape: .black
    ]
    
    public init() {
        applyToolDefaults()
    }
    
    public func selectTool(_ tool: ToolType) {
        // Save current configurations before switching (select carries no
        // width/color of its own; eraser has a size but no color).
        if activeTool != .select {
            toolWidths[activeTool] = strokeWidth
            if activeTool != .highlighter && activeTool != .eraser {
                toolColors[activeTool] = strokeColor
            }
        }

        // Clear any active selection when leaving the select tool.
        if tool != .select {
            selectedShapeID = nil
        }

        activeTool = tool
        isDrawingMode = true
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
