---
source: https://www.x-ways.net/forensics/x-tensions/XWF_functions.html (official) + the X-Ways SDK header (see getting-the-sdk.md) + project empirical
type: official-doc + empirical-finding
fetched: 2026-04-27
last_updated: 2026-04-27
author: X-Ways Software Technology AG; project synthesis from xways-events-api.md and xtension-invocation.md
---

# Reading the Events viewer and Directory Browser as analyzer input

How to consume the data already present in an X-Ways case from inside an X-Tension — events from the Events viewer, items from the Directory Browser, and the file content behind those items — and run analysis logic over it. The natural counterpart to [xways-user-input-and-dialogs.md](xways-user-input-and-dialogs.md) (how to ask the analyst what to look for) and to [xways-events-api.md](xways-events-api.md) (the API reference for `XWF_AddEvent`/`XWF_GetEvent` themselves).

The short answer: **yes, both surfaces are readable from C++**, via stable APIs in the SDK header. The Events viewer enumerates through `XWF_GetEvent`; the Directory Browser is read via the per-item APIs (`XWF_GetItemCount`, `XWF_GetItemName`, `XWF_GetItemSize`, etc.) plus `XWF_OpenItem` + `XWF_Read` for file content. There is no API to read the live grid's column state, filters, or selection-as-rendered — you read from the underlying snapshot, which is the source of truth.

## Reading existing events (`XWF_GetEvent`)

Available since **v18.1**. Full reference in [xways-events-api.md](xways-events-api.md); the analyzer-specific shape:

```c
DWORD XWF_GetEvent(DWORD nEventNo, struct EventInfo* pEvt);
```

### Pre-flight: get the total count

Set `iSize = sizeof(LONG) + sizeof(HANDLE)` so the struct appears to cover only the size + evidence-handle fields. The function then ignores `nEventNo` and returns the total event count for that evidence object. Empirically, this also works **even when the evidence is closed** — useful for pre/post-flight bracketing or rapid-survey logic. (The official docs note that retrieving an actual event "is loaded and accessible only if the evidence object is open" — the count trick sidesteps this because no event payload is being fetched.)

```cpp
EventInfo probe = {};
probe.iSize = sizeof(LONG) + sizeof(HANDLE);
probe.hEvidence = hEvidence;
DWORD total = XWF_GetEvent(0, &probe);  // returns total count
```

### Iterate events as an analyzer

```cpp
for (DWORD i = 0; i < total; ++i) {
    EventInfo evt = {};
    evt.iSize = sizeof(EventInfo);
    evt.hEvidence = hEvidence;

    char descBuf[256] = {0};
    evt.lpDescr = descBuf;  // 256-byte buffer (255 + NUL); description is UTF-8/ANSI

    DWORD rv = XWF_GetEvent(i, &evt);
    if (rv == MAXDWORD) continue;  // failure on this index — skip

    // analyze: evt.nEvtType (category/type), evt.TimeStamp, evt.nItemID,
    // evt.nOfs, evt.nFlags (0x01 = internally-deleted), descBuf
}
```

Failure returns `MAXDWORD`. Success returns the byte length of the description copied (0 means success with no description).

### What you get per event

