---
source: X-Ways SDK header (see getting-the-sdk.md) + https://www.x-ways.net/forensics/x-tensions/api.html + empirical
type: official-doc + empirical-finding
fetched: 2026-04-19
last_updated: 2026-04-26
author: X-Ways Software Technology AG; empirical research notes from testing + CLI-wrapper X-Tension runs
---

# X-Tension Invocation Reference

How X-Ways calls into an X-Tension DLL: the entry points, the invocation modes, the threading model, the return-value semantics, and the patterns that fall out of these mechanics. Authoritative SDK declarations: the X-Ways SDK header (see [getting-the-sdk.md](getting-the-sdk.md)).

## Entry points

X-Ways calls these by name (no decoration — exported via the `.def` file). Only `XT_Init` is mandatory; the rest are optional and only invoked if you've exported them.

| Function | When it's called | Threading |
| --- | --- | --- |
| `XT_Init` | Once when the DLL is loaded. Resolve `XWF_*` function pointers here, refuse to load if anything required is missing (return `-1`). | Single-threaded, X-Ways main thread |
| `XT_About` | When the analyst clicks the "About" button next to the X-Tension in the picker. | Single-threaded, main thread |
| `XT_Prepare` | Once at the start of any operation that involves the X-Tension (Run, RVS, Searches, Context menus). Receives `hVolume`, `hEvidence`, `nOpType`. Most one-shot work belongs here. | Single-threaded, main thread |
| `XT_ProcessItem` | Per item, if `XT_Prepare` returns bit `0x01` (`CALLPI`) **and you export it**. | Multi-threaded under RVS; otherwise single-threaded |
| `XT_ProcessItemEx` | Same as `XT_ProcessItem` but receives an `hItem` for `XWF_Read` access. **Also driven by `0x01`** — *not* a separate flag (`0x04` is unrelated); X-Ways calls whichever per-item callback(s) you export. Export **both** and **both fire per item** (verified — see the return-value note below). | Multi-threaded under RVS |
| `XT_ProcessSearchHit` | Per search hit — only when invoked from a search-hit context menu or as a search-refinement step. | Single-threaded |
| `XT_Finalize` | Once after all per-item callbacks complete. Mirrors `XT_Prepare` — both get the same `nOpType`. | Single-threaded |
| `XT_Done` | Once when X-Ways is about to unload the DLL. | Single-threaded |

### `XT_Init` arguments

```c
LONG __stdcall XT_Init(DWORD info, DWORD nFlags, HANDLE hMainWnd, void* lpReserved);
```

`nFlags` is a bitmask of:

| Bit | Symbol | Meaning |
| --- | --- | --- |
| `0x01` | `XT_INIT_XWF` | Caller is **X-Ways Forensics** (forensic license) |
| `0x02` | `XT_INIT_WHX` | Caller is WinHex (no forensic license) |
| `0x04` | `XT_INIT_XWI` | Caller is X-Ways Investigator |
| `0x08` | `XT_INIT_BETA` | Beta build |
| `0x20` | `XT_INIT_QUICKCHECK` | Just probing whether the X-Tension accepts this caller (since v16.5) — return `1` to accept, `-1` to refuse. No further calls follow. |
| `0x40` | `XT_INIT_ABOUTONLY` | About to call `XT_About` only (since v16.5) — no real work happens this run |

Most X-Tensions that use the Events API or other forensic-license-only features should refuse to load on `WHX`/`XWI` callers:

```c
if (!(nFlags & XT_INIT_XWF)) return -1;
```

### Return values

