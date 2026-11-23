import AppKit
import CoreData
import Foundation
import SwiftUI

// MARK: - Pure Presentation Model (Testable Menu Rules)

public enum NoteActionMenuActionKind: String, Equatable, Sendable {
    case restore
    case deletePermanently
    case chooseCover
    case replaceCover
    case removeCover
    case exportPDF
    case moveTo
    case deleteToTrash
}

public struct NoteActionMenuDestination: Identifiable, Equatable, Sendable {
    public let id: String
    public let swatchIndex: Int?
    public let notebookID: UUID?
    public let title: String
    public let isCurrent: Bool
    public let isDisabled: Bool

    public init(id: String, notebookID: UUID?, title: String, isCurrent: Bool, isDisabled: Bool, swatchIndex: Int? = nil) {
        self.swatchIndex = swatchIndex
        self.id = id
        self.notebookID = notebookID
        self.title = title
        self.isCurrent = isCurrent
        self.isDisabled = isDisabled
    }
}

public struct NoteActionMenuModel: Equatable {
    public static let curatedEmojis: [String] = [
        "📝", "📚", "💡", "🎯", "✅", "📌",
        "🔬", "🎨", "🧠", "🗓️", "⭐️", "🔥"
    ]

    public let noteID: UUID
    public let noteTitle: String
    public let displayTitle: String
    public let displayEmoji: String?
    public let isTrashContext: Bool
    public let hasCustomCover: Bool
    public let coverActionTitle: String
    public let showsRenameAndEmojiSection: Bool
    public let showsCoverSection: Bool
    public let showsRemoveCoverAction: Bool
    public let showsExportPDFAction: Bool
    public let showsMoveSection: Bool
    public let deleteActionTitle: String
    public let actions: [NoteActionMenuActionKind]
    public let moveDestinations: [NoteActionMenuDestination]

    public init(note: Note, notebooks: [Notebook], filter: FilterType) {
        let isTrash = (filter == .trash)
        let customCover = note.hasCustomCover

        self.noteID = note.id
        self.noteTitle = note.title
        self.displayTitle = note.title.isEmpty ? "Sem título" : note.title
        self.displayEmoji = note.displayEmoji
        self.isTrashContext = isTrash
        self.hasCustomCover = customCover
        self.coverActionTitle = customCover ? "Trocar capa…" : "Escolher capa…"
        self.showsRenameAndEmojiSection = !isTrash
        self.showsCoverSection = !isTrash
        self.showsRemoveCoverAction = !isTrash && customCover
        self.showsExportPDFAction = !isTrash
        self.showsMoveSection = !isTrash
        self.deleteActionTitle = isTrash ? "Excluir Definitivamente" : "Excluir Nota"

        if isTrash {
            self.actions = [.restore, .deletePermanently]
            self.moveDestinations = []
        } else {
            var resolvedActions: [NoteActionMenuActionKind] = [
                customCover ? .replaceCover : .chooseCover
            ]
            if customCover {
                resolvedActions.append(.removeCover)
            }
            resolvedActions.append(contentsOf: [.exportPDF, .moveTo, .deleteToTrash])
            self.actions = resolvedActions

            var destinations: [NoteActionMenuDestination] = [
                NoteActionMenuDestination(
                    id: "uncategorized",
                    notebookID: nil,
                    title: "Notas Soltas",
                    isCurrent: note.notebook == nil,
                    isDisabled: note.notebook == nil
                )
            ]
            for notebook in notebooks {
                let isCurrentNotebook = (note.notebook == notebook)
                destinations.append(
                    NoteActionMenuDestination(
                        id: notebook.id.uuidString,
                        notebookID: notebook.id,
                        title: notebook.path,
                        isCurrent: isCurrentNotebook,
                        isDisabled: isCurrentNotebook,
                        swatchIndex: notebook.swatchIndex
                    )
                )
            }
            self.moveDestinations = destinations
        }
    }
}

// MARK: - AppKit Secondary-Click Interceptor

struct SecondaryClickOverlay: NSViewRepresentable {
    let onSecondaryClick: () -> Void

    final class Coordinator {
        var onSecondaryClick: () -> Void

