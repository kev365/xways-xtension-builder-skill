---
source: https://www.x-ways.net/forensics/x-tensions/XT_functions.html + XWF_functions.html (official), enumerated 2026-08-12
type: coverage-map
fetched: 2026-08-12
last_updated: 2026-08-12
author: project
---

# API coverage map — what these notes do and do not cover

The official reference documents **99 functions** across
[XT_functions.html](https://www.x-ways.net/forensics/x-tensions/XT_functions.html)
(the entry points X-Ways calls in your DLL) and
[XWF_functions.html](https://www.x-ways.net/forensics/x-tensions/XWF_functions.html)
(the API you call back into). Enumerated mechanically on **2026-08-12**:

| | Count | Meaning |
| --- | ---: | --- |
| **Covered** | 59 | a page here explains it, not just names it |
| **Named only** | 20 | appears in passing, usually in a version-history row |
| **Absent** | 20 | not mentioned anywhere in this repository |

**Why this page exists.** The hard gate says never invent an `XWF_` call and to
verify against the distilled notes first. That is only safe if it is obvious
when the notes are *silent* — otherwise "not in `docs/`" gets misread as "not in
the API". Roughly **40% of the documented surface is thin or missing here**, so
absence from these notes means nothing at all about whether a function exists.

**If the function you need is in the Absent list below, skip `docs/` and go
straight to the live page.** Do not infer a signature from a neighbouring
function, and do not assume a symbol is unavailable because it is unlisted here.

## Absent — not covered anywhere in this repository

Grouped by the subsystem they belong to, because they go missing in clusters:
these are whole capabilities the notes never explore, not scattered oversights.

| Subsystem | Functions |
| --- | --- |
| **Search hits** | `XT_PrepareSearch`, `XWF_AddSearchHit`, `XWF_GetSearchHit`, `XWF_SetSearchHit`, `XWF_GetSearchTerm` |
| **Viewer X-Tensions** | `XT_View`, `XT_ReleaseMem` |
| **Progress reporting** | `XWF_ShowProgress`, `XWF_HideProgress`, `XWF_SetProgressDescription` |
| **Hex blocks** | `XWF_GetBlock`, `XWF_SetBlock` |
| **Item mutation** | `XWF_SetItemName`, `XWF_SetItemDataRuns` |
| **Evidence & report tables** | `XWF_DeleteEvObj`, `XWF_GetEvObjReportTableAssocs`, `XWF_GetReportTableInfo` |
| **Low-level I/O & rendering** | `XWF_Write`, `XWF_GetSectorContents`, `XWF_GetRasterImage` |

Two of those clusters are **whole X-Tension classes**, not just functions:

- **Search X-Tensions** — `XT_PrepareSearch` receives the search terms and code
  pages before a simultaneous search runs, and the `XWF_SEARCH_*` flag family
  (about 25 constants: `GREP`, `MATCHCASE`, `WHOLEWORDS`, `COVERSLACK`,
  `OMITFILTERED`, `DECODETEXT`, …) configures it. `XT_ProcessSearchHit` — which
  our templates *do* export — is the tail of a pipeline the notes otherwise
  never describe.
- **Viewer X-Tensions** — see [xtension-invocation.md](xtension-invocation.md).

## Named only — a version-history row, not an explanation

Present somewhere, but do not expect a usable description. Verify against the
live page before writing code against any of these:

`XWF_AddSearchTerm`, `XWF_CloseContainer`, `XWF_CloseEvObj`,
`XWF_CopyToContainer`, `XWF_CreateContainer`, `XWF_GetColumnTitle`,
`XWF_GetComment`, `XWF_GetFileCount`, `XWF_GetFirstEvObj`,
`XWF_GetHashSetAssocs`, `XWF_GetHashValue`, `XWF_GetItemOfs`,
`XWF_GetNextEvObj`, `XWF_GetSize`, `XWF_GetVolumeInformation`,
`XWF_ReleaseMem`, `XWF_Search`, `XWF_SelectVolumeSnapshot`, `XWF_SetItemOfs`,
`XWF_SetItemParent`.

## Constants are patchier than functions

The enumeration also found ~60 officially-documented constants absent here,
concentrated in the same places: the whole `XWF_SEARCH_*` family, most
`XWF_ITEM_INFO_*` timestamp and flag selectors
(`LASTACCESSTIME`, `ENTRYMODIFICATIONTIME`, `INTERNALCREATIONTIME`, their
`_DISPLAY_OFS` variants, `FLAGS_SET` / `FLAGS_REMOVE`, `LINKCOUNT`,
`FILECOUNT`, `ORIG_ID`, `EMBEDDEDOFFSET`, `CLASSIFICATION`, `COLORANALYSIS`,
`PIXELINDEX`), and the `XWF_CTR_*` container flags. Where a specific constant
matters, [xways-getprop-reference.md](xways-getprop-reference.md) and
[xways-itemtype-metadata-text.md](xways-itemtype-metadata-text.md) carry
empirically-derived values — but neither is a complete transcription of the
official lists.

## Keeping this page honest

Regenerate rather than hand-edit. The counts came from extracting every
`XWF_*(` / `XT_*(` token from both official pages and matching each against the
tracked files, classifying a function as *covered* only when a `docs/` page
mentions it more than once. Re-run that when the official pages change, and
update the date in the frontmatter — a stale coverage map is worse than none,
because it invites exactly the false confidence this page exists to prevent.
