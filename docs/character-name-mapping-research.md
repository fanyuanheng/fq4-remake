# FQ4 DOS character-name mapping

Research date: 2026-07-25
Target release: Taiwanese DOS `魔域傳說IV：波斯戰記` in this repository

## Conclusion

Yes: the wrapper can show a reliable name for every populated character
record in the bundled saves.

The important discovery is that a save record does **not** need to be mapped
from its internal unit ID alone. Every 32-byte character record also stores a
16-bit name-table index at `+0x02`. That index resolves into the original
Traditional Chinese name table embedded in the Taiwanese `MAIN.EXE`.

For example:

```text
save record 1 at 0x2992:
DC 00 1A 00 ...
^^^^       internal unit ID 0x00DC
      ^^^^^ name ID 0x001A (26)

MAIN.EXE name entry 26:
A6 E3 B9 70 B4 B5 FE FE 00
^^^^^^^^^^^^^^^^^
Big5 "艾雷斯"
```

This identifies the first record as `艾雷斯` (Ares). Likewise, internal unit
ID `0x00DE` has name ID `0x0018`, which decodes as `阿魯富特` (Alfred).

Confidence: **very high** for the original Traditional Chinese labels and
their per-record association.

## Verified binary layout

### Save character record

Character records begin at absolute save offset `0x2992` and are `0x20`
bytes each.

| Record offset | Size | Meaning | Confidence |
|---|---:|---|---|
| `+0x00` | 2 | internal unit/template ID, `UInt16LE` | Verified locally |
| `+0x02` | 2 | name-table index, `UInt16LE` | Verified locally |
| `+0x18` | 8 | editable LV/HR/HP/AT/AR/DF/DR block | Previously verified |

The `+0x02` field is present in both the save records and their corresponding
templates in `HITOBUF.COM`.

Primary evidence:

- [`FQ4GD.3`](../FQ4/FQ4GD.3), record table at `0x2992`;
- [`HITOBUF.COM`](../FQ4/HITOBUF.COM), 600 fixed 32-byte templates;
- [`MAIN.EXE`](../FQ4/MAIN.EXE), localized name table at `0x2EB9A`.

### Taiwanese name table

The table in `MAIN.EXE` has these properties:

| Property | Value |
|---|---|
| Start | `0x2EB9A` |
| End, exclusive | `0x30114` |
| Entry count | 652 (`0x0000...0x028B`) |
| Encoding | Big5 |
| Entry terminator | `FE FE 00` |
| Following data | ASCII `DISMISS\0` at `0x30114` |

The same byte range is identical in `MAIN.ORI`, providing a second local copy
of the table. The executable files as a whole are not identical, so only the
name-table range should be compared.

Relevant SHA-256 values:

```text
MAIN.EXE     e6aa90bfba9af64ca0837ae0230bc4b83b92b31d33e611702935b32ef540c18e
MAIN.ORI     0d340e29046e854f29fcbfe2db7c3ea985760f02e73ad1fa61b1e4fabddb0a72
HITOBUF.COM  3d5b0219f1d8719f06d136e4773212cb3844097e8718bda146cef4ad8efdf81b
```

All populated records in all four bundled saves point to a valid table entry:

| Save | Populated records | Minimum name ID | Maximum name ID | Invalid IDs |
|---|---:|---:|---:|---:|
| `FQ4GD.0` | 311 | `0x0001` | `0x0285` | 0 |
| `FQ4GD.1` | 309 | `0x0001` | `0x0285` | 0 |
| `FQ4GD.2` | 309 | `0x0001` | `0x0285` | 0 |
| `FQ4GD.3` | 309 | `0x0001` | `0x0285` | 0 |

The current writable Slot 4 was also checked read-only: it contains 320
populated records and all 320 name IDs resolve within the same catalogue. No
save was modified during this research.

## Sample resolved records

These entries are identical across the four bundled saves:

| Record | Internal ID | Name ID | Original name | Suggested optional Latin alias |
|---:|---:|---:|---|---|
| 1 | `0x00DC` | `0x001A` | 艾雷斯 | Ares |
| 2 | `0x00DD` | `0x0209` | 愛倫 | Elaine |
| 3 | `0x00DE` | `0x0018` | 阿魯富特 | Alfred |
| 4 | `0x00DF` | `0x0098` | 孔萊多 | Conrad |
| 5 | `0x00E0` | `0x01BE` | 萊姆拉克 | Lamorak |
| 6 | `0x00E1` | `0x0080` | 赫依斯 | — |
| 7 | `0x00E2` | `0x003A` | 雅斯卡魯 | — |
| 8 | `0x00E3` | `0x01F3` | 羅雷斯 | — |
| 9 | `0x00E4` | `0x010B` | 德雷 | — |
| 10 | `0x00E5` | `0x0234` | 優利亞 | — |
| 11 | `0x00E6` | `0x0214` | 施奇 | — |
| 12 | `0x00E7` | `0x020C` | 克莉斯丁 | — |
| 13 | `0x00E8` | `0x005D` | 卡那特 | — |

