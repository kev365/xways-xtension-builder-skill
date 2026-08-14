---
source: extracted from the wrapper template (templates/x-tensions/wrapper/) and working X-Tensions
type: convention
last_updated: 2026-08-12
author: project
---

# Item collection (`XT_ProcessItem` / `XT_ProcessItemEx`)

!!! danger "Traps when you process or collect selected items"
    1. **`0x01` calls whichever callback you export — export both and BOTH fire.** `XT_Prepare`
       returning `0x01` makes X-Ways call your per-item callback(s); there is **no "`Ex` default."**
       Export both `XT_ProcessItem` and `XT_ProcessItemEx` and **each item is delivered to both**
       (verified 2026-06-10: RVS delivers each item to both callbacks, from a multi-threaded worker
       pool — this *is* the "2N items" double-count). So do the per-item work in **exactly one** (use
       `XT_ProcessItemEx` when you need an `hItem`), or dedup.
       Do **not** return `0x01 | 0x04` thinking `0x04` adds `Ex` — `0x04` is `EXPECTMOREITEMS` (you
       will *create* items).
    2. **Per-item callbacks are multi-threaded under RVS.** `XT_ProcessItem(Ex)` runs on an RVS
       worker pool, so **any state shared across calls** (a collected-items vector, counters) is a
       data race unless synchronised. (DBC / "Run X-Tension" is single-threaded — but don't rely on
       the mode.) Self-calling `XWF_OpenItem`/`Read`/`Close` *on this pool* is fine — the trap is a
       thread **you** spawn (see [threading model](threading-model.md)).
    3. **RVS "apply to tagged files only" silently feeds zero items.** If `XT_Prepare` returns
       `0x01` and you export a callback but per-item never fires — `XT_Prepare` reports a non-zero
       item count, then `XT_Finalize` runs immediately with **0 processed** — it is almost always
       the RVS dialog's file-scope radio set to **"apply to tagged files only"** with nothing
       tagged. X-Ways still calls `XT_Prepare`/`XT_Finalize` but delivers **no items**. Switch to
       **"apply selected options to all files"** (or tag first). Verified on xwb 21.8
       (2026-06-27) — *not* a code/flag bug, *not* the already-processed-snapshot
       skip.

**Return-flag reference:** [xtension-invocation.md](../xtension-invocation.md) — `XT_Prepare`
return bitmask (`0x01` `CALLPI` = call per item, whichever callback(s) you export — both fire if both
exported; `0x02` `CALLPILATE` = RVS *late*-call of the non-`Ex` variant; `0x04` `EXPECTMOREITEMS` =
you'll add items). Empirically verified.

**Reference implementation:**
[xways-linux-logs](https://github.com/kev365/xways-linux-logs) (`xways-linux-logs.cpp` →
`CollectItem` / `ResetItems`: deduped, mutex-guarded collection) and its `XT_Prepare` /
`XT_ProcessItem(Ex)` call sites.

## Contents

- Pattern
- Detecting that the analyst cancelled the run
- Remembering what you already processed, across runs
- Do / Don't

## Pattern

When you collect selected items to process later (e.g. in a dialog-driven X-Tension), route **both**
exported callbacks through one collector that dedups under a lock — the dedup makes double-delivery
impossible and the lock makes it RVS-safe:

```cpp
static std::mutex                g_itemsMx;
static std::vector<LONG>         g_items;
static std::unordered_set<LONG>  g_itemSeen;

// Both callbacks call this. Export both: X-Ways delivers zero-byte items (and
// corrupt-archive items) only to the non-Ex variant — confirmed on 21.8 —
// but collect once.
static void CollectItem(LONG nItemID) {
    std::lock_guard<std::mutex> lk(g_itemsMx);
    if (g_itemSeen.insert(nItemID).second) g_items.push_back(nItemID);
}

LONG __stdcall XT_Prepare(HANDLE, HANDLE, DWORD, void*) { /* … */ return 0x01; }   // both PI+PIEx fire → dedup
LONG __stdcall XT_ProcessItem  (LONG id, void*)         { CollectItem(id); return 0; }
LONG __stdcall XT_ProcessItemEx(LONG id, HANDLE, void*) { CollectItem(id); return 0; }
```

If instead you do the work **inline** per item (carver/classifier — no collection), still synchronise
any shared counters/output because RVS is multi-threaded, and put the work in `XT_ProcessItemEx`.

## Detecting that the analyst cancelled the run

Call **`XWF_ShouldStop` in `XT_Finalize`** — that is X-Ways' own answer to "how
does my X-Tension learn the RVS was cancelled" (X-Tension Programming board,
2026-08-05). It matters because `XT_Finalize` still fires after a cancelled run,
so without the check an X-Tension happily does its post-enumeration work on a
truncated item list.

**Two caveats, both live as of 2026-08-12.**

The same reporter found `XWF_ShouldStop` **always returned false inside
`XT_ProcessItemEx`** even when the user aborted, while returning true in
`XT_Finalize`. Behaviour in `XT_ProcessItem` (the non-`Ex` callback, where the
collect-only pattern polls it) has not been reported either way, so treat an
abort check in a per-item callback as **unconfirmed** rather than reliable.

He then found `XT_Finalize` did **not** always return true either, without
finding the pattern; X-Ways replied that it should be consistent and asked for a
retest on 21.9 Beta. So this is the best available signal, not a guarantee.

Polling `XWF_ShouldStop` per N items is still worth doing regardless of its
return value: since v19.3 Preview 1 the call also pumps the message queue and
keeps the host repainting — X-Ways explicitly says you are "doing something good
already by making the calls in the first place". See
[xtension-invocation.md](../xtension-invocation.md).

## Remembering what you already processed, across runs

There is no API for per-item X-Tension state. The vendor's recommended shape
(X-Tension Programming board, 2019-06-26) is an external file you own:

- Put it in the evidence object's own volume-snapshot directory —
  `XWF_GetEvObjProp` with `nPropType = 12`. Anything stored there is **deleted
  along with the snapshot when the user takes a new volume snapshot**, so your
  state cannot silently desynchronise from the items it describes.
- Key it by evidence-object ID (`XWF_GetEvObjProp`, `nPropType = 1`) and case ID
  (`XWF_GetCaseProp` with `XWF_CASEPROP_ID`).
- A bitmap of one bit per snapshot item is enough to record "already processed".
- If you keep the file somewhere else instead, detect a re-taken snapshot
  yourself by comparing the stored **volume snapshot ID** (`nPropType = 4`)
  against the current one.

## Do / Don't

- **Do** put per-item work in exactly **one** callback (use `XT_ProcessItemEx` for an `hItem`) — both fire under `0x01`, so two working callbacks double-process.
- **Do** guard shared state with a mutex — `++counter`, `vec.push_back`, map writes all race under RVS.
- **Do** route both callbacks through one deduping collector if you accumulate item IDs.
- **Don't** return `0x01 | 0x04` to "get both callbacks" — that's `CALLPI | EXPECTMOREITEMS`. You
  need no extra flag: `0x01` already delivers each item to **both** exported callbacks.
- **Don't** assume single-threaded delivery — it holds for DBC, not RVS.

See also: [Threading model](threading-model.md) (run synchronously; never call `XWF_*` from a worker
thread) and [xtension-invocation.md](../xtension-invocation.md).
