---
source: dw2102's X-Ways-DHFS4_1 X-Tension (community, MIT) — cross-referenced against the X-Ways SDK header (see getting-the-sdk.md) and forum-xtensions-distilled.md
type: empirical-finding + case-study
fetched: 2026-05-17
last_updated: 2026-05-17
author: research synthesis (community source + SDK header)
---

# Disk I/O X-Tension class — exports, signatures, lifecycle

A second X-Tension API class lives alongside the ordinary "volume snapshot" X-Tension surface: **Disk I/O X-Tensions** intercept sector- and file-level reads from X-Ways. They were first mentioned in forum threads (v19.2 Preview 3 — see [forum-xtensions-distilled.md](forum-xtensions-distilled.md)); dw2102's DAHUA DHFS4.1 X-Tension (community, MIT) is a complete working implementation to study.

Distinct from:

- **Ordinary X-Tensions** (the `XT_Prepare` / `XT_ProcessItem(Ex)` surface — the class most X-Tensions and most of these notes cover)
- **Image I/O API plugins** (`IIO_Init` / `IIO_Work` / `IIO_Done` — see [xways-image-io-api.md](xways-image-io-api.md)) which present a file as a synthetic disk

A Disk I/O X-Tension is still an X-Tension (loads via `xtensions\` auto-discovery and exports `XT_Init` / `XT_About` / `XT_Prepare`), but it adds four extra exports that let X-Ways delegate raw reads.

## The four extra exports

Verified in the DHFS4.1 X-Tension's `dhfs4_1.def`:

```
LIBRARY
EXPORTS
    XT_Init             @1
    XT_About            @2
    XT_Prepare          @3
    XT_Done             @4
    XT_ProcessItemEx    @5
    XT_SectorIOInit     @6
    XT_SectorIO         @7
    XT_FileIO           @8
    XT_SectorIODone     @9
```

Signatures (from the DHFS4.1 X-Tension's `dhfs4_1.cpp`):

```cpp
// Probe the boot sector to decide whether to claim this drive.
// Returns 0x11 (or other non-zero) to claim, 0 to decline.
DWORD XT_SectorIOInit(LPVOID lpPrivate, LONG nDrive, INT64 nSectorCount, LPVOID lpReserved);

// Per-sector-range read. Most implementations just defer to XWF_SectorIO.
DWORD XT_SectorIO(LPVOID lpPrivate, LONG nDrive, INT64 nSector, DWORD nCount,
                  LPVOID lpBuffer, DWORD nFlags);

// Per-file read for items the X-Tension has created during XT_Prepare.
INT64 XT_FileIO(LPVOID lpPrivate, LONG nDrive, HANDLE hVolume, HANDLE hItem,
                LONG nItemID, INT64 nOffset, LPVOID lpBuffer, INT64 nNumberOfBytes,
                DWORD nFlags);

// Cleanup for a sector-IO session.
DWORD XT_SectorIODone(LPVOID lpPrivate, LPVOID lpReserved);
```

## Lifecycle

The DHFS4.1 case follows this pattern (read top-down through the DHFS4.1 X-Tension's `dhfs4_1.cpp`):

1. `XT_SectorIOInit` fires when the user opens a disk. It receives `nDrive` and `nSectorCount`, then **probes the boot sector** via `XWF_SectorIO` to decide whether this is a filesystem the X-Tension can parse.
   - Return `0` → not interested. X-Ways carries on with its built-in parser chain.
   - Return non-zero (DHFS4.1 returns `0x11`) → claim the drive. Bit semantics here are undocumented and only known empirically — confirm by probing.
2. `XT_Prepare` fires next (with `nOpType` indicating a volume snapshot context). The X-Tension walks the on-disk structures, builds an internal in-memory model, and **creates synthetic items** via `XWF_CreateItem` / `XWF_SetItemInformation` / `XWF_SetItemSize` etc. Each synthetic item stores a tag in **extracted metadata** (DHFS4.1 uses a colon-delimited `"<partition>:<kind>:<descriptor>"` string) that `XT_FileIO` will later decode.
3. `XT_SectorIO` fires for each raw-sector read the analyst's UI gestures trigger (hex view, etc.). DHFS4.1 just delegates to `XWF_SectorIO`, but a Disk I/O X-Tension could also synthesise sector content here.
4. `XT_FileIO` fires when the analyst opens one of the synthetic items. **It supplies the bytes** — X-Ways doesn't know how to read the item, so it asks the X-Tension via this callback. See "The XT_FileIO contract" below.
5. `XT_SectorIODone` fires when the disk is closed. Free per-drive state here.

## The `XT_FileIO` contract

Three empirical constraints visible in the DHFS4.1 X-Tension's `dhfs4_1.cpp`:

**1. Decline with return `-1`.** If the item isn't one the X-Tension created (no extracted metadata tag in DHFS4.1's case), return `-1` and X-Ways falls back to its normal handling. Same idiom as `IIO_Init` returning NULL.

```cpp
LPWSTR lpMetaData = XWF_GetExtractedMetadata(nItemID);
if (lpMetaData == nullptr) {
    return -1;   // not ours
}
```

**2. 8 MB chunk ceiling per call.** Comment from `dhfs4_1.cpp` (line 320):

> `8388608 = 8MB, the maximum chunk size X-Ways can read per call of XT_FileIO`
> `If nNumberOfBytes is less then 8 MB no more fragments are following`

So a 50 MB item is delivered in seven calls (six × 8 MB + one tail). The X-Tension is responsible for tracking position across calls — DHFS4.1 keeps a `moreFragmentsOffset` static plus a `currentNItemID` to detect "new item, reset offset" transitions:

```cpp
if (currentNItemID != nItemID) {
    currentNItemID = nItemID;
    moreFragmentsOffset = 0;
}
// ... fill lpBuffer for this call ...
moreFragmentsOffset += min(nNumberOfBytes, bufferOffset);
if (moreFragmentsOffset >= XWF_GetItemSize(nItemID)) {
    moreFragmentsOffset = 0;   // end of file, ready for the next item
}
```

Note that `nOffset` is also provided as a parameter — DHFS4.1 uses **both** `nOffset` (the analyst-requested logical offset) and an internal cursor. The internal cursor is needed because chunked reads from a single sequential gesture may carry `nOffset == 0` repeatedly even though earlier bytes have already been delivered. Confirm empirically before relying on this — it may be specific to DHFS4.1's use of `XWF_GetExtractedMetadata` as the per-item tag.

**3. Return value = bytes written.** Match `nNumberOfBytes` for a full read; less if you hit EOF inside the chunk. `XWF_GetItemSize(nItemID)` is the authoritative item size for end-of-file detection.

## Pairing with `XWF_SectorIO`

`XT_SectorIO` (callback from X-Ways) and `XWF_SectorIO` (call into X-Ways) are easy to confuse. They are inverses:

- **`XT_SectorIO`** — X-Ways calls *us* for sector reads on a drive we claimed.
- **`XWF_SectorIO`** — we call *X-Ways* to read raw sectors from any drive (including the one we claimed — useful for parsing on-disk structures during `XT_Prepare`).

DHFS4.1's `XT_SectorIO` body is literally `return XWF_SectorIO(nDrive, nSector, nCount, lpBuffer, &nFlags);` — i.e., "we claimed the drive but for sector-level reads we have nothing special to do, hand it back to X-Ways' default reader." Real claim value is in `XT_FileIO`'s file-level synthesis.

The fact that this delegation works at all means: claiming a drive in `XT_SectorIOInit` doesn't prevent the X-Tension from calling `XWF_SectorIO` against the same drive. There's no infinite recursion — X-Ways tracks the "ask the X-Tension first" flag per call site, not per drive.

## What this enables

The DHFS4.1 model is "filesystem parser as X-Tension." X-Ways has built-in parsers for NTFS / FAT / exFAT / Ext / HFS+ / APFS / etc. A Disk I/O X-Tension lets you slot a **new filesystem** into that chain without modifying X-Ways. Other natural fits:

- Proprietary CCTV recorder formats (dw2102's HIKVISION X-Tension is the volume-snapshot variant; DHFS4.1 is the Disk I/O variant of the same idea)
- Custom embedded-device filesystems (cars, IoT, medical devices)
- Vendor formats that ship in raw acquisitions but aren't worth adding to mainline X-Ways

## See also

- [xways-image-io-api.md](xways-image-io-api.md) — the *other* "wedge a parser in" API: presents a file as a disk; complementary to Disk I/O, which presents a disk as a parseable filesystem
- [xtension-invocation.md](xtension-invocation.md) — entry-point + action-code reference; Disk I/O exports live alongside the ordinary X-Tension ones
- [forum-xtensions-distilled.md](forum-xtensions-distilled.md) — original v19.2 Preview 3 announcement context
- Open questions still worth investigating:
  - Exact bit semantics of `XT_SectorIOInit`'s non-zero return value (DHFS4.1 uses `0x11`; the bits aren't documented).
  - Whether `XT_FileIO`'s `nOffset` is monotonic across chunked reads, or whether the implementation is required to maintain its own cursor.
  - Whether `XT_FileIO` is ever called concurrently from multiple threads for the same item (DHFS4.1 assumes single-threaded — uses statics for cursor state).
  - Whether the 8 MB chunk size is a hard upper bound or just what the analyst's build happens to emit.
  - How `XT_FileIO` interacts with carved/embedded items that are *not* created by the X-Tension itself.
