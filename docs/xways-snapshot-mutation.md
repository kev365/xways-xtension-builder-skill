---
type: empirical-finding
last_updated: 2026-06-06
author: project
---

# Snapshot mutation / item creation — empirical findings

First empirical map of the **item-creation / snapshot-mutation** API region.

- **Run:** 2026-06-06, X-Ways Forensics **21.8 SR-1** (xwb64, BYOD), a whole-disk
  E01 image (evidence object + 2 partitions), invoked via
  **Run X-Tension on Volume Snapshot** → `nOpType = 0x1` (action=1), read-only bit clear.

> The test creates items in `XT_Prepare` and `XT_Finalize` returns `0x02`
> (SAVE_SNAPSHOT); X-Ways reported **"+8 files, Events: 1 (+1)"** per volume and
> persisted them. Run on a throwaway case only.

## XWF_CreateFile — works from `XT_Prepare`; flag space mapped

`XWF_CreateFile(pName, nCreationFlags, nParentItemID, pSourceInfo)` succeeds when
called **directly in `XT_Prepare`** (not only during `XT_ProcessItemEx`). New
items appear immediately and are saved. The returned item ID is a **sequential
append** (= the prior snapshot item count, e.g. count 111859 → first new id 111859).

`nCreationFlags` results (a 16-byte buffer was passed only for the `0x10` family):

| flag | xwf-api-rs name | result |
|---|---|---|
| `0x00` | (none) | **created** (no buffer needed → empty/metadata item) |
| `0x01` | MoreItemsToBeCreated | **created** (no buffer) |
| `0x02` | ExcerptFromParent | **access-violation** with `pSourceInfo=NULL`; returns **-1** with a `SrcInfo` whose `pBuffer=NULL`. Needs real source (parent offset/size) — exists, behavior TBD. |
| `0x04` | AttachExternalFile | **access-violation** with `pSourceInfo=NULL`. Needs a file path — exists, behavior TBD. |
| `0x08` | KeepExternalFile | **created** (no buffer) |
| `0x10` | FileContentsFromBuffer | **created** (the item-from-buffer path) |
| `0x11` / `0x12` | `0x10`+`0x01` / `0x10`+`0x02` | **created** (a buffer satisfies the `0x02` source requirement, so `0x12` no longer AVs) |

**`nParentItemID` must be a real item ID.** `parent = -1` **access-violates** —
do not pass `-1` for "root"; pass a real source item's ID.

Takeaway for parser X-Tensions: `0x02` ExcerptFromParent (reference a region of
the parent without copying bytes) and `0x04` AttachExternalFile (pull a disk file
into the snapshot) are **real, distinct modes** — confirming them fully needs the
correct `SrcInfo` shape (offset/size for excerpt, path for attach), which a
follow-up test can supply.

## XWF_SetItemSize return value (21.3) — `-1` success / `0` failure

The header types it `void`; re-typedef'd as `LONG`, it returns **`-1` (TRUE) on a
valid item** (valid/zero/oversize all returned `-1`) and **`0` (FALSE) on an
invalid item ID** (`-1` and `0x7FFFFFFF`). So treat `0` as the failure sentinel.

## XWF_FindItem1 nFlags — `0x01` = case-sensitive

`XWF_FindItem1(parent, name, nFlags, startID)`:
- **Default (`nFlags = 0`) is case-INSENSITIVE** — an upper-cased name matched a
  lower-case item.
- **`nFlags = 0x01` makes the match case-SENSITIVE** — the case-flipped name went
  from found → `-1` only at `0x01`. `0x02`/`0x04`/`0x08` had no effect on matching.
- Not-found returns **`-1`**; exact match returns the item ID.
- `nSearchStartItemID` starts the scan **at** that index (starting at match+1
  skipped the only match → `-1`).

## XWF_GetItemName pointer lifetime — more stable than assumed

The `const wchar_t*` from `XWF_GetItemName`:
- is a **per-item distinct pointer**, NOT a single shared scratch buffer
  (two items returned different addresses; `p1 == p2` was false);
- its content **survived** an intervening `XWF_GetItemSize`, an intervening
  `XWF_GetItemName(otherItem)`, **and** the 8 item creations earlier in the same
  callback (`content_unchanged = yes` in every step).

