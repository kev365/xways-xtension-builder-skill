---
source: https://www.x-ways.net/forensics/x-tensions/XWF_functions.html (live page) + empirical testing (2026-05-03)
type: official-doc + empirical-finding
fetched: 2026-04-26
last_updated: 2026-08-13
author: X-Ways Software Technology AG (official page); empirical sweep notes
---

# `XWF_GetCaseProp` / `XWF_GetEvObjProp` — property type reference

The two property-getter functions in the X-Tension API expose case-level and evidence-object-level metadata via `nPropType` integers. The X-Ways SDK header (see [getting-the-sdk.md](getting-the-sdk.md)) declares the function pointer typedefs but **does not include `#define`s for the property numbers** — those are documented only on the live API page at [x-ways.net](https://www.x-ways.net/forensics/x-tensions/XWF_functions.html).

**This doc captures the property numbers explicitly so they can be used without re-fetching the live page.**

## Contents

- `XWF_GetCaseProp`
- `XWF_GetVSProp` (volume snapshot properties)
- `XWF_GetProp` (volume / item handle)
- `XWF_GetEvObjProp`
- Properties 30 / 31 — time-zone bias and daylight saving
- Recommended pattern: temp base resolution
- See also

## `XWF_GetCaseProp`

```c
INT64 XWF_GetCaseProp(LPVOID pReserved, LONG nPropType, PVOID pBuffer, LONG nBufLen);
```

Pass `pReserved = nullptr`. Return value depends on the property — typically the byte length copied into `pBuffer`, or the value itself for fixed-width fields.

| `nPropType` | Symbol | Returns | Type |
| ---: | --- | --- | --- |
| 0 | `XWF_CASEPROP_ID` | Unique 64-bit case identifier | `INT64` |
| 1 | `XWF_CASEPROP_TITLE` | Case title | `LPWSTR` |
| 2 | `XWF_CASEPROP_CREATION` | Case creation time | `FILETIME` |
| 3 | `XWF_CASEPROP_EXAMINER` | Examiner name | `LPWSTR` |
| 5 | `XWF_CASEPROP_FILE` | Path to the `.xfc` case file | `LPWSTR` |
| 6 | `XWF_CASEPROP_DIR` | Case directory | `LPWSTR` |

Note the gap at 4 — not documented as of 2026-04-26.

Sweeps (2026-05-03) covering `nPropType` 0..127 on a typical case found no other live CaseProp values — the inventory above is complete for that range.

**Empirical (observed 2026-06-05):** property 6 (`CASEPROP_DIR`) returns the case directory in Win32 **extended-length form** — e.g. `\\?\C:\…\case\<name>`, not `C:\…`. (Property 5, the `.xfc` path, almost certainly does too.) Strip a leading `\\?\` (and map `\\?\UNC\` → `\\`) before displaying the path to the analyst or passing it to shell APIs (`SHCreateDirectoryExW`, `SHBrowseForFolder`) that don't accept the prefix. The wide `CreateFileW`/`CreateDirectoryW` family accepts it fine, so it's only a display/shell-API concern.

## `XWF_GetVSProp` (volume snapshot properties)

```c
INT64 XWF_GetVSProp(LONG nPropType, PVOID pBuffer);
```

Header constants in the X-Ways SDK header (see [getting-the-sdk.md](getting-the-sdk.md)): `XWF_VSPROP_SPECIALITEMID = 10`, `_HASHTYPE1 = 20`, `_HASHTYPE2 = 21`, `_SET_HASHTYPE1 = 25`, `_SET_HASHTYPE2 = 26`. The official page adds `_SET_HASCHANGED = 30` (v20.9 SR-12 / v21.0 SR-10 / v21.1 SR-9 / v21.2 SR-5 and later) and `_RESET = 90` (v21.4+). Empirically (observed 2026-05-03):

| `nPropType` | Observed status |
| ---: | --- |
| 10 | `SPECIALITEMID` — header. Not observed live on this snapshot. |
| 11 | **Live** — returns 2 zero bytes. Not in header or xwf-api-rs. Identity unknown. |
| 20, 21 | `HASHTYPE1`, `HASHTYPE2` — live, return 7-byte buffers. |
| 25, 26 | **Write-only.** `pBuffer` must point at a byte holding the desired hash type. Returns `<0` on error, `0` if that type was already set, `1` if newly set. **Warning (official): hash values already computed under a different type are discarded by this call.** |
| 30 | **Write-only** — `_SET_HASCHANGED`. `pBuffer` must point at a byte holding `0xFF`. Marks the snapshot dirty so it gets saved by the time its data window closes. Needed when you mutate a volume snapshot *other* than the one named in your `XT_Prepare` call, or mutate one outside RVS on v21.2 or earlier. |
| 90 | **`XWF_VSPROP_RESET` — destructive.** See the warning below. |
| Other 0..127 | Returned `-1` (unsupported). |

!!! danger "`nPropType = 90` discards the volume snapshot — and our own sweep called it"
    Property **90** is `XWF_VSPROP_RESET` (v21.4 and later). Per the official
    page it **forces X-Ways to take a new volume snapshot and discard the
    previous one, without the usual warning** that tags, search hits and
    refinement results will be lost. Return value is `>0` on success.

    The 2026-05-03 read-only sweep recorded it as *"live, returns 1 zero byte,
    identity unknown, probably status flag"* — i.e. it was **called blind**, on a
    live snapshot, before anyone knew what it did. The returned `0` suggests it
    did not take effect on that build, but that is luck, not design.

    This is the concrete cost of the opt-out sweep the rest of this page warns
    about. **Sweep property numbers by whitelist, never by range** — and when a
    number is unknown, find out what it is before calling it, not after. The same
    reasoning retired the `XWF_GetEvObjProp(…, 100, …)` sweep (see
    [build-and-iteration-gotchas.md](build-and-iteration-gotchas.md)).

### Hash types and their sizes

`HASHTYPE1` / `HASHTYPE2` return a **type code**, and every buffer that receives
a hash value — `XWF_GetHashValue`, `XWF_GetEvObjProp` 21 and 41 — must be sized
from it. The catalogue below is from `xwf-api-rs`
(`XwfHashType` + `get_hash_size`), which is community reverse-engineering, not
the official list:

| Code | Algorithm | Bytes | Code | Algorithm | Bytes |
| ---: | --- | ---: | ---: | --- | ---: |
| 1 | CS8 | 1 | 11 | RIPEMD-160 | 20 |
| 2 | CS16 | 2 | 12 | MD4 | 16 |
| 3 | CS32 | 4 | 13 | ED2K | 16 |
| 4 | CS64 | 8 | 14 | Adler32 | 4 |
| 5 | CRC16 | 2 | 15 | Tiger Tree Hash | 24 |
| 6 | CRC32 | 4 | 16 | Tiger128 | 16 |
| 7 | MD5 | 16 | 17 | Tiger160 | 20 |
| 8 | SHA-1 | 20 | 18 | Tiger192 | 24 |
| 9 | SHA-256 | 32 | 19 | MD5 folded | 16 |
| 10 | RIPEMD-128 | 16 | | | |

Code **19 (MD5 folded)** exists only from **v20.9** in that binding's gating.

!!! warning "Treat these numbers as provisional"
    v21.5 Preview 3 **changed three hash-type IDs and deprecated six**, and the
    announcement pointed at the `XWF_GetVSProp` documentation for the current
    list rather than publishing the new numbers (see
    [xways-api-recency-research.md](xways-api-recency-research.md)). The table
    above predates that change in origin, so a code taken from it may name a
    different algorithm on 21.5 and later.

    **Use it to size a buffer, not to label a hash in a report.** If the
    algorithm name reaches analyst-facing output or a report table, read the
    current list off the official page for the host version you target.

## `XWF_GetProp` (volume / item handle)

```c
INT64 XWF_GetProp(HANDLE hVolumeOrItem, DWORD nPropType, void* lpBuffer);
```

Empirical sweep on a partition volume handle (observed 2026-05-03):

| `nPropType` (volume) | Returns | Notes |
| ---: | --- | --- |
| 0 | Volume size **in bytes** | **Confirmed 2026-08-15** (21.9 Beta 1): equals `XWF_GetEvObjProp` 16 and the exact image byte size (64 MiB image → 67108864). The SDK's QTest.cpp labels this value `" MB"` — that label is wrong. |
| 1 | Same as 0 (logical size) | Equal to 0 on a volume handle, confirmed live. |
| 2 | Valid data length | Returns **-1** on a volume handle (observed 2026-08-15) — meaningful for items only. |
| 2 | (numeric) | Internal pointer-shaped value. Probably opaque. |
| 16 | (numeric, small) | Empirical 3 — possibly a bitmap of features. |
| **3..15, 17..127** | Identical pointer-shaped value across all of these | **Sentinel** — the function returns the same pointer-looking value for every unsupported property number, suggesting a single "unknown" handler. **Don't treat anything past 2 (or 16) as live.** |

Per-item `XWF_GetProp` only meaningful when the item is open (`XWF_OpenItem` first). Surface largely overlaps with `XWF_GetItemInformation`/`XWF_GetItemSize` for individual fields; prefer those when known.

## `XWF_GetEvObjProp`

```c
INT64 XWF_GetEvObjProp(HANDLE hEvidence, DWORD nPropType, PVOID pBuffer);
```

Pass `hEvidence` from `XT_Prepare`. Buffer length is **MAX_PATH wchars** for the path-typed properties.

| `nPropType` | Symbol (xwf-api-rs) | Returns | Type | Notes / availability |
| ---: | --- | --- | --- | --- |
| 0 | `ObjNumber` | Evidence-object number (order in case tree) | `WORD` | May change as EOs are reordered. |
| 1 | `ObjId` | Evidence-object ID (stable, used for parent-child relationships) | `DWORD` | |
| 2 | `ParentObjId` | Parent EO ID (partitions → parent disk) | `DWORD` | 0 if no parent. |
| 3 | `ShortEvObjId` | Short EO ID (used in directory-browser unique IDs) | `WORD` | v18.8 SR-14 / v18.9 SR-12 / v19.0 SR-11+ |
| 4 | `VsSnapshotId` | Volume snapshot ID (increments when a new VS is taken) | `DWORD` | **v19.0 SR-11+** |
| 6 | `ObjTitle` | EO title (e.g. `"Partition 2"`) | `LPWSTR` | |
| 7 | `ExtObjTitle` | Extended EO title (e.g. `"HD123, Partition 2"`) | `LPWSTR` | Buffer = `MAX_PATH`; rv = string length. |
| 8 | `AbbrevObjTitle` | Abbreviated extended title (e.g. `"HD123, P2"`) | `LPWSTR` | Buffer = `MAX_PATH`; rv = string length. |
| 9 | `InternalName` | Internal name | `LPWSTR` | |
| 10 | `Description` | Description | `LPWSTR` | |
| 11 | `ExaminerComments` | Examiner comments | `LPWSTR` | |
| 12 | `IntUsedDir` | **Internally used directory** | `LPWSTR` | **X-Ways-configured working/temp folder for this evidence.** Use for X-Tension scratch space — honors General Options → Folders. Buffer = `MAX_PATH`. |
| 13 | `OutputDir` | Output directory | `LPWSTR` | Where Recover/Copy writes. Don't use for temp scratch. |
| 16 | `SizeInBytes` | EO size in bytes | `INT64` | |
| 17 | `VSFileCount` | Volume snapshot file count | `DWORD` | |
| 18 | `Flags` | Flags / status bitmap | `INT64` | |
| 19 | `FileSystemID` | File-system identifier (matches `XWF_GetVolumeInformation` enum) | `INT64` | xwf-api-rs has it; **not observed in the sweep** — re-test or check whether NTFS reports here. |
| 20 | `HashType` | Hash type | `DWORD` | |
| 21 | `HashValue` | Hash value | `LPVOID` | Buffer size = hash type size; rv = hash size in bytes. |
| 30 | `ReferenceTimeZone` | **Reference time-zone bias, in minutes** | `INT16` + optional DST struct | **v21.2+** — see below. |
| 31 | `ReferenceTimeZoneUser` | **Display time-zone bias chosen by the user**, in minutes | `INT16` + optional DST struct | **v21.2+** — per-evidence-object or case-wide. |
| 32 | `CreationTime` | Time the EO was added to the case | `FILETIME` | |
| 33 | `ModificationTime` | EO modification time | `FILETIME` | xwf-api-rs has it; not observed in the sweep. |
| 40 | `HashType2` | Secondary hash type | `DWORD` | |
| 41 | `HashValue2` | Secondary hash value | `LPVOID` | Same buffer convention as 21. |
| 50 | `NumberOfDataWindow` | Data-window number that currently represents this EO | `WORD` | **v19.9 SR-7+** — `0` if EO is not open in any data window. |
| 100 | (write-side) | **Sets a new image path** for the EO | `BOOLE` rv, `LPWSTR` in | **v21.5 SR-5+.** Plain path, **not** in the square-bracket notation of property 9. Closes the EO's data window; dependent partitions are updated too ("Replace with new image"). Never call read-side — see [build-and-iteration-gotchas.md](build-and-iteration-gotchas.md). |

## Properties 30 / 31 — time-zone bias and daylight saving

Both return the bias **in minutes** in the **low 16 bits** of the return value
(`0` = UTC, `+60` = UTC+1, `-60` = UTC-1), not accounting for daylight saving.
Mask off everything above bit 15 — the official page says explicitly to ignore
it. Three sentinel values are defined:

| Value | Meaning |
| ---: | --- |
| `10000` | variable / defined per file (evidence file container, exFAT) |
| `10001` | unknown or undefined (e.g. FAT32 with no reference zone set) |
| `10002` | undefinable (partitioned storage device, unsupported file system) |

`lpBuffer` is optional. Pass `NULL`, or pass a **zeroed** `DaylightSavingsDefinition`
— zeroing before the call is required, not advisory:

```c
#pragma pack(2)
struct DaylightSavingsDefinition {   // 8 bytes
    WORD FlagsAndMore;               // highest bit: is DST observed at all?
    BYTE DaylightSavingStartHour;
    BYTE DaylightSavingStartDayAndWeek;  // high nibble = weekday (0 = Sunday)
    BYTE DaylightSavingStartMonth;       // low nibble  = nth weekday (5 = last)
    BYTE DaylightSavingEndHour;
    BYTE DaylightSavingEndDayAndWeek;
    BYTE DaylightSavingEndMonth;         // 1 = January … 12 = December
};
```

If the top bit of `FlagsAndMore` is clear, **every remaining byte is meaningless** —
check it first.

The two are not interchangeable. **30 is a property of the data** (the zone the
evidence object's timestamps are stored against); **31 is a property of the
view** (what the analyst chose to display). Timestamp conversion wants 30;
matching what the analyst sees on screen wants 31.

!!! warning "The community Rust binding has 30 and 31 the wrong way round"
    `xwf-api-rs`'s `get_reference_time_zone(display_timezone: bool)` maps
    `true → 30` and `false → 31`, but 30 is the *reference* zone and 31 is the
    *display* zone — so the parameter selects the opposite of what it names.
    Verified against the official page 2026-08-13. A useful reminder that the
    binding is reverse-engineering, not documentation: cross-check the numbers,
    not the names.

Note also that a missing reference time zone does not mean *no* timestamp in
that evidence object is UTC — certain archive types carry UTC timestamps
regardless. `XWF_GetItemInformation` with `XWF_ITEM_INFO_FLAGS` tells you
per item; see [xways-itemtype-metadata-text.md](xways-itemtype-metadata-text.md).

Sources:

- **The named symbols above are taken from [xwf-api-rs](https://github.com/ThomasVogl/xwf-api-rs) (`xwf_api_rs/src/xwf_types/xwf_enums.rs::EvObjPropType`)** — Rust binding by Thomas Vogl, **LGPL-3.0**. xwf-api-rs has reverse-engineered the full property catalog from observing the live binary, so it captures values the official C/C++ header omits.
- **Numeric examples + buffer hex** are from an empirical sweep (2026-05-03) on a partition EO in build 1422138.89.
- **Authoritative cross-check:** the [live API HTML](https://www.x-ways.net/forensics/x-tensions/XWF_functions.html) when the xwf-api-rs source disagrees with empirical observation.

## Recommended pattern: temp base resolution

For X-Tensions that need to write temp files (e.g., exporting items for processing by an external helper), the canonical fallback chain is:

```cpp
typedef INT64 (__stdcall *pfn_XWF_GetEvObjProp)(HANDLE, DWORD, PVOID);
static pfn_XWF_GetEvObjProp XWF_GetEvObjProp = nullptr;

// Resolve in XT_Init:
//   XWF_GetEvObjProp = (pfn_XWF_GetEvObjProp)GetProcAddress(h, "XWF_GetEvObjProp");

// Returns the X-Ways-configured working dir for this evidence, or empty
// string if the call fails (e.g., legacy X-Ways build, or some property
// states where it's not set up).
static std::wstring GetEvidenceWorkingDir(HANDLE hEvidence) {
    if (!XWF_GetEvObjProp || !hEvidence) return {};
    wchar_t buf[MAX_PATH] = {0};
    XWF_GetEvObjProp(hEvidence, 12, buf);
    return buf[0] ? std::wstring(buf) : std::wstring();
}

// Pick a temp base, preferring X-Ways' configured location.
static std::wstring PickTempBase(HANDLE hEvidence) {
    std::wstring xwfDir = GetEvidenceWorkingDir(hEvidence);
    if (!xwfDir.empty()) return xwfDir;
    wchar_t base[MAX_PATH] = {0};
    GetTempPathW(MAX_PATH, base);
    return base;
}
```

Why prefer the evidence working dir over `%TEMP%`:

- **Honors forensic-shop policy.** Many shops configure X-Ways to put temp data on a specific drive (often a fast NVMe scratch volume or an encrypted partition for chain-of-custody reasons). Using the X-Ways-configured location means the X-Tension respects that setup automatically.
- **Co-locates with X-Ways' own temp data.** Cleanup tools and disk-budget monitoring already cover that location.
- **No per-X-Tension config duplication.** Otherwise every X-Tension that writes temp files needs its own `temp_dir` setting, multiplied across however many shops have unusual layouts.

The `XWF_GetEvObjProp` call may fail or return an empty buffer in some edge cases (very old X-Ways builds, evidence that doesn't have a dedicated working dir yet). Falling back to `GetTempPathW` keeps the X-Tension functional.

## See also

- [xways-events-api.md](xways-events-api.md) — Events viewer API reference.
- [xtension-invocation.md](xtension-invocation.md) — entry points + invocation modes.
- The X-Ways SDK header (see [getting-the-sdk.md](getting-the-sdk.md)) — function-pointer typedefs only; the property numbers live in the online docs.
