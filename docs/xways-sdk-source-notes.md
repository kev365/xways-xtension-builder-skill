---
source: the X-Ways SDK source drops (2024-05-31 zip + git HEAD c46a1bd2) and the XT_Python 3.12 binary bundle — see getting-the-sdk.md; reviewed in full 2026-08-14
type: research-summary
fetched: 2026-08-14
last_updated: 2026-08-15
author: project review of X-Ways Software Technology AG source
---

# What the SDK source drops themselves reveal

The SDK is more than `X-Tension.h`. The drops ship the vendor's own per-function
status spreadsheets, five C++ sample X-Tensions, the Python bridge source, and
two generations of C# binding — none of which had been reviewed before
2026-08-14. This page records what they say, where they are stale, and which of
their claims conflict with other sources (conflicts →
[xways-sdk-conflicts-test-plan.md](xways-sdk-conflicts-test-plan.md)).

Three artifacts are involved (see [getting-the-sdk.md](getting-the-sdk.md)):
the **2024-05-31 zip**, the newer **git HEAD (c46a1bd2, 2024-07-26)**, and the
**XT_Python binary bundle**. They are not interchangeable — see the divergence
section.

## Contents

- The vendor's own status spreadsheets — and their staleness
- The vendor never exercised three quarters of the API
- Drop divergence — which copy to trust for what
- The `XT_Init` first parameter — three vendor models
- The five C++ samples — what each teaches
- Vendor sample bug catalog — do not port these verbatim
- The C# bindings — facts mined, no authoring support here
- Enumerations captured from sample source
- What was skimmed, not reviewed
- See also

## The vendor's own status spreadsheets — and their staleness

`Function Status.ods` (git HEAD; three sheets: C, Python, C#) and
`Python funcs.ods` (zip) are the vendor's per-function test matrix. The status
vocabulary is **binary**: `tested` (exercised by a sample) or `provided` (the
header declares it; nothing ever calls it). There is no
untested/deprecated/broken marker, and the "Tested by"/"Remarks" columns on the
C sheet are entirely empty.

The whole workbook contains exactly **two remarks, both unresolved German
TODOs** ("Hier auch Großbuchstaben?" about a casing inconsistency; a note to ask
a colleague whether the test images even contain a file that returns useful
data for `GetDataLength`). These are the author's open questions, not
documentation.

**The spreadsheets are stale against the code they describe**, in at least
three places:

- `XT_ProcessSearchHit` is listed as having **no** Python mapping — wrong; the
  bridge exports and forwards it ([xways-python-bridge.md](xways-python-bridge.md)).
- `XWF_GetHashSetAssocs` is listed as not exposed to Python — wrong; it is in
  the method table.
- Method names `xwf.setProgressDescription`, `xwf.GetFileVolume`,
  `xwf.GetWindowNumber` — the code registers `SetProgressDescription`,
  `GetParentVolume`, `GetWindow`.

**Rule: the spreadsheets are leads; the source is the source.** Same lesson as
the community bindings — cross-check the numbers, not the prose.

## The vendor never exercised three quarters of the API

On the C sheet, **24 distinct functions are `tested` and 52 are `provided`** —
i.e. the vendor's own sample suite exercises barely a quarter of the declared
function-pointer set. The `provided` list includes the entire evidence-object
family, the whole search surface, events, containers, `XWF_GetCellText`,
`XWF_GetRasterImage`, `XWF_CreateFile` and every write-side item function.

Two consequences worth internalising:

- "It's in the SDK" is an even weaker claim than "it's on the official page"
  (which already includes not-implemented entries — see the
  [coverage map](xways-api-coverage-map.md)). For most of the API there is no
  vendor sample demonstrating a correct call.
- Where this project's empirical notes cover a `provided` function
  ([xways-snapshot-mutation.md](xways-snapshot-mutation.md),
  [xways-getprop-reference.md](xways-getprop-reference.md),
  [events-viewer-empirical-findings.md](events-viewer-empirical-findings.md)),
  they are documenting territory the vendor's own samples never entered.

The spreadsheet's function list is also **not the full 21.x API** — it is a
snapshot of `X-Tension.h`'s pointer set circa 2024; `XWF_Mount`/`XWF_Unmount`
appear in the resolver (below) but not in the spreadsheet at all.

## Drop divergence — which copy to trust for what

`src/` is byte-identical between the zip and git HEAD **except**
`X-Tension.h`, `Luhn.cpp` (one signature line), `BGBase.h` (cosmetic), and the
C# material (different generations). The one header difference matters:

- The zip's `X-Tension.h` declares `XT_Init` with a commented
  `DWORD/*CallerInfo*/ info` first parameter and a `CallerInfo
  {byte lang, ServiceRelease; WORD version}` struct.
- Git HEAD replaces that with `LicenseInfo* license` as the **fourth**
  parameter (`XT_Init(DWORD nVersion, DWORD nFlags, HANDLE hMainWnd,
  LicenseInfo* license)`) and deletes `CallerInfo` — the 21.5 Beta 4 change
  already recorded in [xways-api-recency-research.md](xways-api-recency-research.md).

**The XT_Python project cannot be built from any shipped drop** —
compile-verified with MSVC 2019 on 2026-08-15, three independent blockers:

1. `Python.cpp` includes **`BGStringTemplates.h`**, which is absent from both
   current drops (it last shipped in the 2021-04-19 drop).
2. `BGCPString.h` includes **`libinstrumentation.h`**, which has never shipped
   in any drop — it is the header of the vendor's private `ins` library (the
   same one the shipped binary links; see
   [xways-python-bridge.md](xways-python-bridge.md)). A no-op stub defining
   `SET_SCOPE`, `RETURN` and the `st*` functions lets compilation proceed.