So in 21.8 SR-1 the "invalidated by the next XWF call" folklore was **not
reproduced**; an aggressive `_wcsdup`/re-fetch appears unnecessary here (copying
remains harmless). Addresses were adjacent (`…010a` vs `…0004`), i.e. slots in a
persistent name pool. Revisit if a future build/context shows clobbering.

## Created-item interop — mostly first-class

| call (on a buffer-created item) | result |
|---|---|
| `XWF_AddEvent` | **rv=1**, event persisted (the "+1 event") — created items carry events |
| `XWF_SetItemParent` | works — re-homed an item (`before=6 → after=0`) |
| `XWF_AddComment` + `XWF_GetComment` | round-trips exactly (`GetComment` read back the set string) |
| `XWF_AddToReportTable(0x0002\|0x0020\|0x8000)` | **rv=1** (the label triplet is accepted; rv = table number) |
| `XWF_SetItemInformation` CREATIONTIME/MODIFICATIONTIME | `set=TRUE`, read-back differs from the set value by **+512** (×100 ns ≈ 51 µs) — sticks, with a small transform worth a follow-up |
| `XWF_SetItemType` | `set` returned without error but `XWF_GetItemType` gave rv=2 + empty description — **inconclusive** |
| `XWF_SetHashValue` (nParam=0) | returned **TRUE**, but `XWF_GetHashValue` read back zeros (`FALSE`) — **unconfirmed**; `nParam` (hash type) semantics unknown |

## nOpType read-only bit

`XT_NOPTYPE_READONLY (0x100)` was **clear** even though the source is an E01
(physically read-only). The snapshot was mutable (+8 items). So `0x100` reflects
**"snapshot writes allowed"**, not media write-protection — two separate layers:
the *evidence bytes* are always read-only (X-Ways never writes the source), while
the *volume snapshot* (the case-side metadata/item database) is normally writable
and is what item-creation mutates.

**Read-only snapshots are reachable (verified 2026-06-06).** Opening
the **same case in a second X-Ways instance** puts it in **write-protected** mode
(title bar + Volume Snapshot panel read "(write-protected)"; the first instance
holds the write-lock). Launch behaviour then differs by gesture:

- **RVS is gated:** the Refine Volume Snapshot dialog opens but its **OK button is
  disabled (lock icon)** — Run X-Tensions cannot be launched via RVS.
- **DBC is NOT gated:** directory browser → right-click → Run X-Tension runs
  normally, and X-Ways passes **`nOpType = 0x104`** = action `0x04` (DBC) **with the
  `0x100` read-only bit set**. So `XT_NOPTYPE_READONLY` is **real and reachable**
  (not defensive-only), and the `& 0xFF` action / `& 0x100` read-only decode is
  validated. (Returning `XT_INIT_UNDERSTANDS_NOPTYPE` from `XT_Init` is what makes
  the `0x100` bit appear — without it the encoding collapses to the bare action
  code.)

On the read-only snapshot, **every `XWF_CreateFile` returned `-1`** (clean
rejection) — *including* the `0x02`/`0x04`/`parent=-1` calls that **access-violate
on a writable snapshot**. So a read-only snapshot **short-circuits creation to
`-1` before the source handling runs** (no crash, no items added). Read APIs were
unaffected: `XWF_FindItem1` and `XWF_GetItemName` worked normally; `XT_Finalize`
returning `0x02|0x01` had no effect (nothing to save).

**Practical guidance:** test `nOpType & 0x100` in `XT_Prepare` and bail when set
(return `-1` to skip the volume) — otherwise an item-creating
X-Tension burns through every item getting `-1`. Other read-only triggers
(snapshot files on write-protected media) untested but would look identical to the
X-Tension.

## Still open

- `0x02` ExcerptFromParent / `0x04` AttachExternalFile full behavior — supply the
  proper `SrcInfo` (parent offset+size; external path).
- Persistence across **close-without-save → reopen** (does `XT_Finalize 0x02`
  alone persist?), and the `EXPECTMOREITEMS` A/B (`prepare_return = 0x04` vs `0x00`).
- The `SetItemInformation` **+512** timestamp delta; hash storage; `SetItemType` stick.

## Multi-volume invocation note

A 3-volume E01 fires `XT_Prepare` 3× in one invocation. Item-creating X-Tensions
must **reset per-run state at the start of each `XT_Prepare`** (e.g. a created-item
ID global), or a later volume's pass operates on a stale item from the first run.
Same-second TSV/output filenames also collide across runs unless a per-run suffix
is added.
