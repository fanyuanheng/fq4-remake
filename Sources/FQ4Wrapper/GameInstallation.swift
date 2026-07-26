import Foundation

struct GameInstallation {
    enum InstallationError: LocalizedError {
        case missingSource
        case incompleteSource(String)
        case incompleteCopy(String)

        var errorDescription: String? {
            switch self {
            case .missingSource:
                return "The original FQ4 files are missing from this app."
            case .incompleteSource(let name):
                return "The bundled FQ4 folder is missing \(name)."
            case .incompleteCopy(let name):
                return "The writable FQ4 folder is missing \(name)."
            }
        }
    }

    static let requiredFiles = ["MAIN.EXE", "FQ4OPN.EXE", "PLAY.BAT"]
    // Keep the legacy support path so existing saves survive the app rename.
    static let supportFolderName = "FQ4 Wrapper"

    let fileManager: FileManager

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    func prepare(
        sourceURL: URL,
        applicationSupportURL: URL
    ) throws -> URL {
        guard fileManager.fileExists(atPath: sourceURL.path) else {
            throw InstallationError.missingSource
        }
        try validate(sourceURL, error: InstallationError.incompleteSource)

        let wrapperURL = applicationSupportURL
            .appendingPathComponent(Self.supportFolderName, isDirectory: true)
        let gameURL = wrapperURL.appendingPathComponent("FQ4", isDirectory: true)

        if !fileManager.fileExists(atPath: gameURL.path) {
            try fileManager.createDirectory(
                at: wrapperURL,
                withIntermediateDirectories: true
            )
            try fileManager.copyItem(at: sourceURL, to: gameURL)
        }

        try validate(gameURL, error: InstallationError.incompleteCopy)
        return gameURL
    }

    static func dosBoxArguments(
        gameURL: URL,
        fullscreen: Bool
    ) -> [String] {
        var arguments = [
            "--noprimaryconf",
            "--nolocalconf",
            "--set", "cpu_cycles=25000",
            "--set", "aspect=true",
            "--set", "integer_scaling=auto",
        ]
        if fullscreen {
            arguments.append("--fullscreen")
        }
        arguments.append(
            gameURL.appendingPathComponent("PLAY.BAT").path
        )
        return arguments
    }

    private func validate(
        _ directory: URL,
        error: (String) -> InstallationError
    ) throws {
        for name in Self.requiredFiles {
            let fileURL = directory.appendingPathComponent(name)
            guard fileManager.fileExists(atPath: fileURL.path) else {
                throw error(name)
            }
        }
    }
}
