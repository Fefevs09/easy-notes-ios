import AppKit
import Combine
import CoreData
import Foundation

/// Serializes canvas points into the shared `"x1,y1;x2,y2;..."` format.
func serializeCanvasPoints(_ points: [CGPoint]) -> String {
    points.map { "\(String(format: "%.1f", $0.x)),\(String(format: "%.1f", $0.y))" }
        .joined(separator: ";")
}

/// Manages unified selection, hit-testing, marquee selection, move/resize drags,
/// keyboard nudging/deletion, cursor feedback, and selection overlay rendering
/// for `Stroke`, `ShapeObject`, and `EditorImage` objects on a PDF page.
final class CanvasSelectionController {

    enum ImageCornerHandle: CaseIterable {
        case bottomLeft
        case bottomRight
        case topRight
        case topLeft

        func point(in frame: CGRect) -> CGPoint {
            switch self {
            case .bottomLeft: return CGPoint(x: frame.minX, y: frame.minY)
            case .bottomRight: return CGPoint(x: frame.maxX, y: frame.minY)
            case .topRight: return CGPoint(x: frame.maxX, y: frame.maxY)
            case .topLeft: return CGPoint(x: frame.minX, y: frame.maxY)
            }
        }

        var opposite: ImageCornerHandle {
            switch self {
            case .bottomLeft: return .topRight
            case .bottomRight: return .topLeft
            case .topRight: return .bottomLeft
            case .topLeft: return .bottomRight
            }
        }
    }

    private enum DragMode {
        case none
        case move(
            startPoint: CGPoint,
            initialStrokes: [UUID: (points: [CGPoint], rawPoints: String, wasDirty: Bool)],
            initialShapes: [UUID: (points: [CGPoint], rawPoints: String, wasDirty: Bool)],
            initialImages: [UUID: (overlayFrame: CGRect, pageFrame: CGRect, wasDirty: Bool)],
            didMove: Bool
        )
        case resizeShape(
            shapeID: UUID,
            handleIndex: Int,
            initialPoints: [CGPoint],
            rawPoints: String,
            wasDirty: Bool,
            didMove: Bool
        )
        case resizeImage(
            imageID: UUID,
            corner: ImageCornerHandle,
            anchor: CGPoint,
            initialOverlayFrame: CGRect,
            initialPageFrame: CGRect,
            wasDirty: Bool,
            didMove: Bool
        )
        case marquee(
            origin: CGPoint,
            current: CGPoint,
            baseSelection: Set<CanvasObjectRef>,
            pageIndex: Int
        )
    }

    static let minimumImageDimension: CGFloat = 24.0
    private let handleRadius: CGFloat = 6.0
    private let hitThreshold: CGFloat = 12.0

    private var dragMode: DragMode = .none
    private weak var activeDragNote: Note?
    private var activeDragPageIndex: Int = 0
    private var activeDragTransform: CGAffineTransform = .identity

    var isDragging: Bool {
        if case .none = dragMode { return false }
        return true
    }

    var isMovingOrResizing: Bool {
        switch dragMode {
        case .move, .resizeShape, .resizeImage:
            return true
        case .none, .marquee:
            return false
        }
    }

    var marqueeRect: CGRect? {
        guard case let .marquee(origin, current, _, _) = dragMode else { return nil }
        return normalizedRect(origin, current)
    }

    // MARK: - Tool Classification

    static func isPenTool(_ tool: ToolType) -> Bool {
        switch tool {
        case .fountainPen, .calligraphy, .pencil, .highlighter:
            return true
        case .eraser, .shape, .select:
            return false
        }
    }

    // MARK: - Geometry & Bounding Boxes

    static func pointToSegmentDistance(_ p: CGPoint, _ a: CGPoint, _ b: CGPoint) -> CGFloat {
        let dx = b.x - a.x
        let dy = b.y - a.y
        let lengthSquared = dx * dx + dy * dy
        guard lengthSquared > 1e-6 else {
            return hypot(p.x - a.x, p.y - a.y)
        }
        let t = max(0, min(1, ((p.x - a.x) * dx + (p.y - a.y) * dy) / lengthSquared))
        let projX = a.x + t * dx
        let projY = a.y + t * dy
        return hypot(p.x - projX, p.y - projY)
    }

    func boundingBox(for stroke: Stroke) -> CGRect? {
        let points = deserializeStrokePoints(stroke.points)
        guard let first = points.first else { return nil }
        var minX = first.x
        var maxX = first.x
        var minY = first.y
        var maxY = first.y
        for p in points.dropFirst() {
            minX = min(minX, p.x)
            maxX = max(maxX, p.x)
            minY = min(minY, p.y)
            maxY = max(maxY, p.y)
        }
        let pad = max(CGFloat(stroke.width) / 2.0, 4.0)
        return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
            .insetBy(dx: -pad, dy: -pad)
    }

    func boundingBox(for shape: ShapeObject) -> CGRect? {
        let points = deserializeStrokePoints(shape.points)
        guard points.count >= 2 else { return nil }
        let kind = ShapeKind(rawValue: shape.kind) ?? .line
        let pathBox = makeShapeCGPath(kind: kind, points: points).boundingBoxOfPath
        guard !pathBox.isNull else { return nil }
        let pad = max(CGFloat(shape.strokeWidth) / 2.0, 4.0)
        return pathBox.insetBy(dx: -pad, dy: -pad)
    }

    func boundingBox(for image: EditorImage, pageToOverlay: CGAffineTransform) -> CGRect {
        image.frame.applying(pageToOverlay)
    }

