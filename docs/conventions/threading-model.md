# Threading model

!!! danger "Run on X-Ways' thread — don't call `XWF_*` from a worker thread you spawned"
    X-Ways invokes your entry points on **its own thread** and expects the work to happen there.
    Spawning a `std::thread` to do the run while the entry point returns — so a settings dialog
    stays "responsive" — means `XWF_AddEvent`, `XWF_OpenItem/Read/Close`, `XWF_GetItemInformation`,
    `XWF_Label`, etc. get called **off X-Ways' thread**, concurrently with the host.
    `XWF_AddEvent`'s thread-safety is undocumented; off-thread calls can corrupt the event store or
    crash the host. **Run synchronously.**

**Background:** [xtension-invocation.md](../xtension-invocation.md) — "Threading & UI responsiveness":
*never call `XWF_AddEvent` from a multi-threaded context; do event emission in `XT_Prepare` or
`XT_Finalize`.* Note the RVS worker pool is X-Ways' own threading — that's fine; the trap is a worker
thread **you** create. (Empirically confirmed safe on xwb 21.8, 2026-06-27: self-calling
`XWF_OpenItem`/`Read`/`Close` on the RVS pool, across both open flags and archive children to
depth 5, with zero failures. A "never self-open on a worker thread" claim from
[JamieSharpe/XT_MT](https://github.com/JamieSharpe/XT_MT) does **not** reproduce on 21.8.)

**Reference implementation:**
[xways-linux-logs](https://github.com/kev365/xways-linux-logs) (`xways-linux-logs.cpp` →
`XT_Finalize`, request-then-run) — the job runs synchronously on X-Ways' thread instead of on a
spawned `std::thread`, so `XWF_AddEvent` is never called off-thread.

## Pattern

A settings dialog should **capture settings and request a run**, then let the entry point run the job
synchronously after the dialog returns — the dialog proc and `XT_Finalize` are already on X-Ways'
thread:

```cpp
// In the dialog's Run handler: don't spawn a thread — record intent and close.
case IDOK:
    g_runSettings = CollectSettingsFromDlg(hDlg);
    g_doRun = true;
    EndDialog(hDlg, IDOK);
    return TRUE;

// XT_Finalize: run synchronously on X-Ways' own thread after the dialog closes.
LONG __stdcall XT_Finalize(HANDLE hVolume, HANDLE hEvidence, DWORD, void*) {
    g_doRun = false;
    DialogBoxParamW(g_hSelf, MAKEINTRESOURCEW(IDD_SETTINGS), g_hMainWnd, SettingsDlgProc, 0);
    if (g_doRun) RunJob(g_runSettings, /* … */);   // XWF_AddEvent now on X-Ways' thread
    return 0;
}
```

Report progress via the **Messages window** (`XWF_OutputMessage`) — it updates live during a
synchronous run; you don't need a worker thread for a progress bar. For long enumeration loops on the
**main** thread (Run/DBC), pump messages periodically so Windows doesn't mark the host "Not
Responding" — see the heartbeat pattern in [xtension-invocation.md](../xtension-invocation.md).

## Variant: run in-place in the dialog (keep it open, show progress)

When the analyst wants the **settings dialog to stay up and show progress** (rather than
close-then-run), run the job **synchronously inside the dialog's Run handler** — the dialog proc is
already on X-Ways' thread, so every `XWF_*` call (e.g. an evidence-object add-back via
`XWF_CreateEvObj`) stays on the correct thread. No worker needed. The shape:

- On Run: **disable all buttons**, set a marquee progress bar going, relabel Run → "Running…",
  set a `g_running` guard, and call the run pipeline **without** `EndDialog`.
- The pipeline's `RunCommand` / `PumpMessages` keep the dialog repainting + the marquee animating
  (see [subprocess-stdio](subprocess-stdio.md)); update a status line per phase.
- **Guard close while running** — ignore `IDCANCEL`/`WM_CLOSE` when `g_running` so the analyst can't
  tear down the dialog mid-run.
- On completion: stop the marquee, show the result, relabel Run → "Done" (disabled) and Cancel →
  "Close"; the dialog stays open until the analyst closes it.

!!! note "A worker thread is fine *only* if it never touches `XWF_*`"
    Pure-subprocess work (run a tool, read a pipe, `PostMessage` progress back to the dialog) is safe
    off-thread — such a worker makes **zero** `XWF_*` calls, so the rule above isn't violated. The
    moment a thread would call `XWF_AddEvent` / `XWF_CreateEvObj` / `XWF_OpenItem`, keep it on
    X-Ways' thread.

## Do / Don't

- **Do** run the job synchronously in `XT_Prepare` (one-shot) or `XT_Finalize` (after a dialog).
- **Do** emit events (`XWF_AddEvent`) from `XT_Prepare`/`XT_Finalize` on X-Ways' thread.
- **Do** use `XWF_OutputMessage` for progress instead of a dialog progress bar driven by a worker.
- **Don't** spawn a `std::thread`/worker that calls any `XWF_*` function.
- **Don't** confuse this with the RVS worker pool — *that* is X-Ways calling you multi-threaded (see
  [item collection](item-collection.md)); the rule here is about threads **you** create.

See also: [Item collection](item-collection.md), [Events emission](events-emission.md).
