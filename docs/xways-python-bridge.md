---
source: the SDK's Python bridge source (`Python.cpp`, git HEAD c46a1bd2, byte-identical in the 2024-05-31 zip) + the shipped XT_Python bundle readme + sample scripts — see getting-the-sdk.md; read in full 2026-08-14
type: official-doc
fetched: 2026-08-14
last_updated: 2026-08-16
author: X-Ways Software Technology AG (source); project distillation
---

# The Python bridge — what the `xwf` module actually is

`XT_Python.dll` embeds CPython inside X-Ways and exposes a module named **`xwf`**
to your script. Every prior claim in these notes about what the bridge does or
does not expose was sourced (or mis-sourced) second-hand; this page is distilled
from reading the bridge's own source — the SDK's `Python.cpp` (see
[getting-the-sdk.md](getting-the-sdk.md)) — in full. The method table
(`XT_Methods[]`) is the single authoritative inventory; the SDK's own
spreadsheets and readme are both stale against it (see
[xways-sdk-source-notes.md](xways-sdk-source-notes.md)).

Rules of thumb this page justifies:

- The module is **`xwf`, lowercase**. The bundle readme's `import XWF` is wrong
  and fails.
- The bridge exposes **46 methods**. Everything else in the C API — events,
  search, containers, evidence objects, case properties, user input, cell text —
  is **absent**, which is why those X-Tensions must be C++.
- A Python X-Tension is **never multi-threaded** — the bridge hard-returns `1`
  from `XT_Init` with the vendor's own comment: *"not thread-safe, since the
  global state is stored in a few global variables"*. There is no GIL
  management. Never design a Python X-Tension around `XT_ProcessItem(Ex)`
  concurrency.

## Contents

- How dispatch works — generated source, ASCII-only
- Deployment and configuration
- The 46 methods, by group
- Entry points forwarded to your script
- Bridge bugs and limits — verified in source
- Readme errata
- See also

## How dispatch works — generated source, ASCII-only

The bridge does not call your functions through the C API. Every callback is
delivered by **building a line of Python source and executing it** with
`PyRun_StringFlags` against a shared `__main__` dict. `XT_ProcessItem(1234, 0)`
arrives in your script because the bridge ran the string
`yourmodule.XT_ProcessItem(1234, 0)`.

Consequences that matter in practice:

- **Handles and pointers arrive as plain `int`** — decimal literals in the
  generated source. `hVolume`, `hItem`, `hMainWnd` are integers you pass back
  into `xwf.*` calls unchanged.
- **The command string is converted to ASCII** before execution
  (`cmdAscii.convertToCP(CP_ASCII)` in `callScripts`). Non-ASCII content cannot
  survive the call boundary — which is also why search-hit text reaches
  `XT_ProcessSearchHit` mangled (see the bugs table).
- **Every configured script receives every callback.** `Python.cfg` holds a
  list of script paths; the bridge iterates all of them for each entry point.
  Two scripts loaded together both see every item.
- Script errors are caught (`PyErr_Fetch`) and reported to the Messages window
  as `Failed to execute <cmd><error>` — the run continues.
- Before importing each script the bridge `SetCurrentDirectory`s into the
  script's folder, so relative paths in your script resolve against the script
  location at import time.

## Deployment and configuration

