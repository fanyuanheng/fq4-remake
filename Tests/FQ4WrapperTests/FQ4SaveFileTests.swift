import Foundation
import Testing
@testable import FQ4Wrapper

struct FQ4SaveFileTests {
    @Test
    func readsAndEditsVerifiedInventoryRange() throws {
        var data = makeSaveData()
        data[FQ4SaveFile.inventoryOffset] = 7
        var save = try FQ4SaveFile(data: data)

        #expect(save.inventory.count == 72)
        #expect(save.inventory[0] == 7)

        try save.setInventoryQuantity(10, at: 0)

        #expect(save.inventory[0] == 10)
        #expect(save.pendingByteCount == 1)
        #expect(save.data[FQ4SaveFile.inventoryOffset] == 10)
    }

    @Test
    func readsAndEditsKnownCharacterStatLayout() throws {
        var data = makeSaveData()
        let index = 0
        let internalID = 0xDC
        let recordOffset = FQ4SaveFile.characterTableOffset
        data[recordOffset] = UInt8(internalID & 0xFF)
        data[recordOffset + 1] = UInt8(internalID >> 8)
        data[recordOffset + 2] = 0x1A
        let statsOffset = recordOffset + FQ4SaveFile.characterStatsOffset
        let original: [UInt8] = [0, 10, 255, 0, 35, 36, 32, 35]
        data.replaceSubrange(statsOffset..<(statsOffset + 8), with: original)

        var save = try FQ4SaveFile(data: data)
        let record = try #require(save.character(index: index))

        #expect(record.internalID == internalID)
        #expect(record.nameCode == 0x001A)
        #expect(record.stats.level == 0)
        #expect(record.stats.hitRate == 10)
        #expect(record.stats.hitPoints == 255)
        #expect(record.stats.attack == 35)
        #expect(record.stats.attackRange == 36)
        #expect(record.stats.defence == 32)
        #expect(record.stats.defenceRange == 35)

        try save.setCharacterStats(.naturalMaximum, for: index)

        #expect(save.character(index: index)?.stats == .naturalMaximum)
        #expect(save.pendingByteCount == 8)
        #expect(save.data[statsOffset + 2] == 0xE7)
        #expect(save.data[statsOffset + 3] == 0x03)
    }

    @Test
    func rejectsWrongHeaderAndUnsafeStats() throws {
        var invalid = Data(repeating: 0, count: FQ4SaveFile.expectedLength)
        #expect(throws: FQ4SaveFile.SaveError.self) {
            _ = try FQ4SaveFile(data: invalid)
        }

        invalid.replaceSubrange(0..<4, with: Data("FQ-4".utf8))
        let index = 0
        let recordOffset = FQ4SaveFile.characterTableOffset
        invalid[recordOffset] = 1
        let statsOffset = recordOffset + FQ4SaveFile.characterStatsOffset
        invalid[statsOffset + 1] = 8
        invalid[statsOffset + 2] = 100
        var save = try FQ4SaveFile(data: invalid)
        var unsafe = FQ4CharacterStats.naturalMaximum
        unsafe.hitPoints = 1_000

