import CoreFoundation
import Foundation

enum FQ4ClassRisk: String, CaseIterable, Identifiable {
    case standard = "STANDARD"
    case experimental = "EXPERIMENTAL"
    case unavailable = "UNAVAILABLE"

    var id: String { rawValue }
}

struct FQ4ClassOption: Identifiable, Equatable {
    let id: Int
    let localizedName: String
    let englishName: String?
    let risk: FQ4ClassRisk
    let reason: String

    var codeLabel: String {
        String(format: "%02X", id)
    }

    var primaryName: String {
        englishName ?? localizedName
    }

    var displayName: String {
        guard let englishName else { return localizedName }
        return "\(englishName) · \(localizedName)"
    }
}

struct FQ4CharacterClassCatalogue {
    enum CatalogueError: LocalizedError {
        case truncatedExecutable
        case invalidEntry(Int)

        var errorDescription: String? {
            switch self {
            case .truncatedExecutable:
                return "The character-class table is missing from MAIN.EXE."
            case .invalidEntry(let index):
                return "Character class \(index) could not be decoded."
            }
        }
    }

    static let tableOffset = 0x3013D
    static let entryCount = 220
    static let entrySize = 9

    private static let big5Encoding = String.Encoding(
        rawValue: CFStringConvertEncodingToNSStringEncoding(
            CFStringEncoding(0x0A03)
        )
    )

    private static let unavailableCodes: Set<Int> = [
        0x06, 0x1A,
        0xAE, 0xAF, 0xB0, 0xB1, 0xB2, 0xB7,
        0xC7, 0xC8, 0xC9, 0xCA,
    ]

    private static let standardCodes: Set<Int> = {
        var codes = Set(0x00...0x1D)
        codes.formUnion(0x23...0x58)
        codes.formUnion(0x74...0x84)
        codes.formUnion(0xBA...0xC6)
        codes.subtract([
            0x06, 0x1A, 0x26, 0x28, 0x2C, 0x2D, 0x2E, 0x31, 0x33,
        ])
        return codes
    }()

    private static let englishNames: [String: String] = [
        "國王": "King", "勇士": "Hero", "王子": "Prince",
        "銀騎士": "Silver Knight", "法師": "Mage", "學者": "Scholar",
        "指揮官": "Commander", "阿瑪族": "Amazon", "驅魔者": "Exorcist",
        "護士": "Healer", "魔女": "Witch", "怪獸人": "Beastman",
        "軍師": "Strategist", "僧侶": "Cleric", "修道士": "Monk",
        "尼僧": "Nun", "店魔女": "Shop Witch", "兄弟": "Brother",
        "騎士": "Knight", "小偷": "Thief", "忍者": "Ninja",
        "大魔頭": "Demon Lord", "四天王": "Four General",
        "探查機": "Scout Machine", "黑騎士": "Black Knight",
        "次公爵": "Vice Duke", "公爵": "Duke", "紅戰士": "Red Warrior",
        "死靈": "Necromancer", "魔頭": "Demon Lord", "紅公爵": "Red Duke",
        "野武士": "Ronin", "攻擊手": "Striker", "紅騎士": "Red Knight",
        "暗戰士": "Dark Warrior", "劍士": "Swordsman", "隊員": "Trooper",
        "弓騎士": "Bow Knight", "Ｂ士兵": "Blue Soldier",
        "Ｂ戰士": "Blue Warrior", "Ｂ弓兵": "Blue Archer",
        "Ｍ雷母": "M Raymother", "Ｉ雷母": "I Raymother",
        "Ｃ雷母": "C Raymother", "製圖家": "Cartographer",
        "Ｒ士兵": "Red Soldier", "Ｒ弓兵": "Red Archer",
        "普騎士": "Common Knight", "白戰士": "White Warrior",
        "槍兵": "Lancer", "誘導槍": "Guided Lancer", "皇后": "Queen",
        "詩人": "Bard", "綠騎士": "Green Knight", "Ｇ士兵": "Green Soldier",
        "Ｇ戰士": "Green Warrior", "士兵": "Soldier", "戰士": "Warrior",
        "狙擊手": "Sniper", "弓箭手": "Archer", "天使": "Angel",
        "鬼神": "Demon", "還魂": "Revenant", "骸骨": "Skeleton",
        "鬼": "Ghost", "哥布林": "Goblin", "鳥人": "Birdman",
        "歐格": "Ogre", "鱷魚": "Crocodile", "大鱷魚": "Great Crocodile",
        "熊人": "Bearman", "狼人": "Werewolf", "精靈王": "Fairy King",
        "精靈": "Fairy", "大精靈": "High Fairy", "靈魔女": "Spirit Witch",
        "鳥弓": "Bird Archer", "鳥騎士": "Bird Knight", "海盜": "Pirate",
        "大海盜": "Pirate Captain", "克學士": "Scholar", "槍學士": "Gun Scholar",
        "守衛": "Guard", "水之王": "Water King", "地之王": "Earth King",
        "風之王": "Wind King", "土精靈": "Earth Spirit", "靈媒": "Medium",
        "狼族": "Wolf Clan", "學士": "Sage", "狩獵者": "Hunter",
        "虎族": "Tiger Clan", "熊貓": "Panda", "鳥龜族": "Turtle Clan",
        "恐龍族": "Dinosaur Clan", "人面鷲": "Harpy", "盜賊": "Bandit",
        "海獸": "Sea Beast", "蜈蚣": "Centipede", "螃蠍": "Crab Scorpion",
        "蝎子": "Scorpion", "老鼠": "Rat", "公雞": "Rooster",
        "蝸牛": "Snail", "蛇": "Snake", "山貓": "Lynx",
        "小恐龍": "Young Dinosaur", "人造人": "Construct",
        "香菇": "Mushroom", "大老鼠": "Giant Rat", "蜥蜴": "Lizard",
        "海龍": "Sea Dragon", "食人花": "Man-Eating Plant",
        "石像": "Statue", "水晶球": "Crystal Ball", "花": "Flower",
        "陷井": "Trap", "大砲": "Cannon", "飛龍": "Flying Dragon",
        "射出機": "Launcher", "男爵士": "Baron", "馬騎士": "Mounted Knight",
        "怪物": "Monster", "古蜻蜓": "Ancient Dragonfly", "騎兵": "Cavalry",
        "地獄獸": "Hell Beast", "小雞": "Chick", "吸血鬼": "Vampire",
        "克利風": "Griffin", "巨人": "Giant", "攻雷母": "Attack Raymother",
        "龍騎兵": "Dragoon", "吸寫鬼": "Bloodsucker", "保護者": "Guardian",
        "曼蒂可": "Manticore",
    ]

