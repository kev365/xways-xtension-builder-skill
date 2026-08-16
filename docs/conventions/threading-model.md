---
source: extracted from the wrapper template (templates/x-tensions/wrapper/) and working X-Tensions
type: convention
last_updated: 2026-08-16
author: project
---

# Threading model

!!! danger "Run on X-Ways' thread — don't call `XWF_*` from a worker thread you spawned"
    X-Ways invokes your entry points on **its own thread** and expects the work to happen there.
    Spawning a `std::thread` to do the run while the entry point returns — so a settings dialog
    stays "responsive" — means `XWF_AddEvent`, `XWF_OpenItem/Read/Close`, `XWF_GetItemInformation`,
    `XWF_Label`, etc. get called **off X-Ways' thread**, concurrently with the host.
    `XWF_AddEvent`'s thread-safety is undocumented; off-thread calls can corrupt the event store or
    crash the host. **Run synchronously.**

**Background:** [xtension-invocation.md](../xtension-invocation.md) — "Threading" and "Keeping X-Ways responsive during long synchronous work":
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

## Contents

- Pattern
- Variant: run in-place in the dialog (keep it open, show progress)
- The host watches for hanging refinement threads (v21.8 Preview 5)
- Python X-Tensions are single-threaded by construction
- Do / Don't

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

## The host watches for hanging refinement threads (v21.8 Preview 5)

Since **2026-03-26**, X-Ways monitors additional threads during volume snapshot
refinement and attempts to **terminate and resume** any it finds unresponsive
for **~15 minutes** (the announcement offers 15 min as an example, not a
documented constant). Source: the 21.8 announcement thread, distilled in
[forum-xtensions-distilled.md](../forum-xtensions-distilled.md).

Running synchronously on X-Ways' thread — which this page tells you to do — is
therefore not a licence to block indefinitely. Work that can take tens of
minutes (a slow helper process, a large archive) should report progress and be
interruptible rather than sit in an unbounded wait.

**Scope unverified.** "Additional threads" is not defined, so it is unknown
whether the watchdog covers the thread running `XT_Finalize` or only the
multi-threaded file-examination workers, nor what "terminate and resume" does to
an in-flight X-Tension call. Treat it as a reason to bound long waits, not as a
measured limit.

## Python X-Tensions are single-threaded by construction

A C++ X-Tension chooses its threading by returning `1` or `2` from `XT_Init`. A
Python X-Tension never gets that choice: the `XT_Python.dll` bridge hard-returns
**`1`** with the vendor's own source comment — *"not thread-safe, since the
global state is stored in a few global variables"* — and dispatches every
callback by running generated source against one shared interpreter dict, with
no GIL management. Your script's `XT_Init` return value is not propagated.

So never design a Python X-Tension around concurrent `XT_ProcessItem(Ex)`
delivery; it cannot happen with the stock bridge. Details in
[xways-python-bridge.md](../xways-python-bridge.md).

## Do / Don't

- **Do** run the job synchronously in `XT_Prepare` (one-shot) or `XT_Finalize` (after a dialog).
- **Do** bound long waits and surface progress — the host may terminate a thread it judges hung (see above).
- **Do** emit events (`XWF_AddEvent`) from `XT_Prepare`/`XT_Finalize` on X-Ways' thread.
- **Do** use `XWF_OutputMessage` for progress instead of a dialog progress bar driven by a worker.
- **Don't** spawn a `std::thread`/worker that calls any `XWF_*` function.
- **Don't** confuse this with the RVS worker pool — *that* is X-Ways calling you multi-threaded (see
  [item collection](item-collection.md)); the rule here is about threads **you** create.

See also: [Item collection](item-collection.md), [Events emission](events-emission.md).
