import AppKit
import Combine
import SwiftUI

private extension TutorialStep {
    var title: String {
        switch self {
        case .notebooks: "Cadernos"
        case .search: "Busca"
        case .newNote: "Nova nota"
        case .editorTools: "Ferramentas do editor"
        }
    }

    var message: String {
        switch self {
        case .notebooks: "Organize suas notas por assunto. Use o botão + na seção Seus Cadernos para criar um caderno."
        case .search: "Encontre notas na biblioteca pela busca. Pressione ⌘K para ir direto ao campo."
        case .newNote: "Use Nova nota para escolher o papel e abrir o editor."
        case .editorTools: "Use a barra do editor para alternar entre seleção, caneta, marca-texto, borracha e formas."
        }
    }

    var actionTitle: String {
        self == .editorTools ? "Concluir" : "Avançar"
    }
}

struct TutorialClickEvent: Equatable {
    let windowNumber: Int
    let location: CGPoint
    let timestamp: TimeInterval

    init(windowNumber: Int, location: CGPoint, timestamp: TimeInterval) {
        self.windowNumber = windowNumber
        self.location = location
        self.timestamp = timestamp
    }

    init?(event: NSEvent?) {
        guard let event else { return nil }
        switch event.type {
        case .leftMouseDown, .leftMouseUp, .rightMouseDown, .rightMouseUp, .otherMouseDown, .otherMouseUp:
            self.windowNumber = event.windowNumber
            self.location = event.locationInWindow
            self.timestamp = event.timestamp
        default:
            return nil
        }
    }

    func isSameClick(as other: TutorialClickEvent) -> Bool {
        windowNumber == other.windowNumber
            && abs(timestamp - other.timestamp) < 1.0
            && hypot(location.x - other.location.x, location.y - other.location.y) < 16
    }
}

enum TutorialFooterState: Equatable {
    case unavailable(message: String)
    case paused
    case active(message: String, actionTitle: String)
}

@MainActor
final class TutorialSession: ObservableObject {
    @Published private(set) var visibleAnchors: Set<TutorialStep> = []
    @Published private(set) var pausedStep: TutorialStep?
    @Published private(set) var presentedStep: TutorialStep?
    @Published var focusResume = false

    private(set) var pendingTipFocusStep: TutorialStep?
    private(set) var armedNewNoteAdvance = false

    private var anchorFocusRestorers: [TutorialStep: () -> Void] = [:]
    private var lastExternalClickDismiss: (step: TutorialStep, event: TutorialClickEvent)?

    func isAnchorAvailable(_ step: TutorialStep, hasOpenNote: Bool, isInTrash: Bool) -> Bool {
        guard (step == .editorTools) == hasOpenNote else { return false }
        if step == .newNote && isInTrash { return false }
        return visibleAnchors.contains(step)
    }

    func activeAnchor(
        for step: TutorialStep?,
        appearsActive: Bool,
        hasOpenNote: Bool,
        isInTrash: Bool
    ) -> TutorialStep? {
        guard appearsActive, let step, pausedStep != step else { return nil }
        guard isAnchorAvailable(step, hasOpenNote: hasOpenNote, isInTrash: isInTrash) else { return nil }
        guard presentedStep == nil || presentedStep == step else { return nil }
        return step
    }

    func footerState(for step: TutorialStep, hasOpenNote: Bool, isInTrash: Bool) -> TutorialFooterState {
        guard isAnchorAvailable(step, hasOpenNote: hasOpenNote, isInTrash: isInTrash) else {
            return .unavailable(message: unavailableMessage(for: step, hasOpenNote: hasOpenNote, isInTrash: isInTrash))
        }
        if pausedStep == step {
            return .paused
        }
        return .active(message: step.message, actionTitle: step.actionTitle)
    }

    func setVisible(_ step: TutorialStep, _ isVisible: Bool) {
        if isVisible {
            visibleAnchors.insert(step)
        } else {
            visibleAnchors.remove(step)
            if pendingTipFocusStep == step {
                pendingTipFocusStep = nil
            }
            if pausedStep == step {
                focusResume = false
            }
        }
    }

    func clearPendingTipFocus() {
        pendingTipFocusStep = nil
    }

    func setFocusRestorer(_ step: TutorialStep, _ restorer: (() -> Void)?) {
        if let restorer {
            anchorFocusRestorers[step] = restorer
        } else {
            anchorFocusRestorers.removeValue(forKey: step)
        }
    }

