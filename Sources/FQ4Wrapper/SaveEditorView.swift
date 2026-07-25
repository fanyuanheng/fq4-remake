import SwiftUI

struct SaveEditorView: View {
    @ObservedObject var editor: SaveEditorController
    let gameIsRunning: Bool
    @State private var showSaveConfirmation = false
    @State private var showRestoreConfirmation = false
    @State private var showClassOverride = false

    var body: some View {
        HStack(spacing: 0) {
            slotRail
            editorPanel
        }
        .frame(width: 820, height: 500)
        .background(Palette.night)
        .alert(
            "Apply changes to Slot \(editor.selectedSlot + 1)?",
            isPresented: $showSaveConfirmation
        ) {
            Button("Cancel", role: .cancel) {}
            Button("Apply Changes") {
                editor.applyChanges(gameIsRunning: gameIsRunning)
            }
        } message: {
            Text(
                "\(editor.pendingByteCount) bytes will change. "
                    + "A timestamped backup will be created first."
            )
        }
        .alert(
            "Restore the previous save?",
            isPresented: $showRestoreConfirmation
        ) {
            Button("Cancel", role: .cancel) {}
            Button("Restore Backup") {
                editor.restoreLastBackup(gameIsRunning: gameIsRunning)
            }
        } message: {
            Text("This restores the backup created by the last edit in this session.")
        }
        .sheet(isPresented: $showClassOverride) {
            if let character = editor.selectedCharacter {
                ClassOverrideView(
                    editor: editor,
                    character: character
                )
            }
        }
    }

    private var slotRail: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("SAVE ARCHIVE")
                .font(.custom("Copperplate", size: 11))
                .fontWeight(.bold)
                .tracking(1.8)
                .foregroundStyle(Palette.ember)

            Text("Four field records")
                .font(.system(size: 19, weight: .semibold, design: .serif))
                .foregroundStyle(Palette.ivory)
                .padding(.top, 8)

            Rectangle()
                .fill(Palette.violet)
                .frame(width: 34, height: 2)
                .padding(.top, 18)
                .padding(.bottom, 18)

            VStack(spacing: 6) {
                ForEach(editor.slots) { slot in
                    Button {
                        editor.chooseSlot(slot.id)
                    } label: {
                        HStack(spacing: 11) {
                            Text(String(format: "%02d", slot.id + 1))
                                .font(.system(size: 16, weight: .medium, design: .monospaced))
                                .foregroundStyle(
                                    editor.selectedSlot == slot.id
                                        ? Palette.ivory
                                        : Palette.silver.opacity(0.5)
                                )
                            VStack(alignment: .leading, spacing: 3) {
                                Text(slot.filename)
                                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                                Text(slotDetail(slot))
                                    .font(.system(size: 9))
                                    .foregroundStyle(Palette.silver.opacity(0.5))
                            }
                            Spacer()
                            Circle()
                                .fill(slot.isValid ? Palette.sage : Palette.iron)
                                .frame(width: 6, height: 6)
                        }
                        .foregroundStyle(Palette.silver)
                        .padding(.horizontal, 11)
                        .frame(height: 54)
                        .background(
                            editor.selectedSlot == slot.id
                                ? Palette.violet.opacity(0.22)
                                : Color.clear
                        )
                        .overlay(alignment: .leading) {
                            if editor.selectedSlot == slot.id {
                                Rectangle()
                                    .fill(Palette.violet)
                                    .frame(width: 2)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
            }

            Spacer()

            VStack(alignment: .leading, spacing: 7) {
                Label("ORIGINALS PROTECTED", systemImage: "lock.fill")
                Text("Every write creates a timestamped backup.")
                    .font(.system(size: 9))
                    .lineSpacing(2)
                    .foregroundStyle(Palette.silver.opacity(0.48))
            }
            .font(.system(size: 8, weight: .semibold, design: .monospaced))
            .tracking(0.6)
            .foregroundStyle(Palette.sage)
        }
        .padding(.top, 31)
        .padding(.horizontal, 20)
        .padding(.bottom, 24)
        .frame(width: 212)
        .frame(maxHeight: .infinity)
        .background(Palette.night)
    }

    private var editorPanel: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("SLOT \(editor.selectedSlot + 1)")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .tracking(1.2)
                        .foregroundStyle(Palette.ember)
                    Text(sectionTitle)
                        .font(.system(size: 24, weight: .semibold, design: .serif))
                        .foregroundStyle(Palette.ivory)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 5) {
                    Text(gameIsRunning ? "LOCKED · GAME RUNNING" : "VALID FQ-4 SAVE")
                        .font(.system(size: 8, weight: .bold, design: .monospaced))
                        .tracking(0.7)
                        .foregroundStyle(gameIsRunning ? Palette.ember : Palette.sage)
                    if let date = editor.lastLoadedAt {
                        Text("LOADED \(date.formatted(date: .omitted, time: .standard))")
                            .font(.system(size: 7, weight: .medium, design: .monospaced))
                            .foregroundStyle(Palette.silver.opacity(0.4))
                    }
                }

                Button {
                    editor.refreshSelectedSlot()
                } label: {
                    Label("REFRESH", systemImage: "arrow.clockwise")
                        .font(.system(size: 8, weight: .bold, design: .monospaced))
                        .tracking(0.5)
                        .foregroundStyle(Palette.ember)
                        .padding(.horizontal, 9)
                        .frame(height: 27)
                        .overlay {
                            Rectangle()
                                .stroke(Palette.ember.opacity(0.6), lineWidth: 1)
                        }
                }
                .buttonStyle(.plain)
                .help("Reload the selected save slot from disk")
            }
            .padding(.trailing, 168)

