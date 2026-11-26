import AppKit
import Foundation
import SwiftUI

// MARK: - Trigger Button (Contextual Toolbar)

struct PenColorTriggerButton: View {
    let color: Color
    let toolContext: PenColorToolContext
    let isOpen: Bool
    let action: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @FocusState private var isFocused: Bool
    @State private var isHovered = false

    private var components: PenColorComponents {
        PenColorComponents.from(color)
    }

    private var effectiveOpacity: Double {
        toolContext.lockedOpacity ?? components.opacity
    }

    private var effectivePercent: Int {
        Int((effectiveOpacity * 100.0).rounded())
    }

    private var borderColor: Color {
        if isOpen {
            return PixelTheme.accentBorder
        }
        return isHovered ? PixelTheme.borderStrong : PixelTheme.border
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                ZStack {
                    Circle()
                        .fill(PixelTheme.paper)
                    Circle()
                        .fill(components.opaqueColor.opacity(effectiveOpacity))
                        .frame(width: 14, height: 14)
                    Circle()
                        .strokeBorder(PixelTheme.borderStrong, lineWidth: 1)
                }
                .frame(width: 18, height: 18)

                Image(systemName: "chevron.down")
                    .font(PixelTheme.uiFont(size: 9, weight: .semibold))
                    .foregroundStyle(isOpen ? PixelTheme.accentDeep : PixelTheme.inkSecondary)
            }
            .padding(.leading, 5)
            .padding(.trailing, 7)
            .frame(height: 26)
            .background(
                RoundedRectangle(cornerRadius: PixelTheme.controlRadius, style: .continuous)
                    .fill(isOpen ? PixelTheme.accentSoft : PixelTheme.paper)
            )
            .overlay {
                RoundedRectangle(cornerRadius: PixelTheme.controlRadius, style: .continuous)
                    .strokeBorder(borderColor, lineWidth: isOpen ? 1.5 : 1)
            }
            .overlay {
                if isFocused {
                    RoundedRectangle(cornerRadius: PixelTheme.controlRadius + 1, style: .continuous)
                        .stroke(PixelTheme.accent, lineWidth: 2)
                        .padding(-2)
                }
            }
            .contentShape(RoundedRectangle(cornerRadius: PixelTheme.controlRadius, style: .continuous))
        }
        .buttonStyle(.plain)
        .focused($isFocused)
        .focusEffectDisabled()
        .onHover { isHovered = $0 }
        .animation(reduceMotion ? nil : .easeOut(duration: 0.10), value: isHovered)
        .animation(reduceMotion ? nil : .easeOut(duration: 0.10), value: isOpen)
        .accessibilityLabel("Personalizar cor")
        .accessibilityValue("\(components.hex6), \(effectivePercent)%")
        .accessibilityAddTraits(isOpen ? .isSelected : [])
        .accessibilityIdentifier("pen-color-trigger")
        .help("Personalizar cor")
    }
}

// MARK: - Option B Horizontal Low-Occlusion Color Popover

struct PenColorPopoverView: View {
    private enum FocusField: Hashable {
        case container
        case hex
    }

    @Binding var color: Color
    let toolContext: PenColorToolContext
    let onClose: () -> Void
    let initialInvalidHex: String?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @FocusState private var focusedField: FocusField?

    private var isHexFocused: Bool {
        focusedField == .hex
    }

    @State private var hue: Double
    @State private var saturation: Double
    @State private var brightness: Double
    @State private var opacity: Double
    @State private var hexText: String
    @State private var isHexInvalid: Bool
    @State private var lastEmittedSignature: String
    @State private var isCloseHovered = false

