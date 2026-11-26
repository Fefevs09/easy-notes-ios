import Foundation
import Combine

enum TutorialStep: String, CaseIterable {
    case notebooks
    case search
    case newNote
    case editorTools

    var number: Int {
        Self.allCases.firstIndex(of: self)! + 1
    }

    var next: Self? {
        Self.allCases.dropFirst(number).first
    }
}

final class WelcomeState: ObservableObject {
    static let shared = WelcomeState()

    private static let preferenceKey = "easyNotes.welcome.status"
    private static let tutorialKey = "easyNotes.tutorial.step"

    private enum Status: String {
        case pending
        case completed
    }

    private let defaults: UserDefaults
    @Published private(set) var showsWelcome = false
    @Published private(set) var tutorialStep: TutorialStep?

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    // Called before Core Data can create a SQLite file for this installation.
    func prepare(hasExistingInstallation: @autoclosure () -> Bool) {
        let savedStatus = defaults.string(forKey: Self.preferenceKey).flatMap(Status.init(rawValue:))
        let status = savedStatus ?? (hasExistingInstallation() ? .completed : .pending)
        if savedStatus == nil {
            defaults.set(status.rawValue, forKey: Self.preferenceKey)
        }
        showsWelcome = status == .pending
        tutorialStep = status == .completed
            ? defaults.string(forKey: Self.tutorialKey).flatMap(TutorialStep.init(rawValue:))
            : nil
    }

    func complete() {
        guard showsWelcome else { return }
        saveTutorialStep(.notebooks)
        defaults.set(Status.completed.rawValue, forKey: Self.preferenceKey)
        showsWelcome = false
    }

    func advanceTutorial(from step: TutorialStep, hasOpenNote: Bool) {
        guard !showsWelcome, tutorialStep == step else { return }
        guard step != .editorTools || hasOpenNote else { return }
        saveTutorialStep(step.next)
    }

    func skipTutorial(from step: TutorialStep) {
        guard !showsWelcome, tutorialStep == step else { return }
        saveTutorialStep(nil)
    }

    private func saveTutorialStep(_ step: TutorialStep?) {
        defaults.set(step?.rawValue ?? "finished", forKey: Self.tutorialKey)
        tutorialStep = step
    }
}
