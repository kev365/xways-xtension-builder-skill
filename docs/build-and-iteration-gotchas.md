---
source: empirical notes from building X-Tensions with cl/link/rc on Windows and iterating against a live X-Ways install
type: project-pattern
fetched: 2026-05-02
last_updated: 2026-05-02
author: project notes
---

# Build & Iteration Gotchas

Known pitfalls. Each entry: symptom → root cause → fix.

## rc.exe code-page mangling (em-dash → "â€"")

**Symptom:** A non-ASCII character in a `.rc` file (e.g., `CAPTION "bulk_extractor — Settings"`) renders in the dialog title as `bulk_extractor â€" Settings`.

**Root cause:** `rc.exe` reads `.rc` source as **Windows-1252** by default. UTF-8-encoded source files (which the Write tool produces) get misinterpreted — the multi-byte UTF-8 sequence for `—` becomes three Windows-1252 chars.

**Fixes, in order of preference:**

1. **Use ASCII in `.rc` files.** Simplest, no toolchain changes. `bulk_extractor — Settings` → `bulk_extractor - Settings`.
2. **Add a code-page directive at the top of the `.rc`** and save the file as UTF-8 without BOM:
   ```rc
   #pragma code_page(65001)
   ```
3. **Pass `/c 65001` to `rc.exe`** in `build.bat`:
   ```bat
   rc /nologo /c 65001 /fo %NAME%.res %NAME%.rc
   ```
4. **Save the `.rc` as UTF-16 LE with BOM.** `rc.exe` detects the BOM and reads UTF-16 natively. Doesn't play well with the Write tool (always UTF-8).

**Note for `.cpp` source:** the `cl /utf-8` flag in the template's `build.bat` makes the C++ compiler treat both source and execution-charset as UTF-8, so `L"—"` etc. work correctly in `.cpp` files. The mismatch is only in `.rc`.

## DLL locking — no hot-reload

**Symptom:** `LINK : fatal error LNK1104: cannot open file 'my_xtension.dll'` mid-iteration. The DLL exists but can't be overwritten.

**Root cause:** Once X-Ways loads an X-Tension via the picker (or via `XT_INIT_QUICKCHECK`), the DLL is mapped into the X-Ways process and Windows holds a write lock until the process exits. There is **no documented X-Tension unload mechanism** — closing the dialog doesn't unload the DLL.

**Workaround:** Close X-Ways before rebuilding. If you only need to verify code compiles (not link), the cl + rc steps don't touch the DLL — you can run those without closing X-Ways:

```bat
rc /nologo /fo bulk_extractor.res bulk_extractor.rc
cl /nologo /std:c++17 /W3 /EHsc /O2 /utf-8 /DUNICODE /D_UNICODE /c bulk_extractor.cpp
```

`.obj` and `.res` are produced. Then close X-Ways and run the link step.

**Why this matters:** plan iteration cycles around this. Don't expect "edit → rebuild → reload in X-Ways" tight loops. Better workflow: compile-check often, link + reload only when you're ready to test in the UI.

## vcvars64.bat with VS BuildTools 2019

**Symptom:** Calling `vcvars64.bat` prints `'vswhere.exe' is not recognized as an internal or external command`. The env still gets set up correctly afterward — the warning is cosmetic — but it's noisy.

**Root cause:** `vcvars64.bat` looks for `vswhere.exe` on PATH via plain command name, not via the absolute install path. On a clean BuildTools install, `vswhere` lives at `C:\Program Files (x86)\Microsoft Visual Studio\Installer\vswhere.exe` but isn't added to PATH.

**Workaround:** ignore the warning. The env is correct after the script runs. Verify with:

```powershell
where cl    # should find C:\...\VC\Tools\MSVC\<ver>\bin\Hostx64\x64\cl.exe
where rc    # should find C:\...\Windows Kits\10\bin\<sdk>\x64\rc.exe
where link  # should find C:\...\VC\Tools\MSVC\<ver>\bin\Hostx64\x64\link.exe
```

## `build.bat` not found from cmd /c after vcvars

**Symptom:** `'build.bat' is not recognized as an internal or external command` when running `cmd /c "vcvars... && cd /d <dir> && build.bat"`.

**Root cause:** Newer Windows versions don't include the current directory in command resolution by default (`PATHEXT` + cwd). Bare `build.bat` invocation can fail even when you're in the right directory.

**Fix:** Use `.\build.bat` (or call by absolute path):

```bat
cmd /c '... && cd /d <dir> && .\build.bat'
```

When run from a normal "x64 Native Tools Command Prompt" (interactively), `build.bat` works because that prompt's environment is more lenient. The issue only shows up when chaining cmd invocations from PowerShell or MSBuild.

## Bundle in repo: `.gitignore` un-ignore pattern