    func setTipPresented(_ step: TutorialStep, _ isPresented: Bool) {
        if isPresented {
            presentedStep = step
        } else if presentedStep == step {
            presentedStep = nil
        }
    }

    func consumeTipFocusRequest(for step: TutorialStep) -> Bool {
        guard pendingTipFocusStep == step else { return false }
        pendingTipFocusStep = nil
        return true
    }

    func resume(step: TutorialStep, hasOpenNote: Bool, isInTrash: Bool) {
        guard pausedStep == step else { return }
        pausedStep = nil
        focusResume = false
        lastExternalClickDismiss = nil
        pendingTipFocusStep = isAnchorAvailable(step, hasOpenNote: hasOpenNote, isInTrash: isInTrash) ? step : nil
    }

    func advance(
        from step: TutorialStep,
        in welcome: WelcomeState,
        fromTip: Bool,
        appearsActive: Bool,
        hasOpenNote: Bool,
        isInTrash: Bool
    ) {
        let nextStep = step.next
        welcome.advanceTutorial(from: step, hasOpenNote: hasOpenNote)
        guard welcome.tutorialStep == nextStep else {
            pendingTipFocusStep = nil
            return
        }
        if pausedStep == step {
            pausedStep = nil
        }
        lastExternalClickDismiss = nil
        if fromTip,
           let nextStep,
           appearsActive,
           isAnchorAvailable(nextStep, hasOpenNote: hasOpenNote, isInTrash: isInTrash) {
            pendingTipFocusStep = nextStep
        } else {
            pendingTipFocusStep = nil
        }
    }

    func skip(from step: TutorialStep, in welcome: WelcomeState) {
        welcome.skipTutorial(from: step)
        pausedStep = nil
        focusResume = false
        pendingTipFocusStep = nil
        armedNewNoteAdvance = false
        lastExternalClickDismiss = nil
    }

    func pause(
        _ step: TutorialStep,
        activeStep: TutorialStep?,
        restoreFocus: Bool,
        hasOpenNote: Bool,
        isInTrash: Bool,
        externalClick: TutorialClickEvent? = nil,
        scheduleFocusRestore: ((@escaping @MainActor () -> Void) -> Void)? = nil
    ) {
        guard activeStep == step else { return }
        pausedStep = step
        pendingTipFocusStep = nil
        guard restoreFocus else {
            focusResume = false
            if let externalClick {
                lastExternalClickDismiss = (step, externalClick)
            } else {
                lastExternalClickDismiss = nil
            }
            return
        }
        lastExternalClickDismiss = nil
        let performRestore: @MainActor () -> Void = { [weak self] in
            guard let self, self.pausedStep == step else { return }
            if self.isAnchorAvailable(step, hasOpenNote: hasOpenNote, isInTrash: isInTrash) {
                if let restoreAnchor = self.anchorFocusRestorers[step] {
                    self.focusResume = false
                    restoreAnchor()
                } else {
                    self.focusResume = true
                }
            } else {
                self.focusResume = false
            }
        }
        if let scheduleFocusRestore {
            scheduleFocusRestore(performRestore)
        } else {
            DispatchQueue.main.async {
                MainActor.assumeIsolated {
                    performRestore()
                }
            }
        }
    }

    func beginNewNoteCreation(
        activeStep: TutorialStep?,
        tutorialStep: TutorialStep?,
        appearsActive: Bool,
        hasOpenNote: Bool,
        isInTrash: Bool,
        clickEvent: TutorialClickEvent? = nil
    ) {
        guard appearsActive,
              tutorialStep == .newNote,
              !hasOpenNote,
              isAnchorAvailable(.newNote, hasOpenNote: false, isInTrash: isInTrash) else {
            armedNewNoteAdvance = false
            return
        }
        if activeStep == .newNote {
            armedNewNoteAdvance = true
        } else if pausedStep == .newNote,
                  let clickEvent,
                  let dismiss = lastExternalClickDismiss,
                  dismiss.step == .newNote,
                  clickEvent.isSameClick(as: dismiss.event) {
            armedNewNoteAdvance = true
        } else {
            armedNewNoteAdvance = false
        }
        lastExternalClickDismiss = nil
    }