    func selectionBoundingBox(
        for selectedObjects: Set<CanvasObjectRef>,
        in note: Note,
        pageIndex: Int,
        pageToOverlay: CGAffineTransform
    ) -> CGRect? {
        guard !selectedObjects.isEmpty else { return nil }
        let page = Int16(pageIndex)

        var unionRect: CGRect?
        func include(_ rect: CGRect?) {
            guard let rect else { return }
            unionRect = unionRect?.union(rect) ?? rect
        }

        let strokes = (note.strokes as? Set<Stroke> ?? []).filter { $0.pageIndex == page }
        for stroke in strokes where selectedObjects.contains(.stroke(stroke.id)) {
            include(boundingBox(for: stroke))
        }

        let shapes = (note.shapes as? Set<ShapeObject> ?? []).filter { $0.pageIndex == page }
        for shape in shapes where selectedObjects.contains(.shape(shape.id)) {
            include(boundingBox(for: shape))
        }

        let images = (note.editorImages as? Set<EditorImage> ?? []).filter { $0.pageIndex == page }
        for image in images where selectedObjects.contains(.image(image.id)) {
            include(boundingBox(for: image, pageToOverlay: pageToOverlay))
        }

        return unionRect
    }

    // MARK: - Hit Testing

    func hitTestObject(
        at point: CGPoint,
        in note: Note,
        pageIndex: Int,
        pageToOverlay: CGAffineTransform
    ) -> CanvasObjectRef? {
        let page = Int16(pageIndex)

        // 1. Freehand strokes (drawn on top, newest first)
        let strokes = (note.strokes as? Set<Stroke> ?? [])
            .filter { $0.pageIndex == page }
            .sorted { ($0.createdAt, $0.id.uuidString) > ($1.createdAt, $1.id.uuidString) }

        for stroke in strokes {
            if isPoint(point, hittingStroke: stroke) {
                return .stroke(stroke.id)
            }
        }

        // 2. Geometric shapes (drawn below strokes, newest first)
        let shapes = (note.shapes as? Set<ShapeObject> ?? [])
            .filter { $0.pageIndex == page }
            .sorted { ($0.createdAt, $0.id.uuidString) > ($1.createdAt, $1.id.uuidString) }

        for shape in shapes {
            if isPoint(point, hittingShape: shape) {
                return .shape(shape.id)
            }
        }

        // 3. Editor images (drawn behind shapes/strokes, newest first)
        let images = (note.editorImages as? Set<EditorImage> ?? [])
            .filter { $0.pageIndex == page }
            .sorted { ($0.createdAt, $0.id.uuidString) > ($1.createdAt, $1.id.uuidString) }

        for image in images {
            let frame = boundingBox(for: image, pageToOverlay: pageToOverlay)
            if frame.contains(point) {
                return .image(image.id)
            }
        }

        return nil
    }

    func objectsIntersecting(
        _ rect: CGRect,
        in note: Note,
        pageIndex: Int,
        pageToOverlay: CGAffineTransform
    ) -> Set<CanvasObjectRef> {
        let page = Int16(pageIndex)
        var hits: Set<CanvasObjectRef> = []

        for stroke in (note.strokes as? Set<Stroke> ?? []) where stroke.pageIndex == page {
            if let box = boundingBox(for: stroke), box.intersects(rect) {
                hits.insert(.stroke(stroke.id))
            }
        }

        for shape in (note.shapes as? Set<ShapeObject> ?? []) where shape.pageIndex == page {
            if let box = boundingBox(for: shape), box.intersects(rect) {
                hits.insert(.shape(shape.id))
            }
        }

        for image in (note.editorImages as? Set<EditorImage> ?? []) where image.pageIndex == page {
            let box = boundingBox(for: image, pageToOverlay: pageToOverlay)
            if box.intersects(rect) {
                hits.insert(.image(image.id))
            }
        }

        return hits
    }

    private func isPoint(_ point: CGPoint, hittingStroke stroke: Stroke) -> Bool {
        let points = deserializeStrokePoints(stroke.points)
        guard !points.isEmpty else { return false }
        let tolerance = max(hitThreshold, CGFloat(stroke.width) / 2.0 + 4.0)
        if let box = boundingBox(for: stroke),
           !box.insetBy(dx: -tolerance, dy: -tolerance).contains(point) {
            return false
        }
        if points.count == 1 {
            return hypot(points[0].x - point.x, points[0].y - point.y) <= tolerance
        }
        for i in 0..<(points.count - 1) {
            if Self.pointToSegmentDistance(point, points[i], points[i + 1]) <= tolerance {
                return true
            }
        }
        return false
    }

    private func isPoint(_ point: CGPoint, hittingShape shape: ShapeObject) -> Bool {
        let kind = ShapeKind(rawValue: shape.kind) ?? .line
        let pts = deserializeStrokePoints(shape.points)
        guard pts.count >= 2 else { return false }

        if shapeIsClosed(kind), let fillHex = shape.fillColor, !fillHex.isEmpty {
            let path = makeShapeCGPath(kind: kind, points: pts)
            if path.contains(point) { return true }
        }

        let tolerance = max(hitThreshold, CGFloat(shape.strokeWidth) / 2.0 + 4.0)
        if kind == .line {
            return Self.pointToSegmentDistance(point, pts[0], pts[1]) <= tolerance
        }
        let outline = sampleShapePolyline(kind: kind, points: pts)
        guard !outline.isEmpty else { return false }
        if outline.count == 1 {
            return hypot(outline[0].x - point.x, outline[0].y - point.y) <= tolerance
        }
        let segmentCount = shapeIsClosed(kind) ? outline.count : (outline.count - 1)
        for i in 0..<segmentCount {
            let a = outline[i]
            let b = outline[(i + 1) % outline.count]
            if Self.pointToSegmentDistance(point, a, b) <= tolerance {
                return true
            }
        }
        return false
    }

    func shapeHandleIndex(at point: CGPoint, for shape: ShapeObject) -> Int? {
        let pts = deserializeStrokePoints(shape.points)
        for (i, p) in pts.enumerated() {
            if hypot(p.x - point.x, p.y - point.y) <= handleRadius + 3.0 {
                return i
            }
        }
        return nil
    }

