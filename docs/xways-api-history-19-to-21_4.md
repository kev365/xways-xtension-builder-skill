---
source: x-ways.net forum announcement threads (per-version) — see Source URL column
type: research-summary
fetched: 2026-05-03
last_updated: 2026-05-03
author: empirical research notes
---

# X-Tension API history — X-Ways Forensics 19.0 through 21.4

Companion to [`xways-api-recency-research.md`](xways-api-recency-research.md), which covers 21.5–21.7. This file extends the timeline backwards: every X-Tension surface-area mention (new function, new flag, new property number, behaviour change, documentation update) announced in the public release-notes threads from v19.0 through v21.4.

The 2024-05-31 SDK header lands roughly mid-21.3, so most additions in this file are present in the header but not always in the right context. A few late-21.3 / 21.4 additions post-date the header (e.g. `XWF_VSPROP_RESET` in 21.4 Beta 3, expanded `XWF_GetReportTableAssocs()` semantics in 21.3 Beta 3) — these are the same gap surfaced in [`xways-api-recency-research.md`](xways-api-recency-research.md).

## Methodology — coverage and sources

For each version 19.0..21.4, the corresponding public announcement thread on `x-ways.net/winhex/forum/messages/1/<NNNN>.html` was fetched and scanned for occurrences of "X-Tension", "XWF_", "XT_", and "API". Thread numbers were located via Google `site:x-ways.net forum "<version>"` queries. Every paragraph mentioning the X-Tension surface area was extracted with its version-channel header and post date. Non-API content (UI tweaks, file-system parsers, indexing, OCR, gallery, etc.) was filtered out. Where a single thread had multiple X-Tension entries across different channels, each one is its own row. Versions that announced zero X-Tension changes get one "(no X-Tension changes announced)" row so the timeline is gap-free.

## Forum thread index (one URL per version)

| Version | Thread URL |
|---|---|
| 19.0 | <https://www.x-ways.net/winhex/forum/messages/1/4812.html> |
| 19.1 | <https://www.x-ways.net/winhex/forum/messages/1/4856.html> |
| 19.2 | <https://www.x-ways.net/winhex/forum/messages/1/4889.html> |
| 19.3 | <https://www.x-ways.net/winhex/forum/messages/1/4918.html> |
| 19.4 | <https://www.x-ways.net/winhex/forum/messages/1/4931.html> |
| 19.5 | <https://www.x-ways.net/winhex/forum/messages/1/4955.html> |
| 19.6 | <https://www.x-ways.net/winhex/forum/messages/1/4981.html> |
| 19.7 | <https://www.x-ways.net/winhex/forum/messages/1/5028.html> |
| 19.8 | <https://www.x-ways.net/winhex/forum/messages/1/5093.html> |
| 19.9 | <https://www.x-ways.net/winhex/forum/messages/1/5158.html> |
| 20.0 | <https://www.x-ways.net/winhex/forum/messages/1/5214.html> |
| 20.1 | <https://www.x-ways.net/winhex/forum/messages/1/5263.html> |
| 20.2 | <https://www.x-ways.net/winhex/forum/messages/1/5296.html> |
| 20.3 | <https://www.x-ways.net/winhex/forum/messages/1/5308.html> |
| 20.4 | <https://www.x-ways.net/winhex/forum/messages/1/5337.html> |
| 20.5 | <https://www.x-ways.net/winhex/forum/messages/1/5360.html> |
| 20.6 | <https://www.x-ways.net/winhex/forum/messages/1/5379.html> |
| 20.7 | <https://www.x-ways.net/winhex/forum/messages/1/5390.html> |
| 20.8 | <https://www.x-ways.net/winhex/forum/messages/1/5408.html> |
| 20.9 | <https://www.x-ways.net/winhex/forum/messages/1/5430.html> |
| 21.0 | <https://www.x-ways.net/winhex/forum/messages/1/5446.html> |
| 21.1 | <https://www.x-ways.net/winhex/forum/messages/1/5459.html> |
| 21.2 | <https://www.x-ways.net/winhex/forum/messages/1/5471.html> |
| 21.3 | <https://www.x-ways.net/winhex/forum/messages/1/5483.html> |
| 21.4 | <https://www.x-ways.net/winhex/forum/messages/1/5492.html> |

## Per-version X-Tension API additions / changes

