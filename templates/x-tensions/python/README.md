# Python X-Tension Template

Starting point for an X-Tension written in Python, targeting **X-Ways Forensics 21.8+** with `XT_Python.dll`.

## Use this template

1. Copy the whole `python/` folder to `x-tensions/<your_xtension_name>/` (lowercase, snake_case) — that is the *source* location; deployment is different, see below.
2. Rename `xtension.py` → `<your_xtension_name>.py` — **the stem must be a legal Python module name: letters/digits/underscores only, no hyphens.** The bridge loads your script by executing `import <filestem>`, so `xways-foo.py` can never load (`import xways-foo` is a syntax error — the Messages window shows `Failed to execute import ...` for every entry point). Use `xways_foo.py`. (`new-xtension.ps1` does this for you.)
3. Update the `NAME`, `VERSION`, and `DESCRIPTION` constants in the script.
4. Edit `XT_About` text.
5. Implement logic inside `XT_ProcessItem` / `XT_Prepare` as needed.

## Files

- `xtension.py` — main X-Tension script (entry points + skeleton).
- `helpers.py` — pure-Python helpers, kept separate so logic is portable to C++ later.
- `requirements.txt` — optional third-party packages (empty by default).

## Runtime prerequisites

- `XT_Python.dll` and matching `pythonXYZ.dll` must sit next to X-Ways Forensics (both ship in the SDK download — see [getting-the-sdk.md](../../../docs/getting-the-sdk.md)). The current bundle links **`python312.dll`** — verified from the DLL's import table, since the bundle's own readme misstates the version; check the shipped `pythonXYZ.dll` name for any future bundle. A matching system-wide Python install is also required (the embedded interpreter needs its standard library — a per-user-only install may not be found; verified 2026-08-16). Full bridge reference: [xways-python-bridge.md](../../../docs/xways-python-bridge.md).
- **Deploy your `.py` files (entry script + `helpers.py`) into the X-Ways main folder** — next to the EXE, not an `xtensions\` subfolder. The bridge adds nothing to `sys.path`, so a script registered from any other folder fails at `import` (verified live 2026-08-16). The `x-tensions/<name>/` folder in your project is the *source tree*; copying it into the install does not work for Python the way it does for DLLs.
- To register your script: add `XT_Python.dll` to the X-Tensions list, then use its **About** gesture — the bridge's `XT_About` *is* the script picker (a multi-select `.py` dialog that writes `Python.cfg` next to the X-Ways EXE). Running the DLL via **Tools → Run X-Tension** executes whatever scripts `Python.cfg` already lists.

## Entry points implemented

`XT_Init`, `XT_About`, `XT_Prepare`, `XT_ProcessItem`, `XT_ProcessItemEx`, `XT_ProcessSearchHit`, `XT_Finalize`, `XT_Done`.

## Logging

Two helpers in `xtension.py`:

- `_log(msg)` — always prints. Use for one-line summaries.
- `_log_verbose(msg)` — prints only when the module-level `VERBOSE` constant is `True`. Use for per-item, per-row diagnostics.

`VERBOSE = True` by default so you get full traces while developing. Flip to `False` before sharing or running on a huge snapshot — call sites stay in place and switch off at zero cost.

## Conventions

- Keep `XT_*` functions thin — delegate real work to `helpers.py` so the logic is easy to port to C++ if performance ever matters.
- Use `xwf.OutputMessage(...)` for user-visible messages, `print(...)` for console debug (requires `xwf.AllocConsole()` + `OutputRedirector`).
- Return values matter: several entry points expect specific integer return codes — see the official API page.
