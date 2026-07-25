import AppKit
import Combine
import Foundation

struct SaveSlotSummary: Identifiable {
    let id: Int
    let url: URL
    let modifiedAt: Date?
    let isValid: Bool

    var filename: String {
        url.lastPathComponent
    }
}

enum SaveEditorSection: String, CaseIterable, Identifiable {
    case party = "PARTY"
    case inventory = "INVENTORY"
    case resources = "RESOURCES"

    var id: String { rawValue }
}

@MainActor
final class SaveEditorController: ObservableObject {
    @Published private(set) var slots: [SaveSlotSummary] = []
    @Published private(set) var save: FQ4SaveFile?
    @Published private(set) var baseline: FQ4SaveFile?
    @Published var selectedSlot = 3
    @Published var section: SaveEditorSection = .party
    @Published var selectedCharacterIndex: Int?
    @Published var characterFilter = ""
    @Published var showChangedOnly = true
    @Published private(set) var notice = "Choose a save slot to begin."
    @Published private(set) var lastBackupURL: URL?
    @Published private(set) var lastLoadedAt: Date?

    private var gameURL: URL?
    private var baselineGameURL: URL?
    private var characterNames: FQ4CharacterNameCatalogue?
    private var characterClasses: FQ4CharacterClassCatalogue?
    private var classSprites: FQ4ClassSpriteArchive?
    private var classSpriteCache: [Int: NSImage] = [:]

    var pendingByteCount: Int {
        save?.pendingByteCount ?? 0
    }

    var inventory: [Int] {
        save?.inventory ?? []
    }

    var displayedGold: Int {
        save?.displayedGold ?? 0
    }

    var selectedCharacter: FQ4CharacterRecord? {
        guard let selectedCharacterIndex else { return nil }
        return save?.character(index: selectedCharacterIndex)
    }

    func primaryName(for record: FQ4CharacterRecord) -> String {
        characterNames?.primaryName(for: record.nameCode)
            ?? String(format: "Name %04X", record.nameCode)
    }

    func localizedName(for record: FQ4CharacterRecord) -> String? {
        characterNames?.localizedName(for: record.nameCode)
    }

    func englishAlias(for record: FQ4CharacterRecord) -> String? {
        characterNames?.englishAlias(for: record.nameCode)
    }

    var classOptions: [FQ4ClassOption] {
        characterClasses?.options ?? []
    }

    func classOption(for code: Int) -> FQ4ClassOption? {
        characterClasses?.option(for: code)
    }

    func className(for code: Int) -> String {
        classOption(for: code)?.displayName
            ?? String(format: "Unknown class %02X", code)
    }

    func classSprite(for code: Int) -> NSImage? {
        if let cached = classSpriteCache[code] {
            return cached
        }
        guard let page = try? classSprites?.representativePage(for: code),
              let image = page.image
        else {
            return nil
        }
        classSpriteCache[code] = image
        return image
    }

    var loadedClassCode: Int? {
        guard let save, let selectedCharacterIndex else { return nil }
        return save.originalClassCode(for: selectedCharacterIndex)
    }

    var visibleCharacters: [FQ4CharacterRecord] {
        guard let save else { return [] }
        let changed = save.changedCharacterIndices(comparedWith: baseline)
        let query = characterFilter
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .uppercased()

        return save.characters.filter { record in
            if showChangedOnly && !changed.contains(record.id) {
                return false
            }
            guard !query.isEmpty else { return true }
            let decimal = String(record.id + 1)
            let hex = record.displayID
            let localizedName = localizedName(for: record) ?? ""
            let englishName = englishAlias(for: record) ?? ""
            let className = className(for: record.classCode)
            let values = [
                record.stats.level,
                record.stats.hitRate,
                record.stats.hitPoints,
                record.stats.attack,
                record.stats.attackRange,
                record.stats.defence,
                record.stats.defenceRange,
            ].map(String.init).joined(separator: " ")
            return decimal.contains(query)
                || hex.contains(query)
                || localizedName.uppercased().contains(query)
                || englishName.uppercased().contains(query)
                || className.uppercased().contains(query)
                || values.contains(query)
        }
    }

    func reload(gameURL: URL, baselineGameURL: URL?) {
        self.gameURL = gameURL
        self.baselineGameURL = baselineGameURL
        characterNames = loadCharacterNames(
            gameURL: gameURL,
            baselineGameURL: baselineGameURL
        )
        characterClasses = loadCharacterClasses(
            gameURL: gameURL,
            baselineGameURL: baselineGameURL
        )
        classSprites = loadClassSprites(
            gameURL: gameURL,
            baselineGameURL: baselineGameURL
        )
        classSpriteCache = [:]

        refreshSlotSummaries()

        if let newest = slots
            .filter(\.isValid)
            .max(by: { ($0.modifiedAt ?? .distantPast) < ($1.modifiedAt ?? .distantPast) })
        {
            selectedSlot = newest.id
        }
        loadSelectedSlot()
    }