    func completeNewNoteCreation(succeeded: Bool, in welcome: WelcomeState, hasOpenNote: Bool) {
        let shouldAdvance = armedNewNoteAdvance
        armedNewNoteAdvance = false
        guard succeeded, shouldAdvance, welcome.tutorialStep == .newNote, hasOpenNote else {
            return
        }
        pausedStep = nil
        pendingTipFocusStep = nil
        welcome.advanceTutorial(from: .newNote, hasOpenNote: true)
    }

    func cancelNewNoteCreation() {
        armedNewNoteAdvance = false
    }

    private func unavailableMessage(for step: TutorialStep, hasOpenNote: Bool, isInTrash: Bool) -> String {
        switch step {
        case .notebooks:
            return hasOpenNote
                ? "Volte à biblioteca e abra a barra lateral para ver os cadernos."
                : "Abra a barra lateral para ver seus cadernos."
        case .search:
            return hasOpenNote
                ? "Volte à biblioteca para usar a busca."
                : "Role até o topo da biblioteca para revelar a busca."
        case .newNote:
            if hasOpenNote {
                return "Volte à biblioteca para usar Nova nota."
            }
            if isInTrash {
                return "Saia da Lixeira para criar uma nova nota."
            }
            return "Role até o topo da biblioteca para revelar Nova nota."
        case .editorTools:
            return hasOpenNote
                ? "Mostre a barra do editor para ver as ferramentas."
                : "Abra ou crie uma nota para conhecer as ferramentas do editor."
        }
    }
}

struct TutorialContext {
    let activeAnchor: TutorialStep?
    let setVisible: (TutorialStep, Bool) -> Void
    let setFocusRestorer: (TutorialStep, (() -> Void)?) -> Void
    let setTipPresented: (TutorialStep, Bool) -> Void
    let consumeTipFocus: (TutorialStep) -> Bool
    let advanceFromTip: (TutorialStep) -> Void
    let skip: (TutorialStep) -> Void
    let pause: (TutorialStep, _ restoreFocus: Bool, _ externalClick: TutorialClickEvent?) -> Void
    let beginNewNoteCreation: () -> Void
    let completeNewNoteCreation: (Bool) -> Void
    let cancelNewNoteCreation: () -> Void
}

extension EnvironmentValues {
    @Entry var tutorial: TutorialContext?
}

struct TutorialWorkspace<Content: View>: View {
    @ObservedObject var welcome: WelcomeState
    let hasOpenNote: Bool
    var isInTrash: Bool = false
    @ViewBuilder let content: () -> Content

    @Environment(\.appearsActive) private var appearsActive
    @StateObject private var session = TutorialSession()
    @FocusState private var resumeFocused: Bool
    @AccessibilityFocusState private var resumeAccessibilityFocused: Bool

    private var activeAnchor: TutorialStep? {
        session.activeAnchor(
            for: welcome.tutorialStep,
            appearsActive: appearsActive,
            hasOpenNote: hasOpenNote,
            isInTrash: isInTrash
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            content()
                .environment(\.tutorial, TutorialContext(
                    activeAnchor: activeAnchor,
                    setVisible: { session.setVisible($0, $1) },
                    setFocusRestorer: { session.setFocusRestorer($0, $1) },
                    setTipPresented: { session.setTipPresented($0, $1) },
                    consumeTipFocus: { session.consumeTipFocusRequest(for: $0) },
                    advanceFromTip: { advance($0, fromTip: true) },
                    skip: { session.skip(from: $0, in: welcome) },
                    pause: pause,
                    beginNewNoteCreation: {
                        session.beginNewNoteCreation(
                            activeStep: activeAnchor,
                            tutorialStep: welcome.tutorialStep,
                            appearsActive: appearsActive,
                            hasOpenNote: hasOpenNote,
                            isInTrash: isInTrash,
                            clickEvent: TutorialClickEvent(event: NSApp.currentEvent)
                        )
                    },
                    completeNewNoteCreation: { succeeded in
                        session.completeNewNoteCreation(
                            succeeded: succeeded,
                            in: welcome,
                            hasOpenNote: hasOpenNote || succeeded
                        )
                    },
                    cancelNewNoteCreation: { session.cancelNewNoteCreation() }
                ))

            if let step = welcome.tutorialStep, session.presentedStep == nil {
                footer(for: step)
            }
        }
        .onChange(of: appearsActive) { _, isActive in
            if !isActive {
                session.clearPendingTipFocus()
            }
        }
    }