        init(onSecondaryClick: @escaping () -> Void) {
            self.onSecondaryClick = onSecondaryClick
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onSecondaryClick: onSecondaryClick)
    }

    func makeNSView(context: Context) -> SecondaryClickDetectorView {
        let view = SecondaryClickDetectorView()
        let coordinator = context.coordinator
        view.onSecondaryClick = {
            coordinator.onSecondaryClick()
        }
        return view
    }

    func updateNSView(_ nsView: SecondaryClickDetectorView, context: Context) {
        context.coordinator.onSecondaryClick = onSecondaryClick
        let coordinator = context.coordinator
        nsView.onSecondaryClick = {
            coordinator.onSecondaryClick()
        }
    }

    static func dismantleNSView(_ nsView: SecondaryClickDetectorView, coordinator: Coordinator) {
        nsView.teardownMonitor()
        nsView.onSecondaryClick = nil
    }
}

@MainActor
final class SecondaryClickMonitorRegistry {
    static let shared = SecondaryClickMonitorRegistry()

    private struct WeakDetectorBox {
        weak var view: SecondaryClickDetectorView?
    }

    private var boxes: [WeakDetectorBox] = []
    private var eventMonitor: Any?

    var activeDetectorCount: Int {
        prune()
        return boxes.count
    }

    var hasInstalledMonitor: Bool {
        eventMonitor != nil
    }

    func register(_ view: SecondaryClickDetectorView) {
        prune()
        if !boxes.contains(where: { $0.view === view }) {
            boxes.append(WeakDetectorBox(view: view))
        }
        installMonitorIfNeeded()
    }

    func unregister(_ view: SecondaryClickDetectorView) {
        boxes.removeAll { $0.view == nil || $0.view === view }
        if boxes.isEmpty {
            removeMonitor()
        }
    }

    private func prune() {
        boxes.removeAll { $0.view == nil }
        if boxes.isEmpty {
            removeMonitor()
        }
    }

    private func installMonitorIfNeeded() {
        guard eventMonitor == nil, !boxes.isEmpty else { return }
        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: [.rightMouseDown, .leftMouseDown]) { [weak self] event in
            self?.dispatchMouseEvent(event) ?? event
        }
    }

    private func removeMonitor() {
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
    }

    private func dispatchMouseEvent(_ event: NSEvent) -> NSEvent? {
        prune()
        for box in boxes {
            guard let detector = box.view,
                  detector.shouldInterceptSecondaryClick(for: event) else {
                continue
            }
            let callback = detector.onSecondaryClick
            DispatchQueue.main.async {
                callback?()
            }
            return nil
        }
        return event
    }
}

final class SecondaryClickDetectorView: NSView {
    var onSecondaryClick: (() -> Void)?

    isolated deinit {
        teardownMonitor()
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        nil
    }

    override func viewWillMove(toWindow newWindow: NSWindow?) {
        super.viewWillMove(toWindow: newWindow)
        if newWindow == nil {
            teardownMonitor()
        }
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if window != nil {
            installMonitorIfNeeded()
        } else {
            teardownMonitor()
        }
    }

    func teardownMonitor() {
        SecondaryClickMonitorRegistry.shared.unregister(self)
    }

    private func installMonitorIfNeeded() {
        SecondaryClickMonitorRegistry.shared.register(self)
    }

    func shouldInterceptSecondaryClick(for event: NSEvent) -> Bool {
        let isSecondaryClick = event.type == .rightMouseDown
            || (event.type == .leftMouseDown && event.modifierFlags.contains(.control))
        guard isSecondaryClick else { return false }

        guard let window,
              event.window === window,
              NSApp.modalWindow == nil,
              window.attachedSheet == nil,
              !NSApp.windows.contains(where: { ($0 is NSOpenPanel || $0 is NSSavePanel) && $0.isVisible }),
              !isHiddenOrHasHiddenAncestor else {
            return false
        }

        guard window.contentLayoutRect.contains(event.locationInWindow) else {
            return false
        }

        let localPoint = convert(event.locationInWindow, from: nil)
        guard bounds.contains(localPoint), visibleRect.contains(localPoint) else {
            return false
        }

        if let rootView = window.contentView?.superview ?? window.contentView {
            let rootPoint = rootView.convert(event.locationInWindow, from: nil)
            guard let hitView = rootView.hitTest(rootPoint) else {
                return false
            }
            let ownerContainer: NSView? = enclosingScrollView ?? superview
            if let ownerContainer, !hitView.isDescendant(of: ownerContainer) {
                return false
            }
        }

        return true
    }
}

