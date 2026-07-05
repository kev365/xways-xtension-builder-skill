# VERBOSE logging

Every X-Tension exposes a single `VERBOSE` constant near the top of its main
file and a `LogVerbose` / `_log_verbose` helper that is a no-op when the flag
is `false`. Flip the one constant to silence per-item diagnostics before
sharing externally or running on a large snapshot — **do not remove the call
sites**.

## Pattern

=== "C++"

    Extracted from `templates/x-tensions/cpp/my_xtension.cpp` → `VERBOSE`,
    `Log`, `LogVerbose`:

    ```cpp
    // Keep VERBOSE = true during development. Flip to false before sharing or
    // running on a large snapshot to keep the Messages window quiet. Do not remove
    // the LogVerbose call sites -- the flag toggles them at zero cost.
    static constexpr bool VERBOSE = true;

    static void Log(const std::wstring& msg) {
        std::wstring line = L"[";
        line += NAME; line += L"] "; line += msg;
        if (XWF_OutputMessage) XWF_OutputMessage(line.c_str(), 0);
    }
    static void LogVerbose(const std::wstring& msg) { if (VERBOSE) Log(msg); }

    // Usage (in XT_ProcessItemEx):
    LogVerbose(buf);  // per-hit detail -- verbose-only
    ```

=== "Python"

    Extracted from `templates/x-tensions/python/xtension.py` → `VERBOSE`,
    `_log`, `_log_verbose`:

    ```python
    # Keep VERBOSE = True during development. Flip to False before sharing or
    # running on a large snapshot to keep the Messages window quiet. Do not remove
    # the _log_verbose call sites -- the flag toggles them at zero cost.
    VERBOSE = True

    def _log(msg):
        """Visible in the X-Ways Messages window AND in the console (if allocated)."""
        try:
            xwf.OutputMessage(f"[{NAME}] {msg}", 0)
        except Exception:
            pass
        print(f"[{NAME}] {msg}")

    def _log_verbose(msg):
        """Per-item / per-row diagnostics. No-op when VERBOSE is False."""
        if VERBOSE:
            _log(msg)

    # Usage (in XT_ProcessItemEx):
    _log_verbose(f"hit on item {nItem}: {hit}")
    ```

**Source of truth:** `templates/x-tensions/cpp/my_xtension.cpp` → `VERBOSE` / `Log` / `LogVerbose`; `templates/x-tensions/python/xtension.py` → `VERBOSE` / `_log` / `_log_verbose`

## Do / Don't

- **Do** put `VERBOSE` as close to the top of the file as possible — one-line change to silence everything.
- **Do** keep `LogVerbose` / `_log_verbose` call sites intact; removing them loses diagnostic coverage.
- **Do** use `Log` / `_log` for one-line summary output that is always safe to show (counts, path chosen, errors).
- **Do** use `LogVerbose` / `_log_verbose` for per-item, per-row, and per-event diagnostics.
- **Don't** gate a `Log` call that prints error or summary information behind `VERBOSE` — analysts need errors regardless.
- **Don't** set `VERBOSE = false` in a template or shared file — templates ship with `true`; flip it only in a deployed build.
