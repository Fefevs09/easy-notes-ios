import Combine
import CoreData
import Foundation
import XCTest

final class WelcomeStateTests: XCTestCase {
    func testFreshInstallKeepsWelcomeAcrossRelaunchUntilCompletion() throws {
        try withInstallation { directory, defaults in
            let firstLaunch = WelcomeState(defaults: defaults)
            let noteCount: Int
            do {
                let stack = CoreDataStack(defaults: defaults, welcome: firstLaunch, defaultStoreDirectory: directory)
                XCTAssertTrue(firstLaunch.showsWelcome)
                XCTAssertNil(firstLaunch.tutorialStep)
                let viewModel = NoteViewModel(context: stack.viewContext)
                XCTAssertFalse(viewModel.notebooks.isEmpty)
                noteCount = try stack.viewContext.count(for: NSFetchRequest<Note>(entityName: "Note"))
            }

            let secondLaunch = WelcomeState(defaults: defaults)
            do {
                let stack = CoreDataStack(defaults: defaults, welcome: secondLaunch, defaultStoreDirectory: directory)
                XCTAssertTrue(FileManager.default.fileExists(atPath: try XCTUnwrap(stack.currentStoreURL).path))
                XCTAssertTrue(secondLaunch.showsWelcome)
                secondLaunch.complete()
                secondLaunch.complete()
                XCTAssertFalse(secondLaunch.showsWelcome)
                XCTAssertEqual(try stack.viewContext.count(for: NSFetchRequest<Note>(entityName: "Note")), noteCount)
            }

            AppSettingsStore(defaults: defaults).resetAll()
            let completedLaunch = WelcomeState(defaults: defaults)
            _ = CoreDataStack(defaults: defaults, welcome: completedLaunch, defaultStoreDirectory: directory)
            XCTAssertFalse(completedLaunch.showsWelcome)
            XCTAssertEqual(completedLaunch.tutorialStep, .notebooks)
        }
    }

    func testTutorialResumesAtSavedStepAndWaitsForAnOpenNoteToFinish() throws {
        try withInstallation { _, defaults in
            let firstLaunch = WelcomeState(defaults: defaults)
            firstLaunch.prepare(hasExistingInstallation: false)
            firstLaunch.complete()
            firstLaunch.advanceTutorial(from: .notebooks, hasOpenNote: false)
            firstLaunch.complete()
            firstLaunch.advanceTutorial(from: .notebooks, hasOpenNote: false)
            XCTAssertEqual(firstLaunch.tutorialStep, .search)

            let resumed = WelcomeState(defaults: defaults)
            resumed.prepare(hasExistingInstallation: true)
            XCTAssertEqual(resumed.tutorialStep, .search)
            resumed.advanceTutorial(from: .search, hasOpenNote: false)
            XCTAssertEqual(resumed.tutorialStep, .newNote)
            resumed.advanceTutorial(from: .newNote, hasOpenNote: false)
            resumed.advanceTutorial(from: .editorTools, hasOpenNote: false)
            XCTAssertEqual(resumed.tutorialStep, .editorTools)

            let editorLaunch = WelcomeState(defaults: defaults)
            editorLaunch.prepare(hasExistingInstallation: true)
            XCTAssertEqual(editorLaunch.tutorialStep, .editorTools)
            editorLaunch.advanceTutorial(from: .editorTools, hasOpenNote: true)
            XCTAssertNil(editorLaunch.tutorialStep)

            let finished = WelcomeState(defaults: defaults)
            finished.prepare(hasExistingInstallation: true)
            XCTAssertNil(finished.tutorialStep)
        }
    }

    func testSkippingTutorialPersistsAcrossRelaunch() throws {
        try withInstallation { _, defaults in
            let welcome = WelcomeState(defaults: defaults)
            welcome.prepare(hasExistingInstallation: false)
            welcome.complete()
            welcome.advanceTutorial(from: .notebooks, hasOpenNote: false)
            welcome.skipTutorial(from: .notebooks)
            XCTAssertEqual(welcome.tutorialStep, .search)
            welcome.skipTutorial(from: .search)
            XCTAssertNil(welcome.tutorialStep)

            let relaunched = WelcomeState(defaults: defaults)
            relaunched.prepare(hasExistingInstallation: true)
            XCTAssertFalse(relaunched.showsWelcome)
            XCTAssertNil(relaunched.tutorialStep)
        }
    }

