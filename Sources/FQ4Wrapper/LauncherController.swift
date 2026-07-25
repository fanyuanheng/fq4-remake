import AppKit
import Foundation

enum LauncherPhase: Equatable {
    case ready
    case preparing
    case running
    case stopped
    case failed(String)
}

@MainActor
final class LauncherController: ObservableObject {
    @Published private(set) var phase: LauncherPhase = .ready
    @Published private(set) var gameURL: URL?

    private var gameProcess: Process?

    var statusTitle: String {
        switch phase {
        case .ready:
            return "Ready to play"
        case .preparing:
            return "Preparing your game"
        case .running:
            return "FQ4 is running"
        case .stopped:
            return "Game closed"
        case .failed:
            return "Needs attention"
        }
    }

    var statusDetail: String {
        switch phase {
        case .ready:
            return "The original DOS release will open through DOSBox Staging."
        case .preparing:
            return "Creating a private writable copy for saves and settings."
        case .running:
            return "Return here after quitting the DOS window to play again."
        case .stopped:
            return "Your save files are kept safely in Application Support."
        case .failed(let message):
            return message
        }
    }

    var canLaunch: Bool {
        phase != .preparing && phase != .running
    }

    var isGameRunning: Bool {
        phase == .running
    }

    var needsDOSBox: Bool {
        if case .failed(let message) = phase {
            return message.contains("DOSBox Staging")
        }
        return false
    }

    func prepareGameFiles() {
        guard gameURL == nil else { return }
        do {
            gameURL = try preparedGameURL()
        } catch {
            phase = .failed(error.localizedDescription)
        }
    }

    func launch(fullscreen: Bool) {
        guard canLaunch else { return }
        phase = .preparing

        do {
            let preparedURL = try gameURL ?? preparedGameURL()
            gameURL = preparedURL

            guard let executableURL = locateDOSBox() else {
                phase = .failed(
                    "Install DOSBox Staging in Applications, then choose Play again."
                )
                return
            }

            let process = Process()
            process.executableURL = executableURL
            process.currentDirectoryURL = preparedURL
            process.arguments = GameInstallation.dosBoxArguments(
                gameURL: preparedURL,
                fullscreen: fullscreen
            )
            process.terminationHandler = { [weak self] process in
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    self.gameProcess = nil
                    self.phase = process.terminationStatus == 0
                        ? .stopped
                        : .failed("DOSBox exited with code \(process.terminationStatus).")
                }
            }

            try process.run()
            gameProcess = process
            phase = .running
        } catch {
            phase = .failed(error.localizedDescription)
        }
    }

    func revealGameFiles() {
        guard let gameURL else { return }
        NSWorkspace.shared.activateFileViewerSelecting([gameURL])
    }

    func openDOSBoxWebsite() {
        guard let url = URL(string: "https://www.dosbox-staging.org/") else {
            return
        }
        NSWorkspace.shared.open(url)
    }

    private func locateDOSBox() -> URL? {
        let fileManager = FileManager.default
        let knownPaths = [
            "/Applications/DOSBox Staging.app/Contents/MacOS/dosbox",
            "\(NSHomeDirectory())/Applications/DOSBox Staging.app/Contents/MacOS/dosbox",
        ]
        if let path = knownPaths.first(
            where: { fileManager.isExecutableFile(atPath: $0) }
        ) {
            return URL(fileURLWithPath: path)
        }
        guard let appURL = NSWorkspace.shared.urlForApplication(
            withBundleIdentifier: "io.github.dosbox-staging"
        ) else {
            return nil
        }
        let executableURL = appURL.appendingPathComponent(
            "Contents/MacOS/dosbox"
        )
        return fileManager.isExecutableFile(atPath: executableURL.path)
            ? executableURL
            : nil
    }

    private func preparedGameURL() throws -> URL {
        guard let sourceURL = Bundle.main.resourceURL?
            .appendingPathComponent("FQ4", isDirectory: true)
        else {
            throw GameInstallation.InstallationError.missingSource
        }
        guard let supportURL = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first else {
            throw CocoaError(.fileNoSuchFile)
        }
        return try GameInstallation().prepare(
            sourceURL: sourceURL,
            applicationSupportURL: supportURL
        )
    }
}
