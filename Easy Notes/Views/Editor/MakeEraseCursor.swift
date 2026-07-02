import SwiftUI

public func createEraserCursorImage() -> NSImage {
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

public func createCircleCursorImage(color: NSColor, diameter: CGFloat) -> NSImage {
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