| Version | Channel | Date | API addition / change | Source URL |
|---|---|---|---|---|
| 19.0 | Preview 4 | 2016-07-31 | "X-Tension API: Redefined flag to include comments about files in evidence file containers." | <https://www.x-ways.net/winhex/forum/messages/1/4812.html> |
| 19.0 | Beta 4 | 2016-09-26 | File-wise processing via `XT_ProcessItem` / `XT_ProcessItemEx` is parallelised when the X-Tension identifies itself as thread-safe. (Origin of the thread-safe self-identification flag in `XT_Init` return value.) | <https://www.x-ways.net/winhex/forum/messages/1/4812.html> |
| 19.0 | Beta 6 | 2016-10-11 | New X-Tensions API function: `XWF_SetHashValue`. | <https://www.x-ways.net/winhex/forum/messages/1/4812.html> |
| 19.0 | SR-11 | 2017-01-01 | `XWF_GetEvObjProp` gains two new evidence-object-ID property numbers: `nPropType 3` and `nPropType 4`. | <https://www.x-ways.net/winhex/forum/messages/1/4812.html> |
| 19.1 | Preview 5 | 2016-12-04 | `XWF_CreateFile` gains a new flag that creates a file in the volume snapshot from a caller-supplied data buffer. | <https://www.x-ways.net/winhex/forum/messages/1/4856.html> |
| 19.1 | SR-7 | 2017-03-27 | Fix: exception in `XWF_CreateEvObj` when the case was still empty. | <https://www.x-ways.net/winhex/forum/messages/1/4856.html> |
| 19.2 | Preview 3 | 2017-02-21 | New Disk I/O X-Tension class: tensions can intercept I/O at the disk level via a new `XT_FileIO` exported entry point (file-level I/O interception). Documented under `api.html#diskio`. | <https://www.x-ways.net/winhex/forum/messages/1/4889.html> |
| 19.2 | Preview 3 | 2017-02-21 | New `XWF_FindItem1` API function for finding items conveniently. | <https://www.x-ways.net/winhex/forum/messages/1/4889.html> |
| 19.3 | Preview 1 | 2017-05-02 | `XWF_GetItemType` extended to report detected file-format consistency. | <https://www.x-ways.net/winhex/forum/messages/1/4918.html> |
| 19.3 | Preview 1 | 2017-05-02 | `XWF_ShouldStop` no longer only checks for user abort — semantics extended (full text was truncated in fetch but flagged as a behaviour-change). | <https://www.x-ways.net/winhex/forum/messages/1/4918.html> |
| 19.3 | Beta (mid-May) | 2017-05-19 | New context command "Run X-Tension on selected files" (command code 9927). `XWF_CreateEvObj` can now add multiple image files to the case in a single call. | <https://www.x-ways.net/winhex/forum/messages/1/4918.html> |
| 19.3 | Beta 4 | 2017-06-09 | New API function `XWF_GetHashSetAssocs` — returns name(s) of hash set(s) that the specified file is associated with. | <https://www.x-ways.net/winhex/forum/messages/1/4918.html> |
| 19.3 | SR-3 | 2017-07-10 | `XWF_GetItemInformation` with `XWF_ITEM_INFO_DELETION` now returns 5 (was 1) for carved files. (Return-value semantic change.) | <https://www.x-ways.net/winhex/forum/messages/1/4918.html> |
| 19.4 | Preview 1 | 2017-07-10 | `XWF_OutputMessage` gains a flag that directs the message to the case log instead of the Messages window. | <https://www.x-ways.net/winhex/forum/messages/1/4931.html> |
| 19.4 | Beta 2 | 2017-08-29 | Fix: `XWF_CTR_OPEN` flag of `XWF_CreateContainer` did not work — fixed. | <https://www.x-ways.net/winhex/forum/messages/1/4931.html> |
| 19.5 | Preview 2 | 2017-10-04 | Ability to run X-Tensions as part of a volume-snapshot refinement triggered from the command line. | <https://www.x-ways.net/winhex/forum/messages/1/4955.html> |
| 19.5 | Preview 3 | 2017-10-11 | New **Image I/O API** (separate from the X-Tension API) — adds support for additional physical-disk image formats via `Image*.dll` plugins. Documented at `forensics/x-tensions/Image_IO_API.html`. | <https://www.x-ways.net/winhex/forum/messages/1/4955.html> |
| 19.5 | Preview 3 | 2017-10-11 | "X-Tensions API: C++ function definitions and C++ sample projects updated." (header sync) | <https://www.x-ways.net/winhex/forum/messages/1/4955.html> |
| 19.5 | Preview 4 | 2017-10-15 | `XWF_GetItemInformation` `XWF_ITEM_INFO_ATTR` is now documented (was previously undocumented). | <https://www.x-ways.net/winhex/forum/messages/1/4955.html> |
| 19.6 | SR-4 | 2018-04-26 | Convention: X-Tensions writing to the Metadata column should mark their entries with `[XT]` so the Details mode displays them. (Affects formatting expectations for `XWF_AddExtractedMetadata`-style output, no API surface change.) | <https://www.x-ways.net/winhex/forum/messages/1/4981.html> |
| 19.6 | SR-7 | 2018-08-14 | Fix: `XWF_CreateEvObj` returned a handle to a wrong evidence object when called for evidence objects of types 0, 3, and 4. | <https://www.x-ways.net/winhex/forum/messages/1/4981.html> |
| 19.7 | Preview 3 | 2018-05-17 | `XWF_GetHashValue` extended: ability to retrieve primary and secondary hash values in a single call. | <https://www.x-ways.net/winhex/forum/messages/1/5028.html> |
| 19.7 | Beta 3 | 2018-07-11 | `XWF_GetCaseProp` now returns the case **creation timestamp** and **internal case ID**. `XWF_GetVSProp` can now define the hash types of a volume snapshot. (New property numbers on both functions — see `XWF_VSPROP_SET_HASHTYPE1/2`.) | <https://www.x-ways.net/winhex/forum/messages/1/5028.html> |
| 19.7 | Final | 2018-08-19 | Stubborn C# X-Tension DLLs: option to prompt the user whether to fully unload them after execution. (Loader behaviour, no API surface.) | <https://www.x-ways.net/winhex/forum/messages/1/5028.html> |
| 19.8 | — | — | (no X-Tension changes announced) | <https://www.x-ways.net/winhex/forum/messages/1/5093.html> |
| 19.9 | Beta 1 | 2019-09-25 | `XWF_OpenItem` (used with `XWF_Read`) can now retrieve a **PDF representation** of an item. `XWF_GetItemName` can now retrieve the **alternative name** of a file. | <https://www.x-ways.net/winhex/forum/messages/1/5158.html> |
| 19.9 | SR-7 | 2020-05-19 | New API functions `XWF_GetWindow()` and `XWF_GetProp()`. New `nPropType 50` for `XWF_GetEvObjProp()`. | <https://www.x-ways.net/winhex/forum/messages/1/5158.html> |
| 19.9 | SR-10 | 2020-08-17 | Fix: `XWF_GetVSProp(XWF_VSPROP_SET_HASHTYPE1*)` together with `XWF_SetHashValue()` did not work in volume snapshots — fixed. | <https://www.x-ways.net/winhex/forum/messages/1/5158.html> |
| 20.0 | Preview 3 | 2020-03-31 | `XWF_OpenItem` gains a new flag to open only the **plain text** of files. | <https://www.x-ways.net/winhex/forum/messages/1/5214.html> |
| 20.0 | Beta 5 | 2020-06-28 | New API function `XWF_ManageSearchTerm()`. | <https://www.x-ways.net/winhex/forum/messages/1/5214.html> |
| 20.0 | Beta 5 | 2020-06-28 | `XWF_Search()` can now specify the alphabet(s) that define word boundaries. | <https://www.x-ways.net/winhex/forum/messages/1/5214.html> |
| 20.0 | Beta 8 | 2020-08-06 | "X-Tensions API: C++ function definitions and C++ sample projects updated." (header sync) | <https://www.x-ways.net/winhex/forum/messages/1/5214.html> |
| 20.1 | Preview 6 | 2020-09-28 | Command-line interface gains the `XT:<path>` command to invoke an X-Tension from the CLI. | <https://www.x-ways.net/winhex/forum/messages/1/5263.html> |
| 20.1 | SR-3 | 2021-01-13 | Fix: `XWF_Read()` returned 0 (instead of the actual byte count) after reading 2–4 GB of data — fixed. | <https://www.x-ways.net/winhex/forum/messages/1/5263.html> |
| 20.2 | SR-2 | 2021-04-27 | Documentation of `XT_ProcessSearchHit()` updated and corrected. (Doc-only.) | <https://www.x-ways.net/winhex/forum/messages/1/5296.html> |
| 20.3 | Preview 2 | 2021-04-16 | New API functions `XWF_PrepareTextAccess()` and `XWF_GetText()`. | <https://www.x-ways.net/winhex/forum/messages/1/5308.html> |
| 20.3 | Beta 2b | 2021-06-14 | New API functions `XWF_GetColumnTitle` and `XWF_GetCellText` — retrieve directory-browser cells as text. | <https://www.x-ways.net/winhex/forum/messages/1/5308.html> |
| 20.3 | Beta 3 | 2021-07-01 | `XWF_ManageSearchTerm()` can now rename search terms (e.g. for a friendlier display name). | <https://www.x-ways.net/winhex/forum/messages/1/5308.html> |
| 20.3 | SR-3 | 2021-08-23 | `XWF_GetItemCount()` gains additional capabilities (semantics extended; full text was abbreviated in fetch). | <https://www.x-ways.net/winhex/forum/messages/1/5308.html> |
| 20.3 | SR-5 | 2021-09-26 | Fix: `XWF_GetCellText()` did not work for all columns — fixed. | <https://www.x-ways.net/winhex/forum/messages/1/5308.html> |
| 20.4 | — | — | (no X-Tension changes announced) | <https://www.x-ways.net/winhex/forum/messages/1/5337.html> |
| 20.5 | Preview 1 | 2022-01-11 | Applying X-Tensions to files in selected directories is now optional (UI/invocation behaviour). | <https://www.x-ways.net/winhex/forum/messages/1/5360.html> |
| 20.5 | Beta 1 | 2022-03-24 | New Metadata-column convention: entries originating from an X-Tension are tagged `[Xtn]` (was `[XT]` per 19.6 SR-4). | <https://www.x-ways.net/winhex/forum/messages/1/5360.html> |
| 20.6 | Beta 4 | 2022-07-17 | `XWF_OutputMessage()` accepts new flag `0x8` to direct output to the Output window. | <https://www.x-ways.net/winhex/forum/messages/1/5379.html> |
| 20.6 | SR-4 | 2022-10-11 | `XWF_AddComment()` can now also **remove** existing comments from files. (Behaviour extension.) | <https://www.x-ways.net/winhex/forum/messages/1/5379.html> |
| 20.6 | SR-5 | 2022-11-03 | `XWF_GetWindow()` improved — can now also target the active data window. | <https://www.x-ways.net/winhex/forum/messages/1/5379.html> |
| 20.7 | — | — | (no X-Tension changes announced) | <https://www.x-ways.net/winhex/forum/messages/1/5390.html> |
| 20.8 | Beta 3 | 2023-04-18 | X-Tension loader now (by default) loads sibling DLLs from the X-Tension's own directory. New optional opt-out checkbox. (Loader behaviour change — affects DLL placement assumptions.) | <https://www.x-ways.net/winhex/forum/messages/1/5408.html> |
| 20.9 | Beta 7 | 2023-07-23 | `XWF_SelectVolumeSnapshot()` now has a return value indicating success or failure. | <https://www.x-ways.net/winhex/forum/messages/1/5430.html> |
| 21.0 | SR-3 | 2024-02-07 | Fix: `XWF_GetItemName()` did not work correctly when retrieving alternative filenames in v20.9 / v21.0 — fixed. | <https://www.x-ways.net/winhex/forum/messages/1/5446.html> |
| 21.1 | Preview 3 | 2024-02-12 | When X-Tensions add directories to a case as evidence objects, they can choose how X-Ways treats them. (Flag/behaviour on `XWF_CreateEvObj`-family — full text abbreviated in fetch.) | <https://www.x-ways.net/winhex/forum/messages/1/5459.html> |
| 21.1 | Beta 2 | 2024-03-15 | Two new API functions: `XWF_Mount` and `XWF_Unmount` — mount the volume snapshot as a drive letter so external tools can read items via filesystem path. | <https://www.x-ways.net/winhex/forum/messages/1/5459.html> |
| 21.1 | Beta 3 | 2024-03-18 | (Out of scope for the X-Tension C-API surface — `Programs.txt` config feature for piping parameters to external editors. See "Verbatim recoveries" below.) | <https://www.x-ways.net/winhex/forum/messages/1/5459.html> |
| 21.2 | Beta 6 | 2024-07-03 | `XWF_GetEvObjProp` gains two more property types (numbers not stated in announcement; per follow-up search these are time-zone-related, `30` and `31`). | <https://www.x-ways.net/winhex/forum/messages/1/5471.html> |
| 21.2 | Beta 6 | 2024-07-03 | `XWF_GetItemInformation` adds the `XWF_ITEM_INFO_*_DISPLAY_OFS` family (six values per `xwf-api-rs` cross-reference, numbers 48..53). | <https://www.x-ways.net/winhex/forum/messages/1/5471.html> |
| 21.2 | SR-5 | 2024-09-05 | New flag `XT_PREPARE_TARGETFILESWITHUNKNOWNDATA` returnable from `XT_Prepare` — `XT_ProcessItem(Ex)` is then called even for files of which only metadata are known. | <https://www.x-ways.net/winhex/forum/messages/1/5471.html> |
| 21.2 | SR-5 | 2024-09-05 | `XWF_GetVSProp()` accepts new property `XWF_VSPROP_SET_HASCHANGED` (value `30`) — marks the volume snapshot as having changes. | <https://www.x-ways.net/winhex/forum/messages/1/5471.html> |
| 21.2 | SR-9 | 2024-10-07 | `XWF_GetFileCount()` now guarantees a more up-to-date result. (Behaviour change; threading-related.) | <https://www.x-ways.net/winhex/forum/messages/1/5471.html> |
| 21.3 | Preview 3 | 2024-09-05 | New return-value flag `0x02` from `XT_Finalize()` — directs X-Ways to save the volume snapshot of the specified volume. | <https://www.x-ways.net/winhex/forum/messages/1/5483.html> |
| 21.3 | Preview 4 | 2024-09-18 | List of `XT_Init` possible return values extended for X-Tensions that understand the **revised meaning of the `nOpType` parameter**. | <https://www.x-ways.net/winhex/forum/messages/1/5483.html> |
| 21.3 | Preview 4 | 2024-09-18 | `XWF_SetItemSize`, `XWF_SetItemOfs`, `XWF_SetItemParent`, `XWF_SetItemType` now have a return value indicating success or failure. | <https://www.x-ways.net/winhex/forum/messages/1/5483.html> |
| 21.3 | Beta 3 | 2024-10-07 | Meaning and functionality of the **last parameter** of `XWF_GetReportTableAssocs()` was extended. | <https://www.x-ways.net/winhex/forum/messages/1/5483.html> |
| 21.3 | Beta 3 | 2024-10-07 | Documentation of `XWF_GetReportTableAssocs()` and the flag values supported by `XWF_AddToReportTable()` was updated. | <https://www.x-ways.net/winhex/forum/messages/1/5483.html> |
| 21.3 | SR-3 | 2024-11-08 | Fix: `XWF_GetVSProp(XWF_VSPROP_SET_HASHTYPE1)` / `_HASHTYPE2` could not set a new hash type if no hash type was defined yet — fixed. | <https://www.x-ways.net/winhex/forum/messages/1/5483.html> |
| 21.4 | Beta 3 | 2025-01-28 | `XWF_GetVSProp` supports a new operation: `XWF_VSPROP_RESET` — programmatically takes a new volume snapshot. | <https://www.x-ways.net/winhex/forum/messages/1/5492.html> |
| 21.4 | Beta 6 | 2025-02-10 | An X-Tension can now set a file's "ignorable" flag via `XWF_SetItemInformation()` from an early `XT_ProcessItem()` call. | <https://www.x-ways.net/winhex/forum/messages/1/5492.html> |
| 21.4 | Beta 6 | 2025-02-10 | More flags now defined for `XWF_AddToReportTable()`. (Numbers not stated in announcement; cross-reference `xwf-api-rs` `ReportTableFlags::NotDocumented1/2` for `0x0100` / `0x1000`.) | <https://www.x-ways.net/winhex/forum/messages/1/5492.html> |
| 21.4 | SR-5 | 2025-05-07 | `hVolume` handle passed to `XT_Prepare()` and `XT_Finalize()` is now `0` when the X-Tension is applied to the **Case Root window**. (Behaviour change — guard against `NULL hVolume`.) | <https://www.x-ways.net/winhex/forum/messages/1/5492.html> |

