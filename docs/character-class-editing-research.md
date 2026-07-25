# FQ4 DOS character-class editing research

Research date: 2026-07-25
Target release: Taiwanese DOS `魔域傳說IV：波斯戰記` in this repository

## Decision

The character class is a real, independently writable one-byte field at
record offset `+0x0C`. A class-only change within the game's defined range is
structurally possible and period editors did it successfully.

It is **not safe to expose arbitrary class editing as a normal, low-risk
feature**, however:

- the 220 values include heroes, soldiers, monsters, bosses, body parts,
  traps, cannon, flowers, and other map entities;
- many different codes have the same displayed class label but are distinct
  archetypes;
- the class code is tied to appearance and combat behavior, not merely a
  cosmetic occupation label;
- game-native promotions also change equipment and other combat fields;
- two defined class IDs are not used by any of the 600 bundled unit
  templates;
- the save contains future allies and enemies as well as current units.

Recommended product decision:

1. Ship the decoded class name as **read-only** immediately.
2. Do not add the class byte to the normal save-writer allowlist.
3. If class editing is added later, put it behind an **Expert override**,
   restrict values to the verified table, keep faction locked, and perform a
   runtime test matrix on disposable saves first.

Implementation status (2026-07-25): the macOS wrapper now implements that
guarded Expert override. It accepts only `0x00...0xDB`, stages only record byte
`+0x0C`, keeps faction/equipment/stats untouched, separates ordinary roles
from experimental enemy/boss archetypes, blocks object/multi-part/unused IDs,
and adds a second confirmation before staging an experimental class. The
normal apply action still creates a timestamped backup before writing.

Confidence:

- class field location and class-label mapping: **very high**;
- a class-only byte change loading successfully for ordinary humanoid
  classes: **high**, supported by a detailed period-community procedure;
- arbitrary cross-species/boss/object changes being gameplay-safe: **low /
  unsupported**;
- exact companion changes required for a game-native promotion: **not yet
  established**.

## Verified record field

Character records start at absolute save offset `0x2992` and are `0x20`
bytes each.

| Record offset | Size | Meaning | Editor status |
|---|---:|---|---|
| `+0x00` | 2 | internal unit ID, `UInt16LE` | read-only |
| `+0x02` | 2 | localized name ID, `UInt16LE` | read-only |
| `+0x0C` | 1 | class/archetype code | read-only recommended |
| `+0x0D` | 1 | country/faction | **never change** |
| `+0x15` | 1 | equipped/held item ID | companion field in observed promotions |
| `+0x18` | 8 | LV/HR/HP/AT/AR/DF/DR | separately editable |

The bundled Ares record illustrates the placement:

```text
save offset 0x2992

DC 00 1A 00 00 00 0A 08 00 00 00 00 00 10 00 00 ...
^^^^                                     ^^ ^^
unit ID                                  |  faction
                                         class 0x00
```

The same layout is present in the canonical 600-record template bank
[`HITOBUF.COM`](../FQ4/HITOBUF.COM). The current save parser already reads
`+0x0C` as `classCode`; this research confirms the semantics and catalogue.

