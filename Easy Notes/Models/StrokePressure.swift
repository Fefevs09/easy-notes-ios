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
        let pressure: CGFloat
        switch event.type {
        case .tabletPoint:
            pressure = CGFloat(event.pressure)
        case .leftMouseDown, .leftMouseDragged:
            guard event.subtype == .tabletPoint else { return nil }
            // Some tablet drivers expose pressure through the mouse event
            // rather than the tablet-specific Quartz field.
            let tabletPressure = event.cgEvent?.getDoubleValueField(.tabletEventPointPressure) ?? 0
            pressure = tabletPressure > 0 ? CGFloat(tabletPressure) : CGFloat(event.pressure)
        default:
            return nil
        }
        guard pressure > 0 else { return nil }
        self.init(deviceID: event.deviceID, value: pressure)
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
        guard let last = samples?.last else { return }
        // Once the gesture is linked to a tablet, a mouse-only event can
        // supply a position between pressure reports. Keep the last width.
        samples?.append(sample?.deviceID == deviceID ? sample?.value ?? last : last)
    }

    mutating func updateLast(_ sample: TabletPressureSample) -> Bool {
        guard sample.deviceID == deviceID, let index = samples?.indices.last,
              samples?[index] != sample.value else { return false }
        samples?[index] = sample.value
        return true
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
