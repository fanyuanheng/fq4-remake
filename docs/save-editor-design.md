# FQ4 Wrapper — Save Editor Design

## Product direction

The editor should feel like an archivist's field ledger that belongs beside the
original cover art: dark charcoal, aged ivory type, restrained violet accents,
and ember-coloured warnings. It should not look like a generic settings panel
or a trainer full of neon switches.

The editor is a second destination inside the launcher, not a separate utility.
The window keeps two top-level choices:

- **Play**
- **Save Editor**

Opening the editor must never launch DOSBox. Editing is locked while the game is
running.

## Screen structure

```text
┌──────────────────────────────────────────────────────────────────────────┐
│ FIRST QUEEN IV                         [ PLAY ] [ SAVE EDITOR ]           │
├───────────────────┬──────────────────────────────────────────────────────┤
│ SAVE SLOTS        │ SLOT 4 · FQ4GD.3                    VALID FQ-4 SAVE   │
│                   │ Last saved 8:48 am                                    │
│ 01  Before battle │                                                       │
│ 02  Early game    │ [ PARTY ] [ INVENTORY ] [ RESOURCES ]                │
│ 03  Early game    │                                                       │
│ 04  Current  ◀    │  selected section                                    │
│                   │                                                       │
│                   │                                                       │
│                   ├───────────────────────────────────────────────────────┤
│ Original protected│ 3 changes pending      [ REVIEW ] [ APPLY CHANGES ]  │
└───────────────────┴──────────────────────────────────────────────────────┘
```

### Slot rail

The left rail always shows all four slots. Each row includes:

- slot number and filename;
- last-modified time;
- file status: valid, missing, or unsupported;
- a small “edited” marker when the working values differ from disk.

Selecting another slot with pending changes opens a compact discard/continue
confirmation. The editor only reads the writable Application Support copy; the
original files bundled with the app remain untouched.

### Party

The save does not contain a verified name table. Until names can be mapped with
confidence, characters are identified honestly as **Record 1 · ID 00DC**.

The Party section has:

- a searchable record list;
- a “Find by in-game stats” action accepting LV, HR, HP, AT, AR, DF, and DR;
- the seven editable fields with natural ranges;
- an explicit **Known maximum** preset;
- a short identity warning beside every record.

Natural limits from the period documentation:

| Field | Range |
|---|---:|
| LV | 0–99 |
| HR | 0–16 |
| HP | 0–999 |
| AT / AR / DF / DR | 0–99 |

An advanced “raw 255” preset belongs behind a warning disclosure. It should
never be the primary action because the file also contains unrecruited and
enemy records.

### Inventory

The verified inventory table is 72 one-byte entries. The cross-release item
table provides useful English labels, while every row also shows its stable
hex ID.

The main interaction is a dense, searchable table:

| Item | Quantity | Change |
|---|---:|---|
| Item 01 · 00 | 0 | — |
| Item 02 · 01 | 99 | 0 → 99 |

Useful bulk actions:

- **Set owned to 1** — safest unlock preset;
- **Set owned to 10** — practical stock preset;
- **Clear inventory**;
- **Restore from disk**.

“Set all to 255” is intentionally omitted from the normal UI. The source tip
warns that maxing quantities may cause newly acquired items to disappear.

### Resources

Gold is stored as a four-byte little-endian value at `0x47E`; the game displays
ten times that raw value. The UI accepts `0...655350 G`, normalizes values to a
multiple of ten, and preserves the four-byte field width.

## Save transaction

**Apply Changes** opens a review sheet showing:

- the selected slot;
- a human-readable before/after list;
- how many bytes will change;
- the automatic backup destination.

The write path must:

1. require a valid `FQ-4` header and the expected file length;
2. refuse to run while DOSBox is active;
3. change only allow-listed offsets;
4. write a timestamped backup first;
5. write to a sibling temporary file and atomically replace the save;
6. reread and validate the result;
7. offer **Restore Backup** in the completion state.

Backups belong in:

`~/Library/Application Support/FQ4 Wrapper/Save Backups/`

## Confidence labels

The UI should expose uncertainty instead of hiding it:

- **Verified** — independently supported by the supplied documentation and the
  local saves.
- **Inferred** — structurally consistent across local saves but not yet
  validated by a controlled load/save test.
- **Experimental** — disabled by default.

Current classification:

| Feature | Confidence | UI state |
|---|---|---|
| Four slots `FQ4GD.0`–`FQ4GD.3` | Verified | Enabled |
| 72-byte inventory table | Verified structure | Enabled after load test |
| Character stat order and natural maxima | Verified structure | Enabled after load test |
| Character identity/name mapping | Unknown | Use record IDs |
| Gold offset/encoding | Verified structure | Enabled |
| Bytes 4–5 header meaning | Unknown | Preserve unchanged |

## Accessibility and interaction

- Keyboard navigation must cover slot selection, section tabs, record list, and
  every numeric field.
- Do not encode state with colour alone; use labels such as “Valid” and
  “Pending”.
- Numeric controls accept direct typing and stepper/arrow changes.
- Warnings are concise and adjacent to the risky action.
- The editor remembers the last selected slot and section, but never preserves
  unapplied edits across app launches.
