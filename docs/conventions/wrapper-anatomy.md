# CLI-wrapper anatomy

Every X-Tension that wraps an external command-line tool follows a six-element
anatomy. The canonical implementation is the `wrapper` template (`templates/x-tensions/wrapper/`).

## The six elements

1. **`RunSettings` struct** — sidecar config payload (fields map 1:1 to `key = value` cfg lines).
2. **`RunState` global** — holds per-run transient state: volume/evidence handles, resolved exe path, temp dirs, counters.
3. **`LoadCfg` (+ `SaveCfg`)** — tiny `key=value` parser/writer; reads the cfg file next to the DLL; initialises a `RunSettings` in-place.
4. **`XT_Prepare`** — reset `RunState`, log, call `LoadCfg`, resolve the helper exe via `ResolveToolPath`, create temp/output dirs, return `0x01` to request per-item callbacks.
5. **`XT_ProcessItem`** — **collect only.** Push each `nItemID` onto the accumulator so the list honours the active filter and the right-click selection; poll `XWF_ShouldStop` every 1024 items. Export `XT_ProcessItemEx` as a **no-op stub** — see the note below.
6. **`XT_Finalize`** — the actual run: MZ/size gate → extract item bytes to a temp file → spawn the subprocess → parse output → tag items via `XWF_Label` → log stats, clean up temp dirs, reset `RunState`.

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

Extracted from the `wrapper` template (`templates/x-tensions/wrapper/my_xtension.cpp`) — `RunStats`, `RunState`,
the `LoadCfg` call in `XT_Prepare`, and the `XT_Finalize` stats log; and the
`RunSettings` struct in the same file:

```cpp
// Element 1: RunSettings — sidecar config payload
struct RunSettings {
    std::wstring tool_exe;                          // override for tools\mytool\mytool.exe
    std::wstring tool_extra_args;                   // free-form extra args ("-r ./rules" etc.)
    bool         tag_per_capability    = true;
    bool         tag_scanned_no_match  = false;
    INT64        min_pe_size_bytes     = 1024;
    INT64        max_pe_size_bytes     = 256LL * 1024 * 1024;
};

// Element 2: RunState — per-run transient state
struct RunStats {
    size_t pe_seen = 0; size_t pe_scanned = 0; size_t pe_matched = 0;
    size_t pe_skipped_size = 0; size_t tool_failures = 0; size_t tags_added = 0;
};
struct RunState {
    HANDLE       hVolume = nullptr; HANDLE hEvidence = nullptr;
    DWORD        nOpType = 0;
    RunSettings  settings;
    std::wstring runDir; std::wstring inDir; std::wstring outDir;
    std::wstring toolExe;   // resolved once in XT_Prepare
    RunStats     stats;
};
static RunState g_run;

// Element 4: XT_Prepare — init, load cfg, resolve exe, create dirs
LONG __stdcall XT_Prepare(HANDLE hVolume, HANDLE hEvidence, DWORD nOpType, void*) {
    g_run = RunState{};
    g_run.hVolume = hVolume; g_run.hEvidence = hEvidence; g_run.nOpType = nOpType;
    std::wstring cfgPath = GetSelfDirectory() + L"\\my_xtension.cfg";
    LoadCfg(cfgPath, g_run.settings);                          // Element 3
    g_run.toolExe = g_run.settings.tool_exe.empty()
                  ? ResolveToolPath(L"mytool", L"mytool.exe")  // resolve helper exe (see Tool resolution)
                  : g_run.settings.tool_exe;
    // ... create run/in/out dirs, return callback flags ...
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
    Log(FormatW(L"mytool summary: pe_seen=%zu scanned=%zu matched=%zu "
                L"skipped_size=%zu failures=%zu tags=%zu",
                g_run.stats.pe_seen, g_run.stats.pe_scanned, g_run.stats.pe_matched,
                g_run.stats.pe_skipped_size, g_run.stats.tool_failures, g_run.stats.tags_added));
    Log(L"done. outputs: " + g_run.runDir);
    g_run = RunState{};
    return 0;
}
```

**Source of truth:** the `wrapper` template (`templates/x-tensions/wrapper/my_xtension.cpp`) → `RunSettings`, `RunStats`, `RunState`, `Collected`, `XT_Prepare`, `XT_ProcessItem`, `XT_ProcessItemEx`, `XT_Finalize`

## Do / Don't

- **Do** reset `RunState` to a default-constructed value at the top of `XT_Prepare` (`g_run = RunState{};`) so stale state from a previous run never leaks.
- **Do** resolve the helper exe once in `XT_Prepare` and store it in `RunState` — do not re-resolve per item.
- **Do** create all temp/output dirs in `XT_Prepare`; bail early and return 0 if any creation fails (no dirs → no items processed).
- **Do** log a one-line summary (counts) in `XT_Finalize`; it's the only feedback the analyst sees after a headless RVS run.
- **Do** prefer `XWF_Label` for tagging and keep `XWF_AddToReportTable` only as an explicit older-host fallback — resolve `XWF_Label` with `GetProcAddress` *without* counting it as a missing import, since pre-rename hosts legitimately lack it.
- **Don't** return `0x01 | 0x04` to "get both callbacks" — `0x04` is `EXPECTMOREITEMS`. Returning it when you create no items misleads the host, and it does nothing for callback selection.
- **Don't** do the per-item work in both `XT_ProcessItem` and `XT_ProcessItemEx` — both fire for every item under `0x01`, which is the 2N double-count.
- **Don't** do file I/O or subprocess spawning inside `XT_Init` — that runs before the volume is open.
- **Don't** leave temp extraction dirs on disk after `XT_Finalize` for successful runs — clean up to avoid filling the analyst's drive.

See also: [Tool resolution](tool-resolution.md) for how `ResolveToolPath` works.