## Cross-references

- For 21.5–21.8 additions, see [`xways-api-recency-research.md`](xways-api-recency-research.md).
- The 19.7 `XWF_GetCaseProp` / `XWF_GetVSProp` extensions and the 19.9 `XWF_GetProp` / `XWF_GetWindow` additions are the origin of the property-number sweeps catalogued in [`xways-getprop-reference.md`](xways-getprop-reference.md).
- The 20.8 Beta 3 loader change ("X-Tensions are loaded so that sibling DLLs in the X-Tension's own directory resolve") is the historical justification for the deployment convention documented in [`xtension-invocation.md`](xtension-invocation.md) "DLL placement and sidecar files" section, and in `CLAUDE.md` "Deployment convention".
- `xwf-api-rs` enum values referenced above:
  - `EvObjPropType` enum — covers the 19.0 SR-11 (3, 4), 19.9 SR-7 (50), 21.2 Beta 6 (30, 31), 21.5 SR-5 (100) additions.
  - `XwfItemInfoTypes::*_DISPLAY_OFS` (48..53) — 21.2 Beta 6.
  - `VsPropType::SetHasChanged` (30) — 21.2 SR-5.
  - `ReportTableFlags::NotDocumented1` (0x0100), `NotDocumented2` (0x1000) — likely the unnamed flags from 21.4 Beta 6.