// MARK: - Custom Note Action Menu Popover

struct NoteActionMenuPopoverView: View {
    private enum FocusField: Hashable {
        case container
        case title
        case customEmoji
    }

    @ObservedObject var note: Note
    let notebooks: [Notebook]
    let filter: FilterType

    let onRename: (String) throws -> Void
    let onSetEmoji: (String?) throws -> Void
    let onChooseCover: () -> Void
    let onRemoveCover: () -> Void
    let onExportPDF: () -> Void
    let onMoveToNotebook: (UUID?) -> Void
    let onRestore: () -> Void
    let onDelete: () -> Void
    let onClose: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @FocusState private var focusedField: FocusField?

    @State private var draftTitle: String
    @State private var customEmojiInput: String = ""
    @State private var inlineErrorMessage: String?
    @State private var isMoveSectionExpanded = false
    @State private var isCloseHovered = false

    init(
        note: Note,
        notebooks: [Notebook],
        filter: FilterType,
        onRename: @escaping (String) throws -> Void,
        onSetEmoji: @escaping (String?) throws -> Void,
        onChooseCover: @escaping () -> Void,
        onRemoveCover: @escaping () -> Void,
        onExportPDF: @escaping () -> Void,
        onMoveToNotebook: @escaping (UUID?) -> Void,
        onRestore: @escaping () -> Void,
        onDelete: @escaping () -> Void,
        onClose: @escaping () -> Void
    ) {
        self.note = note
        self.notebooks = notebooks
        self.filter = filter
        self.onRename = onRename
        self.onSetEmoji = onSetEmoji
        self.onChooseCover = onChooseCover
        self.onRemoveCover = onRemoveCover
        self.onExportPDF = onExportPDF
        self.onMoveToNotebook = onMoveToNotebook
        self.onRestore = onRestore
        self.onDelete = onDelete
        self.onClose = onClose
        self._draftTitle = State(initialValue: note.title)
    }

    private var model: NoteActionMenuModel {
        NoteActionMenuModel(note: note, notebooks: notebooks, filter: filter)
    }

    private var hasUnsavedTitleChanges: Bool {
        draftTitle != note.title
    }

