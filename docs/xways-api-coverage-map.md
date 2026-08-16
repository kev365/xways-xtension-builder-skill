---
source: https://www.x-ways.net/forensics/x-tensions/XT_functions.html + XWF_functions.html (official), enumerated 2026-08-12
type: coverage-map
fetched: 2026-08-12
last_updated: 2026-08-16
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
| **Covered** | 73 | a page here explains it, not just names it |
| **Named only** | 26 | appears, but do not expect a usable description |
| **Absent** | 0 | nothing is completely unmentioned any more |

Regenerate with [`scripts/api-coverage.ps1`](../scripts/api-coverage.ps1)
(`-Detail` lists the buckets). It is not a CI gate — coverage gaps are expected
and it needs network access.

**Read "0 absent" carefully.** It means every documented function is now
*findable* here, not that every one is *explained*. A third of the surface is
still name-level only, and seven functions are named precisely to record that
**X-Ways has not implemented them** (see below). Treat the Named-only list as
"go to the official page", exactly as before.

**Why this page exists.** The hard gate says never invent an `XWF_` call and to
verify against the distilled notes first. That is only safe when it is obvious
where the notes are thin — otherwise "not in `docs/`" gets misread as "not in
the API".

## Documented but not implemented

Eight entries exist on the official page yet do nothing. X-Ways greys out
**ideas for potential future additions** and says so on the page, so a symbol
appearing in the reference is *not* evidence that it works:

| Function | Note |
| --- | --- |
| `XWF_AddSearchHit`, `XWF_GetSearchHit`, `XWF_SetSearchHit` | the entire search-hit manipulation trio — see [xways-search-api.md](xways-search-api.md) |
| `XWF_SetItemName` | renaming an item |
| `XWF_SetItemDataRuns` | supplying extents for an item |
| `XWF_DeleteEvObj` | removing an evidence object from the case |
| `XWF_Write` | and WinHex-only in any case, never X-Ways Forensics |
| `XWF_GetDriveInfo` | same greyed-out wording as the rest |

**Check for that sentence before designing around any symbol you have not used
before** — verifying a function "exists on the official page" is not
sufficient.

## Contents

- Documented but not implemented
- What is still thin
- Named only — check the live page before relying on these
- Constants are patchier than functions
- Keeping this page honest

## What is still thin

Every function is now findable, but these subsystems are documented at
reference depth rather than "here is how you use it":

| Subsystem | State |
| --- | --- |
| **Search** | [xways-search-api.md](xways-search-api.md) — entry points, hit struct, flags, term management, and which parts do not work |
| **Progress** | [xways-user-input-and-dialogs.md](xways-user-input-and-dialogs.md) — the four calls plus the rule against using them in a per-item callback |
| **Blocks, sector attribution, raster images, bulk label reads** | [xways-reading-events-and-items.md](xways-reading-events-and-items.md) |
| **Viewer X-Tensions** | [xtension-invocation.md](xtension-invocation.md) — the class and the callbacks that do *not* fire in it |
| **Evidence file containers** | [xways-evidence-containers.md](xways-evidence-containers.md) — the three calls, the `XWF_CTR_*` flags, and the one-container-at-a-time rule |
| **Hash values** | [xways-snapshot-mutation.md](xways-snapshot-mutation.md) for the in/out buffer protocol, [xways-getprop-reference.md](xways-getprop-reference.md) for the type codes and sizes |

What remains genuinely unexplored is **constants, not functions** — see below.

## Named only — check the live page before relying on these

`XWF_AddSearchHit`, `XWF_AddSearchTerm`, `XWF_CloseEvObj`, `XWF_DeleteEvObj`,
`XWF_GetColumnTitle`, `XWF_GetComment`, `XWF_GetFileCount`,
`XWF_GetFirstEvObj`, `XWF_GetHashSetAssocs`, `XWF_GetItemOfs`,
`XWF_GetNextEvObj`, `XWF_GetRasterImage`, `XWF_GetReportTableInfo`,
`XWF_GetSearchHit`, `XWF_GetSearchTerm`, `XWF_GetSectorContents`,
`XWF_GetVolumeInformation`, `XWF_HideProgress`, `XWF_ReleaseMem`,
`XWF_SetItemDataRuns`, `XWF_SetItemName`, `XWF_SetItemOfs`,
`XWF_SetItemParent`, `XWF_SetProgressDescription`, `XWF_SetSearchHit`,
`XWF_Write`.

!!! note "The bucket is cruder than it looks — do not over-read it"
    A function counts as *covered* only when some `docs/` page names it **twice
    or more**. That is a proxy for "explained", and a rough one. Several
    functions in the list above *are* properly documented and land here purely
    because one well-written paragraph names them once — `XWF_GetSectorContents`,
    `XWF_GetRasterImage`, `XWF_GetReportTableInfo`, `XWF_HideProgress`,
    `XWF_SetProgressDescription` and `XWF_GetSearchTerm` among them. Others in
    the list are named *because they do not work*.

    The fix is not to sprinkle repeated mentions to move the number — that would
    be gaming the measurement rather than improving the notes. Use the list as a
    prompt to check, not as a verdict.

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

Regenerate with [`scripts/api-coverage.ps1`](../scripts/api-coverage.ps1) rather
than hand-editing, and update `last_updated` when you do. A stale coverage map
is worse than none: it invites exactly the false confidence this page exists to
prevent.

**This page must exclude itself from the measurement**, and the script does.
The first cut did not, and the effect was immediate — by naming every uncovered
function, the map counted as a mention of each and the next run reported **zero**
absent functions. A map that measures itself always reports full coverage. The
same applies to the CHANGELOG, which describes the gaps in prose; it is excluded
for the same reason.

A second bug in the same script: it listed only **tracked** files, so a doc
written minutes earlier was invisible and the map under-reported — exactly when
someone would run it. It now includes new, uncommitted files.

The counts have been revised four times as pages were added
(**59/20/20 → 62/20/17 → 67/32/0 → 72/27/0 → 73/26/0**, 2026-08-12 → 14; the
move-by-move history lives in [CHANGELOG.md](../CHANGELOG.md)) — which is the
map doing its job, and why the numbers are only trustworthy as of the
frontmatter date. Regenerate rather than trusting any copy quoted elsewhere;
the always-on guardrail once quoted a two-revisions-stale triple for months.

Two dimensions this map deliberately does not carry: **per-language exposure**
(whether a Python X-Tension can *call* a covered function is answered
per-method by [xways-python-bridge.md](xways-python-bridge.md) — 46 exposed of
the C surface), and **vendor demonstration** (the SDK's own status spreadsheet
says the vendor's samples exercise only 24 functions; most of the API has no
vendor-demonstrated call anywhere — see
[xways-sdk-source-notes.md](xways-sdk-source-notes.md)).