| Field | Use in an analyzer |
| --- | --- |
| `nEvtType` | Category bucket + Type label — see the lookup tables in [xways-events-api.md:60-209](xways-events-api.md#L60-L209). Filter on a numeric range to isolate "Event log" / "Internet" / "File system" subsets without parsing strings. |
| `TimeStamp` | UTC FILETIME unless `nFlags & 0x20` is set (then local time). Convert before comparing. |
| `nItemID` | The X-Tension item ID of the source artefact — `Int. ID` in the directory browser, **not** plain `ID`. `-1` means no linked item. Use it with `XWF_OpenItem` / `XWF_Read` / `XWF_GetItemInformation` to pull more context. |
| `nOfs` | Byte offset where the timestamp was found, or `-1`. Cosmetic in the UI; useful as a fingerprint for de-duplication. |
| `lpDescr` | UTF-8 description. **Truncated to 254 bytes** in the viewer, but `XWF_GetEvent` reads what was actually stored (which is also bounded). |
| `nFlags` | Read-side bit `0x01` indicates "internally deleted already" — usually skip these in analyzer logic. |

### Enrichment-via-emit pattern

The SDK has **no in-place modification primitive** for events — see [xways-events-api.md:306-314](xways-events-api.md#L306-L314). To add information to an existing event, the workflow is:

1. Enumerate with `XWF_GetEvent`.
2. For events matching your rule (e.g. EventID 4624 at a specific `nItemID`), compute an enrichment string (read item content, parse external data, ...).
3. Call `XWF_AddEvent` with a **new** event anchored to the same `(hEvidence, nItemID, nOfs, TimeStamp)` and the enriched description. This adds a sibling row.

For de-duplication on re-runs, embed a signature in your `lpDescr` (e.g., a leading `[xtA]` marker) and skip events whose description starts with that marker on enumeration.

### Caveats

- **Evidence must be open** to retrieve an actual event (the count trick aside). If the evidence is closed, calls return `MAXDWORD`.
- `XWF_GetEvent` is **not exposed in `XT_Python.dll`'s `xwf` module** — C++ only. See [xways-events-api.md:316-318](xways-events-api.md#L316-L318).
- **Threading is undocumented.** Single-thread the enumeration in `XT_Prepare` to side-step the question; this matches the recommended default for `XWF_AddEvent` (see [threading-model.md](conventions/threading-model.md)).

## Reading the Directory Browser (volume snapshot items)

The directory browser is the rendered view of the **volume snapshot** — the list of files, directories, deleted entries, embedded objects, and metadata items X-Ways has discovered. Item APIs read from that snapshot directly. Header declarations in the X-Ways SDK header (see [getting-the-sdk.md](getting-the-sdk.md)).

### Item-enumeration APIs

| API | Returns |
| --- | --- |
| `XWF_GetItemCount(NULL)` | Total number of items in the current snapshot. |
| `XWF_GetItemName(nItemID)` | UTF-16 wide name (filename only, not path). |
| `XWF_GetItemSize(nItemID)` | Logical size in bytes. |
| `XWF_GetItemOfs(nItemID, &defOfs, &startSector)` | File-system offset and starting sector. |
| `XWF_GetItemParent(nItemID)` | Parent item ID, or `-1` for root. Walk recursively to build the full path. |
| `XWF_GetItemType(nItemID, buf, len)` | Type designation string + numeric type-status. |
| `XWF_GetItemInformation(nItemID, nInfoType, &success)` | Attributes, deletion status, hash status, timestamps, flags. `nInfoType` is an enum — see the SDK header. |
| `XWF_GetHashSetAssocs` / `XWF_GetReportTableAssocs` / `XWF_GetComment` | Hash-set membership, Labels (Report Tables), free-text Comments. **`XWF_GetReportTableAssocs` was renamed `XWF_GetLabels`** (backported to the 21.4–21.7 SRs; old name still callable, deprecated) — see the label-API note below. |
| `XWF_GetProp(hVolumeOrItem, nPropType, buf)` | Generic property accessor — see [xways-getprop-reference.md](xways-getprop-reference.md) for the property numbers. |
| `XWF_GetCellText(nItemID, ..., nColIndex, buf, len)` | Reads the **rendered cell text** for a given column — i.e., the exact string the directory browser is displaying for that column on that item. Useful when you want to consume what the analyst sees rather than reconstructing it. **`nFlags` low bits (0x00..0x80) appear to be inert** — empirical testing (observed 2026-05-03) shows the Size column emits identical text for every flag value 0x00..0x80 across 5 sample items. If flags can change notation (decimal vs hex sizes, ISO vs locale dates), the relevant bits are higher than 0x80 — not yet tested. Pass `nFlags=0` for predictable output. |

**Empirical column count:** the directory browser exposes **62 columns** (indices 0..61) on X-Ways 21.7. Past 61, `XWF_GetColumnTitle` returns `FALSE` but **leaks string-table garbage** in the buffer — see [build-and-iteration-gotchas.md](build-and-iteration-gotchas.md). Trust only `rv=1` rows when iterating columns.

### Label / Report-Table API renames (backported to 21.4–21.7 SRs) + remove-label (v21.8)

Both Report-Table functions were renamed; the old names remain callable but are **deprecated**. Per the live [XWF_functions.html](https://www.x-ways.net/forensics/x-tensions/XWF_functions.html) (re-checked 2026-07-03), the renames shipped in **v21.4 SR-11, v21.5 SR-13, v21.6 SR-8, and v21.7 SR-4** (backported across branches):

| Old name (deprecated) | New name | Role |
| --- | --- | --- |
| `XWF_AddToReportTable` | `XWF_Label` | Apply a label to an item. **In v21.8, `XWF_Label` can also *remove* a label** (`nFlags` `0x80000000`). |
| `XWF_GetReportTableAssocs` | `XWF_GetLabels` | Read / count an item's labels. |

The mapping is by **role** (action vs getter), not by the changelog's listing order. Verified against the SDK header signatures (old names) and the live official page. The related `XWF_OpenItem` `0x8000` "embed EML child objects" flag (v21.8+) is documented in [xways-openitem-flags.md](xways-openitem-flags.md).

### Reading file content

For the bytes of a file:

```cpp
HANDLE hItem = XWF_OpenItem(hVolume, nItemID, 0x01);  // open for reading
if (hItem) {
    INT64 size = XWF_GetSize(hItem, nullptr);  // or XWF_GetProp
    std::vector<BYTE> buf(static_cast<size_t>(size));
    DWORD got = XWF_Read(hItem, 0, buf.data(), static_cast<DWORD>(size));
    XWF_Close(hItem);
    // analyze buf[0..got]
}
```

Open flags and the full set of `XWF_OpenItem` modes are in the X-Ways SDK header (see [getting-the-sdk.md](getting-the-sdk.md)). For text content of supported types, `XWF_PrepareTextAccess` + `XWF_GetText` route through X-Ways' viewer component / OCR pipeline.

### Iterating the whole snapshot vs. just a selection

Two invocation modes give you item iteration ([xtension-invocation.md:64-89](xtension-invocation.md#L64-L89)):

| Mode | What you get |
| --- | --- |
| `XT_ACTION_RVS` (Refine Volume Snapshot) | `XT_ProcessItem(Ex)` fires for **every** item, multi-threaded. Right for "scan the whole snapshot". |
| `XT_ACTION_DBC` (Directory-browser context menu) | Fires only for the **items the analyst selected** in the directory browser. Single-threaded. Right for "run this analyzer on these N files". |

Or — for a one-shot analyzer that wants control over the iteration order — do all the work in `XT_Prepare` and call `XWF_GetItemCount` + `XWF_GetItemName` + ... in a plain `for` loop. Single-threaded, no synchronisation needed, easier to reason about. Pattern documented at [xtension-invocation.md:152-163](xtension-invocation.md#L152-L163).

```cpp
LONG __stdcall XT_Prepare(HANDLE hVolume, HANDLE hEvidence, DWORD nOpType, void*) {
    DWORD n = XWF_GetItemCount(nullptr);
    for (LONG i = 0; i < (LONG)n; ++i) {
        const wchar_t* name = XWF_GetItemName(i);
        // analyze...
    }
    return 0;  // skip per-item callbacks
}
```

### `nItemID` numbering

The `nItemID` returned/accepted everywhere is the directory browser's **`Int. ID`** column, not the plain `ID` column. `ID` is the filesystem-level entry number (e.g., NTFS MFT entry) and can be duplicated across child streams; `Int. ID` is unique per snapshot item and is what the X-Tension API uses. Enable the `Int. ID` column in the directory browser when correlating X-Tension behaviour to UI rows. Documented at [xways-events-api.md:250](xways-events-api.md#L250).

## Combining: events × items × content

The richest analyzer pattern uses all three layers:

1. Enumerate events via `XWF_GetEvent`.
2. For each event with `nItemID >= 0`, look up the linked item (`XWF_GetItemName`, `XWF_GetItemInformation`, ancestor walk via `XWF_GetItemParent`).
3. Optionally `XWF_OpenItem` + `XWF_Read` (or `XWF_GetText`) to inspect the bytes/text behind the artefact.
4. Run the rule.
5. Surface findings: emit enriched events via `XWF_AddEvent`, set comments via `XWF_AddComment`, file items into report tables via `XWF_Label` (née `XWF_AddToReportTable`), set type-status flags via `XWF_SetItemType`, log via `XWF_OutputMessage`. Surfaces summarized at [xways-events-api.md:252-264](xways-events-api.md#L252-L264).

Combined with `XWF_GetUserInput` in `XT_Prepare` (see [xways-user-input-and-dialogs.md](xways-user-input-and-dialogs.md)), the full shape becomes:

```cpp
LONG __stdcall XT_Prepare(HANDLE hVolume, HANDLE hEvidence, DWORD nOpType, void*) {
    wchar_t pattern[260] = L"";
    if (XWF_GetUserInput(L"Pattern to scan for:", pattern, 260, 0) < 0) return -1;

    EventInfo probe = {};
    probe.iSize = sizeof(LONG) + sizeof(HANDLE);
    probe.hEvidence = hEvidence;
    DWORD total = XWF_GetEvent(0, &probe);

    for (DWORD i = 0; i < total; ++i) {
        EventInfo evt = {};
        evt.iSize = sizeof(EventInfo);
        evt.hEvidence = hEvidence;
        char desc[256] = {0};
        evt.lpDescr = desc;
        if (XWF_GetEvent(i, &evt) == MAXDWORD) continue;
        if (!Matches(desc, pattern)) continue;

        if (evt.nItemID >= 0) {
            // pull item context, enrich, emit a sibling event
            EmitEnrichedEvent(hEvidence, evt, ResolveItemContext(evt.nItemID));
        }
    }
    return 0;
}
```

## What you cannot read

- **The live UI grid** — there is no API that returns "the rows currently visible to the analyst given the active filter / sort / selection." `XT_ACTION_DBC` gets you the analyst's selection (the closest equivalent), but only when the X-Tension was launched from the directory-browser context menu.
- **Active filters, sort order, column widths** — internal UI state, not exposed.
- **Visual rendering** (Conditional Coloring decisions, etc.) — those happen at draw time and aren't reflected back through the API.
- **Other evidence objects' events while a different one is "current"** — `XWF_GetEvent` operates on a specific `hEvidence`. To analyze across the whole case, walk evidence objects via `XWF_GetFirstEvObj` / `XWF_GetNextEvObj`, opening each as needed.

## See also

- [xways-events-api.md](xways-events-api.md) — full `XWF_AddEvent` / `XWF_GetEvent` / `EventInfo` reference, subcode tables, `nFlags` semantics.
- [xways-user-input-and-dialogs.md](xways-user-input-and-dialogs.md) — `XWF_GetUserInput`, Win32 dialogs, sidecar config; how to ask the analyst what to look for.
- [xtension-invocation.md](xtension-invocation.md) — `XT_ACTION_*` modes, threading model, when item callbacks fire.
- [xways-getprop-reference.md](xways-getprop-reference.md) — `XWF_GetProp` property numbers for richer per-item / per-evidence reads.
- [events-viewer-empirical-findings.md](events-viewer-empirical-findings.md) — measured behaviour of the Events viewer beyond what the docs commit to.
- The X-Ways SDK header (see [getting-the-sdk.md](getting-the-sdk.md)) — authoritative SDK declarations.
- Official function reference: <https://www.x-ways.net/forensics/x-tensions/XWF_functions.html>