## Caveats

- Some announcement paragraphs were abbreviated during retrieval (noted "full text abbreviated in fetch" in the table). The four most-impacted entries are now recovered verbatim in the next section.
- Where a single SR fixes a regression that originated in an earlier SR of the same version, only the fix is listed — earlier broken state is implicit.
- Versions 19.8, 20.4, 20.7 contain no announced X-Tension changes. Any silent header changes during those release cycles would not appear in this table.
- A few older SDK-header sync events ("C++ function definitions and C++ sample projects updated" in 19.5 P3 and 20.0 B8) are recorded as "header sync" rows — they imply that other versions also shipped header updates without separate announcements.

## Verbatim recoveries (2026-05-03)

Targeted re-fetch of the four entries that the original sweep summarised. Quotes are verbatim from the forum threads.

### 19.3 Preview 1 — `XWF_ShouldStop` semantics extension

> "X-Tensions API: The XWF_ShouldStop function now does not only check whether the user wishes to abort lengthy operations, it also helps to keep the GUI responsive when the X-Tension is not executed in a separate worker thread. Calling this function regularly will process mouse and keyboard input, allow the windows to redraw etc. The user realizes that the application is not hanging, and potential attempts of the user to close the progress indicator window will be noticed. Even if you ignore the result of this function call during lengthy operations conducted by your X-Tension, you are doing something good already by making the calls in the first place."