- `XT_Python.dll` + the matching `pythonXYZ.dll` go in the **X-Ways main
  folder** (next to the EXE), per the bundle readme — not in an `xtensions\`
  subfolder. A matching system-wide Python install is required.
- The script list lives in **`Python.cfg` next to the X-Ways EXE**. It is
  written by the bridge's `XT_About` — the "About" gesture on `XT_Python.dll`
  *is* the script picker (a multi-select `.py` file dialog). That is what the
  readme's cryptic "click …" instruction refers to. Format: UTF-16LE,
  NUL-separated full paths, double-NUL terminated, **no BOM** (the bridge
  reads the file raw into a `wchar_t` buffer).
- **Your `.py` must sit in the X-Ways main folder, not a subfolder** (verified
  2026-08-16, Python 3.12). The bridge does **not** touch `sys.path`: it only
  `SetCurrentDirectory`s into the script's directory and runs
  `import <module>` (source comment: "Import module must be in the same
  directory as XT_Python"). On Python 3.12 the current directory is not
  importable, so a script listed in `Python.cfg` from any other folder fails
  at `import` — the Messages window shows `Failed to execute import <name>`
  for **every** entry point. Placing it in the main folder (where
  `python312.dll` anchors the interpreter's path) is what makes `import`
  resolve. This is the load-bearing meaning behind the readme's "all files in
  the XWF main folder".
- **Which Python version? Settled 2026-08-14 by the binary itself:** the
  shipped `XT_Python.dll`'s PE import table links **`python312.dll`**. The
  bundle readme's "requires Python 3.10" and the source drops' "3.11" are both
  wrong for this binary; the DLL filename in the bundle was the truth-teller.
  Check the import table (or the shipped `pythonXYZ.dll`) for any future
  bundle, not the readme.
- **Undocumented dependency: `ins.dll`.** The shipped DLL has a *load-time*
  import of `ins.dll` — three symbols (`stEnterScope`, `stSetOp`, `stReturn`)
  from the author's private instrumentation library, i.e. the vendor shipped an
  instrumented build. The bundle does not contain `ins.dll`; **X-Ways itself
  ships it** in the install root, and Windows always searches the EXE's
  directory, so inside X-Ways it resolves invisibly. Outside X-Ways the DLL
  fails to load with `ERROR_MOD_NOT_FOUND` (126) — verified 2026-08-14. This
  is the real teeth behind the readme's "extract into the XWF main folder"
  instruction, and it means any out-of-process harness for the bridge must put
  a real or stub `ins.dll` beside the host EXE.
- **The binary's export table matches the source exactly** (verified
  2026-08-14): the 8 entry points including `XT_ProcessSearchHit`, and no
  `XT_PrepareSearch` — independent, binary-level confirmation of the
  spreadsheet correction above.

## The 46 methods, by group

`XT_Methods[]` in the SDK's `Python.cpp`. Names are exact — including the
casing. Many "functions" are convenience splits of a single C call, so the
46-name surface maps to only ~27 `XWF_*` functions.

### Straight wrappers

| Python | C API | Notes |
| --- | --- | --- |
| `xwf.OutputMessage(msg, flags)` | `XWF_OutputMessage` | **Both args mandatory** (no default flags). Prepends `"<script>: "` to every message — don't add your own script-name prefix. Silently drops messages that are only a line break. |
| `xwf.Read(hVolumeOrItem, offset, byteCount)` | `XWF_Read` | The docstring says "sector"; the parameter is a **byte offset**. Returns a `bytearray`. **Short reads are invisible** — see bugs. |
| `xwf.GetItemCount(hVolume)` | `XWF_GetItemCount` | |
| `xwf.GetItemSize(itemID)` | `XWF_GetItemSize` | |
| `xwf.GetItemName(itemID)` | `XWF_GetItemName` | |
| `xwf.GetItemParent(itemID)` | `XWF_GetItemParent` | |
| `xwf.GetItemInformation(itemID, infoType)` | `XWF_GetItemInformation` | Returns a **2-tuple `(value, success)`** — the only wrapper that surfaces the success flag. |
| `xwf.GetComment(itemID)` / `xwf.AddComment(itemID, comment, howToAdd)` | `XWF_GetComment` / `XWF_AddComment` | `howToAdd` optional, default = replace; passed straight through to the C API. |
| `xwf.GetReportTableAssocs(itemID)` | `XWF_GetReportTableAssocs` | Comma-separated string. Fixed 2048-wchar buffer — see bugs. The bridge predates the rename to `XWF_GetLabels`; the old export still resolves on current hosts. |
| `xwf.AddToReportTable(itemID, name, flags)` | `XWF_AddToReportTable` | `flags` optional. Pre-rename name for `XWF_Label` — same note as above. |
| `xwf.GetHashSetAssocs(itemID)` | `XWF_GetHashSetAssocs` | Capped ~1600 wchars + leaks — see bugs. |
| `xwf.GetHashValue(itemID, hashType)` | `XWF_GetHashValue` | `hashType`: 1, 2 (primary/secondary) or 256–259 (PhotoDNA 1–4). Returns lowercase hex string or `None`. **Broken for hashes wider than 128 bits** — see bugs. |
| `xwf.GetExtractedMetadata(itemID)` | `XWF_GetExtractedMetadata` | |
| `xwf.GetVolumeName(hVolume, nameType)` | `XWF_GetVolumeName` | 256-wchar buffer. |
| `xwf.CreateItem(name, flags)` | `XWF_CreateItem` | Snapshot mutation from Python is real — the SDK's `TarAlyze.py` sample creates items for members of tar archives. |
| `xwf.SetItemSize` / `xwf.SetItemParent` / `xwf.SetItemOfs(id, offset, startSector)` | `XWF_SetItemSize` / `XWF_SetItemParent` / `XWF_SetItemOfs` | Companions to `CreateItem`. |
| `xwf.ShowProgress(caption, flags)` / `xwf.SetProgressPercentage(pct)` / `xwf.SetProgressDescription(text)` / `xwf.HideProgress()` | progress API | `SetProgressPercentage` and `HideProgress` also pump one window message. Same rule as C++: never from a per-item callback ([xways-user-input-and-dialogs.md](xways-user-input-and-dialogs.md)). |

### Convenience splits (one C call, several Python names)

| Python names | Underlying call |
| --- | --- |
| `GetVolumeFileSystem`, `GetVolumeBytesPerSector`, `GetVolumeSectorsPerCluster`, `GetVolumeClusterCount`, `GetVolumeFirstClusterSectorNo` (each `(hVolume)`) | `XWF_GetVolumeInformation`, one out-parameter each |
| `GetSectorContentsString(hVolume, sector)` and `GetItemIDForSector(hVolume, sector)` | `XWF_GetSectorContents` — description vs. owning-item halves |
| `GetFileSystemInfoOffset(itemID)` and `GetItemFirstDataSector(itemID)` | `XWF_GetItemOfs` — the two out-parameters |
| `GetBlockStart(h)` and `GetBlockEnd(h)` | `XWF_GetBlock` — returns 0 on failure **and** for a block at offset 0 (see bugs) |
| `GetPhysicalSize` (0), `GetLogicalSize` (1), `GetDataLength` (2), `GetFileAttributes` (4), `GetFilePath` (8), `GetPureName` (9), `GetParentVolume` (10), `GetWindow` (16) | `XWF_GetProp` with the property number in parentheses — the same numbers documented in [xways-evobj-source-resolution.md](xways-evobj-source-resolution.md) |

### Bridge-only methods (no `XWF_*` counterpart)

| Python | What it is |
| --- | --- |
| `xwf.ProcessMessages()` | One `PeekMessage`/`Dispatch` pump iteration — keeps the GUI responsive during long Python loops. The SDK samples call it once per created item / per progress tick. |
| `xwf.GetOpenFileName()` / `xwf.GetSaveFileName()` | Native comdlg32 file dialogs. **No arguments** — hardcoded title, no filter, no `hMainWnd` parenting (the dialog can appear behind X-Ways), `MAX_PATH` buffer. Still usually better than shipping tkinter. |
| `xwf.AllocConsole()` | Opens a Win32 console and rebinds `stdout` — the standard Python-side debugging move (pairs with the bundle's `OutputRedirector.py`). Prints a stray "Hello console" on open. |

Run `help(xwf)` from a script (the SDK's `Sample.py` does) to enumerate the live
table on whatever bridge build you actually have — the fastest way to check a
name on a newer DLL.

## Entry points forwarded to your script

The bridge implements and exports **eight** entry points, each forwarded as a
module-level function call in your script:

`XT_Init(nVersion, nFlags, hMainWnd, lpReserved)`, `XT_Done`, `XT_About`,
`XT_Prepare(hVolume, hEvidence, nOpType, lpReserved)`, `XT_Finalize`,
`XT_ProcessItem(nItemID, lpReserved)`, `XT_ProcessItemEx(nItemID, hItem,
lpReserved)`, and `XT_ProcessSearchHit`.

- **`XT_ProcessSearchHit` IS available from Python** — the SDK's own
  `Python funcs.ods` spreadsheet says otherwise and is wrong; the export and the
  forward are both in the source. The struct arrives **flattened into 9
  positional args**: `(iSize, nItemID, nRelOfs, nAbsOfs, hitText,
  searchTermID, nLength, nCodePage, nFlags)`. Because it is a copy, **Python
  cannot mutate the hit** — no discarding via `nFlags |= 0x0008`, no length
  rewriting. Hit-*filtering* X-Tensions (the `Luhn.cpp` pattern in
  [xways-search-api.md](xways-search-api.md)) must be C++.
- The bridge's own return values are fixed: `XT_Init` → `1` (single-threaded,
  see above), `XT_Prepare` → `1` (always requests per-item calls — your
  script's return value is **not** propagated), everything else → `0`. A Python
  X-Tension cannot return `XT_PREPARE_*` flag combinations, cannot exclude a
  volume, cannot stop the operation from a return code.

**Not bridged at all:** `XT_PrepareSearch`, `XT_View`, `XT_ReleaseMem`, and the
Disk I/O class (`XT_SectorIOInit` / `XT_SectorIO` / `XT_FileIO` /
`XT_SectorIODone`). Viewer and Disk-I/O X-Tensions are C/C++ only.

The bundle readme says every script "should contain" `XT_Init, XT_Done,
XT_About, XT_Prepare, XT_Finalize, XT_ProcessSearchHit` even if empty. The rule
is soft — a missing function produces a caught, logged error per callback, and
the SDK's own `props.py` ships without `XT_ProcessSearchHit` — but define them
anyway to keep the Messages window clean.

## Bridge bugs and limits — verified in source

Read this table before relying on any of these calls. Line references are to
the SDK's `Python.cpp` at git HEAD c46a1bd2.

| Call | Defect | Practical guidance |
| --- | --- | --- |
| `GetHashValue` | **Stack buffer overflow** (source-verified 2026-08-15, `Python.cpp:1157-1165`). `hashStr` is `wchar_t[33]`, commented "256/8=32, plus zero-terminator" — but 256 **bits** = 32 **bytes** = 64 **hex chars**, so the buffer was sized as if bytes were chars. The loop writes 2 chars per hash byte at `hashStr[2i]`/`[2i+1]`, reaching index 63 for SHA-256 (a 62-byte overflow), and `PyUnicode_FromWideChar(hashStr, hashBits/4)` then reads 64 wchars back. **Any hash type wider than 128 bits overflows** (SHA-1/160 by 7 chars, SHA-256/256 by 31); MD5/MD4/RIPEMD-128 are exactly safe. | Do not call on snapshots whose hash type is wider than 128 bits. If you need SHA-1/SHA-256 from Python, `xwf.Read` the file and hash it with `hashlib` instead. |
| `GetHashValue` (again) | The size/name lookup always queries `XWF_VSPROP_HASHTYPE1`, even for `hashType=2` — a differing secondary hash type gets the wrong length. | Treat `hashType=2` as unreliable whenever the two hash types differ. |
| `Read` | The return value of `XWF_Read` is discarded; the bytearray is returned at the requested size regardless. **A short read hands you trailing garbage with no signal.** | Compare against `GetItemSize`/`GetLogicalSize` and treat the tail as suspect near end-of-file. |
| `GetReportTableAssocs` | Fixed 2048-wchar buffer; the association count returned by the C call is discarded; overflow truncates silently. | Fine for normal label counts; do not build completeness-critical logic on it. |
| `GetHashSetAssocs` | Grow-and-retry buffer capped at ~1600 wchars, and the buffer is **never freed — leaks on every call**. | Avoid per-item calls in large loops; expect truncation on hash-set-heavy items. |
| `GetBlockStart` / `GetBlockEnd` | Failure returns `0` — indistinguishable from a real block boundary at offset 0. | Treat `(0, 0)` as "no block", accept the edge-case ambiguity. |
| `XT_ProcessSearchHit` hit text | The copy loop reads the hit as `signed char` and stops at the first byte `< 32` **or ≥ 0x80**, and strips apostrophes (they would break the generated source line — an injection guard). UTF-16 hit text dies at its first NUL byte. | Use the offsets/length/code page args and re-read the data with `xwf.Read`; never trust the delivered hit string. |
| `OutputMessage` | Requires both arguments; drops line-break-only messages; prepends `"<script>: "`. | Pass `flags=0` explicitly; skip custom script-name prefixes ([verbose-logging](conventions/verbose-logging.md)). |

None of these are fixable from script code — they are properties of the shipped
DLL. Empirical confirmation items for the overflow and the version floor are
tracked in [xways-sdk-conflicts-test-plan.md](xways-sdk-conflicts-test-plan.md).

## Readme errata

The bundle `readme.txt` is the only official Python documentation and it is
wrong in several places. Corrections, verified against the source and samples:

- `import XWF` → **`import xwf`** (the module registers lowercase).
- `fake-xwf.py` → the shipped file is **`fake_xwf.py`** (and it stubs only 5 of
  the 46 methods — extend it before using it as an offline test double).
- `GetSectorContentsString` / `GetItemIDForSector` are documented with a 3-arg
  split-64-bit sector signature; the real signature is **2 args** with a single
  64-bit sector.
- `Read(hVolume, sector, byteCount)` — the middle parameter is a **byte
  offset**.
- `GetItemInformation` is described as "returns the sector where file data
  starts" — copy-paste error; it returns `(value, success)`.
- `SetProgressDescription(percent)` — the parameter is a string.
- The `GetVolumeClusterCount` and `GetVolumeFirstClusterSectorNo` descriptions
  are copy-paste duplicates of the sectors-per-cluster line.
- The ten `XWF_GetProp`/`XWF_GetBlock` convenience getters are missing from the
  readme that ships with the binary bundle (they appear only in the newer git
  drop's copy).
- The shipped sample `printHashInfo.py` calls `xwf.GetHashTableAssocs`, which
  **does not exist** (real name: `GetHashSetAssocs`) — the sample dies with
  `AttributeError` on its first item. Don't debug your environment when it
  fails; it never worked.

## See also

- [xways-sdk-source-notes.md](xways-sdk-source-notes.md) — the SDK drops
  themselves: vendor status spreadsheets, sample bug catalog, drop divergence.
- [xways-sdk-conflicts-test-plan.md](xways-sdk-conflicts-test-plan.md) — open
  conflicts needing empirical resolution.
- [xways-events-api.md](xways-events-api.md) — why Events API X-Tensions are
  C++ (`AddEvent`/`GetEvent` absent from the table above).
- [xways-user-input-and-dialogs.md](xways-user-input-and-dialogs.md) —
  prompting; the bridge's `GetOpenFileName`/`GetSaveFileName` vs tkinter.
- The Python template: `templates/x-tensions/python/`.
