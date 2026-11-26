import CoreData
import Foundation
import SwiftUI
import XCTest

final class AppSettingsTests: XCTestCase {
    private var suiteName: String!
    private var isolatedDefaults: UserDefaults!

    override func setUp() {
        super.setUp()
        suiteName = "easyNotes.settings.tests.\(UUID().uuidString)"
        isolatedDefaults = UserDefaults(suiteName: suiteName)!
        isolatedDefaults.removePersistentDomain(forName: suiteName)
    }

    override func tearDown() {
        if let suiteName {
            isolatedDefaults?.removePersistentDomain(forName: suiteName)
        }
        isolatedDefaults = nil
        suiteName = nil
        super.tearDown()
    }

    func testPersistenceAndReloadOfAppearanceThemePaperAndExportPreferences() throws {
        let store = AppSettingsStore(defaults: isolatedDefaults)
        XCTAssertEqual(store.appearanceMode, .system)
        XCTAssertNil(store.appearanceMode.preferredColorScheme)
        XCTAssertEqual(store.themePreset, .editorial)
        XCTAssertEqual(store.interfaceContrast, 1.0, accuracy: 0.0001)
        XCTAssertEqual(store.surfaceOpacity, 1.0, accuracy: 0.0001)
        XCTAssertEqual(store.defaultPaperStyle, .none)
        XCTAssertEqual(store.defaultNoteOrientation, .portrait)
        XCTAssertTrue(store.confirmBeforeDeletingNotebook)
        XCTAssertTrue(store.confirmBeforeEmptyingTrash)
        XCTAssertTrue(store.includePaperGridInExport)

        store.appearanceMode = .dark
        store.themePreset = .ocean
        store.interfaceContrast = 1.15
        store.surfaceOpacity = 0.85
        store.defaultPaperStyle = .grid
        store.defaultNoteOrientation = .landscape
        store.confirmBeforeDeletingNotebook = false
        store.confirmBeforeEmptyingTrash = false
        store.defaultPenColorHex = "#1a2b3c"
        store.defaultHighlighterColorHex = "#00ff88"
        store.defaultPenWidth = 5.0
        store.defaultEraserWidth = 28.0
        store.includePaperGridInExport = false

        let exportDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("easy-notes-export-\(UUID().uuidString)", isDirectory: true)
        store.setDefaultExportDirectory(exportDir)

        // Reload from the same isolated UserDefaults suite.
        let reloaded = AppSettingsStore(defaults: isolatedDefaults)
        XCTAssertEqual(reloaded.appearanceMode, .dark)
        XCTAssertEqual(reloaded.appearanceMode.preferredColorScheme, .dark)
        XCTAssertEqual(reloaded.themePreset, .ocean)
        XCTAssertEqual(reloaded.interfaceContrast, 1.15, accuracy: 0.0001)
        XCTAssertEqual(reloaded.surfaceOpacity, 0.85, accuracy: 0.0001)
        XCTAssertEqual(reloaded.defaultPaperStyle, .grid)
        XCTAssertEqual(reloaded.defaultNoteOrientation, .landscape)
        XCTAssertFalse(reloaded.confirmBeforeDeletingNotebook)
        XCTAssertFalse(reloaded.confirmBeforeEmptyingTrash)
        XCTAssertEqual(reloaded.defaultPenColorHex, "#1A2B3C")
        XCTAssertEqual(reloaded.defaultHighlighterColorHex, "#00FF88")
        XCTAssertEqual(reloaded.defaultPenWidth, 5.0, accuracy: 0.0001)
        XCTAssertEqual(reloaded.defaultEraserWidth, 28.0, accuracy: 0.0001)
        XCTAssertFalse(reloaded.includePaperGridInExport)
        XCTAssertEqual(reloaded.defaultExportDirectoryPath, exportDir.standardizedFileURL.path)

        // Verify clamping bounds.
        reloaded.interfaceContrast = 2.5
        reloaded.surfaceOpacity = 0.1
        XCTAssertEqual(reloaded.interfaceContrast, AppSettingsStore.contrastRange.upperBound, accuracy: 0.0001)
        XCTAssertEqual(reloaded.surfaceOpacity, AppSettingsStore.surfaceOpacityRange.lowerBound, accuracy: 0.0001)
    }

