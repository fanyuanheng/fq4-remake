import Foundation
import Testing
@testable import FQ4Wrapper

struct FQ4ClassSpriteArchiveTests {
    @Test
    func decodesEveryCompressionPipelineUsedByCharacterClasses() throws {
        let archive = try FQ4ClassSpriteArchive(
            data: Data(contentsOf: gameURL.appendingPathComponent("CHRBANK")),
            mainExecutableData: Data(
                contentsOf: gameURL.appendingPathComponent("MAIN.EXE")
            )
        )

        #expect(try archive.decodedPatternData(for: 0x00).count == 4_608)
        #expect(try archive.decodedPatternData(for: 0x01).count == 4_608)
        #expect(try archive.decodedPatternData(for: 0x06).count == 4_608)
        #expect(try archive.decodedPatternData(for: 0x5C).count == 4_608)
        #expect(try archive.decodedPatternData(for: 0xB0).count == 384)
    }

    @Test
    func rendersOneCoherentOriginalPoseInsteadOfInterleavedPlanes() throws {
        let archive = try FQ4ClassSpriteArchive(
            data: Data(contentsOf: gameURL.appendingPathComponent("CHRBANK")),
            mainExecutableData: Data(
                contentsOf: gameURL.appendingPathComponent("MAIN.EXE")
            )
        )
        let page = try archive.representativePage(for: 0x00)

        #expect(page.width == 32)
        #expect(page.height == 32)
        #expect(page.pixels.count == 1_024)
        #expect(page.pixels.contains { $0 != 0 })
        #expect(fnv1a(page.pixels) == 0x5B40A08741232893)
    }

    @Test
    func everyEditableClassHasACompleteOriginalPose() throws {
        let archive = try FQ4ClassSpriteArchive(
            data: Data(contentsOf: gameURL.appendingPathComponent("CHRBANK")),
            mainExecutableData: Data(
                contentsOf: gameURL.appendingPathComponent("MAIN.EXE")
            )
        )

        for classCode in 0...0xDB {
            let page = try archive.representativePage(for: classCode)
            #expect(page.width > 0)
            #expect(page.height > 0)
            #expect(page.pixels.count == page.width * page.height)
        }
    }

    private var gameURL: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("FQ4", isDirectory: true)
    }

    private func fnv1a(_ bytes: [UInt8]) -> UInt64 {
        bytes.reduce(0xCBF29CE484222325) { hash, byte in
            (hash ^ UInt64(byte)) &* 0x100000001B3
        }
    }
}