    func imageCornerHandle(at point: CGPoint, frame: CGRect) -> ImageCornerHandle? {
        for corner in ImageCornerHandle.allCases {
            let hp = corner.point(in: frame)
            if hypot(hp.x - point.x, hp.y - point.y) <= handleRadius + 3.0 {
                return corner
            }
        }
        return nil
    }

    // MARK: - Pointer Interactions

    private func isSelectionActive(on pageIndex: Int, canvasVM: CanvasViewModel) -> Bool {
        guard !canvasVM.selectedObjects.isEmpty else { return false }
        if let ownerPage = canvasVM.selectedPageIndexForSelection {
            return ownerPage == pageIndex
        }
        return true
    }

    func beginSelectInteraction(
        at point: CGPoint,
        modifierFlags: NSEvent.ModifierFlags,
        note: Note,
        pageIndex: Int,
        pageToOverlay: CGAffineTransform,
        canvasVM: CanvasViewModel
    ) {
        dragMode = .none
        activeDragNote = note
        activeDragPageIndex = pageIndex
        activeDragTransform = pageToOverlay

        let isShift = modifierFlags.contains(.shift)
        let samePageSelection = isSelectionActive(on: pageIndex, canvasVM: canvasVM)
        let currentSelectionOnPage = samePageSelection ? canvasVM.selectedObjects : []

        // 1. Single-object resize handles (when not holding Shift).
        if !isShift, currentSelectionOnPage.count == 1, let single = currentSelectionOnPage.first {
            switch single {
            case .shape(let shapeID):
                if let shape = findShape(id: shapeID, in: note, pageIndex: pageIndex),
                   let handleIdx = shapeHandleIndex(at: point, for: shape) {
                    let pts = deserializeStrokePoints(shape.points)
                    dragMode = .resizeShape(
                        shapeID: shapeID,
                        handleIndex: handleIdx,
                        initialPoints: pts,
                        rawPoints: shape.points,
                        wasDirty: shape.hasChanges,
                        didMove: false
                    )
                    return
                }
            case .image(let imageID):
                if let image = findImage(id: imageID, in: note, pageIndex: pageIndex) {
                    let frame = boundingBox(for: image, pageToOverlay: pageToOverlay)
                    if let corner = imageCornerHandle(at: point, frame: frame) {
                        let anchor = corner.opposite.point(in: frame)
                        dragMode = .resizeImage(
                            imageID: imageID,
                            corner: corner,
                            anchor: anchor,
                            initialOverlayFrame: frame,
                            initialPageFrame: image.frame,
                            wasDirty: image.hasChanges,
                            didMove: false
                        )
                        return
                    }
                }
            case .stroke, .textBlock:
                break
            }
        }

        let hit = hitTestObject(at: point, in: note, pageIndex: pageIndex, pageToOverlay: pageToOverlay)

        // 2. Shift+Click toggles hit item or starts additive marquee.
        if isShift {
            if let hit {
                var updated = currentSelectionOnPage
                if updated.contains(hit) {
                    updated.remove(hit)
                } else {
                    updated.insert(hit)
                }
                canvasVM.setSelection(updated, pageIndex: pageIndex)
            } else {
                dragMode = .marquee(
                    origin: point,
                    current: point,
                    baseSelection: currentSelectionOnPage,
                    pageIndex: pageIndex
                )
            }
            return
        }

        // 3. Clicking/dragging inside active selection (or directly on a selected object) moves the group.
        let selectionBox = selectionBoundingBox(
            for: currentSelectionOnPage,
            in: note,
            pageIndex: pageIndex,
            pageToOverlay: pageToOverlay
        )
        let hitIsSelected = hit.map { currentSelectionOnPage.contains($0) } ?? false
        let insideGroupSelection = (selectionBox?.contains(point) == true)
            && (hit == nil || currentSelectionOnPage.count > 1 || hitIsSelected)

        if hitIsSelected || insideGroupSelection {
            startMoveDrag(
                at: point,
                objects: currentSelectionOnPage,
                note: note,
                pageIndex: pageIndex,
                pageToOverlay: pageToOverlay
            )
            return
        }

        // 4. Clicking an unselected object selects it and begins moving it.
        if let hit {
            let next: Set<CanvasObjectRef> = [hit]
            canvasVM.setSelection(next, pageIndex: pageIndex)
            startMoveDrag(
                at: point,
                objects: next,
                note: note,
                pageIndex: pageIndex,
                pageToOverlay: pageToOverlay
            )
            return
        }

        // 5. Clicking empty space clears selection and starts a marquee drag.
        canvasVM.clearSelection()
        dragMode = .marquee(
            origin: point,
            current: point,
            baseSelection: [],
            pageIndex: pageIndex
        )
    }

    /// When using a pen tool (`.fountainPen`, `.calligraphy`, `.pencil`, `.highlighter`)
    /// and a selection is active on `pageIndex`:
    /// - If `point` is inside the active selection's bounding box, starts moving the selection and returns `true`.
    /// - Otherwise clears the selection and returns `false` so normal drawing proceeds.
    func beginPenInteractionIfInsideSelection(
        at point: CGPoint,
        note: Note,
        pageIndex: Int,
        pageToOverlay: CGAffineTransform,
        canvasVM: CanvasViewModel
    ) -> Bool {
        dragMode = .none
        guard isSelectionActive(on: pageIndex, canvasVM: canvasVM),
              let selectionBox = selectionBoundingBox(
                for: canvasVM.selectedObjects,
                in: note,
                pageIndex: pageIndex,
                pageToOverlay: pageToOverlay
              ) else {
            if !canvasVM.selectedObjects.isEmpty {
                canvasVM.clearSelection()
            }
            return false
        }

        if selectionBox.contains(point) {
            if canvasVM.selectedPageIndexForSelection == nil {
                canvasVM.selectedPageIndexForSelection = pageIndex
            }
            activeDragNote = note
            activeDragPageIndex = pageIndex
            activeDragTransform = pageToOverlay
            startMoveDrag(
                at: point,
                objects: canvasVM.selectedObjects,
                note: note,
                pageIndex: pageIndex,
                pageToOverlay: pageToOverlay
            )
            return true
        }

        canvasVM.clearSelection()
        return false
    }

