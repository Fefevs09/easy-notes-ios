import Foundation
import Combine

final class WelcomeState: ObservableObject {
    static let shared = WelcomeState()

    private static let preferenceKey = "easyNotes.welcome.status"

    private enum Status: String {
        case pending
        case completed
    }

    private let defaults: UserDefaults
    @Published private(set) var showsWelcome = false

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
    }

    func complete() {
        guard showsWelcome else { return }
        defaults.set(Status.completed.rawValue, forKey: Self.preferenceKey)
        showsWelcome = false
    }
}
