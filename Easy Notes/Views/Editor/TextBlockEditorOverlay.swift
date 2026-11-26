import AppKit
import PDFKit

/// Custom NSTextView for inline `TextBlock` editing with IME-aware Escape handling
/// and command shortcuts even when embedded inside PDFKit's view hierarchy.
final class InlineTextBlockTextView: NSTextView {
    var onEscape: (() -> Void)?

    override func cancelOperation(_ sender: Any?) {
        if hasMarkedText() {
            inputContext?.discardMarkedText()
            unmarkText()
            return
        }
        onEscape?()
    }

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        if event.type == .keyDown,
           window?.firstResponder === self,
           let chars = event.charactersIgnoringModifiers?.lowercased() {
            if modifiers == .command {
                switch chars {
                case "a":
                    selectAll(nil)
                    return true
                case "c":
                    copy(nil)
                    return true
                case "v":
                    paste(nil)
                    return true
                case "x":
                    cut(nil)
                    return true
                case "z":
                    if undoManager?.canUndo == true {
                        undoManager?.undo()
                    }
                    return true
                default:
                    break
                }
            } else if modifiers == [.command, .shift], chars == "z" {
                if undoManager?.canRedo == true {
                    undoManager?.redo()
                }
                return true
            }
        }
        return super.performKeyEquivalent(with: event)
    }
}

/// Inline AppKit editor overlay mounted over a `PageDrawingCanvas` when creating
/// or editing a `TextBlock`. New blocks are kept as in-memory drafts until
/// committed with non-empty text, preventing ghost records or phantom cards.
final class TextBlockEditorOverlay: NSView, NSTextViewDelegate {
    private(set) var existingBlock: TextBlock?
    let blockID: UUID
    let isNewDraft: Bool
    let note: Note
    let pageIndex: Int
    let mediaBox: CGRect
    private let originalText: String

    private(set) var currentPageFrame: CGRect
    private(set) var currentFontSize: CGFloat
    private(set) var currentColorHex: String

    private weak var noteVM: NoteViewModel?
    private weak var canvasVM: CanvasViewModel?
    private weak var page: PDFPage?
    private weak var pdfView: PDFView?

    private let scrollView = NSScrollView()
    let textView = InlineTextBlockTextView()
    private var isFinishing = false

    var onDidFinish: ((_ restoreCanvasFocus: Bool) -> Void)?

    /// Initializes the overlay for editing an existing persisted `TextBlock`.
    convenience init(
        block: TextBlock,
        mediaBox: CGRect,
        page: PDFPage?,
        pdfView: PDFView?,
        noteVM: NoteViewModel?,
        canvasVM: CanvasViewModel?
    ) {
        guard let owner = block.note else {
            fatalError("Editing TextBlock requires an owning Note")
        }
        self.init(
            existingBlock: block,
            blockID: block.id,
            note: owner,
            pageIndex: Int(block.pageIndex),
            initialFrame: block.frame,
            initialText: block.text,
            fontSize: CGFloat(max(8.0, block.fontSize)),
            colorHex: block.colorHex,
            mediaBox: mediaBox,
            page: page,
            pdfView: pdfView,
            noteVM: noteVM,
            canvasVM: canvasVM
        )
    }

    /// Initializes the overlay for creating a new in-memory `TextBlock` draft.
    convenience init(
        note: Note,
        pageIndex: Int,
        initialFrame: CGRect,
        fontSize: CGFloat,
        colorHex: String,
        mediaBox: CGRect,
        page: PDFPage?,
        pdfView: PDFView?,
        noteVM: NoteViewModel?,
        canvasVM: CanvasViewModel?
    ) {
        self.init(
            existingBlock: nil,
            blockID: UUID(),
            note: note,
            pageIndex: pageIndex,
            initialFrame: initialFrame,
            initialText: "",
            fontSize: fontSize,
            colorHex: colorHex,
            mediaBox: mediaBox,
            page: page,
            pdfView: pdfView,
            noteVM: noteVM,
            canvasVM: canvasVM
        )
    }