    private func startMoveDrag(
        at point: CGPoint,
        objects: Set<CanvasObjectRef>,
        note: Note,
        pageIndex: Int,
        pageToOverlay: CGAffineTransform
    ) {
        let page = Int16(pageIndex)
        var initialStrokes: [UUID: (points: [CGPoint], rawPoints: String, wasDirty: Bool)] = [:]
        var initialShapes: [UUID: (points: [CGPoint], rawPoints: String, wasDirty: Bool)] = [:]
        var initialImages: [UUID: (overlayFrame: CGRect, pageFrame: CGRect, wasDirty: Bool)] = [:]

        for stroke in (note.strokes as? Set<Stroke> ?? [])
        where stroke.pageIndex == page && objects.contains(.stroke(stroke.id)) {
            initialStrokes[stroke.id] = (
                points: deserializeStrokePoints(stroke.points),
                rawPoints: stroke.points,
                wasDirty: stroke.hasChanges
            )
        }

        for shape in (note.shapes as? Set<ShapeObject> ?? [])
        where shape.pageIndex == page && objects.contains(.shape(shape.id)) {
            initialShapes[shape.id] = (
                points: deserializeStrokePoints(shape.points),
                rawPoints: shape.points,
                wasDirty: shape.hasChanges
            )
        }

        for image in (note.editorImages as? Set<EditorImage> ?? [])
        where image.pageIndex == page && objects.contains(.image(image.id)) {
            initialImages[image.id] = (
                overlayFrame: boundingBox(for: image, pageToOverlay: pageToOverlay),
                pageFrame: image.frame,
                wasDirty: image.hasChanges
            )
        }

        dragMode = .move(
            startPoint: point,
            initialStrokes: initialStrokes,
            initialShapes: initialShapes,
            initialImages: initialImages,
            didMove: false
        )
    }

    @discardableResult
    func updateDrag(
        to point: CGPoint,
        note: Note,
        pageIndex: Int,
        pageToOverlay: CGAffineTransform,
        canvasVM: CanvasViewModel
    ) -> Bool {
        switch dragMode {
        case .none:
            return false

        case let .move(startPoint, initialStrokes, initialShapes, initialImages, didMove):
            let dx = point.x - startPoint.x
            let dy = point.y - startPoint.y
            let moved = didMove || hypot(dx, dy) > 0.1
            if moved {
                applyTranslation(
                    dx: dx,
                    dy: dy,
                    initialStrokes: initialStrokes.mapValues(\.points),
                    initialShapes: initialShapes.mapValues(\.points),
                    initialImages: initialImages.mapValues(\.overlayFrame),
                    note: note,
                    pageIndex: pageIndex,
                    pageToOverlay: pageToOverlay
                )
            }
            dragMode = .move(
                startPoint: startPoint,
                initialStrokes: initialStrokes,
                initialShapes: initialShapes,
                initialImages: initialImages,
                didMove: moved
            )
            return moved

        case let .resizeShape(shapeID, handleIndex, initialPoints, rawPoints, wasDirty, didMove):
            guard let shape = findShape(id: shapeID, in: note, pageIndex: pageIndex),
                  handleIndex < initialPoints.count else {
                return false
            }
            let moved = didMove || hypot(point.x - initialPoints[handleIndex].x,
                                         point.y - initialPoints[handleIndex].y) > 0.1
            if moved {
                var pts = initialPoints
                pts[handleIndex] = point
                shape.points = serializeCanvasPoints(pts)
            }
            dragMode = .resizeShape(
                shapeID: shapeID,
                handleIndex: handleIndex,
                initialPoints: initialPoints,
                rawPoints: rawPoints,
                wasDirty: wasDirty,
                didMove: moved
            )
            return moved

        case let .resizeImage(imageID, corner, anchor, initialOverlayFrame, initialPageFrame, wasDirty, didMove):
            guard let image = findImage(id: imageID, in: note, pageIndex: pageIndex) else {
                return false
            }
            let resizedOverlay = Self.aspectPreservingResizedFrame(
                initialFrame: initialOverlayFrame,
                anchor: anchor,
                draggedCorner: corner,
                to: point,
                minimumDimension: Self.minimumImageDimension
            )
            let moved = didMove || abs(resizedOverlay.width - initialOverlayFrame.width) > 0.1
                || abs(resizedOverlay.height - initialOverlayFrame.height) > 0.1
                || abs(resizedOverlay.origin.x - initialOverlayFrame.origin.x) > 0.1
                || abs(resizedOverlay.origin.y - initialOverlayFrame.origin.y) > 0.1
            if moved {
                applyOverlayFrame(resizedOverlay, to: image, pageToOverlay: pageToOverlay)
            }
            dragMode = .resizeImage(
                imageID: imageID,
                corner: corner,
                anchor: anchor,
                initialOverlayFrame: initialOverlayFrame,
                initialPageFrame: initialPageFrame,
                wasDirty: wasDirty,
                didMove: moved
            )
            return moved

        case let .marquee(origin, _, baseSelection, marqueePage):
            let rect = normalizedRect(origin, point)
            let hitObjects = objectsIntersecting(
                rect,
                in: note,
                pageIndex: marqueePage,
                pageToOverlay: pageToOverlay
            )
            canvasVM.setSelection(baseSelection.union(hitObjects), pageIndex: marqueePage)
            dragMode = .marquee(
                origin: origin,
                current: point,
                baseSelection: baseSelection,
                pageIndex: marqueePage
            )
            return true
        }
    }

