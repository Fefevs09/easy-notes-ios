import Foundation
import SwiftUI

enum ShapePickerNavigationDirection: Equatable {
    case previous
    case next
}

enum ShapePickerNavigation {
    static func steppedShape(
        from current: ShapeKind?,
        direction: ShapePickerNavigationDirection,
        in options: [ShapeKind] = ShapeKind.drawable
    ) -> ShapeKind? {
        guard !options.isEmpty else { return nil }
        guard let current, let index = options.firstIndex(of: current) else {
            return direction == .next ? options.first : options.last
        }
        let delta = direction == .next ? 1 : -1
        let nextIndex = (index + delta + options.count) % options.count
        return options[nextIndex]
    }

    static func initialFocusedShape(
        activeShape: ShapeKind,
        in options: [ShapeKind] = ShapeKind.drawable
    ) -> ShapeKind? {
        options.contains(activeShape) ? activeShape : options.first
    }

    static func triggerIconName(isShapeToolActive: Bool, activeShape: ShapeKind) -> String {
        isShapeToolActive ? activeShape.systemImage : "square.on.circle"
    }

    static func triggerAccessibilityValue(isShapeToolActive: Bool, activeShape: ShapeKind) -> String {
        isShapeToolActive ? activeShape.displayName : "Inativa"
    }
}

struct ShapePickerTriggerButton: View {
    let activeShape: ShapeKind
    let isActive: Bool
    let isOpen: Bool
    var isFocused: FocusState<Bool>.Binding
    let action: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: ShapePickerNavigation.triggerIconName(isShapeToolActive: isActive, activeShape: activeShape))
                    .font(PixelTheme.uiFont(size: 12, weight: .medium))
                    .foregroundStyle(isActive ? PixelTheme.accent : PixelTheme.inkSecondary)

                Text("Formas")
                    .font(PixelTheme.uiFont(size: 12, weight: .medium))
                    .foregroundStyle(isActive ? PixelTheme.accent : PixelTheme.inkSecondary)

                Image(systemName: "chevron.down")
                    .font(PixelTheme.uiFont(size: 9, weight: .semibold))
                    .foregroundStyle(isActive || isOpen ? PixelTheme.accentDeep : PixelTheme.muted)
                    .rotationEffect(.degrees(isOpen ? 180 : 0))
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: PixelTheme.controlRadius, style: .continuous)
                    .fill(!isActive && (isHovered || isOpen) ? PixelTheme.surface : Color.clear)
            )
            .overlay {
                RoundedRectangle(cornerRadius: PixelTheme.controlRadius, style: .continuous)
                    .strokeBorder((!isActive && isOpen) ? PixelTheme.border : Color.clear, lineWidth: 1)
            }
            .studioActiveTool(isActive)
            .overlay {
                if isFocused.wrappedValue {
                    RoundedRectangle(cornerRadius: PixelTheme.controlRadius + 1, style: .continuous)
                        .stroke(PixelTheme.accent, lineWidth: 2)
                        .padding(-2)
                }
            }
            .contentShape(RoundedRectangle(cornerRadius: PixelTheme.controlRadius, style: .continuous))
            .fixedSize()
        }
        .buttonStyle(.plain)
        .focusable()
        .focused(isFocused)
        .focusEffectDisabled()
        .onKeyPress(.return, phases: .down) { _ in
            action()
            return .handled
        }
        .onKeyPress(.space, phases: .down) { _ in
            action()
            return .handled
        }
        .onHover { isHovered = $0 }
        .animation(reduceMotion ? nil : .easeOut(duration: 0.12), value: isHovered)
        .animation(reduceMotion ? nil : .easeOut(duration: 0.12), value: isOpen)
        .accessibilityLabel("Formas geométricas")
        .accessibilityValue(ShapePickerNavigation.triggerAccessibilityValue(isShapeToolActive: isActive, activeShape: activeShape))
        .accessibilityAddTraits(isActive ? .isSelected : [])
        .accessibilityIdentifier("shape-picker-trigger")
        .help("Formas geométricas")
    }
}

struct ShapePickerPopoverView: View {
    let activeShape: ShapeKind
    let isShapeToolActive: Bool
    let onSelect: (_ kind: ShapeKind, _ restoreFocus: Bool) -> Void
    let onCancel: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @FocusState private var focusedShape: ShapeKind?
    @State private var hoveredShape: ShapeKind?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Text("Formas geométricas")
                    .font(PixelTheme.uiFont(size: 12.5, weight: .semibold))
                    .foregroundStyle(PixelTheme.ink)
                    .accessibilityAddTraits(.isHeader)

                Spacer(minLength: 0)

