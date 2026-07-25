import Foundation

struct FQ4CharacterStats: Equatable {
    var level: Int
    var hitRate: Int
    var hitPoints: Int
    var attack: Int
    var attackRange: Int
    var defence: Int
    var defenceRange: Int

    static let naturalMaximum = FQ4CharacterStats(
        level: 99,
        hitRate: 16,
        hitPoints: 999,
        attack: 99,
        attackRange: 99,
        defence: 99,
        defenceRange: 99
    )

    var isWithinNaturalLimits: Bool {
        (0...99).contains(level)
            && (0...16).contains(hitRate)
            && (0...999).contains(hitPoints)
            && (0...99).contains(attack)
            && (0...99).contains(attackRange)
            && (0...99).contains(defence)
            && (0...99).contains(defenceRange)
    }
}

struct FQ4CharacterRecord: Identifiable, Equatable {
    let id: Int
    let internalID: Int
    let nameCode: Int
    let classCode: Int
    let factionCode: Int
    let heldItemID: Int
    var stats: FQ4CharacterStats

    var displayID: String {
        String(format: "%04X", internalID)
    }
}

struct FQ4SaveFile {
    enum SaveError: LocalizedError {
        case wrongLength(Int)
        case wrongHeader
        case invalidGold
        case invalidInventoryIndex
        case invalidCharacterRecord(Int)
        case invalidClassCode(Int)
        case invalidStats
        case unsafeMutation

        var errorDescription: String? {
            switch self {
            case .wrongLength(let length):
                return "Unsupported save length: \(length) bytes."
            case .wrongHeader:
                return "This is not an FQ-4 save file."
            case .invalidGold:
                return "Gold must be from 0 to 655,350 in multiples of 10."
            case .invalidInventoryIndex:
                return "That inventory entry is outside the 72-item table."
            case .invalidCharacterRecord(let index):
                return "Character record \(index + 1) is not valid in this save."
            case .invalidClassCode(let code):
                return String(
                    format: "Class %02X is outside the game's verified 00–DB table.",
                    code
                )
            case .invalidStats:
                return "One or more values exceed the game's natural limits."
            case .unsafeMutation:
                return "The pending data contains a change outside the verified fields."
            }
        }
    }

    static let expectedLength = 0x7E12
    static let inventoryOffset = 0x381
    static let inventoryCount = 72
    static let goldOffset = 0x47E
    static let maximumDisplayedGold = 655_350
    static let characterTableOffset = 0x2992
    static let characterRecordSize = 0x20
    static let characterClassOffset = 0x0C
    static let characterStatsOffset = 0x18
    static let maximumCharacterRecords = 380
    static let maximumClassCode = 0xDB

    let originalData: Data
    private(set) var data: Data

    init(data: Data) throws {
        guard data.count == Self.expectedLength else {
            throw SaveError.wrongLength(data.count)
        }
        guard data.prefix(4) == Data("FQ-4".utf8) else {
            throw SaveError.wrongHeader
        }
        originalData = data
        self.data = data
    }

    var changedOffsets: [Int] {
        data.indices.filter { originalData[$0] != data[$0] }
    }

    var pendingByteCount: Int {
        changedOffsets.count
    }

    var displayedGold: Int {
        readUInt32(at: Self.goldOffset) * 10
    }

    mutating func setDisplayedGold(_ value: Int) throws {
        guard (0...Self.maximumDisplayedGold).contains(value),
              value.isMultiple(of: 10)
        else {
            throw SaveError.invalidGold
        }
        writeUInt32(value / 10, at: Self.goldOffset)
    }

    var inventory: [Int] {
        let range = Self.inventoryOffset..<(Self.inventoryOffset + Self.inventoryCount)
        return data[range].map(Int.init)
    }

    mutating func setInventoryQuantity(_ quantity: Int, at index: Int) throws {
        guard (0..<Self.inventoryCount).contains(index) else {
            throw SaveError.invalidInventoryIndex
        }
        guard (0...99).contains(quantity) else {
            throw SaveError.invalidStats
        }
        data[Self.inventoryOffset + index] = UInt8(quantity)
    }

    var characters: [FQ4CharacterRecord] {
        var result: [FQ4CharacterRecord] = []
        for index in 0..<Self.maximumCharacterRecords {
            let offset = characterOffset(index)
            let payload = data[(offset + 2)..<(offset + Self.characterRecordSize)]
            if !payload.contains(where: { $0 != 0 }) {
                break
            }
            if let record = character(index: index) {
                result.append(record)
            }
        }
        return result
    }

    func character(index: Int) -> FQ4CharacterRecord? {
        guard (0..<Self.maximumCharacterRecords).contains(index) else {
            return nil
        }
        let offset = characterOffset(index)
        let payload = data[(offset + 2)..<(offset + Self.characterRecordSize)]
        guard payload.contains(where: { $0 != 0 }) else {
            return nil
        }
        let statsOffset = offset + Self.characterStatsOffset
        let stats = FQ4CharacterStats(
            level: Int(data[statsOffset]),
            hitRate: Int(data[statsOffset + 1]),
            hitPoints: readUInt16(at: statsOffset + 2),
            attack: Int(data[statsOffset + 4]),
            attackRange: Int(data[statsOffset + 5]),
            defence: Int(data[statsOffset + 6]),
            defenceRange: Int(data[statsOffset + 7])
        )
        guard stats.isWithinNaturalLimits else {
            return nil
        }
        return FQ4CharacterRecord(
            id: index,
            internalID: readUInt16(at: offset),
            nameCode: readUInt16(at: offset + 2),
            classCode: Int(data[offset + Self.characterClassOffset]),
            factionCode: Int(data[offset + 0x0D]),
            heldItemID: Int(data[offset + 0x15]),
            stats: stats
        )
    }