    @discardableResult
    func endDrag(
        note: Note?,
        noteVM: NoteViewModel?,
        pageIndex: Int,
        pageToOverlay: CGAffineTransform,
        canvasVM: CanvasViewModel?
    ) -> Bool {
        defer {
            dragMode = .none
            activeDragNote = nil
        }
        switch dragMode {
        case .none:
            return false

        case let .move(_, _, _, _, didMove),
             let .resizeShape(_, _, _, _, _, didMove),
             let .resizeImage(_, _, _, _, _, _, didMove):
            if didMove, let note {
                persistChanges(for: note, noteVM: noteVM)
            }
            return true

        case let .marquee(origin, current, baseSelection, marqueePage):
            if let note, let canvasVM {
                let rect = normalizedRect(origin, current)
                if rect.width < 3.0 && rect.height < 3.0 {
                    canvasVM.setSelection(baseSelection, pageIndex: baseSelection.isEmpty ? nil : marqueePage)
                } else {
                    let hits = objectsIntersecting(
                        rect,
                        in: note,
                        pageIndex: marqueePage,
                        pageToOverlay: pageToOverlay
                    )
                    canvasVM.setSelection(baseSelection.union(hits), pageIndex: marqueePage)
                }
            }
            return true
        }
    }

    func cancelActiveDrag(note: Note? = nil, pageIndex: Int? = nil) {
        let targetNote = note ?? activeDragNote
        let targetPage = pageIndex ?? activeDragPageIndex

        switch dragMode {
        case .none, .marquee:
            break

        case let .move(_, initialStrokes, initialShapes, initialImages, didMove):
            if didMove, let targetNote {
                let page = Int16(targetPage)
                let moc = targetNote.managedObjectContext
                var restoredObjectIDs: Set<NSManagedObjectID> = []

                let strokes = (targetNote.strokes as? Set<Stroke> ?? []).filter {
                    $0.pageIndex == page && initialStrokes[$0.id] != nil
                }
                let shapes = (targetNote.shapes as? Set<ShapeObject> ?? []).filter {
                    $0.pageIndex == page && initialShapes[$0.id] != nil
                }
                let images = (targetNote.editorImages as? Set<EditorImage> ?? []).filter {
                    $0.pageIndex == page && initialImages[$0.id] != nil
                }

                strokes.forEach { restoredObjectIDs.insert($0.objectID) }
                shapes.forEach { restoredObjectIDs.insert($0.objectID) }
                images.forEach { restoredObjectIDs.insert($0.objectID) }

                let allCleanBeforeDrag = strokes.allSatisfy { !(initialStrokes[$0.id]?.wasDirty ?? true) && !$0.isInserted }
                    && shapes.allSatisfy { !(initialShapes[$0.id]?.wasDirty ?? true) && !$0.isInserted }
                    && images.allSatisfy { !(initialImages[$0.id]?.wasDirty ?? true) && !$0.isInserted }

                if let moc, allCleanBeforeDrag, canSafelyRollback(moc, restoringOnly: restoredObjectIDs) {
                    moc.rollback()
                } else {
                    for stroke in strokes {
                        if let snapshot = initialStrokes[stroke.id] {
                            if snapshot.wasDirty || stroke.isInserted {
                                stroke.points = snapshot.rawPoints
                            } else {
                                moc?.refresh(stroke, mergeChanges: false)
                            }
                        }
                    }
                    for shape in shapes {
                        if let snapshot = initialShapes[shape.id] {
                            if snapshot.wasDirty || shape.isInserted {
                                shape.points = snapshot.rawPoints
                            } else {
                                moc?.refresh(shape, mergeChanges: false)
                            }
                        }
                    }
                    for image in images {
                        if let snapshot = initialImages[image.id] {
                            if snapshot.wasDirty || image.isInserted {
                                image.x = snapshot.pageFrame.origin.x
                                image.y = snapshot.pageFrame.origin.y
                                image.width = snapshot.pageFrame.width
                                image.height = snapshot.pageFrame.height
                            } else {
                                moc?.refresh(image, mergeChanges: false)
                            }
                        }
                    }
                }
            }

        case let .resizeShape(shapeID, _, _, rawPoints, wasDirty, didMove):
            if didMove, let targetNote,
               let shape = findShape(id: shapeID, in: targetNote, pageIndex: targetPage) {
                let moc = targetNote.managedObjectContext
                if let moc, !wasDirty, !shape.isInserted,
                   canSafelyRollback(moc, restoringOnly: [shape.objectID]) {
                    moc.rollback()
                } else if wasDirty || shape.isInserted {
                    shape.points = rawPoints
                } else {
                    moc?.refresh(shape, mergeChanges: false)
                }
            }

        case let .resizeImage(imageID, _, _, _, initialPageFrame, wasDirty, didMove):
            if didMove, let targetNote,
               let image = findImage(id: imageID, in: targetNote, pageIndex: targetPage) {
                let moc = targetNote.managedObjectContext
                if let moc, !wasDirty, !image.isInserted,
                   canSafelyRollback(moc, restoringOnly: [image.objectID]) {
                    moc.rollback()
                } else if wasDirty || image.isInserted {
                    image.x = initialPageFrame.origin.x
                    image.y = initialPageFrame.origin.y
                    image.width = initialPageFrame.width
                    image.height = initialPageFrame.height
                } else {
                    moc?.refresh(image, mergeChanges: false)
                }
            }
        }

        dragMode = .none
        activeDragNote = nil
    }

    private func canSafelyRollback(_ moc: NSManagedObjectContext, restoringOnly objectIDs: Set<NSManagedObjectID>) -> Bool {
        moc.processPendingChanges()
        guard moc.insertedObjects.isEmpty, moc.deletedObjects.isEmpty else {
            return false
        }
        let dirtyIDs = Set(moc.updatedObjects.map(\.objectID))
        return dirtyIDs.isSubset(of: objectIDs)
    }

    // MARK: - Keyboard Actions

