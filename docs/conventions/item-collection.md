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

## Do / Don't

- **Do** put per-item work in exactly **one** callback (use `XT_ProcessItemEx` for an `hItem`) — both fire under `0x01`, so two working callbacks double-process.
- **Do** guard shared state with a mutex — `++counter`, `vec.push_back`, map writes all race under RVS.
- **Do** route both callbacks through one deduping collector if you accumulate item IDs.
- **Don't** return `0x01 | 0x04` to "get both callbacks" — that's `CALLPI | EXPECTMOREITEMS`. You
  need no extra flag: `0x01` already delivers each item to **both** exported callbacks.
- **Don't** assume single-threaded delivery — it holds for DBC, not RVS.

See also: [Threading model](threading-model.md) (run synchronously; never call `XWF_*` from a worker
thread) and [xtension-invocation.md](../xtension-invocation.md).
