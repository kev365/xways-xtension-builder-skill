---
source: https://www.x-ways.net/forensics/x-tensions/XWF_functions.html (official) + the X-Ways SDK header (see getting-the-sdk.md)
type: official-doc
fetched: 2026-04-27
last_updated: 2026-04-27
author: X-Ways Software Technology AG; project synthesis
---

# Prompting the user from an X-Tension

How to ask the analyst for input or surface a dialog from inside an X-Tension. Three practical paths, in order of complexity:

1. **`XWF_GetUserInput`** — built-in single-field dialog hosted by X-Ways.
2. **Win32 dialog parented to `hMainWnd`** — anything richer (multi-field, file picker, custom layout).
3. **Sidecar config file** — persisted, analyst-edited config loaded next to the DLL; usually the cleanest UX for runs that should not re-prompt every time.

These compose: load defaults from a sidecar, prompt with `XWF_GetUserInput` for the one value that varies per run, fall back to a Win32 dialog if the input is too rich for a single field.

## `XWF_GetUserInput`

Available in **v18.5 and later** (per the official docs page). SDK header signature in the X-Ways SDK header (see [getting-the-sdk.md](getting-the-sdk.md)):

```c
INT64 __stdcall XWF_GetUserInput(
    LPWSTR lpMessage,   // prompt explaining what input is required
    LPWSTR lpBuffer,    // pre-fill / receives user-entered text (NULL for integer mode)
    DWORD  nBufferLen,  // capacity of lpBuffer in wchar_t (NULL/0 for integer mode)
    DWORD  nFlags);
```

### Flag bits

| Bit | Documented meaning |
| --- | --- |
| `0x00000001` | Requires the user to enter a **positive integer**. The integer is the return value. `lpBuffer` and `nBufferLen` must be NULL/0. |
| `0x00000002` | **Empty input allowed.** Mutually exclusive with `0x01`. |
| `0x00000010` | Hint that the prompt collects a **password** (so X-Ways can suppress screenshots / log entries). *Not yet implemented* per the official docs. |

### Return value

- Text mode (no `0x01` flag): number of `wchar_t` written to `lpBuffer` (excluding the terminating NUL).
- Integer mode (`0x01` flag): the entered positive integer.
- **`-1`**: user clicked Cancel.

### Pre-filling

Seed `lpBuffer` with a NUL-terminated string before the call to suggest a default; pass an empty string (single `L'\0'`) for no suggestion. The dialog renders the suggestion in the input field and the user can edit or accept it.

### Where to call

`XT_Prepare` is the right place — it's single-threaded, runs once per operation, and you have `hMainWnd` available from `XT_Init` if you also want a window-modal Win32 dialog. **Do not** call `XWF_GetUserInput` from a multi-threaded `XT_ProcessItem(Ex)` callback — UI from a worker thread is asking for trouble, and you'll repeatedly prompt the analyst once per item, which is never what you want.

### Pattern

```cpp
// Text input with default
wchar_t buf[260] = L"default-value";
INT64 rv = XWF_GetUserInput(L"Path to enrichment data:", buf, 260, 0);
if (rv < 0) return -1;  // user cancelled — abort the operation
// buf now holds the user's input

// Integer input
INT64 maxRows = XWF_GetUserInput(L"Max rows to process (0 = no limit):", nullptr, 0, 0x01);
if (maxRows < 0) return -1;
```

### Limits

- **Single field per call.** No checkboxes, dropdowns, multi-line text, file pickers. Chain multiple calls if you need multiple fields, but each one is a separate dialog the analyst has to dismiss.
- **`LPWSTR` (UTF-16 wide).** Unlike `EventInfo.lpDescr` (which is UTF-8), this API follows the wide-string convention.
- **Positive integers only** in integer mode. No negatives, no fractional values. For signed/floating input, take a string and parse.
- **No validation hooks.** If the value must be a path/regex/JSON, validate after the call and re-prompt or `XWF_OutputMessage` on failure.

## Win32 dialog parented to `hMainWnd`

For richer prompts, use a normal Win32 dialog. `XT_Init` receives an `hMainWnd` HWND (per the X-Ways SDK header — see [getting-the-sdk.md](getting-the-sdk.md)):

```c
LONG __stdcall XT_Init(DWORD info, DWORD nFlags, HANDLE hMainWnd, void* lpReserved);
```

Capture `hMainWnd` to a global and use it as the parent for `MessageBoxW`, `DialogBoxParamW`, `GetOpenFileNameW`, etc. The dialog will be modal-to-X-Ways and ride the X-Ways main window.

```cpp
static HWND g_hMainWnd = nullptr;

LONG __stdcall XT_Init(DWORD, DWORD nFlags, HANDLE hMainWnd, void*) {
    if (nFlags & 0x20) return 1;          // QUICKCHECK
    g_hMainWnd = (HWND)hMainWnd;
    return 1;
}

// Later, in XT_Prepare:
OPENFILENAMEW ofn = { sizeof(ofn) };
wchar_t path[MAX_PATH] = L"";
ofn.hwndOwner = g_hMainWnd;
ofn.lpstrFile = path;
ofn.nMaxFile  = MAX_PATH;
ofn.lpstrFilter = L"All files\0*.*\0";
if (!GetOpenFileNameW(&ofn)) return -1;
```