Preview 1 · 2017-05-02 · [forum thread](https://www.x-ways.net/winhex/forum/messages/1/4918.html)

**Practical implication:** in any single-threaded `XT_Prepare` doing per-item work, call `XWF_ShouldStop()` once per N items even if you ignore the return — it pumps the message queue and keeps the X-Ways UI responsive.

### 21.1 Preview 3 — directory-as-evidence-object timestamp control

> "When X-Tensions add directories to a case as an evidence object, they can choose to have X-Ways Forensics ignore any of the four regular timestamps of NTFS."

Preview 3 · 2024-02-12 · [forum thread](https://www.x-ways.net/winhex/forum/messages/1/5459.html)

**Practical implication:** `XWF_CreateEvObj(nType=3, ...)` (directory-typed EO — e.g. attaching a tool's output directory as evidence) now accepts flags via `pReserved` to suppress NTFS timestamp inheritance. Numeric flag values not stated in the announcement — re-test or check live API HTML before relying.

### 21.1 Beta 3 — `Programs.txt` parameter passing (NOT an X-Tension C-API change)

> "If you need to call external programs from within X-Ways Forensics with certain parameters in addition to the name of the file that they should open, you can now specify those parameters in the same line of Programs.txt, delimited from the path of the executable file with a tab. The name of the file will be appended at the end, after your own parameters, unless you include the placeholder %1 anywhere in your list of parameters. That placeholder will be replaced with the filename."

Beta 3 · 2024-03-18 · [forum thread](https://www.x-ways.net/winhex/forum/messages/1/5459.html)

**Out of scope:** this is an X-Ways UI/config feature, not a C-API addition. Marked as such in the table above.

**Which dialog field does Programs.txt populate?** Empirically: the **Custom viewer programs** list at the bottom-right of Tools → Options → File Viewing (the multi-line list, edited via the pencil icon next to it — the icon opens `Programs.txt` directly in a text editor). `Programs.txt` does **not** populate the dedicated "Text editor", "HTML viewer", "MPlayer", "Preferred video player", "Tesseract OCR", or "Excire Forensics" fields — those are stored in a `.dlg` saved-dialog-state file alongside `WinHex.cfg`, are only read at X-Ways startup, and have no documented per-field write API. The top half of the announcement quote ("call external programs … with certain parameters") generalises across "Custom viewer" entries; "external editors" in the announcement was X-Ways' shorthand for that list, not the dedicated Text-editor slot.

**File format facts** (verified against `Programs.txt` in the X-Ways install root):

- Encoding: **UTF-16 LE with BOM (`0xFF 0xFE`)**, CRLF line endings.
- One line per Custom viewer entry: `<absolute exe path>\t[params with %1 placeholder]`.
- Idempotent on re-write: keyed on the absolute exe path (case-insensitive on Windows). Edits take effect at next X-Ways startup.

**Practical implication:** an X-Tension that wants to populate Custom viewer entries can write `Programs.txt` directly (atomic-rename via `<path>.tmp` + `MoveFileExW(MOVEFILE_REPLACE_EXISTING)`). For the other File Viewing fields, the only safe path is to surface the analyst-pasteable absolute path so they can paste it into the dialog manually.

**Programs.txt is read only at X-Ways startup.** Edits made while X-Ways is running do not appear in the right-click → View → External programs menu or the File Viewing dialog's Custom viewer programs list until the next launch (confirmed empirically, 2026-05-10). An X-Tension that writes the file must tell the analyst to restart X-Ways before the new entries appear; the dialog state is in-memory and not re-read on dialog open.

**Invocation semantics for Custom viewer programs.**

- **Per-file, never batched.** Selecting N items in the directory browser and clicking a Programs.txt entry invokes the tool N separate times, once per selected file. There is no way via Programs.txt to receive all selected items in one invocation. For batch tooling (run once over many files, get unified output), use an X-Tension with `XT_ACTION_DBC` instead — the canonical pattern is export selected items to a temp dir → run the CLI tool once over the dir → ingest the unified CSV → cleanup (see the `wrapper` template).
- **Child cwd inherits from X-Ways.** When X-Ways spawns the external program, the child's working directory is whatever X-Ways' own cwd happens to be — typically the install directory (`<install>\`). CLI tools that write output to "current directory" (e.g. `EvtxECmd … --csv .`) will dump their output there. Tools should either be given an absolute output path, or be wrapped in a `.bat` shim that resolves a sensible location.
- **Line text is literal — no environment variable expansion, no path resolution.** The whole Programs.txt line is passed to `CreateProcess` as-is. `%USERPROFILE%`, `%TEMP%`, etc. are NOT expanded by Programs.txt itself. To use env vars, point Programs.txt at a `.bat` wrapper and do the expansion inside the shell.
- **Menu label = full Programs.txt line.** X-Ways renders the entire `<basename> <params>` (or just `<basename>` if no tab) as the right-click menu label. There is no separate "display name" field. To present a clean label while still passing real params, write a wrapper `.bat` and let Programs.txt point at the `.bat` (basename becomes the menu label; params live in the script).

### 20.3 SR-3 — `XWF_GetItemCount` extension

> "The X-Tension API function XWF_GetItemCount() now has additional capabilities."

SR-3 · 2021-08-23 · [forum thread](https://www.x-ways.net/winhex/forum/messages/1/5308.html)

**Forum entry is genuinely terse** — the concrete capability detail lives in the live API HTML rather than the release notes. To get the actual semantics, fetch [XWF_functions.html](https://www.x-ways.net/forensics/x-tensions/XWF_functions.html) and look up `XWF_GetItemCount` directly. (No verbatim recovery beyond the one sentence is possible from this thread.)
