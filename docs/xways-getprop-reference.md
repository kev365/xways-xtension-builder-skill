---
source: https://www.x-ways.net/forensics/x-tensions/XWF_functions.html (live page) + empirical testing (2026-05-03)
type: official-doc + empirical-finding
fetched: 2026-04-26
last_updated: 2026-05-03
author: X-Ways Software Technology AG (official page); empirical sweep notes
---

# `XWF_GetCaseProp` / `XWF_GetEvObjProp` — property type reference

The two property-getter functions in the X-Tension API expose case-level and evidence-object-level metadata via `nPropType` integers. The X-Ways SDK header (see [getting-the-sdk.md](getting-the-sdk.md)) declares the function pointer typedefs but **does not include `#define`s for the property numbers** — those are documented only on the live API page at [x-ways.net](https://www.x-ways.net/forensics/x-tensions/XWF_functions.html).

**This doc captures the property numbers explicitly so they can be used without re-fetching the live page.**

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

Header constants in the X-Ways SDK header (see [getting-the-sdk.md](getting-the-sdk.md)): `XWF_VSPROP_SPECIALITEMID = 10`, `_HASHTYPE1 = 20`, `_HASHTYPE2 = 21`, `_SET_HASHTYPE1 = 25`, `_SET_HASHTYPE2 = 26`. xwf-api-rs adds `SetHasChanged = 30` (v21.2 SR-5+) and the unnumbered `_RESET` (v21.4 Beta 3+). Empirically (observed 2026-05-03):

| `nPropType` | Observed status |
| ---: | --- |
| 10 | `SPECIALITEMID` — header. Not observed live on this snapshot. |
| 11 | **Live** — returns 2 zero bytes. Not in header or xwf-api-rs. Identity unknown. |
| 20, 21 | `HASHTYPE1`, `HASHTYPE2` — live, return 7-byte buffers. |
| 25, 26, 30 | **Write-only.** Don't call read-side — calling with a zeroed buffer can mutate snapshot state. A read-only sweep should blacklist these. |
| 90 | **Live** — returns 1 zero byte. Not in header or xwf-api-rs. Identity unknown. Probably status flag. |
| Other 0..127 | Returned `-1` (unsupported). |

## `XWF_GetProp` (volume / item handle)

```c
INT64 XWF_GetProp(HANDLE hVolumeOrItem, DWORD nPropType, void* lpBuffer);
```

Empirical sweep on a partition volume handle (observed 2026-05-03):

| `nPropType` (volume) | Returns | Notes |
| ---: | --- | --- |
| 0 | Volume size in bytes | Empirical: matches `XWF_GetEvObjProp` property 16. |
| 1 | Same as 0 | Possibly an alias or sector count. |
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
| 30 | (timezone-related) | (likely time-zone offset / DST flag) | (TBC) | **v21.2 Beta 6+** — announced as a new property type but number not stated; cross-referenced via [xways-api-history-19-to-21_4.md](xways-api-history-19-to-21_4.md). Re-test to confirm. |
| 31 | (timezone-related) | (likely time-zone name / region string) | (TBC) | **v21.2 Beta 6+** — announced together with 30. Re-test to confirm. |
| 32 | `CreationTime` | Time the EO was added to the case | `FILETIME` | |
| 33 | `ModificationTime` | EO modification time | `FILETIME` | xwf-api-rs has it; not observed in the sweep. |
| 40 | `HashType2` | Secondary hash type | `DWORD` | |
| 41 | `HashValue2` | Secondary hash value | `LPVOID` | Same buffer convention as 21. |
| 50 | `NumberOfDataWindow` | Data-window number that currently represents this EO | `WORD` | **v19.9 SR-7+** — `0` if EO is not open in any data window. |
| 100 | (write-side) | Replaces the EO's image | (write op) | **v21.5 SR-5+** — write side documented in forum. Read side: needs testing. |

Sources:

- **The named symbols above are taken from [xwf-api-rs](https://github.com/ThomasVogl/xwf-api-rs) (`xwf_api_rs/src/xwf_types/xwf_enums.rs::EvObjPropType`)** — Rust binding by Thomas Vogl, MIT-licensed. xwf-api-rs has reverse-engineered the full property catalog from observing the live binary, so it captures values the official C/C++ header omits.
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