    init(
        color: Binding<Color>,
        toolContext: PenColorToolContext,
        onClose: @escaping () -> Void,
        initialInvalidHex: String? = nil
    ) {
        self._color = color
        self.toolContext = toolContext
        self.onClose = onClose
        self.initialInvalidHex = initialInvalidHex

        let initialComponents = PenColorComponents.from(color.wrappedValue)
        let initialHSV = initialComponents.hsv
        let initialEffectiveOpacity = PenColorComponents.clampedOpacity(
            initialComponents.opacity,
            for: toolContext
        )
        let resolvedComponents = initialComponents.withOpacity(initialEffectiveOpacity)

        _hue = State(initialValue: initialHSV.hue)
        _saturation = State(initialValue: initialHSV.saturation)
        _brightness = State(initialValue: initialHSV.brightness)
        _opacity = State(initialValue: initialEffectiveOpacity)

        if let invalidHex = initialInvalidHex {
            _hexText = State(initialValue: invalidHex)
            _isHexInvalid = State(initialValue: PenColorComponents.normalizeHex(invalidHex) == nil)
        } else {
            _hexText = State(initialValue: initialComponents.hex6)
            _isHexInvalid = State(initialValue: false)
        }

        _lastEmittedSignature = State(initialValue: Self.signature(for: resolvedComponents))
    }

    private var effectiveOpacity: Double {
        toolContext.lockedOpacity ?? opacity
    }

    private var effectiveOpacityPercent: Int {
        Int((effectiveOpacity * 100.0).rounded())
    }

    private var currentComponents: PenColorComponents {
        PenColorComponents.fromHSV(
            hue: hue,
            saturation: saturation,
            brightness: brightness,
            opacity: effectiveOpacity
        )
    }

    private var currentOpaqueColor: Color {
        currentComponents.opaqueColor
    }

    private var hexFieldBinding: Binding<String> {
        Binding(
            get: { hexText },
            set: { handleUserHexInput($0) }
        )
    }

    private var hexBoxBackground: Color {
        if isHexInvalid {
            return PixelTheme.dangerSoft
        }
        return isHexFocused ? PixelTheme.paper : PixelTheme.surface
    }

