---
source: https://www.x-ways.net/forensics/x-tensions/XT_functions.html + XWF_functions.html (official), distilled 2026-08-12
type: official-doc
fetched: 2026-08-12
last_updated: 2026-08-12
author: X-Ways Software Technology AG (distilled); project notes
---

# The search surface — search terms and search hits

The simultaneous-search side of the API, which the rest of these notes never
covered even though the templates already export `XT_ProcessSearchHit`.

Two directions, and they do not compose the way you would expect:

| Direction | You implement / call |
| --- | --- |
| **X-Ways searches, you observe** | `XT_PrepareSearch` before, `XT_ProcessSearchHit` per hit |
| **You search** | `XWF_Search` from `XT_Prepare` or `XT_Finalize` |

**The trap:** `XT_ProcessSearchHit` is **not called for a search your own
X-Tension started** with `XWF_Search`. If you kick off a search expecting your
hit callback to fire, nothing happens. Observing hits and driving a search are
separate modes, not two halves of one pipeline.

## Contents

- Injecting search terms — `XT_PrepareSearch`
- Receiving hits — `XT_ProcessSearchHit`
- Running your own search — `XWF_Search`
- Search terms — read and create
- Not implemented — do not build on these

## Injecting search terms — `XT_PrepareSearch`

Exported optionally; called by **v16.9+** when the X-Tension is loaded for use
with a simultaneous search, before the search runs. It lets the X-Tension
pre-fill the search-term box and inspect the settings the analyst chose.

```c
LONG XT_PrepareSearch(struct PrepareSearchInfo* pPSInfo, struct CodePages* pCPages);

#pragma pack(2)
struct PrepareSearchInfo { DWORD nSize; LPWSTR lpSearchTerms; DWORD nBufLen; DWORD nFlags; };
#pragma pack(2)
struct CodePages { DWORD nSize; WORD nCodePage1..nCodePage5; };   // 0 = unused slot
```

- `lpSearchTerms` is a null-terminated, **line-break-delimited** list you may
  edit, replace or extend **within the existing buffer**.
- `nBufLen` is in **UTF-16 characters**, currently 32768 — documented as subject
  to change, so read it rather than hardcoding.
- **Only the search-term text is honoured.** Changes to the pointer, the buffer
  size, the flags or the code pages are *ignored*. You can read the settings to
  decide whether to proceed; you cannot change them.
- Return **1** if you edited the terms, **0** if you left them alone, **−1** if
  the settings are unusable for your purpose — which unselects the X-Tension.

`nFlags` reports the analyst's search settings:

| Bit | Symbol | Meaning |
| --- | --- | --- |
| `0x0010` | `XWF_SEARCH_MATCHCASE` | match case |
| `0x0020` | `XWF_SEARCH_WHOLEWORDS` | whole words only |
| `0x0040` | `XWF_SEARCH_GREP` | GREP syntax |
| `0x4000` | `XWF_SEARCH_WHOLEWORDS2` | whole words only for specially marked terms |
| `0x8000` | `XWF_SEARCH_GREP2` | GREP syntax only for terms starting with `grep:` |

Note `XT_INIT_ABOUTONLY` (`0x40`) means X-Ways is about to call `XT_About`
**or `XT_PrepareSearch`** only — so do not treat that flag as "About dialog
only" and skip search preparation.

## Receiving hits — `XT_ProcessSearchHit`

Called per hit as it is found (and possibly later, applied to hits already in a
list). Return **0** normally, **−1** to abort the search, **−2** to stop being
called while the search continues.

```c
#pragma pack(2)
struct SearchHitInfo {
    DWORD  nSize;          // record size; may grow in future versions
    LONG   nItemID;
    INT64  nRelOfs;        // offset within the file, or -1
    INT64  nAbsOfs;        // offset from the volume start, or negative
    PVOID  lpOptionalHitPtr;
    WORD   nSearchTermID;
    WORD   nLength;        // hit size in bytes
    WORD   nCodePage;
    WORD   nFlags;
    HANDLE hOptionalItemOrVolume;
};
```

**The struct is an in/out parameter — that is the point of the callback.** You
may change `nRelOfs`, `nAbsOfs`, `nLength`, `nSearchTermID` and the flags to
improve a hit, re-file it under a different search term, or throw it away.

