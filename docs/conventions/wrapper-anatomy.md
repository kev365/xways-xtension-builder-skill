---
source: extracted from the wrapper template (templates/x-tensions/wrapper/) and working X-Tensions
type: convention
last_updated: 2026-08-16
author: project
---

# CLI-wrapper anatomy

Every X-Tension that wraps an external command-line tool follows a six-element
anatomy. The canonical implementation is the `wrapper` template (`templates/x-tensions/wrapper/`).

## Contents

- The six elements
- Pattern
- Do / Don't

## The six elements

1. **`Settings` struct** — sidecar config payload (fields map 1:1 to `key = value` cfg lines).
2. **`RunCtx` / `Collected`** — per-run transient state: volume/evidence handles, invocation mode, and the accumulated item list.
3. **`LoadCfg` (+ `SaveSettingsToCfg`)** — tiny `key=value` parser/writer; reads the cfg file next to the DLL; initialises a `Settings` in-place.
4. **`XT_Prepare`** — reset state, log, call `LoadCfg`, resolve the helper exe (`ResolveDefaultTool`, unless the cfg override is set), create temp/output dirs, return `0x01` to request per-item callbacks. (Under `XT_ACTION_RUN` — op 0, Tools → Run X-Tension — X-Ways delivers **no** per-item callbacks despite the `0x01`; the collector fills only under RVS and DBC. Confirmed live 21.8 SR-5 + 21.9 Beta 1 — see [xtension-invocation.md](../xtension-invocation.md).)
5. **`XT_ProcessItem`** — **collect only.** Push each `nItemID` onto the accumulator so the list honours the active filter and the right-click selection; poll `XWF_ShouldStop` every 1024 items. Export `XT_ProcessItemEx` as a **no-op stub** — see the note below.
6. **`XT_Finalize`** — the actual run: MZ/size gate → extract item bytes to a temp file → spawn the subprocess → parse output → tag items via `XWF_Label` → log stats, clean up temp dirs, reset state.

Three things about elements 4–6 are easy to get wrong:

- **Return `0x01`, not `0x01 | 0x04`.** `0x04` is `EXPECTMOREITEMS` (you will
  *create* items), not "also call the `Ex` variant". `0x01` alone already
  delivers each item to **every** per-item callback you export. Full rationale:
  [item-collection.md](item-collection.md).
- **Both exported callbacks fire for every item.** That is why the template's
  `XT_ProcessItemEx` is an exported no-op returning `0` — it keeps the export
  present for hosts that look for it without double-counting. Do the per-item
  work in exactly one callback, or dedup by item ID.
- **The work runs in `XT_Finalize`, on X-Ways' own thread.** The per-item
  callbacks are multi-threaded under RVS and are used only to accumulate IDs.
  See [threading-model.md](threading-model.md).

## Pattern

Extracted from the `wrapper` template (`templates/x-tensions/wrapper/my_xtension.cpp`) — the
`Settings` and `Collected` structs, `XT_Prepare`, the per-item callbacks, and
`XT_Finalize`:

