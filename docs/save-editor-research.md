# FQ4 DOS save-editor research

Research date: 2026-07-25
Target release: Taiwanese DOS `魔域傳說IV：波斯戰記` distributed with this wrapper
Save files: `FQ4GD.0` through `FQ4GD.3`

## Executive summary

The four saves are fixed-size, mostly plain binary files. Gold, inventory
quantities, and the documented combat statistics can be edited without
repacking the file. No checksum repair is required by any known legacy editor.

The safe first release of our editor can therefore support:

- all four slots;
- displayed gold;
- the 72 fixed inventory quantities;
- per-character level, HR, HP, AT, AR, DF, and DR;
- decoded character names;
- automatic, timestamped backups and a byte-level change review.

Character names are mapped, but party membership and ownership remain nuanced
because the save includes characters who have not joined and enemies who may
later defect. The ledger therefore identifies records by name plus internal
ID, avoids bulk character edits, and keeps faction fields read-only.

## Confidence labels

- **Verified locally**: observed in the bundled/live saves or in the surviving
  2000s editor binary.
- **High**: supported by at least two independent archival sources, or one
  archival source plus local binary verification.
- **Medium**: supported by one good source or a very strong cross-version
  correspondence.
- **Unknown**: do not expose as an editable semantic field yet.

## File identity and slot mapping

| Property | Finding | Confidence |
|---|---|---|
| Slot files | `FQ4GD.0` = slot 1 through `FQ4GD.3` = slot 4 | High |
| File size | 32,274 bytes (`0x7E12`) | Verified locally |
| Signature | ASCII `FQ-4` at `0x0000..0x0003` | Verified locally |
| Byte order | Little-endian for multi-byte numbers described below | High |
| Checksum | No recomputation is used by the surviving editor or period hex-edit instructions | High for the supported fields |

