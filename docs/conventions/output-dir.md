# Output directory

Every X-Tension that writes analyst-facing files defaults its output folder to
`<caseRoot>\<NAME>\`, where `caseRoot` comes from `XWF_GetCaseProp` with
property type 6 (`XWF_CASEPROP_DIR`). The folder is created on demand via
`SHCreateDirectoryExW` when the analyst hits Run.

`output_dir` is **never persisted in the cfg sidecar**. Re-deriving it per case
prevents stale paths from leaking across cases.

## Pattern

Extracted from the `wrapper` template (`templates/x-tensions/wrapper/my_xtension.cpp`) →
`GetCaseRootDir` and `DefaultOutputDir`:

```cpp
// XWF_CASEPROP_DIR (nPropType = 6) returns the case's working directory.
// Buffer must be MAX_PATH wchars.
static std::wstring GetCaseRootDir() {
    if (!XWF_GetCaseProp) return {};
    wchar_t buf[MAX_PATH] = {0};
    INT64 rc = XWF_GetCaseProp(nullptr, /*XWF_CASEPROP_DIR=*/6, buf, MAX_PATH);
    if (rc < 0) return {};
    return buf[0] ? std::wstring(buf) : std::wstring();
}

// Per-X-Tension output folder convention: keep reports out of the case root
// itself by nesting them inside a folder named after this X-Tension.
// Empty caseRoot (no case open / property unavailable) returns empty so
// callers fall back to whatever default they had before.
static std::wstring DefaultOutputDir(const std::wstring& caseRoot) {
    if (caseRoot.empty()) return {};
    return caseRoot + L"\\" + NAME;
}
```

The cfg loader skips `output_dir` on load (from the same file, `LoadSettings`):

```cpp
// output_dir intentionally not loaded — it's always derived from
// the current case root at run time so settings can't drift across
// cases (see DefaultOutputDir + WM_INITDIALOG / RVS silent path).
```

**Source of truth:** the `wrapper` template (`templates/x-tensions/wrapper/my_xtension.cpp`) → `GetCaseRootDir`, `DefaultOutputDir`

## Do / Don't

- **Do** call `GetCaseRootDir()` at the start of `XT_Prepare` (or `WM_INITDIALOG`) and pass the result to `DefaultOutputDir(caseRoot)` to seed the output-path field.
- **Do** create the folder with `SHCreateDirectoryExW` just before writing — lazy creation avoids empty folders when the user aborts.
- **Do** use `<NAME>` (the DLL stem constant) as the subfolder name so artifacts are easy to find and archive.
- **Don't** save `output_dir` to the cfg sidecar — re-derive it each time from the live case root.
- **Don't** hardcode a fallback path outside the case root; return empty and let the caller decide (log and bail, or prompt the analyst).

See also: [Naming & deployment](naming-deployment.md) for the `NAME` constant convention.
