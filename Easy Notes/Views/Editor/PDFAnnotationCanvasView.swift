import SwiftUI
import PDFKit
import CoreData

/// Deserializes a stroke's "x1,y1;x2,y2;..." point string back into CGPoints.
func deserializeStrokePoints(_ str: String) -> [CGPoint] {
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

/// Draws every Stroke belonging to `note` on `pageIndex` directly into `context`,
/// in the local coordinate space of the page overlay.
func renderStrokes(for note: Note, pageIndex: Int, into context: CGContext) {
    let strokesSet = note.strokes as? Set<Stroke> ?? []
    let pageStrokes = strokesSet.filter { $0.pageIndex == Int16(pageIndex) }
    guard !pageStrokes.isEmpty else { return }

    context.saveGState()
    for stroke in pageStrokes {
        guard let pointsStr = stroke.points as String? else { continue }
        let points = deserializeStrokePoints(pointsStr)
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

/// Renders saved drawings into a context in native PDF page coordinates.
func renderPageDrawings(for note: Note, pageIndex: Int, mediaBox: CGRect, into context: CGContext) {
    // PDFKit's overlay uses unrotated page points relative to the media box's
    // lower-left corner. The caller's CTM already applies the page rotation.
    context.saveGState()
    context.translateBy(x: mediaBox.minX, y: mediaBox.minY)
    renderShapes(for: note, pageIndex: pageIndex, into: context)
    renderStrokes(for: note, pageIndex: pageIndex, into: context)
    context.restoreGState()
}

// MARK: - Shape geometry

/// Normalized rect from two opposite corners (handles any drag direction).
func normalizedRect(_ a: CGPoint, _ b: CGPoint) -> CGRect {
    CGRect(x: min(a.x, b.x), y: min(a.y, b.y),
           width: abs(b.x - a.x), height: abs(b.y - a.y))
}

private func interpolate(_ a: CGPoint, _ b: CGPoint, steps: Int) -> [CGPoint] {
    guard steps > 0 else { return [a, b] }
    var pts: [CGPoint] = []
    for i in 0...steps {
        let t = CGFloat(i) / CGFloat(steps)
        pts.append(CGPoint(x: a.x + (b.x - a.x) * t, y: a.y + (b.y - a.y) * t))
    }
    return pts
}

private func arrowHeadLength(from a: CGPoint, to b: CGPoint) -> CGFloat {
    min(max(12, hypot(b.x - a.x, b.y - a.y) * 0.25), 26)
}

/// Builds the stroke/fill path for a shape from its control points. Used both
/// on screen (via the overlay's CGContext) and in PDF export.
func makeShapeCGPath(kind: ShapeKind, points: [CGPoint]) -> CGPath {
    let path = CGMutablePath()
    guard points.count >= 2 else {
        if let p = points.first { path.move(to: p); path.addLine(to: p) }
        return path
    }
    let a = points[0], b = points[1]
    switch kind {
    case .line:
        path.move(to: a); path.addLine(to: b)
    case .arrow:
        path.move(to: a); path.addLine(to: b)
        let angle = atan2(b.y - a.y, b.x - a.x)
        let head = arrowHeadLength(from: a, to: b)
        let left = CGPoint(x: b.x - head * cos(angle - .pi / 7),
                           y: b.y - head * sin(angle - .pi / 7))
        let right = CGPoint(x: b.x - head * cos(angle + .pi / 7),
                            y: b.y - head * sin(angle + .pi / 7))
        path.move(to: b); path.addLine(to: left)
        path.move(to: b); path.addLine(to: right)
    case .rectangle:
        path.addRect(normalizedRect(a, b))
    case .ellipse:
        path.addEllipse(in: normalizedRect(a, b))
    case .polygon:
        path.move(to: points[0])
        for p in points.dropFirst() { path.addLine(to: p) }
        path.closeSubpath()
    case .arc, .functionPlot:
        path.move(to: a); path.addLine(to: b)
    }
    return path
}

/// Round caps turn short dashes into dots. Dash the final path once so both
/// contrast layers follow the same curves and disconnected arrowhead wings.
func drawShapeCreationDots(on path: CGPath, zoom: CGFloat, arrowWingLength: CGFloat? = nil, in context: CGContext) {
    guard zoom.isFinite, zoom > 0 else { return }
    let spacing = 10 / zoom
    let dots = path.copy(dashingWithPhase: 0, lengths: [spacing * 0.01, spacing * 0.99])
    // Mark the segment endpoints when a short arrowhead fits between dots.
    var endpoints: [CGPoint] = []
    if let arrowWingLength, arrowWingLength <= spacing {
        path.applyWithBlock { element in
            if element.pointee.type == .addLineToPoint {
                endpoints.append(element.pointee.points[0])
            }
        }
    }
    context.saveGState()
    context.setLineCap(.round)
    for (width, color) in [(spacing * 0.5, NSColor.white), (spacing * 0.25, NSColor.black)] {
        context.setStrokeColor(color.cgColor)
        context.setLineWidth(width)
        context.addPath(dots)
        context.strokePath()
        context.setFillColor(color.cgColor)
        for end in endpoints {
            context.fillEllipse(in: CGRect(x: end.x - width / 2, y: end.y - width / 2,
                                           width: width, height: width))
        }
    }
    context.restoreGState()
}

/// Whether a shape encloses an area (fillable, and hit-testable by containment).
func shapeIsClosed(_ kind: ShapeKind) -> Bool {
    switch kind {
    case .rectangle, .ellipse, .polygon: return true
    case .line, .arrow, .arc, .functionPlot: return false
    }
}

/// A polyline approximation of the shape outline, for proximity hit-testing.
func sampleShapePolyline(kind: ShapeKind, points: [CGPoint]) -> [CGPoint] {
    guard points.count >= 2 else { return points }
    let a = points[0], b = points[1]
    switch kind {
    case .line, .arrow, .arc, .functionPlot:
        return interpolate(a, b, steps: 24)
    case .rectangle:
        let r = normalizedRect(a, b)
        let corners = [CGPoint(x: r.minX, y: r.minY), CGPoint(x: r.maxX, y: r.minY),
                       CGPoint(x: r.maxX, y: r.maxY), CGPoint(x: r.minX, y: r.maxY)]
        var pts: [CGPoint] = []
        for i in 0..<4 { pts += interpolate(corners[i], corners[(i + 1) % 4], steps: 10) }
        return pts
    case .ellipse:
        let r = normalizedRect(a, b)
        var pts: [CGPoint] = []
        for i in 0..<48 {
            let t = CGFloat(i) / 48.0 * 2.0 * .pi
            pts.append(CGPoint(x: r.midX + r.width / 2 * cos(t),
                               y: r.midY + r.height / 2 * sin(t)))
        }
        return pts
    case .polygon:
        var pts: [CGPoint] = []
        for i in 0..<points.count {
            pts += interpolate(points[i], points[(i + 1) % points.count], steps: 10)
        }
        return pts
    }
}

/// Draws every ShapeObject belonging to `note` on `pageIndex` into `context`.
/// Mirrors `renderStrokes`: works both for on-screen overlays and PDF export.
func renderShapes(for note: Note, pageIndex: Int, into context: CGContext) {
    let shapesSet = note.shapes as? Set<ShapeObject> ?? []
    let pageShapes = shapesSet.filter { $0.pageIndex == Int16(pageIndex) }
    guard !pageShapes.isEmpty else { return }

    context.saveGState()
    for shape in pageShapes {
        let kind = ShapeKind(rawValue: shape.kind) ?? .line
        let pts = deserializeStrokePoints(shape.points)
        guard pts.count >= 2 else { continue }
        let path = makeShapeCGPath(kind: kind, points: pts)

        if shapeIsClosed(kind), let fillHex = shape.fillColor,
           let fill = NSColor(hex: fillHex) {
            context.addPath(path)
            context.setFillColor(fill.cgColor)
            context.fillPath()
        }

        context.addPath(path)
        context.setLineWidth(CGFloat(shape.strokeWidth))
        context.setLineCap(.round)
        context.setLineJoin(.round)
        context.setStrokeColor((NSColor(hex: shape.strokeColor) ?? .black).cgColor)
        context.strokePath()
    }
    context.restoreGState()
}

/// Draws the cartesian grid / graph paper for `note` across `bounds`. `bounds`
/// is the overlay's bounds on screen and the page mediaBox during export — both
/// share the shape/stroke coordinate space, so the same code serves both.
func renderGrid(for note: Note, in bounds: CGRect, into context: CGContext) {
    guard let style = GridStyle(rawValue: note.gridStyle) else { return }
    renderGrid(style: style, spacing: CGFloat(max(4, note.gridSpacing)),
               origin: CGPoint(x: CGFloat(note.gridOriginX), y: CGFloat(note.gridOriginY)),
               color: note.gridInk, in: bounds, into: context)
}

extension Note {
    var gridInk: NSColor {
        guard let hex = gridColorHex, let components = PenColorComponents.fromHex(hex) else { return .black }
        return NSColor(components.opaqueColor)
    }
}

func renderGrid(style: GridStyle, spacing: CGFloat, origin: CGPoint, color: NSColor = .black, in bounds: CGRect, into context: CGContext) {
    guard style != .none else { return }
    let ox = origin.x, oy = origin.y

    // First grid line at or after the left/bottom edge, phase-aligned to origin.
    func firstLine(min: CGFloat, origin: CGFloat) -> CGFloat {
        origin + ceil((min - origin) / spacing) * spacing
    }

    context.saveGState()
    let minor = color.withAlphaComponent(0.16).cgColor

    if style == .dots {
        context.setFillColor(minor)
        var y = firstLine(min: bounds.minY, origin: oy)
        while y <= bounds.maxY {
            var x = firstLine(min: bounds.minX, origin: ox)
            while x <= bounds.maxX {
                context.fillEllipse(in: CGRect(x: x - 1, y: y - 1, width: 2, height: 2))
                x += spacing
            }
            y += spacing
        }
        context.restoreGState()
        return
    }

    context.setLineWidth(0.5)
    context.setStrokeColor(minor)

    // Horizontal lines (both `lines` and `grid`).
    var y = firstLine(min: bounds.minY, origin: oy)
    while y <= bounds.maxY {
        context.move(to: CGPoint(x: bounds.minX, y: y))
        context.addLine(to: CGPoint(x: bounds.maxX, y: y))
        y += spacing
    }
    // Vertical lines (`grid` only — `lines` is ruled-notebook style).
    if style == .grid {
        var x = firstLine(min: bounds.minX, origin: ox)
        while x <= bounds.maxX {
            context.move(to: CGPoint(x: x, y: bounds.minY))
            context.addLine(to: CGPoint(x: x, y: bounds.maxY))
            x += spacing
        }
    }
    context.strokePath()

    context.restoreGState()
}

/// Cached tool cursor, keyed on the inputs that affect its appearance, so the
/// high-frequency `mouseMoved` reassert doesn't re-rasterize an NSImage on every
/// event. A single file-scoped cache is fine: all cursor work happens on the
/// main thread and the PDFView and its overlays always share the same tool state.
private var _toolCursorCache: (signature: String, cursor: NSCursor)?

// The base PDF is immutable while editing. Sample once per page, excluding
// transient overlays. White represents unpainted areas of the paper.
private let darkPaperCache = NSMapTable<PDFPage, NSNumber>.weakToStrongObjects()

func shapePaperIsDark(_ page: PDFPage?) -> Bool {
    guard let page, let pdf = page.pageRef else { return false }
    if let cached = darkPaperCache.object(forKey: page) { return cached.boolValue }
    let side = 16
    guard let context = CGContext(data: nil, width: side, height: side,
                                  bitsPerComponent: 8, bytesPerRow: side,
                                  space: CGColorSpaceCreateDeviceGray(),
                                  bitmapInfo: CGImageAlphaInfo.none.rawValue),
          let data = context.data else { return false }
    let bounds = CGRect(x: 0, y: 0, width: side, height: side)
    context.setFillColor(gray: 1, alpha: 1)
    context.fill(bounds)
    context.concatenate(pdf.getDrawingTransform(.cropBox, rect: bounds, rotate: 0,
                                                preserveAspectRatio: false))
    context.drawPDFPage(pdf)
    let pixels = UnsafeBufferPointer(start: data.assumingMemoryBound(to: UInt8.self),
                                     count: side * side)
    let dark = pixels.filter { $0 < 118 }.count > pixels.count / 2
    darkPaperCache.setObject(NSNumber(value: dark), forKey: page)
    return dark
}

/// The NSCursor for the active drawing tool, or `nil` when no drawing cursor
/// applies (reading mode or the `.select` tool — callers should fall back to the
/// system arrow). Shared by both the PDFView and the page overlays.
func toolCursor(for canvasVM: CanvasViewModel, zoom: CGFloat, page: PDFPage? = nil) -> NSCursor? {
    guard canvasVM.isDrawingMode, canvasVM.activeTool != .select else { return nil }

    let darkPaper = canvasVM.activeTool == .shape && shapePaperIsDark(page)
    let signature = "\(canvasVM.activeTool.rawValue)|\(canvasVM.strokeColor)|\(canvasVM.strokeWidth)|\(zoom)|\(darkPaper)"
    if let cached = _toolCursorCache, cached.signature == signature { return cached.cursor }

    let cursorImage: NSImage
    switch canvasVM.activeTool {
    case .shape:
        cursorImage = NSImage.createShapeCrosshairImage(darkPaper: darkPaper)
    case .eraser:
        // Erase radius in page space is canvasVM.strokeWidth (see eraseAt);
        // footprint is the diameter, scaled to match the current zoom.
        cursorImage = NSImage.createEraserCursorImage(footprint: canvasVM.strokeWidth * 2 * zoom)
    default:
        // Brush ring matches the actual painted width: page points × zoom.
        cursorImage = NSImage.createBrushCursorImage(
            color: NSColor(canvasVM.strokeColor),
            diameter: canvasVM.strokeWidth * zoom
        )
    }

    let hotSpot = NSPoint(x: cursorImage.size.width / 2, y: cursorImage.size.height / 2)
    let cursor = NSCursor(image: cursorImage, hotSpot: hotSpot)
    _toolCursorCache = (signature, cursor)
    return cursor
}

class NSPDFAnnotationView: PDFView {
    /// Active drawing-tool state, used to render the correct tool cursor. The
    /// cursor is owned here — on the PDFView — rather than only on the page
    /// overlay, because PDFKit drives cursor / mouse-moved handling at the
    /// PDFView level. The overlay never reliably receives `mouseMoved` (the
    /// window doesn't enable `acceptsMouseMovedEvents` and the overlay is a
    /// PDFKit-managed subview), so a cursor stomped back to the arrow after a
    /// stroke saves would never recover there. PDFView already gets these events
    /// (it's how the I-beam appears over selectable text), so overrides here
    /// actually fire and can restore the tool cursor.
    weak var canvasVM: CanvasViewModel?
    weak var overlayProvider: AnnotatedPDFOverlayProvider?
    var currentZoom: CGFloat = 1.0

    private func rectCursor() -> NSCursor? {
        guard let canvasVM = canvasVM else { return nil }
        let hoveredPage = canvasVM.activeTool == .shape ? window.flatMap {
            page(for: convert($0.mouseLocationOutsideOfEventStream, from: nil), nearest: false)
        } : nil
        return toolCursor(for: canvasVM, zoom: currentZoom, page: hoveredPage)
    }

    private func pointerCursor() -> NSCursor? {
        guard let canvasVM = canvasVM else { return nil }
        if let selectionCursor = overlayProvider?.selectionCursor(in: self) {
            return selectionCursor
        }
        if canvasVM.isDrawingMode, canvasVM.activeTool == .select {
            return .arrow
        }
        return rectCursor()
    }

    override func keyDown(with event: NSEvent) {
        if overlayProvider?.handleKeyDown(event, in: self) == true {
            return
        }
        super.keyDown(with: event)
    }

    override func resetCursorRects() {
        super.resetCursorRects()
        if let cursor = rectCursor() {
            addCursorRect(bounds, cursor: cursor)
        }
    }

    override func cursorUpdate(with event: NSEvent) {
        if let cursor = pointerCursor() {
            cursor.set()
        } else {
            super.cursorUpdate(with: event)
        }
    }

    override func mouseMoved(with event: NSEvent) {
        super.mouseMoved(with: event)
        // Reassert on every move: PDFView reliably receives mouse-moved events,
        // so this restores the tool cursor on the first movement after any
        // PDFKit relayout stomped it back to the default arrow.
        pointerCursor()?.set()
    }

    /// Force the tool cursor if the pointer is currently inside the view. Used
    /// after a save/relayout when the pointer is stationary and no move event
    /// will fire to trigger the restoration in `mouseMoved`.
    func reassertCursorIfInside() {
        guard let window = window, let cursor = pointerCursor() else { return }
        let point = convert(window.mouseLocationOutsideOfEventStream, from: nil)
        if bounds.contains(point) { cursor.set() }
    }

    /// Rebuild the cursor rect after tool / color / width / zoom changes.
    func refreshCursor() {
        window?.invalidateCursorRects(for: self)
    }
}

class PageDrawingCanvas: NSView {
    let pageIndex: Int
    weak var paperPage: PDFPage?
    weak var pdfView: PDFView?
    weak var noteVM: NoteViewModel?
    weak var canvasVM: CanvasViewModel?

    /// Current PDFView zoom, pushed in by the overlay provider so the cursor
    /// footprint can match the on-screen stroke width. Rebuilds the cursor when
    /// it changes.
    var currentZoom: CGFloat = 1.0 {
        didSet {
            if abs(oldValue - currentZoom) > 0.001 {
                invalidateCursor()
                if activeShapeStart != nil { needsDisplay = true }
            }
        }
    }

    private var activePoints: [CGPoint] = []

    // Shape drawing preview (while dragging out a new shape).
    private var activeShapeStart: CGPoint?
    private var activeShapePoints: [CGPoint] = []

    // Unified selection, hit-test, marquee, and group movement controller.
    let selectionController = CanvasSelectionController()

    var pageToOverlayTransform: CGAffineTransform {
        guard superview != nil, window != nil, let page = paperPage, let pdfView else { return .identity }
        let origin = convert(pdfView.convert(.zero as CGPoint, from: page), from: pdfView)
        let x = convert(pdfView.convert(CGPoint(x: 1, y: 0), from: page), from: pdfView)
        let y = convert(pdfView.convert(CGPoint(x: 0, y: 1), from: page), from: pdfView)
        let transform = CGAffineTransform(
            a: x.x - origin.x, b: x.y - origin.y,
            c: y.x - origin.x, d: y.y - origin.y,
            tx: origin.x, ty: origin.y
        )
        let det = transform.a * transform.d - transform.b * transform.c
        return abs(det) > 1e-6 ? transform : .identity
    }

    init(pageIndex: Int, noteVM: NoteViewModel?, canvasVM: CanvasViewModel?) {
        self.pageIndex = pageIndex
        self.noteVM = noteVM
        self.canvasVM = canvasVM
        super.init(frame: .zero)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    /// PDFView/NSScrollView manage their own cursor via this same declarative
    /// cursor-rect system; registering our cursor imperatively via NSCursor.set()
    /// would get silently overridden any time AppKit recomputes cursor rects
    /// (scrolling, resizing, etc.). Participating in resetCursorRects/addCursorRect
    /// instead keeps our cursor correctly prioritized alongside PDFKit's own.
    override func resetCursorRects() {
        super.resetCursorRects()
        addCursorRect(bounds, cursor: currentToolCursor())
    }

    /// The cursor is driven by a tracking area combining `.cursorUpdate` (fires
    /// when the pointer *enters* the view) with `.mouseMoved` (fires on *every*
    /// movement inside it). The `.mouseMoved` half is essential: `.cursorUpdate`
    /// is edge-triggered, so if PDFKit stomps the cursor back to the arrow while
    /// the pointer is stationary inside the canvas — which happens right after a
    /// stroke saves and the page redraws — `cursorUpdate` would never re-fire
    /// (the pointer never left), and the arrow would stick until you moved off
    /// the page and back. Reasserting on `mouseMoved` restores the tool cursor
    /// on the very next pixel of movement instead.
    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        for area in trackingAreas { removeTrackingArea(area) }
        let options: NSTrackingArea.Options = [.activeInActiveApp, .inVisibleRect, .cursorUpdate, .mouseMoved]
        addTrackingArea(NSTrackingArea(rect: .zero, options: options, owner: self, userInfo: nil))
    }

    override func cursorUpdate(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        guard applyToolCursor(at: point) else {
            super.cursorUpdate(with: event)
            return
        }
    }

    override func mouseMoved(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        guard applyToolCursor(at: point) else {
            super.mouseMoved(with: event)
            return
        }
    }

    /// Sets the tool or selection cursor if we're in an active drawing/select mode.
    @discardableResult
    private func applyToolCursor(at point: CGPoint? = nil) -> Bool {
        guard let canvasVM = canvasVM, canvasVM.isDrawingMode else { return false }
        let targetPoint = point ?? window.map { convert($0.mouseLocationOutsideOfEventStream, from: nil) }
        if let selectionCursor = targetPoint.flatMap({ selectionCursor(at: $0) }) {
            selectionCursor.set()
            return true
        }
        if canvasVM.activeTool == .select {
            NSCursor.arrow.set()
            return true
        }
        currentToolCursor(at: targetPoint).set()
        return true
    }

    /// Force the tool cursor if the pointer is currently over this overlay.
    /// Called after PDFKit-driven updates (which can stomp the cursor while the
    /// pointer is stationary, e.g. right after a stroke is saved).
    func applyCursorIfInside() {
        guard let window = window, let canvasVM = canvasVM,
              canvasVM.isDrawingMode else { return }
        let point = convert(window.mouseLocationOutsideOfEventStream, from: nil)
        if bounds.contains(point) {
            if let selectionCursor = selectionCursor(at: point) {
                selectionCursor.set()
            } else if canvasVM.activeTool == .select {
                NSCursor.arrow.set()
            } else {
                currentToolCursor(at: point).set()
            }
        }
    }

    func selectionCursor(at point: CGPoint) -> NSCursor? {
        selectionController.cursor(
            at: point,
            note: noteVM?.selectedNote,
            pageIndex: pageIndex,
            pageToOverlay: pageToOverlayTransform,
            canvasVM: canvasVM
        )
    }

    /// The cursor for the active tool. Extracted so it can be both registered as
    /// a cursor rect and `.set()` imperatively right after a gesture ends —
    /// AppKit only rebuilds cursor rects on the next mouse move, so a stationary
    /// pointer would otherwise revert to the arrow the moment a stroke finishes.
    /// Delegates to the shared `toolCursor(for:zoom:)` builder (same cache the
    /// PDFView uses).
    private func currentToolCursor(at point: CGPoint? = nil) -> NSCursor {
        if let point, let selectionCursor = selectionCursor(at: point) {
            return selectionCursor
        }
        guard let canvasVM = canvasVM else { return .arrow }
        return toolCursor(for: canvasVM, zoom: currentZoom, page: paperPage) ?? .arrow
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        guard let canvasVM = canvasVM, canvasVM.isDrawingMode else {
            return nil
        }
        return super.hitTest(point)
    }

    /// Call whenever the conditions resetCursorRects() depends on change
    /// (drawing mode toggle, active tool, color, width) so AppKit rebuilds
    /// the cursor rect with the up-to-date cursor.
    ///
    /// Also defensively re-enables cursor rects: PDFView/NSScrollView disable
    /// them for the duration of a mouse-down gesture (to avoid flicker while
    /// panning) and re-enable them once *they* see the matching mouseUp. Since
    /// this view consumes mouseDown/mouseDragged/mouseUp entirely while
    /// drawing (never forwarding to super), that mouseUp never reaches
    /// PDFView, so cursor rects would otherwise stay disabled for the rest of
    /// the session after the very first stroke.
    func invalidateCursor() {
        window?.enableCursorRects()
        window?.invalidateCursorRects(for: self)
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        guard let note = noteVM?.selectedNote else { return }

        // Bottom layers (grid, images, and persisted shapes) via the shared CGContext path.
        if let cg = NSGraphicsContext.current?.cgContext {
            renderGrid(for: note, in: bounds, into: cg)
            if paperPage != nil, pdfView != nil {
                cg.saveGState()
                cg.concatenate(pageToOverlayTransform)
                renderEditorImages(for: note, pageIndex: pageIndex, into: cg)
                cg.restoreGState()
            }
            renderShapes(for: note, pageIndex: pageIndex, into: cg)
        }

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

        guard let cg = NSGraphicsContext.current?.cgContext,
              let canvasVM = canvasVM, canvasVM.isDrawingMode else { return }

        // Live preview of the shape currently being dragged out.
        if canvasVM.activeTool == .shape, activeShapePoints.count >= 2 {
            let kind = canvasVM.activeShapeKind
            let previewPath = makeShapeCGPath(kind: kind, points: activeShapePoints)
            cg.saveGState()
            cg.addPath(previewPath)
            cg.setLineWidth(canvasVM.strokeWidth)
            cg.setLineCap(.round)
            cg.setLineJoin(.round)
            cg.setStrokeColor(NSColor(canvasVM.strokeColor).withAlphaComponent(0.9).cgColor)
            cg.strokePath()
            cg.restoreGState()
            let wing = kind == .arrow ? arrowHeadLength(from: activeShapePoints[0], to: activeShapePoints[1]) : nil
            drawShapeCreationDots(on: previewPath, zoom: currentZoom, arrowWingLength: wing, in: cg)
        }

        // Selection handles, group bounds, and marquee rectangle.
        selectionController.drawOverlay(
            in: cg,
            note: note,
            pageIndex: pageIndex,
            pageToOverlay: pageToOverlayTransform,
            canvasVM: canvasVM
        )
    }

    override var acceptsFirstResponder: Bool { true }
    override var canBecomeKeyView: Bool { false }

    override func mouseDown(with event: NSEvent) {
        guard let canvasVM = canvasVM, canvasVM.isDrawingMode else {
            super.mouseDown(with: event)
            return
        }

        window?.makeFirstResponder(self)
        let point = self.convert(event.locationInWindow, from: nil)

        switch canvasVM.activeTool {
        case .eraser:
            eraseAt(point)
        case .shape:
            activeShapeStart = point
            activeShapePoints = [point, point]
            needsDisplay = true
        case .select:
            if let note = noteVM?.selectedNote {
                selectionController.beginSelectInteraction(
                    at: point,
                    modifierFlags: event.modifierFlags,
                    note: note,
                    pageIndex: pageIndex,
                    pageToOverlay: pageToOverlayTransform,
                    canvasVM: canvasVM
                )
            } else {
                canvasVM.clearSelection()
            }
            needsDisplay = true
        default:
            if let note = noteVM?.selectedNote,
               selectionController.beginPenInteractionIfInsideSelection(
                at: point,
                note: note,
                pageIndex: pageIndex,
                pageToOverlay: pageToOverlayTransform,
                canvasVM: canvasVM
               ) {
                needsDisplay = true
            } else {
                activePoints = [point]
                canvasVM.activeStroke = CanvasViewModel.ActiveStroke(pageIndex: pageIndex, points: activePoints)
                needsDisplay = true
            }
        }

        invalidateCursor()
        applyToolCursor(at: point)
    }

    override func mouseDragged(with event: NSEvent) {
        guard let canvasVM = canvasVM, canvasVM.isDrawingMode else {
            super.mouseDragged(with: event)
            return
        }

        let point = self.convert(event.locationInWindow, from: nil)

        switch canvasVM.activeTool {
        case .eraser:
            eraseAt(point)
        case .shape:
            if let start = activeShapeStart {
                activeShapePoints = [start, point]
                needsDisplay = true
            }
        case .select:
            if let note = noteVM?.selectedNote,
               selectionController.updateDrag(
                to: point,
                note: note,
                pageIndex: pageIndex,
                pageToOverlay: pageToOverlayTransform,
                canvasVM: canvasVM
               ) {
                needsDisplay = true
            }
        default:
            if selectionController.isDragging,
               let note = noteVM?.selectedNote,
               selectionController.updateDrag(
                to: point,
                note: note,
                pageIndex: pageIndex,
                pageToOverlay: pageToOverlayTransform,
                canvasVM: canvasVM
               ) {
                needsDisplay = true
            } else if let active = canvasVM.activeStroke, active.pageIndex == pageIndex {
                activePoints.append(point)
                canvasVM.activeStroke = CanvasViewModel.ActiveStroke(pageIndex: pageIndex, points: activePoints)
                needsDisplay = true
            }
        }

        applyToolCursor(at: point)
    }

    override func mouseUp(with event: NSEvent) {
        guard let canvasVM = canvasVM, canvasVM.isDrawingMode else {
            super.mouseUp(with: event)
            return
        }

        let point = self.convert(event.locationInWindow, from: nil)

        switch canvasVM.activeTool {
        case .eraser:
            break
        case .shape:
            saveActiveShape()
            activeShapeStart = nil
            activeShapePoints.removeAll()
        case .select:
            selectionController.endDrag(
                note: noteVM?.selectedNote,
                noteVM: noteVM,
                pageIndex: pageIndex,
                pageToOverlay: pageToOverlayTransform,
                canvasVM: canvasVM
            )
        default:
            if selectionController.isDragging {
                selectionController.endDrag(
                    note: noteVM?.selectedNote,
                    noteVM: noteVM,
                    pageIndex: pageIndex,
                    pageToOverlay: pageToOverlayTransform,
                    canvasVM: canvasVM
                )
            } else {
                if !activePoints.isEmpty { saveActiveStroke() }
                activePoints.removeAll()
                canvasVM.activeStroke = nil
            }
        }

        needsDisplay = true
        invalidateCursor()
        // Re-assert the tool cursor immediately: the pointer is stationary at
        // release, so AppKit won't rebuild the cursor rect until the next move
        // and would otherwise show the default arrow in the meantime.
        currentToolCursor(at: point).set()
    }

    override func keyDown(with event: NSEvent) {
        if selectionController.handleKeyDown(
            event,
            note: noteVM?.selectedNote,
            noteVM: noteVM,
            pageIndex: pageIndex,
            pageToOverlay: pageToOverlayTransform,
            canvasVM: canvasVM,
            firstResponder: window?.firstResponder
        ) {
            needsDisplay = true
            invalidateCursor()
            return
        }
        super.keyDown(with: event)
    }

    // MARK: Shape creation

    private func saveActiveShape() {
        guard let note = noteVM?.selectedNote,
              let moc = note.managedObjectContext,
              let canvasVM = canvasVM,
              activeShapePoints.count >= 2 else { return }

        // Ignore accidental taps that produced no real drag.
        let a = activeShapePoints[0], b = activeShapePoints[1]
        if hypot(b.x - a.x, b.y - a.y) < 3.0 { return }

        let shape = ShapeObject(context: moc)
        shape.id = UUID()
        shape.kind = canvasVM.activeShapeKind.rawValue
        shape.points = serializePoints(activeShapePoints)
        shape.strokeWidth = Float(canvasVM.strokeWidth)
        shape.strokeColor = NSColor(canvasVM.strokeColor).hexString
        shape.fillColor = canvasVM.shapeFillEnabled
            ? NSColor(canvasVM.strokeColor).withAlphaComponent(0.2).hexString : nil
        shape.createdAt = Date()
        shape.note = note
        shape.pageIndex = Int16(pageIndex)

        do {
            try moc.save()
            noteVM?.loadNotes()
        } catch {
            Swift.print("Failed to save shape: \(error)")
        }
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

    private func eraseAt(_ point: CGPoint) {
        guard let note = noteVM?.selectedNote,
              let moc = note.managedObjectContext else { return }

        var objectToErase: NSManagedObject? = nil

        // Erase radius in page space, adjustable via the toolbar size slider.
        let radius = canvasVM?.strokeWidth ?? 18.0

        // Freehand strokes.
        let strokesSet = note.strokes as? Set<Stroke> ?? []
        let pageStrokes = strokesSet.filter { $0.pageIndex == Int16(pageIndex) }
        for stroke in pageStrokes {
            guard let pointsStr = stroke.points as String? else { continue }
            let strokePoints = deserializePoints(pointsStr)
            guard !strokePoints.isEmpty else { continue }

            if let bbox = getBoundingBox(for: strokePoints) {
                let expandedBox = bbox.insetBy(dx: -radius, dy: -radius)
                if !expandedBox.contains(point) { continue }
            }

            for p in strokePoints where sqrt(pow(p.x - point.x, 2) + pow(p.y - point.y, 2)) < radius {
                objectToErase = stroke
                break
            }
            if objectToErase != nil { break }
        }

        // Geometric shapes (only if no stroke was hit).
        if objectToErase == nil {
            let shapesSet = note.shapes as? Set<ShapeObject> ?? []
            let pageShapes = shapesSet.filter { $0.pageIndex == Int16(pageIndex) }
            for shape in pageShapes {
                let kind = ShapeKind(rawValue: shape.kind) ?? .line
                let pts = deserializeStrokePoints(shape.points)
                guard pts.count >= 2 else { continue }
                let outline = sampleShapePolyline(kind: kind, points: pts)
                if outline.contains(where: { sqrt(pow($0.x - point.x, 2) + pow($0.y - point.y, 2)) < radius }) {
                    objectToErase = shape
                    break
                }
            }
        }

        if let obj = objectToErase {
            moc.delete(obj)
            do {
                try moc.save()
                noteVM?.loadNotes()
                needsDisplay = true
            } catch {
                Swift.print("Failed to delete object: \(error)")
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
    private(set) var zoom: CGFloat = 1.0

    init(noteVM: NoteViewModel?, canvasVM: CanvasViewModel?) {
        self.noteVM = noteVM
        self.canvasVM = canvasVM
    }

    func pdfView(_ pdfView: PDFView, overlayViewFor page: PDFPage) -> NSView? {
        guard let doc = page.document else { return nil }
        let pageIndex = doc.index(for: page)

        if let existing = overlays[pageIndex] {
            existing.paperPage = page
            existing.pdfView = pdfView
            existing.noteVM = noteVM
            existing.canvasVM = canvasVM
            existing.currentZoom = zoom
            return existing
        }

        let canvas = PageDrawingCanvas(pageIndex: pageIndex, noteVM: noteVM, canvasVM: canvasVM)
        canvas.paperPage = page
        canvas.pdfView = pdfView
        canvas.currentZoom = zoom
        overlays[pageIndex] = canvas
        return canvas
    }

    /// Propagates the current PDFView zoom to every overlay so their cursors
    /// track the on-screen stroke size.
    func setZoom(_ newZoom: CGFloat) {
        guard abs(zoom - newZoom) > 0.001 else { return }
        zoom = newZoom
        for canvas in overlays.values {
            canvas.currentZoom = newZoom
        }
    }

    func clearCache() {
        for canvas in overlays.values {
            canvas.selectionController.cancelActiveDrag()
        }
        overlays.removeAll()
    }

    func redrawAll() {
        let incompatibleForSelectionDrag = canvasVM.map {
            !$0.isDrawingMode || $0.activeTool == .eraser || $0.activeTool == .shape
        } ?? true

        for canvas in overlays.values {
            if incompatibleForSelectionDrag && canvas.selectionController.isDragging {
                canvas.selectionController.cancelActiveDrag()
            }
            canvas.needsDisplay = true
            canvas.invalidateCursor()
        }
    }

    /// Re-assert the tool cursor on whichever overlay currently holds the
    /// pointer. Call this at the tail of updateNSView, after PDFKit has finished
    /// any relayout that could have reset the cursor to the default arrow.
    func reassertCursors() {
        for canvas in overlays.values {
            canvas.applyCursorIfInside()
        }
    }

    func selectionCursor(in pdfView: PDFView) -> NSCursor? {
        guard let window = pdfView.window else { return nil }
        let viewPoint = pdfView.convert(window.mouseLocationOutsideOfEventStream, from: nil)
        guard pdfView.bounds.contains(viewPoint),
              let page = pdfView.page(for: viewPoint, nearest: false),
              let doc = pdfView.document else {
            return nil
        }
        let pageIndex = doc.index(for: page)
        guard let canvas = overlays[pageIndex] else { return nil }
        let localPoint = canvas.convert(viewPoint, from: pdfView)
        return canvas.selectionCursor(at: localPoint)
    }

    func handleKeyDown(_ event: NSEvent, in pdfView: PDFView) -> Bool {
        guard let canvasVM, !canvasVM.selectedObjects.isEmpty || overlays.values.contains(where: { $0.selectionController.isDragging }) else {
            return false
        }
        let targetPage = canvasVM.selectedPageIndexForSelection
            ?? pdfView.currentPage.flatMap { pdfView.document?.index(for: $0) }
        guard let targetPage,
              let canvas = overlays[targetPage],
              canvas.window != nil,
              canvas.superview != nil,
              let paperPage = canvas.paperPage,
              pdfView.currentPage === paperPage || pdfView.visiblePages.contains(where: { $0 === paperPage }) else {
            return false
        }
        if canvas.selectionController.handleKeyDown(
            event,
            note: noteVM?.selectedNote,
            noteVM: noteVM,
            pageIndex: targetPage,
            pageToOverlay: canvas.pageToOverlayTransform,
            canvasVM: canvasVM,
            firstResponder: pdfView.window?.firstResponder
        ) {
            canvas.needsDisplay = true
            canvas.invalidateCursor()
            return true
        }
        return false
    }
}

@MainActor
final class CanvasFocusTarget {
    weak var view: NSPDFAnnotationView?

    func focus() {
        guard let view else { return }
        view.window?.makeFirstResponder(view)
    }
}

struct PDFAnnotationCanvasView: NSViewRepresentable {
    @ObservedObject var canvasVM: CanvasViewModel
    @ObservedObject var noteVM: NoteViewModel
    let noteId: UUID
    let focusTarget: CanvasFocusTarget
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
        focusTarget.view = pdfView
        pdfView.displayMode = .singlePageContinuous
        // Zoom is driven purely by `zoomScale` (1.0 == 100%). autoScales is left
        // off so PDFKit never overwrites the user's zoom with a transient
        // fit-to-view factor computed during early layout.
        pdfView.autoScales = false
        pdfView.minScaleFactor = 0.25
        pdfView.maxScaleFactor = 4.0
        pdfView.displayBox = .mediaBox
        pdfView.backgroundColor = PixelTheme.nsCanvasBackground

        pdfView.pageOverlayViewProvider = context.coordinator.provider
        pdfView.overlayProvider = context.coordinator.provider

        NotificationCenter.default.addObserver(forName: .PDFViewPageChanged, object: pdfView, queue: .main) { _ in
            if let page = pdfView.currentPage, let doc = pdfView.document {
                let index = doc.index(for: page)
                if selectedPageIndex != index {
                    selectedPageIndex = index
                }
            }
        }

        // Reflect user-driven zoom (pinch / trackpad) back into the label. The
        // epsilon guard prevents a feedback loop with our own programmatic
        // scaleFactor assignments in updateNSView.
        NotificationCenter.default.addObserver(forName: .PDFViewScaleChanged, object: pdfView, queue: .main) { [weak pdfView, weak provider = context.coordinator.provider] _ in
            guard let pdfView = pdfView else { return }
            if abs(pdfView.scaleFactor - zoomScale) > 0.001 {
                zoomScale = pdfView.scaleFactor
            }
            provider?.setZoom(pdfView.scaleFactor)
            pdfView.currentZoom = pdfView.scaleFactor
            pdfView.refreshCursor()
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

        // Own the tool cursor at the PDFView level — the reliable place for it in
        // PDFKit (see NSPDFAnnotationView). Enable window-level mouse-moved events
        // so the move-driven cursor restoration fires, and rebuild the cursor rect
        // for the current tool/color/width.
        nsView.canvasVM = canvasVM
        nsView.window?.acceptsMouseMovedEvents = true

        // Apply the numeric zoom directly. Keep autoScales off and only touch
        // scaleFactor when it actually differs, so we don't fight PDFKit or the
        // scale-changed observer.
        if nsView.autoScales {
            nsView.autoScales = false
        }
        if abs(nsView.scaleFactor - zoomScale) > 0.001 {
            nsView.scaleFactor = zoomScale
        }
        context.coordinator.provider.setZoom(nsView.scaleFactor)
        nsView.currentZoom = nsView.scaleFactor
        nsView.refreshCursor()

        if let doc = nsView.document,
           selectedPageIndex >= 0 && selectedPageIndex < doc.pageCount,
           let page = doc.page(at: selectedPageIndex),
           nsView.currentPage != page {
            nsView.go(to: page)
        }

        // After all PDFKit relayout above, re-assert the drawing cursor in case
        // it was reset to the default arrow while the pointer stayed still.
        DispatchQueue.main.async { [weak nsView] in
            nsView?.reassertCursorIfInside()
            context.coordinator.provider.reassertCursors()
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