    func testPenPresetEditingValidationAndReset() {
        let store = AppSettingsStore(defaults: isolatedDefaults)
        XCTAssertEqual(store.penPresets.count, 5)
        XCTAssertEqual(store.penPresets[0].hex, "#2B2A33")

        // Valid edit normalizes hex and updates optional name.
        XCTAssertTrue(store.updatePenPreset(at: 1, hex: " 12ab34 ", name: "Esmeralda"))
        XCTAssertEqual(store.penPresets[1].hex, "#12AB34")
        XCTAssertEqual(store.penPresets[1].name, "Esmeralda")

        // Invalid hex or out-of-range index is rejected without corrupting state.
        XCTAssertFalse(store.updatePenPreset(at: 1, hex: "not-a-hex"))
        XCTAssertFalse(store.updatePenPreset(at: 1, hex: "#123"))
        XCTAssertFalse(store.updatePenPreset(at: 99, hex: "#FFFFFF"))
        XCTAssertEqual(store.penPresets[1].hex, "#12AB34")
        XCTAssertEqual(store.penPresets[1].name, "Esmeralda")

        // Persists across reloads.
        let reloaded = AppSettingsStore(defaults: isolatedDefaults)
        XCTAssertEqual(reloaded.penPresets[1].hex, "#12AB34")
        XCTAssertEqual(reloaded.penPresets[1].name, "Esmeralda")

        // Reset restores defaults.
        reloaded.resetPenPresets()
        XCTAssertEqual(reloaded.penPresets, PenPresetColor.defaults)

        let afterReset = AppSettingsStore(defaults: isolatedDefaults)
        XCTAssertEqual(afterReset.penPresets, PenPresetColor.defaults)
    }