    private func footer(for step: TutorialStep) -> some View {
        let state = session.footerState(for: step, hasOpenNote: hasOpenNote, isInTrash: isInTrash)

        return HStack(spacing: 12) {
            switch state {
            case .unavailable(let message):
                Text(message)
            case .paused:
                Text("Tutorial pausado")
                Button("Retomar tutorial") {
                    session.resume(step: step, hasOpenNote: hasOpenNote, isInTrash: isInTrash)
                }
                .focusable()
                .focused($resumeFocused)
                .accessibilityFocused($resumeAccessibilityFocused)
                .task {
                    applyResumeFocusIfNeeded()
                }
                .onChange(of: session.focusResume) { _, _ in
                    applyResumeFocusIfNeeded()
                }
            case .active(let message, let actionTitle):
                Text(message)
                Button(actionTitle) {
                    advance(step, fromTip: false)
                }
            }

            Spacer()
            Button("Pular tutorial") {
                session.skip(from: step, in: welcome)
            }
        }
        .font(PixelTheme.uiFont(size: 13))
        .foregroundStyle(PixelTheme.ink)
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(PixelTheme.paper)
        .overlay(alignment: .top) {
            Rectangle().fill(PixelTheme.border).frame(height: 1)
        }
    }

    private func applyResumeFocusIfNeeded() {
        guard session.focusResume else { return }
        session.focusResume = false
        resumeFocused = true
        resumeAccessibilityFocused = true
    }

    private func advance(_ step: TutorialStep, fromTip: Bool) {
        session.advance(
            from: step,
            in: welcome,
            fromTip: fromTip,
            appearsActive: appearsActive,
            hasOpenNote: hasOpenNote,
            isInTrash: isInTrash
        )
    }

    private func pause(_ step: TutorialStep, restoreFocus: Bool, externalClick: TutorialClickEvent?) {
        session.pause(
            step,
            activeStep: activeAnchor,
            restoreFocus: restoreFocus,
            hasOpenNote: hasOpenNote,
            isInTrash: isInTrash,
            externalClick: externalClick
        )
    }
}

extension View {
    func tutorialAnchor(
        _ step: TutorialStep,
        arrowEdge: Edge = .bottom,
        onRestoreFocus: (() -> Void)? = nil
    ) -> some View {
        modifier(TutorialAnchor(step: step, arrowEdge: arrowEdge, onRestoreFocus: onRestoreFocus))
    }
}

private struct TutorialAnchor: ViewModifier {
    let step: TutorialStep
    let arrowEdge: Edge
    let onRestoreFocus: (() -> Void)?

    @Environment(\.tutorial) private var tutorial
    @State private var isReadyToPresent = false
    @State private var shouldFocusTip = false
    @State private var isGeometryVisible = false
    @State private var isHierarchyHidden = false

    private var wantsPresentation: Bool { tutorial?.activeAnchor == step }

    func body(content: Content) -> some View {
        content
            .onGeometryChange(for: Bool.self) { proxy in
                guard proxy.size.width > 0, proxy.size.height > 0 else { return false }
                let globalFrame = proxy.frame(in: .global)
                guard globalFrame.maxX > 0, globalFrame.maxY > 0 else { return false }
                guard let viewport = proxy.bounds(of: .scrollView) else { return true }
                let frame = proxy.frame(in: .scrollView)
                return CGRect(origin: .zero, size: viewport.size)
                    .contains(CGPoint(x: frame.midX, y: frame.midY))
            } action: { visible in
                isGeometryVisible = visible
                tutorial?.setVisible(step, visible && !isHierarchyHidden)
            }
            .background(AnchorVisibilityProbe { hidden in
                isHierarchyHidden = hidden
                tutorial?.setVisible(step, isGeometryVisible && !hidden)
            })
            .onAppear {
                tutorial?.setFocusRestorer(step, onRestoreFocus)
            }
            .onDisappear {
                tutorial?.setVisible(step, false)
                tutorial?.setFocusRestorer(step, nil)
            }
            .task(id: wantsPresentation) {
                isReadyToPresent = false
                shouldFocusTip = false
                guard wantsPresentation else { return }
                // Let the activating click and any previous popover dismissal finish.
                do {
                    try await Task.sleep(for: .milliseconds(250))
                    shouldFocusTip = tutorial?.consumeTipFocus(step) ?? false
                    isReadyToPresent = true
                } catch {
                    // The step, window or anchor changed before presentation.
                }
            }
            .popover(isPresented: Binding(
                get: { wantsPresentation && isReadyToPresent },
                set: { isPresented in
                    guard !isPresented else { return }
                    let event = NSApp.currentEvent
                    let restoreFocus = isEscapeDismissEvent(event)
                    let clickEvent = restoreFocus ? nil : TutorialClickEvent(event: event)
                    tutorial?.pause(step, restoreFocus, clickEvent)
                }
            ), arrowEdge: arrowEdge) {
                if let tutorial {
                    TutorialTip(
                        step: step,
                        focusOnAppear: shouldFocusTip,
                        advance: { tutorial.advanceFromTip(step) },
                        skip: { tutorial.skip(step) },
                        pause: { tutorial.pause(step, true, nil) }
                    )
                    .presentationBackground(PixelTheme.paper)
                    .onAppear { tutorial.setTipPresented(step, true) }
                    .onDisappear { tutorial.setTipPresented(step, false) }
                }
            }
    }

