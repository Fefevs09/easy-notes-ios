import SwiftUI
import AppKit
import CoreData

struct DrawingCanvasView: NSViewRepresentable {
    @ObservedObject var canvasVM: CanvasViewModel
    @EnvironmentObject var noteVM: NoteViewModel
    @Environment(\.managedObjectContext) var moc
    let noteId: UUID?
    
    func makeNSView(context: Context) -> NSDrawingCanvas {
        let canvas = NSDrawingCanvas()
        canvas.canvasVM = canvasVM
        canvas.noteVM = noteVM
        canvas.moc = moc
        canvas.noteId = noteId
        return canvas
    }
    
    func updateNSView(_ nsView: NSDrawingCanvas, context: Context) {
        nsView.noteId = noteId
        nsView.canvasVM = canvasVM
        nsView.noteVM = noteVM
        nsView.moc = moc
        nsView.needsDisplay = true
    }
}

class NSDrawingCanvas: NSView {
    var canvasVM: CanvasViewModel?
    var noteVM: NoteViewModel?
    var moc: NSManagedObjectContext?
    
    // Clear point caches when note selection changes
    var noteId: UUID? {
        didSet {
            if oldValue != noteId {
                pointsCache.removeAll()
            }
        }
    }
    
    // Coordinates of the stroke currently being drawn
    private var activePoints: [CGPoint] = []
    
    // High-performance caches
    private var pointsCache: [UUID: [CGPoint]] = [:]
    private var hasUnsavedChanges = false
    
    override var isFlipped: Bool {
        // Keeps SwiftUI top-left coordinate alignment in AppKit
        return true
    }
    

    
    // MARK: - Drawing methods
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        
        // 1. Render Existing Persisted Strokes from Core Data
        drawPersistedStrokes()
        
        // 2. Render Active Stroke (currently drawing)
        drawActiveStroke()
    }
    
    private func drawPersistedStrokes() {
        guard let note = noteVM?.selectedNote else { return }
        let strokesSet = note.strokes as? Set<Stroke> ?? []
        
        // Sort chronologically so they layer correctly
        let sortedStrokes = strokesSet.sorted { $0.createdAt < $1.createdAt }
        
        for stroke in sortedStrokes {
            let points = getCachedPoints(for: stroke)
            guard !points.isEmpty else { continue }
            
            let path = NSBezierPath()
            path.lineWidth = CGFloat(stroke.width)
            path.lineCapStyle = .round
            path.lineJoinStyle = .round
            
            // Set Hex color with alpha support
            if let color = NSColor(hex: stroke.color) {
                color.setStroke()
            } else {
                NSColor.black.setStroke()
            }
            
            path.move(to: points[0])
            for i in 1..<points.count {
                path.line(to: points[i])
            }
            path.stroke()
        }
    }
    
    private func drawActiveStroke() {
        guard !activePoints.isEmpty, let canvasVM = canvasVM else { return }
        
        let path = NSBezierPath()
        path.lineWidth = canvasVM.strokeWidth
        path.lineCapStyle = .round
        path.lineJoinStyle = .round
        
        // Get active tool color
        let activeColor = NSColor(canvasVM.strokeColor)
        activeColor.setStroke()
        
        path.move(to: activePoints[0])
        for i in 1..<activePoints.count {
            path.line(to: activePoints[i])
        }
        path.stroke()
    }
    
    // MARK: - Mouse Event Capture
    override func mouseDown(with event: NSEvent) {
        guard canvasVM?.isDrawingMode == true, noteVM?.selectedNote != nil else { return }
        let point = self.convert(event.locationInWindow, from: nil)
        
        if canvasVM?.activeTool == .eraser {
            checkAndEraseStroke(at: point)
        } else {
            activePoints = [point]
            needsDisplay = true
        }
    }
    
    override func mouseDragged(with event: NSEvent) {
        guard canvasVM?.isDrawingMode == true, noteVM?.selectedNote != nil else { return }
        let point = self.convert(event.locationInWindow, from: nil)
        
        if canvasVM?.activeTool == .eraser {
            checkAndEraseStroke(at: point)
        } else {
            activePoints.append(point)
            needsDisplay = true
        }
    }
    
    override func mouseUp(with event: NSEvent) {
        guard canvasVM?.isDrawingMode == true, noteVM?.selectedNote != nil else { return }
        
        if canvasVM?.activeTool != .eraser && activePoints.count > 1 {
            saveActiveStroke()
        } else if canvasVM?.activeTool == .eraser && hasUnsavedChanges {
            // Commit and refresh only once at the end of the gesture (avoiding sessional lag)
            saveChanges()
            hasUnsavedChanges = false
        }
        activePoints = []
        needsDisplay = true
    }
    
    // MARK: - Core Data Save / Load
    private func saveActiveStroke() {
        guard let note = noteVM?.selectedNote, let moc = moc, let canvasVM = canvasVM else { return }
        
        let serialized = serializePoints(activePoints)
        guard !serialized.isEmpty else { return }
        
        let stroke = Stroke(context: moc)
        stroke.id = UUID()
        stroke.points = serialized
        stroke.width = Float(canvasVM.strokeWidth)
        stroke.color = NSColor(canvasVM.strokeColor).hexString
        stroke.createdAt = Date()
        stroke.note = note
        
        // Cache the points directly to skip deserializing them on subsequent redraws
        pointsCache[stroke.id] = activePoints
        
        do {
            try moc.save()
            noteVM?.loadNotes() // Updates views
        } catch {
            print("Failed to save drawing stroke: \(error)")
        }
    }
    
    private func saveChanges() {
        guard let moc = moc else { return }
        do {
            try moc.save()
            noteVM?.loadNotes()
        } catch {
            print("Failed to save Core Data changes: \(error)")
        }
    }
    
    private func checkAndEraseStroke(at point: CGPoint) {
        guard let note = noteVM?.selectedNote, let moc = moc else { return }
        let strokesSet = note.strokes as? Set<Stroke> ?? []
        
        var strokeToErase: Stroke? = nil
        for stroke in strokesSet {
            let strokePoints = getCachedPoints(for: stroke)
            guard !strokePoints.isEmpty else { continue }
            
            // 1. Sweep and Prune: Check bounding box first
            if let bbox = getBoundingBox(for: strokePoints) {
                let expandedBox = bbox.insetBy(dx: -18.0, dy: -18.0)
                if !expandedBox.contains(point) {
                    continue // Skip detailed checks for distant lines
                }
            }
            
            // 2. Detailed distance checks
            for p in strokePoints {
                let dist = sqrt(pow(p.x - point.x, 2) + pow(p.y - point.y, 2))
                if dist < 18.0 { // Eraser range
                    strokeToErase = stroke
                    break
                }
            }
            if strokeToErase != nil { break }
        }
        
        if let stroke = strokeToErase {
            pointsCache.removeValue(forKey: stroke.id)
            moc.delete(stroke)
            hasUnsavedChanges = true
            needsDisplay = true // Redraw immediately in-memory
        }
    }
    
    // MARK: - Bounding Box sweeps
    private func getBoundingBox(for points: [CGPoint]) -> CGRect? {
        guard !points.isEmpty else { return nil }
        var minX = points[0].x
        var maxX = points[0].x
        var minY = points[0].y
        var maxY = points[0].y
        
        for p in points {
            if p.x < minX { minX = p.x }
            if p.x > maxX { maxX = p.x }
            if p.y < minY { minY = p.y }
            if p.y > maxY { maxY = p.y }
        }
        return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }
    
    // MARK: - Point Serialization Helpers
    private func getCachedPoints(for stroke: Stroke) -> [CGPoint] {
        if let cached = pointsCache[stroke.id] {
            return cached
        }
        let points = deserializePoints(stroke.points)
        pointsCache[stroke.id] = points
        return points
    }
    
    private func serializePoints(_ points: [CGPoint]) -> String {
        return points.map { String(format: "%.1f,%.1f", $0.x, $0.y) }.joined(separator: ";")
    }
    
    private func deserializePoints(_ string: String) -> [CGPoint] {
        guard !string.isEmpty else { return [] }
        let coordinatePairs = string.components(separatedBy: ";")
        return coordinatePairs.compactMap { pair in
            let components = pair.components(separatedBy: ",")
            if components.count == 2,
               let x = Double(components[0]),
               let y = Double(components[1]) {
                return CGPoint(x: x, y: y)
            }
            return nil
        }
    }
}

