import AppKit

struct TabletPressureSample {
    let deviceID: Int
    let value: CGFloat

    init?(deviceID: Int, value: CGFloat) {
        guard value.isFinite, (0...1).contains(value) else { return nil }
        self.deviceID = deviceID
        self.value = value
    }

    init?(event: NSEvent) {
        // The mouse pressure field is also populated by trackpads. Tablet
        // drivers attach tablet-point data to the mouse events used to draw.
        guard event.type == .leftMouseDown || event.type == .leftMouseDragged,
              event.subtype == .tabletPoint,
              let tabletPoint = event.cgEvent else { return nil }
        let pressure = tabletPoint.getDoubleValueField(.tabletEventPointPressure)
        // A zero tablet field can also mean the driver supplied no pressure.
        // Mouse-up releases are deliberately excluded from capture.
        guard pressure > 0 else { return nil }
        self.init(deviceID: event.deviceID, value: CGFloat(pressure))
    }
}

struct StrokePressureCapture {
    private let deviceID: Int?
    private(set) var samples: [CGFloat]?

    init(enabled: Bool, tool: ToolType, firstSample: TabletPressureSample?) {
        if enabled, tool == .fountainPen, let firstSample, firstSample.value > 0 {
            deviceID = firstSample.deviceID
            samples = [firstSample.value]
        } else {
            deviceID = nil
        }
    }

    mutating func append(_ sample: TabletPressureSample?) {
        guard samples != nil else { return }
        guard let sample, sample.deviceID == deviceID else {
            samples = nil
            return
        }
        samples?.append(sample.value)
    }
}

enum StrokePressure {
    // A semicolon-delimited extension with no comma is skipped by legacy
    // coordinate readers. The Core Data field and coordinate tokens stay intact.
    private static let marker = "pressure-v1:"

    static func storing(_ samples: [CGFloat]?, in coordinates: String) -> String {
        guard let samples, !samples.isEmpty,
              samples.allSatisfy({ $0.isFinite && (0...1).contains($0) }) else { return coordinates }
        return coordinates + ";" + marker + samples.map { String(Double($0)) }.joined(separator: "|")
    }

    static func samples(in serialized: String, pointCount: Int) -> [CGFloat]? {
        guard let suffix = serialized.split(separator: ";").last, suffix.hasPrefix(marker) else { return nil }
        let fields = suffix.dropFirst(marker.count).split(separator: "|", omittingEmptySubsequences: false)
        guard fields.count == pointCount else { return nil }
        let samples = fields.compactMap { Double($0) }.map { CGFloat($0) }
        guard samples.count == pointCount,
              samples.allSatisfy({ $0.isFinite && (0...1).contains($0) }) else { return nil }
        return samples
    }
}
