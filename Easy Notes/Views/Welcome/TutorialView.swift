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

private struct TutorialContext {
    let activeAnchor: TutorialStep?
    let setVisible: (TutorialStep, Bool) -> Void
    let setTipPresented: (TutorialStep, Bool) -> Void
    let advance: (TutorialStep) -> Void
    let skip: (TutorialStep) -> Void
    let pause: (TutorialStep, _ restoreFocus: Bool) -> Void
}

private extension EnvironmentValues {
    @Entry var tutorial: TutorialContext?
}

struct TutorialWorkspace<Content: View>: View {
    @ObservedObject var welcome: WelcomeState
    let hasOpenNote: Bool
    @ViewBuilder let content: () -> Content

    @Environment(\.appearsActive) private var appearsActive
    @State private var visibleAnchors: Set<TutorialStep> = []
    @State private var presentedStep: TutorialStep?
    @State private var pausedStep: TutorialStep?
    @State private var focusResume = false
    @FocusState private var resumeFocused: Bool
    @AccessibilityFocusState private var resumeAccessibilityFocused: Bool

    private var activeAnchor: TutorialStep? {
        guard appearsActive, let step = welcome.tutorialStep, pausedStep != step else { return nil }
        guard (step == .editorTools) == hasOpenNote, visibleAnchors.contains(step) else { return nil }
        guard presentedStep == nil || presentedStep == step else { return nil }
        return step
    }

    var body: some View {
        VStack(spacing: 0) {
            content()
                .environment(\.tutorial, TutorialContext(
                    activeAnchor: activeAnchor,
                    setVisible: setVisible,
                    setTipPresented: setTipPresented,
                    advance: advance,
                    skip: welcome.skipTutorial,
                    pause: pause
                ))

            if let step = welcome.tutorialStep, presentedStep == nil {
                footer(for: step)
            }
        }
        .onChange(of: hasOpenNote) { _, open in
            if open, welcome.tutorialStep == .newNote {
                advance(.newNote)
            }
        }
    }

    private func footer(for step: TutorialStep) -> some View {
        let waitingForEditor = step == .editorTools && !hasOpenNote

        return HStack(spacing: 12) {
            if waitingForEditor {
                Text("Abra ou crie uma nota para conhecer as ferramentas do editor.")
            } else if pausedStep == step {
                Text("Tutorial pausado")
                Button("Retomar tutorial") { pausedStep = nil }
                    .focusable()
                    .focused($resumeFocused)
                    .accessibilityFocused($resumeAccessibilityFocused)
                    .task {
                        if focusResume {
                            focusResume = false
                            resumeFocused = true
                            resumeAccessibilityFocused = true
                        }
                    }
            } else {
                Text(step.message)
                Button(step.actionTitle) { advance(step) }
            }

            Spacer()
            Button("Pular tutorial") { welcome.skipTutorial(from: step) }
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

    private func setVisible(_ step: TutorialStep, _ isVisible: Bool) {
        if isVisible {
            visibleAnchors.insert(step)
        } else {
            visibleAnchors.remove(step)
        }
    }

    private func advance(_ step: TutorialStep) {
        welcome.advanceTutorial(from: step, hasOpenNote: hasOpenNote)
    }

    private func setTipPresented(_ step: TutorialStep, _ isPresented: Bool) {
        if isPresented {
            presentedStep = step
        } else if presentedStep == step {
            presentedStep = nil
        }
    }

    private func pause(_ step: TutorialStep, restoreFocus: Bool) {
        guard activeAnchor == step else { return }
        pausedStep = step
        focusResume = restoreFocus
    }
}

extension View {
    func tutorialAnchor(_ step: TutorialStep, arrowEdge: Edge = .bottom) -> some View {
        modifier(TutorialAnchor(step: step, arrowEdge: arrowEdge))
    }
}

private struct TutorialAnchor: ViewModifier {
    let step: TutorialStep
    let arrowEdge: Edge
    @Environment(\.tutorial) private var tutorial
    @State private var isReadyToPresent = false

    private var wantsPresentation: Bool { tutorial?.activeAnchor == step }

    func body(content: Content) -> some View {
        content
            .onGeometryChange(for: Bool.self) { proxy in
                guard proxy.size.width > 0, proxy.size.height > 0 else { return false }
                guard let viewport = proxy.bounds(of: .scrollView) else { return true }
                let frame = proxy.frame(in: .scrollView)
                return CGRect(origin: .zero, size: viewport.size)
                    .contains(CGPoint(x: frame.midX, y: frame.midY))
            } action: { visible in
                tutorial?.setVisible(step, visible)
            }
            .onDisappear { tutorial?.setVisible(step, false) }
            .task(id: wantsPresentation) {
                isReadyToPresent = false
                guard wantsPresentation else { return }
                // Let the activating click and any previous popover dismissal finish.
                do {
                    try await Task.sleep(for: .milliseconds(250))
                    isReadyToPresent = true
                } catch {
                    // The step, window or anchor changed before presentation.
                }
            }
            .popover(isPresented: Binding(
                get: { wantsPresentation && isReadyToPresent },
                set: { if !$0 { tutorial?.pause(step, false) } }
            ), arrowEdge: arrowEdge) {
                if let tutorial {
                    TutorialTip(
                        step: step,
                        advance: { tutorial.advance(step) },
                        skip: { tutorial.skip(step) },
                        pause: { tutorial.pause(step, true) }
                    )
                    .presentationBackground(PixelTheme.paper)
                    .onAppear { tutorial.setTipPresented(step, true) }
                    .onDisappear { tutorial.setTipPresented(step, false) }
                }
            }
    }
}

private struct TutorialTip: View {
    let step: TutorialStep
    let advance: () -> Void
    let skip: () -> Void
    let pause: () -> Void

    @FocusState private var advanceFocused: Bool
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
                Spacer()
                Button(step.actionTitle, action: advance)
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
                    .focusable()
                    .focused($advanceFocused)
            }
        }
        .padding(16)
        .frame(width: 320)
        .defaultFocus($advanceFocused, true)
        .onKeyPress(.escape) {
            pause()
            return .handled
        }
        .onExitCommand(perform: pause)
        .task {
            advanceFocused = true
            titleFocused = true
        }
    }
}
