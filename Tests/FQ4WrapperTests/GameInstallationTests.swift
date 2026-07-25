import Foundation
import Testing
@testable import FQ4Wrapper

struct GameInstallationTests {
    @Test
    func preparesWritableCopyWithoutOverwritingExistingSaves() throws {
        let fileManager = FileManager.default
        let temporaryURL = fileManager.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? fileManager.removeItem(at: temporaryURL) }

        let sourceURL = temporaryURL.appendingPathComponent(
            "Original",
            isDirectory: true
        )
        try fileManager.createDirectory(
            at: sourceURL,
            withIntermediateDirectories: true
        )
        for name in GameInstallation.requiredFiles {
            try Data(name.utf8).write(
                to: sourceURL.appendingPathComponent(name)
            )
        }

        let supportURL = temporaryURL.appendingPathComponent(
            "Support",
            isDirectory: true
        )
        let installation = GameInstallation(fileManager: fileManager)
        let gameURL = try installation.prepare(
            sourceURL: sourceURL,
            applicationSupportURL: supportURL
        )
        let saveURL = gameURL.appendingPathComponent("SAVE.DAT")
        try Data("player progress".utf8).write(to: saveURL)

        let secondURL = try installation.prepare(
            sourceURL: sourceURL,
            applicationSupportURL: supportURL
        )

        #expect(gameURL == secondURL)
        #expect(try String(contentsOf: saveURL, encoding: .utf8) == "player progress")
    }

    @Test
    func buildsIsolatedDOSBoxArguments() {
        let gameURL = URL(fileURLWithPath: "/tmp/FQ4")
        let windowed = GameInstallation.dosBoxArguments(
            gameURL: gameURL,
            fullscreen: false
        )
        let fullscreen = GameInstallation.dosBoxArguments(
            gameURL: gameURL,
            fullscreen: true
        )

        #expect(windowed.contains("--noprimaryconf"))
        #expect(windowed.contains("--nolocalconf"))
        #expect(windowed.contains("cpu_cycles=25000"))
        #expect(windowed.last == "/tmp/FQ4/PLAY.BAT")
        #expect(!windowed.contains("--fullscreen"))
        #expect(fullscreen.contains("--fullscreen"))
    }
}