// MARK: - NSColor Hex Extension
extension NSColor {
    convenience init?(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        
        if hexSanitized.hasPrefix("#") {
            hexSanitized.remove(at: hexSanitized.startIndex)
        }
        
        var rgb: UInt64 = 0
        guard Scanner(string: hexSanitized).scanHexInt64(&rgb) else { return nil }
        
        let r, g, b, a: CGFloat
        if hexSanitized.count == 6 {
            r = CGFloat((rgb & 0xFF0000) >> 16) / 255.0
            g = CGFloat((rgb & 0x00FF00) >> 8) / 255.0
            b = CGFloat(rgb & 0x0000FF) / 255.0
            a = 1.0
        } else if hexSanitized.count == 8 {
            r = CGFloat((rgb & 0xFF000000) >> 24) / 255.0
            g = CGFloat((rgb & 0x00FF0000) >> 16) / 255.0
            b = CGFloat((rgb & 0x0000FF00) >> 8) / 255.0
            a = CGFloat(rgb & 0x000000FF) / 255.0
        } else {
            return nil
        }
        
        self.init(red: r, green: g, blue: b, alpha: a)
    }
    
    var hexString: String {
        guard let colorSpaceCorrected = self.usingColorSpace(.deviceRGB) else {
            return "#000000"
        }
        let r = Int(round(colorSpaceCorrected.redComponent * 255.0))
        let g = Int(round(colorSpaceCorrected.greenComponent * 255.0))
        let b = Int(round(colorSpaceCorrected.blueComponent * 255.0))
        let a = Int(round(colorSpaceCorrected.alphaComponent * 255.0))
        
        if a < 255 {
            return String(format: "#%02X%02X%02X%02X", r, g, b, a)
        } else {
            return String(format: "#%02X%02X%02X", r, g, b)
        }
    }
}

// MARK: - Color Alpha Extension
extension Color {
    /// Returns this color with its alpha channel set (not multiplied) to `alpha`.
    func withAlpha(_ alpha: CGFloat) -> Color {
        Color(NSColor(self).withAlphaComponent(alpha))
    }
}
