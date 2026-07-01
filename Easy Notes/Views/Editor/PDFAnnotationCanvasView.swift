import SwiftUI
import PDFKit
import CoreData

class AnnotatedPDFPage: PDFPage {
    weak var noteVM: NoteViewModel?
    weak var canvasVM: CanvasViewModel?

    override func draw(with box: PDFDisplayBox, to context: CGContext) {
        super.draw(with: box, to: context)

        guard let doc = self.document,
              let noteVM = noteVM,
              let note = noteVM.selectedNote else { return }

        let pageIndex = doc.index(for: self)

        let strokesSet = note.strokes as? Set<Stroke> ?? []
        let pageStrokes = strokesSet.filter { $0.pageIndex == Int16(pageIndex) }

        context.saveGState()

        // Render existing strokes
        for stroke in pageStrokes {
            guard let pointsStr = stroke.points as String? else { continue }
            let points = deserializePoints(pointsStr)
            guard !points.isEmpty else { continue }

            context.setLineWidth(CGFloat(stroke.width))
            context.setLineCap(.round)
            context.setLineJoin(.round)

            let color = NSColor(hex: stroke.color) ?? NSColor.black
            context.setStrokeColor(color.cgColor)

            context.beginPath()
            context.move(to: points[0])
            for i in 1..<points.count {
                context.addLine(to: points[i])
            }
            context.strokePath()
        }
        context.restoreGState()
    }

    private func deserializePoints(_ str: String) -> [CGPoint] {
        var points: [CGPoint] = []
        let pairs = str.components(separatedBy: ";")
        for pair in pairs {
            let coords = pair.components(separatedBy: ",")
            if coords.count == 2,
               let x = Double(coords[0]),
               let y = Double(coords[1]) {
                points.append(CGPoint(x: x, y: y))
            }
        }
        return points
    }
}

class AnnotatedPDFDelegate: NSObject, PDFDocumentDelegate {
    func `class`(forPage pageType: PDFPage.Type) -> AnyClass {
        return AnnotatedPDFPage.self
    }
}

class NSPDFAnnotationView: PDFView {
    // Standard PDFView container
}

class PageDrawingCanvas: NSView {
    let pageIndex: Int
    weak var noteVM: NoteViewModel?
    weak var canvasVM: CanvasViewModel?

    private var activePoints: [CGPoint] = []
    private var trackingArea: NSTrackingArea?

    init(pageIndex: Int, noteVM: NoteViewModel?, canvasVM: CanvasViewModel?) {
        self.pageIndex = pageIndex
        self.noteVM = noteVM
        self.canvasVM = canvasVM
        super.init(frame: .zero)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let existing = trackingArea {
            removeTrackingArea(existing)
        }
        
        let options: NSTrackingArea.Options = [
            .mouseMoved,
            .cursorUpdate,
            .activeInActiveApp,
            .inVisibleRect
        ]
        
        let newArea = NSTrackingArea(
            rect: self.bounds,
            options: options,
            owner: self,
            userInfo: nil
        )
        addTrackingArea(newArea)
        trackingArea = newArea
    }

    override func cursorUpdate(with event: NSEvent) {
        updateCursor()
    }

    private func updateCursor() {
        guard let canvasVM = canvasVM, canvasVM.isDrawingMode else {
            NSCursor.arrow.set()
            return
        }
        
        let cursor: NSCursor
        if canvasVM.activeTool == .eraser {
            let cursorImage = NSImage.createEraserCursorImage()
            cursor = NSCursor(image: cursorImage, hotSpot: NSPoint(x: cursorImage.size.width / 2, y: cursorImage.size.height / 2))
        } else {
            let activeColor = NSColor(canvasVM.strokeColor)
            let cursorImage = NSImage.createCircleCursorImage(color: activeColor, diameter: canvasVM.strokeWidth)
            cursor = NSCursor(image: cursorImage, hotSpot: NSPoint(x: cursorImage.size.width / 2, y: cursorImage.size.height / 2))
        }
        cursor.set()
    }