| Flag | Meaning |
| --- | --- |
| `0x0001` | index search hit |
| `0x0002` | lives in alternative text for the file — `nRelOfs` indexes *that text*, not the file |
| `0x0004` | notable |
| `0x0008` | deleted — **set this to discard the hit** |
| `0x0020` | special: found by user, or by block-hash matching/comparison |
| `0x0040` | include in the case report — **see the caveat below** |
| `0x0100` | (with `0x0001`) found in text decoded from the file format — v20.3+ |
| `0x0200` | (with `0x0001`) found in text derived by OCR — v20.3+ |
| `0x0400` | (with `0x0001`) found in a directory-browser column (Name, Owner, Author, Metadata…) — v20.3+ |

!!! warning "`0x0040` is listed twice on the official page"
    The flag list gives `0x0040` two different meanings back to back — "to be
    included in case report" and "contained in slack space or an uninitialised
    end portion of a file". One of them is presumably a typo for a neighbouring
    bit, but the page does not say which. **Verify empirically before relying on
    either reading**, and do not infer the other bit's value.

Two fields are only populated in the live-search case:

- **`lpOptionalHitPtr`** points at the hit inside the buffer that was searched.
  Provided only *during* a search, and only for simultaneous-search hits — never
  for index searches, and not when the callback is applied to an existing hit.
  **Make no assumption about how many bytes either side of the hit are readable.**
- **`hOptionalItemOrVolume`** (v16.5+) is the item for a logical search or the
  volume for a physical one. `0` for index searches and for later application.

If you call `XWF_SelectVolumeSnapshot` while handling a hit, **you must call it
again to restore the previous selection before returning.**

Related invocation modes: `XT_ACTION_LSS` (2) and `XT_ACTION_PSS` (3) signal a
logical or physical search starting; `XT_ACTION_SHC` (5) is the search-hit-list
context menu — see [xtension-invocation.md](xtension-invocation.md).

## Running your own search — `XWF_Search`

Available **v16.5+**. **Callable only from `XT_Prepare` or `XT_Finalize`.**

```c
LONG XWF_Search(struct SearchInfo* pSInfo, struct CodePages* pCPages);

#pragma pack(2)
struct SearchInfo {
    DWORD  nSize;  HANDLE hVolume;  LPWSTR lpSearchTerms;  DWORD nFlags;
    DWORD  nSearchWindow;  LPSTR lpLatin1Alphabet;  LPWSTR lpNonLatin1Alphabet;
};
```

The volume **must be associated with an evidence object**. Negative return means
error. Run as part of refinement, it can fire automatically for every selected
evidence object if the analyst applies the X-Tension that way — so a search you
think you are running once may run once per evidence object.

And again: hits from this search do **not** reach your `XT_ProcessSearchHit`.

## Search terms — read and create

**`XWF_GetSearchTerm(nSearchTermID, pReserved)`** — v17.7+. Returns a pointer to
the term's null-terminated name, or NULL if the ID does not exist. IDs are
consecutive from 0. **Pass `-1` to get the total count instead** — cast the
returned pointer to an integer. `pReserved` must be NULL.

**`XWF_AddSearchTerm(lpSearchTerm, nUsageFlags)`** — v18.5+. Creates a term and
returns its ID, or `-1` on error. Flags: `0x01` re-use an existing term with the
same expression rather than duplicating it; `0x02` mark it as a term for user
search hits. Limits: **8,191 search terms per case**, and the name is truncated
beyond about **90 characters** (as of v20.3).

Together these are how you categorise hits: create or look up a term, then set
`nSearchTermID` on the hit in `XT_ProcessSearchHit`.

## Not implemented — do not build on these

The official page documents three hit-manipulation functions that **do not
work**:

| Function | Page says |
| --- | --- |
| `XWF_AddSearchHit(SearchHitInfo*)` | creates a search hit — *not currently implemented* |
| `XWF_GetSearchHit(nSearchHitNo, SearchHitInfo*)` | reads a hit — *not currently implemented* |
| `XWF_SetSearchHit(nSearchHitNo, SearchHitInfo*)` | changes a hit — *not currently implemented* |

This is a property of the page, not an oversight in these notes: X-Ways greys
out entries that are **ideas for potential future additions** and says so
explicitly. **Presence on the official page is therefore not proof a function
works** — check for the "not currently implemented" sentence before designing
around a symbol. The same wording appears on `XWF_SetItemName`,
`XWF_SetItemDataRuns`, `XWF_DeleteEvObj`, `XWF_GetDriveInfo` and `XWF_Write`
(which the page notes would be WinHex-only regardless).

The practical consequence: the only supported way to alter a search hit is to
mutate the `SearchHitInfo` you were handed in `XT_ProcessSearchHit`. There is no
API for revisiting hits afterwards.