    func chooseSlot(_ index: Int) {
        guard pendingByteCount == 0 else {
            notice = "Apply or revert the pending changes before changing slots."
            return
        }
        selectedSlot = index
        loadSelectedSlot()
    }

    func selectCharacter(_ id: Int) {
        selectedCharacterIndex = id
    }

    func updateSelectedCharacter(
        _ transform: (inout FQ4CharacterStats) -> Void
    ) {
        guard var file = save, let selectedCharacterIndex,
              var stats = file.character(index: selectedCharacterIndex)?.stats
        else {
            return
        }
        transform(&stats)
        do {
            try file.setCharacterStats(stats, for: selectedCharacterIndex)
            save = file
            notice = "Changes are staged. The save on disk is untouched."
        } catch {
            notice = error.localizedDescription
        }
    }

    func applyNaturalMaximum() {
        updateSelectedCharacter { $0 = .naturalMaximum }
    }

    func stageSelectedCharacterClass(_ classCode: Int) {
        guard var file = save, let selectedCharacterIndex,
              let option = classOption(for: classCode)
        else {
            notice = "The class catalogue is unavailable."
            return
        }
        guard option.risk != .unavailable else {
            notice = "Class \(option.codeLabel) is blocked because it is not a safe character archetype."
            return
        }

        do {
            try file.setCharacterClass(classCode, for: selectedCharacterIndex)
            save = file
            notice = "Class \(option.codeLabel) · \(option.primaryName) is staged. Only one byte changed."
        } catch {
            notice = error.localizedDescription
        }
    }

    func restoreLoadedClass() {
        guard var file = save, let selectedCharacterIndex,
              let loadedClassCode
        else {
            return
        }
        do {
            try file.setCharacterClass(loadedClassCode, for: selectedCharacterIndex)
            save = file
            notice = "The class loaded from disk has been restored."
        } catch {
            notice = error.localizedDescription
        }
    }

    func updateInventory(index: Int, quantity: Int) {
        guard var file = save else { return }
        do {
            try file.setInventoryQuantity(quantity, at: index)
            save = file
            notice = "Changes are staged. The save on disk is untouched."
        } catch {
            notice = error.localizedDescription
        }
    }

    func updateGold(_ value: Int) {
        guard var file = save else { return }
        let normalized = min(
            FQ4SaveFile.maximumDisplayedGold,
            max(0, value - (value % 10))
        )
        do {
            try file.setDisplayedGold(normalized)
            save = file
            notice = "Gold is staged at \(normalized.formatted()) G."
        } catch {
            notice = error.localizedDescription
        }
    }

    func setAllInventory(to quantity: Int) {
        guard var file = save else { return }
        do {
            for index in 0..<FQ4SaveFile.inventoryCount {
                try file.setInventoryQuantity(quantity, at: index)
            }
            save = file
            notice = "All 72 inventory quantities are staged at \(quantity)."
        } catch {
            notice = error.localizedDescription
        }
    }

    func revertChanges() {
        loadSelectedSlot()
    }

    func refreshSelectedSlot() {
        guard pendingByteCount == 0 else {
            notice = "Apply or revert the pending changes before refreshing from disk."
            return
        }
        guard let slot = slots.first(where: { $0.id == selectedSlot }) else {
            notice = "Save slot not found."
            return
        }

        do {
            let refreshed = try FQ4SaveFile(data: Data(contentsOf: slot.url))
            let didChange = refreshed.data != save?.data
            let refreshedBaseline: FQ4SaveFile?
            if let baselineGameURL {
                let url = baselineGameURL.appendingPathComponent(slot.filename)
                refreshedBaseline = try? FQ4SaveFile(data: Data(contentsOf: url))
            } else {
                refreshedBaseline = nil
            }

            save = refreshed
            baseline = refreshedBaseline
            lastLoadedAt = Date()
            refreshSlotSummaries()
            preserveCharacterSelection()

            let action = didChange ? "Reloaded latest data" : "Already current"
            notice = "\(action) · \(slot.filename) checked \(Self.refreshTime.string(from: lastLoadedAt!))."
        } catch {
            notice = "Refresh failed; the loaded data was kept: \(error.localizedDescription)"
        }
    }

    func applyChanges(gameIsRunning: Bool) {
        guard !gameIsRunning else {
            notice = "Quit FQ4 before editing its save files."
            return
        }
        guard let slot = slots.first(where: { $0.id == selectedSlot }),
              let save, save.pendingByteCount > 0,
              let gameURL
        else {
            notice = "There are no changes to apply."
            return
        }

        do {
            try save.validatePendingChanges()
            let fileManager = FileManager.default
            let backupDirectory = gameURL
                .deletingLastPathComponent()
                .appendingPathComponent("Save Backups", isDirectory: true)
            try fileManager.createDirectory(
                at: backupDirectory,
                withIntermediateDirectories: true
            )

            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.dateFormat = "yyyyMMdd-HHmmss"
            let backupURL = backupDirectory.appendingPathComponent(
                "\(slot.filename)-\(formatter.string(from: Date())).bak"
            )
            try fileManager.copyItem(at: slot.url, to: backupURL)
            try save.data.write(to: slot.url, options: .atomic)

            let written = try FQ4SaveFile(data: Data(contentsOf: slot.url))
            guard written.data == save.data else {
                throw CocoaError(.fileWriteUnknown)
            }
            lastBackupURL = backupURL
            notice = "Saved safely. A timestamped backup was created."
            loadSelectedSlot(preservingNotice: true)
        } catch {
            notice = "Save failed: \(error.localizedDescription)"
        }
    }