    func invalidateCursor() {
        self.window?.invalidateCursorRects(for: self)
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        guard let note = noteVM?.selectedNote else { return }
        let strokesSet = note.strokes as? Set<Stroke> ?? []
        let pageStrokes = strokesSet.filter { $0.pageIndex == Int16(pageIndex) }

        let path = NSBezierPath()
        path.lineCapStyle = .round
        path.lineJoinStyle = .round

        for stroke in pageStrokes {
            guard let pointsStr = stroke.points as String? else { continue }
            let points = deserializePoints(pointsStr)
            guard !points.isEmpty else { continue }

            if let color = NSColor(hex: stroke.color) {
                color.setStroke()
            } else {
                NSColor.black.setStroke()
            }

            path.removeAllPoints()
            path.lineWidth = CGFloat(stroke.width)
            path.move(to: points[0])
            for i in 1..<points.count {
                path.line(to: points[i])
            }
            path.stroke()
        }

        if let canvasVM = canvasVM,
           canvasVM.isDrawingMode,
           let active = canvasVM.activeStroke,
           active.pageIndex == pageIndex {

            NSColor(canvasVM.strokeColor).setStroke()
            path.removeAllPoints()
            path.lineWidth = canvasVM.strokeWidth
            path.move(to: active.points[0])
            for i in 1..<active.points.count {
                path.line(to: active.points[i])
            }
            path.stroke()
        }
    }

    override func mouseDown(with event: NSEvent) {
        guard let canvasVM = canvasVM, canvasVM.isDrawingMode else {
            super.mouseDown(with: event)
            return
        }

        let point = self.convert(event.locationInWindow, from: nil)

        if canvasVM.activeTool == .eraser {
            eraseStrokeAt(point)
        } else {
            activePoints = [point]
            canvasVM.activeStroke = CanvasViewModel.ActiveStroke(pageIndex: pageIndex, points: activePoints)
            needsDisplay = true
        }
    }

    override func mouseDragged(with event: NSEvent) {
        guard let canvasVM = canvasVM, canvasVM.isDrawingMode else {
            super.mouseDragged(with: event)
            return
        }

        let point = self.convert(event.locationInWindow, from: nil)

        if canvasVM.activeTool == .eraser {
            eraseStrokeAt(point)
        } else {
            if let active = canvasVM.activeStroke, active.pageIndex == pageIndex {
                activePoints.append(point)
                canvasVM.activeStroke = CanvasViewModel.ActiveStroke(pageIndex: pageIndex, points: activePoints)
                needsDisplay = true
            }
        }
    }

    override func mouseUp(with event: NSEvent) {
        guard let canvasVM = canvasVM, canvasVM.isDrawingMode else {
            super.mouseUp(with: event)
            return
        }

        if canvasVM.activeTool != .eraser, !activePoints.isEmpty {
            saveActiveStroke()
        }

        activePoints.removeAll()
        canvasVM.activeStroke = nil
        needsDisplay = true
    }

    private func saveActiveStroke() {
        guard let note = noteVM?.selectedNote,
              let moc = note.managedObjectContext,
              let canvasVM = canvasVM else { return }

        let serialized = serializePoints(activePoints)
        guard !serialized.isEmpty else { return }

        let stroke = Stroke(context: moc)
        stroke.id = UUID()
        stroke.points = serialized
        stroke.width = Float(canvasVM.strokeWidth)
        stroke.color = NSColor(canvasVM.strokeColor).hexString
        stroke.createdAt = Date()
        stroke.note = note
        stroke.pageIndex = Int16(pageIndex)

        do {
            try moc.save()
            noteVM?.loadNotes()
            needsDisplay = true
        } catch {
            Swift.print("Failed to save drawing stroke: \(error)")
        }
    }