3. With both headers supplied, git HEAD still fails at `Python.cpp:1302` —
   `error C2065: 'CallerInfo': undeclared identifier` — because the
   `LicenseInfo` change deleted the struct the bridge still uses.

Blockers 1–2 affect the 2024-05-31 zip as well; blocker 3 is git-HEAD-only.
(Both drops' `XT_Python.vcxproj` also carry the original developer's hardcoded
Python 3.7 / 2.7 paths.) The likely story is ordinary: an incomplete export
from an internal tree where the two headers exist.

Practical rule: **build C++ against git HEAD's header; treat the Python project
as reference source only** (the shipped `XT_Python.dll` binary bundle is what
analysts actually run — see [xways-python-bridge.md](xways-python-bridge.md)).

## The `XT_Init` first parameter — three vendor models

The SDK contains three mutually inconsistent treatments of the same argument:

| Where | Model |
| --- | --- |
| Zip `X-Tension.h` | `CallerInfo` struct: `byte lang; byte ServiceRelease; WORD version` (packed into the DWORD) |
| Git-HEAD `X-Tension.h` | bare `DWORD nVersion`, no decode offered |
| C# `XT_Manager.XT_Init` | shift-unpack: `lang = v & 0xFF; SR = (v >> 8) & 0xFF; version = v >> 16` |

The zip's struct layout and the C# arithmetic agree with each other and with
the community decode already documented in
[xtension-invocation.md](xtension-invocation.md) (version word high 16 bits,
SR, language) — three independent sources now, none of them the official page.
**Confirmed live 2026-08-15** on 21.9 Beta 1 (`0x088E0001` → v21.9 SR-0
lang 1) — see [xtension-invocation.md](xtension-invocation.md).

## The five C++ samples — what each teaches

All are single-threaded (`XT_Init` returns `1`); **nothing in the entire SDK —
C++, Python bridge, or C# — returns `2`**. The vendor's samples never
demonstrate the thread-safe mode.

