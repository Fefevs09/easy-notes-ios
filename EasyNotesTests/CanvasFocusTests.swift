import AppKit
import SwiftUI
import XCTest

@MainActor
final class CanvasFocusTests: XCTestCase {
    func testFirstPenDownAfterRenameEndsEditingAndBeginsStroke() throws {
        _ = NSApplication.shared
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 400, height: 300),
                              styleMask: [.titled], backing: .buffered, defer: false)
        let title = NSTextField(string: "Original")
        title.frame = NSRect(x: 10, y: 250, width: 250, height: 24)
        let tools = CanvasViewModel()
        let canvas = PageDrawingCanvas(pageIndex: 0, noteVM: nil, canvasVM: tools)
        canvas.frame = NSRect(x: 0, y: 0, width: 400, height: 240)
        window.contentView?.addSubview(title)
        window.contentView?.addSubview(canvas)
        XCTAssertTrue(window.makeFirstResponder(title))
        let editor = try XCTUnwrap(title.currentEditor() as? NSTextView)
        editor.selectAll(nil)
        editor.insertText("Página recém-renomeada", replacementRange: editor.selectedRange())
        let point = NSPoint(x: 50, y: 80)
        let event = try XCTUnwrap(NSEvent.mouseEvent(with: .leftMouseDown, location: point,
            modifierFlags: [], timestamp: 0, windowNumber: window.windowNumber, context: nil,
            eventNumber: 1, clickCount: 1, pressure: 1))
        canvas.mouseDown(with: event)
        XCTAssertFalse(window.firstResponder === editor)
        XCTAssertEqual(title.stringValue, "Página recém-renomeada")
        XCTAssertEqual(tools.activeStroke?.points, [point])
    }

    func testReturnInEditorCommitsTitleAndFocusesCanvas() throws {
        _ = NSApplication.shared
        let (model, context) = TestSupport.makeInMemoryViewModel()
        model.addNote(title: "Original")
        let note = try XCTUnwrap(model.selectedNote)
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 1100, height: 700),
                              styleMask: [.titled], backing: .buffered, defer: false)
        let host = NSHostingView(rootView: ContentView().environmentObject(model)
            .environment(\.managedObjectContext, context))
        host.frame = try XCTUnwrap(window.contentView).bounds
        window.contentView?.addSubview(host)
        window.displayIfNeeded()
        host.layoutSubtreeIfNeeded()

        func titleField(in view: NSView) -> NSTextField? {
            if let field = view as? NSTextField, field.isEditable, field.stringValue == "Original" {
                return field
            }
            return view.subviews.lazy.compactMap { titleField(in: $0) }.first
        }
        let title = try XCTUnwrap(titleField(in: host))
        XCTAssertTrue(window.makeFirstResponder(title))
        let editor = try XCTUnwrap(title.currentEditor() as? NSTextView)
        editor.selectAll(nil)
        editor.insertText("Última edição 📝", replacementRange: editor.selectedRange())
        let enter = try XCTUnwrap(NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: [],
            timestamp: 0, windowNumber: window.windowNumber, context: nil, characters: "\r",
            charactersIgnoringModifiers: "\r", isARepeat: false, keyCode: 36))
        window.sendEvent(enter)
        RunLoop.main.run(until: Date().addingTimeInterval(0.05))
        XCTAssertTrue(window.firstResponder is NSPDFAnnotationView)
        XCTAssertEqual(note.committedValues(forKeys: ["title"])["title"] as? String, "Última edição 📝")

        let nextField = NSTextField(string: "")
        nextField.frame = NSRect(x: 0, y: 0, width: 150, height: 24)
        window.contentView?.addSubview(nextField)
        title.nextKeyView = nextField
        XCTAssertTrue(window.makeFirstResponder(title))
        let tab = try XCTUnwrap(NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: [],
            timestamp: 0, windowNumber: window.windowNumber, context: nil, characters: "\t",
            charactersIgnoringModifiers: "\t", isARepeat: false, keyCode: 48))
        window.sendEvent(tab)
        RunLoop.main.run(until: Date().addingTimeInterval(0.05))
        XCTAssertNotNil(nextField.currentEditor())
    }
}
