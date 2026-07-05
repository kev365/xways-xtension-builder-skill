---
source: empirical testing (2026-05-03 against build 1422138.89) + the X-Ways SDK header (see getting-the-sdk.md)
type: empirical-finding + official-doc
fetched: 2026-05-03
last_updated: 2026-05-03
author: project empirical sweep
---

# `XWF_GetItemType` flag bits, `XWF_GetMetadataEx`, `XWF_GetText` — empirical decoding

The X-Ways SDK header (see [getting-the-sdk.md](getting-the-sdk.md)) declares these three function pointers but does **not** document the semantics of their flag/parameter bits. An empirical sweep enumerated their behavior on a clean NTFS partition snapshot; the decoded semantics are captured here so X-Tensions don't have to re-discover them.

## `XWF_GetItemInformation` — full live `nInfoType` map (empirical 2026-05-03)

Empirical results from sweeping `nInfoType` 0..255 across 19 items spanning 14 distinct X-Ways "Type category" values (Pictures, Audio, Source Code, Spreadsheet, Programs, Archives/Backup, Cryptography, Fonts, Database, Misc Documents, etc.) on build 1422138.89:

| `nInfoType` | xwf-api-rs name | Status |
| ---: | --- | --- |
| 1 | `OrigId` | live + ok=1 |
| 2 | `Attr` | live + ok=1 |
| 3 | `Flags` | live + ok=1 |
| 4 | `Deletion` | live + ok=1 |
| 5 | `Classification` | live + ok=1 |
| 6 | `LinkCount` | live + ok=1 |
| 7 | `ColorAnalysis` | live + ok=1 (per-image attribute). Return-value legend (per the community xwf-api-rs binding's color-analysis conversion): `-2` = error, `-3` = grayscale, `-4` = irrelevant (X-Ways considers the item not a picture), `0..100` = colorfulness percentage, anything else = not available. Re-test on a snapshot with diverse images to confirm. |
| 8 | `PixelIndex` | live + ok=1 — value semantics undocumented in xwf-api-rs; appears to be a per-image index into X-Ways' internal pixel-analysis cache. Cross-correlate with `nInfoType=7` to learn the mapping. |
| **10** | **(NEW — undocumented)** | **live + ok=1 across all observed items, value always `0` on this clean snapshot. Most plausible identity: `XWF_ITEM_INFO_RELEVANCE`, added in v21.5 Preview 6 per the forum announcement (see [xways-api-history-19-to-21_4.md](xways-api-history-19-to-21_4.md)). The integer wasn't published; this empirical sweep nails it down.** Verify by setting a Relevance value via the X-Ways UI on one item and re-testing — the value at `nInfoType=10` should change. |
| 11 | `FileCount` | live + ok=1 |
| 16 | `EmbeddedOffset` | not observed live in this sample (probably set only on items extracted from container/archive parents) |
| 32–35 | `*Time` family | live + ok=1 (creation, modification, last-access, entry-modification) |
| 36, 37 | `DeletionTime`, `InternalCreationTime` | not observed live (no deleted items in sample; internal-creation often == creation) |
| 48–51 | `*_DISPLAY_OFS` for the four 32–35 timestamps | live + ok=1 — confirms the 21.2 Beta 6 addition is present in 21.7 |
| 52, 53 | `DeletionTimeDisplayOfs`, `InternalCreationTimeDisplayOfs` | not observed (same reason as 36/37) |
| 64, 65 | `_FLAGS_SET`, `_FLAGS_REMOVE` | write-only (per header) — not exercised |

**Practical takeaway:** when iterating items, you can request `nInfoType` 1..8, 10, 11, 32..37, 48..53 in one pass. Any other value `< 256` returns `ok=FALSE` (not live). `> 255` not yet tested.

### `nInfoType=3` (`Flags`) — bit values

The flags `INT64` returned from `XWF_GetItemInformation(id, 3, &ok)` carries multiple item-state bits. Confirmed against the community xwf-api-rs binding's `ItemInfoFlags`:

| Bit | Name | Meaning |
| ---: | --- | --- |
| `0x00000001` | `IsDirectory` | item is a directory (filter out before hashing/labeling per-file) |
| `0x00000002` | `HasChildObjects` | container surfaces children (not the same as IsDirectory!) |
| `0x00000004` | `HasSubDirectories` | |
| `0x00000008` | `IsVirtualItem` | X-Ways pseudo-item (e.g., `[root]`) |
| `0x00000010` | `HiddenByExaminer` | analyst tagged "hide" |
| `0x00000020` | `Tagged` | |
| `0x00000080` | `ViewedByExaminer` | |
| `0x00040000` | `Hash1AlreadyComputed` | primary hash present (use with `XWF_GetHashValue`) |
| `0x00100000` | `Hash2AlreadyComputed` | secondary hash present |
| `0x00800000` | `FoundInVolumeShadowCopy` | item is from a VSC, not the live FS |
| `0x01000000` | `DeletedFilesWithKnownOriginalContents` | |
| `0x02000000` | `FileFormatConstistencyOk` | |
| `0x04000000` | `FileFormatConstistencyNotOk` | |
| `0x100000000` | `FileEmbeddedinOtherFile` | (≥ 33-bit; use INT64) |

**Two common gotchas:** (1) some early X-Tensions had `XWF_ITEM_INFO_FLAGS = 0` and `IsDirectory = 0x02` — both wrong, the directory-skip silently no-ops. Use `3` for the info-type and `0x01` for IsDirectory. (2) the `0x02` value is `HasChildObjects`, *not* IsDirectory — easy to confuse.

The `FoundInVolumeShadowCopy` bit is the cleanest signal for "skip items that came from a VSC" — string-matching the path for `shadow` / `[vsc` is defence-in-depth but the flag is canonical.

## `XWF_GetItemType` — `nBufferLenAndFlags` is `len | flag_bits`

```c
LONG XWF_GetItemType(LONG nItemID, wchar_t* lpTypeDescr, DWORD nBufferLenAndFlags);
```

The low 24 bits of `nBufferLenAndFlags` carry the buffer length in `wchar_t`s; the high bits select **which** type label to return.

Definitive mapping confirmed empirically (2026-05-03) across 19 items spanning 14 different file-type categories (NTFS metafiles + JPEG, GZip, XML, INI, CSV, SQL, TTF, Wave, JPEG, Icon Cache, etc.):

| Flag bit set | Buffer content returned | Example values observed |
| --- | --- | --- |
| (none) | **empty** — buffer untouched, but `rv` carries the type-status integer | (no string) |
| `0x10000000` (bit 28) | **empty** — buffer untouched | (no string) |
| `0x20000000` (bit 29) | **type description** (file-format-specific label) | `JPEG`, `GZip`, `XML`, `True Type Fonts`, `Wave`, `Comma-separated values`, `Structured Query Language`, `LaTeX Auxiliary`, `Icon cache`, `Initialization`, `C/C++ Header`, `dns`, `NTFS system file`, `NTFS journal` |
| `0x40000000` (bit 30) | **type category** (the X-Ways `FileTypeCategory` grouping) | `Pictures`, `Archives/Backup`, `Misc Documents`, `Source Code`, `Programs`, `Cryptography`, `Various Data`, `Spreadsheet`, `Thumbnails/Icons`, `Fonts`, `Database, Finance`, `Audio`, `Other/unknown type`, `Windows Internals` |
| `0x80000000` (bit 31) | **same buffer content as bit 30** | Same category labels as bit 30, but `rv` differs: bit-30 returned `rv=0` for item 1043 (Pictures); bit-31 returned `rv=256` for the same item with the same buffer text. The 256 matches the `nBufferLen` we passed (`0x100`), so bit 31 may indicate "buffer length filled" rather than the type-status integer. Most uses should prefer bit 30; bit 31 is an apparent variant whose extra signal isn't yet decoded. |

These match xwf-api-rs's `FileTypeCategory` enum exactly (Picture, Archive, Source Code, Program, etc.) — the buffer returned at bit 30 is the human-readable form of that enum.

The **return value** (`LONG`, independent of the buffer flag) is the **type-status code** documented in [docs/events-viewer-empirical-findings.md](events-viewer-empirical-findings.md):

The **return value** (`LONG`, independent of the buffer flag) is the **type-status code** documented in [docs/events-viewer-empirical-findings.md](events-viewer-empirical-findings.md):

- `0` = not in list
- `1` = not confirmed
- `2` = confirmed
- `3` = mismatch detected

So `XWF_GetItemType` is really three queries in one — pick the buffer-flag bit for the label you need, the return value tells you the type-status independently.

## `XWF_GetMetadata` — undocumented export, likely deprecated

**Status: confirmed exported, real implementation, but uncallable from `XT_Prepare` in testing (21.7, build 1422138.89).**

Discovered by a PE export-table walk on 2026-05-03 against build 1422138.89:

- Export ordinal **33** (sibling to `XWF_GetMetadataEx` at ordinal 32).
- Function RVA `0x1B1020`; first 32 bytes confirm a real x64 implementation:

  ```text
  55 57 56 53                push rbp/rdi/rsi/rbx   ; save callee-saved regs
  48 83 ec 78                sub  rsp, 0x78         ; allocate stack frame
  48 8b ec                   mov  rbp, rsp
  89 cb                      mov  ebx, ecx          ; <- 1st arg = 32-bit (LONG/DWORD)
  48 89 d6                   mov  rsi, rdx          ; <- 2nd arg = 64-bit pointer
  48 8b 05 c1 af 45 00       mov  rax, [rip+0x45afc1]
  80 38 00                   cmp  byte ptr [rax], 0
  0f 84 d5 00 00 00          je   +0xd5             ; skip body if global flag == 0
  ```

- **Calling-convention shape: `something __stdcall XWF_GetMetadata(LONG/DWORD, void*)`.**
- Automated testing of all reasonable signatures (16 candidate shapes, plus per-item iteration across items 0..9 for the three highest-confidence shapes) — **every call AVs** in the function body. The prolog runs cleanly; the AV happens after the conditional `je +0xd5`, in the fall-through branch.

**Assessment (2026-05-03):** treat `XWF_GetMetadata` as a deprecated v18-era predecessor of `XWF_GetMetadataEx`. The export is retained in `xwforensics64.exe` for binary compat, but the metadata-storage subsystem its body reads from is no longer populated in modern X-Ways (21.7+). The conditional `je +0xd5` skips the body when the global flag is clear — and on the test snapshots the global flag is **set**, so the function falls through into code that dereferences the legacy structure that no longer exists, hence the AV.

**Don't call it.** Use `XWF_GetMetadataEx` instead, which is the supported replacement.

If a future X-Ways changelog re-introduces metadata-storage-system-1 functionality (or someone reverse-engineers the `XWF_PrepareXxx`-style call that re-populates the global), the function may become callable again — but until then, it's exported-but-dead.

This finding is a textbook example of why a PE export-table walk is worth running: it discovers symbols the SDK doesn't declare, **and** lets us reason about whether they're safe to use.

## `XWF_GetMetadataEx` — flag bits mostly do nothing

```c
LPVOID XWF_GetMetadataEx(HANDLE hItem, PDWORD lpnFlags);
```

Tested flag values: `0x00`, `0x01`, `0x02`, `0x04`, `0x08`, `0x10`, `0x20`, `0x40`, `0x80`, `0x100`, `0x200`, `0x10000`, `0x20000`. On every NTFS metafile in the sample, `*lpnFlags` came back as `0` (the flags are output-only — caller writes a value in but X-Ways always overwrites with 0).

Buffer behaviour, sampled on `$Bitmap`:

- `flags=0x01` → **NULL buffer** (suppression)
- All other flag values → **same** ~18-byte buffer containing UTF-16 string `"UTF-16BE"`

So bit `0x01` means "**don't return metadata**" / "ignore". All other bits are no-ops on this item type — the call returns whatever metadata X-Ways indexed (here: a text-encoding hint).

The buffer is owned by X-Ways and **must be released with `XWF_ReleaseMem`** when the X-Tension is done with it.

For items where X-Ways has no indexed metadata (`$MFT`, `$LogFile`, `$Volume`, `$AttrDef`, root dir, `$Boot`, `$BadClus`), every flag value returned NULL. So the function is "give me whatever metadata you indexed for this item, if any" — not a flag-driven selector.

**Empirical refinement (2026-05-03, across 19 items spanning 14 file-type categories):** on a snapshot where **RVS file metadata extraction has not yet been run**, the function returns a **detected text encoding hint string** for items where X-Ways has formed an opinion — not actual file metadata. Observed values: `"UTF-16BE"` for `$Bitmap`, `"UTF-16"` for `ARWConfig*.xml` and `WmiApRpl.ini`, NULL for the other 16 items. **The flag bits are inert in this state — every non-suppression flag returned the same encoding string.**

To exercise the real metadata-returning path (EXIF on JPEGs, ID3 on audio, Office document properties, etc.), run **Refine Volume Snapshot → Extract metadata + ...** before calling the X-Tension. Until that's done, `XWF_GetMetadataEx` is essentially an encoding-detection getter, not a metadata getter.

## `XWF_GetText` — `nFlags=0x02` triggers OCR / viewer-component invocation

```c
LPVOID XWF_GetText(HANDLE hItem, DWORD nFlags, int* lpnResult,
                   PDWORD lpnBufUsedSize, PDWORD lpnBufAllocSize);
```

Tested flag values: `0x00`, `0x01`, `0x02`, `0x04`, `0x08`, `0x10`. On the NTFS-metafile sample (none of which contain extractable text), `lpnResult` returned `0` for all flags **except `0x02`**, which returned `-3` for items that triggered the viewer/OCR pipeline.

When `nFlags=0x02` is set on items X-Ways treats as bitmap/image-like, it **shells out to OCR** — in testing, X-Ways invoked `Tesseract\Tesseract.exe` 8 times during the sweep (one per item that fit the criteria). Eight items in the sample were considered viewer-component candidates; the others (`$Volume`, `$BadClus`) were not.

This means:

- `nFlags=0x00` (or any of `0x01`/`0x04`/`0x08`/`0x10`) — **fast path** — only return text X-Ways already indexed; no external tool invocation.
- `nFlags=0x02` — **slow path** — invoke the viewer component / OCR pipeline. Will block on Tesseract for image-like items and on the viewer process for documents. Can fail with `-3` if external tools aren't installed.

**Recommendation for X-Tensions:** call `XWF_PrepareTextAccess(0, NULL)` once in `XT_Prepare`, then use `XWF_GetText` with `nFlags=0` for bulk text extraction. Only set `nFlags=0x02` for items where you actually want OCR / viewer-component output, and budget for the per-item cost (seconds per page on Tesseract).

The other return-code bits aren't yet decoded — `0` means "no text" but might also mean "not attempted"; `-3` correlates with "external tool failed" but isn't yet known to be specific. Re-test with Tesseract installed to disambiguate.

## See also

- [xways-reading-events-and-items.md](xways-reading-events-and-items.md) — analyzer pattern: events × items × content. References `XWF_PrepareTextAccess` + `XWF_GetText`.
- [events-viewer-empirical-findings.md](events-viewer-empirical-findings.md) — the type-status integer decoding (0..3) referenced above.
- [xtension-invocation.md](xtension-invocation.md) — when to call these (typically `XT_Prepare` for one-shot scans, or per-item callbacks for incremental work).
- [build-and-iteration-gotchas.md](build-and-iteration-gotchas.md) — `XWF_GetWindow` nWndNo / nWndIndex crash bounds (related X-Tension API surface).