    @discardableResult
    func handleKeyDown(
        _ event: NSEvent,
        note: Note?,
        noteVM: NoteViewModel?,
        pageIndex: Int,
        pageToOverlay: CGAffineTransform,
        canvasVM: CanvasViewModel?,
        firstResponder: NSResponder? = nil
    ) -> Bool {
        guard event.modifierFlags.intersection([.command, .option, .control]).isEmpty else {
            return false
        }
        if firstResponder is NSText {
            return false
        }
        guard let canvasVM, canvasVM.isDrawingMode,
              (!canvasVM.selectedObjects.isEmpty || isDragging) else {
            return false
        }

        // Escape cancels any active drag (restoring initial coordinates) and clears selection.
        if event.keyCode == 53 {
            cancelActiveDrag(note: note, pageIndex: pageIndex)
            canvasVM.clearSelection()
            return true
        }

        guard let note, isSelectionActive(on: pageIndex, canvasVM: canvasVM) else {
            return false
        }

        // Delete / Backspace or Forward Delete removes selected objects.
        if event.keyCode == 51 || event.keyCode == 117 {
            deleteSelection(note: note, noteVM: noteVM, pageIndex: pageIndex, canvasVM: canvasVM)
            return true
        }

        // Arrow keys nudge selection (1 pt, or 10 pt with Shift).
        let step: CGFloat = event.modifierFlags.contains(.shift) ? 10.0 : 1.0
        switch event.keyCode {
        case 123: // Left
            nudgeSelection(dx: -step, dy: 0, note: note, noteVM: noteVM, pageIndex: pageIndex, pageToOverlay: pageToOverlay, canvasVM: canvasVM)
            return true
        case 124: // Right
            nudgeSelection(dx: step, dy: 0, note: note, noteVM: noteVM, pageIndex: pageIndex, pageToOverlay: pageToOverlay, canvasVM: canvasVM)
            return true
        case 125: // Down (AppKit unflipped: -Y)
            nudgeSelection(dx: 0, dy: -step, note: note, noteVM: noteVM, pageIndex: pageIndex, pageToOverlay: pageToOverlay, canvasVM: canvasVM)
            return true
        case 126: // Up (AppKit unflipped: +Y)
            nudgeSelection(dx: 0, dy: step, note: note, noteVM: noteVM, pageIndex: pageIndex, pageToOverlay: pageToOverlay, canvasVM: canvasVM)
            return true
        default:
            return false
        }
    }

    func nudgeSelection(
        dx: CGFloat,
        dy: CGFloat,
        note: Note,
        noteVM: NoteViewModel?,
        pageIndex: Int,
        pageToOverlay: CGAffineTransform,
        canvasVM: CanvasViewModel
    ) {
        let objects = canvasVM.selectedObjects
        guard !objects.isEmpty else { return }

        let page = Int16(pageIndex)
        var initialStrokes: [UUID: [CGPoint]] = [:]
        var initialShapes: [UUID: [CGPoint]] = [:]
        var initialImages: [UUID: CGRect] = [:]

        for stroke in (note.strokes as? Set<Stroke> ?? [])
        where stroke.pageIndex == page && objects.contains(.stroke(stroke.id)) {
            initialStrokes[stroke.id] = deserializeStrokePoints(stroke.points)
        }
        for shape in (note.shapes as? Set<ShapeObject> ?? [])
        where shape.pageIndex == page && objects.contains(.shape(shape.id)) {
            initialShapes[shape.id] = deserializeStrokePoints(shape.points)
        }
        for image in (note.editorImages as? Set<EditorImage> ?? [])
        where image.pageIndex == page && objects.contains(.image(image.id)) {
            initialImages[image.id] = boundingBox(for: image, pageToOverlay: pageToOverlay)
        }

        guard !initialStrokes.isEmpty || !initialShapes.isEmpty || !initialImages.isEmpty else {
            return
        }

        applyTranslation(
            dx: dx,
            dy: dy,
            initialStrokes: initialStrokes,
            initialShapes: initialShapes,
            initialImages: initialImages,
            note: note,
            pageIndex: pageIndex,
            pageToOverlay: pageToOverlay
        )
        persistChanges(for: note, noteVM: noteVM)
    }

    func deleteSelection(
        note: Note,
        noteVM: NoteViewModel?,
        pageIndex: Int,
        canvasVM: CanvasViewModel
    ) {
        guard let moc = note.managedObjectContext else { return }
        let selected = canvasVM.selectedObjects
        guard !selected.isEmpty else { return }
        let page = Int16(pageIndex)

        var deletedAny = false
        for stroke in (note.strokes as? Set<Stroke> ?? [])
        where stroke.pageIndex == page && selected.contains(.stroke(stroke.id)) {
            moc.delete(stroke)
            deletedAny = true
        }
        for shape in (note.shapes as? Set<ShapeObject> ?? [])
        where shape.pageIndex == page && selected.contains(.shape(shape.id)) {
            moc.delete(shape)
            deletedAny = true
        }
        for image in (note.editorImages as? Set<EditorImage> ?? [])
        where image.pageIndex == page && selected.contains(.image(image.id)) {
            moc.delete(image)
            deletedAny = true
        }

        canvasVM.clearSelection()
        dragMode = .none

        if deletedAny {
            persistChanges(for: note, noteVM: noteVM)
        }
    }

    // MARK: - Coordinate & Persistence Helpers

    static func aspectPreservingResizedFrame(
        initialFrame: CGRect,
        anchor: CGPoint,
        draggedCorner: ImageCornerHandle,
        to point: CGPoint,
        minimumDimension: CGFloat
    ) -> CGRect {
        let baseWidth = max(1, initialFrame.width)
        let baseHeight = max(1, initialFrame.height)

        let sx: CGFloat = (draggedCorner == .bottomRight || draggedCorner == .topRight) ? 1.0 : -1.0
        let sy: CGFloat = (draggedCorner == .topLeft || draggedCorner == .topRight) ? 1.0 : -1.0

        let rawWidth = max(0, (point.x - anchor.x) * sx)
        let rawHeight = max(0, (point.y - anchor.y) * sy)

        let minScale = max(minimumDimension / baseWidth, minimumDimension / baseHeight)
        let targetScale = max(rawWidth / baseWidth, rawHeight / baseHeight, minScale)

        let newWidth = baseWidth * targetScale
        let newHeight = baseHeight * targetScale
        let originX = sx > 0 ? anchor.x : anchor.x - newWidth
        let originY = sy > 0 ? anchor.y : anchor.y - newHeight
        return CGRect(x: originX, y: originY, width: newWidth, height: newHeight)
    }

