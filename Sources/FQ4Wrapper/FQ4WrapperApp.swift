import AppKit
import SwiftUI

enum Palette {
    static let night = Color(red: 0.045, green: 0.04, blue: 0.05)
    static let smoke = Color(red: 0.105, green: 0.095, blue: 0.125)
    static let iron = Color(red: 0.40, green: 0.41, blue: 0.42)
    static let silver = Color(red: 0.80, green: 0.78, blue: 0.75)
    static let ivory = Color(red: 0.93, green: 0.90, blue: 0.84)
    static let violet = Color(red: 0.43, green: 0.24, blue: 0.60)
    static let ember = Color(red: 0.82, green: 0.42, blue: 0.22)
    static let sage = Color(red: 0.42, green: 0.49, blue: 0.39)
}

@main
struct FQ4WrapperApp: App {
    @StateObject private var launcher = LauncherController()
    @AppStorage("launchFullscreen") private var launchFullscreen = true

    var body: some Scene {
        WindowGroup("FQ4 Wrapper") {
            LauncherView(
                launcher: launcher,
                launchFullscreen: $launchFullscreen
            )
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .defaultSize(width: 820, height: 500)
        .commands {
            CommandGroup(replacing: .newItem) {}
        }
    }
}

private struct LauncherView: View {
    @ObservedObject var launcher: LauncherController
    @Binding var launchFullscreen: Bool
    @StateObject private var saveEditor = SaveEditorController()
    @State private var destination: LauncherDestination = .play

    var body: some View {
        ZStack(alignment: .topTrailing) {
            switch destination {
            case .play:
                HStack(spacing: 0) {
                    artworkPanel
                    launchPanel
                }
            case .saveEditor:
                SaveEditorView(
                    editor: saveEditor,
                    gameIsRunning: launcher.isGameRunning
                )
            }

            LauncherDestinationPicker(destination: $destination)
                .padding(.top, 18)
                .padding(.trailing, 20)
        }
        .frame(width: 820, height: 500)
        .background(Palette.night)
        .preferredColorScheme(.dark)
        .onAppear {
            launcher.prepareGameFiles()
            loadEditorIfReady()
        }
        .onChange(of: launcher.gameURL) { _ in
            loadEditorIfReady()
        }
    }

    private func loadEditorIfReady() {
        guard let gameURL = launcher.gameURL else { return }
        let baselineURL = Bundle.main.resourceURL?
            .appendingPathComponent("FQ4", isDirectory: true)
        saveEditor.reload(
            gameURL: gameURL,
            baselineGameURL: baselineURL
        )
    }

