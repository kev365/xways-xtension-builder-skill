---
source: extracted from the wrapper template (templates/x-tensions/wrapper/) and working X-Tensions
type: convention
last_updated: 2026-08-09
author: project
---

# Tool resolution

A CLI-wrapper X-Tension resolves its helper exe from the DLL's own directory
before spawning, so the helper is found wherever the analyst dropped the
per-X-Tension bundle. There are two forms of this, and they are not the same
function — check which one you have before citing it.

## Contents

- What the `wrapper` template ships
- The richer form — a shared `tools\` tree
- Resolution order summary (richer form)
- Do / Don't

## What the `wrapper` template ships

`ResolveDefaultTool()` — no arguments, probes three fixed locations under the
DLL directory, then falls back to a bounded breadth-first search:

```cpp
static std::wstring ResolveDefaultTool() {
    std::wstring dllDir = GetSelfDirectory();
    if (dllDir.empty()) return {};
    for (const wchar_t* sub : {
            L"\\tools\\yourtool\\yourtool.exe",
            L"\\tools\\yourtool.exe",
            L"\\yourtool.exe",
         }) {
        std::wstring guess = dllDir + sub;
        if (FileExists(guess)) return guess;
    }
    return FindSiblingFile(dllDir, L"yourtool.exe");
}
```

`FindSiblingFile(root, targetName, maxDepth = 4, maxDirsVisited = 256)` is the
bounded BFS — the visit cap matters, because a helper dropped next to a large
evidence tree would otherwise walk it. The name is matched **exactly**; the
template has no glob support.

The cfg override (`tool_exe = ...`) is applied by the caller in `XT_Prepare`:
if the override is set and the file exists, `ResolveDefaultTool` is never
called.

**Source of truth:** the `wrapper` template
(`templates/x-tensions/wrapper/my_xtension.cpp`) → `ResolveDefaultTool`,
`FindSiblingFile`.

## The richer form — a shared `tools\` tree

Working X-Tensions that share one helper tree across several X-Tensions use a
wider search with a `subdir` hint and glob matching. **This is not in the
template** — adopt it deliberately when a shared tree is what you want, and
port `FindExeInDir` / `FindExeRecursive` along with it.

!!! example "Here the `exe` argument is a glob"
    `exe` is a `FindFirstFileW` pattern, so a caller can write
    `L"hayabusa*.exe"` to match version-suffixed release binaries like
    `hayabusa-3.8.1-win-x64.exe` without hardcoding the version.

```cpp
// Resolve a tool binary path. `exe` is a filename glob (FindFirstFileW pattern
// — supports * and ?), so callers can match version-suffixed binaries like
// "hayabusa-3.8.1-win-x64.exe" via `exe = L"hayabusa*.exe"`.
//
// Search order:
//   1. <dll-dir>\..\tools\<subdir>\<exe>           (preferred: shared tools tree, direct)
//   2. <dll-dir>\..\tools\<subdir>\<anysub>\<exe>  (shared tools + vendor-version subdir)
//   3. <dll-dir>\tools\<subdir>\<exe>              (back-compat: self-contained bundle)
//   4. <dll-dir>\tools\<subdir>\<anysub>\<exe>     (self-contained + vendor-version subdir)
//   5. <dll-dir>\..\tools\**\<exe>                 (deep search, max 4 levels)
//   6. <dll-dir>\tools\**\<exe>                    (back-compat deep search)
//
// `subdir` is treated as a *hint* — if the analyst put the binary somewhere
// else in the shared tools tree, we still find it via the recursive fallback.
std::wstring ResolveToolPath(const std::wstring& subdir, const std::wstring& exe) {
    std::wstring dllDir = GetSelfDirectory();
    if (dllDir.empty()) return {};

    std::wstring siblingHint = dllDir + L"\\..\\tools\\" + subdir;
    std::wstring localHint   = dllDir + L"\\tools\\" + subdir;
    std::wstring siblingRoot = dllDir + L"\\..\\tools";
    std::wstring localRoot   = dllDir + L"\\tools";

    // Hint paths first (cheap; semantically meaningful when analyst chose
    // the recommended subdir name).
    std::wstring hit = FindExeInDir(siblingHint, exe);
    if (!hit.empty()) return hit;
    hit = FindExeInDir(localHint, exe);
    if (!hit.empty()) return hit;

    // Recursive fallback across the whole tools tree.
    hit = FindExeRecursive(siblingRoot, exe, 4);
    if (!hit.empty()) return hit;
    return FindExeRecursive(localRoot, exe, 4);
}
```

## Resolution order summary (richer form)

| Priority | Path searched | Rationale |
|---|---|---|
| 1 | `<dll-dir>\..\tools\<subdir>\<exe>` | Shared tools tree, exact subdir |
| 2 | `<dll-dir>\..\tools\<subdir>\<anysub>\<exe>` | Shared + vendor-version subdir |
| 3 | `<dll-dir>\tools\<subdir>\<exe>` | Self-contained bundle, exact subdir |
| 4 | `<dll-dir>\tools\<subdir>\<anysub>\<exe>` | Self-contained + vendor-version subdir |
| 5 | `<dll-dir>\..\tools\**\<exe>` (depth 4) | Deep search — handles analyst-chosen paths |
| 6 | `<dll-dir>\tools\**\<exe>` (depth 4) | Back-compat deep search |

As with the template's simpler form, the cfg override is resolved by the
**caller** before the search runs.

## Do / Don't

- **Do** resolve the exe path once in `XT_Prepare` and store it in `Settings.toolExe`; do not re-resolve per item.
- **Do** pass `subdir` as the canonical tool name (e.g. `L"hayabusa"`, `L"yourtool"`) — this is the recommended directory name under `xtensions\tools\`.
- **Do** use a glob for `exe` when the release filename includes a version number (e.g. `L"hayabusa*.exe"`).
- **Do** check that the resolved path exists (`GetFileAttributesW != INVALID_FILE_ATTRIBUTES`) and log a human-readable download URL if not found.
- **Don't** search `PATH` or the X-Ways executable directory — tools must be explicit (cfg or bundled).
- **Don't** pass an empty `subdir` to the richer form — the recursive fallback still works, but you lose the cheap hint-path fast-path.
- **Don't** cite `ResolveToolPath` as if the template shipped it. The template's function is `ResolveDefaultTool`, and it takes no arguments.

See also: [Wrapper anatomy](wrapper-anatomy.md) for where resolution fits in `XT_Prepare`.
