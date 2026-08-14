---
source: extracted from the wrapper template (templates/x-tensions/wrapper/) and working X-Tensions
type: convention
last_updated: 2026-08-12
author: project
---

# Naming & deployment

Every X-Tension uses a single stem (`xways-<name>`) shared by
the source folder, DLL file, source files, and the `.def` `LIBRARY` directive.
The build system then copies the DLL into a **deploy bundle** whose path uses
`xtensions\` (no hyphen) — the deployment spelling.

!!! warning "`xtensions\\` vs `x-tensions\\` — the hyphen matters"
    The source-tree parent directory is `x-tensions\` (hyphenated — the
    source-tree organisation convention).  The **deploy output** directory is `xtensions\` (NO
    hyphen). Both spellings are **conventions** — the build scripts
    stage, verify, and mirror the no-hyphen path, so a wrong spelling breaks
    the build/deploy tooling and scatters files.

!!! note "X-Ways does NOT auto-discover DLLs from any folder (confirmed on 21.8, 2026-07-03)"
    X-Ways loads X-Tensions only from paths the analyst registers: once via
    **Tools | Run X-Tensions → +** (persisted by full path in
    `<install>\X-Tensions.txt` — the DLL can live anywhere on disk), or per-run
    via the `XT:<path>` command-line parameter. There is no auto-load folder in
    the manual, the official API page, or observed 21.8 behaviour. The
    `xtensions\` deploy bundle exists for consistency: one self-contained
    folder per X-Tension (DLL + cfg sidecar + helper exe) at a stable path the
    analyst registers once and rebuilds never invalidate.

## Contents

- Pattern
- Deploy targets (which install)
- Dependent DLLs beside the X-Tension (v20.8+)
- Do / Don't

## Pattern

Extracted from `templates/x-tensions/cpp/build.bat` — `set NAME=` line,
`mkdir xtensions\%NAME%`, and the copy-DLL step:

```bat
set NAME=my_xtension
set OUT=%NAME%.dll
set CXXFLAGS=/nologo /std:c++17 /W3 /EHsc /O2 /utf-8 /DUNICODE /D_UNICODE
set LDFLAGS=/DLL /DEF:%NAME%.def /OUT:%OUT% /MACHINE:X64

cl %CXXFLAGS% /c %NAME%.cpp || goto :fail
link %LDFLAGS% %NAME%.obj   || goto :fail

REM Deployment convention: xtensions\<name>\<name>.dll
REM (Each X-Tension lives in its own subfolder under xtensions\.)
if not exist xtensions\%NAME% mkdir xtensions\%NAME%
copy /Y "%OUT%" "xtensions\%NAME%\%OUT%" >nul || goto :fail
echo Deployed: xtensions\%NAME%\%OUT%
```

The `.def` file must declare:

```
LIBRARY my_xtension
```

…where `my_xtension` is replaced with the same stem used in `set NAME=`.

**Source of truth:** `templates/x-tensions/cpp/build.bat` → `set NAME=` / `mkdir xtensions\%NAME%` / `copy /Y`

## Deploy targets (which install)

The build copies in two stages: **Stage A** stages a ready-to-copy folder at
`x-tensions\xways-<name>\xtensions\xways-<name>\`; **Stage B** mirrors that into
the X-Ways install's `xtensions\xways-<name>\` — a stable path the analyst
registers once via *Tools | Run X-Tensions* and that rebuilds never invalidate.

Stage B resolves the install **root** in this order. Your install path is **your
own environment** — nothing is hardcoded; the script asks for it once and
remembers it:

1. `-DeployRoot '<install-root>'` passed to `build-xtension.ps1` — and it is
   **remembered** for next time in a git-ignored `.xtension-deploy.local`;
2. `$env:XWT_DEPLOY_ROOT`;
3. the remembered path in `.xtension-deploy.local`.

A candidate root counts as an install only if it holds `xwb64.exe` (BYOD) **or**
`xwforensics64.exe` (licensed). If none is set, the build still succeeds and
stages the DLL locally — copy it into `<install>\xtensions\` yourself, or use
`-NoDeploy` to skip the deploy step. The mirror is **newer-only** (`xcopy /D`),
so an analyst-edited sidecar `.cfg`/`.yaml` already in the install survives
rebuilds.

Shared helper binaries live one level up at `xtensions\tools\` (e.g.
`tools\EZTools\`, `tools\Hayabusa\`) so multiple X-Tensions reuse the same
fetched tools; any shared tool-fetcher utility can sit beside them under
`xtensions\`.

## Dependent DLLs beside the X-Tension (v20.8+)

If your X-Tension **statically** links against extra DLLs — i.e. they are named
in the import table rather than `LoadLibrary`'d on demand — those DLLs were
historically **not found** when they sat next to the X-Tension, unless that
directory happened to be the X-Ways install directory or another
search-path-special location.

From **v20.8** X-Ways loads X-Tensions with `LOAD_WITH_ALTERED_SEARCH_PATH`, so
the X-Tension's **own directory** is searched for its dependencies. That is what
makes the per-X-Tension bundle layout above work for native dependencies as well
as for helper exes.

**Two caveats worth designing around.** The behaviour is **user-disableable** —
there is a checkbox to turn it off if it causes problems — so a bundle that
*requires* it can still fail on an analyst's machine. And it does nothing for
hosts older than v20.8. If you can, prefer loading optional dependencies
dynamically with an explicit path derived from `GetModuleFileNameW(g_hSelf)`,
which works regardless of the host version or the checkbox.

Source: the X-Tension Programming board, 2023-04-13 (see
[forum-xtensions-distilled.md](../forum-xtensions-distilled.md)).

## Do / Don't

- **Do** keep the stem identical everywhere: folder name, DLL name, `.cpp`/`.def`/`.rc` filenames, `LIBRARY` in `.def`, and `set NAME=` in `build.bat`.
- **Do** use `xtensions\` (no hyphen) for the deploy output path — the exact spelling the build scripts stage, verify, and mirror.
- **Do** keep source under `x-tensions\xways-<name>\` (hyphenated) for repo organisation; this is separate from the deploy path.
- **Don't** put cfg sidecars in the project root — they must land in `xtensions\<name>\` next to the DLL (the build script removes the project-root DLL for exactly this reason).
- **Don't** develop working X-Tensions inside `templates/` — copy a template to `x-tensions/<your-name>/` first.