    func restoreLastBackup(gameIsRunning: Bool) {
        guard !gameIsRunning else {
            notice = "Quit FQ4 before restoring a backup."
            return
        }
        guard let backupURL = lastBackupURL,
              let slot = slots.first(where: { $0.id == selectedSlot })
        else {
            notice = "There is no backup from this session to restore."
            return
        }

        do {
            let backupData = try Data(contentsOf: backupURL)
            _ = try FQ4SaveFile(data: backupData)
            try backupData.write(to: slot.url, options: .atomic)
            notice = "The previous save was restored from backup."
            lastBackupURL = nil
            loadSelectedSlot(preservingNotice: true)
        } catch {
            notice = "Restore failed: \(error.localizedDescription)"
        }
    }

    private func loadSelectedSlot(preservingNotice: Bool = false) {
        guard let slot = slots.first(where: { $0.id == selectedSlot }) else {
            save = nil
            baseline = nil
            notice = "Save slot not found."
            return
        }

        do {
            save = try FQ4SaveFile(data: Data(contentsOf: slot.url))
            if let baselineGameURL {
                let url = baselineGameURL.appendingPathComponent(slot.filename)
                baseline = try? FQ4SaveFile(data: Data(contentsOf: url))
            } else {
                baseline = nil
            }
            lastLoadedAt = Date()
            preserveCharacterSelection()
            if !preservingNotice {
                notice = "Loaded \(slot.filename). Originals remain protected."
            }
        } catch {
            save = nil
            baseline = nil
            notice = error.localizedDescription
        }
    }

    private func refreshSlotSummaries() {
        guard let gameURL else {
            slots = []
            return
        }
        let fileManager = FileManager.default
        slots = (0..<4).map { index in
            let url = gameURL.appendingPathComponent("FQ4GD.\(index)")
            let attributes = try? fileManager.attributesOfItem(atPath: url.path)
            let modifiedAt = attributes?[.modificationDate] as? Date
            let isValid = (try? FQ4SaveFile(data: Data(contentsOf: url))) != nil
            return SaveSlotSummary(
                id: index,
                url: url,
                modifiedAt: modifiedAt,
                isValid: isValid
            )
        }
    }

    private func preserveCharacterSelection() {
        let candidates = visibleCharacters
        if selectedCharacterIndex.flatMap({ save?.character(index: $0) }) == nil {
            selectedCharacterIndex = candidates.first?.id ?? save?.characters.first?.id
        }
    }

    private static let refreshTime: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "HH:mm:ss"
        return formatter
    }()

    private func loadCharacterNames(
        gameURL: URL,
        baselineGameURL: URL?
    ) -> FQ4CharacterNameCatalogue? {
        let candidates = [
            baselineGameURL?.appendingPathComponent("MAIN.EXE"),
            gameURL.appendingPathComponent("MAIN.EXE"),
        ].compactMap { $0 }

        for url in candidates {
            guard let data = try? Data(contentsOf: url) else { continue }
            if let catalogue = try? FQ4CharacterNameCatalogue(
                mainExecutableData: data
            ) {
                return catalogue
            }
        }
        return nil
    }

    private func loadCharacterClasses(
        gameURL: URL,
        baselineGameURL: URL?
    ) -> FQ4CharacterClassCatalogue? {
        let candidates = [
            baselineGameURL?.appendingPathComponent("MAIN.EXE"),
            gameURL.appendingPathComponent("MAIN.EXE"),
        ].compactMap { $0 }

        for url in candidates {
            guard let data = try? Data(contentsOf: url) else { continue }
            if let catalogue = try? FQ4CharacterClassCatalogue(
                mainExecutableData: data
            ) {
                return catalogue
            }
        }
        return nil
    }

    private func loadClassSprites(
        gameURL: URL,
        baselineGameURL: URL?
    ) -> FQ4ClassSpriteArchive? {
        let candidates = [
            baselineGameURL,
            gameURL,
        ].compactMap { $0 }

        for directory in candidates {
            guard let data = try? Data(
                contentsOf: directory.appendingPathComponent("CHRBANK")
            ),
            let executable = try? Data(
                contentsOf: directory.appendingPathComponent("MAIN.EXE")
            ),
            let archive = try? FQ4ClassSpriteArchive(
                data: data,
                mainExecutableData: executable
            )
            else {
                continue
            }
            return archive
        }
        return nil
    }
}
