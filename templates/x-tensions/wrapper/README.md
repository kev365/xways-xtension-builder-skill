# `wrapper` — CLI-tool-wrapper X-Tension template

A generic, **manager-compatible** starting point for an X-Tension that wraps an
external command-line tool. For each file in the active volume snapshot (or a
right-click Directory-Browser selection) it:

1. extracts the item's bytes to a scratch file (`XWF_Read` → `CreateFile`),
2. runs your CLI tool over that file (`<tool.exe> <args> <inputFile>`),
3. parses the tool's output, and
4. tags items in a **Report Table** + the **Comments** column, and writes a
   consolidated `results.csv` under the run folder.

It self-declares the `XWF_*` function-pointer typedefs and resolves them via
`GetProcAddress`, so **no `X-Tension.h` is needed** to build.

## What this template wires in for you

| Convention | Where |
| --- | --- |
| **Helper-exe identity verification** | `PeIdentityContains` (PE VERSIONINFO) **OR** `DetectToolVersion` (`--version` banner) via `VerifyHelperIdentity`; async probe (`StartAsyncVersionProbe`) + in-dialog red-flash rejection (`ShowHelperRejection` / `ClearHelperRejection`). Run is gated until the binary identifies as your tool. |
| **Ctrl-to-save / Ctrl-to-save-as** | `g_runCtrlDown` + `kCtrlPollTimerId` poll `VK_CONTROL`; owner-draw Run/Cancel buttons (`WM_DRAWITEM`) turn blue and relabel to **Save** / **Save as…**. Ctrl+Run saves the cfg without running; Ctrl+Close opens a `GetSaveFileNameW` picker. |
| **Per-X-Tension output folder** | `GetCaseRootDir` + `DefaultOutputDir` default output to `<caseRoot>\<NAME>`; re-resolved per dialog open so it follows the active case. |
| **Subprocess stdio** | `RunCommand` (redirect via `cmd.exe /C … > out 2> err`, wait) and `RunCaptureStdout` (pipe + `STARTF_USESTDHANDLES`, used for the `--version` probe). |
| **xways-xt-manager compatibility** | `XwaysManagerPluginEntry` export + `Wrapper*` `On*` callbacks; the scan runs synchronously in `WrapperOnFinalize` with `hDlg=NULL`. ABI from `manager-plugin.h` (copied verbatim — do not edit). The manager host is a separate project, not yet publicly released. |
| **Verbose logging toggle** | `g_verbose` + `Log` / `LogVerbose`; Verbose checkbox in the dialog and `xtension_verbose` cfg key. |
| **cfg lifecycle** | `Settings` ↔ `SerializeSettings` / `LoadCfg` / `SaveSettingsToCfg` / `EnsureCfgExists`. The serializer is the single source of truth for the auto-created cfg. |

## What you must fill in

Search the `.cpp` for **`TODO:`**. The tool-specific logic is stubbed so the
template compiles and runs end-to-end (finding nothing) out of the box:

1. **Identity constants** — `NAME` / `VERSION` / `DESCRIPTION` / `REPORT_TABLE`
   (a scaffolder normally rewrites these).
2. **`HELPER_NEEDLE` / `kHelperIdentityNeedle`** — the lowercase substring that
   identifies your tool in its PE VERSIONINFO and/or `--version` banner.
3. **`ResolveDefaultTool`** — the conventional bundled `<tool>.exe` path(s).
4. **`BuildToolCmd`** — your tool's command-line shape.
5. **`ParseToolOutput`** — turn the captured tool output into `ScanResult`
   rows (label / detail / line). The trufflehog exemplar has a
   dependency-free JSONL scanner you can model on.
6. **`WriteResultsCsv`** — adjust the columns to your tool's findings (or swap
   in an XLSX writer — see the trufflehog exemplar's store-only ZIP writer).
7. **dialog labels** in `my_xtension.rc` / `resource.h` (cosmetic) and the
   About-box GitHub URL.

## Files

| File | Purpose |
| --- | --- |
| `my_xtension.cpp` | The wrapper implementation (compiles as-is). |
| `my_xtension.def` | `LIBRARY` + the `EXPORTS` list (incl. `XwaysManagerPluginEntry`). |
| `my_xtension.rc` / `resource.h` | DIALOGEX: Tool binary / Input source / Output handling + Status + Run/Close, plus an About box. |
| `build.bat` | Auto-bootstraps MSVC 2019/2022 vcvars, compiles, deploys to a project-local `xtensions\my_xtension\`. Links `version.lib` for the PE identity check. |
| `manager-plugin.h` | xways-xt-manager plugin ABI — **copy verbatim, do not edit**. |
| `my_xtension.cfg.example` | Documented minimal cfg sample. |

## Build

From an *x64 Native Tools Command Prompt for VS*, or any cmd/PowerShell (the
script bootstraps vcvars):

```bat
build.bat
```

Output: `xtensions\my_xtension\my_xtension.dll` (+ `.cfg.example`). Copy that
whole subfolder into your X-Ways install's `xtensions\` directory.

## Scaffold from this template

```powershell
new-xtension.ps1 -Name <name> -Template wrapper
```

This copies the template, renames the three source files + the `LIBRARY` /
`set NAME=` lines, and seeds the identity constants — leaving the `TODO:`
markers for the tool-specific logic you fill in.
