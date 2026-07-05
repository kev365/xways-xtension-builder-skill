---
source: SourceForge SDK page, X-Ways 21.5–21.8 release notes / changelog, live API HTML (checked 2026-07-03), github.com/ThomasVogl/xwf-api-rs, the 21.9 announcement thread, 21.7 / 21.8 X-Tension behaviour notes (2026-05-13)
type: research-summary
fetched: 2026-05-03
last_updated: 2026-07-03
author: empirical research notes
---

# X-Tension API recency research (21.5 – 21.9)

State-of-the-world snapshot for the X-Tension API surface. Captures (a) whether a newer SDK exists than the 2024-05-31 header, (b) what API additions/changes the 21.5–21.8 forum threads announced beyond what the header documents, and (c) the highest-value community RE source for cross-referencing the empirical findings in this documentation set.

For the distilled behavior notes driving the 21.7/21.8 rows, see [forum-xtensions-distilled.md](forum-xtensions-distilled.md).

## TL;DR

**No newer C++ SDK zip has shipped, but the git repo HEAD is newer.** [SourceForge xwf-api files](https://sourceforge.net/projects/xwf-api/files/) still lists `XWF_API-source-2024-05-31.zip` as the latest packaged release. **However, the project's git repo at [sourceforge.net/p/xwf-api/code](https://sourceforge.net/p/xwf-api/code/) has 10 commits past that zip, through commit `c46a1bd2` (2024-07-26)** (fetched 2026-05-18; see [getting-the-sdk.md](getting-the-sdk.md) for how to obtain the SDK).

What the git HEAD adds vs the 2024-05-31 zip:

- **`XT_Init` signature change** — `void* lpReserved` is now `LicenseInfo* license`. License info lives in the fourth parameter, not in `nFlags`. Binary-compatible at the call site (no source change required to keep existing X-Tensions building / loading).
- **No other `X-Tension.h` changes** — every function pointer typedef, every `XWF_*` / `XT_*` / `IIO_*` constant identical to the 2024-05-31 zip. The 23-line diff is exclusively the `XT_Init` block.
- New `C#/` directory under active development (Björn Ganster commits 2024-06-12 → 2024-07-26) — first official C# binding from the vendor. Not yet evaluated against community alternatives (e.g. kezzier's `XTension_template`).
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
| 21.5 Preview 6 | `XWF_GetItemInformation` / `XWF_SetItemInformation` read/write the **Relevance** column. xwf-api-rs already names this `XWF_ITEM_INFO_RELEVANCE` — find the integer there. | X-Ways 21.5 release notes |
| 21.5 Beta 4 | `XT_Init` receives **dongle / BYOD license ID** — **confirmed (2026-05-18)**: delivered via the new `LicenseInfo*` fourth parameter (formerly `void* lpReserved`); see the git HEAD X-Ways SDK header ([getting-the-sdk.md](getting-the-sdk.md)). Not in `nFlags` after all. | X-Ways 21.5 release notes + git HEAD |
| 21.5 Beta 6 | `XWF_GetItemSize` defines new return codes for invalid IDs | X-Ways 21.5 release notes |
| 21.5 SR-5 | `XWF_GetEvObjProp` **`nPropType = 100`** — write side replaces an evidence object's image. Read side: test to learn what 100 returns. | X-Ways 21.5 release notes |
| 21.6 SR-6 | `XT_PREPARE_DONTOMIT` + `XT_PREPARE_TARGETFILESWITHUNKNOWNDATA` flag combo overrides UI omit setting | X-Ways 21.6 release notes |
| 21.7 Beta 2 | `XT_PREPARE_TARGETFILESWITHUNKNOWNDATA` **widened** to also force `XT_ProcessItem(Ex)` on encrypted files and files with unsupported compression (previously: metadata-only files only). | X-Ways 21.7 release notes |
| 21.7 Beta 4 | Files inside corrupt / incomplete archives are now opened with a **size-0 (useless) handle** so `XT_ProcessItemEx` is called on them. Implementations must check size before reading. | X-Ways 21.7 release notes |
| 21.8 | `XWF_OpenItem()` flag **`0x8000`** — embed child objects if the item is an e-mail message extracted by X-Ways in `.eml` format, mirroring the GUI "Copy/Recovery" behaviour. Per the live [XWF_functions.html](https://www.x-ways.net/forensics/x-tensions/XWF_functions.html) (2026-07-03): the forum thread's user code used `0x2000`, which is **not** in the official flag list — see [xways-openitem-flags.md](xways-openitem-flags.md). *Caveat — open issue:* `XWF_GetProp(h, 1, 0)` and `XWF_GetSize(h)` may still return the bare-EML size; measure by reading to EOF. | X-Ways 21.8 release notes + live HTML (2026-07-03) |
| 21.8 (rename backported to 21.4 SR-11 / 21.5 SR-13 / 21.6 SR-8 / 21.7 SR-4) | The "label-removal counterpart" is `XWF_Label(LONG nItemID, LPWSTR lpLabelName, DWORD nFlags)` — the rename of `XWF_AddToReportTable` — with removal via `nFlags` `0x80000000` (v21.8+). `XWF_GetLabels(LONG nItemID, LPWSTR lpBuffer, DWORD nBufLenAndMatchType)` likewise renames `XWF_GetReportTableAssocs`. Both old names remain callable but deprecated — see [xways-reading-events-and-items.md](xways-reading-events-and-items.md). | Live [XWF_functions.html](https://www.x-ways.net/forensics/x-tensions/XWF_functions.html) (2026-07-03) |
| 21.9 Preview 1 | **Custom numeric `nEvtType`s become filterable.** The Events filter dialog now lists event types other than the internally defined ones if such events were added by an X-Tension — pick values ≥ 25000 (Category shows "Other") and ≤ 65535. No new/changed `XWF_*`/`XT_*` functions announced through 21.9 Preview 3, and the live [XWF_functions.html](https://www.x-ways.net/forensics/x-tensions/XWF_functions.html) carries no v21.9 notes yet (checked 2026-07-03). See [xways-events-api.md](xways-events-api.md). | 21.9 announcement thread ([messages/1/5547](https://www.x-ways.net/winhex/forum/messages/1/5547.html), Stefan post 2026-06-09) |

Also worth re-confirming (older but referenced in threads):

- **21.4 Beta 3** added `XWF_VSPROP_RESET` (programmatically take a new VS). The SDK header does not define a `_RESET` value (`X-Tension.h:177-181` lists 10/20/21/25/26).

### Bugs / doc-vs-reality discrepancies (not yet fixed at time of writing)

| Symptom | Status | Source |
| --- | --- | --- |
| **`XT_PREPARE_TARGETZEROBYTEFILES` has no effect on `XT_ProcessItemEx()`** despite documentation. Zero-byte files are only delivered to the older `XT_ProcessItem()`. Workaround: register both callbacks (routed through one deduping collector — see [item-collection](conventions/item-collection.md)). | Acknowledged by X-Ways; a fix is planned for all future releases — **no specific version stated**. **Still present in 21.8** (verified 2026-06-27 with an item-open probe: the non-`Ex` callback saw exactly one more item — the lone 0-byte file). | X-Ways developer guidance + probe |

## Community RE — `ThomasVogl/xwf-api-rs` is the gold mine

[github.com/ThomasVogl/xwf-api-rs](https://github.com/ThomasVogl/xwf-api-rs) — Rust binding, **v1.0.1 released 2025-05-17**, last commit 2025-07-21, branches `main`/`develop`/`v2-develop`. The function inventory matches the official SDK exports (no extra entry points), but the **enum / bitflag definitions include reverse-engineered values the SDK header does not document**:

| RE constant | Value | Where used |
| --- | --- | --- |
| `ReportTableFlags::NotDocumented1` | `0x0100` | `XWF_AddToReportTable` `nFlags` — observed live, not in docs |
| `ReportTableFlags::NotDocumented2` | `0x1000` | `XWF_AddToReportTable` `nFlags` — observed live, not in docs |
| `EvObjPropType` enum | 0..50 named | Cross-check against the property-number sweep in [xways-getprop-reference.md](xways-getprop-reference.md) |
| `XwfItemInfoTypes` `*_DISPLAY_OFS` family | 48..53 | Six properties added in 21.2 — check the SDK header carries all six |
| `VsPropType::SetHasChanged` | `30` | A VS property the SDK header doesn't list |

The community xwf-api-rs binding is a useful local cross-reference (with its license attribution preserved); it is not redistributed in this repo.

## No public Ghidra/IDA export dump

Searches for "xwforensics64.exe exports" / "X-Ways IDA database" returned nothing public. The xwf-api-rs author appears to be the de-facto RE source. A runtime export-table walk closes that gap by surfacing every `XWF_*` export at runtime.

## Open verification ideas

Research leads that would extend or confirm the findings above:

- A `XWF_GetEvObjProp` sweep over `nPropType` 0..127 covers the `100` added in 21.5 SR-5 (see [xways-getprop-reference.md](xways-getprop-reference.md)).
- A runtime export-table enumeration catches anything new in the binary that the SDK header doesn't declare.
- `XWF_AddToReportTable` flag-bit sweep including `0x0100` and `0x1000` from xwf-api-rs. Caveat: this **mutates** report-table state, so it would only be appropriate as an opt-in step, not a default sweep.
- Cross-check [Donovoi/X-Ways-MCP](https://github.com/Donovoi/X-Ways-MCP)'s 21.8 export inventory (`data/xwf-external-surface/`: **77 `XWF_*` exports vs 85 documented**, PE + Ghidra, exe SHA256 recorded; flags `XWF_EDB` / `XT_error` as undocumented candidates) against a runtime export-table walk. Resolve-only on the two candidates — do **not** call them (unknown semantics). See the [exemplars](exemplars.md) entry.
- Cross-reference the [xways-getprop-reference.md](xways-getprop-reference.md) findings with xwf-api-rs's `EvObjPropType` enum to name the empirical numbers.
- Cross-reference the [xways-itemtype-metadata-text.md](xways-itemtype-metadata-text.md) decoding (`GetItemType` flag bits 29/30/31) — check whether xwf-api-rs has constants for them.
- Pin down the `XT_PREPARE_*` flag values from the 21.6/21.7 forum threads (see [xtension-invocation.md](xtension-invocation.md)).

## See also

- [xways-getprop-reference.md](xways-getprop-reference.md) — canonical reference for `XWF_GetCaseProp` / `XWF_GetEvObjProp` / `XWF_GetVSProp` / `XWF_GetProp` numbers (mix of official + empirical).
- [xways-itemtype-metadata-text.md](xways-itemtype-metadata-text.md) — `XWF_GetItemType` flag bits + `XWF_GetMetadataEx` + `XWF_GetText` empirical decoding.
- [build-and-iteration-gotchas.md](build-and-iteration-gotchas.md) — `XWF_GetWindow` crash bounds, etc.