                if isShapeToolActive {
                    Text("Ativa")
                        .font(PixelTheme.uiFont(size: 10, weight: .semibold))
                        .foregroundStyle(PixelTheme.accentDeep)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            RoundedRectangle(cornerRadius: PixelTheme.compactRadius, style: .continuous)
                                .fill(PixelTheme.accentSoft)
                        )
                }
            }

            VStack(spacing: 4) {
                ForEach(ShapeKind.drawable, id: \.self) { kind in
                    shapeRow(for: kind)
                }
            }

            Text("↑↓ navegar · ⏎ escolher · Esc fechar")
                .font(PixelTheme.uiFont(size: 10, weight: .regular))
                .foregroundStyle(PixelTheme.popoverMuted)
                .accessibilityHidden(true)
        }
        .padding(12)
        .frame(width: 236)
        .studioCard(fill: PixelTheme.paper, radius: PixelTheme.cardRadius, borderColor: PixelTheme.border)
        .background(PixelTheme.paper)
        .preferredColorScheme(.light)
        .defaultFocus($focusedShape, ShapePickerNavigation.initialFocusedShape(activeShape: activeShape))
        .onAppear {
            let initial = ShapePickerNavigation.initialFocusedShape(activeShape: activeShape)
            focusedShape = initial
            DispatchQueue.main.async {
                MainActor.assumeIsolated {
                    if focusedShape == nil {
                        focusedShape = initial
                    }
                }
            }
        }
        .onKeyPress(.upArrow) {
            focusedShape = ShapePickerNavigation.steppedShape(from: focusedShape ?? activeShape, direction: .previous)
            return .handled
        }
        .onKeyPress(.downArrow) {
            focusedShape = ShapePickerNavigation.steppedShape(from: focusedShape ?? activeShape, direction: .next)
            return .handled
        }
        .onKeyPress(.escape, phases: .down) { _ in
            onCancel()
            return .handled
        }
        .onExitCommand(perform: onCancel)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Seletor de formas geométricas")
        .accessibilityIdentifier("shape-picker-popover")
    }

    private func shapeRow(for kind: ShapeKind) -> some View {
        let isSelected = isShapeToolActive && kind == activeShape
        let isHovered = hoveredShape == kind
        let isFocused = focusedShape == kind

        let rowFill: Color = isSelected
            ? PixelTheme.accentSoft
            : (isHovered ? PixelTheme.surface : PixelTheme.paper)
        let borderColor: Color = isFocused
            ? (isSelected ? PixelTheme.accent : PixelTheme.accentBorder)
            : (isSelected
               ? PixelTheme.accentBorder.opacity(0.65)
               : (isHovered ? PixelTheme.border : Color.clear))
        let borderWidth: CGFloat = isFocused ? 2 : 1

        let iconBoxFill: Color = isSelected
            ? PixelTheme.paper.opacity(0.85)
            : (isHovered ? PixelTheme.paper : PixelTheme.surface)
        let iconBoxBorder: Color = isSelected
            ? PixelTheme.accentBorder.opacity(0.7)
            : PixelTheme.border
        let iconForeground: Color = isSelected
            ? PixelTheme.accentDeep
            : ((isHovered || isFocused) ? PixelTheme.ink : PixelTheme.inkSecondary)

        return Button {
            onSelect(kind, false)
        } label: {
            HStack(spacing: 9) {
                ZStack {
                    RoundedRectangle(cornerRadius: PixelTheme.compactRadius, style: .continuous)
                        .fill(iconBoxFill)
                    RoundedRectangle(cornerRadius: PixelTheme.compactRadius, style: .continuous)
                        .strokeBorder(iconBoxBorder, lineWidth: 1)
                    Image(systemName: kind.systemImage)
                        .font(PixelTheme.uiFont(size: 12.5, weight: .medium))
                        .foregroundStyle(iconForeground)
                }
                .frame(width: 26, height: 26)
                .accessibilityHidden(true)

                Text(kind.displayName)
                    .font(PixelTheme.uiFont(size: 12.5, weight: isSelected ? .semibold : .medium))
                    .foregroundStyle(isSelected ? PixelTheme.accentDeep : PixelTheme.ink)
                    .lineLimit(1)

                Spacer(minLength: 8)

                if isSelected {
                    Image(systemName: "checkmark")
                        .font(PixelTheme.uiFont(size: 11, weight: .semibold))
                        .foregroundStyle(PixelTheme.accentDeep)
                        .accessibilityHidden(true)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: PixelTheme.controlRadius, style: .continuous)
                    .fill(rowFill)
            )
            .overlay {
                RoundedRectangle(cornerRadius: PixelTheme.controlRadius, style: .continuous)
                    .strokeBorder(borderColor, lineWidth: borderWidth)
            }
            .contentShape(RoundedRectangle(cornerRadius: PixelTheme.controlRadius, style: .continuous))
        }
        .buttonStyle(.plain)
        .focusable()
        .focused($focusedShape, equals: kind)
        .focusEffectDisabled()
        .onKeyPress(.return, phases: .down) { _ in
            onSelect(kind, true)
            return .handled
        }
        .onKeyPress(.space, phases: .down) { _ in
            onSelect(kind, true)
            return .handled
        }
        .onHover { hovering in
            hoveredShape = hovering ? kind : (hoveredShape == kind ? nil : hoveredShape)
        }
        .animation(reduceMotion ? nil : .easeOut(duration: 0.10), value: isHovered)
        .animation(reduceMotion ? nil : .easeOut(duration: 0.10), value: isFocused)
        .accessibilityLabel(kind.displayName)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityIdentifier("shape-option-\(kind.rawValue)")
    }
}