    private func applyTranslation(
        dx: CGFloat,
        dy: CGFloat,
        initialStrokes: [UUID: [CGPoint]],
        initialShapes: [UUID: [CGPoint]],
        initialImages: [UUID: CGRect],
        note: Note,
        pageIndex: Int,
        pageToOverlay: CGAffineTransform
    ) {
        let page = Int16(pageIndex)

        if !initialStrokes.isEmpty {
            for stroke in (note.strokes as? Set<Stroke> ?? []) where stroke.pageIndex == page {
                if let pts = initialStrokes[stroke.id] {
                    stroke.points = serializeCanvasPoints(pts.map { CGPoint(x: $0.x + dx, y: $0.y + dy) })
                }
            }
        }

        if !initialShapes.isEmpty {
            for shape in (note.shapes as? Set<ShapeObject> ?? []) where shape.pageIndex == page {
                if let pts = initialShapes[shape.id] {
                    shape.points = serializeCanvasPoints(pts.map { CGPoint(x: $0.x + dx, y: $0.y + dy) })
                }
            }
        }

        if !initialImages.isEmpty {
            for image in (note.editorImages as? Set<EditorImage> ?? []) where image.pageIndex == page {
                if let initialOverlay = initialImages[image.id] {
                    let translated = initialOverlay.offsetBy(dx: dx, dy: dy)
                    applyOverlayFrame(translated, to: image, pageToOverlay: pageToOverlay)
                }
            }
        }
    }

    private func applyOverlayFrame(
        _ overlayFrame: CGRect,
        to image: EditorImage,
        pageToOverlay: CGAffineTransform
    ) {
        let determinant = pageToOverlay.a * pageToOverlay.d - pageToOverlay.b * pageToOverlay.c
        let overlayToPage = abs(determinant) > 1e-6 ? pageToOverlay.inverted() : .identity
        let pageFrame = overlayFrame.applying(overlayToPage)
        image.x = Double(pageFrame.origin.x)
        image.y = Double(pageFrame.origin.y)
        image.width = Double(pageFrame.width)
        image.height = Double(pageFrame.height)
    }

    private func persistChanges(for note: Note, noteVM: NoteViewModel?) {
        guard let moc = note.managedObjectContext else { return }
        note.updatedAt = max(Date(), note.updatedAt.addingTimeInterval(0.001))
        do {
            try moc.save()
            noteVM?.coverCache.invalidate(noteID: note.id)
            noteVM?.loadNotes()
            noteVM?.objectWillChange.send()
        } catch {
            Swift.print("Failed to persist selection changes: \(error)")
        }
    }

    private func findShape(id: UUID, in note: Note, pageIndex: Int) -> ShapeObject? {
        (note.shapes as? Set<ShapeObject> ?? []).first {
            $0.pageIndex == Int16(pageIndex) && $0.id == id
        }
    }

    private func findImage(id: UUID, in note: Note, pageIndex: Int) -> EditorImage? {
        (note.editorImages as? Set<EditorImage> ?? []).first {
            $0.pageIndex == Int16(pageIndex) && $0.id == id
        }
    }

    // MARK: - Cursor Resolution

    func cursor(
        at point: CGPoint,
        note: Note?,
        pageIndex: Int,
        pageToOverlay: CGAffineTransform,
        canvasVM: CanvasViewModel?
    ) -> NSCursor? {
        guard let canvasVM, canvasVM.isDrawingMode else { return nil }

        if isMovingOrResizing {
            return .closedHand
        }
        if case .marquee = dragMode {
            return .crosshair
        }

        let supportsMoveCursor = canvasVM.activeTool == .select || Self.isPenTool(canvasVM.activeTool)
        guard supportsMoveCursor,
              let note,
              isSelectionActive(on: pageIndex, canvasVM: canvasVM) else {
            return nil
        }

        if canvasVM.activeTool == .select,
           canvasVM.selectedObjects.count == 1,
           let single = canvasVM.selectedObjects.first {
            switch single {
            case .shape(let shapeID):
                if let shape = findShape(id: shapeID, in: note, pageIndex: pageIndex),
                   shapeHandleIndex(at: point, for: shape) != nil {
                    return .crosshair
                }
            case .image(let imageID):
                if let image = findImage(id: imageID, in: note, pageIndex: pageIndex),
                   imageCornerHandle(at: point, frame: boundingBox(for: image, pageToOverlay: pageToOverlay)) != nil {
                    return .crosshair
                }
            case .stroke, .textBlock:
                break
            }
        }

        if let box = selectionBoundingBox(
            for: canvasVM.selectedObjects,
            in: note,
            pageIndex: pageIndex,
            pageToOverlay: pageToOverlay
        ), box.contains(point) {
            return .openHand
        }

        return nil
    }

    // MARK: - Overlay Rendering

