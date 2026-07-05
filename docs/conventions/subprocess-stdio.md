# Subprocess stdio

!!! danger "Mandatory for every X-Tension that spawns a child process"
    X-Ways runs as a GUI-subsystem process — it accepts command-line *parameters*, but has
    **no console** window attached. A child you spawn inherits NULL std handles, and any tool
    using `rich`/`colorama`/`prompt_toolkit` (and many others) will **hard-crash** on a NULL
    handle. You MUST open the `NUL` device and pass all three std handles via `STARTUPINFOW`
    with `STARTF_USESTDHANDLES`.

**Source of truth:** the `wrapper` template (`templates/x-tensions/wrapper/my_xtension.cpp`) → `RunCommand`.
(For a capturing variant — read the child's stdout — see the same file's
`CreateCapturePipe` / `DrainPipe` / `RunHelper`, which use an inheritable pipe + a drain
thread to avoid deadlock on chatty children.)

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
// Optional: a dedicated stderr file handle so the caller can read tracebacks;
// falls back to hNul when not requested.
HANDLE hStderr = (hErr != INVALID_HANDLE_VALUE) ? hErr : hNul;

STARTUPINFOW si = {};
si.cb         = sizeof(si);
si.dwFlags    = STARTF_USESTDHANDLES;
si.hStdInput  = hNul;
si.hStdOutput = hNul;
si.hStdError  = hStderr;
PROCESS_INFORMATION pi = {};
CreateProcessW(nullptr, mut.data(), nullptr, nullptr,
               TRUE,                 // inherit handles so NUL/stderr reach the child
               CREATE_NO_WINDOW, nullptr,
               workingDir.empty() ? nullptr : workingDir.c_str(),
               &si, &pi);
// ... WaitForSingleObject + GetExitCodeProcess + CloseHandle(all) ...
```

## Do / Don't

- **Do** redirect all three handles (`hStdInput`, `hStdOutput`, `hStdError`).
- **Do** use a drain thread when you need the child's output, to avoid pipe-buffer deadlock.
- **Don't** leave handles at NULL "because the tool seems fine in testing" — it crashes in the field.
- **Don't** use `CREATE_NEW_CONSOLE` to dodge this for a tool meant to run headless during RVS.

See also: [Helper-exe verification](helper-exe-verification.md) and
[external-tool integration](../external-tool-integration.md).
