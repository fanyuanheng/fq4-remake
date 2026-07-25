import Foundation
import Testing
@testable import FQ4Wrapper

struct SaveEditorControllerTests {
    @Test
    @MainActor
    func filtersCharactersByMappedEnglishAndLocalizedNames() throws {
        let testsURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
        let gameURL = testsURL
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("FQ4", isDirectory: true)

        let editor = SaveEditorController()
        editor.reload(gameURL: gameURL, baselineGameURL: gameURL)
        editor.showChangedOnly = false

        editor.characterFilter = "Ares"
        #expect(editor.visibleCharacters.contains { $0.nameCode == 0x001A })

        editor.characterFilter = "孔萊多"
        #expect(editor.visibleCharacters.contains { $0.nameCode == 0x0098 })
    }

    @Test
    @MainActor
    func backsUpWritesAndRestoresDisposableSaveCopy() throws {
        let fileManager = FileManager.default
        let temporaryURL = fileManager.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? fileManager.removeItem(at: temporaryURL) }

        let gameURL = temporaryURL.appendingPathComponent("FQ4", isDirectory: true)
        try fileManager.createDirectory(
            at: gameURL,
            withIntermediateDirectories: true
        )
        let testsURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
        let fixtureURL = testsURL
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("FQ4/FQ4GD.3")
        let original = try Data(contentsOf: fixtureURL)
        let workingURL = gameURL.appendingPathComponent("FQ4GD.3")
        try original.write(to: workingURL)

        let editor = SaveEditorController()
        editor.reload(gameURL: gameURL, baselineGameURL: nil)
        editor.updateGold(100_000)
        #expect(editor.pendingByteCount > 0)

        editor.applyChanges(gameIsRunning: false)

        let edited = try FQ4SaveFile(data: Data(contentsOf: workingURL))
        #expect(edited.displayedGold == 100_000)
        #expect(editor.lastBackupURL != nil)
        #expect(editor.lastBackupURL.map { fileManager.fileExists(atPath: $0.path) } == true)

        editor.restoreLastBackup(gameIsRunning: false)

        #expect(try Data(contentsOf: workingURL) == original)
        #expect(editor.lastBackupURL == nil)
    }

    @Test
    @MainActor
    func stagesAndRestoresClassWithoutTouchingCompanionFields() throws {
        let testsURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
        let gameURL = testsURL
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("FQ4", isDirectory: true)
        let editor = SaveEditorController()
        editor.reload(gameURL: gameURL, baselineGameURL: gameURL)
        editor.showChangedOnly = false
        editor.selectCharacter(0)
        let original = try #require(editor.selectedCharacter)

        editor.stageSelectedCharacterClass(0xD4)

        #expect(editor.selectedCharacter?.classCode == 0xD4)
        #expect(editor.selectedCharacter?.factionCode == original.factionCode)
        #expect(editor.selectedCharacter?.heldItemID == original.heldItemID)
        #expect(editor.selectedCharacter?.stats == original.stats)
        #expect(editor.pendingByteCount == 1)

        editor.restoreLoadedClass()

        #expect(editor.selectedCharacter?.classCode == original.classCode)
        #expect(editor.pendingByteCount == 0)
    }

    @Test
    @MainActor
    func refusesUnavailableObjectClass() throws {
        let testsURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
        let gameURL = testsURL
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("FQ4", isDirectory: true)
        let editor = SaveEditorController()
        editor.reload(gameURL: gameURL, baselineGameURL: gameURL)
        editor.selectCharacter(0)
        let originalClass = editor.selectedCharacter?.classCode

        editor.stageSelectedCharacterClass(0xB1)

        #expect(editor.selectedCharacter?.classCode == originalClass)
        #expect(editor.pendingByteCount == 0)
        #expect(editor.notice.contains("blocked"))
    }

    @Test
    @MainActor
    func manuallyRefreshesExternalSaveChangesAndUpdatesTimestamp() throws {
        let original = try Data(
            contentsOf: bundledGameURL.appendingPathComponent("FQ4GD.3")
        )
        let (gameURL, cleanup) = try makeTemporaryGame(saveData: original)
        defer { cleanup() }
        let workingURL = gameURL.appendingPathComponent("FQ4GD.3")

        let editor = SaveEditorController()
        editor.reload(gameURL: gameURL, baselineGameURL: nil)
        let firstLoadedAt = try #require(editor.lastLoadedAt)

        var external = try FQ4SaveFile(data: original)
        try external.setDisplayedGold(120_000)
        try external.data.write(to: workingURL, options: .atomic)

        #expect(editor.displayedGold != 120_000)
        editor.refreshSelectedSlot()

        #expect(editor.displayedGold == 120_000)
        #expect(editor.lastLoadedAt.map { $0 >= firstLoadedAt } == true)
        #expect(editor.notice.contains("Reloaded latest data"))
    }

    @Test
    @MainActor
    func refreshRefusesToDiscardStagedChanges() throws {
        let original = try Data(
            contentsOf: bundledGameURL.appendingPathComponent("FQ4GD.3")
        )
        let (gameURL, cleanup) = try makeTemporaryGame(saveData: original)
        defer { cleanup() }

        let editor = SaveEditorController()
        editor.reload(gameURL: gameURL, baselineGameURL: nil)
        editor.updateGold(100_000)
        let stagedGold = editor.displayedGold

        editor.refreshSelectedSlot()

        #expect(editor.displayedGold == stagedGold)
        #expect(editor.pendingByteCount > 0)
        #expect(editor.notice.contains("Apply or revert"))
    }

    private var bundledGameURL: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("FQ4", isDirectory: true)
    }

    private func makeTemporaryGame(
        saveData: Data
    ) throws -> (URL, () -> Void) {
        let fileManager = FileManager.default
        let temporaryURL = fileManager.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let gameURL = temporaryURL.appendingPathComponent("FQ4", isDirectory: true)
        try fileManager.createDirectory(
            at: gameURL,
            withIntermediateDirectories: true
        )
        try saveData.write(to: gameURL.appendingPathComponent("FQ4GD.3"))
        return (gameURL, { try? fileManager.removeItem(at: temporaryURL) })
    }
}
