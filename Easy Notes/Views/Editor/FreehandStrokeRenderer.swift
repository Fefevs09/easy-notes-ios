import AppKit

enum FreehandStrokeRenderer {
    static func draw(_ stroke: Stroke, into context: CGContext) {
        let points = deserializeStrokePoints(stroke.points)
        draw(
            points: points,
            pressure: StrokePressure.samples(in: stroke.points, pointCount: points.count),
            width: CGFloat(stroke.width),
            color: NSColor(hex: stroke.color) ?? .black,
            into: context
        )
    }

    static func draw(
        points: [CGPoint], pressure: [CGFloat]?, width: CGFloat, color: NSColor, into context: CGContext
    ) {
        guard let first = points.first else { return }
        context.saveGState()
        defer { context.restoreGState() }

        context.beginPath()
        if let pressure, pressure.count == points.count {
            context.setFillColor(color.cgColor)
            context.addPath(pressureOutline(points: points, pressure: pressure, width: width))
            context.fillPath()
        } else {
            context.setLineWidth(width)
            context.setLineCap(.round)
            context.setLineJoin(.round)
            context.setStrokeColor(color.cgColor)
            context.move(to: first)
            for point in points.dropFirst() {
                context.addLine(to: point)
            }
            context.strokePath()
        }
    }

    private static func pressureOutline(points: [CGPoint], pressure: [CGFloat], width: CGFloat) -> CGPath {
        let path = CGMutablePath()
        let radii = pressure.map { width * (0.25 + 0.75 * $0) / 2 }

        // Fill round joins and tapered connectors together so overlapping
        // segments apply the ink opacity only once.
        for (index, point) in points.enumerated() {
            let radius = radii[index]
            path.move(to: CGPoint(x: point.x + radius, y: point.y))
            path.addArc(center: point, radius: radius, startAngle: 0, endAngle: 2 * .pi, clockwise: false)
            path.closeSubpath()

            guard index > 0 else { continue }
            let previous = points[index - 1]
            let dx = point.x - previous.x
            let dy = point.y - previous.y
            let length = hypot(dx, dy)
            guard length > 0 else { continue }
            let normal = CGPoint(x: -dy / length, y: dx / length)
            let previousRadius = radii[index - 1]

            path.move(to: CGPoint(x: previous.x - normal.x * previousRadius, y: previous.y - normal.y * previousRadius))
            path.addLine(to: CGPoint(x: point.x - normal.x * radius, y: point.y - normal.y * radius))
            path.addLine(to: CGPoint(x: point.x + normal.x * radius, y: point.y + normal.y * radius))
            path.addLine(to: CGPoint(x: previous.x + normal.x * previousRadius, y: previous.y + normal.y * previousRadius))
            path.closeSubpath()
        }
        return path
    }
}
