# C++ X-Tension Template

Minimal, self-contained C++ starting point for an X-Ways Forensics 21.7+ X-Tension (Windows x64). Resolves XWF exports via `GetProcAddress`, so there is **no build-time dependency** on the SDK's BG\* helper files — only the Windows SDK.

## Files

- `my_xtension.cpp` — entry points (`XT_Init` … `XT_Done`) and a small `XWF_*` pointer table.
- `my_xtension.def` — module-definition file so the exported names are `XT_Init` (not `?XT_Init@@…`).
- `build.bat` — one-shot MSVC build. Produces `my_xtension.dll`.

## Use this template

Scaffold a copy with the skill's
[`new-xtension.ps1`](../../../.claude/skills/xways-xtension-authoring/scripts/new-xtension.ps1)
(`-Template cpp`) — it copies the folder, renames the `my_xtension.*` files, and sets
the identity constants. To do it by hand:

1. Copy the whole `cpp/` folder to your X-Tension's working folder.
2. Rename the three `my_xtension.*` files to `<your_xtension_name>.*`.
3. In the renamed `.bat` and `.def`, change `my_xtension` to your new name.
4. In the renamed `.cpp`, update the `NAME` / `VERSION` / `DESCRIPTION` / `REPORT_TABLE` constants and implement your logic inside `XT_ProcessItem` (or `XT_ProcessItemEx` if you need a read-handle to item data).
5. Open **"x64 Native Tools Command Prompt for VS 2022"**, `cd` into the folder, run `build.bat`. On success you'll have `<name>.dll` next to the sources.
6. In X-Ways: **Tools → Run X-Tension…** → **+** → select the `.dll`.

## Adding more XWF\_ functions

Only the exports actually used by the template are declared at the top of the `.cpp`. To add another (e.g. `XWF_GetItemInformation`):

1. Open your local SDK header (`X-Tension.h` — see [getting-the-sdk.md](../../../docs/getting-the-sdk.md) for where to download it) and copy the `typedef ... fptr_XWF_…` signature.
2. Add a matching `pfn_` typedef + `static` pointer near the top of your `.cpp`.
3. Add one more `Resolve<…>(h, "XWF_…", missing)` line inside `RetrieveFunctionPointers`.

Don't invent signatures — `X-Tension.h` is authoritative and tracks real changes as the API evolves. Route every `XWF_*` question through the skill's [API guardrail](../../../.claude/skills/xways-xtension-authoring/references/api-guardrail.md).

## Per-X-Tension output folder

