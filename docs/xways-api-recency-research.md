---
source: SourceForge SDK page (xwf-api-rs v2-develop reviewed 2026-08-13), X-Ways 21.5–21.9 release notes / changelog, live API HTML (checked 2026-08-12), github.com/ThomasVogl/xwf-api-rs, the 21.8 + 21.9 announcement threads, 21.7 / 21.8 X-Tension behaviour notes (2026-05-13)
type: research-summary
fetched: 2026-05-03
last_updated: 2026-08-14
author: empirical research notes
---

# X-Tension API recency research (21.5 – 21.9)

State-of-the-world snapshot for the X-Tension API surface. Captures (a) whether a newer SDK exists than the 2024-05-31 header, (b) what API additions/changes the 21.5–21.8 forum threads announced beyond what the header documents, and (c) the highest-value community RE source for cross-referencing the empirical findings in this documentation set.

For the distilled behavior notes driving the 21.7/21.8 rows, see [forum-xtensions-distilled.md](forum-xtensions-distilled.md).

## Contents

- TL;DR
- SDK status
- Forum announcements 21.5 → 21.9 — net new API surface
- Community RE — `ThomasVogl/xwf-api-rs` is the gold mine
- No public Ghidra/IDA export dump
- Open verification ideas
- See also

## TL;DR

