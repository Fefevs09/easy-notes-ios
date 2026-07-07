import AppKit

/// Modern drawing cursors, rendered resolution-independently.
///
/// Each cursor is built with `NSImage(size:flipped:drawingHandler:)` so AppKit
/// re-rasterizes it at the display's backing scale (crisp on Retina), unlike
/// `lockFocus()` which bakes a 1x bitmap. Sizes passed in are already in screen
/// pixels (page points × current zoom), so the on-screen footprint matches the
/// stroke that will actually be painted.
extension NSImage {

    /// Hollow brush ring in the stroke color with a white casing (contrast on
    /// dark pages), a faint dark hairline (contrast on white paper), a
    /// translucent color fill, and a precise center dot at the draw point.
    /// `diameter` is the brush footprint in screen pixels.
    static func createBrushCursorImage(color: NSColor, diameter: CGFloat) -> NSImage {
        let d = min(max(diameter, 14.0), 400.0)   // floor for visibility, cap for sanity
        let pad: CGFloat = 6.0
        let side = d + pad * 2
        let r = d / 2

        return NSImage(size: NSSize(width: side, height: side), flipped: false) { rect in
            let c = NSPoint(x: rect.midX, y: rect.midY)

            func oval(_ radius: CGFloat) -> NSBezierPath {
                NSBezierPath(ovalIn: NSRect(x: c.x - radius, y: c.y - radius,
                                            width: radius * 2, height: radius * 2))
            }

            // Translucent color fill (lets the paper/PDF show through).
            color.withAlphaComponent(0.14).setFill()
            oval(r).fill()

            // Outer dark hairline — reads against light backgrounds.
            NSColor.black.withAlphaComponent(0.13).setStroke()
            let hairline = oval(r + 2)
            hairline.lineWidth = 1
            hairline.stroke()

            // White casing — reads against dark backgrounds.
            NSColor.white.withAlphaComponent(0.92).setStroke()
            let casing = oval(r + 1)
            casing.lineWidth = 1.5
            casing.stroke()

            // Colored ring at the true brush radius.
            color.setStroke()
            let ring = oval(r)
            ring.lineWidth = 2
            ring.stroke()

            // Center precision dot.
            drawCenterDot(at: c, fill: color)
            return true
        }
    }

    /// Soft rounded-square eraser outline (distinct from the round pen), sized
    /// to the erase footprint in screen pixels.
    static func createEraserCursorImage(footprint: CGFloat = 36.0) -> NSImage {
        let d = min(max(footprint, 18.0), 400.0)
        let pad: CGFloat = 6.0
        let side = d + pad * 2
        let corner = d * 0.28
        let neutral = NSColor.secondaryLabelColor

        return NSImage(size: NSSize(width: side, height: side), flipped: false) { rect in
            let c = NSPoint(x: rect.midX, y: rect.midY)
            let r = d / 2

            func square(_ inset: CGFloat, radius: CGFloat) -> NSBezierPath {
                NSBezierPath(roundedRect: NSRect(x: c.x - r + inset, y: c.y - r + inset,
                                                 width: (r - inset) * 2, height: (r - inset) * 2),
                             xRadius: radius, yRadius: radius)
            }

            // Faint fill.
            neutral.withAlphaComponent(0.08).setFill()
            square(0, radius: corner).fill()

            // Dark hairline.
            NSColor.black.withAlphaComponent(0.13).setStroke()
            let outer = square(-2, radius: corner + 2)
            outer.lineWidth = 1
            outer.stroke()

            // White casing.
            NSColor.white.withAlphaComponent(0.92).setStroke()
            let casing = square(-1, radius: corner + 1)
            casing.lineWidth = 1.5
            casing.stroke()

            // Neutral eraser outline.
            neutral.withAlphaComponent(0.85).setStroke()
            let ring = square(0, radius: corner)
            ring.lineWidth = 1.6
            ring.stroke()

            drawCenterDot(at: c, fill: neutral)
            return true
        }
    }

    /// Precision crosshair for shape tools: thin arms with a center gap and a
    /// dot, white-cased for contrast. Fixed size (not zoom-scaled) since it's a
    /// precision indicator, not a footprint.
    static func createShapeCrosshairImage() -> NSImage {
        let side: CGFloat = 34.0
        let arm: CGFloat = 9.0
        let gap: CGFloat = 5.0

        return NSImage(size: NSSize(width: side, height: side), flipped: false) { rect in
            let c = NSPoint(x: rect.midX, y: rect.midY)

            func arms(width: CGFloat, color: NSColor) {
                let path = NSBezierPath()
                path.lineCapStyle = .round
                path.lineWidth = width
                path.move(to: NSPoint(x: c.x, y: c.y + gap)); path.line(to: NSPoint(x: c.x, y: c.y + gap + arm))
                path.move(to: NSPoint(x: c.x, y: c.y - gap)); path.line(to: NSPoint(x: c.x, y: c.y - gap - arm))
                path.move(to: NSPoint(x: c.x + gap, y: c.y)); path.line(to: NSPoint(x: c.x + gap + arm, y: c.y))
                path.move(to: NSPoint(x: c.x - gap, y: c.y)); path.line(to: NSPoint(x: c.x - gap - arm, y: c.y))
                color.setStroke()
                path.stroke()
            }

            arms(width: 3.5, color: NSColor.white.withAlphaComponent(0.92)) // casing
            arms(width: 1.6, color: NSColor.labelColor.withAlphaComponent(0.85))
            drawCenterDot(at: c, fill: NSColor.labelColor)
            return true
        }
    }

    private static func drawCenterDot(at c: NSPoint, fill: NSColor) {
        let dot = NSBezierPath(ovalIn: NSRect(x: c.x - 2.5, y: c.y - 2.5, width: 5, height: 5))
        fill.setFill()
        dot.fill()
        NSColor.white.withAlphaComponent(0.9).setStroke()
        dot.lineWidth = 1
        dot.stroke()
    }
}