    func testInstallThatAlreadyCompletedWelcomeDoesNotStartTutorial() throws {
        try withInstallation { _, defaults in
            defaults.set("completed", forKey: "easyNotes.welcome.status")
            let welcome = WelcomeState(defaults: defaults)
            welcome.prepare(hasExistingInstallation: true)
            welcome.complete()
            XCTAssertFalse(welcome.showsWelcome)
            XCTAssertNil(welcome.tutorialStep)
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
            XCTAssertNil(welcome.tutorialStep)
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

    func testConfiguredDirectoryWithoutSQLiteSkipsWelcome() throws {
        try withInstallation { directory, defaults in
            let custom = directory.appendingPathComponent("Custom", isDirectory: true)
            try FileManager.default.createDirectory(at: custom, withIntermediateDirectories: true)
            defaults.set(custom.path, forKey: AppSettingsStore.Keys.customStoragePath)
            let welcome = WelcomeState(defaults: defaults)
            let stack = CoreDataStack(defaults: defaults, welcome: welcome, defaultStoreDirectory: directory)
            XCTAssertFalse(welcome.showsWelcome)
            XCTAssertFalse(stack.didFallbackToDefaultStore)
            XCTAssertEqual(stack.currentStoreURL?.path, custom.appendingPathComponent(CoreDataStack.storeFileName).path)
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

    @MainActor
    func testNewNoteStepAdvancesOnlyThroughActiveNewNoteFlow() throws {
        try withInstallation { _, defaults in
            let welcome = WelcomeState(defaults: defaults)
            welcome.prepare(hasExistingInstallation: false)
            welcome.complete()
            welcome.advanceTutorial(from: .notebooks, hasOpenNote: false)
            welcome.advanceTutorial(from: .search, hasOpenNote: false)
            XCTAssertEqual(welcome.tutorialStep, .newNote)

            let (model, _) = TestSupport.makeInMemoryViewModel()
            let existingNote = try XCTUnwrap(model.notes.first)
            let session = TutorialSession()
            session.setVisible(.newNote, true)

            // Opening an existing note must not consume the .newNote step.
            model.selectedNote = existingNote
            session.completeNewNoteCreation(succeeded: true, in: welcome, hasOpenNote: model.selectedNote != nil)
            XCTAssertEqual(welcome.tutorialStep, .newNote)
            model.selectedNote = nil

            // Creating a note while the anchor is out of view must not advance.
            session.setVisible(.newNote, false)
            session.beginNewNoteCreation(
                activeStep: session.activeAnchor(for: welcome.tutorialStep, appearsActive: true, hasOpenNote: false, isInTrash: false),
                tutorialStep: welcome.tutorialStep,
                appearsActive: true,
                hasOpenNote: false,
                isInTrash: false
            )
            XCTAssertTrue(NewNoteDraft(title: "Fora de vista").create(in: model))
            session.completeNewNoteCreation(succeeded: true, in: welcome, hasOpenNote: model.selectedNote != nil)
            XCTAssertEqual(welcome.tutorialStep, .newNote)
            model.selectedNote = nil

            // Creating a note while the tutorial is paused must not advance.
            session.setVisible(.newNote, true)
            let escapeActive = session.activeAnchor(for: welcome.tutorialStep, appearsActive: true, hasOpenNote: false, isInTrash: false)
            session.pause(.newNote, activeStep: escapeActive, restoreFocus: true, hasOpenNote: false, isInTrash: false) { $0() }
            session.beginNewNoteCreation(
                activeStep: session.activeAnchor(for: welcome.tutorialStep, appearsActive: true, hasOpenNote: false, isInTrash: false),
                tutorialStep: welcome.tutorialStep,
                appearsActive: true,
                hasOpenNote: false,
                isInTrash: false,
                clickEvent: TutorialClickEvent(windowNumber: 1, location: CGPoint(x: 400, y: 500), timestamp: 10)
            )
            XCTAssertTrue(NewNoteDraft(title: "Pausada").create(in: model))
            session.completeNewNoteCreation(succeeded: true, in: welcome, hasOpenNote: model.selectedNote != nil)
            XCTAssertEqual(welcome.tutorialStep, .newNote)
            model.selectedNote = nil

            // Resuming and clicking Nova nota (including transient mouseDown dismissal) arms and advances on creation.
            session.resume(step: .newNote, hasOpenNote: false, isInTrash: false)
            let clickDown = TutorialClickEvent(windowNumber: 1, location: CGPoint(x: 400, y: 500), timestamp: 20.0)
            let clickUp = TutorialClickEvent(windowNumber: 1, location: CGPoint(x: 401, y: 501), timestamp: 20.1)
            session.pause(
                .newNote,
                activeStep: session.activeAnchor(for: welcome.tutorialStep, appearsActive: true, hasOpenNote: false, isInTrash: false),
                restoreFocus: false,
                hasOpenNote: false,
                isInTrash: false,
                externalClick: clickDown
            )
            session.beginNewNoteCreation(
                activeStep: session.activeAnchor(for: welcome.tutorialStep, appearsActive: true, hasOpenNote: false, isInTrash: false),
                tutorialStep: welcome.tutorialStep,
                appearsActive: true,
                hasOpenNote: false,
                isInTrash: false,
                clickEvent: clickUp
            )
            XCTAssertTrue(session.armedNewNoteAdvance)

            // Cancelling the sheet disarms without advancing.
            session.cancelNewNoteCreation()
            XCTAssertFalse(session.armedNewNoteAdvance)
            XCTAssertEqual(welcome.tutorialStep, .newNote)

            // Active creation via NewNoteDraft advances to .editorTools.
            session.resume(step: .newNote, hasOpenNote: false, isInTrash: false)
            session.beginNewNoteCreation(
                activeStep: session.activeAnchor(for: welcome.tutorialStep, appearsActive: true, hasOpenNote: false, isInTrash: false),
                tutorialStep: welcome.tutorialStep,
                appearsActive: true,
                hasOpenNote: false,
                isInTrash: false
            )
            XCTAssertTrue(NewNoteDraft(title: "Criada no tutorial").create(in: model))
            session.completeNewNoteCreation(succeeded: true, in: welcome, hasOpenNote: model.selectedNote != nil)
            XCTAssertEqual(welcome.tutorialStep, .editorTools)
        }
    }

    @MainActor
    func testTipFocusRequestedOnlyOnExplicitResumeOrTipAdvance() throws {
        try withInstallation { _, defaults in
            let welcome = WelcomeState(defaults: defaults)
            welcome.prepare(hasExistingInstallation: false)
            welcome.complete()

            let session = TutorialSession()
            session.setVisible(.notebooks, true)
            session.setVisible(.search, true)
            session.setVisible(.newNote, true)

            // Automatic presentation does not steal focus.
            XCTAssertFalse(session.consumeTipFocusRequest(for: .notebooks))

            // Advancing from inside the tip transfers focus to the next available tip.
            session.advance(from: .notebooks, in: welcome, fromTip: true, appearsActive: true, hasOpenNote: false, isInTrash: false)
            XCTAssertEqual(welcome.tutorialStep, .search)
            XCTAssertTrue(session.consumeTipFocusRequest(for: .search))
            XCTAssertFalse(session.consumeTipFocusRequest(for: .search))

            // Advancing from footer does not steal tip focus.
            session.advance(from: .search, in: welcome, fromTip: false, appearsActive: true, hasOpenNote: false, isInTrash: false)
            XCTAssertEqual(welcome.tutorialStep, .newNote)
            XCTAssertFalse(session.consumeTipFocusRequest(for: .newNote))

            // Pausing and resuming explicitly transfers focus back to the tip.
            let active = session.activeAnchor(for: welcome.tutorialStep, appearsActive: true, hasOpenNote: false, isInTrash: false)
            session.pause(.newNote, activeStep: active, restoreFocus: true, hasOpenNote: false, isInTrash: false) { $0() }
            session.resume(step: .newNote, hasOpenNote: false, isInTrash: false)
            XCTAssertTrue(session.consumeTipFocusRequest(for: .newNote))

            // Advancing from .newNote when no note is open does not leave a pending focus request for .editorTools.
            session.advance(from: .newNote, in: welcome, fromTip: true, appearsActive: true, hasOpenNote: false, isInTrash: false)
            XCTAssertEqual(welcome.tutorialStep, .editorTools)
            XCTAssertFalse(session.consumeTipFocusRequest(for: .editorTools))
        }
    }

    @MainActor
    func testEscapeRestoresAnchorFocusWithFallbackAndExternalClickPreservesFocus() throws {
        let session = TutorialSession()
        session.setVisible(.search, true)

        var anchorRestoredCount = 0
        session.setFocusRestorer(.search) {
            anchorRestoredCount += 1
        }

        // Escape restores focus to the anchor when available and does not focus the footer button.
        session.pause(
            .search,
            activeStep: .search,
            restoreFocus: true,
            hasOpenNote: false,
            isInTrash: false
        ) { $0() }
        XCTAssertEqual(session.pausedStep, .search)
        XCTAssertEqual(anchorRestoredCount, 1)
        XCTAssertFalse(session.focusResume)

        // External click pauses without touching anchor or footer focus.
        session.resume(step: .search, hasOpenNote: false, isInTrash: false)
        session.pause(
            .search,
            activeStep: .search,
            restoreFocus: false,
            hasOpenNote: false,
            isInTrash: false,
            externalClick: TutorialClickEvent(windowNumber: 1, location: CGPoint(x: 10, y: 10), timestamp: 1)
        ) { $0() }
        XCTAssertEqual(session.pausedStep, .search)
        XCTAssertEqual(anchorRestoredCount, 1)
        XCTAssertFalse(session.focusResume)

        // Escape falls back to Retomar tutorial when the anchor is available without a restorer.
        session.resume(step: .search, hasOpenNote: false, isInTrash: false)
        session.setFocusRestorer(.search, nil)
        session.pause(
            .search,
            activeStep: .search,
            restoreFocus: true,
            hasOpenNote: false,
            isInTrash: false
        ) { $0() }
        XCTAssertEqual(anchorRestoredCount, 1)
        XCTAssertEqual(session.footerState(for: .search, hasOpenNote: false, isInTrash: false), .paused)
        XCTAssertTrue(session.focusResume)

        // When the anchor disappears, footer switches to unavailable and does not keep a stale focusResume.
        session.setVisible(.search, false)
        if case .unavailable = session.footerState(for: .search, hasOpenNote: false, isInTrash: false) {
            XCTAssertFalse(session.focusResume)
        } else {
            XCTFail("Expected unavailable footer state when anchor disappears")
        }

        // Escape when the anchor disappears during dismissal does not arm focusResume.
        session.setVisible(.search, true)
        session.resume(step: .search, hasOpenNote: false, isInTrash: false)
        session.pause(
            .search,
            activeStep: .search,
            restoreFocus: true,
            hasOpenNote: false,
            isInTrash: false
        ) { restore in
            session.setVisible(.search, false)
            restore()
        }
        XCTAssertFalse(session.focusResume)

        // Losing window activity clears any pending tip focus request.
        session.setVisible(.search, true)
        session.resume(step: .search, hasOpenNote: false, isInTrash: false)
        session.clearPendingTipFocus()
        XCTAssertFalse(session.consumeTipFocusRequest(for: .search))
    }

    @MainActor
    func testFooterAdaptsWhenAnchorIsUnavailableWithoutOfferingAdvance() {
        let session = TutorialSession()

        // Sidebar collapsed / notebooks hidden.
        if case .unavailable(let message) = session.footerState(for: .notebooks, hasOpenNote: false, isInTrash: false) {
            XCTAssertTrue(message.contains("barra lateral"))
        } else {
            XCTFail("Expected unavailable footer state for hidden notebooks")
        }

        // Search scrolled out of view.
        if case .unavailable(let message) = session.footerState(for: .search, hasOpenNote: false, isInTrash: false) {
            XCTAssertTrue(message.contains("busca"))
        } else {
            XCTFail("Expected unavailable footer state for hidden search")
        }

        // New note in Trash removes the anchor and instructs leaving Trash.
        session.setVisible(.newNote, true)
        XCTAssertNil(session.activeAnchor(for: .newNote, appearsActive: true, hasOpenNote: false, isInTrash: true))
        if case .unavailable(let message) = session.footerState(for: .newNote, hasOpenNote: false, isInTrash: true) {
            XCTAssertTrue(message.contains("Lixeira"))
        } else {
            XCTFail("Expected unavailable footer state in Trash")
        }

        // Leaving Trash restores the active state.
        XCTAssertEqual(
            session.footerState(for: .newNote, hasOpenNote: false, isInTrash: false),
            .active(
                message: "Use Nova nota para escolher o papel e abrir o editor.",
                actionTitle: "Avançar"
            )
        )

        // Viewing an existing note during .newNote guides back to library.
        if case .unavailable(let message) = session.footerState(for: .newNote, hasOpenNote: true, isInTrash: false) {
            XCTAssertTrue(message.contains("biblioteca"))
        } else {
            XCTFail("Expected unavailable footer state when a note is open on .newNote")
        }

        // Editor tools without open note guides opening or creating a note.
        if case .unavailable(let message) = session.footerState(for: .editorTools, hasOpenNote: false, isInTrash: false) {
            XCTAssertTrue(message.contains("nota"))
        } else {
            XCTFail("Expected unavailable footer state for editorTools without open note")
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