```cpp
// Element 1: Settings — sidecar config payload, one field per cfg key
struct Settings {
    std::wstring toolExe;              // resolved absolute path to <yourtool>.exe
    std::wstring toolVersion;          // detected version banner (display-only)
    std::wstring outputBase;           // base dir; runDir = outputBase\run-...
    INT64        minSizeBytes = 1;     // scope filters, applied before we hand
    INT64        maxSizeMiB   = 256;   // any bytes to the tool
    std::wstring extraArgs;            // free-form pass-through
    bool         addToReportTable = true;
    bool         addComment       = true;
    int          tagThreshold     = 1;
    bool         verbose          = true;   // toggles Log vs LogVerbose
};

// Element 2: Collected — the item accumulator, filled by XT_ProcessItem and
// consumed in XT_Finalize. RunCtx carries the same handles into the dialog.
struct Collected {
    bool              ready = false;
    bool              aborted = false;   // analyst hit Stop/Esc during enumeration
    HANDLE            hVolume = nullptr;
    HANDLE            hEvidence = nullptr;
    InvocationMode    invocationMode = InvocationMode::Run;
    std::vector<LONG> items;
};
static Collected g_collected;

// Element 4: XT_Prepare — init, load cfg, resolve exe, create dirs
LONG __stdcall XT_Prepare(HANDLE hVolume, HANDLE hEvidence, DWORD nOpType, void*) {
    g_collected = Collected{};
    g_collected.ready     = true;
    g_collected.hVolume   = hVolume;
    g_collected.hEvidence = hEvidence;
    std::wstring cfgPath = GetSelfDirectory() + L"\\my_xtension.cfg";
    LoadCfg(cfgPath, g_settings);                   // Element 3
    if (g_settings.toolExe.empty() || !FileExists(g_settings.toolExe))
        g_settings.toolExe = ResolveDefaultTool();  // see Tool resolution
    // ... create run/in/out dirs ...
    return 0x01;  // CALLPI — request per-item callbacks. NOT 0x01|0x04.
}

// Element 5: XT_ProcessItem — collect IDs only; Ex is a no-op so both
// exported callbacks firing per item cannot double-count.
LONG __stdcall XT_ProcessItem(LONG nItemID, void*) {
    if (!g_collected.ready) return 0;
    g_collected.items.push_back(nItemID);
    if ((g_collected.items.size() & 0x3FF) == 0 && XWF_ShouldStop && XWF_ShouldStop()) {
        g_collected.aborted = true;
        return -1;
    }
    return 0;
}
LONG __stdcall XT_ProcessItemEx(LONG, HANDLE, void*) { return 0; }

// Tagging (inside the XT_Finalize run): prefer XWF_Label, fall back to the
// pre-rename XWF_AddToReportTable so pre-SR hosts still tag.
if (XWF_Label) XWF_Label(nItemID, tableName, 0);
else if (XWF_AddToReportTable) XWF_AddToReportTable(nItemID, tableName, 0);

// Element 6: XT_Finalize — run the collected items, then stats + cleanup.
// This is where the extract/spawn/parse/tag work happens, on X-Ways' thread.
LONG __stdcall XT_Finalize(HANDLE, HANDLE, DWORD, void*) {
    if (g_collected.ready && !g_collected.aborted) ShowDialogAndRun(g_collected);
    Log(FormatW(L"summary: seen=%zu scanned=%zu matched=%zu tags=%zu",
                stats.seen, stats.scanned, stats.matched, stats.tagsAdded));
    g_collected = Collected{};
    return 0;
}
```

The template keeps its run counters on the worker context (`WorkerCtx`) rather
than in a standalone stats struct, since the worker writes them and the dialog
reads them on completion.

**Source of truth:** the `wrapper` template (`templates/x-tensions/wrapper/my_xtension.cpp`) → `Settings`, `RunCtx`, `Collected`, `LoadCfg`, `SaveSettingsToCfg`, `ResolveDefaultTool`, `XT_Prepare`, `XT_ProcessItem`, `XT_ProcessItemEx`, `XT_Finalize`

## Do / Don't

- **Do** reset the accumulator to a default-constructed value at the top of `XT_Prepare` (`g_collected = Collected{};`) so stale state from a previous run never leaks.
- **Do** resolve the helper exe once in `XT_Prepare` and store it in `Settings.toolExe` — do not re-resolve per item.
- **Do** create all temp/output dirs in `XT_Prepare`; bail early and return 0 if any creation fails (no dirs → no items processed).
- **Do** log a one-line summary (counts) in `XT_Finalize`; it's the only feedback the analyst sees after a headless RVS run.
- **Do** prefer `XWF_Label` for tagging and keep `XWF_AddToReportTable` only as an explicit older-host fallback — resolve `XWF_Label` with `GetProcAddress` *without* counting it as a missing import, since pre-rename hosts legitimately lack it.
- **Don't** return `0x01 | 0x04` to "get both callbacks" — `0x04` is `EXPECTMOREITEMS`. Returning it when you create no items misleads the host, and it does nothing for callback selection.
- **Don't** do the per-item work in both `XT_ProcessItem` and `XT_ProcessItemEx` — both fire for every item under `0x01`, which is the 2N double-count.
- **Don't** do file I/O or subprocess spawning inside `XT_Init` — that runs before the volume is open.
- **Don't** leave temp extraction dirs on disk after `XT_Finalize` for successful runs — clean up to avoid filling the analyst's drive.

See also: [Tool resolution](tool-resolution.md) for how `ResolveDefaultTool` works, and for the richer shared-tools-tree variant that is *not* in the template.
