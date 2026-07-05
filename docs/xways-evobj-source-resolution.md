---
source: empirical sweeps (2026-05-06)
type: empirical-finding
fetched: 2026-05-06
last_updated: 2026-05-06
author: empirical research notes
---

# Resolving an evidence object's source path

How to recover the on-disk path (or other input source) X-Ways used to acquire/load an evidence object, when an X-Tension needs to feed external tools (bulk_extractor, yara, …) the underlying bytes.

## "EO added as File" vs "EO added as Disk" — the only distinction that matters

Empirically derived from runs across four contexts on a 21.7 build (1422138.89). The image **format** (E01, DD, XWFIM, …) is not the variable. The variable is **how the analyst added it to the case**:

| How added | Example | `XWF_GetVolumeName(hVolume)` returns | Source-path strategy |
| --- | --- | --- | --- |
| **As File** (drag-drop, "Add File…") | `DC01-E01.E01` dropped into Case Root | The full source path (extension may be stripped for libewf-segmented sets — segment-1 base name only) | Use `XWF_GetVolumeName` directly. Done. |
| **As Disk** — running on the disk EO | `20200918_0347_CDrive` (an .E01 added as Disk) | Just the friendly EO name (no path) | `XWF_GetVolumeName` is **not** the path. Dereference the pointer-typed properties (9 / 10 / 11) — see below. |
| **As Disk** — running on a partition under it | `Partition 2` of `20200918_0347_CDrive` | Partition friendly name (`20200918_0347_CDrive, Partition 2`) | Walk to the parent EO and apply the disk strategy. Empirically `XWF_OpenEvObj(parent, 0) + XWF_GetVolumeName` *also* returns just the friendly name in this mode — pointer-deref on the parent's prop 9 is untested; confirm empirically. |
| **Case Root** | (no EO selected) | n/a — `hVolume == NULL` | No source path resolvable; X-Tension should disable the EO-source mode. |

### The right API is `XWF_GetProp` (NOT `XWF_GetEvObjProp`)

Source for this finding: the SDK's own Python binding (`Python.cpp`, shipped with the X-Ways SDK — see [getting-the-sdk.md](getting-the-sdk.md)). It defines a `GetFilePath(hVolumeOrHItem)` Python function that calls:

```cpp
wchar_t* filePath = (wchar_t*) XWF_GetProp((HANDLE) itemID, 8, nullptr);
```

So **`XWF_GetProp(hVolumeOrItem, 8, NULL)` returns the file path** as a `wchar_t*` directly through the `INT64` return value (the buffer must be `NULL`, not a buffer pointer). The Python wrapper docstring says `"Returns the file path, if available, or just the filename"`.

**Property numbers for `XWF_GetProp`** — extracted from Python.cpp:

| nPropType | Returns | Type | How returned |
| --- | --- | --- | --- |
| **0** | physical size | `INT64` | direct INT64 return |
| **1** | logical size | `INT64` | direct INT64 return |
| **2** | data length (valid data length) | `INT64` | direct INT64 return |
| **4** | file attributes | `DWORD` | direct INT64 return (cast) |
| **8** | **file path** | `wchar_t*` | INT64 return is a pointer to internal state — deref, do not free |
| **9** | pure name | `wchar_t*` | INT64 return is a pointer — deref, do not free |
| **10** | parent volume handle | `HANDLE` | INT64 return |
| **16** | data-window number (1-based) | `WORD` | INT64 return (cast) |

The empirical TSV confirms the pointer pattern: `XWF_GetProp.volume nPropType=8` returned `62910800` (= `0x03BFCB10`), and prop 9 returned `62910928` (`0x03BFCB90`) — separate buffers in the same heap region. The dereferenced strings are the path and pure name respectively.

`XWF_GetEvObjProp` is the **wrong** API for source-path queries. Its small-numeric returns for properties 9/10/11 might also be heap pointers, but they're *not* documented anywhere and serve a different purpose (per-EO metadata, not per-volume).

### Recommended source-resolution algorithm

For X-Tensions like `bulk_extractor` that feed external tools:

