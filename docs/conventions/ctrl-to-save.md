---
source: extracted from the wrapper template (templates/x-tensions/wrapper/) and working X-Tensions
type: convention
last_updated: 2026-08-16
author: project
---

# Ctrl-to-save gesture

X-Tensions with a settings dialog and cfg sidecar expose a uniform keyboard
gesture so analysts can save config without triggering a full run. A 100 ms
`WM_TIMER` polls `VK_CONTROL` while the dialog is open; on a state transition
it swaps two button labels and repaints.

- **Ctrl+Run** — saves current dialog state to the standard cfg sidecar; skips
  Run-only validation. The Run button (owner-draw, `BS_OWNERDRAW`) relabels to
  **"Save"** and fills blue.
- **Ctrl+Close** — opens `GetSaveFileNameW`, saves to the chosen path, closes.
  The Close button label swaps to **"Save as..."**.
- **`DM_SETDEFID`** keeps Enter triggering Run even with `BS_OWNERDRAW` on the
  Run button. In the template that button is `IDC_BTN_RUN`, not `IDOK` — the
  settings dialog has no `IDOK` control.
- Both gestures are **inert while a worker is active** — Close stays "Cancel".

## Contents

- Pattern
- Run-click handling — Ctrl at click time, not the cached flag
- Ctrl+Close save-as implementation
- Do / Don't

## Pattern

Extracted from the `wrapper` template (`templates/x-tensions/wrapper/my_xtension.cpp`) —
timer setup, the `kCtrlPollTimerId` / `g_runCtrlDown` declarations, the
`WM_TIMER` label swap, and the `WM_DRAWITEM` blue-tint block:

```cpp
// Ctrl-to-save / Save-as: WM_TIMER polls Ctrl every 100 ms while the dialog
// is up. On a transition we swap two button labels and repaint:
//   - Run   : "<rc label>" <-> "Save"        (BS_OWNERDRAW + WM_DRAWITEM = blue)
//   - Close : "<rc label>" <-> "Save as..."  (only when no worker is running)
// Declared as statics inside SettingsDlgProc.
static bool      g_runCtrlDown   = false;
static bool      g_closeCtrlDown = false;
constexpr UINT_PTR kCtrlPollTimerId = 0xAB10;
constexpr UINT     kCtrlPollMs      = 100;

// Resting labels are read back from the .rc rather than hardcoded, so the
// restore cannot silently drop an "&" mnemonic the .rc declared.
static wchar_t g_runRestLabel[64]   = L"Run";
static wchar_t g_closeRestLabel[64] = L"Close";

// WM_INITDIALOG — DM_SETDEFID keeps Enter on Run despite BS_OWNERDRAW
SendMessageW(hDlg, DM_SETDEFID, IDC_BTN_RUN, 0);
GetDlgItemTextW(hDlg, IDC_BTN_RUN, g_runRestLabel,   _countof(g_runRestLabel));
GetDlgItemTextW(hDlg, IDCANCEL,    g_closeRestLabel, _countof(g_closeRestLabel));
SetTimer(hDlg, kCtrlPollTimerId, kCtrlPollMs, nullptr);

// WM_TIMER — swap labels when Ctrl state changes
if (wp == kCtrlPollTimerId) {
    bool ctrlDown = (GetKeyState(VK_CONTROL) & 0x8000) != 0;
    if (ctrlDown != g_runCtrlDown) {
        g_runCtrlDown = ctrlDown;
        SetDlgItemTextW(hDlg, IDC_BTN_RUN, ctrlDown ? L"Save" : g_runRestLabel);
        InvalidateRect(GetDlgItem(hDlg, IDC_BTN_RUN), nullptr, TRUE);
    }
    // Close only offers Save-as when no worker is running.
    bool closeSaveMode = ctrlDown && (g_workerThread == nullptr);
    if (closeSaveMode != g_closeCtrlDown) {
        g_closeCtrlDown = closeSaveMode;
        SetDlgItemTextW(hDlg, IDCANCEL,
                        closeSaveMode ? L"Save as..."
                                      : (g_workerThread ? L"Cancel"
                                                        : g_closeRestLabel));
        InvalidateRect(GetDlgItem(hDlg, IDCANCEL), nullptr, TRUE);
    }
    return TRUE;
}

// WM_DRAWITEM — blue fill in the Ctrl "alternate action" state
DRAWITEMSTRUCT* dis = (DRAWITEMSTRUCT*)lp;
const bool isRunBtn    = (dis->CtlID == IDC_BTN_RUN);
const bool isCancelBtn = (dis->CtlID == IDCANCEL);
bool altMode   = (isRunBtn && g_runCtrlDown) || (isCancelBtn && g_closeCtrlDown);
bool isPressed = (dis->itemState & ODS_SELECTED) != 0;
COLORREF bg = altMode ? (isPressed ? RGB(0, 90, 168) : RGB(0, 120, 215))
                      : GetSysColor(COLOR_BTNFACE);
HBRUSH hbr = CreateSolidBrush(bg);
FillRect(dis->hDC, &dis->rcItem, hbr);
DeleteObject(hbr);
```