The archival Chinese instructions identify `FQ4GD.*` and the four-slot
mapping. The same mapping appears independently in a Korean editing guide.
[Chinese guide mirror](https://vv0817.neocities.org/gametxt/21_fq4)
[Korean editing guide](https://kazelnight.tistory.com/8501135)

The legacy Windows `FQ4 Editor 1.0` is described as supporting gold,
characters, and inventory and making `.bak` files before saving.
[Legacy editor description and screenshots](https://seogilang.tistory.com/464)

### Local evidence snapshot

All four bundled files are 32,274 bytes and begin with `46 51 2D 34`
(`FQ-4`). The currently played slot 4 also has the same size and signature.
Read-only inspection found:

- bundled new-game gold bytes: `64 00 00 00`;
- live slot-4 gold bytes: `6D 18 00 00`;
- decoded stored values: 100 and 6,253 respectively.

No source or game save was changed during this research.

## Confirmed byte layout

All offsets below are zero-based absolute file offsets.

| Range | Length | Encoding | Meaning | Confidence |
|---|---:|---|---|---|
| `0x0381..0x03C8` | 72 | `UInt8[72]` | inventory quantities for item IDs `0x01..0x48` | High |
| `0x047E..0x0481` | 4 | `UInt32LE` | stored gold units; displayed gold is stored value × 10 | Verified locally |
| `0x2992...` | 32 bytes/record | fixed records | character records; legacy editor scans at most 380 records | Verified locally |

### Why inventory starts at `0x381`, not `0x382`

The original Chinese instructions say PCTools sector `0001`, decimal positions
385–456 inclusive. With 512-byte sectors this gives absolute decimal
897–968, or `0x381..0x3C8`.

The surviving VB6 editor confirms this mechanically: it calls VB `Seek` with
position `0x382` (VB random/binary positions are one-based) and reads exactly
72 one-byte values. Its save path writes the same 72 bytes back. A later
Korean post labels the address `0x382`; that is best treated as a one-based
display/off-by-one description, not as the zero-based first byte.

The Chinese source warns that filling every quantity with `FF` can cause newly
acquired treasure to disappear. The editor should cap normal quantities at 99
and avoid presenting “all maximum” as the recommended action.
[Chinese inventory instructions](https://vv0817.neocities.org/gametxt/21_fq4)
[Independent Korean inventory note](https://kazelnight.tistory.com/8501135)

### Gold

The raw value at `0x47E` is a four-byte little-endian integer. The game displays
ten times that value:

```text
raw 100 (64 00 00 00) -> 1,000 G
raw 6,253 (6D 18 00 00) -> 62,530 G
```

The legacy editor reads and writes four bytes, multiplies by ten for display,
and divides user input by ten before storage. Its documented maximum is
655,350 G, corresponding to raw `65,535`. Values should therefore be limited
to `0...655350`, normalized to a multiple of 10, and stored as
`displayedGold / 10`.

The Korean guide independently identifies `0x47E`, a new-game stored value of
100, and the ×10 display rule.
[Korean gold instructions](https://kazelnight.tistory.com/8501135)

### Character records

The legacy editor seeks VB position `0x2993`, which is zero-based `0x2992`,
then reads 32-byte records. It allocates up to 380 records and stops when the
first record has no meaningful data beyond its internal ID.

| Record offset | Size | Meaning | Recommended editor behavior | Confidence |
|---|---:|---|---|---|
| `+0x00` | 2 | internal unit ID, `UInt16LE` | show read-only | Verified locally |
| `+0x07` | 1 | leadership | advanced/read-only initially | Verified in legacy editor |
| `+0x08` | 1 | four element flags/bit field | read-only until bit mapping is tested | Verified in legacy editor |
| `+0x0A` | 1 | fatigue | advanced/read-only initially | Verified in legacy editor |
| `+0x0C` | 1 | class/type code | show read-only | High |
| `+0x0D` | 1 | country/faction code | lock; never change in v1 | High |
| `+0x0F` | 1 | encoded arrow-defense value (`display = 30 - stored`) | omit in v1 | Verified in legacy editor |
| `+0x10` | 1 | arrow-avoidance/rate value | omit in v1 | Verified in legacy editor |
| `+0x11` | 1 | encoded magic-defense value (`display = 30 - stored`) | omit in v1 | Verified in legacy editor |
| `+0x15` | 1 | equipped/held item ID | read-only initially | High |
| `+0x18` | 1 | level (`LV`) | editable `0...99` | High |
| `+0x19` | 1 | healing/recovery rate (`HR`) | editable `0...16` | High |
| `+0x1A` | 2 | hit points (`HP`), `UInt16LE` | editable `0...999` | High |
| `+0x1C` | 1 | attack (`AT`) | editable `0...99` | High |
| `+0x1D` | 1 | attack rate (`AR`) | editable `0...99` | High |
| `+0x1E` | 1 | defence (`DF`) | editable `0...99` | High |
| `+0x1F` | 1 | defence rate (`DR`) | editable `0...99` | High |

The period Chinese example says an unequipped Ares has:

```text
LV=0, HP=255, HR=10, AT=35, AR=36, DF=32, DR=35
```

It gives the file-order search sequence:

```text
LV HR HP(lo hi) AT AR DF DR
00 0A FF 00    23 24 20 23
```

That exact sequence appears at offsets `+0x18..+0x1F` in the first character
record of the bundled new-game slots. The source recommends game-native
maxima of level/AT/AR/DF/DR 99 (`0x63`), HR 16 (`0x10`), and HP 999
(`E7 03`).
[Chinese attribute instructions](https://vv0817.neocities.org/gametxt/21_fq4)

The Korean guide independently says each character occupies 32 bytes, advises
finding a character by the visible AT/AR/DF/DR sequence, identifies the class
and country bytes, and explicitly warns not to alter the country value.
[Korean character-record instructions](https://kazelnight.tistory.com/8501135)

#### Character-identification guardrail

Names are decoded, but party membership is not exposed because the observed
candidate bytes do not establish player ownership reliably. The Chinese source
explicitly warns that saves also contain not-yet-joined characters and enemies
who may later defect. Editing the wrong record can make a future enemy
effectively invincible.

The ledger therefore identifies a record using:

- decoded name;
- record number and internal ID;
- class/faction shown read-only;
- its current LV, HR, HP, AT, AR, DF, and DR;

Do not provide “max every character”.

## Inventory ID table

The DOS file has 72 fixed quantity bytes. The Japanese PlayStation item table
also has exactly 72 IDs, `0x01..0x48`, and starts with Short Sword, matching
the Chinese DOS source. The item-order mapping is therefore **medium-high**
confidence across releases. Offset formula:

```text
quantityOffset = 0x381 + (itemID - 1)
```

| ID | English label | Offset | ID | English label | Offset |
|---:|---|---:|---:|---|---:|
| `01` | Short Sword | `0381` | `25` | Lion Armor | `03A5` |
| `02` | Long Sword | `0382` | `26` | Wind Veil | `03A6` |
| `03` | Ice Sword | `0383` | `27` | Laughing Mask | `03A7` |
| `04` | Heat Sword | `0384` | `28` | Medusa's Head | `03A8` |
| `05` | Claymore | `0385` | `29` | Wolf Ring | `03A9` |
| `06` | Death Sword | `0386` | `2A` | Tiger Ring | `03AA` |
| `07` | Cursed Sword | `0387` | `2B` | Lion Ring | `03AB` |
| `08` | Double-Edged Sword | `0388` | `2C` | Angel Ring | `03AC` |
| `09` | Assassin's Dagger | `0389` | `2D` | Red Cross | `03AD` |
| `0A` | Swallow-Reversal Sword | `038A` | `2E` | Fire Ward | `03AE` |
| `0B` | Dragon-Slayer Sword | `038B` | `2F` | Earth Ward | `03AF` |
| `0C` | Freezing Sword | `038C` | `30` | Wind Ward | `03B0` |
| `0D` | Lightning Sword | `038D` | `31` | Water Ward | `03B1` |
| `0E` | Crushing Sword | `038E` | `32` | Conch | `03B2` |
| `0F` | Scorching Sword | `038F` | `33` | Caral Horn | `03B3` |
| `10` | Excalibur | `0390` | `34` | Vampire Flute | `03B4` |
| `11` | Halberd | `0391` | `35` | Elf Flute | `03B5` |
| `12` | Partisan | `0392` | `36` | Angel Flute | `03B6` |
| `13` | Ron's Spear | `0393` | `37` | Earth Whistle | `03B7` |
| `14` | Fighting God's Spear | `0394` | `38` | Water Whistle | `03B8` |
| `15` | Battle Axe | `0395` | `39` | Wind Whistle | `03B9` |
| `16` | Destruction Axe | `0396` | `3A` | Ballista Kit | `03BA` |
| `17` | Flail | `0397` | `3B` | Light Stone | `03BB` |
| `18` | Morning Star | `0398` | `3C` | Fire Stone | `03BC` |
| `19` | Wizard's Staff | `0399` | `3D` | Lightning Stone | `03BD` |
| `1A` | Gambanteinn | `039A` | `3E` | Ice Crystal | `03BE` |
| `1B` | Magic Bow | `039B` | `3F` | Dark Stone | `03BF` |
| `1C` | Ultimate Bow | `039C` | `40` | Destruction Stone | `03C0` |
| `1D` | Obsession Bow | `039D` | `41` | Eye Drops | `03C1` |
| `1E` | Chainmail | `039E` | `42` | Bacchus Wine | `03C2` |
| `1F` | Plate Mail | `039F` | `43` | Ginseng Extract | `03C3` |
| `20` | Scale Mail | `03A0` | `44` | HP Recovery Medicine | `03C4` |
| `21` | Tabard | `03A1` | `45` | Fatigue Recovery Medicine | `03C5` |
| `22` | Silver Armor | `03A2` | `46` | Antidote | `03C6` |
| `23` | Gold Armor | `03A3` | `47` | Petrification Cure | `03C7` |
| `24` | Mirror Armor | `03A4` | `48` | Revival Medicine | `03C8` |

[Japanese item table](https://ds-cheat.boy.jp/ps/firstqueen4.html)

One Korean legacy editor includes only 69 labels and omits item IDs `0x0C`,
`0x0D`, and `0x24`, even though it still reads and writes 72 quantity bytes.
Our implementation should not reproduce that editor bug.

## Corruption and compatibility hazards

1. **Never save while DOSBox is running.** The game could later overwrite the
   file with its in-memory copy. Disable editing until the game process exits.
2. **Always make a backup.** Use a timestamped copy adjacent to the working
   save and expose “Restore backup”.
3. **Write atomically.** Create a sibling temporary file, preserve the exact
   32,274-byte length, then replace the save.
4. **Validate before and after.** Require signature `FQ-4`, exact length
   `0x7E12`, and confirm the final diff contains only approved offsets.
5. **Keep class and faction locked.** The Korean guide warns against changing
   faction. The Chinese guide warns that not-yet-joined enemies are present.
6. **Avoid inventory `FF`.** Normal UI range should be `0...99`; offer useful
   presets such as 0, 1, 10, and 99, with 10 as the gentle bulk preset.
7. **Protect `0x0F6D..0x0FB6`.** A modern reverse-engineering note reports
   that these 74 bytes can be unexpectedly overwritten and can break four
   generic-character definitions. This range is unrelated to the supported
   editor fields and must remain untouched.
   [Reported save corruption range](https://home.gamer.com.tw/artwork.php?sn=5694786)
8. **Do not reuse offsets across releases.** A Japanese PC-98-era community
   tool describes a different-size save. Gate this editor specifically on the
   Taiwanese DOS signature and 32,274-byte length.

## Recommended launcher UI

Keep the cover-led launcher as the home screen. Add a quiet secondary action,
`Edit save`, next to the launch controls rather than turning the launcher into
a dashboard.

The editor should open as a focused sheet/window:

1. **Slot rail:** four large slot buttons with file modified time, current
   gold, and a “Backup available” indicator. Slot numbering must read 1–4,
   even though filenames end in 0–3.
2. **Overview:** gold as the prominent field, a short save-integrity status,
   and the last-backup time.
3. **Inventory:** searchable table grouped into Weapons, Armor, Accessories,
   Instruments, Stones, and Medicine. Each row has item ID, name, current
   quantity, minus/plus, and a numeric field. Use `Set all to 10` as the
   conservative bulk action; place `Set all to 99` behind confirmation.
4. **Characters:** compact record list at left; detail pane at right with the
   seven verified statistics. Show internal ID and class/faction as read-only.
   Include the warning to unequip gear and match visible stats before editing.
5. **Review changes:** before committing, summarize semantic changes such as
   “Gold 62,530 → 100,000” and “Short Sword 0 → 10”. Do not lead with hex.
6. **Commit:** `Save changes` creates a backup first. Keep `Cancel` and
   `Restore backup` visibly separate.

The visual language should reuse the launcher's violet/ember accents and cover
art, but the editing surface should be calm, dense, and legible: one table,
one detail pane, no card grid for every item, and no novelty “god mode”
language.

## Implementation acceptance criteria

- Reads only the wrapper's working copies under Application Support, never the
  app-bundled originals.
- Refuses unknown size/signature files.
- Refuses edits while the game is running.
- Makes a verified backup before every write.
- Inventory supports exactly 72 quantities at `0x381..0x3C8`.
- Gold round-trips via `UInt32LE` at `0x47E`, display multiplier 10.
- Character writes are limited to `+0x18..+0x1F` of a specifically selected
  record in v1.
- Class, faction, identity fields, and all unknown bytes remain unchanged.
- Every save operation verifies file length, signature, and an allowlisted
  byte diff.
- Tests use copied fixtures, never the user's live saves.

## Sources

- [1998 Google Groups archive of the original Chinese cheat collection](https://groups.google.com/g/tw.bbs.comp.hacker/c/bgbBC0V2Zm4)
- [Clean Chinese guide mirror, credited to 杜勝利](https://vv0817.neocities.org/gametxt/21_fq4)
- [PTT repost of the same Chinese guide](https://www.ptt.cc/man/Old-Games/D9EE/D24A/D54A/M.1201001999.A.1EF.html)
- [2009 Korean DOS save-editing guide](https://kazelnight.tistory.com/8501135)
- [2018 screenshots and download of the legacy Windows editor](https://seogilang.tistory.com/464)
- [2008 legacy editor description](https://www.corpseplay.com/entry/FQ4-Editor)
- [Japanese PlayStation item ID table](https://ds-cheat.boy.jp/ps/firstqueen4.html)
- [2023 generic-character and save-corruption research](https://home.gamer.com.tw/artwork.php?sn=5694786)