**Symptom:** Built `xtensions/<xtension>.dll` and bundled `<tool>.exe` get ignored by git despite being intentionally committed.

**Root cause:** Project-wide `.gitignore` has `*.dll`, `*.exe`, `*.lib`, etc. for build artifacts.

**Fix:** Add an explicit un-ignore for each X-Tension's bundle directory at the bottom of `.gitignore`:

```gitignore
# -----------------------------------------------------------------------------
#  Included
# -----------------------------------------------------------------------------

!x-tensions/xways-<name>/xtensions/**
```

Each new X-Tension that ships a bundle needs a corresponding un-ignore line. Subdirectories within the bundle need their own line (gitignore patterns don't auto-recurse).

## String encoding across the API surface

| Surface | Encoding |
| --- | --- |
| `XWF_*` API parameters / results (most) | **UTF-16 wide** (`LPWSTR` / `wchar_t*`) |
| `EventInfo.lpDescr` (Events API) | **UTF-8** (`LPSTR` / `char*`) — the one exception |
| `XWF_OutputMessage` flag bit `0x04` | Treat the message as ANSI (rarely useful) |
| `.rc` source files | Windows-1252 by default (see above) |
| `.cpp` source files (with `cl /utf-8`) | UTF-8 source + UTF-8 execution-charset |
| Sidecar `.cfg` files (convention) | UTF-8 (no BOM) |
| `bulk_extractor` feature files | ANSI / UTF-8 mixed (BE doesn't always escape non-ASCII) |
| `bulk_extractor` `report.xml` | UTF-8 (per XML spec) |

When reading sidecar configs or text output from external tools, decode UTF-8 explicitly with `MultiByteToWideChar(CP_UTF8, ...)`. Don't rely on the C runtime's locale-dependent defaults.

## DLL surface area: only export what you need

`.def` files explicitly list the exported entry points. The X-Ways picker calls these by name:

```text
LIBRARY my_xtension
EXPORTS
    XT_Init
    XT_About
    XT_Prepare
    XT_ProcessItem
    XT_Finalize
    XT_Done
```

If your X-Tension doesn't iterate items, omit `XT_ProcessItem`. If it doesn't need `XT_About`, omit it. X-Ways gracefully handles missing exports (only `XT_Init` is mandatory).

`extern "C"` on the entry-point definitions disables C++ name mangling so the exported names match the `.def`.

## Common stack-trace traps

- **`XWF_AddEvent` from a multi-threaded `XT_ProcessItem(Ex)` callback under RVS** — undocumented thread safety, easy to corrupt state. Pattern: do all event-emission in `XT_Prepare` or batch into `XT_Finalize`. See [events-viewer-empirical-findings.md](events-viewer-empirical-findings.md).
- **Returning a negative value from `XT_ProcessItem(Ex)`** — aborts the iteration. Make sure the normal path returns `0`, not `-1`.
- **Calling `XWF_GetUserInput` from a worker thread** — modal dialog from the wrong thread. Prompt only in `XT_Prepare`.
- **Forgetting `XT_INIT_QUICKCHECK`** — return `1` on `nFlags & 0x20` without doing real work, otherwise X-Ways may incorrectly conclude the X-Tension is incompatible.
- **`XWF_GetWindow` is bounded on both axes.** Empirical (observed 2026-05-03):
  - **`nWndIndex` ≤ 11.** Indices 0, 1, 2, 10, 11 return live HWNDs (`WHXWin` data window, `HexWin` hex pane, `ListView` directory browser, `CollWin` column header, `BtnWnd` button strip respectively); 3..9 safely return `NULL`; 12+ triggers a "page protection fault, high or unknown impact" inside X-Ways' own code — the function reads off the end of an internal sub-handle table.
  - **`nWndNo` < (number of open data windows).** Testing confirmed the crash boundary: with 6 data windows open (5 evidence + Case Root → `nWndNo` 0..5), `nWndNo` 6, 7, 8 each triggered an SEH access violation. The function reads off the end of the open-windows array.
  - **Mitigation.** Cap any sweep at `nWndIndex ≤ 11`. For `nWndNo`, you can either query the value of "how many data windows are open" via some other API (none currently known) or sweep with SEH wrappers + bail after N consecutive empty `nWndNo`s (3 is a reasonable threshold). SEH **does** catch the fault — X-Ways' VEH dialog complains but the X-Tension thread survives. Each AV displays a modal "page protection fault" dialog that the analyst has to dismiss, so prefer to **avoid making the call** when possible.
- **`XWF_GetColumnTitle` "succeeds" past the real column count by leaking string-table entries.** Empirical: when the index exceeds the real column count, the function returns `FALSE` but **leaves the buffer populated with random strings from X-Ways' internal localisation table** (menu items, error messages, dialog strings). Trust **only** rows where the function returned `TRUE`. Empirically X-Ways 21.7 has 62 directory-browser columns (indices 0..61); past that everything is leaked-string-table data.
- **Some property numbers are write-only despite being callable on `XWF_Get*Prop`.** `XWF_GetEvObjProp(hEvidence, 100, pBuf)` does **not** return data — calling it triggers an asynchronous **image-replacement** operation that uses whatever bytes are in `pBuf` as the new image path (per 21.5 SR-5 forum announcement). Testing (2026-05-03) showed that calling it with a zeroed buffer caused X-Ways to fail asynchronously with `Error #10 Cannot access "<evidence working dir>". Access is denied.` — the image-replace logic queues an operation that fires later and can terminate the X-Tension. Same pattern applies to `XWF_GetVSProp` properties **25** (`SET_HASHTYPE1`), **26** (`SET_HASHTYPE2`), and **30** (`SetHasChanged` per xwf-api-rs) — all are write-only despite living on the `Get` function. **Lesson: when sweeping property numbers, blacklist known write-side properties.** A read-only sweep should maintain a `SkipEvObjProp` / `SkipVSProp` blacklist. Any read-side sweep against a binary should treat property numbers as opt-in (whitelist) once the safe set is known, not opt-out.
- **`hVolume` is `NULL` (`0`) when the X-Tension is invoked from the Case Root window** (per 21.4 SR-5 announcement, 2025-05-07 — see [xways-api-history-19-to-21_4.md](xways-api-history-19-to-21_4.md)). Any code that calls `XWF_GetVolumeName(hVolume, ...)`, `XWF_GetVolumeInformation(hVolume, ...)`, or `XWF_OpenItem(hVolume, ...)` without first checking `hVolume != NULL` will AV in the Case Root invocation path. Guard: `if (hVolume && XWF_*) { ... }`. Future X-Tensions should match this pattern.
- **`XWF_SetItemSize` / `SetItemOfs` / `SetItemParent` / `SetItemType` typedefs are wrong in the 2024-05-31 SDK header.** Per 21.3 Preview 4 (2024-09-18 — see [xways-api-history-19-to-21_4.md](xways-api-history-19-to-21_4.md)), these functions **gained return values** indicating success/failure. The 2024-05-31 SDK header (your locally-acquired `X-Tension.h` — see getting-the-sdk.md) still declares them as `void __stdcall`. The fix is to redeclare the function pointer locally in your X-Tension. Use these corrected signatures (project-local override; replace each `void` with the specified return type):

  ```cpp
  // Corrected signatures per 21.3 Preview 4 forum announcement.
  // The SDK header still says VOID — these BOOL/LONG returns are real and worth capturing.
  typedef BOOL (__stdcall *pfn_XWF_SetItemSize)   (LONG nItemID, INT64 nSize);
  typedef BOOL (__stdcall *pfn_XWF_SetItemOfs)    (LONG nItemID, INT64 nDefOfs, INT64 nStartSector);
  typedef BOOL (__stdcall *pfn_XWF_SetItemParent) (LONG nChildItemID, LONG nParentItemID);
  typedef BOOL (__stdcall *pfn_XWF_SetItemType)   (LONG nItemID, const wchar_t* lpTypeDescr, LONG nTypeStatus);
  ```

  The exact return-value semantics (BOOL vs LONG, what 0 vs negative means) are undocumented — verify empirically (log the return value) before relying on them. The same 21.3 Preview 4 announcement also extended `XT_Init`'s return-value catalogue for X-Tensions that handle the "revised meaning of `nOpType`" — that extension is likewise unverified.

  **Watch for stale typedefs in older code:** an X-Tension that declares `pfn_XWF_SetItemType` as `VOID`-returning still works (return value silently ignored) but doesn't capture the new success/failure signal. Update stale typedefs to capture the return value.

## Build environment quick-reference

```bat
REM Find VS install
set VCVARS="C:\Program Files (x86)\Microsoft Visual Studio\2019\BuildTools\VC\Auxiliary\Build\vcvars64.bat"
REM (or VS 2022 Community / Professional / Enterprise / BuildTools — same relative path)

REM Set up env (silenced; the vswhere warning is harmless)
call %VCVARS% >nul 2>&1

REM Build
cd /d <x-tension-dir>
.\build.bat
```

`rc.exe` comes from the Windows SDK (`Windows Kits\10\bin\<sdk-version>\x64\rc.exe`); `cl.exe` and `link.exe` come from VS (`VC\Tools\MSVC\<ver>\bin\Hostx64\x64\`). Both are added to PATH by `vcvars64.bat`.

## See also

- [xtension-invocation.md](xtension-invocation.md) — entry points, return values, action codes.
- [external-tool-integration.md](external-tool-integration.md) — wrapping CLI tools as X-Tensions.
- [xways-user-input-and-dialogs.md](xways-user-input-and-dialogs.md) — Win32 dialog patterns.
