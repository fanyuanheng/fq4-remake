import CoreFoundation
import Foundation

struct FQ4CharacterNameCatalogue {
    enum CatalogueError: LocalizedError {
        case truncatedExecutable
        case invalidEntry(Int)

        var errorDescription: String? {
            switch self {
            case .truncatedExecutable:
                return "The character-name table is missing from MAIN.EXE."
            case .invalidEntry(let index):
                return "Character name \(index) could not be decoded."
            }
        }
    }

    static let tableOffset = 0x2EB9A
    static let entryCount = 652

    private static let terminator = Data([0xFE, 0xFE, 0x00])
    private static let big5Encoding = String.Encoding(
        rawValue: CFStringConvertEncodingToNSStringEncoding(
            CFStringEncoding(0x0A03)
        )
    )

    private static let englishAliases: [Int: String] = [
        0x0018: "Alfred",
        0x001A: "Ares",
        0x0098: "Conrad",
        0x01BE: "Lamorak",
        0x0209: "Elaine",
    ]

    let names: [String]

    init(mainExecutableData: Data) throws {
        guard mainExecutableData.count > Self.tableOffset else {
            throw CatalogueError.truncatedExecutable
        }

        var cursor = Self.tableOffset
        var parsedNames: [String] = []
        parsedNames.reserveCapacity(Self.entryCount)

        for index in 0..<Self.entryCount {
            guard let range = mainExecutableData.range(
                of: Self.terminator,
                in: cursor..<mainExecutableData.count
            ) else {
                throw CatalogueError.truncatedExecutable
            }

            let encodedName = mainExecutableData[cursor..<range.lowerBound]
            guard let name = String(
                data: encodedName,
                encoding: Self.big5Encoding
            ) else {
                throw CatalogueError.invalidEntry(index)
            }

            parsedNames.append(
                name.trimmingCharacters(in: .whitespacesAndNewlines)
            )
            cursor = range.upperBound
        }

        names = parsedNames
    }

    func localizedName(for nameCode: Int) -> String? {
        guard names.indices.contains(nameCode) else { return nil }
        let name = names[nameCode]
        return name.isEmpty ? nil : name
    }

    func englishAlias(for nameCode: Int) -> String? {
        Self.englishAliases[nameCode]
    }

    func primaryName(for nameCode: Int) -> String {
        englishAlias(for: nameCode)
            ?? localizedName(for: nameCode)
            ?? String(format: "Name %04X", nameCode)
    }
}