    private func eraseStrokeAt(_ point: CGPoint) {
        guard let note = noteVM?.selectedNote,
              let moc = note.managedObjectContext else { return }

        let strokesSet = note.strokes as? Set<Stroke> ?? []
        let pageStrokes = strokesSet.filter { $0.pageIndex == Int16(pageIndex) }

        var strokeToErase: Stroke? = nil
        for stroke in pageStrokes {
            guard let pointsStr = stroke.points as String? else { continue }
            let strokePoints = deserializePoints(pointsStr)
            guard !strokePoints.isEmpty else { continue }

            if let bbox = getBoundingBox(for: strokePoints) {
                let expandedBox = bbox.insetBy(dx: -18.0, dy: -18.0)
                if !expandedBox.contains(point) {
                    continue
                }
            }

            for p in strokePoints {
                let dist = sqrt(pow(p.x - point.x, 2) + pow(p.y - point.y, 2))
                if dist < 18.0 {
                    strokeToErase = stroke
                    break
                }
            }
            if strokeToErase != nil { break }
        }

        if let stroke = strokeToErase {
            moc.delete(stroke)
            do {
                try moc.save()
                noteVM?.loadNotes()
                needsDisplay = true
            } catch {
                Swift.print("Failed to delete stroke: \(error)")
            }
        }
    }

    private func serializePoints(_ pts: [CGPoint]) -> String {
        return pts.map { "\(String(format: "%.1f", $0.x)),\(String(format: "%.1f", $0.y))" }.joined(separator: ";")
    }

    private func deserializePoints(_ str: String) -> [CGPoint] {
        var pts: [CGPoint] = []
        let pairs = str.components(separatedBy: ";")
        for pair in pairs {
            let coords = pair.components(separatedBy: ",")
            if coords.count == 2,
               let x = Double(coords[0]),
               let y = Double(coords[1]) {
                pts.append(CGPoint(x: x, y: y))
            }
        }
        return pts
    }

    private func getBoundingBox(for pts: [CGPoint]) -> CGRect? {
        guard !pts.isEmpty else { return nil }
        var minX = pts[0].x
        var maxX = pts[0].x
        var minY = pts[0].y
        var maxY = pts[0].y
        for p in pts {
            minX = min(minX, p.x)
            maxX = max(maxX, p.x)
            minY = min(minY, p.y)
            maxY = max(maxY, p.y)
        }
        return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }
}

class AnnotatedPDFOverlayProvider: NSObject, PDFPageOverlayViewProvider {
    weak var noteVM: NoteViewModel?
    weak var canvasVM: CanvasViewModel?

    private var overlays: [Int: PageDrawingCanvas] = [:]

    init(noteVM: NoteViewModel?, canvasVM: CanvasViewModel?) {
        self.noteVM = noteVM
        self.canvasVM = canvasVM
    }

    func pdfView(_ pdfView: PDFView, overlayViewFor page: PDFPage) -> NSView? {
        guard let doc = page.document else { return nil }
        let pageIndex = doc.index(for: page)

        if let existing = overlays[pageIndex] {
            existing.noteVM = noteVM
            existing.canvasVM = canvasVM
            return existing
        }

        let canvas = PageDrawingCanvas(pageIndex: pageIndex, noteVM: noteVM, canvasVM: canvasVM)
        overlays[pageIndex] = canvas
        return canvas
    }

    func clearCache() {
        overlays.removeAll()
    }

    func redrawAll() {
        for canvas in overlays.values {
            canvas.needsDisplay = true
            canvas.invalidateCursor()
        }
    }
}

struct PDFAnnotationCanvasView: NSViewRepresentable {
    @ObservedObject var canvasVM: CanvasViewModel
    @ObservedObject var noteVM: NoteViewModel
    let noteId: UUID
    @Binding var zoomScale: CGFloat
    @Binding var selectedPageIndex: Int

    class Coordinator: NSObject {
        let provider: AnnotatedPDFOverlayProvider

        init(noteVM: NoteViewModel, canvasVM: CanvasViewModel) {
            self.provider = AnnotatedPDFOverlayProvider(noteVM: noteVM, canvasVM: canvasVM)
        }
    }

    func makeCoordinator() -> Coordinator {
        return Coordinator(noteVM: noteVM, canvasVM: canvasVM)
    }