**No newer C++ SDK zip has shipped, but the git repo HEAD is newer.** [SourceForge xwf-api files](https://sourceforge.net/projects/xwf-api/files/) still lists `XWF_API-source-2024-05-31.zip` as the latest packaged release. **However, the project's git repo at [sourceforge.net/p/xwf-api/code](https://sourceforge.net/p/xwf-api/code/) has 10 commits past that zip, through commit `c46a1bd2` (2024-07-26)** (fetched 2026-05-18; see [getting-the-sdk.md](getting-the-sdk.md) for how to obtain the SDK).

What the git HEAD adds vs the 2024-05-31 zip:

- **`XT_Init` signature change** — `void* lpReserved` is now `LicenseInfo* license`. License info lives in the fourth parameter, not in `nFlags`. Binary-compatible at the call site (no source change required to keep existing X-Tensions building / loading).
- **No other `X-Tension.h` changes** — every function pointer typedef, every `XWF_*` / `XT_*` / `IIO_*` constant identical to the 2024-05-31 zip. The 23-line diff is exclusively the `XT_Init` block.
- New `C#/` directory under active development (Björn Ganster commits 2024-06-12 → 2024-07-26) — first official C# binding from the vendor. **Evaluated 2026-08-14** ([xways-sdk-source-notes.md](xways-sdk-source-notes.md)): a CLR-hosting shim that wraps exactly **three** functions (`OutputMessage`, `Read`, `GetProp` — the last with a >4 GB truncation bug), marshals callbacks as decimal strings, and never forwards search hits to managed code. Community C# bindings remain far more complete; the official one is a proof of concept.
- Bugfix `CoInitializeEx → CoInitialize` (file-dialog crash) in `X-Tension.cpp` (commit `512321`, 2024-07-12). Worth porting into any X-Tension that raises file dialogs from `XT_Prepare`.
- MSVC 2019 project files removed; MSVC 2022 only.

Treat the **git HEAD** of the X-Ways SDK header (commit `c46a1bd2`; see [getting-the-sdk.md](getting-the-sdk.md)) as canonical. Treat the [live API HTML](https://www.x-ways.net/forensics/x-tensions/XWF_functions.html) as the only post-HEAD source of truth.

The git-HEAD header is still missing roughly **8–10 small additions** made through versions 21.5–21.7 (mostly new property numbers, new flag bits, and new return-code semantics — same gap the 2024-05-31 zip had). The pieces below are documented only on the forum threads + in [`ThomasVogl/xwf-api-rs`](https://github.com/ThomasVogl/xwf-api-rs).

## SDK status

| Source | Latest artefact | Date |
| --- | --- | --- |
| SourceForge: `xwf-api` git repo HEAD | commit `c46a1bd2` "Fix bug in Search Test" | 2024-07-26 |
| SourceForge: `xwf-api` files | `XWF_API-source-2024-05-31.zip` (143 kB, C++ source bundle) | 2024-05-31 |
| SourceForge: `xwf-api` files (Python) | `XT_Python_3.12_x64.zip` | 2024-05-31 |
| Live HTML reference | [XWF_functions.html](https://www.x-ways.net/forensics/x-tensions/XWF_functions.html) | rolling — newest "newer" source past git HEAD |
| Live HTML reference | [api.html](https://www.x-ways.net/forensics/x-tensions/api.html) | rolling |

**Conclusion:** treat git HEAD (2024-07-26) as the canonical SDK; treat the live HTML as the only source for additions past that date.

## Forum announcements 21.5 → 21.9 — net new API surface

Pulled from the X-Ways 21.5–21.9 release notes / changelog. None of these are in the 2024-05-31 header.

| Version | Addition | Source |
| --- | --- | --- |
| 21.4 Beta (2025-02) | **Regression, since fixed:** `XWF_CreateEvObj(1, 0, <path-to-.ctr>, NULL)` access-violated when adding a container that had just been created with `XWF_CreateContainer` / `XWF_CloseContainer`. Worked in 21.3, fixed in later 21.4 releases. Only relevant if you support that build range. | X-Tension board thread 5499 |
| 21.5 Preview 3 (2025-03-07) | **Hash-type IDs changed.** 3 rarely-used hash IDs changed value and 6 were marked deprecated; the announcement points at the `XWF_GetVSProp()` documentation for the updated list. A hard-coded hash-type number from before 21.5 may now name a different algorithm — see the provisional code table in [xways-getprop-reference.md](xways-getprop-reference.md), which is community-sourced and predates this change. (This was previously cited as the lead on the `nParam` puzzle in [xways-snapshot-mutation.md](xways-snapshot-mutation.md); that puzzle turned out to be unrelated and is now closed.) The updated list has **not** yet been transcribed here. | 21.5 announcement thread ([messages/1/5501](https://www.x-ways.net/winhex/forum/messages/1/5501.html)) |
| 21.5 Preview 6 | `XWF_GetItemInformation` / `XWF_SetItemInformation` read/write the **Relevance** column. xwf-api-rs already names this `XWF_ITEM_INFO_RELEVANCE` — find the integer there. Empirically pinned to `nInfoType = 10` — see [xways-itemtype-metadata-text.md](xways-itemtype-metadata-text.md). | X-Ways 21.5 release notes |
| 21.5 Beta 4 | `XT_Init` receives **dongle / BYOD license ID** — **confirmed (2026-05-18)**: delivered via the new `LicenseInfo*` fourth parameter (formerly `void* lpReserved`); see the git HEAD X-Ways SDK header ([getting-the-sdk.md](getting-the-sdk.md)). Not in `nFlags` after all. | X-Ways 21.5 release notes + git HEAD |
| 21.5 Beta 5 (2025-05-19) | **X-Ways prompts before executing / loading an X-Tension** — including when the run is triggered from the **command line**. Plan for it in any unattended/scripted invocation; see [xways-command-line.md](xways-command-line.md). | 21.5 announcement thread ([messages/1/5501](https://www.x-ways.net/winhex/forum/messages/1/5501.html)) |
| 21.5 Beta 6 | `XWF_GetItemSize` defines new return codes for invalid IDs. The same release also made **various `XWF_*()` functions handle an incorrectly supplied `nItemID` more gracefully** — so a bad-ID crash on a pre-21.5-Beta-6 host is not necessarily reproducible on a newer one. | X-Ways 21.5 release notes + 21.5 thread |
| 21.5 SR-5 | `XWF_GetEvObjProp` **`nPropType = 100`** — write side replaces an evidence object's image. Read side: test to learn what 100 returns. | X-Ways 21.5 release notes |
| 21.6 Beta 4 (2025-09-21) | **Fix: the `[XT]` prefix could be separated from its message** in the Messages window when an X-Tension logged from multiple threads. On older hosts, expect interleaved/garbled X-Tension log lines under multi-threaded refinement — a logging artefact, not lost data. See [verbose-logging](conventions/verbose-logging.md). | 21.6 announcement thread ([messages/1/5512](https://www.x-ways.net/winhex/forum/messages/1/5512.html)) |
| 21.6 SR-6 | `XT_PREPARE_DONTOMIT` + `XT_PREPARE_TARGETFILESWITHUNKNOWNDATA` combined override the UI setting to omit files **whose first cluster of original data is known not to be available**. | X-Ways 21.6 release notes + 21.6 thread ([messages/1/5512](https://www.x-ways.net/winhex/forum/messages/1/5512.html)) |
| 21.7 Beta 2 | `XT_PREPARE_TARGETFILESWITHUNKNOWNDATA` **widened** to also force `XT_ProcessItem(Ex)` on encrypted files and files with unsupported compression (previously: metadata-only files only). | X-Ways 21.7 release notes + 21.7 thread ([messages/1/5525](https://www.x-ways.net/winhex/forum/messages/1/5525.html)) |
| 21.7 Beta 4 | Files inside corrupt / incomplete archives are now opened with a **size-0 (useless) handle** so `XT_ProcessItemEx` is called on them. Implementations must check size before reading. | X-Ways 21.7 release notes + 21.7 thread ([messages/1/5525](https://www.x-ways.net/winhex/forum/messages/1/5525.html)) |
| 21.7 SR-4 (2026-05-17) | The label-API rename lands on the 21.7 branch. **The announcement lists the pairs in a misleading order** — "`XWF_GetReportTableAssocs()` and `XWF_AddToReportTable()` got new names: `XWF_Label()` and `XWF_GetLabels()`" reads as a positional mapping but is not one. Pair by **role**: `XWF_AddToReportTable`→`XWF_Label` (action), `XWF_GetReportTableAssocs`→`XWF_GetLabels` (getter). | 21.7 announcement thread ([messages/1/5525](https://www.x-ways.net/winhex/forum/messages/1/5525.html)) |
| 21.8 | `XWF_OpenItem()` flag **`0x8000`** — embed child objects if the item is an e-mail message extracted by X-Ways in `.eml` format, mirroring the GUI "Copy/Recovery" behaviour. Per the live [XWF_functions.html](https://www.x-ways.net/forensics/x-tensions/XWF_functions.html) (2026-07-03): the forum thread's user code used `0x2000`, which is **not** in the official flag list — see [xways-openitem-flags.md](xways-openitem-flags.md). *Resolved 2026-05-23:* the reported "bare-EML size" was the wrong flag, not a size bug — the documentation had said `0x2000`, which embeds nothing. With `0x8000` the size functions report the embedded size; no read-to-EOF workaround needed. | X-Ways 21.8 release notes + live HTML (2026-07-03) |
| 21.8 (rename backported to 21.4 SR-11 / 21.5 SR-13 / 21.6 SR-8 / 21.7 SR-4) | The "label-removal counterpart" is `XWF_Label(LONG nItemID, LPWSTR lpLabelName, DWORD nFlags)` — the rename of `XWF_AddToReportTable` — with removal via `nFlags` `0x80000000` (v21.8+). `XWF_GetLabels(LONG nItemID, LPWSTR lpBuffer, DWORD nBufLenAndMatchType)` likewise renames `XWF_GetReportTableAssocs`. Both old names remain callable but deprecated — see [xways-reading-events-and-items.md](xways-reading-events-and-items.md). | Live [XWF_functions.html](https://www.x-ways.net/forensics/x-tensions/XWF_functions.html) (2026-07-03) |
| 21.8 Preview 5 (2026-03-26) | **The host watchdogs refinement threads.** X-Ways monitors additional threads during volume snapshot refinement and attempts to terminate and resume any unresponsive for ~15 minutes (given as an example, not a documented constant). Bounds how long an X-Tension may block a refinement thread; **scope unverified** — see [forum-xtensions-distilled.md](forum-xtensions-distilled.md) and [threading-model](conventions/threading-model.md). | 21.8 announcement thread ([messages/1/5537](https://www.x-ways.net/winhex/forum/messages/1/5537.html)) |
| 21.8 SR-4 (2026-07-02) | **Fix:** `XWF_OpenItem()` could fail when called from `XT_ProcessItem()` for files inside **nested archives** during multi-threaded refinement. Forum-only — not on the official API page (checked 2026-08-12). On hosts older than 21.8 SR-4, handle the failed open rather than assuming a valid handle. | 21.8 announcement thread ([messages/1/5537](https://www.x-ways.net/winhex/forum/messages/1/5537.html)) |
| 21.8 SR-5 (2026-07-28) | **`XWF_GetCellText` hardened + documented.** Exceptions inside the function are now caught by it and reported as the new return code **`-3`** instead of reaching the X-Tension. The official page also gained a restriction: the **Metadata** column and columns depending on it (generator signature, device type) may be inaccessible during multi-threaded refinement, and X-Ways advises calling the function from `XT_Finalize` instead. Full return-code table in [xways-reading-events-and-items.md](xways-reading-events-and-items.md). | 21.8 announcement thread + live [XWF_functions.html](https://www.x-ways.net/forensics/x-tensions/XWF_functions.html) (2026-08-12) |
| 20.3 SR-3 | `XWF_GetItemCount()` gains the ability to return the count of **selected** files rather than the total. The parameter had been `PVOID pReserved` — undefined, unused and always ignored — so values other than `NULL` / `(LPVOID)1` are still ignored. | X-Tension board thread 5334 |
| 20.3 SR-5 / 20.4 Previews | `XWF_GetCellText` fixed for columns it silently returned empty for (Device Type among them). Note the first fix did **not** land: v20.3 SR-4 still had the error, and it worked from the v20.4 Previews. | X-Tension board thread 5341 |
| 20.8 | X-Tensions are loaded with **`LOAD_WITH_ALTERED_SEARCH_PATH`**, so statically-linked dependent DLLs sitting next to the X-Tension are found. Previously they were not, unless the directory was the X-Ways install or another search-path-special location. **User-disableable via a checkbox.** See [naming-deployment](conventions/naming-deployment.md). | X-Tension board thread 5421 |
| 20.9 SR-9 / 21.0 SR-3 | Fix: `XWF_GetItemName()` returned the wrong thing for certain files when retrieving potentially-available **alternative filenames** (broken in v20.9 and v21.0). | X-Tension board thread 5460 |
| 21.4 Beta 3 | `XWF_GetVSProp()` gains `XWF_VSPROP_RESET` — removes a container from an evidence object. From a later release this happens automatically. | X-Tension board threads 5498 / 5499 |
| 21.9 Preview 1 | **Custom numeric `nEvtType`s become filterable.** The Events filter dialog now lists event types other than the internally defined ones if such events were added by an X-Tension — pick values ≥ 25000 (Category shows "Other") and ≤ 65535. See [xways-events-api.md](xways-events-api.md). | 21.9 announcement thread ([messages/1/5547](https://www.x-ways.net/winhex/forum/messages/1/5547.html), Stefan post 2026-06-09) |
| 21.9 Previews 2–6 + Beta 1 (to 2026-08-11) | **Checked, nothing API-facing.** Read in full on 2026-08-12: hex-display endianness/nibble order, time-zone definitions, UFDR chat extraction (TikTok/Instagram/Telegram/WhatsApp/Messenger), light-bulb evidence-object marking, volume labels in evidence-object titles. No new or changed `XWF_*`/`XT_*` functions, and the live HTML still carries no v21.9 notes. Recorded so the next pass need not re-read these posts. | 21.9 announcement thread ([messages/1/5547](https://www.x-ways.net/winhex/forum/messages/1/5547.html)) |

Also worth re-confirming (older but referenced in threads):

- **21.4 Beta 3** added `XWF_VSPROP_RESET` (programmatically take a new VS). The SDK header does not define a `_RESET` value (`X-Tension.h:177-181` lists 10/20/21/25/26).

### Bugs / doc-vs-reality discrepancies (not yet fixed at time of writing)

| Symptom | Status | Source |
| --- | --- | --- |
| **`XT_PREPARE_TARGETZEROBYTEFILES` has no effect on `XT_ProcessItemEx()`** despite documentation. Zero-byte files are only delivered to the older `XT_ProcessItem()`. Workaround: register both callbacks (routed through one deduping collector — see [item-collection](conventions/item-collection.md)). | Acknowledged by X-Ways; a fix is planned for all future releases — **no specific version stated**. **Still present in 21.8** (verified 2026-06-27 with an item-open probe: the non-`Ex` callback saw exactly one more item — the lone 0-byte file). | X-Ways developer guidance + probe |

## Community RE — `ThomasVogl/xwf-api-rs` is the gold mine

[github.com/ThomasVogl/xwf-api-rs](https://github.com/ThomasVogl/xwf-api-rs) — Rust binding, **LGPL-3.0**. `main` carries v1.0.1 (released 2025-05-17); active development has moved to **`v2-develop`**, version `2.0.0-dev`, last commit **2026-07-14** (reviewed at `4f14ef9` on 2026-08-13). The function inventory still matches the official SDK exports (no extra entry points), but the **enum / bitflag definitions include reverse-engineered values the SDK header does not document**:

| RE constant | Value | Where used |
| --- | --- | --- |
| `EvObjPropType` enum | 0..50 named | Cross-check against the property-number sweep in [xways-getprop-reference.md](xways-getprop-reference.md) |
| `XwfItemInfoTypes` `*_DISPLAY_OFS` family | 48..53 | Six properties added in 21.2 — check the SDK header carries all six |
| `VsPropType::SetHasChanged` | `30` | A VS property the SDK header doesn't list |
| `XwfHashType` + `get_hash_size` | 1..19 | Hash algorithm codes and their byte lengths — transcribed into [xways-getprop-reference.md](xways-getprop-reference.md) |
| `ItemInfoFlags` above bit 31 | `0x1_0000_0000`+ | Three modern flags a `DWORD` would silently drop |

The community xwf-api-rs binding is a useful local cross-reference (with its license attribution preserved); it is not redistributed in this repo.

### What the v2 branch resolved (reviewed 2026-08-13)

Two entries that sat on this page as open questions are now closed, and one has
been superseded:

- **`ReportTableFlags::NotDocumented1/2` are documented after all.** `0x0100` and
  `0x1000` are `GuiApplyToSelectedItem` and `GuiApplyToDuplicates`, part of a
  five-flag block (`0x0100`–`0x1000`) that controls what a label defaults to
  being applied to in the GUI: selected item, parent, direct children, recursive
  children, known duplicates. They appear in both the crate's `ReportTableFlags`
  and its `AddReportTableFlags`. The proposed **flag-bit sweep is therefore
  unnecessary** — and it would have mutated report-table state to learn
  something already written down.
- **`EvObjPropType` 30 / 31 are the reference and display time zones**, not
  "likely timezone-related" — see
  [xways-getprop-reference.md](xways-getprop-reference.md) for the full
  semantics, including the `DaylightSavingsDefinition` struct and the three
  sentinel bias values. Note the crate has the two the wrong way round.

The branch also adds **compile-time API-level gating**: cargo features
`api_20_1` … `api_21_6`, each implying the one below, with a runtime check in
`XT_Init` that compares the host's version against the level the X-Tension was
built for. That feature ladder is itself a version-availability map — where the
crate marks a symbol `#[cfg(feature = "api_20_9")]`, it is asserting the symbol
arrived in 20.9. Useful as corroboration, not as a citation:

| Gated at | Symbol | Cross-check |
| --- | --- | --- |
| `api_20_3` | `XWF_GetItemCount((LPVOID)1)` — selected-item count | matches the 20.3 SR-3 announcement in [xways-api-history-19-to-21_4.md](xways-api-history-19-to-21_4.md) |
| `api_20_5` | `FileFormatConsistency` splits `2 = corrupt or irregular` into `2 = corrupt`, `3 = irregular` | confirmed on the official `XWF_GetItemType` page |
| `api_20_6` | `XWF_OutputMessage` flag `0x08` (Output window) | matches [xways-user-input-and-dialogs.md](xways-user-input-and-dialogs.md) |
| `api_20_9` | `XWF_SelectVolumeSnapshot` gains a return value (the item count); `XwfHashType::MD5Folded` | **not yet cross-checked** |
| `api_21_2` | `*_DISPLAY_OFS` (48–53); `EvObjProp` 30/31; `XT_PREPARE_TARGETFILESWITHUNKNOWNDATA` (`0x40`) | 30/31 confirmed official; the rest already recorded here |

The `XWF_SelectVolumeSnapshot` change is the one worth knowing: on **v20.9 and
later it returns the item count**, where previously it returned nothing and you
had to follow it with `XWF_GetItemCount`. Both call shapes remain valid, so this
is an efficiency note rather than a compatibility break.

**A caution on reading the crate as documentation.** Three defects surfaced in a
single pass through v2: the inverted 30/31 mapping, a `FileTypeCategory` string
map that sends `"fonts"` to `UnixLinux`, and a `MIN_VERSION` `cfg` ladder whose
top four arms lack `not(...)` guards — since `api_21_6` implies `api_21_5`
implies `api_21_4` implies `api_21_3`, selecting a 21.3+ level appears to leave
several arms simultaneously active. (Read, not compiled — verify before
reporting it upstream.) None of this makes the binding less useful as a lead
generator; all of it argues for confirming a value against the official page
before it lands in these notes as fact.

## No public Ghidra/IDA export dump

Searches for "xwforensics64.exe exports" / "X-Ways IDA database" returned nothing public. The xwf-api-rs author appears to be the de-facto RE source. A runtime export-table walk closes that gap by surfacing every `XWF_*` export at runtime.

## Open verification ideas

Research leads that would extend or confirm the findings above:

- A `XWF_GetEvObjProp` sweep over `nPropType` 0..127 covers the `100` added in 21.5 SR-5 (see [xways-getprop-reference.md](xways-getprop-reference.md)).
- A runtime export-table enumeration catches anything new in the binary that the SDK header doesn't declare. Note the SDK's own loader (`X-Tension.cpp`) resolves `XWF_Mount` / `XWF_Unmount` — two functions absent from the SDK's status spreadsheets and from these notes' coverage sources; they'd be caught by such a walk.
- ~~`XWF_AddToReportTable` flag-bit sweep including `0x0100` and `0x1000`~~ — **closed 2026-08-13.** Both bits are named on the official page and in the v2 branch (`GuiApplyToSelectedItem`, `GuiApplyToDuplicates`); no mutating sweep needed.
- Cross-check [Donovoi/X-Ways-MCP](https://github.com/Donovoi/X-Ways-MCP)'s 21.8 export inventory (`data/xwf-external-surface/`: **77 `XWF_*` exports vs 85 documented**, PE + Ghidra, exe SHA256 recorded; flags `XWF_EDB` / `XT_error` as undocumented candidates) against a runtime export-table walk. Resolve-only on the two candidates — do **not** call them (unknown semantics). See the [exemplars](exemplars.md) entry.
- ~~Cross-reference the [xways-getprop-reference.md](xways-getprop-reference.md) findings with xwf-api-rs's `EvObjPropType` enum~~ — **done 2026-08-13**; 30/31 named and VSProp 90 identified as `XWF_VSPROP_RESET`.
- ~~Cross-reference the [xways-itemtype-metadata-text.md](xways-itemtype-metadata-text.md) decoding (`GetItemType` flag bits 29/30/31)~~ — **done 2026-08-13**; the crate names all three, and bit 31 turned out to pack file-format consistency into the second-lowest return byte, correcting a misreading on that page.
- Confirm the `api_20_9` claims empirically: that `XWF_SelectVolumeSnapshot` returns the item count on v20.9+, and that hash-type `19` is MD5-folded.
- Pin down the `XT_PREPARE_*` flag values from the 21.6/21.7 forum threads (see [xtension-invocation.md](xtension-invocation.md)).

## See also

- [xways-getprop-reference.md](xways-getprop-reference.md) — canonical reference for `XWF_GetCaseProp` / `XWF_GetEvObjProp` / `XWF_GetVSProp` / `XWF_GetProp` numbers (mix of official + empirical).
- [xways-itemtype-metadata-text.md](xways-itemtype-metadata-text.md) — `XWF_GetItemType` flag bits + `XWF_GetMetadataEx` + `XWF_GetText` empirical decoding.
- [build-and-iteration-gotchas.md](build-and-iteration-gotchas.md) — `XWF_GetWindow` crash bounds, etc.
