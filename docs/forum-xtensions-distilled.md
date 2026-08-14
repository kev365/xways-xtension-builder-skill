---
type: empirical-finding
last_updated: 2026-08-12
author: project
---

# X-Tension behavior notes (X-Ways 21.7–21.8)

> Distilled notes on X-Tension runtime behavior in X-Ways 21.7–21.8. Verify
> specifics against the official API page / live `XWF_functions.html`.

## Which parts of the forum are readable

The X-Ways user forum has **five boards**, and only one is public
(surveyed 2026-08-12):

| Board | URL stem | Access |
| --- | --- | --- |
| Public Announcements — the version threads | `messages/1/` | **public** |
| four further boards | `messages/6/`, `messages/838/`, `messages/1744/`, `messages/5307/` | **HTTP 401** |

The board menu states that access is limited to users with **active update
maintenance**, which is what the four restricted boards need. Board **5307 is
the X-Tension Programming section** — announced 2021-03-26 in the Miscellaneous
thread and, at the time of writing, **46 threads carrying 75 posts from X-Ways
themselves**. It is by a wide margin the densest API source outside the official
function reference, and much of what follows is drawn from it.

Anything sourced from a restricted board is cited by thread number below. If you
are re-checking a claim and get an HTTP 401, that is why — you need forum
credentials, not a different URL.

---

## Contents

- Which parts of the forum are readable
- XT_ProcessItem(Ex) — which items are actually delivered
- XWF_AddToReportTable — label removal
- XWF_OpenItem — opening EMLs with embedded attachments
- Disk I/O X-Tensions vs ordinary X-Tensions — API surface
- Host watchdog on refinement threads (v21.8 Preview 5)
- Version-history pointers extracted from these threads

## XT_ProcessItem(Ex) — which items are actually delivered

This is the most consequential finding for any X-Tension that iterates items. The documented `XT_PREPARE_TARGET*` flag semantics diverged from runtime behaviour in several ways, and several fixes shipped across v21.7 betas.

**Bugs / doc-mismatches confirmed by X-Ways:**

1. `XT_PREPARE_TARGETZEROBYTEFILES` had **no effect on `XT_ProcessItemEx()`** despite documentation. Zero-byte files were only delivered to `XT_ProcessItem()`. A fix is planned for all future releases.
2. `XT_PREPARE_TARGETFILESWITHUNKNOWNDATA` was scoped narrower than docs imply — pre-v21.7 Beta 2 it only targeted **metadata-only files**. Encrypted files and files with unsupported compression were *not* included. Fixed in v21.7 Beta 2.
3. Files inside corrupt/incomplete archives weren't passed to `XT_ProcessItemEx()` at all. Fixed in v21.7 Beta 4 — such items are now opened with a (useless) size-0 handle so the callback fires.

**The vendor's own framing (2019-03-08), which is broader than the bug list.**
File-level refinement does **not** process previously-existing files whose first
cluster is known to have been overwritten, or whose first cluster is unknown,
*unless the user specifically targets them by tagging or selection*. And
`XT_ProcessItem()` is called as part of file-based processing — so "not targeted
for refinement" means **no call**, by design rather than by defect.

The stated escape hatch: *"If you wish to be in control over which items you
process, and not be restricted to what X-Ways Forensics or the user thinks
should be processed, then you can simply iterate over all items of the volume
snapshot yourself, in response to `XT_Prepare()` or `XT_Finalize()`."*

That is a real trade-off rather than a better option. Driving the callbacks
honours the analyst's active filter and right-click selection; iterating the
snapshot yourself sees every item but ignores what the analyst asked for. Pick
deliberately — see [item-collection](conventions/item-collection.md).

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

- **The "wrong size" caveat is resolved — it was the wrong flag, not a size bug.**
  The reporter measured 1.3 KB (bare EML) while calling
  `XWF_OpenItem(hVol, 1256, 0x2000)`. He reached the right conclusion himself on
  2026-05-22 — *not* a `XWF_GetProp` problem, but `XWF_OpenItem` not embedding —
  and X-Ways confirmed the next day that **the flag value in the documentation
  was wrong: `0x8000`, not `0x2000`**, and corrected the page. With `0x8000` the
  size functions report the embedded size. Do **not** write a read-to-EOF
  workaround for this.

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

## Host watchdog on refinement threads (v21.8 Preview 5)

From **2026-03-26**: X-Ways monitors additional threads during volume snapshot
refinement, and attempts to **terminate and resume hanging threads** found to be
unresponsive for **~15 minutes** (the announcement gives 15 min as an example,
not a documented constant).

This is a host-robustness feature, but it bounds how long an X-Tension may block
a refinement thread. It matters most for CLI wrappers that wait on a slow helper
process — see the note in
[subprocess-stdio](conventions/subprocess-stdio.md) and
[threading-model](conventions/threading-model.md).

**Unverified — worth measuring before relying on either reading.** The
announcement says "additional threads" without defining which. It is not known
whether the watchdog covers the thread that runs `XT_Finalize` (where the
wrapper template does its work) or only the multi-threaded file-examination
workers, nor whether "terminate and resume" means the X-Tension's call is
unwound, the thread is killed outright, or the operation is retried.

---

## Version-history pointers extracted from these threads

Dated API-history data points from these threads (see also [xways-api-history-19-to-21_4.md](xways-api-history-19-to-21_4.md)):

- **v21.7 Beta 2** — `XT_PREPARE_TARGETFILESWITHUNKNOWNDATA` widened to include encrypted files and files with unsupported compression (previously: metadata-only).
- **v21.7 Beta 4** — files in corrupt/incomplete archives are now opened with a size-0 handle so `XT_ProcessItemEx()` is called on them.
- **v21.8 Beta 5** (2026-05-08) —
  - `XWF_OpenItem()` gains a new flag to include embedded EML attachments (officially **`0x8000`** per the live HTML, checked 2026-07-03; the thread's `0x2000` is not in the official list).
  - A label-removal counterpart to `XWF_AddToReportTable` is added (`XWF_Label` with `nFlags` `0x80000000`).
- **v21.8 SR-4** (2026-07-02) — **`XWF_OpenItem()` could fail when called from
  `XT_ProcessItem()` for files inside nested archives while refinement ran with
  multiple threads.** Fixed in this release. Not mentioned on the official API
  page (checked 2026-08-12) — this is forum-only. If you support hosts older
  than 21.8 SR-4, handle a failed open on nested-archive items rather than
  assuming a valid handle.
- **v21.8 SR-5** (2026-07-28) — exceptions inside `XWF_GetCellText` are now
  caught by the function itself instead of reaching the X-Tension, and notes
  were added to the official documentation. Both are distilled in
  [xways-reading-events-and-items.md](xways-reading-events-and-items.md).
- **Pending fix (no version named yet)** — `XT_PREPARE_TARGETZEROBYTEFILES` will start affecting `XT_ProcessItemEx()` (currently a doc-vs-reality mismatch).
