import SwiftUI

struct ClassOverrideView: View {
    @ObservedObject var editor: SaveEditorController
    let character: FQ4CharacterRecord

    @Environment(\.dismiss) private var dismiss
    @State private var riskFilter: FQ4ClassRisk
    @State private var searchText = ""
    @State private var selectedCode: Int
    @State private var showExperimentalConfirmation = false

    init(
        editor: SaveEditorController,
        character: FQ4CharacterRecord
    ) {
        self.editor = editor
        self.character = character
        _selectedCode = State(initialValue: character.classCode)
        let initialRisk = editor.classOption(for: character.classCode)?.risk
        _riskFilter = State(
            initialValue: initialRisk == .experimental ? .experimental : .standard
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header

            Rectangle()
                .fill(Palette.iron.opacity(0.28))
                .frame(height: 1)
                .padding(.top, 12)

            HStack(alignment: .top, spacing: 20) {
                catalogue
                classPreview
            }
            .padding(.top, 12)

            Spacer(minLength: 8)
            footer
        }
        .padding(.top, 18)
        .padding(.horizontal, 26)
        .padding(.bottom, 16)
        .frame(width: 660, height: 456)
        .background(Palette.smoke)
        .preferredColorScheme(.dark)
        .alert(
            "Stage experimental class?",
            isPresented: $showExperimentalConfirmation
        ) {
            Button("Cancel", role: .cancel) {}
            Button("Stage Class", role: .destructive) {
                stageSelection()
            }
        } message: {
            Text(
                "This changes only the class byte. Movement, attacks, sprites, "
                    + "or saving may behave unexpectedly. Stats, equipment, "
                    + "and faction stay unchanged."
            )
        }
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 5) {
                Text("CLASS OVERRIDE // EXPERT")
                    .font(.custom("Copperplate", size: 10))
                    .fontWeight(.bold)
                    .tracking(1.5)
                    .foregroundStyle(Palette.ember)
                Text("Field conversion order")
                    .font(.system(size: 24, weight: .semibold, design: .serif))
                    .foregroundStyle(Palette.ivory)
                Text(
                    editor.primaryName(for: character)
                        + " · "
                        + String(format: "RECORD %d / UNIT %04X", character.id + 1, character.internalID)
                )
                .font(.system(size: 8, weight: .medium, design: .monospaced))
                .foregroundStyle(Palette.silver.opacity(0.5))
            }
            Spacer()
            Text("ONE BYTE")
                .font(.system(size: 8, weight: .bold, design: .monospaced))
                .tracking(0.8)
                .foregroundStyle(Palette.sage)
                .padding(.horizontal, 9)
                .frame(height: 24)
                .overlay {
                    Rectangle()
                        .stroke(Palette.sage.opacity(0.7), lineWidth: 1)
                }
        }
    }

    private var catalogue: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 7) {
                riskButton(.standard)
                riskButton(.experimental)
            }

            TextField("Search class name or hex code", text: $searchText)
                .textFieldStyle(.plain)
                .font(.system(size: 9, design: .monospaced))
                .padding(.horizontal, 10)
                .frame(height: 29)
                .background(Palette.night.opacity(0.5))
                .overlay {
                    Rectangle()
                        .stroke(Palette.iron.opacity(0.3), lineWidth: 1)
                }

            ScrollView {
                LazyVStack(spacing: 3) {
                    ForEach(filteredOptions) { option in
                        classRow(option)
                    }
                }
            }
            .frame(height: 184)

            Text("Unsafe objects, artillery, multi-part units, and unused IDs are excluded.")
                .font(.system(size: 8))
                .lineSpacing(2)
                .foregroundStyle(Palette.silver.opacity(0.43))
        }
        .frame(width: 330)
    }

    private var classPreview: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("ORIGINAL CLASS ART")
                Spacer()
                Text("CHRBANK")
                    .foregroundStyle(Palette.sage)
            }
                .font(.system(size: 8, weight: .bold, design: .monospaced))
                .tracking(0.9)
                .foregroundStyle(Palette.silver.opacity(0.45))

            HStack(alignment: .center, spacing: 7) {
                spritePlate(
                    title: "CURRENT",
                    option: currentOption,
                    image: editor.classSprite(for: character.classCode)
                )
                Image(systemName: "arrow.right")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(Palette.ember)
                spritePlate(
                    title: "TARGET",
                    option: selectedOption,
                    image: editor.classSprite(for: selectedCode)
                )
            }

            Text("Original model · field pose · nearest-neighbour")
                .font(.system(size: 7, weight: .medium, design: .monospaced))
                .foregroundStyle(Palette.silver.opacity(0.36))

            if let option = selectedOption {
                Text(option.reason)
                    .font(.system(size: 9))
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
                    .foregroundStyle(
                        option.risk == .experimental
                            ? Palette.ember
                            : Palette.silver.opacity(0.62)
                    )
            }

            VStack(alignment: .leading, spacing: 5) {
                lockedLine("STATS", value: "UNCHANGED")
                lockedLine("EQUIPMENT", value: "UNCHANGED")
                lockedLine("FACTION", value: "LOCKED")
            }

            if editor.loadedClassCode != character.classCode {
                Button("RESTORE LOADED CLASS") {
                    editor.restoreLoadedClass()
                    selectedCode = editor.loadedClassCode ?? selectedCode
                }
                .buttonStyle(.plain)
                .font(.system(size: 8, weight: .bold, design: .monospaced))
                .foregroundStyle(Palette.ember)
            }
        }
        .frame(width: 258, alignment: .leading)
    }

    private func spritePlate(
        title: String,
        option: FQ4ClassOption?,
        image: NSImage?
    ) -> some View {
        VStack(spacing: 0) {
            HStack {
                Text(title)
                Spacer()
                Text(option?.codeLabel ?? "—")
                    .foregroundStyle(Palette.ember)
            }
            .font(.system(size: 7, weight: .bold, design: .monospaced))
            .tracking(0.6)
            .foregroundStyle(Palette.silver.opacity(0.48))
            .padding(.horizontal, 7)
            .frame(height: 21)

            ZStack(alignment: .bottom) {
                Palette.night.opacity(0.62)
                Rectangle()
                    .fill(Palette.iron.opacity(0.18))
                    .frame(height: 1)
                    .padding(.horizontal, 9)
                    .padding(.bottom, 12)
                if let image {
                    Image(nsImage: image)
                        .interpolation(.none)
                        .resizable()
                        .scaledToFit()
                        .padding(.vertical, 5)
                        .padding(.horizontal, 8)
                } else {
                    Text("NO ART")
                        .font(.system(size: 7, weight: .bold, design: .monospaced))
                        .foregroundStyle(Palette.silver.opacity(0.32))
                }
            }
            .frame(height: 98)

            Text(option?.primaryName ?? "Unknown")
                .font(.system(size: 8, weight: .semibold, design: .serif))
                .foregroundStyle(Palette.ivory)
                .lineLimit(1)
                .padding(.horizontal, 6)
                .frame(height: 23)
        }
        .frame(width: 112)
        .overlay {
            Rectangle()
                .stroke(Palette.iron.opacity(0.28), lineWidth: 1)
        }
    }

    private var footer: some View {
        HStack {
            Text("Disk remains untouched until APPLY CHANGES.")
                .font(.system(size: 8, weight: .medium, design: .monospaced))
                .foregroundStyle(Palette.sage)
            Spacer()
            Button("CANCEL") {
                dismiss()
            }
            .buttonStyle(.plain)
            .font(.system(size: 8, weight: .bold, design: .monospaced))
            .foregroundStyle(Palette.silver.opacity(0.7))

            Button(stageButtonTitle) {
                guard selectedOption?.risk == .experimental else {
                    stageSelection()
                    return
                }
                showExperimentalConfirmation = true
            }
            .buttonStyle(ClassStageButtonStyle(isExperimental: selectedOption?.risk == .experimental))
            .disabled(
                selectedOption == nil
                    || selectedOption?.risk == .unavailable
                    || selectedCode == character.classCode
            )
        }
        .frame(height: 32)
    }

    private var filteredOptions: [FQ4ClassOption] {
        let query = searchText
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .uppercased()
        return editor.classOptions.filter { option in
            guard option.risk == riskFilter else { return false }
            guard !query.isEmpty else { return true }
            return option.codeLabel.contains(query)
                || option.localizedName.uppercased().contains(query)
                || (option.englishName?.uppercased().contains(query) ?? false)
        }
    }

    private var currentOption: FQ4ClassOption? {
        editor.classOption(for: character.classCode)
    }

    private var selectedOption: FQ4ClassOption? {
        editor.classOption(for: selectedCode)
    }

    private var stageButtonTitle: String {
        selectedOption?.risk == .experimental
            ? "STAGE EXPERIMENTAL CLASS"
            : "STAGE CLASS CHANGE"
    }

    private func riskButton(_ risk: FQ4ClassRisk) -> some View {
        Button(risk.rawValue) {
            riskFilter = risk
            if editor.classOption(for: selectedCode)?.risk != risk {
                selectedCode = editor.classOptions.first(where: { $0.risk == risk })?.id
                    ?? selectedCode
            }
        }
        .buttonStyle(.plain)
        .font(.system(size: 8, weight: .bold, design: .monospaced))
        .tracking(0.5)
        .foregroundStyle(
            riskFilter == risk
                ? Palette.ivory
                : Palette.silver.opacity(0.42)
        )
        .padding(.horizontal, 10)
        .frame(height: 25)
        .background(
            riskFilter == risk
                ? risk == .experimental
                    ? Palette.ember.opacity(0.38)
                    : Palette.violet.opacity(0.44)
                : Palette.night.opacity(0.25)
        )
    }

    private func classRow(_ option: FQ4ClassOption) -> some View {
        Button {
            selectedCode = option.id
        } label: {
            HStack(spacing: 9) {
                Text(option.codeLabel)
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundStyle(Palette.ember)
                    .frame(width: 24, alignment: .leading)
                VStack(alignment: .leading, spacing: 2) {
                    Text(option.primaryName)
                        .font(.system(size: 10, weight: .semibold, design: .serif))
                    if let englishName = option.englishName {
                        Text(option.localizedName)
                            .font(.system(size: 8))
                            .foregroundStyle(Palette.silver.opacity(0.45))
                            .opacity(englishName == option.localizedName ? 0 : 1)
                    }
                }
                Spacer()
                if option.id == character.classCode {
                    Text("CURRENT")
                        .font(.system(size: 7, weight: .bold, design: .monospaced))
                        .foregroundStyle(Palette.sage)
                }
            }
            .foregroundStyle(Palette.silver)
            .padding(.horizontal, 9)
            .frame(height: 39)
            .background(
                selectedCode == option.id
                    ? Palette.violet.opacity(0.3)
                    : Palette.night.opacity(0.25)
            )
            .overlay(alignment: .leading) {
                if selectedCode == option.id {
                    Rectangle()
                        .fill(Palette.violet)
                        .frame(width: 2)
                }
            }
        }
        .buttonStyle(.plain)
    }

    private func lockedLine(_ label: String, value: String) -> some View {
        HStack {
            Text(label)
            Spacer()
            Text(value)
                .foregroundStyle(Palette.sage)
        }
        .font(.system(size: 8, weight: .bold, design: .monospaced))
        .foregroundStyle(Palette.silver.opacity(0.48))
    }

    private func stageSelection() {
        editor.stageSelectedCharacterClass(selectedCode)
        dismiss()
    }
}

private struct ClassStageButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    let isExperimental: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 8, weight: .bold, design: .monospaced))
            .tracking(0.6)
            .foregroundStyle(Palette.ivory.opacity(isEnabled ? 1 : 0.38))
            .padding(.horizontal, 13)
            .frame(height: 30)
            .background(
                isEnabled
                    ? (isExperimental ? Palette.ember : Palette.violet)
                        .opacity(configuration.isPressed ? 0.65 : 1)
                    : Palette.iron.opacity(0.22)
            )
    }
}