    private var hexBoxBorderColor: Color {
        if isHexInvalid {
            return PixelTheme.danger
        }
        return isHexFocused ? PixelTheme.accent : PixelTheme.borderStrong
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            headerRow

            HStack(alignment: .top, spacing: 14) {
                leftColumn
                rightColumn
            }
        }
        .padding(14)
        .frame(width: 416)
        .background(PixelTheme.paper)
        .preferredColorScheme(.light)
        .focusable()
        .focused($focusedField, equals: .container)
        .focusEffectDisabled()
        .defaultFocus($focusedField, .container)
        .onAppear {
            syncFromExternalColorIfNeeded(color)
            focusedField = .container
        }
        .onChange(of: color) { _, newColor in
            syncFromExternalColorIfNeeded(newColor)
        }
        .onChange(of: toolContext) { _, newContext in
            let nextOp = PenColorComponents.clampedOpacity(opacity, for: newContext)
            if abs(nextOp - opacity) > 0.0001 {
                opacity = nextOp
            }
            let updated = PenColorComponents.fromHSV(
                hue: hue,
                saturation: saturation,
                brightness: brightness,
                opacity: newContext.lockedOpacity ?? nextOp
            )
            lastEmittedSignature = Self.signature(for: updated)
        }
        .onChange(of: focusedField) { _, nextField in
            if nextField != .hex {
                commitHexIfValid()
            }
        }
        .onExitCommand(perform: onClose)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Seletor de cor personalizada")
        .accessibilityIdentifier("pen-color-popover")
    }

    // MARK: - Header

    private var headerRow: some View {
        HStack(spacing: 8) {
            HStack(spacing: 6) {
                Text("Cor personalizada")
                    .font(PixelTheme.uiFont(size: 12.5, weight: .semibold))
                    .foregroundStyle(PixelTheme.ink)
                    .lineLimit(1)

                Text(toolContext.badgeTitle)
                    .font(PixelTheme.uiFont(size: 10, weight: .semibold))
                    .foregroundStyle(PixelTheme.accentDeep)
                    .lineLimit(1)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(
                        RoundedRectangle(cornerRadius: PixelTheme.compactRadius, style: .continuous)
                            .fill(PixelTheme.accentSoft)
                    )
            }

            Spacer(minLength: 0)

            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(PixelTheme.uiFont(size: 9.5, weight: .semibold))
                    .foregroundStyle(isCloseHovered ? PixelTheme.ink : PixelTheme.inkSecondary)
                    .frame(width: 22, height: 22)
                    .background(
                        RoundedRectangle(cornerRadius: PixelTheme.compactRadius, style: .continuous)
                            .fill(PixelTheme.surface)
                    )
                    .overlay {
                        RoundedRectangle(cornerRadius: PixelTheme.compactRadius, style: .continuous)
                            .strokeBorder(isCloseHovered ? PixelTheme.borderStrong : Color.clear, lineWidth: 1)
                    }
                    .contentShape(RoundedRectangle(cornerRadius: PixelTheme.compactRadius, style: .continuous))
            }
            .buttonStyle(.plain)
            .onHover { isCloseHovered = $0 }
            .animation(reduceMotion ? nil : .easeOut(duration: 0.10), value: isCloseHovered)
            .accessibilityLabel("Fechar seletor")
            .accessibilityIdentifier("pen-color-close")
            .help("Fechar seletor")
        }
        .frame(height: 22)
    }

    // MARK: - Left Column (2D SB Area + Hue Track)

    private var leftColumn: some View {
        VStack(alignment: .leading, spacing: 10) {
            SaturationBrightnessPicker(
                hue: hue,
                saturation: saturation,
                brightness: brightness,
                currentOpaqueColor: currentOpaqueColor
            ) { nextSaturation, nextBrightness in
                focusedField = .container
                saturation = nextSaturation
                brightness = nextBrightness
                isHexInvalid = false
                let updated = emitCurrentColor()
                hexText = updated.hex6
            }
            .frame(width: 196, height: 134)

            VStack(alignment: .leading, spacing: 5) {
                Text("Matiz")
                    .font(PixelTheme.uiFont(size: 11, weight: .medium))
                    .foregroundStyle(PixelTheme.popoverMuted)
                    .lineLimit(1)

                HueTrackSlider(hue: hue) { nextHue in
                    focusedField = .container
                    hue = nextHue
                    isHexInvalid = false
                    let updated = emitCurrentColor()
                    hexText = updated.hex6
                }
            }
        }
        .frame(width: 196)
    }

    // MARK: - Right Column (Paper Preview + HEX + Opacity)

    private var rightColumn: some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 4) {
                    Text("Prévia no papel")
                        .font(PixelTheme.uiFont(size: 11, weight: .medium))
                        .foregroundStyle(PixelTheme.popoverMuted)
                        .lineLimit(1)
                    Spacer(minLength: 0)
                    Text("\(effectiveOpacityPercent)%")
                        .font(.system(size: 10.5, weight: .medium, design: .monospaced))
                        .monospacedDigit()
                        .foregroundStyle(PixelTheme.inkSecondary)
                }

                PaperStrokePreview(
                    toolContext: toolContext,
                    color: currentOpaqueColor,
                    opacity: effectiveOpacity
                )
            }

            hexSection

            opacitySection
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - HEX Input + Fixed-Height Validation Slot

    private var hexSection: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 8) {
                Text("HEX")
                    .font(PixelTheme.uiFont(size: 11, weight: .medium))
                    .foregroundStyle(PixelTheme.popoverMuted)
                    .frame(width: 26, alignment: .leading)

                HStack(spacing: 7) {
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(currentOpaqueColor)
                        .overlay {
                            RoundedRectangle(cornerRadius: 4, style: .continuous)
                                .strokeBorder(PixelTheme.borderStrong, lineWidth: 1)
                        }
                        .frame(width: 14, height: 14)

                    TextField("", text: hexFieldBinding)
                        .textFieldStyle(.plain)
                        .focused($focusedField, equals: .hex)
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .foregroundStyle(isHexInvalid ? PixelTheme.danger : PixelTheme.ink)
                        .onSubmit {
                            commitHexIfValid()
                            focusedField = .container
                        }
                        .onExitCommand(perform: onClose)
                        .accessibilityLabel("Valor hexadecimal")
                        .accessibilityIdentifier("pen-color-hex-field")
                }
                .padding(.horizontal, 8)
                .frame(height: 30)
                .background(
                    RoundedRectangle(cornerRadius: PixelTheme.controlRadius, style: .continuous)
                        .fill(hexBoxBackground)
                )
                .overlay {
                    RoundedRectangle(cornerRadius: PixelTheme.controlRadius, style: .continuous)
                        .strokeBorder(hexBoxBorderColor, lineWidth: isHexInvalid ? 1.5 : 1)
                }
                .animation(reduceMotion ? nil : .easeOut(duration: 0.10), value: isHexInvalid)
                .animation(reduceMotion ? nil : .easeOut(duration: 0.10), value: isHexFocused)
            }

            HStack(spacing: 4) {
                Image(systemName: "exclamationmark.circle.fill")
                    .font(.system(size: 10.5))
                    .foregroundStyle(PixelTheme.danger)
                Text("Use formato #RRGGBB")
                    .font(PixelTheme.uiFont(size: 10, weight: .medium))
                    .foregroundStyle(PixelTheme.danger)
                    .lineLimit(1)
                    .minimumScaleFactor(0.9)
            }
            .padding(.leading, 34)
            .frame(height: 15, alignment: .leading)
            .opacity(isHexInvalid ? 1 : 0)
            .accessibilityHidden(!isHexInvalid)
            .accessibilityIdentifier("pen-color-hex-error")
            .animation(reduceMotion ? nil : .easeOut(duration: 0.10), value: isHexInvalid)
        }
    }

    // MARK: - Opacity Slot (Fixed 38pt Height Across Tools)

    private var opacitySection: some View {
        Group {
            if toolContext.isOpacityLocked {
                HStack(spacing: 8) {
                    HStack(spacing: 6) {
                        Image(systemName: "lock")
                            .font(.system(size: 10.5, weight: .medium))
                            .foregroundStyle(PixelTheme.ink)
                        Text("Opacidade \(Int((Double(CanvasViewModel.highlighterOpacity) * 100.0).rounded()))%")
                            .font(PixelTheme.uiFont(size: 11.5, weight: .semibold))
                            .foregroundStyle(PixelTheme.ink)
                            .lineLimit(1)
                    }

                    Spacer(minLength: 0)

                    Text("Fixa")
                        .font(PixelTheme.uiFont(size: 10.5, weight: .regular))
                        .foregroundStyle(PixelTheme.popoverMuted)
                        .lineLimit(1)
                }
                .padding(.horizontal, 10)
                .frame(height: 34)
                .background(
                    RoundedRectangle(cornerRadius: PixelTheme.controlRadius, style: .continuous)
                        .fill(PixelTheme.surface)
                )
                .overlay {
                    RoundedRectangle(cornerRadius: PixelTheme.controlRadius, style: .continuous)
                        .strokeBorder(PixelTheme.border, lineWidth: 1)
                }
                .help("A opacidade do marca-texto é fixa em 30%")
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("pen-color-opacity-locked")
            } else {
                VStack(alignment: .leading, spacing: 5) {
                    HStack(spacing: 4) {
                        Text("Opacidade")
                            .font(PixelTheme.uiFont(size: 11, weight: .medium))
                            .foregroundStyle(PixelTheme.popoverMuted)
                            .lineLimit(1)
                        Spacer(minLength: 0)
                        Text("\(effectiveOpacityPercent)%")
                            .font(.system(size: 10.5, weight: .medium, design: .monospaced))
                            .monospacedDigit()
                            .foregroundStyle(PixelTheme.inkSecondary)
                    }

                    OpacityTrackSlider(
                        color: currentOpaqueColor,
                        opacity: effectiveOpacity,
                        toolContext: toolContext
                    ) { nextOpacity in
                        focusedField = .container
                        opacity = nextOpacity
                        isHexInvalid = false
                        let updated = emitCurrentColor()
                        hexText = updated.hex6
                    }
                }
            }
        }
        .frame(height: 38, alignment: .center)
    }

    // MARK: - State Synchronization Helpers

    private static func signature(for components: PenColorComponents) -> String {
        "\(components.hex6)@\(components.opacityPercent)"
    }

    @discardableResult
    private func emitCurrentColor(componentsOverride: PenColorComponents? = nil) -> PenColorComponents {
        let resolved = componentsOverride ?? currentComponents
        let effective = resolved.withOpacity(
            PenColorComponents.clampedOpacity(resolved.opacity, for: toolContext)
        )
        lastEmittedSignature = Self.signature(for: effective)
        color = effective.swiftUIColor
        return effective
    }

    private func syncFromExternalColorIfNeeded(_ incomingColor: Color) {
        let raw = PenColorComponents.from(incomingColor)
        let clampedOp = PenColorComponents.clampedOpacity(raw.opacity, for: toolContext)
        let resolved = raw.withOpacity(clampedOp)
        let incomingSignature = Self.signature(for: resolved)

        guard incomingSignature != lastEmittedSignature else { return }

        let hsv = resolved.hsv
        hue = hsv.hue
        saturation = hsv.saturation
        brightness = hsv.brightness
        opacity = clampedOp
        hexText = resolved.hex6
        isHexInvalid = false
        lastEmittedSignature = incomingSignature
    }

    private func handleUserHexInput(_ raw: String) {
        if let normalized = PenColorComponents.normalizeHex(raw) {
            hexText = raw.count > 7 ? normalized : raw
            isHexInvalid = false
            if let parsed = PenColorComponents.fromHex(normalized, opacity: effectiveOpacity) {
                let hsv = parsed.hsv
                hue = hsv.hue
                saturation = hsv.saturation
                brightness = hsv.brightness
                emitCurrentColor(componentsOverride: parsed)
            }
        } else {
            hexText = String(raw.prefix(7))
            isHexInvalid = true
        }
    }

    private func commitHexIfValid() {
        guard let normalized = PenColorComponents.normalizeHex(hexText) else { return }
        hexText = normalized
        isHexInvalid = false
    }
}

