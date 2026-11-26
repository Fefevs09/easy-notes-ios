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

    private struct PressurePoint {
        let position: CGPoint
        let radius: CGFloat

        func offset(by normal: CGVector) -> CGPoint {
            CGPoint(x: position.x + normal.dx * radius, y: position.y + normal.dy * radius)
        }
    }

    private static func pressureOutline(points: [CGPoint], pressure: [CGFloat], width: CGFloat) -> CGPath {
        let path = CGMutablePath()
        var samples: [PressurePoint] = []
        samples.reserveCapacity(points.count)
        for (point, sample) in zip(points, pressure) {
            let node = PressurePoint(position: point, radius: width * (0.25 + 0.75 * sample) / 2)
            if samples.last?.position == point {
                samples[samples.count - 1] = node
            } else {
                samples.append(node)
            }
        }

        guard samples.count > 1 else {
            if let sample = samples.first {
                let r = sample.radius
                path.addEllipse(in: CGRect(x: sample.position.x - r, y: sample.position.y - r, width: 2 * r, height: 2 * r))
            }
            return path
        }

        let normals = zip(samples, samples.dropFirst()).map { first, second in
            let dx = second.position.x - first.position.x
            let dy = second.position.y - first.position.y
            let distance = hypot(dx, dy)
            return CGVector(dx: -dy / distance, dy: dx / distance)
        }

        // Fill one continuous outline per run. Splitting at close reversals
        // avoids huge miters, and a single fill applies ink opacity only once.
        var runStart = 0
        for index in 1..<normals.count {
            if dot(normals[index - 1], normals[index]) < -0.7 {
                addRun(from: runStart, through: index, samples: samples, normals: normals, to: path)
                runStart = index
            }
        }
        addRun(from: runStart, through: samples.count - 1, samples: samples, normals: normals, to: path)
        return path
    }

    private static func addRun(
        from start: Int, through end: Int,
        samples: [PressurePoint], normals: [CGVector], to path: CGMutablePath
    ) {
        let startNormal = normals[start]
        let endNormal = normals[end - 1]
        path.move(to: samples[start].offset(by: startNormal))
        for index in (start + 1)..<end {
            path.addLine(to: samples[index].offset(by: join(normals[index - 1], normals[index])))
        }
        path.addLine(to: samples[end].offset(by: endNormal))
        addCap(at: samples[end], from: endNormal, to: path)

        for index in ((start + 1)..<end).reversed() {
            let normal = join(normals[index - 1], normals[index])
            path.addLine(to: samples[index].offset(by: CGVector(dx: -normal.dx, dy: -normal.dy)))
        }
        let oppositeStart = CGVector(dx: -startNormal.dx, dy: -startNormal.dy)
        path.addLine(to: samples[start].offset(by: oppositeStart))
        addCap(at: samples[start], from: oppositeStart, to: path)
        path.closeSubpath()
    }

    private static func addCap(at sample: PressurePoint, from normal: CGVector, to path: CGMutablePath) {
        let angle = atan2(normal.dy, normal.dx)
        path.addArc(center: sample.position, radius: sample.radius, startAngle: angle, endAngle: angle - .pi, clockwise: true)
    }

    private static func join(_ incoming: CGVector, _ outgoing: CGVector) -> CGVector {
        let scale = 1 / (1 + dot(incoming, outgoing))
        return CGVector(dx: (incoming.dx + outgoing.dx) * scale, dy: (incoming.dy + outgoing.dy) * scale)
    }

    private static func dot(_ first: CGVector, _ second: CGVector) -> CGFloat {
        first.dx * second.dx + first.dy * second.dy
    }
}