    private init(
        existingBlock: TextBlock?,
        blockID: UUID,
        note: Note,
        pageIndex: Int,
        initialFrame: CGRect,
        initialText: String,
        fontSize: CGFloat,
        colorHex: String,
        mediaBox: CGRect,
        page: PDFPage?,
        pdfView: PDFView?,
        noteVM: NoteViewModel?,
        canvasVM: CanvasViewModel?
    ) {
        self.existingBlock = existingBlock
        self.blockID = blockID
        self.isNewDraft = (existingBlock == nil)
        self.note = note
        self.pageIndex = pageIndex
        self.mediaBox = mediaBox
        self.originalText = initialText
        self.currentPageFrame = initialFrame
        self.currentFontSize = min(max(fontSize, TextBlockLayout.fontSizeRange.lowerBound), TextBlockLayout.fontSizeRange.upperBound)
        self.currentColorHex = colorHex
        self.page = page
        self.pdfView = pdfView
        self.noteVM = noteVM
        self.canvasVM = canvasVM

        super.init(frame: initialFrame)
        setupView(initialText: initialText)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupView(initialText: String) {
        wantsLayer = true
        layer?.backgroundColor = NSColor(srgbRed: 1.0, green: 1.0, blue: 1.0, alpha: 0.97).cgColor
        layer?.cornerRadius = TextBlockLayout.cardCornerRadius
        layer?.borderWidth = 1.5
        layer?.borderColor = NSColor.controlAccentColor.cgColor

        scrollView.frame = bounds
        scrollView.autoresizingMask = [.width, .height]
        scrollView.drawsBackground = false
        scrollView.hasVerticalScroller = false
        scrollView.hasHorizontalScroller = false
        scrollView.borderType = .noBorder

        textView.delegate = self
        textView.isEditable = true
        textView.isSelectable = true
        textView.isRichText = false
        textView.importsGraphics = false
        textView.allowsUndo = true
        textView.drawsBackground = false
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.minSize = NSSize(width: 0, height: 0)
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.containerSize = NSSize(width: max(1, bounds.width), height: CGFloat.greatestFiniteMagnitude)
        textView.textContainer?.lineFragmentPadding = 4
        textView.textContainerInset = NSSize(
            width: TextBlockLayout.horizontalPadding - 4,
            height: TextBlockLayout.verticalPadding
        )
        textView.string = initialText
        textView.setAccessibilityLabel("Editor de bloco de texto")
        textView.setAccessibilityRole(.textArea)
        textView.onEscape = { [weak self] in
            self?.finishEditing(restoreCanvasFocus: true)
        }

        applyTextAppearance()
        scrollView.documentView = textView
        addSubview(scrollView)
    }

    private func applyTextAppearance() {
        let color = TextBlockLayout.resolvedTextColor(from: currentColorHex)
        textView.font = NSFont.systemFont(ofSize: currentFontSize, weight: .regular)
        textView.textColor = color
        textView.insertionPointColor = color
    }

    func updateOverlayGeometry(in canvas: NSView) {
        let targetRect: CGRect
        if let page, let pdfView {
            let p1 = canvas.convert(
                pdfView.convert(CGPoint(x: currentPageFrame.minX, y: currentPageFrame.minY), from: page),
                from: pdfView
            )
            let p2 = canvas.convert(
                pdfView.convert(CGPoint(x: currentPageFrame.maxX, y: currentPageFrame.maxY), from: page),
                from: pdfView
            )
            targetRect = CGRect(
                x: min(p1.x, p2.x),
                y: min(p1.y, p2.y),
                width: max(40, abs(p2.x - p1.x)),
                height: max(32, abs(p2.y - p1.y))
            )
        } else {
            targetRect = currentPageFrame
        }
        if frame != targetRect {
            frame = targetRect
            textView.textContainer?.containerSize = NSSize(
                width: max(1, targetRect.width - (TextBlockLayout.horizontalPadding - 4) * 2),
                height: CGFloat.greatestFiniteMagnitude
            )
        }
    }

    func focusEditor() {
        window?.makeFirstResponder(textView)
        let length = (textView.string as NSString).length
        textView.setSelectedRange(NSRange(location: length, length: 0))
    }

    func applyStyle(fontSize: CGFloat, colorHex: String) {
        let clampedFont = min(max(fontSize, TextBlockLayout.fontSizeRange.lowerBound), TextBlockLayout.fontSizeRange.upperBound)
        let changed = abs(clampedFont - currentFontSize) > 0.01 || colorHex != currentColorHex
        guard changed else { return }

        currentFontSize = clampedFont
        currentColorHex = colorHex
        applyTextAppearance()
        expandHeightToFitIfNeeded()
    }

    func finishEditing(restoreCanvasFocus: Bool = false, deferPublishedUpdates: Bool = false) {
        guard !isFinishing else { return }
        isFinishing = true

        let rawText = textView.string
        let trimmed = rawText.trimmingCharacters(in: .whitespacesAndNewlines)

        let clearEditingState = { [weak canvasVM, blockID] in
            if canvasVM?.editingTextBlockID == blockID {
                canvasVM?.editingTextBlockID = nil
            }
        }
        if deferPublishedUpdates {
            DispatchQueue.main.async(execute: clearEditingState)
        } else {
            clearEditingState()
        }

        if isNewDraft {
            if !trimmed.isEmpty, !note.isDeleted {
                _ = noteVM?.addTextBlock(
                    to: note,
                    pageIndex: pageIndex,
                    frame: currentPageFrame,
                    text: rawText,
                    fontSize: Float(currentFontSize),
                    colorHex: currentColorHex,
                    reloadNotes: !deferPublishedUpdates
                )
            }
        } else if let block = existingBlock, !block.isDeleted, block.managedObjectContext != nil {
            if trimmed.isEmpty {
                // Protect existing block against accidental loss when emptied: restore original text.
                textView.string = originalText
                noteVM?.updateTextBlock(
                    block,
                    text: originalText,
                    frame: currentPageFrame,
                    fontSize: Float(currentFontSize),
                    colorHex: currentColorHex,
                    reloadNotes: !deferPublishedUpdates
                )
            } else {
                noteVM?.updateTextBlock(
                    block,
                    text: rawText,
                    frame: currentPageFrame,
                    fontSize: Float(currentFontSize),
                    colorHex: currentColorHex,
                    reloadNotes: !deferPublishedUpdates
                )
            }
        }

        if deferPublishedUpdates {
            DispatchQueue.main.async { [weak noteVM] in
                noteVM?.loadNotes()
            }
        }

        removeFromSuperview()
        onDidFinish?(restoreCanvasFocus)
    }

    private func expandHeightToFitIfNeeded() {
        guard let layoutManager = textView.layoutManager,
              let textContainer = textView.textContainer else { return }
        layoutManager.ensureLayout(for: textContainer)
        let usedRect = layoutManager.usedRect(for: textContainer)
        let neededHeight = ceil(usedRect.height + TextBlockLayout.verticalPadding * 2 + 2)
        guard neededHeight > currentPageFrame.height + 0.5 else { return }

        let effectiveMargin = mediaBox.height > TextBlockLayout.pageMargin * 2 ? TextBlockLayout.pageMargin : 0
        let minAllowedY = mediaBox.minY + effectiveMargin
        let maxAllowedY = mediaBox.maxY - effectiveMargin
        let maxUsableHeight = max(1, maxAllowedY - minAllowedY)
        let targetHeight = min(neededHeight, maxUsableHeight)
        guard targetHeight > currentPageFrame.height + 0.5 else { return }

        let topEdge = min(currentPageFrame.maxY, maxAllowedY)
        var newY = topEdge - targetHeight
        if newY < minAllowedY {
            // Reached bottom margin: shift upward within mediaBox to keep growing up to maxUsableHeight.
            newY = minAllowedY
        }

        let expanded = CGRect(
            x: currentPageFrame.origin.x,
            y: newY,
            width: currentPageFrame.width,
            height: targetHeight
        )
        currentPageFrame = TextBlockLayout.clampedFrame(expanded, in: mediaBox)
        if let superview {
            updateOverlayGeometry(in: superview)
        }
    }

    // MARK: - NSTextViewDelegate

    func textDidChange(_ notification: Notification) {
        guard !isFinishing else { return }
        expandHeightToFitIfNeeded()
    }

    func textView(_ textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
        if commandSelector == #selector(NSResponder.cancelOperation(_:)) {
            if textView.hasMarkedText() {
                return false
            }
            finishEditing(restoreCanvasFocus: true)
            return true
        }
        return false
    }

    func textDidEndEditing(_ notification: Notification) {
        if canvasVM?.isTextStylePopoverPresented == true {
            return
        }
        finishEditing(restoreCanvasFocus: false)
    }
}
