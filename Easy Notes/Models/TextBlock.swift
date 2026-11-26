import AppKit
import CoreData
import CoreText
import Foundation

@objc(TextBlock)
public class TextBlock: NSManagedObject {
    @NSManaged public var id: UUID
    @NSManaged public var text: String
    @NSManaged public var x: Double
    @NSManaged public var y: Double
    @NSManaged public var width: Double
    @NSManaged public var height: Double
    @NSManaged public var fontSize: Float
    @NSManaged public var colorHex: String
    @NSManaged public var pageIndex: Int16
    @NSManaged public var createdAt: Date
    @NSManaged public var updatedAt: Date
    @NSManaged public var note: Note?

    public var frame: CGRect {
        get { CGRect(x: x, y: y, width: width, height: height) }
        set {
            x = newValue.origin.x
            y = newValue.origin.y
            width = newValue.size.width
            height = newValue.size.height
        }
    }
}

public extension Note {
    var textBlocksArray: [TextBlock] {
        let set = textBlocks as? Set<TextBlock> ?? []
        return set.sorted { ($0.createdAt, $0.id.uuidString) < ($1.createdAt, $1.id.uuidString) }
    }
}

public enum TextBlockLayout {
    public static let defaultSize = CGSize(width: 220, height: 72)
    public static let defaultFontSize: CGFloat = 15.0
    public static let fontSizeRange: ClosedRange<CGFloat> = 12...36
    public static let defaultColorHex = "#1C1C1E"
    public static let cardCornerRadius: CGFloat = 6.0
    public static let horizontalPadding: CGFloat = 8.0
    public static let verticalPadding: CGFloat = 6.0
    public static let pageMargin: CGFloat = 8.0

    /// Computes an initial `TextBlock` rect anchored near `pagePoint` (top-left)
    /// and clamped to fit completely within `mediaBox` (bottom-left PDF origin).
    public static func defaultFrame(
        at pagePoint: CGPoint,
        in mediaBox: CGRect,
        preferredSize: CGSize = defaultSize
    ) -> CGRect {
        let usableWidth = max(1, mediaBox.width - pageMargin * 2)
        let usableHeight = max(1, mediaBox.height - pageMargin * 2)
        let width = min(preferredSize.width, mediaBox.width >= preferredSize.width + pageMargin * 2 ? preferredSize.width : usableWidth)
        let height = min(preferredSize.height, mediaBox.height >= preferredSize.height + pageMargin * 2 ? preferredSize.height : usableHeight)

        let minX = mediaBox.minX + min(pageMargin, max(0, (mediaBox.width - width) / 2))
        let maxX = max(minX, mediaBox.maxX - width - min(pageMargin, max(0, (mediaBox.width - width) / 2)))
        let minY = mediaBox.minY + min(pageMargin, max(0, (mediaBox.height - height) / 2))
        let maxY = max(minY, mediaBox.maxY - height - min(pageMargin, max(0, (mediaBox.height - height) / 2)))

        let originX = min(max(pagePoint.x, minX), maxX)
        let originY = min(max(pagePoint.y - height, minY), maxY)
        return CGRect(x: originX, y: originY, width: width, height: height)
    }

    /// Clamps an existing rect inside `mediaBox`.
    public static func clampedFrame(_ rect: CGRect, in mediaBox: CGRect) -> CGRect {
        let maxWidth = max(1.0, mediaBox.width)
        let maxHeight = max(1.0, mediaBox.height)
        let minWidth = min(40.0, maxWidth)
        let minHeight = min(32.0, maxHeight)
        let width = min(max(minWidth, rect.width), maxWidth)
        let height = min(max(minHeight, rect.height), maxHeight)
        let minX = mediaBox.minX
        let maxX = max(minX, mediaBox.maxX - width)
        let minY = mediaBox.minY
        let maxY = max(minY, mediaBox.maxY - height)
        let x = min(max(rect.minX, minX), maxX)
        let y = min(max(rect.minY, minY), maxY)
        return CGRect(x: x, y: y, width: width, height: height)
    }

    public static func topmostTextBlock(at pagePoint: CGPoint, in note: Note, pageIndex: Int) -> TextBlock? {
        note.textBlocksArray
            .filter { Int($0.pageIndex) == pageIndex }
            .reversed()
            .first { $0.frame.contains(pagePoint) }
    }

    public static func resolvedTextColor(from hex: String) -> NSColor {
        NSColor(hex: hex) ?? NSColor(srgbRed: 0.110, green: 0.110, blue: 0.118, alpha: 1.0)
    }
}

/// Draws every persisted `TextBlock` for `note` on `pageIndex` into `context`
/// using PDF `mediaBox` coordinates (bottom-left origin, Y-up).
public func renderTextBlocks(
    for note: Note,
    pageIndex: Int,
    into context: CGContext,
    excluding editingID: UUID? = nil
) {
    let blocks = note.textBlocksArray.filter { block in
        Int(block.pageIndex) == pageIndex && block.id != editingID
    }
    guard !blocks.isEmpty else { return }

    let fillColor = CGColor(srgbRed: 1.0, green: 1.0, blue: 1.0, alpha: 0.92)
    let borderColor = CGColor(srgbRed: 0.835, green: 0.820, blue: 0.776, alpha: 0.90)

    context.saveGState()
    for block in blocks {
        let trimmedText = block.text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty else { continue }

        let frame = block.frame
        guard frame.width > 1, frame.height > 1 else { continue }

        let radius = min(TextBlockLayout.cardCornerRadius, min(frame.width, frame.height) / 2)
        let cardPath = CGPath(roundedRect: frame, cornerWidth: radius, cornerHeight: radius, transform: nil)

        context.saveGState()
        context.addPath(cardPath)
        context.setFillColor(fillColor)
        context.fillPath()

        context.addPath(cardPath)
        context.setStrokeColor(borderColor)
        context.setLineWidth(0.75)
        context.strokePath()
        context.restoreGState()

        let textRect = frame.insetBy(
            dx: TextBlockLayout.horizontalPadding,
            dy: TextBlockLayout.verticalPadding
        )
        guard !block.text.isEmpty, textRect.width > 2, textRect.height > 2 else { continue }

        let fontSize = CGFloat(max(8.0, block.fontSize))
        let font = NSFont.systemFont(ofSize: fontSize, weight: .regular)
        let textColor = TextBlockLayout.resolvedTextColor(from: block.colorHex)

        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineBreakMode = .byWordWrapping
        paragraphStyle.alignment = .left

        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: textColor,
            .paragraphStyle: paragraphStyle
        ]
        let attributedString = NSAttributedString(string: block.text, attributes: attributes)
        let framesetter = CTFramesetterCreateWithAttributedString(attributedString)
        let textPath = CGPath(rect: textRect, transform: nil)
        let ctFrame = CTFramesetterCreateFrame(
            framesetter,
            CFRange(location: 0, length: attributedString.length),
            textPath,
            nil
        )

        context.saveGState()
        context.clip(to: textRect)
        context.textMatrix = .identity
        CTFrameDraw(ctFrame, context)
        context.restoreGState()
    }
    context.restoreGState()
}