    private var hasValidCustomEmoji: Bool {
        NoteViewModel.normalizedEmoji(customEmojiInput) != nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if model.isTrashContext {
                trashMenuContent
            } else {
                standardMenuContent
            }
        }
        .padding(14)
        .frame(width: 304)
        .background(PixelTheme.paper)
        .preferredColorScheme(.light)
        .focusable()
        .focused($focusedField, equals: .container)
        .focusEffectDisabled()
        .defaultFocus($focusedField, .container)
        .onAppear {
            draftTitle = note.title
            inlineErrorMessage = nil
            focusedField = .container
        }
        .onExitCommand(perform: onClose)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Opções da nota \(model.displayTitle)")
    }

    // MARK: - Trash Context Menu

    private var trashMenuContent: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 8) {
                if let emoji = model.displayEmoji {
                    Text(emoji)
                        .font(.system(size: 16))
                        .frame(width: 28, height: 28)
                        .background(
                            RoundedRectangle(cornerRadius: PixelTheme.compactRadius, style: .continuous)
                                .fill(PixelTheme.surface)
                        )
                        .overlay {
                            RoundedRectangle(cornerRadius: PixelTheme.compactRadius, style: .continuous)
                                .strokeBorder(PixelTheme.border, lineWidth: 1)
                        }
                        .accessibilityHidden(true)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(model.displayTitle)
                        .font(PixelTheme.uiFont(size: 13.5, weight: .semibold))
                        .foregroundStyle(PixelTheme.ink)
                        .lineLimit(2)
                        .accessibilityAddTraits(.isHeader)

                    Text("Na lixeira")
                        .font(PixelTheme.uiFont(size: 11, weight: .medium))
                        .foregroundStyle(PixelTheme.muted)
                }

                Spacer(minLength: 4)

                closeButton
            }

            Rectangle()
                .fill(PixelTheme.border)
                .frame(height: 1)

            MenuActionButton(
                title: "Restaurar Nota",
                systemImage: "arrow.uturn.backward",
                isDestructive: false
            ) {
                onRestore()
                onClose()
            }

            Rectangle()
                .fill(PixelTheme.border)
                .frame(height: 1)

            MenuActionButton(
                title: model.deleteActionTitle,
                systemImage: "trash",
                isDestructive: true
            ) {
                onDelete()
                onClose()
            }
        }
    }

    // MARK: - Standard Library / Notebook Menu

    private var standardMenuContent: some View {
        VStack(alignment: .leading, spacing: 10) {
            headerRow

            if let errorMessage = inlineErrorMessage {
                inlineErrorBanner(errorMessage)
            }

            identitySection

            sectionDivider

            coverSection

            sectionDivider

            additionalActionsSection

            sectionDivider

            MenuActionButton(
                title: model.deleteActionTitle,
                systemImage: "trash",
                isDestructive: true
            ) {
                onDelete()
                onClose()
            }
        }
    }

    private var headerRow: some View {
        HStack(spacing: 8) {
            Text("Opções da nota")
                .studioSectionHeader()
                .accessibilityAddTraits(.isHeader)

            Spacer(minLength: 4)

            closeButton
        }
        .frame(height: 22)
    }

    private var closeButton: some View {
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
                        .strokeBorder(isCloseHovered ? PixelTheme.borderStrong : PixelTheme.border, lineWidth: 1)
                }
                .contentShape(RoundedRectangle(cornerRadius: PixelTheme.compactRadius, style: .continuous))
        }
        .buttonStyle(.plain)
        .onHover { isCloseHovered = $0 }
        .animation(reduceMotion ? nil : .easeOut(duration: 0.10), value: isCloseHovered)
        .accessibilityLabel("Cancelar e fechar")
        .help("Fechar (Esc)")
    }

    private func inlineErrorBanner(_ message: String) -> some View {
        HStack(alignment: .top, spacing: 6) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 11))
                .foregroundStyle(PixelTheme.danger)
                .padding(.top, 1)
                .accessibilityHidden(true)

            Text(message)
                .font(PixelTheme.uiFont(size: 11, weight: .medium))
                .foregroundStyle(PixelTheme.danger)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 7)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: PixelTheme.controlRadius, style: .continuous)
                .fill(PixelTheme.dangerSoft)
        )
        .overlay {
            RoundedRectangle(cornerRadius: PixelTheme.controlRadius, style: .continuous)
                .strokeBorder(PixelTheme.danger.opacity(0.35), lineWidth: 1)
        }
    }

    // MARK: - Nome & Emoji Card

    private var identitySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Nome")
                    .font(PixelTheme.uiFont(size: 11, weight: .semibold))
                    .foregroundStyle(PixelTheme.popoverMuted)
                    .accessibilityAddTraits(.isHeader)

                HStack(spacing: 6) {
                    ZStack {
                        RoundedRectangle(cornerRadius: PixelTheme.compactRadius, style: .continuous)
                            .fill(PixelTheme.paper)

                        if let emoji = model.displayEmoji {
                            Text(emoji)
                                .font(.system(size: 15))
                        } else {
                            Image(systemName: "doc.text")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(PixelTheme.muted)
                        }
                    }
                    .frame(width: 30, height: 30)
                    .overlay {
                        RoundedRectangle(cornerRadius: PixelTheme.compactRadius, style: .continuous)
                            .strokeBorder(PixelTheme.border, lineWidth: 1)
                    }
                    .accessibilityHidden(true)

                    TextField("Sem título", text: $draftTitle)
                        .textFieldStyle(.plain)
                        .focused($focusedField, equals: .title)
                        .font(PixelTheme.uiFont(size: 12.5, weight: .medium))
                        .foregroundStyle(PixelTheme.ink)
                        .padding(.horizontal, 8)
                        .frame(height: 30)
                        .background(
                            RoundedRectangle(cornerRadius: PixelTheme.controlRadius, style: .continuous)
                                .fill(PixelTheme.paper)
                        )
                        .overlay {
                            RoundedRectangle(cornerRadius: PixelTheme.controlRadius, style: .continuous)
                                .strokeBorder(
                                    focusedField == .title ? PixelTheme.accentBorder : PixelTheme.borderStrong,
                                    lineWidth: focusedField == .title ? 1.5 : 1
                                )
                        }
                        .onSubmit {
                            commitRename()
                        }
                        .onExitCommand(perform: onClose)
                        .accessibilityLabel("Nome da nota")

                    Button(action: commitRename) {
                        Text("Salvar")
                            .font(PixelTheme.uiFont(size: 11.5, weight: .semibold))
                            .foregroundStyle(hasUnsavedTitleChanges ? .white : PixelTheme.muted)
                            .padding(.horizontal, 10)
                            .frame(height: 30)
                            .background(
                                RoundedRectangle(cornerRadius: PixelTheme.controlRadius, style: .continuous)
                                    .fill(hasUnsavedTitleChanges ? PixelTheme.accent : PixelTheme.paper)
                            )
                            .overlay {
                                RoundedRectangle(cornerRadius: PixelTheme.controlRadius, style: .continuous)
                                    .strokeBorder(
                                        hasUnsavedTitleChanges ? PixelTheme.accentDeep : PixelTheme.border,
                                        lineWidth: 1
                                    )
                            }
                    }
                    .buttonStyle(.plain)
                    .disabled(!hasUnsavedTitleChanges)
                    .accessibilityLabel("Salvar nome da nota")
                }
            }

            VStack(alignment: .leading, spacing: 7) {
                HStack(spacing: 6) {
                    Text("Emoji")
                        .font(PixelTheme.uiFont(size: 11, weight: .semibold))
                        .foregroundStyle(PixelTheme.popoverMuted)
                        .accessibilityAddTraits(.isHeader)

                    Spacer(minLength: 4)

                    if model.displayEmoji != nil {
                        Button(action: { applyEmoji(nil) }) {
                            Text("Remover emoji")
                                .font(PixelTheme.uiFont(size: 11, weight: .medium))
                                .foregroundStyle(PixelTheme.danger)
                                .padding(.horizontal, 7)
                                .padding(.vertical, 3)
                                .background(
                                    RoundedRectangle(cornerRadius: PixelTheme.compactRadius, style: .continuous)
                                        .fill(PixelTheme.dangerSoft)
                                )
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Remover emoji")
                    }
                }

                LazyVGrid(
                    columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 6),
                    spacing: 6
                ) {
                    ForEach(NoteActionMenuModel.curatedEmojis, id: \.self) { emoji in
                        let isSelected = (model.displayEmoji == emoji)
                        EmojiChoiceButton(emoji: emoji, isSelected: isSelected) {
                            applyEmoji(emoji)
                        }
                    }
                }

                HStack(spacing: 6) {
                    TextField("Outro emoji…", text: $customEmojiInput)
                        .textFieldStyle(.plain)
                        .focused($focusedField, equals: .customEmoji)
                        .font(PixelTheme.uiFont(size: 12))
                        .foregroundStyle(PixelTheme.ink)
                        .padding(.horizontal, 8)
                        .frame(height: 28)
                        .background(
                            RoundedRectangle(cornerRadius: PixelTheme.compactRadius, style: .continuous)
                                .fill(PixelTheme.paper)
                        )
                        .overlay {
                            RoundedRectangle(cornerRadius: PixelTheme.compactRadius, style: .continuous)
                                .strokeBorder(
                                    focusedField == .customEmoji ? PixelTheme.accentBorder : PixelTheme.border,
                                    lineWidth: focusedField == .customEmoji ? 1.5 : 1
                                )
                        }
                        .onSubmit {
                            commitCustomEmoji()
                        }
                        .onExitCommand(perform: onClose)
                        .accessibilityLabel("Emoji personalizado")

                    Button(action: commitCustomEmoji) {
                        Text("Usar")
                            .font(PixelTheme.uiFont(size: 11.5, weight: .semibold))
                            .foregroundStyle(hasValidCustomEmoji ? PixelTheme.accentDeep : PixelTheme.muted)
                            .padding(.horizontal, 10)
                            .frame(height: 28)
                            .background(
                                RoundedRectangle(cornerRadius: PixelTheme.compactRadius, style: .continuous)
                                    .fill(hasValidCustomEmoji ? PixelTheme.accentSoft : PixelTheme.paper)
                            )
                            .overlay {
                                RoundedRectangle(cornerRadius: PixelTheme.compactRadius, style: .continuous)
                                    .strokeBorder(
                                        hasValidCustomEmoji ? PixelTheme.accentBorder : PixelTheme.border,
                                        lineWidth: 1
                                    )
                            }
                    }
                    .buttonStyle(.plain)
                    .disabled(!hasValidCustomEmoji)
                    .accessibilityLabel("Aplicar emoji personalizado")
                }
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: PixelTheme.controlRadius + 2, style: .continuous)
                .fill(PixelTheme.surface)
        )
        .overlay {
            RoundedRectangle(cornerRadius: PixelTheme.controlRadius + 2, style: .continuous)
                .strokeBorder(PixelTheme.border, lineWidth: 1)
        }
    }

    // MARK: - Capa Section

    private var coverSection: some View {
        VStack(alignment: .leading, spacing: 3) {
            MenuActionButton(
                title: model.coverActionTitle,
                systemImage: model.hasCustomCover ? "photo.badge.arrow.down" : "photo",
                isDestructive: false
            ) {
                onChooseCover()
            }

            if model.showsRemoveCoverAction {
                MenuActionButton(
                    title: "Remover capa",
                    systemImage: "photo.badge.minus",
                    isDestructive: false
                ) {
                    onRemoveCover()
                }
            }
        }
    }

    // MARK: - Additional Actions (Export & Move)

    private var additionalActionsSection: some View {
        VStack(alignment: .leading, spacing: 3) {
            MenuActionButton(
                title: "Exportar como PDF…",
                systemImage: "square.and.arrow.up",
                isDestructive: false
            ) {
                onExportPDF()
            }

            moveDisclosureButton

            if isMoveSectionExpanded {
                moveDestinationsList
            }
        }
    }

    private var moveDisclosureButton: some View {
        Button {
            if reduceMotion {
                isMoveSectionExpanded.toggle()
            } else {
                withAnimation(.easeOut(duration: 0.15)) {
                    isMoveSectionExpanded.toggle()
                }
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "folder")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(PixelTheme.inkSecondary)
                    .frame(width: 16)

                Text("Mover para…")
                    .font(PixelTheme.uiFont(size: 12.5, weight: .medium))
                    .foregroundStyle(PixelTheme.ink)

                Spacer(minLength: 4)

                Image(systemName: isMoveSectionExpanded ? "chevron.down" : "chevron.right")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(PixelTheme.muted)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: PixelTheme.compactRadius, style: .continuous)
                    .fill(isMoveSectionExpanded ? PixelTheme.surface : Color.clear)
            )
            .contentShape(RoundedRectangle(cornerRadius: PixelTheme.compactRadius, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Mover para")
        .accessibilityValue(isMoveSectionExpanded ? "Expandido" : "Recolhido")
    }

    private var moveDestinationsList: some View {
        let rows = VStack(alignment: .leading, spacing: 2) {
            ForEach(model.moveDestinations) { destination in
                MoveDestinationRowButton(destination: destination) {
                    onMoveToNotebook(destination.notebookID)
                    onClose()
                }
            }
        }
        .padding(6)

        return Group {
            if model.moveDestinations.count > 6 {
                ScrollView {
                    rows
                }
                .frame(maxHeight: 156)
            } else {
                rows
            }
        }
        .background(
            RoundedRectangle(cornerRadius: PixelTheme.controlRadius, style: .continuous)
                .fill(PixelTheme.surface)
        )
        .overlay {
            RoundedRectangle(cornerRadius: PixelTheme.controlRadius, style: .continuous)
                .strokeBorder(PixelTheme.border, lineWidth: 1)
        }
        .padding(.top, 2)
    }

    private var sectionDivider: some View {
        Rectangle()
            .fill(PixelTheme.border)
            .frame(height: 1)
    }

    // MARK: - Actions

    private func commitRename() {
        inlineErrorMessage = nil
        do {
            try onRename(draftTitle)
            onClose()
        } catch {
            inlineErrorMessage = error.localizedDescription
        }
    }

    private func applyEmoji(_ raw: String?) {
        inlineErrorMessage = nil
        do {
            try onSetEmoji(raw)
        } catch {
            inlineErrorMessage = error.localizedDescription
        }
    }

    private func commitCustomEmoji() {
        guard let normalized = NoteViewModel.normalizedEmoji(customEmojiInput) else { return }
        inlineErrorMessage = nil
        do {
            try onSetEmoji(normalized)
            customEmojiInput = ""
        } catch {
            inlineErrorMessage = error.localizedDescription
        }
    }
}

