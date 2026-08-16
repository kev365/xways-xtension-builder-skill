---
source: https://www.x-ways.net/forensics/x-tensions/XT_functions.html + XWF_functions.html (official), distilled 2026-08-12; XWF_SEARCH_* family from XT_API.pas (hmrc/XT_XWF-AutoCTR, Apache-2.0), 2026-08-13
type: official-doc
fetched: 2026-08-12
last_updated: 2026-08-15
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

**The trap:** by default `XT_ProcessSearchHit` is **not called for a search
your own X-Tension started** with `XWF_Search`. The documented opt-in is the
`XWF_SEARCH_CALLPSH` flag (*"Only if the XWF_SEARCH_CALLPSH flag is specified,
X-Ways Forensics will call XT_ProcessSearchHit(), if exported, for each
hit"* — official prose this page originally missed). **Empirically the opt-in
delivered zero callbacks on 21.9 Beta 1 in a CLI-launched context** — see the
`XWF_Search` section and the
[conflicts register](xways-sdk-conflicts-test-plan.md) before designing around
either behaviour.

## Contents

- Injecting search terms — `XT_PrepareSearch`
- Receiving hits — `XT_ProcessSearchHit`
- Running your own search — `XWF_Search`
- The `XWF_SEARCH_*` flag family
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

### Vendor-sample confirmation — the SDK's `Luhn.cpp`

The SDK ships exactly one search-related sample: `Luhn.cpp` (see
[getting-the-sdk.md](getting-the-sdk.md)), a passive hit filter that
Luhn-validates credit-card hits. It demonstrates, in working vendor code,
the hit-mutation idioms this page could previously only state from prose:

- **Discard a hit:** `info->nFlags |= 0x0008;` with the vendor's own comment
  `// ignore hit` — confirming the `0x0008` reading in the flag table below.
- **Rewrite the hit in place:** it shrinks `info->nLength` after stripping
  separator characters, and X-Ways honours the new length.
- **Version-gate on `iSize`:** `if (info->iSize < 36) return 0;` — the struct
  is versioned by its size field; check it before touching later fields.
- **The hit-buffer convention:** `nLength` is a **byte** count in `nCodePage`.
  If `nCodePage != 1200`, convert with `MultiByteToWideChar(nCodePage, …)`;
  if `nCodePage == 1200` the bytes are **already UTF-16LE** (wchar count =
  `nLength / 2`). This is the clearest statement of the convention anywhere in
  the SDK — with the caveat that the sample's own 1200 branch is broken (it
  never copies the bytes; see the bug catalog in
  [xways-sdk-source-notes.md](xways-sdk-source-notes.md)).

Also instructive: `Luhn.cpp` never calls `XWF_Search` and returns `0` from
`XT_Prepare` — a hit filter is *passive*, driven entirely by the analyst's own
search. Python note: `XT_ProcessSearchHit` does reach Python scripts, but as a
**flattened copy** — mutation-based filtering like Luhn's is C++-only
([xways-python-bridge.md](xways-python-bridge.md)).

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

**Corrections and live findings (2026-08-15, 21.9 Beta 1):**

- **`hVolume` must be `0`** — official: "Currently must be 0, function is
  always applied to the active volume."
- **`pCPages` is mandatory in practice.** Passing `NULL` — which the signature
  invites — **access-violates inside X-Ways** (0xC0000005; surfaces as Delphi
  runtime error 217 and kills the host if unhandled). Pass a `CodePages`
  struct with `nSize` set and at least one code page (e.g. 1252).