**Source of truth:** the `wrapper` template (`templates/x-tensions/wrapper/my_xtension.cpp`) → `kCtrlPollTimerId`, `g_runCtrlDown`, `g_closeCtrlDown`, `g_runRestLabel`, `g_closeRestLabel`, `WM_TIMER` handler, `WM_DRAWITEM` handler

## Run-click handling — Ctrl at click time, not the cached flag

The timer state is only a UI hint. The Run handler re-reads the key at click
time:

```cpp
// WM_COMMAND, IDC_BTN_RUN:
if (!ReadDialogToSettings(hDlg, *s)) return TRUE;
SaveSettingsToCfg(cfgPath, *s);
// GetKeyState at click time -- not the cached g_runCtrlDown -- is the
// source of truth (the timer state is just a UI hint).
if ((GetKeyState(VK_CONTROL) & 0x8000) != 0) {
    SetDlgItemTextW(hDlg, IDC_LABEL_PROGRESS_STATUS,
                    L"Settings saved to cfg. (Ctrl+Run: scan NOT started.)");
    return TRUE;   // Ctrl+Run: saved, skip the worker
}
// ... spawn worker ...
```

`GetKeyState` (not `GetAsyncKeyState`) reports the key state as of the message
this thread is processing, so it is already scoped to our own message pump —
no `GetFocus()`/`GA_ROOT` gate is needed to stop the label flickering while
the analyst types Ctrl+key in another window.

## Ctrl+Close save-as implementation

The exported file is a snapshot — on next launch the X-Tension still
auto-loads only the standard sidecar next to its DLL:

```cpp
if (id == IDCANCEL) {
    bool ctrlHeld = (GetKeyState(VK_CONTROL) & 0x8000) != 0;
    if (ctrlHeld && !g_workerThread && s && ctx) {
        if (!ReadDialogToSettings(hDlg, *s)) return TRUE;
        wchar_t fileBuf[MAX_PATH];
        swprintf_s(fileBuf, L"%s.cfg", NAME);
        OPENFILENAMEW ofn = {};
        ofn.lStructSize  = sizeof(ofn);
        ofn.hwndOwner    = hDlg;
        ofn.lpstrFilter  = L"Config Files (*.cfg)\0*.cfg\0All files (*.*)\0*.*\0";
        ofn.nFilterIndex = 1;
        ofn.lpstrFile    = fileBuf;      // doubles as the default filename
        ofn.nMaxFile     = MAX_PATH;
        ofn.lpstrTitle   = L"Save settings to...";
        ofn.Flags        = OFN_OVERWRITEPROMPT | OFN_PATHMUSTEXIST | OFN_NOCHANGEDIR;
        ofn.lpstrDefExt  = L"cfg";
        if (!GetSaveFileNameW(&ofn)) return TRUE;   // user cancelled
        if (SaveSettingsToCfg(fileBuf, *s)) EndDialog(hDlg, IDCANCEL);
        return TRUE;
    }
    // ... existing cancel-worker-or-close logic
}
```

`OFN_OVERWRITEPROMPT` makes an auto-numbered filename unnecessary — the common
dialog asks before clobbering. `OFN_NOCHANGEDIR` matters more than it looks:
without it the picker mutates the host process's current directory, and X-Ways
keeps running long after your dialog closes. Gate on
`g_workerThread == nullptr`; if the X-Tension wraps a helper exe, also refuse
while a helper-identity rejection is outstanding, so a rejected path can't be
persisted into an exported cfg.

## Do / Don't

- **Do** use `BS_OWNERDRAW` on the Run button and pair it with `DM_SETDEFID` so Enter still triggers Run.
- **Do** capture the resting labels from the `.rc` at `WM_INITDIALOG` and restore *those*; a hardcoded `L"Run"` against an `.rc` that says `"&Run"` silently kills the Alt+R accelerator.
- **Do** give `IDCANCEL` its resting label (`Close`) in the `.rc`; it reads `Cancel` only while a worker runs.
- **Do** kill the timer in `WM_DESTROY` (`KillTimer(hDlg, kCtrlPollTimerId)`) and reset `g_runCtrlDown = false`.
- **Do** skip both Ctrl branches while a worker is active — the Close button must remain a cancel during a run.
- **Don't** use `MessageBox` for the "Save" confirmation — the silent write is the convention.
- **Do** tooltip the Run button so analysts discover the modifier without reading the README (see `IDC_BTN_RUN`'s tooltip in the wrapper template).
- **Don't** mix the Ctrl-to-save sidecar path with the "Save as..." export path — only the sidecar next to the DLL is auto-loaded on the next launch.