`DefaultOutputDir(caseRoot)` returns `<caseRoot>\<NAME>\`. The case root comes from `GetCaseRootDir()` (via `XWF_GetCaseProp` property 6). This is the **project-wide convention** for analyst-facing output:

- Use it as the default for any "output dir" edit field or hardcoded write path.
- Create the folder on demand via `SHCreateDirectoryExW` when Run fires.
- Don't override an already-saved `output_dir` in a cfg — only seed this default when the field is empty.

Rationale: case roots otherwise accumulate evidence dirs, `.xfc` files, and every X-Tension's outputs at the same level. The subfolder keeps each tool's artifacts contiguous and easy to archive. Full convention: [docs/conventions/output-dir.md](../../../docs/conventions/output-dir.md).

## Temp-folder helper

`GetTempBase(hEvidence)` near the top of the `.cpp` returns X-Ways' configured working directory for the current evidence (via `XWF_GetEvObjProp` property 12), falling back to Windows `%TEMP%` if the call fails. **Use it instead of `GetTempPathW` directly** when your X-Tension writes scratch files — that way forensic-shop policy about temp-data location (D: drive, encrypted volume, etc.) is honored automatically because X-Ways exposes whatever the analyst set in General Options → Folders.

Property numbers for `XWF_GetCaseProp` / `XWF_GetEvObjProp` aren't in `X-Tension.h` — they live only on the live API page. See [docs/xways-getprop-reference.md](../../../docs/xways-getprop-reference.md) for the catalog.

## Logging

Two helpers near the top of the `.cpp`:

- `Log(msg)` — always prints to the X-Ways Messages window. Use for one-line summaries.
- `LogVerbose(msg)` — prints only when the `VERBOSE` constant is `true`. Use for per-item, per-row, per-event diagnostics that would flood the Messages window on a real case.

`VERBOSE` is `true` by default so you get full traces while developing. Flip it to `false` before sharing or running on a large snapshot — the call sites stay in place and switch off at zero cost. Full convention: [docs/conventions/verbose-logging.md](../../../docs/conventions/verbose-logging.md).

## Growing past the bare template

This template ships with **no settings dialog** — `XT_Prepare` runs straight from defaults and sidecar config. When an X-Tension needs an analyst-facing dialog, wraps an external CLI tool, or spawns a subprocess, don't reinvent the patterns here — **start from the [`wrapper/`](../wrapper/) template**, which already wires them in, and follow the conventions library:

- **Wrapping a CLI tool** → [`wrapper/`](../wrapper/) + [docs/conventions/wrapper-anatomy.md](../../../docs/conventions/wrapper-anatomy.md), [tool-resolution.md](../../../docs/conventions/tool-resolution.md).
- **Helper-exe identity verification** (verify the picked exe really is the expected tool before spawning it; in-dialog flash on rejection) → [docs/conventions/helper-exe-verification.md](../../../docs/conventions/helper-exe-verification.md).
- **Ctrl-to-save / Save-as gesture** (Ctrl+Run saves the cfg sidecar; Ctrl+Close exports a copy) → [docs/conventions/ctrl-to-save.md](../../../docs/conventions/ctrl-to-save.md).
- **Subprocess stdio** (see the caveat below) → [docs/conventions/subprocess-stdio.md](../../../docs/conventions/subprocess-stdio.md).
- **Dialog layout / UX** (filter-aware item collection, bold group titles, cue banners, tooltips, progress bar, worker thread, one cfg serializer, folder pickers) → [docs/xtension-dialog-conventions.md](../../../docs/xtension-dialog-conventions.md).
- **Manager (`xways-xt-manager`) compatibility** → the [`cpp-xtmgr-compatible/`](../cpp-xtmgr-compatible/) template + [docs/conventions/manager-compatibility.md](../../../docs/conventions/manager-compatibility.md).

Real-world implementations to study: [xways-trufflehog](https://github.com/kev365/xways-trufflehog) (the canonical tool-wrap) and [xways-ual-timeliner](https://github.com/kev365/xways-ual-timeliner) (dialog + Ctrl-to-save + helper-exe verification).

## Patterns borrowed

- Report-table + Comments-column writes: **CrowdStrike/xwf-yara-scanner** (MIT).
- `nOpType` awareness in `XT_Prepare` (RVS vs DBC vs search): official API + CrowdStrike.

## Caveats

- `__stdcall` on x64: the attribute is accepted but effectively ignored by the MSVC x64 ABI (there's only one calling convention). It's kept for signature fidelity with the SDK header.
- This template does not link against X-Ways' own `BGBase`/`BGCPString` utilities; if you need them later, add the SDK source folder to `cl`'s include path and compile those `.cpp` files alongside yours.
- **Subprocess stdio:** X-Ways is a GUI process with no console, so any child process you `CreateProcessW` inherits NULL / invalid `stdout` / `stderr` handles. Modern Python tools that probe their output stream at startup (anything using `rich` / `colorama` / `prompt_toolkit`) will crash silently mid-run on those NULL handles, surfacing as a non-zero exit code with empty stderr. **Always open `\NUL` and pass it for all three std handles via `STARTUPINFOW.hStdInput/Output/Error` with `STARTF_USESTDHANDLES` and `bInheritHandles=TRUE`.** Canonical pattern + rationale: [docs/conventions/subprocess-stdio.md](../../../docs/conventions/subprocess-stdio.md).