```text
1. INT64 rv = XWF_GetProp(hVolume, 8, NULL);
   if (rv > 0x10000) {
       wchar_t* path = (wchar_t*)rv;
       if (path[0] && (path[1] == L':' || path[0] == L'\\')) {
           // looks like an absolute path — try it
           if (FileExists(path) || DirExists(path)) USE IT;
       }
   }

2. If active EO is a partition or sub-EO, walk to parent:
   parentID = XWF_GetEvObjProp(hEvidence, 2, NULL);
   parentEO = XWF_GetEvObj(parentID);
   parentVol = XWF_OpenEvObj(parentEO, 0);
   try step 1 on parentVol;
   XWF_CloseEvObj(parentVol);

3. Fallback: stream bytes via XWF_OpenItem(hVolume, 0, ...) + XWF_Read
   into a temp file, then point the external tool at the temp.
```

Steps 1+2 should handle every EO class (file-backed, image-as-disk, partition-of-disk-image, XWFIM). Step 3 is the universal fallback for anything truly with no source file (live volumes, RAID-reconstructed, decrypted-Bitlocker, etc.).

## What individual properties actually return

`XWF_GetEvObjProp(hEvidence, nPropType, buf)` — measured on 21.7 (1422138.89) across the four EO contexts above.

| Prop | Meaning | Reliable? |
| --- | --- | --- |
| 0 | Some short byte field (1–7 bytes, usually all zeros) | unclear |
| **1** | **The EO's own ID (DWORD)** | yes — matches `XWF_GetEvObj` lookup |
| **2** | **Parent EO ID** (use the **INT64 return value, NULL buffer** form) | yes — `0` means top-level |
| 3 | Variable-length zero-padded blob | unclear (placeholder?) |
| 4 | Some ID, often `prop1 - 1` | unclear (sibling? prior version?) |
| 5 | `-1` (not present) on every test | empty |
| 6 | Small numeric → memory pointer leak | **junk** — do not parse |
| **7** | Extended title / friendly EO name | yes — but a *name*, not a path. May happen to be the filename for file-backed EOs. |
| **8** | Short title (truncated form) | yes |
| 9 | Documented as "source notation"; in practice returns a memory pointer leak (e.g., `52370180`) for every EO tested | **junk** — do not parse |
| 10, 11 | Memory pointer leaks | **junk** |
| **12** | EO's case-temp directory: `<case>\_<EO_name>` | yes — but it's the *case temp dir*, NOT the source |
| **13** | EO's case-data directory: `<case>\<EO_name>` | yes — but it's the *case data dir*, NOT the source. Often empty. |
| 14, 15 | `-1` | empty |
| **16** | **EO total size in bytes** | yes (12079595520 for an 11.25 GB disk; 11710496768 for the partition) |
| **17** | **Item count of the EO's snapshot** | yes (matches the count shown in the case tree) |
| 18 | 18-byte zeroed buffer | placeholder |
| 19 | `-16` | unclear — perhaps a status enum |
| 20 | 8-byte zeroed buffer | placeholder |
| **21** | **20-byte hash** (SHA-1 length) | yes — likely SHA-1 of the acquired data |
| 22..29 | `-1` | empty |
| 30 | Numeric (e.g., `10002`) | unclear |
| 31 | `0` | empty |
| **32, 33** | Windows FILETIMEs | yes — acquisition / modification timestamps |
| 34..40 | `-1` or zero blobs | empty / placeholder |
| **41** | 16-byte UUID | yes — EO unique identifier |
| 42..99 | `-1` | empty |
| 100 | **Write-only** — replaces the EO's image (do not call read-side, per 21.5 SR-5 forum) | dangerous |
| 101..127 | `-1` | empty |

The pattern: most "return -1" properties are unused slots reserved for future API additions.

## Detecting a leaked pointer return

Properties 6, 9, 10, 11 return `INT64` values that look like memory addresses (e.g. `52370180`, `63080720`) when the EO has no string to give back. Heuristic to detect:

- `rv` is small (under 1 GB or so — well below typical buffer-fill sizes).
- The buffer doesn't decode as plausible UTF-16 (no human-readable substring).
- `rv` doesn't equal the buffer's actual content length.

If your X-Tension treats any of these properties as path strings, validate the result with `FileExists()` / `DirExists()` before passing it to anything.

## API note (see "right API" section above for what to actually do)

`XWF_GetEvObjProp(eo, 9, ...)` does **not** return the source notation as an embedded string — its small-numeric returns are *not* the source path. The path lives in `XWF_GetProp(hVolume, 8, NULL)` instead. The deref recipe is the same — return value is a `wchar_t*` to internal state — but the calling API and property number differ.

## See also

- [xways-getprop-reference.md](xways-getprop-reference.md) — older property-number reference (predates these empirical findings).
- Wrapper X-Tensions that feed external tools (bulk_extractor-style) are the main consumers of this resolution logic.
