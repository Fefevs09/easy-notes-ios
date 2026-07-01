import SwiftUI
import AppKit

struct TextEditorView: NSViewRepresentable {
    @Binding var text: String
    
    class Coordinator: NSObject, NSTextViewDelegate {
        var parent: TextEditorView
        var isUpdating = false
        
        init(_ parent: TextEditorView) {
            self.parent = parent
        }
        
        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            isUpdating = true
            parent.text = textView.string
            isUpdating = false
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.drawsBackground = false
        scrollView.autoresizingMask = [.width, .height]
        
        let textView = NSTextView()
        textView.delegate = context.coordinator
        textView.isRichText = false
        textView.font = NSFont.systemFont(ofSize: 15, weight: .regular)
        textView.textColor = NSColor.textColor
        textView.drawsBackground = false
        
        // Disable automatic quote and dash substitution to make it coding/raw-text friendly
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        
        // Layout and paddings
        textView.textContainerInset = NSSize(width: 24, height: 24)
        textView.autoresizingMask = [.width]
        
        scrollView.documentView = textView
        return scrollView
    }
    
    func updateNSView(_ nsView: NSScrollView, context: Context) {
        guard let textView = nsView.documentView as? NSTextView else { return }
        
        if !context.coordinator.isUpdating {
            let currentSelectedRanges = textView.selectedRanges
            textView.string = text
            if currentSelectedRanges.count > 0 {
                textView.selectedRanges = currentSelectedRanges
            }
        }
    }
}