| Sample | What it demonstrates | Worth stealing |
| --- | --- | --- |
| `New.cpp` (98 ln) | Minimal skeleton; all 8 entry points as no-ops. Its `.def` exports **only `XT_Init`**, the others `;`-commented. | The **selective-export idiom**: implement everything, export only what's live. X-Ways drives behaviour off the export table (cf. the 2N double-callback in [xtension-invocation.md](xtension-invocation.md)), so an unexported no-op is safer than an exported one. |
| `XT_Timer.cpp` (167 ln) | Times an RVS run: tick count in `XT_Prepare`, elapsed in `XT_Finalize`. | The shape only — see the bug catalog. |
| `QTest.cpp` (216 ln) | Volume-property dump in `XT_Prepare`; magic-byte sniff + `XWF_AddComment` per item; **runtime capability probing**. | The **NULL-probe pattern**: after resolving pointers, it NULL-checks 13 newer functions (`XWF_GetBlock`, `XWF_SetBlock`, `XWF_GetCaseProp`, the five ev-obj calls, `XWF_GetExtractedMetadata`, `XWF_GetMetadataEx`, `XWF_AddExtractedMetadata`, `XWF_GetHashValue`, `XWF_AddEvent`) — the vendor's own version-compat strategy in lieu of a version check. Its comments also record three real hazards (see gotchas, below). |
| `Luhn.cpp` (218 ln) | **The only search-related sample in the whole SDK**: a passive `XT_ProcessSearchHit` filter that Luhn-validates credit-card hits and suppresses false positives. Never calls `XWF_Search`. | The hit-mutation idioms, now folded into [xways-search-api.md](xways-search-api.md): `iSize` version gate, `nCodePage == 1200` convention, `nLength` rewrite, `nFlags \|= 0x0008` to discard. |
| `X-Tension.cpp` (192 ln) | The loader every sample links: 68 `GetProcAddress` resolutions against `GetModuleHandle(NULL)` (the **host EXE**), wrapped so `XT_RetrieveFunctionPointers()` returns the **count of missing functions** (`> 0` = degraded host). Includes `XWF_Mount`/`XWF_Unmount`, which appear nowhere else in the SDK. | The missing-count return convention. |

**No working `XWF_Search` invocation exists anywhere in the SDK** — not in
C++, not in Python, not in C# (despite one project being named "Search Test",
below). Everything these notes say about *driving* a search rests on the header
typedef, the flag defines, and the official prose alone.

## Vendor sample bug catalog — do not port these verbatim

The samples are teaching aids with real defects. Anyone using them as
copy-paste sources inherits these:

| Sample | Defect |
| --- | --- |
| `QTest.cpp` | The picture-signature check reads `if ((buf[0] = 'B' && buf[1] == 'M') \|\| (buf[0] = 0xff && buf[1] == 0xd8))` — **assignment, not comparison**, in both branches; it comments nearly every 512-byte-readable file as a picture. |
| `QTest.cpp` | Prints `XWF_GetProp(hVolume, 0, nullptr)` with an `" MB"` label without dividing — **confirmed wrong 2026-08-15**: the value is in bytes ([xways-getprop-reference.md](xways-getprop-reference.md)). |
| `Luhn.cpp` | In the `nCodePage == 1200` branch it computes the wide length but **never copies the hit bytes into the buffer** — it validates uninitialised stack memory. The UTF-16 path never worked. |
| `Luhn.cpp` + `QTest.cpp` + `XT_Timer.cpp` + `New.cpp` | `#pragma pack(2)` before the local `SearchHitInfo` **without push/pop** — 2-byte packing stays in force for every struct declared after it in the translation unit. Only `Python.cpp` does `#pragma pack(push/pop)` correctly. Use push/pop in real code. |
| `XT_Timer.cpp` | Deciseconds computed as `delta % 10` (should be `(delta % 1000) / 100`); one raw `wcscat` into a fixed 100-wchar buffer that long locale date strings can overrun. |
| `Sample.py` / `printHashInfo.py` | Each defines `XT_About` **twice** (last definition silently wins); `printHashInfo.py` calls a method that does not exist and has never run to completion ([xways-python-bridge.md](xways-python-bridge.md)). |

QTest's comments also preserve three vendor-authored warnings — see
[build-and-iteration-gotchas.md](build-and-iteration-gotchas.md) for their
current status (two of the three were re-tested 2026-08-15 and no longer
reproduce as stated; the `XWF_OutputMessage` throughput warning stands).

## The C# bindings — facts mined, no authoring support here

Per project decision the skill does not document C# authoring; the C# material
was read for what it reveals about the API. Two incompatible generations exist:

- **Zip drop:** a COM prototype (`XWF_COM.h` — `IXWF_Imports`/`IXWF_Exports`
  IUnknown interfaces) plus a non-compiling pseudocode `XWF_Base.cs` that uses
  C++ types in C#. Notable only because `XWF_COM.h` is the sole place in the
  SDK where `XT_PrepareSearch` appears as a declared signature — and its
  `PrepareSearchInfo` struct is declared but never defined. In `X-Tension.h`
  itself the `PrepareSearchInfo` definition exists **only inside a comment
  block**; it is not a compilable type in either drop.