`XWF_GetWindow(WORD nWndNo, WORD nWndIndex)` (since v19.9 SR-7) lets you get HWNDs for specific X-Ways child windows (data window, hex window, directory browser, gallery, etc.) if you ever need to parent a dialog to a sub-window instead of the main window — but for normal prompting, `hMainWnd` from `XT_Init` is the right parent.

### When this is the right choice

- The prompt has more than one field.
- The input is a path / file / folder picker.
- You want validation feedback in the same dialog (re-prompt without modal whiplash).
- You need richer controls (radio groups, checkboxes, dropdowns).

The cost is that you ship a real Win32 UI inside the DLL — `DialogBoxParamW` + a dialog template, or a custom CreateWindow stack. The `wrapper` template (`templates/x-tensions/wrapper/`) ships a worked example (settings dialog with input-source radios, toggle checklist, output-handling options); see [xtension-dialog-conventions.md](xtension-dialog-conventions.md).

### Convention: append the version to the dialog title bar

Standard practice for any X-Tension that opens a Win32 dialog: append `(vX.Y.Z)` to the dialog's caption in `WM_INITDIALOG`. Makes the build obvious to the analyst and useful in bug-report screenshots.

```cpp
case WM_INITDIALOG: {
    // ... other init ...

    // Append "(vX.Y.Z)" to the existing dialog caption (set by the .rc).
    wchar_t title[256] = {0};
    GetWindowTextW(hDlg, title, 256);
    std::wstring augmented = title;
    augmented += L"  (v";
    augmented += VERSION;       // the X-Tension's static const wchar_t* VERSION
    augmented += L")";
    SetWindowTextW(hDlg, augmented.c_str());

    // ...
    return TRUE;
}
```

The pattern preserves the static caption from the `.rc` file (which usually carries the X-Tension name + a context suffix like " - Settings") and appends the version dynamically. Bumping `VERSION` in source updates the caption automatically — no second place to edit.

## Sidecar config file

For settings that should persist across runs (helper-binary paths, default flags, output directories), the project convention is a `.cfg` file deployed next to the DLL. Documented at [xtension-invocation.md:217-256](xtension-invocation.md#L217-L256). Typical shape:

```text
<X-Ways install>\xtensions\
├── my_xtension.dll
├── my_xtension.cfg     # analyst edits this once
└── helper.exe
```

Resolve the cfg path via `GetModuleFileNameW(g_hSelf)` (DLL's own directory, not the X-Ways executable's directory). The `wrapper` template (`templates/x-tensions/wrapper/`) ships the plain `key = value` cfg pattern in `LoadCfg` / `SaveCfg`; an X-Tension that handles credentials would store them DPAPI-encrypted in the same sidecar instead.

### When to combine with `XWF_GetUserInput`

- **Sidecar for stable settings** that the analyst sets once per machine (paths, API keys, default flags).
- **`XWF_GetUserInput` for per-run knobs** (the date range, the keyword, the case-specific filter).

This avoids both extremes: no prompt-spam every run, and no requirement that the analyst hand-edit a config to vary one value.

## `XWF_OutputMessage` for status / errors

Not a prompt, but the natural counterpart for surfacing results back to the analyst when no input is needed. SDK signature in the X-Ways SDK header (see [getting-the-sdk.md](getting-the-sdk.md)). Flag bits per the official docs page:

| Bit | Meaning |
| --- | --- |
| `0x01` | Append without line break (joins with a space to the previous message). |
| `0x02` | Don't log this message to `msglog.txt`. |
| `0x04` | `lpMessage` is ANSI, not Unicode (since v16.5). |
| `0x08` | Send to the **Output window** instead of the Messages window (since v20.6); no `[XT]` prefix. |
| `0x10` | Send to the **case log** instead of the Messages window (since v19.4); ignored if no case is active; combinable with `0x04`. |

Convention: use the `Log` helper in the C++ template for one-line summary messages, `LogVerbose` for per-item diagnostics gated on the `VERBOSE` constant.

## Caveats

- `XWF_GetUserInput` is **not exposed by `XT_Python.dll`'s embedded `xwf` module** (per the XT_Python readme shipped with the SDK). Python X-Tensions can prompt via `tkinter` or similar instead — but with no parenting to `hMainWnd`, the dialog can be hidden behind X-Ways.
- The dialog is **modal to the calling thread**. Calling it from a multi-threaded `XT_ProcessItem(Ex)` is wrong — prompt once in `XT_Prepare`, store the answer in a global, consume it during item iteration.
- **Cancel returns `-1`.** Treat that as "abort the operation" and return `-1` from `XT_Prepare` so X-Ways skips the rest of the run cleanly.
- The "password hint" flag (`0x10`) is documented as **not yet implemented** — don't rely on it for actual secret-handling.

## See also

- [xtension-invocation.md](xtension-invocation.md) — entry points (`XT_Init` for `hMainWnd`, `XT_Prepare` for prompting), threading rules, sidecar config pattern.
- [xways-reading-events-and-items.md](xways-reading-events-and-items.md) — the analyzer-pattern counterpart: how to consume data once you have the analyst's input.
- The X-Ways SDK header (see [getting-the-sdk.md](getting-the-sdk.md)) — authoritative `XWF_GetUserInput` declaration.
- Official function reference: <https://www.x-ways.net/forensics/x-tensions/XWF_functions.html>