- **`nSize` may be 28** (packed, through `nSearchWindow`) — official: "should
  cover at least all member variables up to nSearchWindow". The two alphabet
  pointers are v20.0+ extensions, and **both overwrite the analyst's alphabet
  settings permanently when non-NULL** ("The previously used alphabet will be
  lost") — leave them NULL unless that is intended.
- **The SDK C header's `SearchInfo` is wrong twice**: it lacks the two
  alphabet members and is **not packed** (default alignment puts `hVolume` at
  offset 8; the packed/official layout has it at 4). Use the official page's
  `#pragma pack(2)` 7-field layout.
- **`XWF_Search` re-enters your own X-Tension**: each call ran our
  `XT_Finalize` (with `nOpType = 2`, LSS) before returning — entry points must
  be re-entrancy-safe if you call `XWF_Search`.
- **Post-search host instability**: every run in which `XWF_Search`
  executed — even cleanly, CLI-launched *and* GUI-session alike — ended with
  runtime error 217 at the same address. Tracked as a bug candidate; treat
  `XWF_Search` as hazardous on 21.9 Beta 1 regardless of context.

**The analyst-driven side works (verified 2026-08-15, 21.8 SR-5):** with the
X-Tension participating in a GUI simultaneous search, `XT_ProcessSearchHit`
fired per hit (`nOpType = 2` at `XT_Prepare`), delivering `iSize = 48` (the
full current struct), `nCodePage = 1252`, and `nFlags = 0x0000` on plain
in-content hits — so ordinary hits carry *neither* documented meaning of the
ambiguous `0x0040` bit. The search lifecycle also showed an undocumented
shape: the DLL is first initialised with `XT_INIT_ABOUTONLY` (0x40) set —
matching the documented "About or XT_PrepareSearch" semantics — then unloaded
(`XT_Done`) and re-initialised for the actual search.

**On the hit callback:** the official prose (missed in this page's first
distillation) says *"Only if the XWF_SEARCH_CALLPSH flag is specified, X-Ways
Forensics will call XT_ProcessSearchHit(), if exported, for each hit"* — i.e.
the trap stated at the top of this page is the *default*, and `CALLPSH`
(`0x01000000`, observed from v16.8 SR-5) is the documented opt-in. **Empirically
on 21.9 Beta 1 the opt-in did not work in any tested context**: CLI-launched
and GUI-session runs both delivered **zero callbacks against a term with 2,658
confirmed hits**. See the [conflicts register](xways-sdk-conflicts-test-plan.md)
entry 2 for caveats and status.

## The `XWF_SEARCH_*` flag family

`nFlags` on `SearchInfo` — and the subset that `XT_PrepareSearch` reports back to
you. These are transcribed from **`XT_API.pas`**, the Pascal binding in
[hmrc/XT_XWF-AutoCTR](https://github.com/hmrc/XT_XWF-AutoCTR) (Apache-2.0):

| Bit | Constant | Meaning |
| --- | --- | --- |
| `0x00000001` | `XWF_SEARCH_LOGICAL` | logical search (rather than physical) |
| `0x00000004` | `XWF_SEARCH_TAGGEDOBJ` | tagged objects only |
| `0x00000010` | `XWF_SEARCH_MATCHCASE` | match case |
| `0x00000020` | `XWF_SEARCH_WHOLEWORDS` | whole words only |
| `0x00000040` | `XWF_SEARCH_GREP` | GREP syntax |
| `0x00000080` | `XWF_SEARCH_OVERLAPPED` | allow overlapping hits |
| `0x00000100` | `XWF_SEARCH_COVERSLACK` | cover slack space |
| `0x00000200` | `XWF_SEARCH_COVERSLACKEX` | cover slack, extended |
| `0x00000400` | `XWF_SEARCH_DECODETEXT` | decode text |
| `0x00000800` | `XWF_SEARCH_DECODETEXTEX` | decode text, extended — **binding comments say "not yet supported"** |
| `0x00001000` | `XWF_SEARCH_1HITPERFILE` | stop at the first hit in each file |
| `0x00002000` | `XWF_SEARCH_COVERSLACK2` | a third slack-coverage variant |
| `0x00004000` | `XWF_SEARCH_WHOLEWORDS2` | whole words for specially marked terms only |
| `0x00008000` | `XWF_SEARCH_GREP2` | GREP for terms prefixed `grep:` only |
| `0x00010000` | `XWF_SEARCH_OMITIRRELEVANT` | skip items categorised irrelevant |
| `0x00020000` | `XWF_SEARCH_OMITHIDDEN` | skip hidden items |
| `0x00040000` | `XWF_SEARCH_OMITFILTERED` | skip filtered-out items |
| `0x00080000` | `XWF_SEARCH_DATAREDUCTION` | apply data reduction |
| `0x00100000` | `XWF_SEARCH_OMITDIRS` | skip directories |
| `0x01000000` | `XWF_SEARCH_CALLPSH` | **call `XT_ProcessSearchHit` for each hit** |
| `0x02000000` | `XWF_SEARCH_IGNORECODEPAGES` | ignore the code-page list |
| `0x04000000` | `XWF_SEARCH_DISPLAYHITS` | show the hits in the GUI |

The five flags in the `XT_PrepareSearch` table above (`0x10`, `0x20`, `0x40`,
`0x4000`, `0x8000`) are the same bits, and they agree — a useful cross-check on
the rest of the list.

!!! warning "Provenance: an old binding, unverified above the five confirmed bits"
    `XT_API.pas` is a **v18-era snapshot**. It predates `XT_ACTION_EVT` (6),
    `XT_PREPARE_TARGETZEROBYTEFILES` (`0x20`) and the 21.x additions, its
    `SearchInfo` lacks the two alphabet pointers current X-Ways declares, and
    its `XWF_GetReportTableInfo` signature takes `nOptional` **by value** where
    the current API takes a `PLONG` — calling that one as declared would be a
    bug. Treat the table above as a **strong lead, not a citation**: verify a
    bit against the official page or empirically before shipping behaviour that
    depends on it.

    `XWF_SEARCH_CALLPSH` (`0x01000000`) is the one to be most careful with,
    because it appears to contradict the rule stated at the top of this page —
    that `XT_ProcessSearchHit` is not called for a search you started yourself.
    Either the flag is what lifts that restriction, or it is a leftover. **Test
    it before designing around either reading.**

    The 2026-08-14 SDK source review made this worse, not better: **no working
    `XWF_Search` invocation exists anywhere in the SDK** — not in the C++
    samples, not in the Python bridge (which doesn't expose it), and not in the
    C# tree (the project literally named "C# Search Test" never calls it). The
    flag has never been demonstrated by anyone, vendor included. Probe design in
    [xways-sdk-conflicts-test-plan.md](xways-sdk-conflicts-test-plan.md).

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