- **Git HEAD:** a CLR-hosting design. A native shim DLL
  (`XT_CSHARP_CPP.cpp`) starts .NET `v4.0.30319` (hardcoded) and marshals every
  callback to a managed `XT_Manager` **as a space-separated decimal string** —
  the same stringly-typed bridge pattern as Python. The managed binding wraps
  exactly **three** functions: `OutputMessage`, `Read`, `GetProp`.

API-relevant facts mined:

- The managed `GetProp` delegate returns `uint` while `XWF_GetProp` returns
  `INT64` — the vendor's own sample truncates **files over 4 GB**.
- The shim hardcodes `XT_Prepare → 3` (`CALLPI | CALLPILATE`) with the comment
  *"Not sure how to get real return values from the X-Tensions…"* — managed
  return values are not propagated, same limitation as the Python bridge.
- The shim exports `XT_ProcessSearchHit` but its body is `return 0;` — hits
  never reach managed code. Combined with the "C# Search Test" project **never
  calling `XWF_Search`** (it is a hand-rolled byte scanner over
  `XWF_Read` windows, WinForms filter UI, nothing more), the C# tree contains
  zero search-API usage. The project name is a trap.
- The version-word unpack in `XT_Manager` (third model, table above).

## Enumerations captured from sample source

**File-system IDs** (`XWF_GetVolumeInformation` first out-param /
`XWF_GetEvObjProp` 19), from `Sample.py`'s lookup table — the only place the
SDK enumerates them; note **−14 is skipped** in the source:

| ID | File system | ID | File system |
| ---: | --- | ---: | --- |
| 9 | Main memory | −4 | Ext3 |
| 8 | CDFS | −5 | ReiserFS |
| 7 | NetFS | −6 | Reiser4 |
| 6 | xwfS | −7 | Ext4 |
| 5 | UDF | −8 | Linux swap (future) |
| 4 | exFAT | −9 | JFS |
| 3 | FAT32 | −10 | XFS |
| 2 | FAT16 | −11 | UFS |
| 1 | FAT12 | −12 | HFS |
| −1 | NTFS | −13 | HFS+ |
| −2 | HPFS | −15 | NTFS BitLocker |
| −3 | Ext2 | −16 | physical disk |
| | | −17 | EFI system partition |
| | | −18 | MS reserved partition |
| | | −19/−20 | LDM metadata / data |
| | | −21..−23 | Apple misc / map / driver |
| | | −24 | Linux swap |

**Hash-type codes** (`XWF_GetVSProp` `HASHTYPE1/2`), from the bridge's
`getHashName`/`getHashSize`: codes 1–18 with bit lengths — **agrees exactly
with the community table** already in
[xways-getprop-reference.md](xways-getprop-reference.md) (which adds code 19,
MD5-folded, from a v20.9-gated source). Two vendor sources and one community
source now corroborate 1–18; the same v21.5 renumbering caveat applies to all
of them.

## What was skimmed, not reviewed

- `BGBase` / `BGCPString` / `BGException` (~3,300 lines) — the author's
  personal string/exception utility library that the samples link against.
  Generic Win32 utility code; no API semantics. One incidental find: git HEAD's
  `BGBase.h` adds a `LogToXWFID = 30` log-target enum, used by the C# shim's
  message listener.
- Project files (`.vcxproj`/`.sln`) — MSVC 2019 removed at git HEAD; several
  carry stale per-developer paths (noted above where it matters).
- The WinForms designer boilerplate in the C# tree.

## See also

- [xways-python-bridge.md](xways-python-bridge.md) — the bridge's method table,
  entry points, bugs.
- [xways-sdk-conflicts-test-plan.md](xways-sdk-conflicts-test-plan.md) — every
  conflict this review surfaced, with probe designs.
- [xways-api-recency-research.md](xways-api-recency-research.md) — SDK vs live
  page recency; the `LicenseInfo` change.
- [getting-the-sdk.md](getting-the-sdk.md) — how to obtain these drops.