The Korean hex-editing guide independently identifies the byte immediately
before country/faction as the job/class field, says not to change the country
byte, and documents successful class-only changes.
[Class-editing procedure](https://kazelnight.tistory.com/8501135)

## Class-name table

The Taiwanese class-label table is embedded in both
[`MAIN.EXE`](../FQ4/MAIN.EXE) and [`MAIN.ORI`](../FQ4/MAIN.ORI):

| Property | Value |
|---|---|
| Start | `0x3013D` |
| End, exclusive | `0x308F9` |
| Entry count | 220 (`0x00...0xDB`) |
| Encoding | Big5 |
| Entry format | fixed 9 bytes: 6-byte padded Big5 label + `FE FE 00` |

The range is byte-identical in `MAIN.EXE` and `MAIN.ORI`.

```text
classLabelOffset = 0x3013D + (classCode * 9)
table SHA-256    = 1a9a5ac1aa21b6ddb041b64d5b2ff702a75919d8265be81f60d2f969450e7860
```

Reverse inspection of the executable independently establishes the same
bounds. The selector lookup checks for `0xDC`; values below it are multiplied
by `0x20` to address a base template. The class-label lookup multiplies the
class by 9 and adds the table's runtime address. Values `0xDC...0xFF` would
index beyond the class table and must never be accepted.

Every populated character record in the four bundled saves uses a class code
inside this table. Those saves use 104–106 distinct codes, with a maximum of
`0xD4`. The complete 600-record `HITOBUF.COM` template bank uses 218 of the
220 defined codes and reaches `0xDB`.

The only defined codes absent from the class bytes of every active
`HITOBUF.COM` template are:

- `0x06` — `國王` (King);
- `0x1A` — `王子` (Prince).

They have label slots but no canonical active unit-template example, so they
should be marked **unused/unverified**, not presented as normal choices.

`HITOBUF.COM` is exactly 19,200 bytes (`0x4B00`), or 600 fixed 32-byte
records:

- records `0...219` are class/base selectors;
- records `220...528` are 309 named-character templates;
- records `529...599` contain only their sequential ID and otherwise-zero
  payloads.

Most class/base selectors store their own index at `+0x0C`. Eight redirect to
another class byte:

```text
06 -> 34    08 -> 34    0A -> 32    0B -> 33
17 -> 28    18 -> 28    1A -> 30    92 -> 9A
```

This is another reason not to assume the code table is a set of simple,
interchangeable occupations.

## Complete class-code map

These are exact Traditional Chinese labels from the Taiwanese executable.
Some translations and spellings are period-specific; preserve them as source
labels rather than silently “correcting” them.

| ID | Name | ID | Name | ID | Name | ID | Name |
|---:|---|---:|---|---:|---|---:|---|
| `00` | 國王 | `37` | 紅戰士 | `6E` | 精靈 | `A5` | 人造人 |
| `01` | 勇士 | `38` | 弓騎士 | `6F` | 大精靈 | `A6` | 香菇 |
| `02` | 王子 | `39` | Ｂ士兵 | `70` | 靈魔女 | `A7` | 大老鼠 |
| `03` | 銀騎士 | `3A` | Ｂ戰士 | `71` | 鳥人 | `A8` | 蜥蜴 |
| `04` | 法師 | `3B` | Ｂ弓兵 | `72` | 鳥弓 | `A9` | 海龍 |
| `05` | 國王 | `3C` | Ｍ雷母 | `73` | 鳥騎士 | `AA` | 海龍 |
| `06` | 國王 | `3D` | Ｉ雷母 | `74` | 國王 | `AB` | 海龍 |
| `07` | 學者 | `3E` | Ｃ雷母 | `75` | 海盜 | `AC` | 食人花 |
| `08` | 指揮官 | `3F` | 國王 | `76` | 大海盜 | `AD` | 食人花 |
| `09` | 阿瑪族 | `40` | 學者 | `77` | 公爵 | `AE` | 石像 |
| `0A` | 驅魔者 | `41` | 製圖家 | `78` | 克學士 | `AF` | 水晶球 |
| `0B` | 護士 | `42` | 勇士 | `79` | 槍學士 | `B0` | 花 |
| `0C` | 學者 | `43` | 紅騎士 | `7A` | 守衛 | `B1` | 陷井 |
| `0D` | 魔女 | `44` | Ｒ士兵 | `7B` | 水之王 | `B2` | 大砲 |
| `0E` | 怪獸人 | `45` | Ｒ弓兵 | `7C` | 地之王 | `B3` | 滿依達 |
| `0F` | 軍師 | `46` | 王子 | `7D` | 風之王 | `B4` | 飛龍 |
| `10` | 學者 | `47` | 王子 | `7E` | 溫蒂 | `B5` | 飛龍 |
| `11` | 學者 | `48` | 普騎士 | `7F` | 土精靈 | `B6` | 人造人 |
| `12` | 僧侶 | `49` | 白戰士 | `80` | 西魯 | `B7` | 射出機 |
| `13` | 修道士 | `4A` | 騎士 | `81` | 土精靈 | `B8` | 薩拉達 |
| `14` | 尼僧 | `4B` | 槍兵 | `82` | 靈媒 | `B9` | 伊比魯 |
| `15` | 魔女 | `4C` | 誘導槍 | `83` | 特拉斯 | `BA` | 男爵士 |
| `16` | 店魔女 | `4D` | 國王 | `84` | 國王 | `BB` | 黑騎士 |
| `17` | 兄弟 | `4E` | 皇后 | `85` | 狼族 | `BC` | 馬騎士 |
| `18` | 兄弟 | `4F` | 學者 | `86` | 勇士 | `BD` | 怪物 |
| `19` | 騎士 | `50` | 詩人 | `87` | 學士 | `BE` | 古蜻蜓 |
| `1A` | 王子 | `51` | 綠騎士 | `88` | 狩獵者 | `BF` | 國王 |
| `1B` | 小偷 | `52` | Ｇ士兵 | `89` | 虎族 | `C0` | 騎兵 |
| `1C` | 忍者 | `53` | Ｇ戰士 | `8A` | 熊貓 | `C1` | 騎士 |
| `1D` | 國王 | `54` | 士兵 | `8B` | 鳥龜族 | `C2` | 騎士 |
| `1E` | 大魔頭 | `55` | 戰士 | `8C` | 恐龍族 | `C3` | 誘導槍 |
| `1F` | 四天王 | `56` | 騎士 | `8D` | 人面鷲 | `C4` | 王子 |
| `20` | 四天王 | `57` | 狙擊手 | `8E` | 灰甲 | `C5` | 黑騎士 |
| `21` | 四天王 | `58` | 弓箭手 | `8F` | 大進 | `C6` | 騎兵 |
| `22` | 四天王 | `59` | 塔奧 | `90` | 戰鬥機 | `C7` | 飛龍 |
| `23` | 國王 | `5A` | 瑪地普 | `91` | 盜賊 | `C8` | 飛龍 |
| `24` | 王子 | `5B` | 依夫利 | `92` | 刀人 | `C9` | 飛龍 |
| `25` | 國王 | `5C` | 琴 | `93` | 淑人 | `CA` | 飛龍 |
| `26` | 探查機 | `5D` | 天使 | `94` | 海獸 | `CB` | 特達羅 |
| `27` | 國王 | `5E` | 死靈 | `95` | 蜈蚣 | `CC` | 特達羅 |
| `28` | 黑騎士 | `5F` | 鬼神 | `96` | 工龍 | `CD` | 特達羅 |
| `29` | 次公爵 | `60` | 還魂 | `97` | 伊古特 | `CE` | 地獄獸 |
| `2A` | 公爵 | `61` | 骸骨 | `98` | 螃蠍 | `CF` | 阿畢士 |
| `2B` | 紅戰士 | `62` | 鬼 | `99` | 蝎子 | `D0` | 小雞 |
| `2C` | 死靈 | `63` | 哥布林 | `9A` | 米粘 | `D1` | 吸血鬼 |
| `2D` | 魔頭 | `64` | 林學士 | `9B` | 雷斯坦 | `D2` | 伊比魯 |
| `2E` | 紅公爵 | `65` | 鳥人 | `9C` | 哈查斯 | `D3` | 克利風 |
| `2F` | 野武士 | `66` | 歐格 | `9D` | 老鼠 | `D4` | 巨人 |
| `30` | 攻擊手 | `67` | 歐格 | `9E` | 公雞 | `D5` | 攻雷母 |
| `31` | 黑騎士 | `68` | 鱷魚 | `9F` | 蝸牛 | `D6` | 飛龍 |
| `32` | 紅騎士 | `69` | 大鱷魚 | `A0` | 蝸牛 | `D7` | 克利風 |
| `33` | 暗戰士 | `6A` | 熊人 | `A1` | 蛇 | `D8` | 龍騎兵 |
| `34` | 劍士 | `6B` | 狼人 | `A2` | 山貓 | `D9` | 吸寫鬼 |
| `35` | 騎士 | `6C` | 精靈王 | `A3` | 小恐龍 | `DA` | 保護者 |
| `36` | 隊員 | `6D` | 精靈 | `A4` | 天使 | `DB` | 曼蒂可 |

## Label collisions

The table contains 220 codes but only 158 unique labels. Twenty-eight labels
are repeated across 90 codes.

Examples:

```text
國王: 00, 05, 06, 1D, 23, 25, 27, 3F, 4D, 74, 84, BF
王子: 02, 1A, 24, 46, 47, C4
騎士: 19, 35, 4A, 56, C1, C2
飛龍: B4, B5, C7, C8, C9, CA, D6
```

These are not interchangeable aliases. The Korean class catalogue identifies
early codes by their specific visual archetype—for example `00` as Ares,
`01` as Elaine, `02` as Alfred, and `03` as Conrad—even though the Taiwanese
status labels are King, Warrior, Prince, and Silver Knight. A class code
therefore combines occupation/behavior with a specific visual archetype.

The UI must always show the hexadecimal code with the label. A menu containing
twelve indistinguishable “King” rows would be unsafe.

## Primary executable evidence: class drives runtime behavior

Static inspection of the bundled `MAIN.EXE` shows several independent uses of
the class byte:

- the character-expansion routine reads save/template record `+0x0C` and
  copies it into runtime actor byte `+0x14`;
- a behavior routine branches on many exact class codes, including `0x91`,
  `0x1B`, `0xDB`, `0x99`, `0x5F`, `0x3C`, `0x60`, `0x65`, `0x2C`, `0x3D`,
  `0xCE`, `0xD5`, `0x8F`, and `0xBD`;
- another routine computes `6 * classCode` and reads a per-class numeric
  table;
- actor-comparison and flag-building routines directly compare class bytes.

Therefore class controls game logic and calculations, not just the localized
label shown in the status UI.

The record's name remains independent. Named records have a nonzero name ID
at `+0x02`; the executable falls back to a class label only when that name ID
is zero. Changing class on a named character should not rename them.

## Base-template evidence: class-only edits do not normalize the record

For each of the 309 named templates, its class code can be compared with the
corresponding base selector:

- fields `+0x04`, `+0x05`, `+0x08...+0x0B`, `+0x0D...+0x0F`, `+0x14`,
  `+0x16`, and `+0x17` match the selected base in all 309 templates;
- named characters vary from the base at leadership-related `+0x06/+0x07`,
  defence-related `+0x10...+0x13`, held item `+0x15`, and stats
  `+0x18...+0x1F`;
- only 4 of 309 named records match their class base across the entire
  `+0x04...+0x1F` payload.

These are hybrid records initialized from class defaults and then customized.
Changing `+0x0C` later does not copy in the target class's defaults or
reconcile equipment/stat fields.

One `HITOBUF` data anomaly is worth preserving in future tooling: record 313
at `0x2720` has ID `0x0139`, name ID `0x01D7`, and class `0x36`; record 318
at `0x27C0` is a different template but repeats ID `0x0139`, with name ID
`0x0042` and class `0x53`. Expected sequential ID `0x013E` is absent. Do not
key templates solely by internal ID.

## Evidence that natural class changes touch more than `+0x0C`

The game itself supports some class changes. Localized dialogue explains:

- weapon shops can change soldiers into archers;
- archers lose defence and ordinary attack;
- abandoning the bow requires changing type again;
- a bishop can grant qualifying soldiers/warriors the knight title at level
  50, increasing combat ability;
- buying a horse turns a knight into cavalry and raises attack, while cavalry
  is weak against arrows.

These are primary strings in [`FQ4MES`](../FQ4/FQ4MES), particularly messages
113, 118, 126, 127, 129, and 699.

Read-only comparison of the original Slot 4 and the current played copy found
nineteen corresponding records whose class changed during play:

- nine records changed from `0x54` Soldier (one from `0x57` Sniper) to
  `0x56` Knight;
- ten records changed from `0x55` Warrior to `0x58` Archer.

Those records also changed several other fields. Most notably:

- the observed Knight records acquired held-item code `0x10`
  (the catalogue's Excalibur entry);
- the observed Archer records acquired held-item code `0x1D`
  (the catalogue's Obsession Bow entry);
- leadership/defence-related bytes and combat statistics also changed across
  the observed Knight group;
- the Archer group changed additional state/faction-related bytes as the
  campaign progressed.

This is not a controlled before/after experiment, so it does not prove that
every companion-field change was caused by promotion. It does prove that a
game-native result is richer than simply replacing one class byte. No save
was modified during the comparison.

## What the period editor proves—and does not prove

The Korean guide reports successful one-byte class overrides, including
turning ordinary allied units into alternate humanoid classes. It gives
`0x54` as the normal unnamed allied soldier class, recommends locating the
record by stats plus the `class/faction` pair, and explicitly says to change
the class but not the country/faction.
[Detailed class override instructions](https://kazelnight.tistory.com/8501135)

A surviving Windows editor also exposed appearance/class selection alongside
the character's name, item, and statistics.
[Legacy editor screenshots](https://seogilang.tistory.com/464)

This supports:

- the game can load a class-only override;
- `+0x0C` is the correct byte;
- ordinary humanoid substitutions can be usable.

It does **not** establish:

- that all 220 values are safe for a controllable party member;
- that boss, object, or multi-part creature codes behave correctly;
- that switching between ranged, mounted, magic, and melee archetypes without
  matching equipment produces a coherent unit;
- that a class-only change reproduces the game's native promotion effects.

## Safe and unsafe UI design

### Original class-art preview

`CHRBANK` is a class-indexed graphics archive rather than an opaque runtime
buffer:

- its first 512 bytes are 256 little-endian record lengths;
- the sum of those lengths plus the index is exactly the file size;
- class byte `00...DB` selects the record at the matching index;
- records use the same compression dispatcher found in `MAIN.EXE`, with RLE,
  LZ, and Huffman stages in modes `1...9`;
- decoded class data is cell-major eight-colour artwork. Each cell is `16 × 16`
  pixels with three local colour planes;
- `MAIN.EXE` maps each class to a packed cell-grid size and a pose count.
  Ordinary characters use a `2 × 2` cell grid (`32 × 32` pixels), while large
  creatures use larger grids.

The native class override now renders one coherent current and target pose side
by side with nearest-neighbour scaling. It reads only the bundled or writable
`CHRBANK` and `MAIN.EXE`; selecting a preview never changes the save.

### Safe now

- Display `Class 00 · 國王` read-only.
- Search/filter by code and original label.
- Preview the original current and target class artwork.
- Retain `CLASS 00` as a secondary technical identifier.
- Keep country/faction read-only.
- Preserve the original class byte through normal stat edits.

### Potential Expert override

An advanced override can be considered after runtime testing. It should:

1. Be disabled while DOSBox is running.
2. Create the existing timestamped backup before writing.
3. Permit only `0x00...0xDB`.
4. Flag `0x06` and `0x1A` as unused/unverified.
5. Show code, original label, and a category:
   `humanoid`, `monster`, `boss`, `object`, or `unverified`.
6. Hide monster/boss/object codes by default.
7. Warn that equipment and derived combat values are not adjusted.
8. Never modify `+0x0D` faction.
9. Add only the selected record's `+0x0C` offset to the byte-diff allowlist.
10. Require explicit confirmation such as:
    “Change only the class byte; keep current equipment and stats.”

Do not offer a “change every character” or “random class” action.

### Required runtime test before enabling writes

Use a disposable full game copy and a known recruited, non-critical unit:

1. test a small curated group such as Soldier, Warrior, Knight, Sniper, and
   Archer;
2. load the save and inspect name, sprite, status label, and equipment;
3. test movement, normal attack, ranged attack, receiving damage, and healing;
4. save again in-game, quit, and reload;
5. compare the game's rewritten record and identify every normalized field;
6. separately test mounted and magic classes;
7. do not test boss/object classes on a real campaign save.

Until that matrix is complete, class editing should remain an expert-only
unsupported override—or simply read-only.

## Reproducible extraction

```js
const fs = require("fs");
const { TextDecoder } = require("util");

const exe = fs.readFileSync("FQ4/MAIN.EXE");
const save = fs.readFileSync("FQ4/FQ4GD.3");
const decoder = new TextDecoder("big5");
const terminator = Buffer.from([0xfe, 0xfe, 0x00]);

let cursor = 0x3013d;
const classes = [];

for (let code = 0; code < 220; code += 1) {
  const end = exe.indexOf(terminator, cursor);
  if (end < 0) throw new Error(`Missing class terminator at ${code}`);
  classes.push(decoder.decode(exe.subarray(cursor, end)).trim());
  cursor = end + terminator.length;
}

for (let index = 0; index < 380; index += 1) {
  const offset = 0x2992 + index * 0x20;
  const payload = save.subarray(offset + 2, offset + 0x20);
  if (!payload.some(byte => byte !== 0)) break;

  const classCode = save[offset + 0x0c];
  console.log(index + 1, classCode, classes[classCode]);
}
```

Expected extraction endpoint:

```text
220 entries
cursor = 0x308F9
```

## Final recommendation

The class mapping is good enough to improve the editor's identification UI
now. It is not yet good enough to make arbitrary class changes feel like a
safe, polished feature.

Treat class editing as a separate advanced reverse-engineering project:
first map categories and native transition recipes, then verify a curated
subset in disposable gameplay. The normal cheat editor should continue to
protect the class byte until that work is done.
