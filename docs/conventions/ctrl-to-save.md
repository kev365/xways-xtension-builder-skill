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
- **`DM_SETDEFID`** keeps Enter triggering Run even with `BS_OWNERDRAW` on IDOK.
- Both gestures are **inert while a worker is active** — Close stays "Cancel".

## Pattern

Extracted from the `wrapper` template (`templates/x-tensions/wrapper/my_xtension.cpp`) —
timer setup, the `kCtrlPollTimerId` / `g_runCtrlDown` declarations, the
`WM_TIMER` label swap, and the `WM_DRAWITEM` blue-tint block:

```cpp
// Ctrl-to-save / Save-as: WM_TIMER polls Ctrl every 100 ms while the dialog
// is up. On a transition we swap two button labels and repaint:
//   - Run   : "Run"   <-> "Save"         (BS_OWNERDRAW + WM_DRAWITEM = blue)
//   - Close : "Close" <-> "Save as..."   (label-only swap; standard button)
static constexpr UINT_PTR kCtrlPollTimerId = 0xAB10;
static bool               g_runCtrlDown   = false;

// WM_INITDIALOG — set up owner-draw Run + timer
SendMessageW(hDlg, DM_SETDEFID, IDOK, 0);
g_runCtrlDown = false;
SetDlgItemTextW(hDlg, IDOK,     L"Run");
SetDlgItemTextW(hDlg, IDCANCEL, L"Close");
SetTimer(hDlg, kCtrlPollTimerId, 100, nullptr);

// WM_TIMER — swap labels when Ctrl state changes
if (wParam == kCtrlPollTimerId) {
    bool nowDown = (GetKeyState(VK_CONTROL) & 0x8000) != 0;
    if (nowDown != g_runCtrlDown) {
        g_runCtrlDown = nowDown;
        HWND hRun = GetDlgItem(hDlg, IDOK);
        if (hRun) {
            SetWindowTextW(hRun, nowDown ? L"Save" : L"Run");
            InvalidateRect(hRun, nullptr, TRUE);
        }
    }
}

// WM_DRAWITEM — blue fill when Ctrl held, standard 3D otherwise
DRAWITEMSTRUCT* dis = (DRAWITEMSTRUCT*)lParam;
if (!dis || dis->CtlType != ODT_BUTTON || dis->CtlID != IDOK)
    return FALSE;
bool ctrl    = g_runCtrlDown;
bool pressed = (dis->itemState & ODS_SELECTED) != 0;
COLORREF bg;
if      (dis->itemState & ODS_DISABLED) bg = GetSysColor(COLOR_BTNFACE);
else if (ctrl)  bg = pressed ? RGB(0, 90, 170) : RGB(0, 120, 215);
else            bg = pressed ? GetSysColor(COLOR_BTNSHADOW)
                             : GetSysColor(COLOR_BTNFACE);
HBRUSH hbr = CreateSolidBrush(bg);
FillRect(dis->hDC, &dis->rcItem, hbr);
DeleteObject(hbr);
```

**Source of truth:** the `wrapper` template (`templates/x-tensions/wrapper/my_xtension.cpp`) → `kCtrlPollTimerId`, `g_runCtrlDown`, `WM_TIMER` handler, `WM_DRAWITEM` handler

## Do / Don't

- **Do** use `BS_OWNERDRAW` on IDOK and pair it with `DM_SETDEFID` so Enter still triggers Run.
- **Do** kill the timer in `WM_DESTROY` (`KillTimer(hDlg, kCtrlPollTimerId)`) and reset `g_runCtrlDown = false`.
- **Do** skip both Ctrl branches while a worker is active — the Close button must remain a cancel during a run.
- **Don't** use `MessageBox` for the "Save" confirmation — the silent write is the convention.
- **Don't** mix the Ctrl-to-save sidecar path with the "Save as..." export path — only the sidecar next to the DLL is auto-loaded on the next launch.
