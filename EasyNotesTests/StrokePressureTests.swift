import AppKit
import CoreData
import XCTest

final class StrokePressureTests: XCTestCase {
    func testPreferenceDefaultsOffPersistsAndResets() throws {
        let suite = "StrokePressureTests.\(UUID())"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }

        let settings = AppSettingsStore(defaults: defaults)
        XCTAssertFalse(settings.pressureSensitivityEnabled)
        settings.pressureSensitivityEnabled = true
        let reloaded = AppSettingsStore(defaults: defaults)
        XCTAssertTrue(reloaded.pressureSensitivityEnabled)
        reloaded.resetAll()
        XCTAssertFalse(AppSettingsStore(defaults: defaults).pressureSensitivityEnabled)
    }

    func testMouseEventPressureIsIgnored() throws {
        let mouse = try XCTUnwrap(NSEvent.mouseEvent(
            with: .leftMouseDown, location: .zero, modifierFlags: [], timestamp: 0,
            windowNumber: 0, context: nil, eventNumber: 0, clickCount: 1, pressure: 0.6
        ))
        XCTAssertGreaterThan(mouse.pressure, 0)
        XCTAssertNil(TabletPressureSample(event: mouse))
    }

    @MainActor
    func testTabletMouseEventsPersistSamplesUsingPreferenceAtMouseDown() throws {
        _ = NSApplication.shared
        let suite = "StrokePressureTests.\(UUID())"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let settings = AppSettingsStore(defaults: defaults)
        let tools = CanvasViewModel(settings: settings)
        let (model, _) = TestSupport.makeInMemoryViewModel()
        model.addNote(title: "Mesa digitalizadora")
        let note = try XCTUnwrap(model.selectedNote)
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 300),
            styleMask: [.titled], backing: .buffered, defer: false
        )
        let canvas = PageDrawingCanvas(pageIndex: 0, noteVM: model, canvasVM: tools)
        window.contentView?.addSubview(canvas)

        func tabletEvent(_ type: CGEventType, x: CGFloat, pressure: Double) throws -> NSEvent {
            let event = try XCTUnwrap(CGEvent(
                mouseEventSource: nil, mouseType: type,
                mouseCursorPosition: CGPoint(x: x, y: 30), mouseButton: .left
            ))
            event.setIntegerValueField(.mouseEventSubtype, value: 1) // kCGEventMouseSubtypeTabletPoint
            event.setIntegerValueField(.tabletEventDeviceID, value: 42)
            if type == .leftMouseDragged {
                event.setDoubleValueField(.mouseEventPressure, value: pressure)
            } else {
                event.setDoubleValueField(.tabletEventPointPressure, value: pressure)
            }
            return try XCTUnwrap(NSEvent(cgEvent: event))
        }

        let down = try tabletEvent(.leftMouseDown, x: 30, pressure: 0.25)
        let drag = try tabletEvent(.leftMouseDragged, x: 80, pressure: 0.75)
        let up = try tabletEvent(.leftMouseUp, x: 80, pressure: 0)
        let dragWithoutPressure = try tabletEvent(.leftMouseDragged, x: 80, pressure: 0)
        XCTAssertNil(TabletPressureSample(event: dragWithoutPressure))
        settings.pressureSensitivityEnabled = true
        canvas.mouseDown(with: down)
        settings.pressureSensitivityEnabled = false
        canvas.mouseDragged(with: drag)
        canvas.mouseUp(with: up)

        canvas.mouseDown(with: down)
        settings.pressureSensitivityEnabled = true
        canvas.mouseDragged(with: drag)
        canvas.mouseUp(with: up)

        let strokes = try XCTUnwrap(note.strokes as? Set<Stroke>).sorted { $0.createdAt < $1.createdAt }
        XCTAssertEqual(strokes.count, 2)
        let first = try XCTUnwrap(strokes.first)
        let last = try XCTUnwrap(strokes.last)
        let samples = try XCTUnwrap(StrokePressure.samples(in: first.points, pointCount: 2))
        XCTAssertEqual(samples[0], 0.25, accuracy: 0.001)
        XCTAssertEqual(samples[1], 0.75, accuracy: 0.002)
        XCTAssertNil(StrokePressure.samples(in: last.points, pointCount: 2))
    }

    @MainActor
    func testNativeTabletPointUpdatesPressureWithoutMouseMovement() throws {
        _ = NSApplication.shared
        let suite = "StrokePressureTests.\(UUID())"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let settings = AppSettingsStore(defaults: defaults)
        settings.pressureSensitivityEnabled = true
        let (model, _) = TestSupport.makeInMemoryViewModel()
        let tools = CanvasViewModel(settings: settings)
        model.addNote(title: "Ponta parada")
        let canvas = PageDrawingCanvas(pageIndex: 0, noteVM: model, canvasVM: tools)

        func event(_ type: CGEventType, pressure: Double) throws -> NSEvent {
            let cgEvent = try XCTUnwrap(CGEvent(
                mouseEventSource: nil, mouseType: .leftMouseDown,
                mouseCursorPosition: CGPoint(x: 30, y: 30), mouseButton: .left
            ))
            cgEvent.type = type
            cgEvent.setIntegerValueField(.mouseEventSubtype, value: 1)
            cgEvent.setIntegerValueField(.tabletEventDeviceID, value: 42)
            cgEvent.setDoubleValueField(.tabletEventPointPressure, value: pressure)
            return try XCTUnwrap(NSEvent(cgEvent: cgEvent))
        }

        canvas.mouseDown(with: try event(.leftMouseDown, pressure: 0.25))
        canvas.tabletPoint(with: try event(.tabletPointer, pressure: 0.8))
        canvas.mouseUp(with: try event(.leftMouseUp, pressure: 0))

        let strokes = try XCTUnwrap(model.selectedNote?.strokes as? Set<Stroke>)
        let stroke = try XCTUnwrap(strokes.first)
        let samples = try XCTUnwrap(StrokePressure.samples(in: stroke.points, pointCount: 1))
        XCTAssertEqual(samples[0], 0.8, accuracy: 0.002)
    }

    func testLongPressureStrokeRendersWithoutAPathPerSample() throws {
        let bitmap = try XCTUnwrap(CGContext(
            data: nil, width: 1024, height: 1024, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ))
        let points = (0..<4_000).map { index in
            CGPoint(x: 20 + Double(index) * 0.24, y: 512 + 120 * sin(Double(index) / 200))
        }
        let pressure = (0..<4_000).map { CGFloat(0.5 + 0.4 * sin(Double($0) / 90)) }

        let start = ProcessInfo.processInfo.systemUptime
        FreehandStrokeRenderer.draw(points: points, pressure: pressure, width: 12, color: .black, into: bitmap)
        let elapsed = ProcessInfo.processInfo.systemUptime - start

        XCTAssertLessThan(elapsed, 1, "Drawing one long stroke took \(elapsed) seconds")
    }

    func testGesturePolicyAndSampleFallback() throws {
        let first = try XCTUnwrap(TabletPressureSample(deviceID: 1, value: 0.25))
        let second = try XCTUnwrap(TabletPressureSample(deviceID: 1, value: 0.8))
        var capture = StrokePressureCapture(enabled: true, tool: .fountainPen, firstSample: first)
        capture.append(second)
        XCTAssertEqual(capture.samples, [0.25, 0.8])
        capture.append(nil)
        capture.append(second)
        XCTAssertEqual(capture.samples, [0.25, 0.8, 0.8, 0.8])
        XCTAssertTrue(capture.updateLast(first))
        XCTAssertEqual(capture.samples, [0.25, 0.8, 0.8, 0.25])

        var differentDevice = StrokePressureCapture(enabled: true, tool: .fountainPen, firstSample: first)
        differentDevice.append(TabletPressureSample(deviceID: 2, value: 0.8))
        XCTAssertEqual(differentDevice.samples, [0.25, 0.25])
        XCTAssertFalse(differentDevice.updateLast(try XCTUnwrap(TabletPressureSample(deviceID: 2, value: 0.8))))

        var missingStart = StrokePressureCapture(enabled: true, tool: .fountainPen, firstSample: nil)
        missingStart.append(second)
        XCTAssertNil(missingStart.samples)
        XCTAssertNil(StrokePressureCapture(enabled: false, tool: .fountainPen, firstSample: first).samples)
        for tool in ToolType.allCases where tool != .fountainPen {
            XCTAssertNil(StrokePressureCapture(enabled: true, tool: tool, firstSample: first).samples)
        }
        XCTAssertNil(TabletPressureSample(deviceID: 1, value: .nan))
        XCTAssertNil(TabletPressureSample(deviceID: 1, value: 1.1))
    }

    func testSQLiteReopenPreservesLegacyAndPressureStrokes() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let storeURL = directory.appendingPathComponent("notes.sqlite")

        let coordinates = "100.1,200.2;300.3,400.4"
        let pressures: [CGFloat] = [0.2, 0.95]
        let pressurePoints = StrokePressure.storing(pressures, in: coordinates)
        XCTAssertNil(StrokePressure.samples(in: coordinates + ";pressure-v1:0.3", pointCount: 2))
        XCTAssertNil(StrokePressure.samples(in: coordinates + ";pressure-v1:0.3|nan", pointCount: 2))

        let original = try TestSupport.makeSQLiteContainer(at: storeURL)
        let context = original.viewContext
        let viewModel = NoteViewModel(context: context, coverCache: NoteCoverCache())
        viewModel.addNote(title: "Traços", content: "")
        let note = try XCTUnwrap(viewModel.notes.first)

        for (index, data) in [coordinates, pressurePoints].enumerated() {
            let stroke = Stroke(context: context)
            stroke.id = UUID()
            stroke.width = 12
            stroke.color = "#FF0000"
            stroke.createdAt = Date()
            stroke.pageIndex = Int16(index)
            stroke.points = data
            stroke.note = note
        }
        try context.save()
        context.reset()
        let originalStore = try XCTUnwrap(original.persistentStoreCoordinator.persistentStores.first)
        try original.persistentStoreCoordinator.remove(originalStore)

        let reopened = try TestSupport.makeSQLiteContainer(at: storeURL)
        let reopenedStore = try XCTUnwrap(reopened.persistentStoreCoordinator.persistentStores.first)
        defer {
            reopened.viewContext.reset()
            try? reopened.persistentStoreCoordinator.remove(reopenedStore)
        }
        let strokes = try reopened.viewContext.fetch(NSFetchRequest<Stroke>(entityName: "Stroke"))
        XCTAssertEqual(strokes.count, 2)
        let legacy = try XCTUnwrap(strokes.first { $0.pageIndex == 0 })
        let variable = try XCTUnwrap(strokes.first { $0.pageIndex == 1 })
        XCTAssertEqual(legacy.points, coordinates)
        XCTAssertNil(StrokePressure.samples(in: legacy.points, pointCount: 2))
        XCTAssertEqual(variable.points, pressurePoints)
        XCTAssertEqual(StrokePressure.samples(in: variable.points, pointCount: 2), pressures)
        XCTAssertEqual(legacy.width, variable.width)
        XCTAssertEqual(deserializeStrokePoints(variable.points), deserializeStrokePoints(coordinates))
        XCTAssertEqual(variable.note?.title, "Traços")
    }
}