// MARK: - 2D Saturation × Brightness Picker

private struct SaturationBrightnessPicker: View {
    let hue: Double
    let saturation: Double
    let brightness: Double
    let currentOpaqueColor: Color
    let onChange: (Double, Double) -> Void

    @State private var isCrosshairPushed = false

    var body: some View {
        GeometryReader { proxy in
            let width = max(proxy.size.width, 1)
            let height = max(proxy.size.height, 1)
            let reticleX = min(max(saturation, 0), 1) * width
            let reticleY = (1.0 - min(max(brightness, 0), 1)) * height

            ZStack {
                PenColorComponents.pureHueColor(hue: hue)

                LinearGradient(
                    colors: [.white, .white.opacity(0)],
                    startPoint: .leading,
                    endPoint: .trailing
                )

                LinearGradient(
                    colors: [.black.opacity(0), .black],
                    startPoint: .top,
                    endPoint: .bottom
                )

                Circle()
                    .fill(currentOpaqueColor)
                    .overlay {
                        Circle()
                            .strokeBorder(Color.white, lineWidth: 2)
                    }
                    .frame(width: 14, height: 14)
                    .shadow(color: Color.black.opacity(0.45), radius: 2, x: 0, y: 1)
                    .position(x: reticleX, y: reticleY)
                    .allowsHitTesting(false)
            }
            .clipShape(RoundedRectangle(cornerRadius: PixelTheme.controlRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: PixelTheme.controlRadius, style: .continuous)
                    .strokeBorder(PixelTheme.border, lineWidth: 1)
            }
            .contentShape(RoundedRectangle(cornerRadius: PixelTheme.controlRadius, style: .continuous))
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        let nextS = min(max(value.location.x / width, 0.0), 1.0)
                        let nextV = 1.0 - min(max(value.location.y / height, 0.0), 1.0)
                        onChange(nextS, nextV)
                    }
            )
            .onHover { hovering in
                updateCrosshairCursor(active: hovering)
            }
            .onDisappear {
                updateCrosshairCursor(active: false)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Saturação e luminosidade")
        .accessibilityValue(
            "Saturação \(Int((saturation * 100.0).rounded()))%, luminosidade \(Int((brightness * 100.0).rounded()))%"
        )
        .accessibilityIdentifier("pen-color-sb-picker")
    }

