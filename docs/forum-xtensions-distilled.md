---
type: empirical-finding
last_updated: 2026-06-06
author: project
---

# X-Tension behavior notes (X-Ways 21.7–21.8)

> Distilled notes on X-Tension runtime behavior in X-Ways 21.7–21.8. Verify
> specifics against the official API page / live `XWF_functions.html`.

---

## XT_ProcessItem(Ex) — which items are actually delivered

This is the most consequential finding for any X-Tension that iterates items. The documented `XT_PREPARE_TARGET*` flag semantics diverged from runtime behaviour in several ways, and several fixes shipped across v21.7 betas.

**Bugs / doc-mismatches confirmed by X-Ways:**

1. `XT_PREPARE_TARGETZEROBYTEFILES` had **no effect on `XT_ProcessItemEx()`** despite documentation. Zero-byte files were only delivered to `XT_ProcessItem()`. A fix is planned for all future releases.
2. `XT_PREPARE_TARGETFILESWITHUNKNOWNDATA` was scoped narrower than docs imply — pre-v21.7 Beta 2 it only targeted **metadata-only files**. Encrypted files and files with unsupported compression were *not* included. Fixed in v21.7 Beta 2.
3. Files inside corrupt/incomplete archives weren't passed to `XT_ProcessItemEx()` at all. Fixed in v21.7 Beta 4 — such items are now opened with a (useless) size-0 handle so the callback fires.

**Practical rules of thumb:**

- If you want every item, register `XT_ProcessItem()` as well as `XT_ProcessItemEx()`. The zero-byte and unopenable cases get delivered there even on older builds, and the handle in `XT_ProcessItemEx()` would be useless for them anyway.
- From v21.7 Beta 2 onward there are no further documented exceptions to `XT_PREPARE_TARGET*FILES*` coverage — every item should be reachable.
- Test against an NTFS shake-out corpus that includes zero-byte, metadata-only, encrypted, and corrupt-archive items.

---

## XWF_AddToReportTable — label removal

Until v21.8 Beta 5 there was **no API to remove a report-table label** from an item — `XWF_AddToReportTable` had no counterpart. A removal function was added in v21.8 Beta 5 (2026-05-08).

> The removal function is `XWF_Label(LONG nItemID, LPWSTR lpLabelName, DWORD nFlags)` — the rename of `XWF_AddToReportTable`, backported to the 21.4–21.7 SRs — with removal via `nFlags` `0x80000000` (v21.8+; confirmed against the live XWF_functions.html, 2026-07-03). See [xways-reading-events-and-items.md](xways-reading-events-and-items.md).

---

## XWF_OpenItem — opening EMLs with embedded attachments

- From v21.8 Beta 5, X-Ways adds a new flag to `XWF_OpenItem()` that returns the EML *plus* embedded attachments, matching the GUI "Copy/Recovery" behaviour. The flag value observed in the thread's user code was **`0x2000`**:

  ```cpp
  hHandle = XWF_OpenItem(hCurVolume, nItemID, 0x2000);
  ```

  > The official flag is **`0x8000`** per the live [XWF_functions.html](https://www.x-ways.net/forensics/x-tensions/XWF_functions.html) ("embed child objects ... v21.8 and later", checked 2026-07-03); the thread's `0x2000` is not in the official flag list. See [xways-openitem-flags.md](xways-openitem-flags.md).

- **Caveat (as of 2026-05-11):** with that flag, `XWF_GetProp(hHandle, 1, 0)` and `XWF_GetSize()` may still return the size of the bare EML (~1.3 KB in one example), not the size with attachments. Don't trust the reported size; measure by reading until EOF.

---

## Disk I/O X-Tensions vs ordinary X-Tensions — API surface

A single DLL **can** serve as both an ordinary X-Tension and a disk I/O X-Tension simultaneously, but the two contexts have **disjoint API surfaces** and must be kept separate in your head:

| Context | Entered via | API available |
|---|---|---|
| Ordinary X-Tension | command line, main menu, dir-browser context menu, volume-snapshot refinement | Full `XWF_*` API in response to `XT_*` callbacks |
| Disk I/O X-Tension | X-Ways calls `XT_SectorIOInit()` | Restricted; only `XWF_SectorIO()` is documented as callable here ("May be called when processing `XT_SectorIO()`") |

**Concrete pitfall:** calling `XWF_CreateItem()` from inside `XT_SectorIOInit()` is **not supported** — it pagefaults (type 216) every time. Per X-Ways: if `XT_SectorIOInit()` is called, at that moment your X-Tension is considered a disk I/O X-Tension, not an ordinary X-Tension. So if you want to both decode an unknown filesystem (disk I/O role) *and* populate a file tree via `XWF_CreateItem()` (ordinary role), they must happen in different invocations — typically the file tree is built when the user runs the same DLL as an ordinary X-Tension via the menu.

The key facts here are the explicit pagefault outcome and the four canonical entry paths for "ordinary" mode; see [xtension-invocation.md](xtension-invocation.md) for entry-point context.

---

## Version-history pointers extracted from these threads

Dated API-history data points from these threads (see also [xways-api-history-19-to-21_4.md](xways-api-history-19-to-21_4.md)):

- **v21.7 Beta 2** — `XT_PREPARE_TARGETFILESWITHUNKNOWNDATA` widened to include encrypted files and files with unsupported compression (previously: metadata-only).
- **v21.7 Beta 4** — files in corrupt/incomplete archives are now opened with a size-0 handle so `XT_ProcessItemEx()` is called on them.
- **v21.8 Beta 5** (2026-05-08) —
  - `XWF_OpenItem()` gains a new flag to include embedded EML attachments (officially **`0x8000`** per the live HTML, checked 2026-07-03; the thread's `0x2000` is not in the official list).
  - A label-removal counterpart to `XWF_AddToReportTable` is added (`XWF_Label` with `nFlags` `0x80000000`).
- **Pending fix (no version named yet)** — `XT_PREPARE_TARGETZEROBYTEFILES` will start affecting `XT_ProcessItemEx()` (currently a doc-vs-reality mismatch).
