# Add output back to the case

An X-Tension that produces analyst-facing artifacts — an export tree, a report, a
parsed database, files reconstructed from a log — can register them **back into
the open case** so they appear in the case tree and are searchable / filterable
like any other evidence, with no manual "Add files" step. Two API calls do this,
and they add output at different levels:

- **`XWF_CreateEvObj`** — adds a new **evidence object** to the case from an
  on-disk path (a single file, or a whole directory tree). X-Ways then takes its
  own volume snapshot of it, so the files inside get individually indexed. This is
  the natural fit for output already written to disk under the
  [output directory](output-dir.md) convention.
- **`XWF_CreateFile`** — creates **items inside the existing volume snapshot**, as
  children of a real parent item. This is the fit for a parser that wants its
  extracted artifacts to appear as child items of the source they came from,
  in the same snapshot rather than as a separate object. It is snapshot mutation
  and carries the gotchas documented in
  [snapshot mutation](../xways-snapshot-mutation.md).

!!! warning "`XWF_CreateEvObj` is an OPTIONAL export — null-check it"
    Older X-Ways builds do not export `XWF_CreateEvObj`. Resolve it as an optional
    pointer (do **not** count it as a missing-required-function failure in
    `XT_Init`), and null-check at the call site. When it is absent, log-skip the
    add-back — the output is still on disk. `XWF_CreateFile` is a core export and
    does not need this treatment.

## Which one applies

| | `XWF_CreateEvObj` | `XWF_CreateFile` |
|---|---|---|
| **Adds** | a new top-level evidence object | items in the current snapshot |
| **Input** | an on-disk path (file or folder) | a name + creation flags + parent item ID (+ optional source) |
| **Use when** | the X-Tension wrote finished output to disk and wants the whole tree ingested | a parser wants per-record / per-artifact items nested under their source item |
| **Persistence** | immediate (a new EO) | requires `XT_Finalize` to return `0x02` (see below) |
| **Availability** | optional export — null-check | core export |

## Signatures (header-confirmed)

Both are declared in the canonical `X-Tension.h`; mirror the parameter types exactly:

```cpp
// Create evidence object from an on-disk path.
typedef HANDLE (__stdcall *pfn_XWF_CreateEvObj)(DWORD nType, LONG nDiskID,
    LPWSTR lpPath, PVOID pReserved);

// Create an item inside the current volume snapshot.
typedef long int (__stdcall *pfn_XWF_CreateFile)(LPWSTR pName, DWORD nCreationFlags,
    LONG nParentItemID, PVOID pSourceInfo);

// pSourceInfo payload for the source-bearing creation flags (packed to 2 bytes):
#pragma pack(push, 2)
struct SrcInfo { DWORD nStructSize; INT64 nBufSize; LPVOID pBuffer; };
#pragma pack(pop)
```

## Pattern — new evidence object (`XWF_CreateEvObj`)

Point it at the output the X-Tension already produced (see the
[output directory](output-dir.md) convention for where that lives). `lpPath` is
`LPWSTR` — pass a **mutable** buffer, not a string literal.

```cpp
// nType is a DWORD in the header; the value meanings are per the live API page
// (see external-tool-integration.md), not enumerated in the header.
enum { EVOBJ_FILE = 0, EVOBJ_IMAGE = 1, EVOBJ_MEMDUMP = 2, EVOBJ_DIRECTORY = 3, EVOBJ_PHYSDISK = 4 };

if (!XWF_CreateEvObj) {                 // optional export — resolved but may be null
    Log(L"add-back requested but XWF_CreateEvObj unavailable — output left on disk");
    return;
}

std::wstring path = outputDir;          // mutable buffer for the LPWSTR param
HANDLE h = XWF_CreateEvObj(EVOBJ_DIRECTORY, /*nDiskID=*/0, path.data(), /*pReserved=*/nullptr);

// NULL / INVALID_HANDLE_VALUE means "did not add" — commonly because the object is
// already in the case. Log it; do not treat it as a hard error.
Log((h && h != INVALID_HANDLE_VALUE) ? L"added output as evidence object"
                                     : L"not added (already in case?)");
```

`nType` values (a `DWORD` in the header; meanings from the live official API page):

| nType | Meaning | Typical use |
|---|---|---|
| 0 | file | a single output file (e.g. a report or a zip) |
| 1 | image | a disk / forensic image |
| 2 | memory dump | a memory artifact |
| 3 | directory | an exported **folder tree** — the usual choice for tool output |
| 4 | physical disk | — |

`nDiskID` is `0` for file/directory adds; `pReserved` is `nullptr` (recent builds
accept directory-timestamp flags there — see the live API page).

!!! danger "Zip trap: `tar … .` prefixes every entry with `./` and X-Ways mis-nests it"
    If you zip the output first and add the archive as an `nType = 0` file, do **not**
    build it with `tar -a -cf out.zip -C dir .` — the trailing `.` makes every entry
    `./sub/x.txt`, and X-Ways' zip reader collapses the files to the archive **root**
    and shows the folders as empty `(0)`. Name the top-level entries **explicitly** so
    entries are `sub/…` with no `./` prefix:

    ```text
    tar -a -c -f out.zip -C dir "sub1" "sub2" "sub3"     (NOT ".")
    ```

    `tar.exe` (bsdtar) ships with Windows 10 1803+; it is a runtime tool, not a bundled
    library. Adding the folder directly with `nType = 3` avoids the trap entirely.

## Pattern — items in the existing snapshot (`XWF_CreateFile`)

`XWF_CreateFile` appends an item to the current volume snapshot and returns its new
item ID (a sequential append equal to the prior item count), or `-1` on rejection.
`nCreationFlags` selects where the item's content comes from; the empirically-mapped
flag space is documented in [snapshot mutation](../xways-snapshot-mutation.md):