    func makeNSView(context: Context) -> NSPDFAnnotationView {
        let pdfView = NSPDFAnnotationView()
        pdfView.displayMode = .singlePageContinuous
        pdfView.autoScales = true
        pdfView.displayBox = .mediaBox
        pdfView.backgroundColor = NSColor.windowBackgroundColor

        pdfView.pageOverlayViewProvider = context.coordinator.provider

        NotificationCenter.default.addObserver(forName: .PDFViewPageChanged, object: pdfView, queue: .main) { _ in
            if let page = pdfView.currentPage, let doc = pdfView.document {
                let index = doc.index(for: page)
                if selectedPageIndex != index {
                    selectedPageIndex = index
                }
            }
        }

        NotificationCenter.default.addObserver(forName: .PDFViewScaleChanged, object: pdfView, queue: .main) { _ in
            if pdfView.scaleFactor != zoomScale {
                zoomScale = pdfView.scaleFactor
            }
        }

        return pdfView
    }

    func updateNSView(_ nsView: NSPDFAnnotationView, context: Context) {
        if let note = noteVM.selectedNote, note.id == noteId {
            let doc = noteVM.getPDFDocument(for: note)
            if nsView.document !== doc {
                context.coordinator.provider.clearCache()
                nsView.document = doc
            }
        }

        context.coordinator.provider.noteVM = noteVM
        context.coordinator.provider.canvasVM = canvasVM
        context.coordinator.provider.redrawAll()

        if zoomScale == 1.0 {
            if !nsView.autoScales {
                nsView.autoScales = true
            }
        } else {
            if nsView.autoScales {
                nsView.autoScales = false
            }
            if nsView.scaleFactor != zoomScale {
                nsView.scaleFactor = zoomScale
            }
        }

        if let doc = nsView.document,
           selectedPageIndex >= 0 && selectedPageIndex < doc.pageCount,
           let page = doc.page(at: selectedPageIndex),
           nsView.currentPage != page {
            nsView.go(to: page)
        }
    }
    
    private func getBoundingBox(for pts: [CGPoint]) -> CGRect? {
        guard !pts.isEmpty else { return nil }
        var minX = pts[0].x
        var maxX = pts[0].x
        var minY = pts[0].y
        var maxY = pts[0].y
        for p in pts {
            minX = min(minX, p.x)
            maxX = max(maxX, p.x)
            minY = min(minY, p.y)
            maxY = max(maxY, p.y)
        }
        return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }
}

extension NSImage {
    static func createCircleCursorImage(color: NSColor, diameter: CGFloat) -> NSImage {
        let size = max(4.0, diameter)
        let imageSize = NSSize(width: size + 4, height: size + 4)
        let image = NSImage(size: imageSize)
        
        image.lockFocus()
        let rect = NSRect(x: 2, y: 2, width: size, height: size)
        let path = NSBezierPath(ovalIn: rect)
        
        color.setFill()
        path.fill()
        
        NSColor.white.setStroke()
        path.lineWidth = 1.0
        path.stroke()
        
        let outerRect = rect.insetBy(dx: -0.5, dy: -0.5)
        let outerPath = NSBezierPath(ovalIn: outerRect)
        NSColor.black.withAlphaComponent(0.25).setStroke()
        outerPath.lineWidth = 0.5
        outerPath.stroke()
        
        image.unlockFocus()
        return image
    }
    
    static func createEraserCursorImage() -> NSImage {
        let diameter: CGFloat = 36.0
        let imageSize = NSSize(width: diameter + 4, height: diameter + 4)
        let image = NSImage(size: imageSize)
        
        image.lockFocus()
        let rect = NSRect(x: 2, y: 2, width: diameter, height: diameter)
        let path = NSBezierPath(ovalIn: rect)
        
        NSColor.secondaryLabelColor.withAlphaComponent(0.6).setStroke()
        path.lineWidth = 1.0
        let pattern: [CGFloat] = [4.0, 4.0]
        path.setLineDash(pattern, count: 2, phase: 0.0)
        path.stroke()
        
        image.unlockFocus()
        return image
    }
}