            sectionPicker
                .padding(.top, 17)

            Rectangle()
                .fill(Palette.iron.opacity(0.25))
                .frame(height: 1)
                .padding(.top, 12)

            Group {
                switch editor.section {
                case .party:
                    partySection
                case .inventory:
                    inventorySection
                case .resources:
                    resourcesSection
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            footer
        }
        .padding(.top, 30)
        .padding(.horizontal, 24)
        .padding(.bottom, 20)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Palette.smoke)
        .overlay(alignment: .leading) {
            Rectangle()
                .fill(Palette.violet.opacity(0.72))
                .frame(width: 1)
        }
    }

    private var sectionPicker: some View {
        HStack(spacing: 18) {
            ForEach(SaveEditorSection.allCases) { section in
                Button(section.rawValue) {
                    editor.section = section
                }
                .buttonStyle(.plain)
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .tracking(0.9)
                .foregroundStyle(
                    editor.section == section
                        ? Palette.ivory
                        : Palette.silver.opacity(0.45)
                )
                .overlay(alignment: .bottom) {
                    if editor.section == section {
                        Rectangle()
                            .fill(Palette.violet)
                            .frame(height: 2)
                            .offset(y: 7)
                    }
                }
            }
        }
    }

    private var partySection: some View {
        HStack(spacing: 18) {
            VStack(spacing: 8) {
                TextField("Name, ID or visible stats", text: $editor.characterFilter)
                    .textFieldStyle(.plain)
                    .font(.system(size: 10, design: .monospaced))
                    .padding(.horizontal, 10)
                    .frame(height: 30)
                    .background(Palette.night.opacity(0.48))
                    .overlay {
                        Rectangle()
                            .stroke(Palette.iron.opacity(0.3), lineWidth: 1)
                    }

                Toggle("Changed from original", isOn: $editor.showChangedOnly)
                    .toggleStyle(.checkbox)
                    .font(.system(size: 9))
                    .foregroundStyle(Palette.silver.opacity(0.7))
                    .frame(maxWidth: .infinity, alignment: .leading)

                ScrollView {
                    LazyVStack(spacing: 3) {
                        ForEach(editor.visibleCharacters) { character in
                            Button {
                                editor.selectCharacter(character.id)
                            } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(editor.primaryName(for: character))
                                            .font(.system(size: 10, weight: .semibold, design: .serif))
                                            .lineLimit(1)
                                        Text(characterListMetadata(character))
                                            .font(.system(size: 8, design: .monospaced))
                                            .foregroundStyle(Palette.silver.opacity(0.46))
                                    }
                                    Spacer()
                                    Text("LV \(character.stats.level)")
                                        .font(.system(size: 9, weight: .medium, design: .monospaced))
                                        .foregroundStyle(Palette.ember)
                                }
                                .foregroundStyle(Palette.silver)
                                .padding(.horizontal, 9)
                                .frame(height: 40)
                                .background(
                                    editor.selectedCharacterIndex == character.id
                                        ? Palette.violet.opacity(0.25)
                                        : Palette.night.opacity(0.24)
                                )
                            }
                            .buttonStyle(.plain)
                        }

                        if editor.visibleCharacters.isEmpty {
                            VStack(spacing: 8) {
                                Text("No changed records found.")
                                Button("SHOW ALL CHARACTERS") {
                                    editor.showChangedOnly = false
                                }
                                .buttonStyle(.plain)
                                .foregroundStyle(Palette.ember)
                            }
                            .font(.system(size: 9, design: .monospaced))
                            .foregroundStyle(Palette.silver.opacity(0.55))
                            .padding(.top, 28)
                        }
                    }
                }
            }
            .frame(width: 196)

            VStack(alignment: .leading, spacing: 10) {
                if let character = editor.selectedCharacter {
                    HStack {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(editor.primaryName(for: character))
                                .font(.system(size: 18, weight: .semibold, design: .serif))
                                .foregroundStyle(Palette.ivory)
                            HStack(spacing: 7) {
                                if let localizedName = editor.localizedName(for: character),
                                   editor.englishAlias(for: character) != nil
                                {
                                    Text(localizedName)
                                        .foregroundStyle(Palette.ember)
                                }
                                Text(
                                    String(
                                        format: "NAME %04X · RECORD %d · UNIT %04X",
                                        character.nameCode,
                                        character.id + 1,
                                        character.internalID
                                    )
                                )
                                .foregroundStyle(Palette.silver.opacity(0.48))
                            }
                            .font(.system(size: 8, weight: .medium, design: .monospaced))
                        }
                        Spacer()
                        Button("KNOWN MAXIMUM") {
                            editor.applyNaturalMaximum()
                        }
                        .buttonStyle(.plain)
                        .font(.system(size: 8, weight: .bold, design: .monospaced))
                        .foregroundStyle(Palette.ember)
                    }

                    LazyVGrid(
                        columns: [
                            GridItem(.flexible(), spacing: 9),
                            GridItem(.flexible(), spacing: 9),
                        ],
                        spacing: 8
                    ) {
                        statControl("LV", keyPath: \.level, range: 0...99)
                        statControl("HR", keyPath: \.hitRate, range: 0...16)
                        statControl("HP", keyPath: \.hitPoints, range: 0...999)
                        statControl("AT", keyPath: \.attack, range: 0...99)
                        statControl("AR", keyPath: \.attackRange, range: 0...99)
                        statControl("DF", keyPath: \.defence, range: 0...99)
                        statControl("DR", keyPath: \.defenceRange, range: 0...99)
                    }

                    HStack(spacing: 10) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("CLASS")
                                .font(.system(size: 7, weight: .bold, design: .monospaced))
                                .tracking(0.8)
                                .foregroundStyle(Palette.silver.opacity(0.4))
                            Text(
                                String(format: "%02X · ", character.classCode)
                                    + editor.className(for: character.classCode)
                            )
                            .font(.system(size: 9, weight: .semibold, design: .monospaced))
                            .foregroundStyle(Palette.ivory)
                            .lineLimit(1)
                            Text(
                                String(
                                    format: "FACTION %02X LOCKED · ITEM %02X PRESERVED",
                                    character.factionCode,
                                    character.heldItemID
                                )
                            )
                            .font(.system(size: 7, weight: .semibold, design: .monospaced))
                            .foregroundStyle(Palette.silver.opacity(0.42))
                        }
                        Spacer()
                        Button("EXPERT OVERRIDE") {
                            showClassOverride = true
                        }
                        .buttonStyle(.plain)
                        .font(.system(size: 8, weight: .bold, design: .monospaced))
                        .tracking(0.5)
                        .foregroundStyle(Palette.ember)
                        .padding(.horizontal, 9)
                        .frame(height: 27)
                        .overlay {
                            Rectangle()
                                .stroke(Palette.ember.opacity(0.65), lineWidth: 1)
                        }
                    }
                    .padding(.horizontal, 10)
                    .frame(height: 52)
                    .background(Palette.night.opacity(0.32))
                } else {
                    Text("Choose a character record.")
                        .font(.system(size: 11))
                        .foregroundStyle(Palette.silver.opacity(0.5))
                }
                Spacer()
            }
            .padding(.top, 2)
        }
        .padding(.top, 14)
    }

    private var inventorySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("72 verified quantity bytes · IDs 01–48")
                    .font(.system(size: 9))
                    .foregroundStyle(Palette.silver.opacity(0.55))
                Spacer()
                Button("SET OWNED · 1") {
                    editor.setAllInventory(to: 1)
                }
                Button("PRACTICAL STOCK · 10") {
                    editor.setAllInventory(to: 10)
                }
                Button("CLEAR") {
                    editor.setAllInventory(to: 0)
                }
            }
            .buttonStyle(.plain)
            .font(.system(size: 8, weight: .bold, design: .monospaced))
            .foregroundStyle(Palette.ember)

            ScrollView {
                LazyVGrid(
                    columns: [
                        GridItem(.flexible(), spacing: 8),
                        GridItem(.flexible(), spacing: 8),
                    ],
                    spacing: 7
                ) {
                    ForEach(Array(editor.inventory.enumerated()), id: \.offset) { index, quantity in
                        HStack(spacing: 6) {
                            VStack(alignment: .leading, spacing: 1) {
                                Text(FQ4ItemCatalogue.names[index].uppercased())
                                    .font(.system(size: 8, weight: .semibold, design: .monospaced))
                                    .lineLimit(1)
                                Text(String(format: "ID %02X", index + 1))
                                    .font(.system(size: 7, design: .monospaced))
                                    .foregroundStyle(Palette.silver.opacity(0.38))
                            }
                            Spacer()
                            TextField(
                                "",
                                value: inventoryBinding(index),
                                format: .number
                            )
                            .textFieldStyle(.plain)
                            .multilineTextAlignment(.trailing)
                            .font(.system(size: 10, weight: .medium, design: .monospaced))
                            .frame(width: 34)
                        }
                        .foregroundStyle(Palette.silver)
                        .padding(.horizontal, 8)
                        .frame(height: 36)
                        .background(Palette.night.opacity(0.3))
                    }
                }
            }

            Text("Normal quantities are capped at 99. Using 1 or 10 is safer than filling every entry.")
                .font(.system(size: 9))
                .foregroundStyle(Palette.ember)
        }
        .padding(.top, 14)
    }

    private var resourcesSection: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("CAMPAIGN TREASURY")
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .tracking(0.8)
                .foregroundStyle(Palette.ember)

            HStack(alignment: .bottom, spacing: 12) {
                TextField(
                    "",
                    value: goldBinding,
                    format: .number
                )
                .textFieldStyle(.plain)
                .font(.system(size: 30, weight: .semibold, design: .serif))
                .foregroundStyle(Palette.ivory)
                .frame(width: 220)

                Text("G")
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundStyle(Palette.ember)
                    .padding(.bottom, 5)
            }
            .padding(.horizontal, 14)
            .frame(height: 58)
            .background(Palette.night.opacity(0.38))

            HStack(spacing: 16) {
                Button("100,000 G") {
                    editor.updateGold(100_000)
                }
                Button("MAX · 655,350 G") {
                    editor.updateGold(FQ4SaveFile.maximumDisplayedGold)
                }
            }
            .buttonStyle(.plain)
            .font(.system(size: 8, weight: .bold, design: .monospaced))
            .foregroundStyle(Palette.ember)

            Text("Verified encoding: the save stores four little-endian bytes at one tenth of the displayed amount. Values are normalized to multiples of 10.")
                .font(.system(size: 10))
                .lineSpacing(3)
                .foregroundStyle(Palette.silver.opacity(0.62))
                .frame(maxWidth: 430, alignment: .leading)
            Spacer()
        }
        .padding(.top, 20)
    }

    private var footer: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(editor.pendingByteCount > 0 ? Palette.ember : Palette.sage)
                .frame(width: 6, height: 6)
            VStack(alignment: .leading, spacing: 2) {
                Text(
                    editor.pendingByteCount == 0
                        ? "NO PENDING CHANGES"
                        : "\(editor.pendingByteCount) BYTES PENDING"
                )
                .font(.system(size: 8, weight: .bold, design: .monospaced))
                .tracking(0.6)
                Text(editor.notice)
                    .font(.system(size: 8))
                    .foregroundStyle(Palette.silver.opacity(0.45))
                    .lineLimit(1)
            }

            Spacer()

            Button("REVERT") {
                editor.revertChanges()
            }
            .buttonStyle(.plain)
            .disabled(editor.pendingByteCount == 0)
            .font(.system(size: 8, weight: .bold, design: .monospaced))
            .foregroundStyle(Palette.silver.opacity(0.7))

            if editor.lastBackupURL != nil {
                Button("RESTORE BACKUP") {
                    showRestoreConfirmation = true
                }
                .buttonStyle(.plain)
                .font(.system(size: 8, weight: .bold, design: .monospaced))
                .foregroundStyle(Palette.ember)
            }

            Button("APPLY CHANGES") {
                showSaveConfirmation = true
            }
            .buttonStyle(EditorApplyButtonStyle())
            .disabled(editor.pendingByteCount == 0 || gameIsRunning)
        }
        .frame(height: 42)
        .padding(.top, 8)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(Palette.iron.opacity(0.24))
                .frame(height: 1)
        }
    }

    private var sectionTitle: String {
        switch editor.section {
        case .party:
            return "Character ledger"
        case .inventory:
            return "Inventory stores"
        case .resources:
            return "Campaign resources"
        }
    }

    private func slotDetail(_ slot: SaveSlotSummary) -> String {
        guard slot.isValid else { return "Missing or unsupported" }
        guard let date = slot.modifiedAt else { return "Valid save" }
        return date.formatted(date: .abbreviated, time: .shortened)
    }

    private func characterListMetadata(_ character: FQ4CharacterRecord) -> String {
        if let localizedName = editor.localizedName(for: character),
           editor.englishAlias(for: character) != nil
        {
            return "\(localizedName) · ID \(character.displayID)"
        }
        return "RECORD \(character.id + 1) · ID \(character.displayID)"
    }

    private func statControl(
        _ label: String,
        keyPath: WritableKeyPath<FQ4CharacterStats, Int>,
        range: ClosedRange<Int>
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.system(size: 8, weight: .bold, design: .monospaced))
                .tracking(0.8)
                .foregroundStyle(Palette.silver.opacity(0.46))
            Stepper(
                value: statBinding(keyPath),
                in: range
            ) {
                Text("\(editor.selectedCharacter?.stats[keyPath: keyPath] ?? 0)")
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    .foregroundStyle(Palette.ivory)
            }
            .padding(.horizontal, 9)
            .frame(height: 32)
            .background(Palette.night.opacity(0.38))
        }
    }

    private func statBinding(
        _ keyPath: WritableKeyPath<FQ4CharacterStats, Int>
    ) -> Binding<Int> {
        Binding(
            get: {
                editor.selectedCharacter?.stats[keyPath: keyPath] ?? 0
            },
            set: { value in
                editor.updateSelectedCharacter {
                    $0[keyPath: keyPath] = value
                }
            }
        )
    }

    private func inventoryBinding(_ index: Int) -> Binding<Int> {
        Binding(
            get: {
                guard editor.inventory.indices.contains(index) else { return 0 }
                return editor.inventory[index]
            },
            set: { value in
                editor.updateInventory(index: index, quantity: min(99, max(0, value)))
            }
        )
    }

    private var goldBinding: Binding<Int> {
        Binding(
            get: { editor.displayedGold },
            set: { editor.updateGold($0) }
        )
    }
}

private struct EditorApplyButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 8, weight: .bold, design: .monospaced))
            .tracking(0.8)
            .foregroundStyle(Palette.ivory.opacity(isEnabled ? 1 : 0.45))
            .padding(.horizontal, 13)
            .frame(height: 30)
            .background(
                isEnabled
                    ? configuration.isPressed
                        ? Palette.ember
                        : Palette.violet
                    : Palette.iron.opacity(0.25)
            )
    }
}