    func drawOverlay(
        in cg: CGContext,
        note: Note,
        pageIndex: Int,
        pageToOverlay: CGAffineTransform,
        canvasVM: CanvasViewModel
    ) {
        let showResizeHandles = (canvasVM.activeTool == .select)

        if isSelectionActive(on: pageIndex, canvasVM: canvasVM) {
            if canvasVM.selectedObjects.count == 1, let single = canvasVM.selectedObjects.first {
                switch single {
                case .shape(let shapeID):
                    if let shape = findShape(id: shapeID, in: note, pageIndex: pageIndex) {
                        let pts = deserializeStrokePoints(shape.points)
                        drawShapeSelection(
                            kind: ShapeKind(rawValue: shape.kind) ?? .line,
                            points: pts,
                            showHandles: showResizeHandles,
                            in: cg
                        )
                    }
                case .image(let imageID):
                    if let image = findImage(id: imageID, in: note, pageIndex: pageIndex) {
                        let frame = boundingBox(for: image, pageToOverlay: pageToOverlay)
                        drawImageSelection(frame: frame, showHandles: showResizeHandles, in: cg)
                    }
                case .stroke(let strokeID):
                    if let stroke = (note.strokes as? Set<Stroke> ?? [])
                        .first(where: { $0.pageIndex == Int16(pageIndex) && $0.id == strokeID }),
                       let box = boundingBox(for: stroke) {
                        drawBoundingSelection(box, showCornerMarkers: showResizeHandles, in: cg)
                    }
                case .textBlock:
                    break
                }
            } else if let groupBox = selectionBoundingBox(
                for: canvasVM.selectedObjects,
                in: note,
                pageIndex: pageIndex,
                pageToOverlay: pageToOverlay
            ) {
                drawIndividualSelectionHighlights(
                    for: canvasVM.selectedObjects,
                    in: note,
                    pageIndex: pageIndex,
                    pageToOverlay: pageToOverlay,
                    cg: cg
                )
                drawBoundingSelection(groupBox, showCornerMarkers: showResizeHandles, in: cg)
            }
        }

        if case let .marquee(origin, current, _, marqueePage) = dragMode, marqueePage == pageIndex {
            let rect = normalizedRect(origin, current)
            drawMarquee(rect, in: cg)
        }
    }

    private func drawShapeSelection(kind: ShapeKind, points: [CGPoint], showHandles: Bool, in cg: CGContext) {
        guard points.count >= 2 else { return }
        cg.saveGState()
        cg.addPath(makeShapeCGPath(kind: kind, points: points))
        cg.setLineWidth(1.0)
        cg.setLineDash(phase: 0, lengths: [4, 3])
        cg.setStrokeColor(NSColor.controlAccentColor.cgColor)
        cg.strokePath()
        cg.setLineDash(phase: 0, lengths: [])

        if showHandles {
            for p in points {
                drawHandle(at: p, in: cg)
            }
        }
        cg.restoreGState()
    }

    private func drawImageSelection(frame: CGRect, showHandles: Bool, in cg: CGContext) {
        cg.saveGState()
        cg.setLineWidth(1.5)
        cg.setLineDash(phase: 0, lengths: [5, 3])
        cg.setStrokeColor(NSColor.controlAccentColor.cgColor)
        cg.stroke(frame)
        cg.setLineDash(phase: 0, lengths: [])

        if showHandles {
            for corner in ImageCornerHandle.allCases {
                drawHandle(at: corner.point(in: frame), in: cg)
            }
        }
        cg.restoreGState()
    }

    private func drawIndividualSelectionHighlights(
        for selectedObjects: Set<CanvasObjectRef>,
        in note: Note,
        pageIndex: Int,
        pageToOverlay: CGAffineTransform,
        cg: CGContext
    ) {
        let page = Int16(pageIndex)
        cg.saveGState()
        cg.setLineWidth(1.0)
        cg.setStrokeColor(NSColor.controlAccentColor.withAlphaComponent(0.35).cgColor)

        for stroke in (note.strokes as? Set<Stroke> ?? [])
        where stroke.pageIndex == page && selectedObjects.contains(.stroke(stroke.id)) {
            if let box = boundingBox(for: stroke) {
                cg.stroke(box)
            }
        }
        for shape in (note.shapes as? Set<ShapeObject> ?? [])
        where shape.pageIndex == page && selectedObjects.contains(.shape(shape.id)) {
            if let box = boundingBox(for: shape) {
                cg.stroke(box)
            }
        }
        for image in (note.editorImages as? Set<EditorImage> ?? [])
        where image.pageIndex == page && selectedObjects.contains(.image(image.id)) {
            cg.stroke(boundingBox(for: image, pageToOverlay: pageToOverlay))
        }
        cg.restoreGState()
    }

    private func drawBoundingSelection(_ rect: CGRect, showCornerMarkers: Bool, in cg: CGContext) {
        cg.saveGState()
        cg.setLineWidth(1.25)
        cg.setLineDash(phase: 0, lengths: [5, 3])
        cg.setStrokeColor(NSColor.controlAccentColor.cgColor)
        cg.stroke(rect)
        cg.setLineDash(phase: 0, lengths: [])

        if showCornerMarkers {
            for corner in ImageCornerHandle.allCases {
                let p = corner.point(in: rect)
                let marker = CGRect(x: p.x - 3.5, y: p.y - 3.5, width: 7.0, height: 7.0)
                cg.setFillColor(NSColor.controlAccentColor.cgColor)
                cg.fill(marker)
            }
        }
        cg.restoreGState()
    }

    private func drawHandle(at point: CGPoint, in cg: CGContext) {
        let r = CGRect(
            x: point.x - handleRadius,
            y: point.y - handleRadius,
            width: handleRadius * 2,
            height: handleRadius * 2
        )
        cg.setFillColor(NSColor.white.cgColor)
        cg.fill(r)
        cg.setStrokeColor(NSColor.controlAccentColor.cgColor)
        cg.setLineWidth(1.25)
        cg.stroke(r)
    }

    private func drawMarquee(_ rect: CGRect, in cg: CGContext) {
        cg.saveGState()
        cg.setFillColor(NSColor.controlAccentColor.withAlphaComponent(0.10).cgColor)
        cg.fill(rect)
        cg.setLineWidth(1.0)
        cg.setLineDash(phase: 0, lengths: [4, 3])
        cg.setStrokeColor(NSColor.controlAccentColor.cgColor)
        cg.stroke(rect)
        cg.restoreGState()
    }
}