    mutating func setCharacterStats(
        _ stats: FQ4CharacterStats,
        for index: Int
    ) throws {
        guard character(index: index) != nil else {
            throw SaveError.invalidCharacterRecord(index)
        }
        guard stats.isWithinNaturalLimits else {
            throw SaveError.invalidStats
        }

        let offset = characterOffset(index) + Self.characterStatsOffset
        data[offset] = UInt8(stats.level)
        data[offset + 1] = UInt8(stats.hitRate)
        writeUInt16(stats.hitPoints, at: offset + 2)
        data[offset + 4] = UInt8(stats.attack)
        data[offset + 5] = UInt8(stats.attackRange)
        data[offset + 6] = UInt8(stats.defence)
        data[offset + 7] = UInt8(stats.defenceRange)
    }

    mutating func setCharacterClass(_ classCode: Int, for index: Int) throws {
        guard character(index: index) != nil else {
            throw SaveError.invalidCharacterRecord(index)
        }
        guard (0...Self.maximumClassCode).contains(classCode) else {
            throw SaveError.invalidClassCode(classCode)
        }

        data[
            characterOffset(index) + Self.characterClassOffset
        ] = UInt8(classCode)
    }

    func originalClassCode(for index: Int) -> Int? {
        guard character(index: index) != nil else { return nil }
        return Int(
            originalData[
                characterOffset(index) + Self.characterClassOffset
            ]
        )
    }

    func changedCharacterIndices(comparedWith baseline: FQ4SaveFile?) -> Set<Int> {
        guard let baseline else { return [] }
        return Set((0..<Self.maximumCharacterRecords).filter { index in
            let current = character(index: index)
            let original = baseline.character(index: index)
            return current?.stats != original?.stats
                || current?.classCode != original?.classCode
        })
    }

    func validatePendingChanges() throws {
        let inventoryRange = Self.inventoryOffset..<(Self.inventoryOffset + Self.inventoryCount)
        let goldRange = Self.goldOffset..<(Self.goldOffset + 4)

        for offset in changedOffsets {
            if inventoryRange.contains(offset) || goldRange.contains(offset) {
                continue
            }
            let relative = offset - Self.characterTableOffset
            guard relative >= 0 else {
                throw SaveError.unsafeMutation
            }
            let withinRecord = relative % Self.characterRecordSize
            let recordIndex = relative / Self.characterRecordSize
            let isVerifiedCharacterField =
                withinRecord == Self.characterClassOffset
                || (Self.characterStatsOffset..<(Self.characterStatsOffset + 8))
                    .contains(withinRecord)
            guard recordIndex < Self.maximumCharacterRecords,
                  isVerifiedCharacterField
            else {
                throw SaveError.unsafeMutation
            }
        }
    }

    private func characterOffset(_ index: Int) -> Int {
        Self.characterTableOffset + (index * Self.characterRecordSize)
    }

    private func readUInt16(at offset: Int) -> Int {
        Int(data[offset]) | (Int(data[offset + 1]) << 8)
    }

    private func readUInt32(at offset: Int) -> Int {
        Int(data[offset])
            | (Int(data[offset + 1]) << 8)
            | (Int(data[offset + 2]) << 16)
            | (Int(data[offset + 3]) << 24)
    }

    private mutating func writeUInt16(_ value: Int, at offset: Int) {
        data[offset] = UInt8(value & 0xFF)
        data[offset + 1] = UInt8((value >> 8) & 0xFF)
    }

    private mutating func writeUInt32(_ value: Int, at offset: Int) {
        data[offset] = UInt8(value & 0xFF)
        data[offset + 1] = UInt8((value >> 8) & 0xFF)
        data[offset + 2] = UInt8((value >> 16) & 0xFF)
        data[offset + 3] = UInt8((value >> 24) & 0xFF)
    }
}

enum FQ4ItemCatalogue {
    static let names = [
        "Short Sword", "Long Sword", "Ice Sword", "Heat Sword",
        "Claymore", "Death Sword", "Cursed Sword", "Double-Edged Sword",
        "Assassin's Dagger", "Swallow-Reversal Sword", "Dragon-Slayer Sword",
        "Freezing Sword", "Lightning Sword", "Crushing Sword",
        "Scorching Sword", "Excalibur", "Halberd", "Partisan", "Ron's Spear",
        "Fighting God's Spear", "Battle Axe", "Destruction Axe", "Flail",
        "Morning Star", "Wizard's Staff", "Gambanteinn", "Magic Bow",
        "Ultimate Bow", "Obsession Bow", "Chainmail", "Plate Mail",
        "Scale Mail", "Tabard", "Silver Armor", "Gold Armor", "Mirror Armor",
        "Lion Armor", "Wind Veil", "Laughing Mask", "Medusa's Head",
        "Wolf Ring", "Tiger Ring", "Lion Ring", "Angel Ring", "Red Cross",
        "Fire Ward", "Earth Ward", "Wind Ward", "Water Ward", "Conch",
        "Caral Horn", "Vampire Flute", "Elf Flute", "Angel Flute",
        "Earth Whistle", "Water Whistle", "Wind Whistle", "Ballista Kit",
        "Light Stone", "Fire Stone", "Lightning Stone", "Ice Crystal",
        "Dark Stone", "Destruction Stone", "Eye Drops", "Bacchus Wine",
        "Ginseng Extract", "HP Recovery Medicine", "Fatigue Recovery Medicine",
        "Antidote", "Petrification Cure", "Revival Medicine",
    ]
}