    func testResetAllRestoresAllDefaults() throws {
        let store = AppSettingsStore(defaults: isolatedDefaults)
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("easy-notes-reset-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        store.appearanceMode = .light
        store.themePreset = .terracotta
        store.interfaceContrast = 0.85
        store.surfaceOpacity = 0.75
        store.confirmBeforeDeletingNotebook = false
        store.confirmBeforeEmptyingTrash = false
        store.defaultPenColorHex = "#334455"
        store.defaultHighlighterColorHex = "#FFAA00"
        store.defaultPenWidth = 9.0
        store.defaultEraserWidth = 32.0
        XCTAssertTrue(store.updatePenPreset(at: 0, hex: "#FF0000", name: "Vermelho"))
        store.defaultPaperStyle = .dots
        store.defaultNoteOrientation = .landscape
        try store.setCustomStorageURL(tempDir)
        store.setDefaultExportDirectory(tempDir)
        store.includePaperGridInExport = false

        store.resetAll()

        let reloaded = AppSettingsStore(defaults: isolatedDefaults)
        XCTAssertEqual(reloaded.appearanceMode, .system)
        XCTAssertEqual(reloaded.themePreset, .editorial)
        XCTAssertEqual(reloaded.interfaceContrast, 1.0, accuracy: 0.0001)
        XCTAssertEqual(reloaded.surfaceOpacity, 1.0, accuracy: 0.0001)
        XCTAssertTrue(reloaded.confirmBeforeDeletingNotebook)
        XCTAssertTrue(reloaded.confirmBeforeEmptyingTrash)
        XCTAssertEqual(reloaded.defaultPenColorHex, AppSettingsStore.defaultPenColorHexValue)
        XCTAssertEqual(reloaded.defaultHighlighterColorHex, AppSettingsStore.defaultHighlighterColorHexValue)
        XCTAssertEqual(reloaded.defaultPenWidth, AppSettingsStore.defaultPenWidthValue, accuracy: 0.0001)
        XCTAssertEqual(reloaded.defaultEraserWidth, AppSettingsStore.defaultEraserWidthValue, accuracy: 0.0001)
        XCTAssertEqual(reloaded.penPresets, PenPresetColor.defaults)
        XCTAssertEqual(reloaded.defaultPaperStyle, .none)
        XCTAssertEqual(reloaded.defaultNoteOrientation, .portrait)
        // Custom storage path MUST be preserved by resetAll() so user notes are never silently detached.
        XCTAssertEqual(reloaded.customStoragePath, tempDir.standardizedFileURL.path)
        XCTAssertNil(reloaded.defaultExportDirectoryPath)
        XCTAssertTrue(reloaded.includePaperGridInExport)
    }

    func testInvalidHexRejectedForDefaultPenAndHighlighterColors() {
        let store = AppSettingsStore(defaults: isolatedDefaults)
        store.defaultPenColorHex = "#112233"
        store.defaultHighlighterColorHex = "#AABBCC"

        store.defaultPenColorHex = "not-a-color"
        store.defaultPenColorHex = "#123"
        store.defaultHighlighterColorHex = "zzzzzz"
        store.defaultHighlighterColorHex = ""

        XCTAssertEqual(store.defaultPenColorHex, "#112233")
        XCTAssertEqual(store.defaultHighlighterColorHex, "#AABBCC")

        let reloaded = AppSettingsStore(defaults: isolatedDefaults)
        XCTAssertEqual(reloaded.defaultPenColorHex, "#112233")
        XCTAssertEqual(reloaded.defaultHighlighterColorHex, "#AABBCC")
    }

    func testCanvasAndNewNoteDraftUseConfiguredDefaults() {
        let store = AppSettingsStore(defaults: isolatedDefaults)
        store.defaultPenColorHex = "#2B7A8C"
        store.defaultHighlighterColorHex = "#FF88AA"
        store.defaultPenWidth = 7.0
        store.defaultEraserWidth = 26.0
        store.defaultPaperStyle = .lines
        store.defaultNoteOrientation = .landscape

        let canvasVM = CanvasViewModel(settings: store)
        XCTAssertEqual(canvasVM.strokeWidth, 7.0, accuracy: 0.001)
        XCTAssertEqual(PenColorComponents.from(canvasVM.strokeColor).hex6, "#2B7A8C")

        canvasVM.selectTool(.eraser)
        XCTAssertEqual(canvasVM.strokeWidth, 26.0, accuracy: 0.001)

        canvasVM.selectTool(.highlighter)
        XCTAssertEqual(PenColorComponents.from(canvasVM.strokeColor).hex6, "#FF88AA")
        XCTAssertEqual(PenColorComponents.from(canvasVM.strokeColor).opacity, Double(CanvasViewModel.highlighterOpacity), accuracy: 0.02)

        let draft = NewNoteDraft.fromSettings(store)
        XCTAssertEqual(draft.paper, .lines)
        XCTAssertEqual(draft.orientation, .landscape)
    }

    func testCustomStorageURLValidationAndSafeMigrationCopyPreservesOriginal() throws {
        let baseTemp = FileManager.default.temporaryDirectory
            .appendingPathComponent("easy-notes-storage-test-\(UUID().uuidString)", isDirectory: true)
        let sourceDir = baseTemp.appendingPathComponent("source", isDirectory: true)
        let destDir = baseTemp.appendingPathComponent("destination", isDirectory: true)
        let missingDir = baseTemp.appendingPathComponent("does-not-exist", isDirectory: true)

        try FileManager.default.createDirectory(at: sourceDir, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: destDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: baseTemp) }

        let store = AppSettingsStore(defaults: isolatedDefaults)
        XCTAssertThrowsError(try store.setCustomStorageURL(missingDir))

        let sourceStoreURL = sourceDir.appendingPathComponent(CoreDataStack.storeFileName)
        let stack = CoreDataStack(storeURL: sourceStoreURL, defaults: isolatedDefaults)
        XCTAssertEqual(stack.currentStoreURL?.standardizedFileURL, sourceStoreURL.standardizedFileURL)

        let note = NSEntityDescription.insertNewObject(forEntityName: "Note", into: stack.viewContext) as! Note
        note.id = UUID()
        note.title = "Nota Preservada"
        note.content = "Conteúdo importante"
        note.createdAt = Date()
        note.updatedAt = Date()
        note.isTrashed = false
        note.pageCount = 1
        note.gridStyle = GridStyle.none.rawValue
        note.gridSpacing = 24
        note.gridOriginX = 0
        note.gridOriginY = 0
        // Large binary payload (>128KB) to exercise Core Data's allowsExternalBinaryDataStorage (_EXTERNAL_DATA).
        let coverPayload = Data((0..<(256 * 1024)).map { UInt8($0 % 251) })
        note.coverMediaData = coverPayload
        note.coverMediaType = "image/png"
        stack.saveContext()

        // Migrating into the active directory itself must be rejected.
        XCTAssertThrowsError(try stack.migrateStoreCopy(to: sourceDir)) { error in
            XCTAssertEqual(error as? CoreDataStorageError, .destinationMatchesSource(sourceStoreURL.standardizedFileURL))
        }

        let copiedURL = try stack.migrateStoreCopy(to: destDir)
        XCTAssertEqual(copiedURL.standardizedFileURL, destDir.appendingPathComponent(CoreDataStack.storeFileName).standardizedFileURL)
        XCTAssertTrue(FileManager.default.fileExists(atPath: copiedURL.path))
        // Original database MUST remain intact as backup.
        XCTAssertTrue(FileManager.default.fileExists(atPath: sourceStoreURL.path))

        // Attempting to migrate again into the same populated directory must refuse to overwrite.
        XCTAssertThrowsError(try stack.migrateStoreCopy(to: destDir)) { error in
            XCTAssertEqual(error as? CoreDataStorageError, .destinationAlreadyExists(copiedURL))
        }

        // Persist custom storage path and verify a new CoreDataStack loads from it,
        // including the externally stored coverMediaData payload.
        try store.setCustomStorageURL(destDir)
        XCTAssertEqual(store.customStoragePath, destDir.standardizedFileURL.path)

        let reopenedStack = CoreDataStack(defaults: isolatedDefaults)
        XCTAssertNil(reopenedStack.storageLoadWarning)
        XCTAssertFalse(reopenedStack.didFallbackToDefaultStore)
        XCTAssertEqual(reopenedStack.currentStoreURL?.standardizedFileURL, copiedURL.standardizedFileURL)
        let request = NSFetchRequest<Note>(entityName: "Note")
        let fetched = try reopenedStack.viewContext.fetch(request)
        let migratedNote = try XCTUnwrap(fetched.first(where: { $0.title == "Nota Preservada" }))
        XCTAssertEqual(migratedNote.coverMediaData, coverPayload)
        XCTAssertEqual(migratedNote.coverMediaType, "image/png")

        // Verify original source store still has the note and external data intact.
        let originalStack = CoreDataStack(storeURL: sourceStoreURL, defaults: isolatedDefaults)
        let originalFetched = try originalStack.viewContext.fetch(NSFetchRequest<Note>(entityName: "Note"))
        let originalNote = try XCTUnwrap(originalFetched.first(where: { $0.title == "Nota Preservada" }))
        XCTAssertEqual(originalNote.coverMediaData, coverPayload)

        store.resetStorageLocation()
        XCTAssertNil(store.customStoragePath)
        XCTAssertNil(store.storageDirectoryBookmark)
    }