    private func isEscapeDismissEvent(_ event: NSEvent?) -> Bool {
        guard let event else { return false }
        return event.type == .keyDown && event.keyCode == 53
    }
}

private struct AnchorVisibilityProbe: NSViewRepresentable {
    let onHiddenChange: (Bool) -> Void

    func makeNSView(context: Context) -> VisibilityProbeNSView {
        let view = VisibilityProbeNSView(frame: .zero)
        view.onHiddenChange = onHiddenChange
        return view
    }

    func updateNSView(_ nsView: VisibilityProbeNSView, context: Context) {
        nsView.onHiddenChange = onHiddenChange
    }

    final class VisibilityProbeNSView: NSView {
        var onHiddenChange: ((Bool) -> Void)?
        private var lastReportedHidden: Bool?

        override func hitTest(_ point: NSPoint) -> NSView? { nil }

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            reportHiddenState()
        }

        override func viewDidHide() {
            super.viewDidHide()
            reportHiddenState()
        }

        override func viewDidUnhide() {
            super.viewDidUnhide()
            reportHiddenState()
        }

        private func reportHiddenState() {
            let hidden = window == nil || isHiddenOrHasHiddenAncestor
            guard hidden != lastReportedHidden else { return }
            lastReportedHidden = hidden
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.onHiddenChange?(self.window == nil || self.isHiddenOrHasHiddenAncestor)
            }
        }
    }
}

private struct TutorialTip: View {
    private enum TipAction {
        case skip
        case advance
    }

    let step: TutorialStep
    let focusOnAppear: Bool
    let advance: () -> Void
    let skip: () -> Void
    let pause: () -> Void

    @FocusState private var focusedAction: TipAction?
    @AccessibilityFocusState private var titleFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("\(step.title) · \(step.number) de \(TutorialStep.allCases.count)")
                .font(PixelTheme.displayFont(size: 15, weight: .semibold))
                .foregroundStyle(PixelTheme.ink)
                .accessibilityAddTraits(.isHeader)
                .accessibilityFocused($titleFocused)

            Text(step.message)
                .font(PixelTheme.uiFont(size: 13))
                .foregroundStyle(PixelTheme.inkSecondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack {
                Button("Pular tutorial", action: skip)
                    .focusable()
                    .focused($focusedAction, equals: .skip)
                    .onKeyPress(.return, phases: .down) { _ in
                        skip()
                        return .handled
                    }
                Spacer()
                Button(step.actionTitle, action: advance)
                    .buttonStyle(.borderedProminent)
                    .focusable()
                    .focused($focusedAction, equals: .advance)
                    .onKeyPress(.return, phases: .down) { _ in
                        advance()
                        return .handled
                    }
            }
        }
        .padding(16)
        .frame(width: 320)
        .onKeyPress(.escape) {
            pause()
            return .handled
        }
        .onExitCommand(perform: pause)
        .task {
            guard focusOnAppear else { return }
            focusedAction = .advance
            titleFocused = true
            DispatchQueue.main.async {
                MainActor.assumeIsolated {
                    if focusedAction == nil {
                        focusedAction = .advance
                    }
                }
            }
        }
    }
}