// MARK: - Modular Menu Subcomponents

private struct MenuActionButton: View {
    let title: String
    let systemImage: String
    let isDestructive: Bool
    let action: () -> Void

    @State private var isHovered = false

    private var foregroundColor: Color {
        isDestructive ? PixelTheme.danger : PixelTheme.ink
    }

    private var iconColor: Color {
        isDestructive ? PixelTheme.danger : PixelTheme.inkSecondary
    }

    private var hoverBackground: Color {
        isDestructive ? PixelTheme.dangerSoft : PixelTheme.surface
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: systemImage)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(iconColor)
                    .frame(width: 16)

                Text(title)
                    .font(PixelTheme.uiFont(size: 12.5, weight: .medium))
                    .foregroundStyle(foregroundColor)
                    .lineLimit(1)

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: PixelTheme.compactRadius, style: .continuous)
                    .fill(isHovered ? hoverBackground : Color.clear)
            )
            .contentShape(RoundedRectangle(cornerRadius: PixelTheme.compactRadius, style: .continuous))
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}

private struct EmojiChoiceButton: View {
    let emoji: String
    let isSelected: Bool
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            Text(emoji)
                .font(.system(size: 15))
                .frame(maxWidth: .infinity)
                .frame(height: 32)
                .background(
                    RoundedRectangle(cornerRadius: PixelTheme.compactRadius, style: .continuous)
                        .fill(
                            isSelected
                                ? PixelTheme.accentSoft
                                : (isHovered ? PixelTheme.paper : PixelTheme.paper.opacity(0.75))
                        )
                )
                .overlay {
                    RoundedRectangle(cornerRadius: PixelTheme.compactRadius, style: .continuous)
                        .strokeBorder(
                            isSelected
                                ? PixelTheme.accentBorder
                                : (isHovered ? PixelTheme.borderStrong : PixelTheme.border),
                            lineWidth: isSelected ? 1.5 : 1
                        )
                }
                .contentShape(RoundedRectangle(cornerRadius: PixelTheme.compactRadius, style: .continuous))
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .accessibilityLabel("Emoji \(emoji)")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

private struct MoveDestinationRowButton: View {
    let destination: NoteActionMenuDestination
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if destination.notebookID == nil {
                    Image(systemName: "tray")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(destination.isDisabled ? PixelTheme.muted : PixelTheme.inkSecondary)
                        .frame(width: 12)
                } else {
                    Circle()
                        .fill(destination.swatchIndex.map { PixelTheme.notebookSwatches[$0].dot } ?? PixelTheme.muted)
                        .frame(width: 8, height: 8)
                        .frame(width: 12)
                }

                Text(destination.title)
                    .font(PixelTheme.uiFont(size: 12, weight: destination.isCurrent ? .semibold : .medium))
                    .foregroundStyle(destination.isDisabled ? PixelTheme.muted : PixelTheme.ink)
                    .lineLimit(1)

                Spacer(minLength: 4)

                if destination.isCurrent {
                    Image(systemName: "checkmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(PixelTheme.accent)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: PixelTheme.compactRadius - 1, style: .continuous)
                    .fill(isHovered && !destination.isDisabled ? PixelTheme.paper : Color.clear)
            )
            .contentShape(RoundedRectangle(cornerRadius: PixelTheme.compactRadius - 1, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(destination.isDisabled)
        .onHover { isHovered = $0 }
        .accessibilityLabel(destination.isCurrent ? "\(destination.title), atual" : destination.title)
        .accessibilityAddTraits(destination.isCurrent ? .isSelected : [])
    }
}