| Function | Return value semantics |
| --- | --- |
| `XT_Init` | `1` = OK; `-1` = refuse to load (X-Ways drops the DLL) |
| `XT_About` | Ignored |
| `XT_Prepare` | Bitmask (see the full flag table below). In brief: `0` = no per-item iteration; `0x01` (`CALLPI`) = call your per-item callback(s) — **whichever of `XT_ProcessItem`/`XT_ProcessItemEx` you export; export both and both fire per item**; `0x02` (`CALLPILATE`) = call non-`Ex` *late* (RVS); `0x04` (`EXPECTMOREITEMS`) = signal you will add items. Negative values: `-1`..`-4` (distinct meanings — see below), not a generic "abort". |
| `XT_ProcessItem(Ex)` | `0` = continue; negative = abort iteration |
| `XT_ProcessSearchHit` | Bitmask describing whether to keep/delete the hit; consult the API page when implementing |
| `XT_Finalize` | `0` = ignored; **`0x02`** = ask X-Ways to save the volume snapshot of the specified volume (added v21.3 Preview 3, 2024-09-05 — see [xways-api-history-19-to-21_4.md](xways-api-history-19-to-21_4.md)). Use when your X-Tension mutated the snapshot via `XWF_SetItem*` / `XWF_AddEvent` / etc. and wants those changes persisted without the analyst doing it manually. |
| `XT_Done` | Ignored |

### `XT_Prepare` return value — full flag table