    func testCoreDataStackFallsBackSafelyWhenCustomDirectoryIsMissing() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("easy-notes-fallback-test-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let missingPath = directory.appendingPathComponent("missing").path
        isolatedDefaults.set(missingPath, forKey: AppSettingsStore.Keys.customStoragePath)

        let stack = CoreDataStack(defaults: isolatedDefaults, welcome: nil, defaultStoreDirectory: directory)
        defer {
            stack.viewContext.reset()
            let coordinator = stack.container.persistentStoreCoordinator
            for store in coordinator.persistentStores {
                try? coordinator.remove(store)
            }
        }
        XCTAssertTrue(stack.didFallbackToDefaultStore)
        XCTAssertNotNil(stack.storageLoadWarning)
        XCTAssertEqual(stack.currentStoreURL?.deletingLastPathComponent().standardizedFileURL,
                       directory.standardizedFileURL)
    }

    func testSettingsSearchFilteringMatchesKeywordsAndTitles() {
        XCTAssertEqual(SettingsTab.allCases.filter { $0.matches(query: "") }.count, SettingsTab.allCases.count)
        XCTAssertTrue(SettingsTab.appearance.matches(query: "escuro"))
        XCTAssertTrue(SettingsTab.appearance.matches(query: "aparencia"))
        XCTAssertTrue(SettingsTab.storage.matches(query: "Finder"))
        XCTAssertTrue(SettingsTab.export.matches(query: "PDF"))
        XCTAssertFalse(SettingsTab.about.matches(query: "quadriculado"))
    }
}