        #expect(throws: FQ4SaveFile.SaveError.self) {
            try save.setCharacterStats(unsafe, for: index)
        }
    }

    @Test
    func roundTripsDisplayedGoldWithTenTimesEncoding() throws {
        var data = makeSaveData()
        data[FQ4SaveFile.goldOffset] = 0x64
        var save = try FQ4SaveFile(data: data)

        #expect(save.displayedGold == 1_000)

        try save.setDisplayedGold(62_530)

        #expect(save.displayedGold == 62_530)
        #expect(save.data[FQ4SaveFile.goldOffset] == 0x6D)
        #expect(save.data[FQ4SaveFile.goldOffset + 1] == 0x18)
        try save.validatePendingChanges()
    }

    @Test
    func parsesBundledTaiwaneseDOSFixture() throws {
        let testsURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
        let fixtureURL = testsURL
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("FQ4/FQ4GD.3")
        let fixture = try Data(contentsOf: fixtureURL)
        let save = try FQ4SaveFile(data: fixture)
        let first = try #require(save.character(index: 0))

        #expect(save.displayedGold == 1_000)
        #expect(save.inventory.count == 72)
        #expect(first.internalID == 0xDC)
        #expect(first.nameCode == 0x001A)
        #expect(first.stats.hitPoints == 255)
        #expect(first.stats.attack == 35)
    }

    @Test
    func mapsBundledBig5CharacterNamesAndEnglishAliases() throws {
        let testsURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
        let executableURL = testsURL
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("FQ4/MAIN.EXE")
        let catalogue = try FQ4CharacterNameCatalogue(
            mainExecutableData: Data(contentsOf: executableURL)
        )

        #expect(catalogue.names.count == 652)
        #expect(catalogue.localizedName(for: 0x001A) == "艾雷斯")
        #expect(catalogue.primaryName(for: 0x001A) == "Ares")
        #expect(catalogue.localizedName(for: 0x0018) == "阿魯富特")
        #expect(catalogue.primaryName(for: 0x0018) == "Alfred")
        #expect(catalogue.localizedName(for: 0x0098) == "孔萊多")
        #expect(catalogue.primaryName(for: 0x0098) == "Conrad")
    }

    @Test
    func mapsClassTableAndAssignsGuardrailRisk() throws {
        let executableURL = bundledGameURL
            .appendingPathComponent("MAIN.EXE")
        let catalogue = try FQ4CharacterClassCatalogue(
            mainExecutableData: Data(contentsOf: executableURL)
        )

        #expect(catalogue.options.count == 220)
        #expect(catalogue.option(for: 0x00)?.localizedName == "國王")
        #expect(catalogue.option(for: 0x00)?.englishName == "King")
        #expect(catalogue.option(for: 0x54)?.risk == .standard)
        #expect(catalogue.option(for: 0x54)?.englishName == "Soldier")
        #expect(catalogue.option(for: 0x5F)?.risk == .experimental)
        #expect(catalogue.option(for: 0xD4)?.englishName == "Giant")
        #expect(catalogue.option(for: 0x06)?.risk == .unavailable)
        #expect(catalogue.option(for: 0xB1)?.risk == .unavailable)
        #expect(catalogue.option(for: 0xDC) == nil)
    }

    @Test
    func stagesOnlyVerifiedClassByteAndPreservesAdjacentFaction() throws {
        let originalData = try Data(
            contentsOf: bundledGameURL.appendingPathComponent("FQ4GD.3")
        )
        var save = try FQ4SaveFile(data: originalData)
        let original = try #require(save.character(index: 0))
        let classOffset = FQ4SaveFile.characterTableOffset
            + FQ4SaveFile.characterClassOffset

        try save.setCharacterClass(0xD4, for: 0)

        #expect(save.character(index: 0)?.classCode == 0xD4)
        #expect(save.character(index: 0)?.factionCode == original.factionCode)
        #expect(save.character(index: 0)?.heldItemID == original.heldItemID)
        #expect(save.character(index: 0)?.stats == original.stats)
        #expect(save.originalClassCode(for: 0) == original.classCode)
        #expect(save.changedOffsets == [classOffset])
        try save.validatePendingChanges()

        #expect(throws: FQ4SaveFile.SaveError.self) {
            try save.setCharacterClass(0xDC, for: 0)
        }
    }

    @Test
    func classChangesParticipateInChangedCharacterFilter() throws {
        let data = try Data(
            contentsOf: bundledGameURL.appendingPathComponent("FQ4GD.3")
        )
        let baseline = try FQ4SaveFile(data: data)
        var changed = try FQ4SaveFile(data: data)

        try changed.setCharacterClass(0xD4, for: 0)

        #expect(changed.changedCharacterIndices(comparedWith: baseline) == Set([0]))
    }

    private var bundledGameURL: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("FQ4", isDirectory: true)
    }

    private func makeSaveData() -> Data {
        var data = Data(repeating: 0, count: FQ4SaveFile.expectedLength)
        data.replaceSubrange(0..<4, with: Data("FQ-4".utf8))
        return data
    }
}
