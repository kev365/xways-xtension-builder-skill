# CLI-wrapper anatomy

Every X-Tension that wraps an external command-line tool follows a six-element
anatomy. The canonical implementation is the `wrapper` template (`templates/x-tensions/wrapper/`).

## The six elements

1. **`RunSettings` struct** — sidecar config payload (fields map 1:1 to `key = value` cfg lines).
2. **`RunState` global** — holds per-run transient state: volume/evidence handles, resolved exe path, temp dirs, counters.
3. **`LoadCfg` (+ `SaveCfg`)** — tiny `key=value` parser/writer; reads the cfg file next to the DLL; initialises a `RunSettings` in-place.
4. **`XT_Prepare`** — reset `RunState`, log, call `LoadCfg`, resolve the helper exe via `ResolveToolPath`, create temp/output dirs, return item-callback flags.
5. **`XT_ProcessItem(Ex)`** — MZ/size gate → extract item bytes to temp file → spawn subprocess → parse output → tag item via `XWF_AddToReportTable`.
6. **`XT_Finalize`** — log per-item stats, clean up temp dirs, reset `RunState`.

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
    return 0x01 | 0x04;  // XT_ProcessItem + XT_ProcessItemEx
}

// Element 6: XT_Finalize — stats + cleanup
LONG __stdcall XT_Finalize(HANDLE, HANDLE, DWORD, void*) {
    Log(FormatW(L"mytool summary: pe_seen=%zu scanned=%zu matched=%zu "
                L"skipped_size=%zu failures=%zu tags=%zu",
                g_run.stats.pe_seen, g_run.stats.pe_scanned, g_run.stats.pe_matched,
                g_run.stats.pe_skipped_size, g_run.stats.tool_failures, g_run.stats.tags_added));
    Log(L"done. outputs: " + g_run.runDir);
    g_run = RunState{};
    return 0;
}
```

**Source of truth:** the `wrapper` template (`templates/x-tensions/wrapper/my_xtension.cpp`) → `RunSettings`, `RunStats`, `RunState`, `XT_Prepare`, `XT_Finalize`

## Do / Don't

- **Do** reset `RunState` to a default-constructed value at the top of `XT_Prepare` (`g_run = RunState{};`) so stale state from a previous run never leaks.
- **Do** resolve the helper exe once in `XT_Prepare` and store it in `RunState` — do not re-resolve per item.
- **Do** create all temp/output dirs in `XT_Prepare`; bail early and return 0 if any creation fails (no dirs → no items processed).
- **Do** log a one-line summary (counts) in `XT_Finalize`; it's the only feedback the analyst sees after a headless RVS run.
- **Don't** do file I/O or subprocess spawning inside `XT_Init` — that runs before the volume is open.
- **Don't** leave temp extraction dirs on disk after `XT_Finalize` for successful runs — clean up to avoid filling the analyst's drive.

See also: [Tool resolution](tool-resolution.md) for how `ResolveToolPath` works.