    private func updateCrosshairCursor(active: Bool) {
        if active && !isCrosshairPushed {
            NSCursor.crosshair.push()
            isCrosshairPushed = true
        } else if !active && isCrosshairPushed {
            NSCursor.pop()
            isCrosshairPushed = false
        }
    }
}

// MARK: - Hue Track Slider

private struct HueTrackSlider: View {
    let hue: Double
    let onChange: (Double) -> Void

    private static let hueGradientStops: [Gradient.Stop] = [
        .init(color: Color(.sRGB, red: Double(0xFF) / 255, green: Double(0x3B) / 255, blue: Double(0x30) / 255, opacity: 1), location: 0.00),
        .init(color: Color(.sRGB, red: Double(0xFF) / 255, green: Double(0xCC) / 255, blue: 0.0, opacity: 1), location: 0.17),
        .init(color: Color(.sRGB, red: Double(0x34) / 255, green: Double(0xC7) / 255, blue: Double(0x59) / 255, opacity: 1), location: 0.33),
        .init(color: Color(.sRGB, red: 0.0, green: Double(0xC7) / 255, blue: Double(0xBE) / 255, opacity: 1), location: 0.50),
        .init(color: Color(.sRGB, red: 0.0, green: Double(0x7A) / 255, blue: 1.0, opacity: 1), location: 0.67),
        .init(color: Color(.sRGB, red: Double(0xAF) / 255, green: Double(0x52) / 255, blue: Double(0xDE) / 255, opacity: 1), location: 0.83),
        .init(color: Color(.sRGB, red: Double(0xFF) / 255, green: Double(0x3B) / 255, blue: Double(0x30) / 255, opacity: 1), location: 1.00)
    ]

