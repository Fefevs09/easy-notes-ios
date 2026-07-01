import Foundation
import SwiftUI
import Combine

public enum ToolType: String, CaseIterable {
    case fountainPen = "Caneta Tinteiro"
    case calligraphy = "Caligráfica"
    case pencil = "Lápis"
    case highlighter = "Marca-texto"
    case eraser = "Borracha"
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
    
    // Store configurations for each tool for premium persistence during toggle
    private var toolWidths: [ToolType: CGFloat] = [
        .fountainPen: 3.0,
        .calligraphy: 5.0,
        .pencil: 2.0,
        .highlighter: 20.0,
        .eraser: 15.0
    ]
    
    private var toolColors: [ToolType: Color] = [
        .fountainPen: .black,
        .calligraphy: .blue,
        .pencil: .gray,
        .highlighter: .yellow.opacity(0.3)
    ]
    
    public init() {
        applyToolDefaults()
    }
    
    public func selectTool(_ tool: ToolType) {
        // Save current configurations before switching
        if activeTool != .eraser {
            toolWidths[activeTool] = strokeWidth
            if activeTool != .highlighter {
                toolColors[activeTool] = strokeColor
            }
        }
        
        activeTool = tool
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