From the official [X-Tension functions page](https://www.x-ways.net/forensics/x-tensions/XT_functions.html) (confirmed against the official page, 2026-06-06; these constants are **not** in the SDK header). Return `0`, a combination of these positive flags, or one negative value:

| Bit | Symbol | Meaning |
| --- | --- | --- |
| `0x01` | `XT_PREPARE_CALLPI` | call your per-item callback(s) — **whichever of `XT_ProcessItem` / `XT_ProcessItemEx` you export. Export both → both fire per item** (verified, see note) |
| `0x02` | `XT_PREPARE_CALLPILATE` | RVS modifier: deliver the non-`Ex` `XT_ProcessItem()` *late* (after other refinement steps). **Not** required to receive non-`Ex` — under `0x01` it already fires. |
| `0x04` | `XT_PREPARE_EXPECTMOREITEMS` | signal X-Ways that you **may create more items** in the volume snapshot |
| `0x08` | `XT_PREPARE_DONTOMIT` | also get callbacks for files the user chose to omit |
| `0x10` | `XT_PREPARE_TARGETDIRS` | also get callbacks for directories |
| `0x20` | `XT_PREPARE_TARGETZEROBYTEFILES` | also get callbacks for 0-byte files |
| `0x40` | `XT_PREPARE_TARGETFILESWITHUNKNOWNDATA` | also get callbacks for files with only metadata known |

> **Verified empirically (2026-06-10):** `0x01` makes X-Ways call **whichever per-item callback(s) you export** — there is **no "`Ex` by default."** Export *both* `XT_ProcessItem` and `XT_ProcessItemEx` and **both fire for every item** — under RVS, each item is delivered to both exported callbacks (equal call counts) from a multi-threaded worker pool, exactly the "2N items" double-count this mistake produces. So: do per-item work in **exactly one** callback (use `XT_ProcessItemEx` when you need `hItem`), or route both through one dedup-by-item-ID collector — see [item-collection](conventions/item-collection.md). `0x04` is `EXPECTMOREITEMS` (you'll create items), **not** a callback selector — an item-creating X-Tension returns `0x01 | 0x04`.

Negative `XT_Prepare` returns (distinct, not interchangeable):

| Return | Meaning |
| ---: | --- |
| `-1` | don't call other functions of this X-Tension **for this volume**, not even `XT_Finalize()` |
| `-2` | exclude **this particular volume** from the operation |
| `-3` | prevent further use of this X-Tension for the **rest of the whole operation** (e.g. wrong `nOpType`) |
| `-4` | stop the **whole operation** (e.g. the entire RVS) altogether |

`XT_Finalize` returns `0` or: `0x01` (v17.6+) refresh the directory-browser listing after `XT_ACTION_DBC` (only needed when you added files); `0x02` (v21.3+) save the volume snapshot. Combine when an item-creating X-Tension runs from DBC.

## Invocation modes (`nOpType` values)

`XT_Prepare` and `XT_Finalize` both receive an `nOpType` (`DWORD`) that tells you which UI gesture invoked the X-Tension. Constants from the X-Ways SDK header (see [getting-the-sdk.md](getting-the-sdk.md)):

| Value | Symbol | Triggered by | What you typically get |
| ---: | --- | --- | --- |
| `0` | `XT_ACTION_RUN` | **Tools → Run X-Tension…** on a volume snapshot | One `XT_Prepare`. No per-item callbacks unless requested. |
| `1` | `XT_ACTION_RVS` | X-Tension included as a **Refine Volume Snapshot** step | `XT_Prepare`, then `XT_ProcessItem(Ex)` for every snapshot item (multi-threaded), then `XT_Finalize` |
| `2` | `XT_ACTION_LSS` | A **logical simultaneous search** is starting | Search-hit callbacks, not item callbacks |
| `3` | `XT_ACTION_PSS` | A **physical simultaneous search** is starting | Same as LSS, search-level |
| `4` | `XT_ACTION_DBC` | **Directory-browser context menu** → Run X-Tension on the selected items | `XT_Prepare`, then `XT_ProcessItem(Ex)` for **each selected item only** (not the whole snapshot), then `XT_Finalize` |
| `5` | `XT_ACTION_SHC` | **Search-hit-list context menu** | `XT_ProcessSearchHit` per hit |
| `6` | (no symbol in 2024-05-31 header) | **Events viewer context menu** — added v20.3 SR-3 (2021-08-23, see [xways-api-history-19-to-21_4.md](xways-api-history-19-to-21_4.md)). xwf-api-rs names this `XtPrepareOpType::EventListContextMenu`. | `XT_Prepare` plus the analyst-selected event(s); the per-event callback shape is undocumented and unverified — confirm empirically before relying on it. |

> **Note:** the DBC/SHC values are easy to misremember as 3 and 4 — the header values are 4 and 5 respectively. Use the `XT_ACTION_*` symbols defined here directly to avoid off-by-one confusion.

### Mode characteristics in detail

**`XT_ACTION_RUN`** — the most common case. Analyst picks the X-Tension via Tools → Run X-Tension. You get exactly one `XT_Prepare` call. If you do all your work in `XT_Prepare` and `return 0`, no per-item callbacks happen and `XT_Finalize` runs once. This is the cleanest pattern for X-Tensions that operate on the snapshot as a whole (e.g., timeline ingesters, summary generators).

**`XT_ACTION_RVS`** — fires when an analyst includes the X-Tension as a refinement step. `XT_Prepare` runs once on the main thread, then `XT_ProcessItem(Ex)` fires for every item in the snapshot — **multi-threaded by default**. After all items, `XT_Finalize` runs. If your X-Tension is a per-item processor (file carver, classifier, hash adder), this is the natural mode. If it's a one-shot pass (like a timeline ingester), do the work in `XT_Prepare` and return 0 — same code that handles `XT_ACTION_RUN` will work here.

**`XT_ACTION_LSS` / `XT_ACTION_PSS`** — invoked when the X-Tension participates in a search. You're operating on search hits, not items. Most X-Tensions can ignore these modes.

**`XT_ACTION_DBC`** — fires when the analyst right-clicks a selection in the directory browser and picks "Run X-Tension" from the context menu. Critically: `XT_ProcessItem(Ex)` is called **only for the selected items**, not the whole snapshot. Useful for "process this one file" or "process these N selected items" gestures. To honor the selection, return `0x01` (`XT_PREPARE_CALLPI`) from `XT_Prepare` so the per-item callbacks fire (X-Ways calls whichever you export — both `XT_ProcessItem` and `XT_ProcessItemEx` if you export both). Returning `0x04` alone is `EXPECTMOREITEMS` and fires **no** per-item callbacks.

**`XT_ACTION_SHC`** — fires from the search-hit-list context menu. You get `XT_ProcessSearchHit` callbacks. Most X-Tensions can ignore.

## Threading

| Callback | Threading model |
| --- | --- |
| `XT_Init`, `XT_About`, `XT_Prepare`, `XT_Finalize`, `XT_Done` | Always single-threaded on the X-Ways main thread |
| `XT_ProcessItem(Ex)` under `XT_ACTION_RVS` | **Multi-threaded** — RVS uses a worker pool. State shared across calls needs synchronisation. |
| `XT_ProcessItem(Ex)` under `XT_ACTION_DBC` | Single-threaded (per-selection iteration) |
| `XT_ProcessSearchHit` | Single-threaded |

For X-Tensions that touch global state (e.g., emit events, update a shared counter), the safest pattern is to do all the work in `XT_Prepare` and return `0`. That sidesteps the threading question entirely. For per-item processors, mutex around any shared state.

> ℹ️ **Self-`XWF_OpenItem` on RVS worker threads is reliable (tested xwb 21.8) — but the supplied `hItem` is still the simpler default.** [JamieSharpe/XT_MT](https://github.com/JamieSharpe/XT_MT) reported self-open failures on archive-child items under RVS, which suggested a "never self-open on a worker thread" rule. Testing (2026-06-27, xwb 21.8, +10 threads) **could not reproduce it**: every item self-opened with **zero** failures — across archive children to depth 5, with both `0x01` and `0x00` prepare flags, from both `XT_ProcessItem` and `XT_ProcessItemEx`. So self-opening via a `g_hVolume` captured in `XT_Prepare` is not inherently broken; XT_MT's failures appear environment/version/corpus-specific. Practical guidance: prefer `XT_ProcessItemEx` and read through the supplied `hItem` because it's one less call and one less handle to leak — not because self-open is unsafe.

The Events API (`XWF_AddEvent`) has **undocumented thread safety**. Recommended practice: never call `XWF_AddEvent` from a multi-threaded context. Either do all event-emission in `XT_Prepare`, or batch into `XT_Finalize`.

### Keeping X-Ways responsive during long synchronous work

`XT_Prepare` and `XT_Finalize` run **on the X-Ways UI thread**. Any blocking call there — `WaitForSingleObject(childProcess, INFINITE)`, a synchronous network call, a long file scan, a CPU-bound loop — freezes that thread until it returns. Windows' DWM probes top-level windows every few seconds via a `SendMessage` ping; if the thread doesn't dispatch the ping within ~5 seconds, the title bar is decorated with **"(Not Responding)"** and Windows starts compositing a ghost copy of the window. The X-Tension is alive and progressing, but the analyst sees a hung application.

The fix is `MsgWaitForMultipleObjects` + a `PeekMessage` pump. Instead of blocking the thread completely, the wait wakes whenever **either** the kernel object signals **or** a UI message arrives — then the X-Tension drains the message queue and re-enters the wait. The semantics stay synchronous from the X-Tension's point of view (XT_Prepare still returns when the work is done), but the thread is doing real UI work during the wait so Windows never marks it hung.

```cpp
// Replace:    WaitForSingleObject(hChild, INFINITE);
//
// With this pump loop. Works for any HANDLE (process, event, mutex, etc.).
for (;;) {
    DWORD r = MsgWaitForMultipleObjects(1, &hChild, FALSE,
                                        INFINITE, QS_ALLINPUT);
    if (r == WAIT_OBJECT_0) break;            // child finished
    if (r == WAIT_OBJECT_0 + 1) {             // UI messages waiting
        MSG msg;
        while (PeekMessageW(&msg, nullptr, 0, 0, PM_REMOVE)) {
            TranslateMessage(&msg);
            DispatchMessageW(&msg);
        }
        continue;
    }
    break;                                     // WAIT_FAILED — bail
}
```

**When to use it:**

- Spawning an external helper binary and waiting for it (`bulk_extractor`, `yara`, …).
- Reading a large file synchronously.
- Any place an X-Tension would otherwise call a `Wait*` API on the UI thread.

**Caveats:**

- The dispatched messages run *real* code — including any modal Win32 dialogs the X-Tension itself owns. Reentry from those is fine (they have their own pump). Reentry from the user clicking a menu item that re-invokes the X-Tension would be problematic, but X-Ways serializes X-Tension invocation, so this isn't a practical concern.
- The pump only helps if the wait is on the UI thread. If the long work is *already* on a worker thread (e.g., spawned via `CreateThread`), the UI thread is free to pump on its own and you don't need this — the UI thread isn't blocked.
- Don't pump on a multi-threaded `XT_ProcessItem(Ex)` callback; those run on RVS worker threads, which have no UI to keep responsive.

Without the pump, e.g., a run that includes pagefile.sys freezes X-Ways for the wrapped tool's full runtime; with it, the main window stays interactive.

### Heartbeat for tight `XT_ProcessItem` enumeration loops

Different shape, same outcome. When X-Ways drives `XT_ProcessItem` on the main UI thread (Run, DBC — *not* RVS, which is multi-threaded), the X-Tension isn't waiting on anything — it's being called back in a tight loop and returning immediately. There's no `Wait*` call to convert to a pump, but the responsiveness timer still applies: if the enumeration loop runs for more than ~5 s without any `PeekMessage` call on the main thread, Windows marks the host "Not Responding" and may offer to terminate it.

The fix is a `PeekMessage` heartbeat inside the callback, **without dispatching**, paired with an `XWF_ShouldStop` check that gives the analyst an escape hatch:

```cpp
LONG __stdcall XT_ProcessItem(LONG nItemID, void*) {
    // ... real work (collect ID, etc.) ...

    // Every N items, tickle the responsiveness timer AND check whether the
    // analyst has asked to abort. PM_NOREMOVE only peeks — it does NOT
    // dispatch, so no re-entrancy vs. X-Ways' loop. 1024 is far below the 5s
    // threshold even at slow enumeration rates.
    static size_t tick = 0;
    if ((++tick & 0x3FF) == 0) {
        MSG msg;
        PeekMessageW(&msg, nullptr, 0, 0, PM_NOREMOVE);
        if (XWF_ShouldStop && XWF_ShouldStop()) {
            // Set a flag so XT_Finalize knows to skip its post-enumeration UI
            // (opening a dialog with a partial item set is rarely what the
            // analyst wanted). Returning negative tells X-Ways to stop calling
            // us; XT_Finalize still fires.
            g_aborted = true;
            return -1;
        }
    }
    return 0;
}
```

Per [IsHungAppWindow](https://learn.microsoft.com/windows/win32/api/winuser/nf-winuser-ishungappwindow): "*An application is considered to be not responding if … has not called PeekMessage within the internal timeout period of 5 seconds.*" Any `PeekMessage` call (PM_NOREMOVE or PM_REMOVE) resets the timer. PM_NOREMOVE deliberately doesn't dispatch — that's the safety property: X-Ways is in the middle of its own enumeration loop, and dispatching messages risks re-entering the X-Tension or other parts of X-Ways while internal state is mid-transition.

The `XWF_ShouldStop` check is what makes the freeze *survivable* rather than just non-fatal. Pressing Esc (or clicking X-Ways' Stop button) returns TRUE here, the X-Tension returns -1, X-Ways stops the enumeration loop, and `XT_Finalize` can branch on the abort flag to skip its normal post-enumeration UI.

**Does NOT fix the visible freeze.** The UI is still unresponsive (no paints, no clicks processed) because nothing is dispatched. What this *does* fix is: (a) the "Windows offered to kill it" failure mode that turns the freeze into a perceived crash, and (b) the inability to abort once you realise you've selected too much. For DBC selections in the hundreds of thousands of items, the freeze can still be many seconds regardless. If the UX matters, document the limit and recommend a filter-narrowed *Tools → Run X-Tension* invocation instead.

Without the heartbeat, huge right-click selections can freeze X-Ways long enough for Windows to mark it Not Responding and sometimes terminate it before the X-Tension's settings dialog appears.

## Invocation flow examples

### Run on Volume Snapshot (most common)

```text
analyst clicks Tools → Run X-Tension on Volume Snapshot
    ↓
XT_Init(nFlags, ...)            // once per X-Ways session
    ↓
XT_Prepare(hVolume, hEvidence, nOpType=XT_ACTION_RUN)
    ↓
[no per-item callbacks if XT_Prepare returns 0]
    ↓
XT_Finalize(hVolume, hEvidence, nOpType=XT_ACTION_RUN)
    ↓
XT_Done()                       // when X-Ways unloads the DLL (often at app exit)
```

### Refine Volume Snapshot (item-level processing)

```text
XT_Prepare(..., nOpType=XT_ACTION_RVS)   // returns 0x01 | 0x04
    ↓
[X-Ways spawns worker pool]
    ↓
XT_ProcessItemEx(item_0, hItem_0)  ┐
XT_ProcessItemEx(item_1, hItem_1)  ├ multi-threaded
XT_ProcessItemEx(item_2, hItem_2)  │
...                                 ┘
    ↓
XT_Finalize(..., nOpType=XT_ACTION_RVS)
```

### Directory-browser context menu (selected items only)

```text
analyst selects N items, right-click → Run X-Tension
    ↓
XT_Prepare(..., nOpType=XT_ACTION_DBC)   // returns 0x01 to request item callbacks
    ↓
XT_ProcessItem(item_a)  ┐
XT_ProcessItem(item_b)  ├ single-threaded, only the selected items
XT_ProcessItem(item_c)  ┘
    ↓
XT_Finalize(..., nOpType=XT_ACTION_DBC)
```

## Common patterns

### One-shot snapshot operation

Do all the work in `XT_Prepare`, regardless of `nOpType`. Return `0` to skip per-item iteration. This is the pattern a single-pass snapshot scanner or a one-shot timeline-builder X-Tension uses.

```c
LONG __stdcall XT_Prepare(HANDLE hVolume, HANDLE hEvidence, DWORD nOpType, void*) {
    DoMyWork(hVolume, hEvidence);  // scan, ingest, emit events, etc.
    return 0;
}
```

Pros: dead simple, single-threaded, works in every invocation mode. Cons: can't act on per-item selections from `XT_ACTION_DBC`.

### Selection-aware

Branch on `nOpType` in `XT_Prepare`:

```c
LONG __stdcall XT_Prepare(HANDLE hVolume, HANDLE hEvidence, DWORD nOpType, void*) {
    if (nOpType == XT_ACTION_DBC) {
        // analyst selected specific items — collect them via XT_ProcessItem
        return 0x01;  // request XT_ProcessItem
    }
    // any other mode: scan the whole snapshot
    DoSnapshotWork(hVolume, hEvidence);
    return 0;
}

LONG __stdcall XT_ProcessItem(LONG nItemID, void*) {
    g_selected.push_back(nItemID);  // single-threaded under DBC, no mutex needed
    return 0;
}

LONG __stdcall XT_Finalize(HANDLE hVolume, HANDLE hEvidence, DWORD nOpType, void*) {
    if (nOpType == XT_ACTION_DBC) DoSelectedItemsWork(g_selected);
    g_selected.clear();
    return 0;
}
```

### Per-item processor (RVS-friendly)

```c
LONG __stdcall XT_Prepare(HANDLE, HANDLE, DWORD, void*) {
    return 0x01;  // call per-item callback(s) — XT_ProcessItemEx below (only Ex is exported)
}

LONG __stdcall XT_ProcessItemEx(LONG nItemID, HANDLE hItem, void*) {
    // multi-threaded under RVS — synchronise any shared state
    {
        std::lock_guard<std::mutex> lk(g_mu);
        // ... write to shared structures ...
    }
    return 0;
}
```

## Pitfalls

- **`XWF_AddEvent` from multi-threaded context.** Don't, unless you're holding a mutex. Easier to do event emission in `XT_Prepare` or batch in `XT_Finalize`.
- **Long-running work in `XT_ProcessItem(Ex)` under RVS.** RVS-multi-threaded callbacks should be lean per-call; expensive setup belongs in `XT_Prepare`, expensive teardown in `XT_Finalize`.
- **Forgetting `XT_INIT_QUICKCHECK`.** When `XT_Init` is called with `nFlags & XT_INIT_QUICKCHECK`, return `1` (or `-1` to refuse) without doing real work. X-Ways uses this to ask "are you compatible with me?" before committing to a real load.
- **Negative return from `XT_ProcessItem(Ex)`.** Aborts the iteration. Make sure your normal path returns `0`, not `-1`.
- **Action-code numbering.** Use `XT_ACTION_*` symbols, not custom enums — the per-mode values are easy to misremember.
- **RVS "apply to tagged files only" silently starves per-item callbacks.** If your X-Tension's `XT_ProcessItem(Ex)` never fires under Refine Volume Snapshot — `XT_Prepare` runs, reports a non-zero item count, returns `0x01`, then `XT_Finalize` runs immediately with **zero items processed** — check the RVS dialog's file-scope radio. When **"apply to tagged files only"** is selected and nothing is tagged, X-Ways still invokes `XT_Prepare`/`XT_Finalize` but feeds **no items** to the per-item callbacks. Switch to **"apply selected options to all files"** (or tag the items first). Verified on xwb 21.8 (2026-06-27): in testing, item counts went from `processed=0` to `processed=46` purely by flipping this radio. This is **not** the "already-processed snapshot" skip and **not** a code/flag bug — it's a dialog-scope default that's easy to miss.
- **Mixing disk-I/O and ordinary API surfaces in the same callback.** A single DLL can serve as both an ordinary X-Tension *and* a disk I/O X-Tension, but the API surfaces are disjoint. Inside `XT_SectorIOInit()` the DLL is in disk-I/O mode and only `XWF_SectorIO()` is supported — calling `XWF_CreateItem()` (or other ordinary `XWF_*` functions) there pagefaults (type 216 reported). Build the file tree in an ordinary `XT_Prepare`/`XT_ProcessItem` invocation; keep `XT_SectorIO*` callbacks limited to sector decoding. See [forum-xtensions-distilled.md](forum-xtensions-distilled.md#disk-io-x-tensions-vs-ordinary-x-tensions--api-surface) for details.

## DLL placement and sidecar files

X-Tension DLLs are loaded from wherever the analyst points the picker (*Tools | Run X-Tensions* → persisted by full path in `X-Tensions.txt`) or the `XT:<path>` command-line parameter — they don't need to live in any particular folder relative to X-Ways, and X-Ways does **not** auto-discover DLLs from any folder (confirmed against the manual, the API page, and a live 21.8 install, 2026-07-03). But by convention, every X-Tension is deployed in its own per-tension subfolder under the X-Ways install's `xtensions\` directory — one self-contained bundle at a stable path the analyst registers once:

```text
<X-Ways install>\
├── xwforensics64.exe
├── xtensions\
│   └── xways-mytool\
│       ├── xways-mytool.dll
│       └── mytool.exe               # helper binaries travel in the same subfolder
└── ...
```

Each `build.bat` produces this exact layout under the project-local `xtensions\<name>\` folder — the analyst copies the whole subfolder into the X-Ways install's `xtensions\`.

### Locating the DLL's own directory

X-Tensions that need to find sidecar files (config, helper binaries, data) should resolve them relative to the DLL itself, not relative to the X-Ways executable's directory. Pattern:

```cpp
// Captured in DllMain on DLL_PROCESS_ATTACH
static HMODULE g_hSelf = nullptr;

BOOL APIENTRY DllMain(HMODULE hModule, DWORD reason, LPVOID) {
    if (reason == DLL_PROCESS_ATTACH) g_hSelf = hModule;
    return TRUE;
}

// Get the directory containing this DLL.
static std::wstring GetSelfDirectory() {
    wchar_t path[MAX_PATH] = {0};
    GetModuleFileNameW(g_hSelf, path, MAX_PATH);
    wchar_t* lastSlash = wcsrchr(path, L'\\');
    if (lastSlash) *lastSlash = L'\0';
    return path;
}
```

`GetSelfDirectory() + L"\\<sidecar_name>"` gives the canonical path for cfg files, helper binaries, etc. — matches whatever folder the analyst actually deployed the DLL to.

### Helper binary lookup

Bare filenames in cmdlines that get passed to `CreateProcessW` are resolved per Windows' standard search order, **starting with the directory of the application that loaded the helper** — meaning the X-Ways install dir, NOT the X-Tension DLL's directory. So if the X-Tension wants a helper binary deployed *next to itself* (in `xtensions\`), it needs to either:

1. **Existence-check + rewrite.** If the helper's bare name exists at `<dll_dir>\<helper>`, rewrite the cmd to use the full path before calling `CreateProcessW`. Leave the original cmd alone if the file isn't there (so Windows' standard PATH search still fires for things like `python` from a global Python install). Quote the rewritten path in case the directory contains spaces.
2. **Always full path.** Require absolute paths in the X-Tension's config. Simpler but less portable across analyst machines.
3. **PATH-based.** Require the helper to be on the user's `PATH`. Simplest setup but requires extra configuration step on each analyst's machine.

The `wrapper` template (`templates/x-tensions/wrapper/`) uses approach (1) — see the `ResolveHelperPath` / `ResolveToolPath` helper, which composes the cfg → bundled → PATH → user-prompt chain. A bare-filename helper resolves correctly wherever the analyst drops the per-tension subfolder, and if it doesn't, the X-Tension prompts once and remembers the choice in a sidecar cfg.

### Recursive partner-binary lookup

The fixed-path probes in `ResolveHelperPath` only catch the layouts the X-Tension author thought of (`<dll-dir>\<name>.exe`, `<dll-dir>\tools\<name>.exe`, `<dll-dir>\tools\<name>\<name>.exe`). Analysts often drop the partner binary somewhere reasonable that isn't on the list. A bounded recursive scan under the DLL's own folder is a cheap last resort:

```cpp
// Breadth-first scan under `root` for `targetName`. Returns the shallowest
// match (a copy directly next to the DLL beats one nested under tools\). Caps
// scan depth and total directories visited so an accidental scan over a huge
// case-output subtree stays cheap. Skips well-known nuisance dirs (.git,
// .vs, node_modules, __pycache__) and anything hidden / dotted.
static std::wstring FindSiblingFile(const std::wstring& root,
                                    const wchar_t* targetName,
                                    int maxDepth = 4,
                                    int maxDirsVisited = 256);
```

Use it AFTER the fixed-path probes so a deliberately-placed binary always wins over the scan. Reference implementation: the `wrapper` template (`templates/x-tensions/wrapper/my_xtension.cpp`) — the recursive-fallback branch of `ResolveToolPath`.

### Anchor `GetOpenFileNameW` to the X-Tension folder

The `OPENFILENAMEW` common dialog is anchored, in order:

1. The directory in `lpstrFile` (if it contains one).
2. `lpstrInitialDir` (if set and the directory exists).
3. The **process-wide most-recently-used common-dialog folder** — set as a side effect of the *previous* `GetOpenFileNameW` call in this process, no matter which DLL made it.

Step 3 is the gotcha: if the analyst just used another X-Tension's Browse button (e.g. one pointed at `xtensions\xways-mytool\mytool.exe`), the next X-Tension's Browse dialog opens in *that* folder unless we override. Always set `lpstrInitialDir`:

```cpp
std::wstring initDir;
if (!current.empty()) {
    size_t slash = current.find_last_of(L"\\/");
    if (slash != std::wstring::npos) initDir = current.substr(0, slash);
}
if (initDir.empty()) initDir = GetSelfDirectory();  // anchor on the DLL's own folder

OPENFILENAMEW ofn = {};
// ...
ofn.lpstrInitialDir = initDir.empty() ? nullptr : initDir.c_str();
ofn.Flags          |= OFN_NOCHANGEDIR;  // dialog mustn't mutate process CWD
```

Add `OFN_NOCHANGEDIR` on the same line of thinking — the dialog can change the process current directory as a side effect, which can break later relative-path lookups inside the host.

Reference implementation: the `wrapper` template (`templates/x-tensions/wrapper/my_xtension.cpp`) — `BrowseForFile`. Apply the same `lpstrInitialDir` + `OFN_NOCHANGEDIR` pattern in any X-Tension that calls `GetOpenFileNameW`.

## See also

- [xways-events-api.md](xways-events-api.md) — Events API specifics (`XWF_AddEvent`, subcode tables, etc.).
- [events-viewer-empirical-findings.md](events-viewer-empirical-findings.md) — empirical Events-Viewer findings.
- [templates/x-tensions/cpp/](../templates/x-tensions/cpp/) — minimal C++ scaffold using these patterns.