    var body: some View {
        GeometryReader { proxy in
            let trackWidth = max(proxy.size.width, 16)
            let usableWidth = max(trackWidth - 16, 1)
            let clampedHue = min(max(hue, 0.0), 0.999)
            let handleX = 8 + usableWidth * clampedHue

            ZStack {
                Capsule()
                    .fill(
                        LinearGradient(
                            stops: Self.hueGradientStops,
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .overlay {
                        Capsule()
                            .strokeBorder(PixelTheme.ink.opacity(0.12), lineWidth: 1)
                    }
                    .frame(height: 12)

                Circle()
                    .fill(PenColorComponents.pureHueColor(hue: clampedHue))
                    .overlay {
                        Circle()
                            .strokeBorder(Color.white, lineWidth: 2.5)
                    }
                    .frame(width: 16, height: 16)
                    .shadow(color: Color.black.opacity(0.30), radius: 2, x: 0, y: 1)
                    .position(x: handleX, y: proxy.size.height / 2)
                    .allowsHitTesting(false)
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        let raw = (value.location.x - 8) / usableWidth
                        onChange(min(max(raw, 0.0), 0.999))
                    }
            )
        }
        .frame(height: 16)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Matiz")
        .accessibilityValue("\(Int((hue * 360.0).rounded()))°")
        .accessibilityIdentifier("pen-color-hue-slider")
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment:
                onChange(min(hue + 0.02, 0.999))
            case .decrement:
                onChange(max(hue - 0.02, 0.0))
            @unknown default:
                break
            }
        }
    }
}

// MARK: - Opacity Track Slider

private struct OpacityTrackSlider: View {
    let color: Color
    let opacity: Double
    let toolContext: PenColorToolContext
    let onChange: (Double) -> Void