    private var artworkPanel: some View {
        VStack(spacing: 0) {
            HStack {
                Text("ARCHIVE // 1994")
                Spacer()
                Text("DOS")
            }
            .font(.system(size: 9, weight: .semibold, design: .monospaced))
            .tracking(1.2)
            .foregroundStyle(Palette.silver.opacity(0.62))

            Spacer(minLength: 24)

            coverArtwork
                .frame(width: 390, height: 292)
                .overlay {
                    Rectangle()
                        .stroke(Palette.silver.opacity(0.16), lineWidth: 1)
                }
                .shadow(color: .black.opacity(0.5), radius: 18, y: 8)

            Spacer(minLength: 22)

            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 5) {
                    Text("ORIGINAL COVER")
                        .font(.system(size: 9, weight: .semibold, design: .monospaced))
                        .tracking(1.3)
                        .foregroundStyle(Palette.ember)
                    Text("First Queen IV")
                        .font(.system(size: 17, weight: .semibold, design: .serif))
                        .foregroundStyle(Palette.ivory)
                }
                Spacer()
                Text("PERSONAL EDITION")
                    .font(.system(size: 8, weight: .medium, design: .monospaced))
                    .tracking(1.1)
                    .foregroundStyle(Palette.silver.opacity(0.48))
            }
        }
        .padding(.top, 28)
        .padding(.horizontal, 24)
        .padding(.bottom, 24)
        .frame(width: 438)
        .background(Palette.night)
    }

    @ViewBuilder
    private var coverArtwork: some View {
        if let url = Bundle.main.url(
            forResource: "FirstQueenIVCover",
            withExtension: "png"
        ), let image = NSImage(contentsOf: url) {
            Image(nsImage: image)
                .resizable()
                .scaledToFit()
        } else {
            ZStack {
                Palette.smoke
                Text("FIRST QUEEN IV")
                    .font(.system(size: 18, weight: .bold, design: .serif))
                    .foregroundStyle(Palette.ivory)
            }
        }
    }

    private var launchPanel: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("FIRST QUEEN IV")
                .font(.custom("Copperplate", size: 12))
                .fontWeight(.bold)
                .tracking(2.1)
                .foregroundStyle(Palette.ember)

            Text("The kingdom is waiting.")
                .font(.system(size: 29, weight: .semibold, design: .serif))
                .foregroundStyle(Palette.ivory)
                .padding(.top, 10)

            HStack(spacing: 7) {
                Rectangle()
                    .fill(Palette.violet)
                    .frame(width: 38, height: 2)
                Rectangle()
                    .fill(Palette.iron.opacity(0.45))
                    .frame(height: 1)
            }
            .padding(.vertical, 24)

            HStack(alignment: .top, spacing: 12) {
                Circle()
                    .fill(statusColour)
                    .frame(width: 8, height: 8)
                    .padding(.top, 5)
                VStack(alignment: .leading, spacing: 5) {
                    Text(launcher.statusTitle)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Palette.ivory)
                    Text(launcher.statusDetail)
                        .font(.system(size: 12))
                        .foregroundStyle(Palette.silver.opacity(0.72))
                        .lineSpacing(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(minHeight: 68, alignment: .top)

            Button {
                launcher.launch(fullscreen: launchFullscreen)
            } label: {
                HStack {
                    Text(launcher.phase == .running ? "GAME IS RUNNING" : "PLAY FQ4")
                    Spacer()
                    Text("↗")
                        .font(.system(size: 18, weight: .regular))
                }
            }
            .buttonStyle(LaunchButtonStyle())
            .disabled(!launcher.canLaunch)
            .accessibilityIdentifier("playFQ4")
            .padding(.top, 16)

            HStack(spacing: 14) {
                Toggle("Start in full screen", isOn: $launchFullscreen)
                    .toggleStyle(.checkbox)
                    .font(.system(size: 11))
                    .foregroundStyle(Palette.silver)

                Spacer()

                if launcher.needsDOSBox {
                    Button("Get DOSBox Staging") {
                        launcher.openDOSBoxWebsite()
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(Palette.ember)
                } else {
                    Button("Game files") {
                        launcher.revealGameFiles()
                    }
                    .buttonStyle(.plain)
                    .disabled(launcher.gameURL == nil)
                    .foregroundStyle(Palette.silver)
                }
            }
            .font(.system(size: 10, weight: .medium))
            .padding(.top, 17)

            Spacer()

            VStack(spacing: 10) {
                HStack {
                    Text("EMULATED CPU")
                    Spacer()
                    Text("25,000 CYCLES")
                        .foregroundStyle(Palette.ivory)
                }
                Rectangle()
                    .fill(Palette.iron.opacity(0.34))
                    .frame(height: 1)
                HStack {
                    Text("ORIGINALS PROTECTED")
                    Spacer()
                    Text("SAVES STORED SEPARATELY")
                }
            }
            .font(.system(size: 8, weight: .semibold, design: .monospaced))
            .tracking(0.8)
            .foregroundStyle(Palette.silver.opacity(0.48))
        }
        .padding(.top, 38)
        .padding(.horizontal, 32)
        .padding(.bottom, 27)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Palette.smoke)
        .overlay(alignment: .leading) {
            Rectangle()
                .fill(Palette.violet.opacity(0.72))
                .frame(width: 1)
        }
    }

    private var statusColour: Color {
        switch launcher.phase {
        case .ready, .stopped:
            return Palette.sage
        case .preparing:
            return Palette.ember
        case .running:
            return Palette.violet
        case .failed:
            return .red
        }
    }
}

private enum LauncherDestination: String, CaseIterable {
    case play = "PLAY"
    case saveEditor = "SAVE EDITOR"
}

private struct LauncherDestinationPicker: View {
    @Binding var destination: LauncherDestination

    var body: some View {
        HStack(spacing: 3) {
            ForEach(LauncherDestination.allCases, id: \.self) { item in
                Button(item.rawValue) {
                    destination = item
                }
                .buttonStyle(.plain)
                .font(.system(size: 8, weight: .bold, design: .monospaced))
                .tracking(0.9)
                .foregroundStyle(
                    destination == item
                        ? Palette.ivory
                        : Palette.silver.opacity(0.52)
                )
                .padding(.horizontal, 10)
                .frame(height: 24)
                .background(
                    destination == item
                        ? Palette.violet.opacity(0.9)
                        : Color.clear
                )
                .overlay {
                    Rectangle()
                        .stroke(
                            destination == item
                                ? Color.clear
                                : Palette.iron.opacity(0.28),
                            lineWidth: 1
                        )
                }
            }
        }
    }
}

private struct LaunchButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 11, weight: .bold, design: .monospaced))
            .tracking(1.2)
            .foregroundStyle(Palette.ivory.opacity(isEnabled ? 1 : 0.62))
            .padding(.horizontal, 17)
            .frame(height: 46)
            .background(
                !isEnabled
                    ? Palette.violet.opacity(0.42)
                    : configuration.isPressed
                    ? Palette.ember
                    : Palette.violet
            )
            .contentShape(Rectangle())
            .opacity(configuration.isPressed ? 0.88 : 1)
    }
}