The first five Latin aliases are useful display aids, but the Chinese strings
are the authoritative labels for this release. The Japanese names
`アレス`, `エレイン`, `アルフレッド`, `コンラッド`, and
`ラモラック` are corroborated by a detailed character guide, while sources
vary on English spelling (for example, “Ares” versus “Aless”). Treat Latin
spellings as curated aliases, not replacements for the original labels.
[Character-guide corroboration](https://namu.moe/w/%ED%8D%BC%EC%8A%A4%ED%8A%B8%20%ED%80%B8%204/%EB%93%B1%EC%9E%A5%EC%9D%B8%EB%AC%BC)

## Why internal ID alone is unsafe

Internal unit IDs are not globally unique in a save. For example, `0x0139`
appears twice:

```text
record 94 @ 0x3532:
internal ID 0x0139, name ID 0x01D7 -> 雷

record 99 @ 0x35D2:
internal ID 0x0139, name ID 0x0042 -> 歐魯幸
```

A dictionary such as `[0x0139: "some name"]` would therefore mislabel at
least one record. The UI must resolve the name from each record's `+0x02`
field.

This also explains why a surviving Windows editor could expose a name
selector for individual records. Its documentation and screenshot show a
character name field, independently supporting that names are a distinct
record attribute.
[Legacy editor description and screenshots](https://seogilang.tistory.com/464)

## Independent dialogue confirmation

`FQ4MES` is a separate localized message bank:

- the first `0x640` bytes are 800 little-endian message offsets;
- payload strings are NUL-terminated Big5;
- dialogue at `0x65B` is spoken by `艾雷斯`;
- dialogue at `0x16D6` is spoken by `阿魯富特`.

This confirms that the decoded strings are real names used by the localized
game. `FQ4MES` does not itself provide the save-record mapping; that mapping
comes from the name ID at record `+0x02`.

Kure Software's official series page identifies First Queen IV as the 1994
release in this series.
[Official First Queen series page](https://www.kuresoft.net/news2.html)

## Recommended implementation

1. Add `nameID: UInt16` as a read-only property sourced from character record
   `+0x02`.
2. Use a mechanically extracted, immutable 652-entry catalogue from this
   exact Taiwanese `MAIN.EXE`, or decode the matching executable at runtime.
3. Resolve each visible row as:

   ```text
   originalName = names[record.nameID]
   ```

4. Display the original name prominently:

   ```text
   艾雷斯 · Ares
   Record 1 · Unit DC · Name 001A
   ```

5. Add curated Latin aliases only for names verified separately. For all
   others, the original Traditional Chinese name is safer than an automated
   romanization.
6. If a name ID is outside `0..<652`, fall back to `Name ID XXXX` and keep the
   record editable by its existing record/stat identity.
7. Keep name editing disabled for now. Showing the name is well verified;
   changing `+0x02` is a different feature and is outside the current
   save-writer allowlist.

The catalogue should be gated to the bundled Taiwanese release. Other FQ4
ports and localizations may contain different text tables and encodings.

## Reproducible extraction

The following read-only Node script extracts the table and resolves records:

```js
const fs = require("fs");
const { TextDecoder } = require("util");

const exe = fs.readFileSync("FQ4/MAIN.EXE");
const save = fs.readFileSync("FQ4/FQ4GD.3");
const decoder = new TextDecoder("big5");
const terminator = Buffer.from([0xfe, 0xfe, 0x00]);

let cursor = 0x2eb9a;
const names = [];

for (let index = 0; index < 652; index += 1) {
  const end = exe.indexOf(terminator, cursor);
  if (end < 0) throw new Error(`Missing name terminator at ${index}`);
  names.push(decoder.decode(exe.subarray(cursor, end)));
  cursor = end + terminator.length;
}

for (let index = 0; index < 380; index += 1) {
  const offset = 0x2992 + index * 0x20;
  const payload = save.subarray(offset + 2, offset + 0x20);
  if (!payload.some(byte => byte !== 0)) break;

  const internalID = save.readUInt16LE(offset);
  const nameID = save.readUInt16LE(offset + 2);
  console.log(index + 1, internalID, nameID, names[nameID]);
}
```

## Decision

A complete, stable mapping is feasible for this wrapper, provided “mapping”
means:

```text
save record -> its stored name ID -> the matching Taiwanese name-table entry
```

It is **not** safe to reduce that to:

```text
internal unit ID -> one universal name
```

The first form is exact for every populated bundled save record and should be
used in the app.