    var body: some View {
        GeometryReader { proxy in
            let trackWidth = max(proxy.size.width, 14)
            let usableWidth = max(trackWidth - 14, 1)
            let clamped = min(max(opacity, 0.0), 1.0)
            let handleX = 7 + usableWidth * clamped

            ZStack {
                Capsule()
                    .fill(PixelTheme.sidebar)
                    .overlay {
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [color.opacity(0), color],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                    }
                    .overlay {
                        Capsule()
                            .strokeBorder(PixelTheme.border, lineWidth: 1)
                    }
                    .frame(height: 10)

                Circle()
                    .fill(color)
                    .overlay {
                        Circle()
                            .strokeBorder(Color.white, lineWidth: 2)
                    }
                    .frame(width: 14, height: 14)
                    .shadow(color: Color.black.opacity(0.28), radius: 2, x: 0, y: 1)
                    .position(x: handleX, y: proxy.size.height / 2)
                    .allowsHitTesting(false)
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        let raw = (value.location.x - 7) / usableWidth
                        onChange(PenColorComponents.clampedOpacity(raw, for: toolContext))
                    }
            )
        }
        .frame(height: 16)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Opacidade")
        .accessibilityValue("\(Int((opacity * 100.0).rounded()))%")
        .accessibilityIdentifier("pen-color-opacity-slider")
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment:
                onChange(PenColorComponents.clampedOpacity(opacity + 0.05, for: toolContext))
            case .decrement:
                onChange(PenColorComponents.clampedOpacity(opacity - 0.05, for: toolContext))
            @unknown default:
                break
            }
        }
    }
}

// MARK: - Paper Stroke Preview

private struct PaperStrokePreview: View {
    let toolContext: PenColorToolContext
    let color: Color
    let opacity: Double

    var body: some View {
        ZStack {
            PixelTheme.paper

            // Ruled paper lines matching editor.css (1px at y = 16, 30, 44)
            Canvas { context, size in
                let ruleColor = PixelTheme.border.opacity(0.7)
                for y in [16.0, 30.0, 44.0] {
                    let rect = CGRect(x: 0, y: y, width: size.width, height: 1)
                    context.fill(Path(rect), with: .color(ruleColor))
                }
            }

            if toolContext == .highlighter {
                Text("A membrana plasmática controla as trocas")
                    .font(PixelTheme.uiFont(size: 10, weight: .regular))
                    .foregroundStyle(PixelTheme.popoverMuted.opacity(0.78))
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .padding(.horizontal, 10)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            }

            strokeOverlay
        }
        .frame(height: 48)
        .clipShape(RoundedRectangle(cornerRadius: PixelTheme.controlRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: PixelTheme.controlRadius, style: .continuous)
                .strokeBorder(PixelTheme.border, lineWidth: 1)
        }
        .accessibilityHidden(true)
    }

    private var strokeOverlay: some View {
        GeometryReader { proxy in
            let sx = proxy.size.width / 236.0
            let sy = proxy.size.height / 52.0
            let pt: (CGFloat, CGFloat) -> CGPoint = { x, y in
                CGPoint(x: x * sx, y: y * sy)
            }

            switch toolContext {
            case .highlighter:
                Path { path in
                    path.move(to: pt(16, 26))
                    path.addCurve(
                        to: pt(218, 25),
                        control1: pt(68, 23),
                        control2: pt(152, 29)
                    )
                }
                .stroke(
                    color,
                    style: StrokeStyle(lineWidth: 14, lineCap: .round)
                )
                .opacity(Double(CanvasViewModel.highlighterOpacity))

            case .pen:
                Path { path in
                    path.move(to: pt(18, 34))
                    path.addCurve(
                        to: pt(146, 21),
                        control1: pt(60, 11),
                        control2: pt(102, 42)
                    )
                    path.addCurve(
                        to: pt(218, 23),
                        control1: pt(176, 7),
                        control2: pt(198, 31)
                    )
                }
                .stroke(
                    color,
                    style: StrokeStyle(lineWidth: 3.5, lineCap: .round)
                )
                .opacity(opacity)

            case .shape:
                Path { path in
                    path.addRoundedRect(
                        in: CGRect(x: 24 * sx, y: 12 * sy, width: 64 * sx, height: 28 * sy),
                        cornerSize: CGSize(width: 4 * sx, height: 4 * sy)
                    )
                    path.move(to: pt(108, 32))
                    path.addLine(to: pt(188, 18))
                    path.move(to: pt(180, 13))
                    path.addLine(to: pt(189, 18))
                    path.addLine(to: pt(183, 26))
                }
                .stroke(
                    color,
                    style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round)
                )
                .opacity(opacity)

            case .textBox:
                Text("Bloco de texto")
                    .font(PixelTheme.uiFont(size: 14, weight: .medium))
                    .foregroundStyle(color.opacity(opacity))
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                    .padding(.horizontal, 12)
            }
        }
    }
}
