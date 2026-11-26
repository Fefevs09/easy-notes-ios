import AppKit
import Foundation
import SwiftUI

/// Tool context presented by the custom pen color picker.
public enum PenColorToolContext: Equatable {
    case pen
    case highlighter
    case shape
    case textBox

    public init(tool: ToolType) {
        switch tool {
        case .highlighter:
            self = .highlighter
        case .shape:
            self = .shape
        case .textBox:
            self = .textBox
        default:
            self = .pen
        }
    }

    public var badgeTitle: String {
        switch self {
        case .pen:
            return "Caneta"
        case .highlighter:
            return "Marca-texto"
        case .shape:
            return "Formas"
        case .textBox:
            return "Texto"
        }
    }

    public var isOpacityLocked: Bool {
        self == .highlighter
    }

    public var lockedOpacity: Double? {
        self == .highlighter ? Double(CanvasViewModel.highlighterOpacity) : nil
    }
}

/// Normalized sRGB + opacity representation used as the bridge between
/// `CanvasViewModel.strokeColor`, the custom color picker UI, and hex serialization.
public struct PenColorComponents: Equatable {
    public let red: Double
    public let green: Double
    public let blue: Double
    public let opacity: Double

    public init(red: Double, green: Double, blue: Double, opacity: Double = 1.0) {
        self.red = min(max(red, 0.0), 1.0)
        self.green = min(max(green, 0.0), 1.0)
        self.blue = min(max(blue, 0.0), 1.0)
        self.opacity = min(max(opacity, 0.0), 1.0)
    }

    public var hex6: String {
        let r = Int(round(red * 255.0))
        let g = Int(round(green * 255.0))
        let b = Int(round(blue * 255.0))
        return String(format: "#%02X%02X%02X", r, g, b)
    }

    public var hexString: String {
        let r = Int(round(red * 255.0))
        let g = Int(round(green * 255.0))
        let b = Int(round(blue * 255.0))
        let a = Int(round(opacity * 255.0))
        if a < 255 {
            return String(format: "#%02X%02X%02X%02X", r, g, b, a)
        }
        return String(format: "#%02X%02X%02X", r, g, b)
    }

    public var opacityPercent: Int {
        Int(round(opacity * 100.0))
    }

    public var hsv: (hue: Double, saturation: Double, brightness: Double) {
        let maxVal = max(red, green, blue)
        let minVal = min(red, green, blue)
        let delta = maxVal - minVal

        var hue = 0.0
        if delta > 0.000001 {
            if maxVal == red {
                hue = ((green - blue) / delta).truncatingRemainder(dividingBy: 6.0)
            } else if maxVal == green {
                hue = (blue - red) / delta + 2.0
            } else {
                hue = (red - green) / delta + 4.0
            }
            hue /= 6.0
            if hue < 0.0 {
                hue += 1.0
            }
        }

        let saturation = maxVal <= 0.000001 ? 0.0 : delta / maxVal
        return (hue: min(max(hue, 0.0), 1.0), saturation: min(max(saturation, 0.0), 1.0), brightness: maxVal)
    }

    public var opaqueColor: Color {
        Color(.sRGB, red: red, green: green, blue: blue, opacity: 1.0)
    }

    public var swiftUIColor: Color {
        Color(.sRGB, red: red, green: green, blue: blue, opacity: opacity)
    }

    public func withOpacity(_ newOpacity: Double) -> PenColorComponents {
        PenColorComponents(red: red, green: green, blue: blue, opacity: newOpacity)
    }

    public func matchesPreset(_ preset: Color) -> Bool {
        hex6 == PenColorComponents.from(preset).hex6
    }

    public static func from(_ color: Color) -> PenColorComponents {
        let nsColor = NSColor(color)
        let srgb = nsColor.usingColorSpace(.sRGB) ?? nsColor.usingColorSpace(.deviceRGB)
        guard let resolved = srgb else {
            return PenColorComponents(red: 0, green: 0, blue: 0, opacity: 1)
        }
        return PenColorComponents(
            red: Double(resolved.redComponent),
            green: Double(resolved.greenComponent),
            blue: Double(resolved.blueComponent),
            opacity: Double(resolved.alphaComponent)
        )
    }

    public static func fromHSV(
        hue: Double,
        saturation: Double,
        brightness: Double,
        opacity: Double = 1.0
    ) -> PenColorComponents {
        let h = min(max(hue, 0.0), 1.0)
        let s = min(max(saturation, 0.0), 1.0)
        let v = min(max(brightness, 0.0), 1.0)

        let sector = Int(floor(h * 6.0))
        let fraction = h * 6.0 - Double(sector)
        let p = v * (1.0 - s)
        let q = v * (1.0 - fraction * s)
        let t = v * (1.0 - (1.0 - fraction) * s)

        let r: Double
        let g: Double
        let b: Double
        switch sector % 6 {
        case 0: (r, g, b) = (v, t, p)
        case 1: (r, g, b) = (q, v, p)
        case 2: (r, g, b) = (p, v, t)
        case 3: (r, g, b) = (p, q, v)
        case 4: (r, g, b) = (t, p, v)
        default: (r, g, b) = (v, p, q)
        }

        let rByte = min(max(Int(round(r * 255.0)), 0), 255)
        let gByte = min(max(Int(round(g * 255.0)), 0), 255)
        let bByte = min(max(Int(round(b * 255.0)), 0), 255)

        return PenColorComponents(
            red: Double(rByte) / 255.0,
            green: Double(gByte) / 255.0,
            blue: Double(bByte) / 255.0,
            opacity: opacity
        )
    }

    public static func pureHueColor(hue: Double) -> Color {
        fromHSV(hue: hue, saturation: 1.0, brightness: 1.0, opacity: 1.0).opaqueColor
    }

    public static func normalizeHex(_ raw: String) -> String? {
        var trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasPrefix("#") {
            trimmed.removeFirst()
        }
        guard trimmed.count == 6 else { return nil }
        let isValidHex = trimmed.unicodeScalars.allSatisfy { scalar in
            (scalar.value >= 48 && scalar.value <= 57) ||   // 0-9
            (scalar.value >= 65 && scalar.value <= 70) ||   // A-F
            (scalar.value >= 97 && scalar.value <= 102)     // a-f
        }
        guard isValidHex else { return nil }
        return "#" + trimmed.uppercased()
    }

    public static func fromHex(_ raw: String, opacity: Double = 1.0) -> PenColorComponents? {
        guard let normalized = normalizeHex(raw) else { return nil }
        let hexDigits = String(normalized.dropFirst())
        guard let rgb = UInt64(hexDigits, radix: 16) else { return nil }
        let r = Double((rgb & 0xFF0000) >> 16) / 255.0
        let g = Double((rgb & 0x00FF00) >> 8) / 255.0
        let b = Double(rgb & 0x0000FF) / 255.0
        return PenColorComponents(red: r, green: g, blue: b, opacity: opacity)
    }

    public static func clampedOpacity(_ raw: Double, for context: PenColorToolContext) -> Double {
        if let locked = context.lockedOpacity {
            return locked
        }
        let clamped = min(max(raw, 0.10), 1.0)
        return (clamped * 100.0).rounded() / 100.0
    }
}