    let options: [FQ4ClassOption]

    init(mainExecutableData: Data) throws {
        let tableEnd = Self.tableOffset + (Self.entryCount * Self.entrySize)
        guard mainExecutableData.count >= tableEnd else {
            throw CatalogueError.truncatedExecutable
        }

        options = try (0..<Self.entryCount).map { index in
            let offset = Self.tableOffset + (index * Self.entrySize)
            let entry = mainExecutableData[offset..<(offset + Self.entrySize)]
            let nameBytes = entry.prefix(while: { $0 != 0xFE && $0 != 0x00 })
            guard let name = String(
                data: nameBytes,
                encoding: Self.big5Encoding
            ) else {
                throw CatalogueError.invalidEntry(index)
            }
            let localizedName = name.trimmingCharacters(
                in: .whitespacesAndNewlines
            )
            let risk = Self.risk(for: index)
            return FQ4ClassOption(
                id: index,
                localizedName: localizedName,
                englishName: Self.englishNames[localizedName],
                risk: risk,
                reason: Self.reason(for: index, risk: risk)
            )
        }
    }

    func option(for code: Int) -> FQ4ClassOption? {
        guard options.indices.contains(code) else { return nil }
        return options[code]
    }

    private static func risk(for code: Int) -> FQ4ClassRisk {
        if unavailableCodes.contains(code) {
            return .unavailable
        }
        if standardCodes.contains(code) {
            return .standard
        }
        return .experimental
    }

    private static func reason(
        for code: Int,
        risk: FQ4ClassRisk
    ) -> String {
        switch risk {
        case .standard:
            return "Ordinary humanoid or game-supported role."
        case .experimental:
            return "Enemy, monster, boss, mounted, or special-behavior archetype."
        case .unavailable:
            if code == 0x06 || code == 0x1A {
                return "Defined label, but no canonical active unit template."
            }
            if (0xC7...0xCA).contains(code) {
                return "Multi-part dragon component; unsafe as a standalone character."
            }
            return "Map object or fixed emplacement; unsafe as a character class."
        }
    }
}
