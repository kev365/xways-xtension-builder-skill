# Tool resolution

Every CLI-wrapper X-Tension resolves its helper exe via `ResolveToolPath`
before spawning. The function searches a prioritised set of directories
relative to the DLL's own location, so helpers are found whether the analyst
uses the shared `xtensions\tools\` layout or a self-contained per-X-Tension
bundle.

!!! example "The `exe` argument is a glob"
    `exe` is a `FindFirstFileW` pattern — callers can write
    `L"hayabusa*.exe"` to match version-suffixed release binaries like
    `hayabusa-3.8.1-win-x64.exe` without hardcoding the version.

## Pattern

Extracted from the `wrapper` template (`templates/x-tensions/wrapper/my_xtension.cpp`) → `ResolveToolPath`
(declaration comment + function body):

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

**Source of truth:** the `wrapper` template (`templates/x-tensions/wrapper/my_xtension.cpp`) → `ResolveToolPath`

## Resolution order summary

| Priority | Path searched | Rationale |
|---|---|---|
| 1 | `<dll-dir>\..\tools\<subdir>\<exe>` | Shared tools tree, exact subdir |
| 2 | `<dll-dir>\..\tools\<subdir>\<anysub>\<exe>` | Shared + vendor-version subdir |
| 3 | `<dll-dir>\tools\<subdir>\<exe>` | Self-contained bundle, exact subdir |
| 4 | `<dll-dir>\tools\<subdir>\<anysub>\<exe>` | Self-contained + vendor-version subdir |
| 5 | `<dll-dir>\..\tools\**\<exe>` (depth 4) | Deep search — handles analyst-chosen paths |
| 6 | `<dll-dir>\tools\**\<exe>` (depth 4) | Back-compat deep search |

The cfg-override path (`tool_exe = ...`) is resolved by the **caller** before
`ResolveToolPath` is even invoked; if the override is set and the file exists,
`ResolveToolPath` is skipped entirely.

## Do / Don't

- **Do** resolve the exe path once in `XT_Prepare` and store it in `RunState`; do not call `ResolveToolPath` per item.
- **Do** pass `subdir` as the canonical tool name (e.g. `L"hayabusa"`, `L"yourtool"`) — this is the recommended directory name under `xtensions\tools\`.
- **Do** use a glob for `exe` when the release filename includes a version number (e.g. `L"hayabusa*.exe"`).
- **Do** check that the resolved path exists (`GetFileAttributesW != INVALID_FILE_ATTRIBUTES`) and log a human-readable download URL if not found.
- **Don't** search `PATH` or the X-Ways executable directory — tools must be explicit (cfg or bundled).
- **Don't** call `ResolveToolPath` with an empty `subdir` — the recursive fallback will still work, but you lose the cheap hint-path fast-path.

See also: [Wrapper anatomy](wrapper-anatomy.md) for where `ResolveToolPath` fits in `XT_Prepare`.
