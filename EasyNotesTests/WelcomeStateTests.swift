import Combine
import CoreData
import Foundation
import XCTest

final class WelcomeStateTests: XCTestCase {
    func testFreshInstallKeepsWelcomeAcrossRelaunchUntilCompletion() throws {
        try withInstallation { directory, defaults in
            let firstLaunch = WelcomeState(defaults: defaults)
            do {
                let stack = CoreDataStack(defaults: defaults, welcome: firstLaunch, defaultStoreDirectory: directory)
                XCTAssertTrue(firstLaunch.showsWelcome)
                let viewModel = NoteViewModel(context: stack.viewContext)
                XCTAssertFalse(viewModel.notebooks.isEmpty)
            }

            let secondLaunch = WelcomeState(defaults: defaults)
            do {
                let stack = CoreDataStack(defaults: defaults, welcome: secondLaunch, defaultStoreDirectory: directory)
                XCTAssertTrue(FileManager.default.fileExists(atPath: try XCTUnwrap(stack.currentStoreURL).path))
                XCTAssertTrue(secondLaunch.showsWelcome)
                secondLaunch.complete()
                secondLaunch.complete()
                XCTAssertFalse(secondLaunch.showsWelcome)
            }

            AppSettingsStore(defaults: defaults).resetAll()
            let completedLaunch = WelcomeState(defaults: defaults)
            _ = CoreDataStack(defaults: defaults, welcome: completedLaunch, defaultStoreDirectory: directory)
            XCTAssertFalse(completedLaunch.showsWelcome)
        }
    }

    func testCompletionNotifiesBothWindowObserversOnce() throws {
        try withInstallation { _, defaults in
            let welcome = WelcomeState(defaults: defaults)
            welcome.prepare(hasExistingInstallation: false)
            var firstWindow: [Bool] = []
            var secondWindow: [Bool] = []
            let firstObserver = welcome.$showsWelcome.sink { firstWindow.append($0) }
            let secondObserver = welcome.$showsWelcome.sink { secondWindow.append($0) }

            withExtendedLifetime([firstObserver, secondObserver]) {
                welcome.complete()
                welcome.complete()
                XCTAssertEqual(firstWindow, [true, false])
                XCTAssertEqual(secondWindow, [true, false])
            }
        }
    }

    func testEmptyLegacySQLiteSkipsWelcomeBeforeSeeding() throws {
        try withInstallation { directory, defaults in
            let legacyStore = directory.appendingPathComponent(CoreDataStack.storeFileName)
            _ = try TestSupport.makeSQLiteContainer(at: legacyStore)

            let welcome = WelcomeState(defaults: defaults)
            let stack = CoreDataStack(defaults: defaults, welcome: welcome, defaultStoreDirectory: directory)
            XCTAssertFalse(welcome.showsWelcome)
            XCTAssertEqual(try stack.viewContext.count(for: NSFetchRequest<Note>(entityName: "Note")), 0)
        }
    }

    func testMigratedCustomStoreSkipsWelcomeAndPreservesLibrary() throws {
        try withInstallation { directory, defaults in
            let originalDirectory = directory.appendingPathComponent("Original", isDirectory: true)
            let customDirectory = directory.appendingPathComponent("Custom", isDirectory: true)
            for folder in [originalDirectory, customDirectory] {
                try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            }

            let noteID = UUID()
            let notebookID = UUID()
            let copiedStore: URL
            do {
                let original = CoreDataStack(defaults: defaults, welcome: nil, defaultStoreDirectory: originalDirectory)
                let notebook = NSEntityDescription.insertNewObject(forEntityName: "Notebook", into: original.viewContext) as! Notebook
                notebook.id = notebookID
                notebook.name = "Meu caderno"

                let note = NSEntityDescription.insertNewObject(forEntityName: "Note", into: original.viewContext) as! Note
                note.id = noteID
                note.title = "Nota existente"
                note.content = "Texto existente"
                note.createdAt = Date()
                note.updatedAt = note.createdAt
                note.notebook = notebook
                copiedStore = try original.migrateStoreCopy(to: customDirectory)
            }

            defaults.set(customDirectory.path, forKey: AppSettingsStore.Keys.customStoragePath)
            let welcome = WelcomeState(defaults: defaults)
            let stack = CoreDataStack(defaults: defaults, welcome: welcome, defaultStoreDirectory: directory)
            XCTAssertFalse(welcome.showsWelcome)
            XCTAssertFalse(stack.didFallbackToDefaultStore)
            XCTAssertEqual(stack.currentStoreURL, copiedStore)
            XCTAssertFalse(FileManager.default.fileExists(atPath: directory.appendingPathComponent(CoreDataStack.storeFileName).path))
            XCTAssertTrue(FileManager.default.fileExists(atPath: originalDirectory.appendingPathComponent(CoreDataStack.storeFileName).path))

            let viewModel = NoteViewModel(context: stack.viewContext)
            XCTAssertEqual(viewModel.notebooks.map(\.id), [notebookID])
            let notes = try stack.viewContext.fetch(NSFetchRequest<Note>(entityName: "Note"))
            XCTAssertEqual(notes.map(\.id), [noteID])
            XCTAssertEqual(notes.first?.content, "Texto existente")
            XCTAssertEqual(notes.first?.notebook?.id, notebookID)
        }
    }

    func testUnavailableConfiguredStorageSkipsWelcomeWhenFallingBack() throws {
        try withInstallation { directory, defaults in
            defaults.set(directory.appendingPathComponent("Missing").path, forKey: AppSettingsStore.Keys.customStoragePath)
            let welcome = WelcomeState(defaults: defaults)
            let stack = CoreDataStack(defaults: defaults, welcome: welcome, defaultStoreDirectory: directory)
            XCTAssertTrue(stack.didFallbackToDefaultStore)
            XCTAssertFalse(welcome.showsWelcome)
        }
    }

    private func withInstallation(_ run: (URL, UserDefaults) throws -> Void) throws {
        let suite = "easyNotes.welcome.tests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(suite, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer {
            defaults.removePersistentDomain(forName: suite)
            try? FileManager.default.removeItem(at: directory)
        }
        try run(directory, defaults)
    }
}
