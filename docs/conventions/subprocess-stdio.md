---
source: extracted from the wrapper template (templates/x-tensions/wrapper/) and working X-Tensions
type: convention
last_updated: 2026-08-09
author: project
---

# Subprocess stdio

!!! danger "Mandatory for every X-Tension that spawns a child process"
    X-Ways runs as a GUI-subsystem process — it accepts command-line *parameters*, but has
    **no console** window attached. A child you spawn inherits NULL std handles, and any tool
    using `rich`/`colorama`/`prompt_toolkit` (and many others) will **hard-crash** on a NULL
    handle. You MUST open the `NUL` device and pass all three std handles via `STARTUPINFOW`
    with `STARTF_USESTDHANDLES`.

**Source of truth:** the `wrapper` template (`templates/x-tensions/wrapper/my_xtension.cpp`) → `RunCommand`.
(For a capturing variant — read the child's stdout — see the same file's
`RunCaptureStdout`, which swaps the `NUL` handle for an inheritable pipe and
reads it with a timeout so a chatty child cannot deadlock the caller.)

## Pattern

Extracted from the `wrapper` template (`templates/x-tensions/wrapper/my_xtension.cpp`) → `RunCommand` (open `NUL` with an
inheritable `SECURITY_ATTRIBUTES`, point all three std handles at it, and inherit handles into
the child):

```cpp
SECURITY_ATTRIBUTES sa = {};
sa.nLength        = sizeof(sa);
sa.bInheritHandle = TRUE;
HANDLE hNul = CreateFileW(L"NUL", GENERIC_READ | GENERIC_WRITE,
                          FILE_SHARE_READ | FILE_SHARE_WRITE,
                          &sa, OPEN_EXISTING, FILE_ATTRIBUTE_NORMAL, nullptr);

STARTUPINFOW si = {}; si.cb = sizeof(si);
BOOL inheritHandles = FALSE;
if (hNul != INVALID_HANDLE_VALUE) {
    si.dwFlags     = STARTF_USESTDHANDLES;
    si.hStdInput   = hNul;
    si.hStdOutput  = hNul;
    si.hStdError   = hNul;
    inheritHandles = TRUE;   // required for the child to receive them
}

PROCESS_INFORMATION pi = {};
BOOL ok = CreateProcessW(nullptr, mut.data(), nullptr, nullptr, inheritHandles,
                         CREATE_NO_WINDOW, nullptr,
                         workingDir.empty() ? nullptr : workingDir.c_str(),
                         &si, &pi);
if (hNul != INVALID_HANDLE_VALUE) CloseHandle(hNul);
// ... WaitForSingleObject + GetExitCodeProcess + CloseHandle(pi.*) ...
```

Want the child's stderr in a file the analyst can read? Two ways, and the
template uses the first: wrap the command in `cmd.exe /C "... > out 2> err"`
(see `BuildToolCmd`), which leaves this function unchanged — `cmd` re-opens
those files for the tool, and `cmd` itself still gets valid handles instead of
NULL ones. Otherwise open the file yourself with the same inheritable
`SECURITY_ATTRIBUTES` and put it in `si.hStdError` in place of `hNul`.

## Do / Don't

- **Do** redirect all three handles (`hStdInput`, `hStdOutput`, `hStdError`).
- **Do** use a drain thread when you need the child's output, to avoid pipe-buffer deadlock.
- **Don't** leave handles at NULL "because the tool seems fine in testing" — it crashes in the field.
- **Don't** use `CREATE_NEW_CONSOLE` to dodge this for a tool meant to run headless during RVS.

See also: [Helper-exe verification](helper-exe-verification.md) and
[external-tool integration](../external-tool-integration.md).