| flag | mnemonic | content source |
|---|---|---|
| `0x00` | (none) | metadata-only item (no bytes) |
| `0x01` | MoreItemsToBeCreated | hint that more items follow (combine with a content flag) |
| `0x02` | ExcerptFromParent | a byte range of the parent — needs a real offset/size source |
| `0x04` | AttachExternalFile | an on-disk file pulled into the snapshot — needs a path source |
| `0x08` | KeepExternalFile | keep an external file reference |
| `0x10` | FileContentsFromBuffer | in-memory bytes supplied via `SrcInfo` |

The header types `nCreationFlags` as a plain `DWORD`; the value meanings above are
from the live API page and the empirical map — do not infer new flags.

```cpp
// Content-from-buffer (0x10): give the new item bytes you hold in memory.
// nParentItemID MUST be a real item ID — pass the source item's ID, never -1.
SrcInfo si{ (DWORD)sizeof(SrcInfo), (INT64)bytes.size(), bytes.data() };

std::wstring name = L"parsed_record_001";       // mutable buffer for the LPWSTR param
LONG newId = XWF_CreateFile(name.data(), /*nCreationFlags=*/0x10,
                            /*nParentItemID=*/parentItemID, &si);
if (newId < 0) { Log(L"XWF_CreateFile rejected the item"); return; }
// newId is now a first-class snapshot item: XWF_AddEvent, XWF_SetItemParent,
// XWF_AddComment, XWF_Label all work on it.
```

!!! danger "Snapshot mutation: on X-Ways' thread, real parent, and only persisted if `XT_Finalize` returns `0x02`"
    - **Parent must be a real item ID.** `nParentItemID = -1` **access-violates** —
      never pass `-1` for "root"; pass a real source item's ID.
    - **Source-bearing flags need a source.** `0x02` and `0x04` **access-violate**
      when `pSourceInfo` is `NULL`. Supply a valid `SrcInfo` (buffer for `0x10`;
      offset/size for `0x02`; path for `0x04`) or use `0x00`/`0x10`.
    - **Persist with `0x02`.** Created items are only saved if `XT_Finalize` returns
      `0x02` (the save-snapshot bit). Without it, the items vanish on close.
    - **Bail on a read-only snapshot.** Test `nOpType & 0x100` in `XT_Prepare` and
      return `-1` to skip the volume when set — otherwise every `XWF_CreateFile`
      returns `-1` and the run burns through every item (see
      [snapshot mutation](../xways-snapshot-mutation.md)).
    - **Reset per-run state each `XT_Prepare`.** A multi-volume image fires
      `XT_Prepare` once per volume in a single invocation; a stale item-ID global
      from an earlier volume will target the wrong snapshot.
    - **Run on X-Ways' thread.** Both calls mutate case state — do them in
      `XT_Prepare`, `XT_ProcessItemEx`, or `XT_Finalize`, never from a worker thread
      you spawned (see [threading model](threading-model.md)).

!!! note "Related: evidence file containers"
    To collect items (or byte ranges) into a **portable `.ctr` container** rather
    than adding them to the live case, the header also declares
    `XWF_CreateContainer(LPWSTR lpFileName, DWORD nFlags, LPVOID pReserved)`,
    `XWF_CopyToContainer(HANDLE hContainer, HANDLE hItem, DWORD nFlags, DWORD nMode, INT64 nStartOfs, INT64 nEndOfs, LPVOID pReserved)`,
    and `XWF_CloseContainer(HANDLE hContainer, LPVOID pReserved)`. The resulting
    container is itself added to a case as an evidence object. See the live API page
    for the `nFlags` / `nMode` meanings.

## Do / Don't

- **Do** resolve `XWF_CreateEvObj` as an optional pointer and null-check before
  calling — the export stays on disk when it is unavailable.
- **Do** pass a **mutable** `wchar_t*` (`path.data()` / `&path[0]`) for the `LPWSTR`
  path and name parameters — they are not `const`.
- **Do** prefer `nType = 3` (directory) to ingest a whole output tree; it sidesteps
  the zip-nesting trap.
- **Do** offer add-back as an explicit dialog/cfg choice, and treat a `NULL` /
  `-1` return as "did not add" (log it), not as a hard error — for an EO it usually
  means the object is already in the case.
- **Do** pass a real `nParentItemID` to `XWF_CreateFile`, supply a `SrcInfo` for
  the source-bearing flags, and return `0x02` from `XT_Finalize` to persist.
- **Don't** call either function from a worker thread you spawned — snapshot
  mutation belongs on X-Ways' thread.
- **Don't** pass `-1` as the parent item ID, and don't call the source-bearing
  flags (`0x02` / `0x04`) with `pSourceInfo = NULL` — both access-violate.
- **Don't** add back an **unbounded** export — bound the set first (see
  [wrapper anatomy](wrapper-anatomy.md)) or you register a multi-GB/TB object.

## See also

- [Output directory](output-dir.md) — where the output being added back lives.
- [Output writers](output-writers.md) — bounding and validating the files before add-back.
- [Snapshot mutation](../xways-snapshot-mutation.md) — empirical `XWF_CreateFile` flag space, parent/read-only/persistence gotchas.
- [Evidence-object source resolution](../xways-evobj-source-resolution.md) — the inverse: recovering an EO's on-disk source.
- [Threading model](threading-model.md) — why these calls must run on X-Ways' thread.
- [Item collection](item-collection.md) — collecting the source items you nest new items under.
- [External-tool integration](../external-tool-integration.md) — the `nType` table in context.
- Live API reference: <https://www.x-ways.net/forensics/x-tensions/XWF_functions.html>
