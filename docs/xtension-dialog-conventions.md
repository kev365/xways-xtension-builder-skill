---
source: synthesized from CLI-wrapper dialog implementations (see exemplars.md and the wrapper template)
type: convention / template-companion
fetched: 2026-05-14
last_updated: 2026-05-14
---

# X-Tension dialog conventions

Settings UX patterns used consistently across the exemplar X-Tensions and the
wrapper template. New
X-Tensions with non-trivial configuration should follow this guide; deviations
should be deliberate and noted in the X-Tension's README.

Reference implementations:

- The `wrapper` template (`templates/x-tensions/wrapper/`) — a refined
  `.rc`-based `DIALOGEX` with grouped controls, per-role fonts, file/folder
  pickers, helper-exe verification, and the Ctrl-to-save gesture already wired
  in. Use this as the starting point for substantial dialogs.
- In-memory `DLGTEMPLATE` (built in C++, no `.rc` / `.res` linking) — acceptable
  for very small popups (3–6 controls); avoid it once a dialog needs grouping or
  multiple fonts.
- *No dialog yet*, sidecar-only cfg — acceptable for v0.1 of a single-purpose
  X-Tension whose configuration is short and analyst-stable (e.g. a Neo4j URL or
  a target-query path); promote to a real dialog once user-facing toggles
  multiply.

## When to use which pattern

| Pattern | When | Examples |
| --- | --- | --- |
| `.rc` + `resource.h` + `DialogBoxParamW` | Two or more grouped sections, file/folder pickers, runtime-populated checkbox grids, any control over 12pt-equivalent visual hierarchy | xways-bulk_extractor (rich settings) |
| In-memory `DLGTEMPLATE` built in C++ | 3–6 controls, one screen, no font/group customization needed, build pipeline shouldn't pull in `rc.exe` | a wrapper's per-tool checkboxes |
| Sidecar `.cfg` only (no dialog) | One-time setup configuration that an analyst sets once and forgets | a wrapper's DB URL/credentials or plugin list |

If a sidecar-only X-Tension grows past ~6 cfg keys or its first interactive
choice, promote it to an `.rc` dialog rather than expanding the cfg shape.

## File layout (.rc dialogs)

```text
x-tensions/xways-<name>/
├── xways-<name>.cpp        # entry points + dialog proc + handlers
├── xways-<name>.def        # exports
├── xways-<name>.rc         # DIALOGEX template (see below)
├── resource.h              # IDC_* / IDD_* constants
├── common.{h,cpp}          # XWF resolver + helpers (copy from the wrapper template)
└── build.bat               # compiles resources via rc.exe + cl.exe
```

`build.bat` must compile the `.rc` and link the resulting `.res` alongside
the `.obj` files:

```cmd
rc /nologo /fo xways-<name>.res xways-<name>.rc || goto :fail
link %LDFLAGS% common.obj xways-<name>.obj xways-<name>.res %LIBS% || goto :fail
```

## Identifier numbering convention

`resource.h` uses the following ID ranges to keep IDs predictable across
X-Tensions and avoid collisions when subordinate code grafts in shared
controls:

| Range | Purpose |
| --- | --- |
| `100..199` | Dialog templates (`IDD_*`) and primary control IDs (`IDC_GROUP_*`, `IDC_LABEL_*`, `IDC_EDIT_*`, `IDC_BTN_*`, `IDC_CHK_*`, `IDC_RADIO_*`). One number per control. |
| `5000..5999` | Programmatically-created controls (e.g. scanner checkboxes built at WM_INITDIALOG time, one per upstream plugin/scanner). Use a `_BASE` / `_LAST` pair to bound the range. |

Don't reuse Win32 standard IDs (`IDOK = 1`, `IDCANCEL = 2`) for anything
else. The dialog's primary action button must be `IDOK` (the
`DEFPUSHBUTTON`) and the cancel button must be `IDCANCEL` so Enter / Escape
keystrokes route correctly.

## Standard section layout

```text
+------------------------------------------------------------+
| <X-Tension name> - Settings  (vMAJOR.MINOR.PATCH)          |  ← title bar
+------------------------------------------------------------+
| ┌─ Input source ──────────────────────────────────────┐   |  ← GROUPBOX
| | ( ) Active evidence object's source image          |   |
| | ( ) External file or directory:                    |   |
| |     [edit path                ] [File...] [Folder] |   |
| | ( ) Use selected items in directory browser        |   |
| | [ ] sub-option 1                                   |   |
| | [ ] sub-option 2                                   |   |
| └─────────────────────────────────────────────────────┘   |
|                                                            |
| Tool binary:                                               |  ← field label
| [edit path                                  ] [Browse...]  |
|                                                            |
| ┌─ Plugins / Scanners ──────────┐  [Reset to defaults  ]   |
| | [ ] plugin_1   [ ] plugin_4   |  [Check / Uncheck all]   |
| | [ ] plugin_2   [ ] plugin_5   |                          |
| | [ ] plugin_3   [ ] plugin_6   |                          |
| └───────────────────────────────┘                          |
|                                                            |
| ┌─ Output handling ─────────────┐  Threads:    [ 4 v ]     |
| | Output directory:             |  Max recurse:[ 5 ]       |
| | [edit path        ] [Browse]  |                          |
| | [ ] Add output to case        |                          |
| | [ ] Open folder when done     |                          |
| └───────────────────────────────┘                          |
|                                                            |
|                                          [Run]  [Cancel]   |  ← bottom right
+------------------------------------------------------------+
```

This is the canonical order for a tool-wrap X-Tension. Not every X-Tension
needs every section — pick the ones that apply. The order is load-bearing:
**analysts read top-to-bottom**, and the cognitive flow is "what am I
processing (input) → what tool am I using → which features → where does
output go." Don't shuffle for visual reasons.

Specific X-Tensions add their own sections (e.g. xways-bulk_extractor has a
"Run via WSL" toggle + detected-version readout inside the Tool-binary row),
but the four-group skeleton above is the consistent shape.

## Title bar

Caption in the `.rc`:

```rc
CAPTION "<X-Tension name> - Settings"
```

`WM_INITDIALOG` appends the version constant at runtime so the analyst
always knows which build they're running:

```cpp
wchar_t title[256] = {0};
GetWindowTextW(hDlg, title, 256);
std::wstring augmented = title;
augmented += L"  (v";
augmented += VERSION;
augmented += L")";
SetWindowTextW(hDlg, augmented.c_str());
```

Don't bake the version into the `.rc` caption directly — it would drift the
moment `VERSION` is bumped and only one place is updated.

## Font hierarchy

The `.rc` `FONT` directive carries one font for the whole dialog. Use
`WM_SETFONT` to overlay per-role fonts at `WM_INITDIALOG`:

| Role | Size / weight | Examples |
| --- | --- | --- |
| GROUPBOX title (section header) | 11pt bold | "Input source", "Output handling" |
| Field label (`LTEXT` followed by an EDITTEXT or COMBOBOX) | 10pt bold | "Output directory:", "Threads:" |
| Body text / radio button / standalone checkbox | 10pt regular (dialog default) | radio options, action checkboxes |
| Dense control grid (scanner / plugin checkboxes) | 9pt regular | per-scanner checkboxes in xways-bulk_extractor |

Use the DPI-aware font construction pattern:

```cpp
HDC hdc = GetDC(hDlg);
int dpiY = hdc ? GetDeviceCaps(hdc, LOGPIXELSY) : 96;
if (hdc) ReleaseDC(hDlg, hdc);

LOGFONTW lf = {};
lf.lfWeight  = FW_BOLD;
lf.lfCharSet = DEFAULT_CHARSET;
wcscpy_s(lf.lfFaceName, LF_FACESIZE, L"MS Shell Dlg");
lf.lfHeight  = -MulDiv(11, dpiY, 72);
HFONT s_groupTitleFont = CreateFontIndirectW(&lf);
```

Cache custom fonts as `static HFONT s_<role>Font` inside the dialog proc —
they outlive each dialog open and only leak on DLL unload (one-time, milli-GDI).

## Settings round-trip (LPARAM convention)

Stamp out the per-X-Tension `Settings` struct in `common.h` / the X-Tension's
main header. `XT_Prepare` builds a `Settings` from sidecar + context, hands
the address to `DialogBoxParamW` via `LPARAM`, the dialog proc reads /
writes the same struct, return value is `IDOK` / `IDCANCEL`:

```cpp
struct Settings {
    InputMode    inputMode;           // radio choice
    std::wstring inputPath;
    std::wstring outputDir;
    bool         addToCase  = true;
    bool         openFolder = false;
    std::vector<bool> scannerOn;      // per-scanner checkbox state
    // ... per-X-Tension fields
};

static bool ShowSettingsDialog(HWND parent, Settings& s) {
    INT_PTR rv = DialogBoxParamW(g_hSelf, MAKEINTRESOURCEW(IDD_SETTINGS),
                                 parent, SettingsDlgProc,
                                 reinterpret_cast<LPARAM>(&s));
    return rv == IDOK;
}
```

Inside the dialog proc, cache the pointer on `WM_INITDIALOG`:

```cpp
static INT_PTR CALLBACK SettingsDlgProc(HWND hDlg, UINT msg, WPARAM wp, LPARAM lp) {
    static Settings* s = nullptr;
    switch (msg) {
    case WM_INITDIALOG:
        s = reinterpret_cast<Settings*>(lp);
        // ... populate controls from *s
        return TRUE;
    case WM_COMMAND:
        if (LOWORD(wp) == IDOK && s) {
            // ... read controls back into *s
            EndDialog(hDlg, IDOK);
            return TRUE;
        }
        if (LOWORD(wp) == IDCANCEL) {
            EndDialog(hDlg, IDCANCEL);
            return TRUE;
        }
        break;
    }
    return FALSE;
}
```

Static `Settings* s = nullptr` works because the X-Tension is single-threaded
through `XT_Prepare` and the dialog is modal. Don't use a thread-local or a
property on the HWND for this — the static is simpler and matches the
exemplar and template implementations.

## Context-aware defaults

Don't make the analyst toggle the same setting every run. The dialog proc
should pick the most useful default given the live X-Ways context:

```cpp
// Pick the most useful radio default:
int radio = IDC_RADIO_INPUT_PICK;            // fallback
if      (s->selectionMode)    radio = IDC_RADIO_INPUT_SELECTED;
else if (s->hasActiveEoImage) radio = IDC_RADIO_INPUT_EVOIMAGE;
CheckRadioButton(hDlg, IDC_RADIO_INPUT_EVOIMAGE,
                 IDC_RADIO_INPUT_SELECTED, radio);
```

The X-Tension's `XT_Prepare` already knows: is `XT_ACTION_DBC` set? did the
EvObj-source resolver find a usable image path? populate the boolean flags
inside `Settings` before showing the dialog.

## Hint text for disabled controls

If a control is disabled because something on the system is missing or
unavailable, **say so** in a static text right next to it. Don't just gray
the control out — analysts can't tell whether it's disabled-on-purpose or
disabled-because-the-X-Tension-broke.

```cpp
if (!s->hasActiveEoImage && !s->eoUnavailableReason.empty()) {
    std::wstring hint = L"  (" + s->eoUnavailableReason + L")";
    SetDlgItemTextW(hDlg, IDC_STATIC_EO_HINT, hint.c_str());
}
```

`IDC_STATIC_EO_HINT` in the `.rc` is a zero-width-when-empty `LTEXT`
positioned next to the disabled radio.

## One-time detection caching

Detection-heavy operations (probing WSL, finding a bundled binary, version
sniffing) should run at most once per X-Tension load — not once per dialog
open. Cache via a function-local static:

```cpp
static const WslInfo& DetectWslOnce() {
    static WslInfo info;
    static bool detected = false;
    if (detected) return info;
    detected = true;
    // ... probe wsl --status, which bulk_extractor, -V, etc.
    return info;
}
```

300 ms of `wsl --status` latency added once at first dialog open is
acceptable; adding it on every dialog open isn't.

## Browse buttons

Every path-shaped edit gets a `Browse...` push button to its right:

```rc
EDITTEXT                                IDC_EDIT_OUTPUT_DIR,  14, 394, 215, 12, ES_AUTOHSCROLL
PUSHBUTTON      "Browse...",            IDC_BTN_BROWSE_OUTPUT,233, 393,  47, 14
```

Two button labels are common: `Browse...` (single combined picker for
either file or folder — usually folder), or split-pair `File...` + `Folder...`
when the same edit accepts either (xways-bulk_extractor input path).

Use the `SHBrowseForFolderW` Win32 API for folder picking; `GetOpenFileNameW`
for file picking. Both wrapped behind a `BrowseForFolder(hDlg, current)` and
`BrowseForFile(hDlg, current, filter)` helper that returns the picked path
or empty string on cancel. The helpers live in `common.cpp` once and are
shared across X-Tensions.

## Status-text coloring (optional polish)

For "we detected something good" status text (e.g. "WSL bulk_extractor v2.1.1
detected"), paint blue via `WM_CTLCOLORSTATIC`:

```cpp
case WM_CTLCOLORSTATIC: {
    HDC hdc = (HDC)wp;
    HWND hCtrl = (HWND)lp;
    if (GetDlgCtrlID(hCtrl) == IDC_STATIC_WSL_VERSION) {
        SetTextColor(hdc, RGB(0x10, 0x60, 0xC0));   // mid blue
        SetBkMode(hdc, TRANSPARENT);
        return (INT_PTR)GetStockObject(NULL_BRUSH);
    }
    break;
}
```

Don't paint red for "missing" status — gray-disabled is enough; reserve red
for hard validation errors at IDOK time.

## Programmatic children inside a GROUPBOX (padTop must clear the title)

When creating child controls inside a GROUPBOX at runtime (the plugin /
scanner / profile-row grid pattern), the first row's `y` is computed as
`grouptop + padTop`. **Hard-coding `padTop` to a guess like `22` breaks
when the GROUPBOX title font is larger than the dialog default** — e.g.
with an 11pt-bold group title, first-row controls visibly overlap the
group title (the GROUPBOX renders its caption INSIDE the box, occupying
y=0..tmHeight of the same client area your children live in).

The fix — measure with the GROUPBOX's actual current font, fetched
via `WM_GETFONT`:

```cpp
int padTop = 22;  // sane default for the 9pt dialog font
{
    HDC hdc = GetDC(hDlg);
    HFONT titleFont = (HFONT)SendMessageW(grp, WM_GETFONT, 0, 0);
    if (hdc && titleFont) {
        HFONT old = (HFONT)SelectObject(hdc, titleFont);
        TEXTMETRICW tm = {};
        if (GetTextMetricsW(hdc, &tm)) {
            // tmHeight = ascender + descender; +10px is the empty
            // band between title bottom and first child row.
            int derived = tm.tmHeight + 10;
            if (derived > padTop) padTop = derived;
        }
        SelectObject(hdc, old);
    }
    if (hdc) ReleaseDC(hDlg, hdc);
}
```

Always use `WM_GETFONT` rather than your own stored font handle — the
GROUPBOX caches whichever font was last `WM_SETFONT`'d to it, and
matching what Windows actually renders is the only way to get the math
right across DPI / theme / font-substitution changes.

Place the snippet above directly above the
`for (i = 0; i < nRows; ++i)` programmatic-create loop.

## Auto-fit shrink-to-content (advanced)

When a section's natural height depends on the number of dynamically-created
controls (e.g. one row per detected scanner / plugin), the GROUPBOX in the
`.rc` is over-allocated to the worst case. At WM_INITDIALOG, measure the
actual rendered height and:

1. `SetWindowPos(grp, ..., natural_h, ...)` shrinks the GROUPBOX.
2. Walk a `kShiftIds[]` list of controls below and `SetWindowPos` each
   up by the saved delta.
3. `SetWindowPos(hDlg, ..., dialogHeight - delta, ...)` shrinks the dialog
   itself.

See xways-bulk_extractor's `xways-bulk_extractor.cpp` (WM_INITDIALOG handler around line 940)
for the working implementation. Only do this when the natural size really
varies — otherwise it's premature complexity.

## Common control IDs (recommended)

To make handler code easy to grep across X-Tensions, use these IDC names
consistently. Numbers can change per X-Tension; the *names* should not.

| Name | Purpose |
| --- | --- |
| `IDD_SETTINGS` | Main settings dialog |
| `IDC_GROUP_INPUT` | Input source GROUPBOX |
| `IDC_RADIO_INPUT_EVOIMAGE` | "Active evidence object's source image" radio |
| `IDC_RADIO_INPUT_PICK` | "External file or directory" radio |
| `IDC_RADIO_INPUT_SELECTED` | "Use selected items in directory browser" radio |
| `IDC_EDIT_INPUT_PATH` | Path edit under the External-path radio |
| `IDC_BTN_BROWSE_INPUT_FILE` / `_DIR` | File / folder picker buttons |
| `IDC_STATIC_EO_HINT` | Hint text next to the EO-image radio when unavailable |
| `IDC_STATIC_SELECTED_COUNT` | Count text next to the Selected-items radio |
| `IDC_GROUP_TOOL` | Tool binary GROUPBOX (if the binary needs its own group) |
| `IDC_LABEL_TOOL_BIN` | "Tool binary:" label |
| `IDC_EDIT_TOOL_BIN` | Path edit for the tool exe |
| `IDC_BTN_BROWSE_TOOL` | Browse button for the tool exe |
| `IDC_GROUP_PLUGINS` | Plugins / Scanners GROUPBOX |
| `IDC_BTN_RESET_PLUGINS` | "Reset to defaults" |
| `IDC_BTN_TOGGLE_ALL` | Smart "Check / Uncheck all" |
| `IDC_PLUGIN_BASE` / `IDC_PLUGIN_LAST` | Range for programmatically-created plugin checkboxes (5000..5099) |
| `IDC_GROUP_OUTPUT` | Output handling GROUPBOX |
| `IDC_LABEL_OUTPUT` | "Output directory:" label |
| `IDC_EDIT_OUTPUT_DIR` | Output dir edit |
| `IDC_BTN_BROWSE_OUTPUT` | Browse for output folder |
| `IDC_CHK_ADD_TO_CASE` | "Add output dir to case as evidence object" |
| `IDC_CHK_OPEN_FOLDER` | "Open output folder in Explorer when done" |
| `IDC_CHK_TAG_*` | Per-X-Tension tagging toggles |

Append per-X-Tension IDs after these (use the `120..` range for
tool-specific labels like `IDC_LABEL_THREADS`, `IDC_LABEL_MAXRECURSE`,
etc.).

## Sidecar cfg ↔ dialog state

The dialog populates from a `Settings` struct that was already initialized
from the sidecar `.cfg`. The Run button writes the struct back; the
X-Tension's pipeline reads from the same struct.

Two-way persistence pattern (a common pattern for self-contained wrappers,
e.g. xways-bulk_extractor):

1. `XT_Prepare` loads the `.cfg` into `Settings` via the cfg reader.
2. `XT_Prepare` overlays context (selectionMode, hasActiveEoImage,
   eoUnavailableReason) into the same struct.
3. Dialog populates controls from `Settings`.
4. Dialog writes controls back to `Settings` on Run.
5. Pipeline reads `Settings` and runs.
6. Optional: a "Save as default" checkbox in the dialog writes the modified
   `Settings` back to the `.cfg` after the run.

The cfg's key names should match the `Settings` field names where possible
(e.g. cfg `add_to_case = true` ↔ `s.addToCase`). Keeps cross-X-Tension
analyst-edit muscle memory intact.

## Cancel safety

`IDCANCEL` (Esc / close button / explicit Cancel button) must abort the run
cleanly — return from `XT_Prepare` without setting up the run dir, without
extracting items, without invoking subprocesses. The dialog proc returning
`IDCANCEL` propagates through `ShowSettingsDialog` returning `false`, which
`XT_Prepare` checks and exits on.

Don't pop a "Are you sure?" — analyst already decided. Pop a confirmation
only when a destructive choice is being made (e.g. "Output dir exists and
will be overwritten — proceed?").

## Validation

Validate at IDOK time, before `EndDialog`. Refuse to close on bad input,
with a `MessageBoxW` pointing at the problem and the analyst still in the
dialog:

```cpp
if (LOWORD(wp) == IDOK) {
    wchar_t path[MAX_PATH] = {0};
    GetDlgItemTextW(hDlg, IDC_EDIT_INPUT_PATH, path, MAX_PATH);
    if (!*path) {
        MessageBoxW(hDlg, L"Input path is required.", L"Settings", MB_ICONWARNING);
        SetFocus(GetDlgItem(hDlg, IDC_EDIT_INPUT_PATH));
        return TRUE;
    }
    // ... write to *s + EndDialog(hDlg, IDOK)
}
```

Validation that needs subprocess probes (e.g. "does this binary respond
to --version?") happens **after** the dialog closes — log an error to the
Messages window and return from `XT_Prepare` rather than blocking the UI.

## Don't

- Don't use `Sleep()` inside `WM_INITDIALOG` — pumps freeze.
- Don't make the dialog modeless. Every settings dialog is modal.
- Don't carry persistent state in static globals other than cached HFONTs
  / one-time-detection caches — keep the `Settings*` LPARAM as the only
  state pipe.
- Don't pop progress dialogs as a SECOND window during the run. Embed the
  progress bar + status label in the SAME settings dialog (the bar stays
  visible from open; the worker drives it during the run).
- Don't ship per-control hardcoded screen-pixel offsets when the .rc DLU
  values would do — Windows handles DPI scaling for you when you stay in
  dialog units.
- Don't put a banner/status string at the top of the dialog. The bottom
  status line is the single source of truth for what's happening.

## Cue-banner placeholders (every edit gets one)

`EM_SETCUEBANNER` shows greyed placeholder text in an edit when it's empty.
Shorter than tooltips; tooltips explain WHY, cue banners hint at FORMAT.
Pass `TRUE` as wParam so the placeholder stays visible while the edit has
focus:

```cpp
SendDlgItemMessageW(hDlg, IDC_EDIT_FILTER_ENTROPY,
                    EM_SETCUEBANNER, TRUE,
                    (LPARAM)L"e.g. 3.0  (blank = off)");
```

For path-shaped edits, the cue banner is often the resolved default path
itself (e.g. the case directory) — so an empty field clearly shows where
output will land. See `ApplyCueBanners()` in the `wrapper` template
(`templates/x-tensions/wrapper/my_xtension.cpp`) for the canonical pattern.

## Tooltip popups (every non-obvious control)

Win32 `TOOLTIPS_CLASS` attached via `TTF_SUBCLASS` — the tooltip control
hooks each target's mouse events itself, so no per-message forwarding is
needed. Lives for the dialog's lifetime; destroy it on `WM_DESTROY`.

Required: `ICC_BAR_CLASSES` in the `InitCommonControlsEx` call at
`XT_Init` time (registers `TOOLTIPS_CLASS`).

```cpp
HWND hTip = CreateWindowExW(WS_EX_TOPMOST, TOOLTIPS_CLASSW, nullptr,
                            WS_POPUP | TTS_ALWAYSTIP | TTS_NOPREFIX,
                            CW_USEDEFAULT, CW_USEDEFAULT,
                            CW_USEDEFAULT, CW_USEDEFAULT,
                            hDlg, nullptr, g_hSelf, nullptr);
SendMessageW(hTip, TTM_SETMAXTIPWIDTH, 0, 360);
SendMessageW(hTip, TTM_SETDELAYTIME, TTDT_AUTOPOP, MAKELPARAM(12000, 0));

for (const auto& t : kTooltips) {
    HWND hCtl = GetDlgItem(hDlg, t.id);
    if (!hCtl) continue;
    TOOLINFOW ti = {};
    ti.cbSize   = sizeof(ti);
    ti.uFlags   = TTF_IDISHWND | TTF_SUBCLASS;
    ti.hwnd     = hDlg;
    ti.uId      = (UINT_PTR)hCtl;
    ti.lpszText = (LPWSTR)t.text;
    SendMessageW(hTip, TTM_ADDTOOLW, 0, (LPARAM)&ti);
}
```

Tip-text style: multi-line, explain WHY rather than WHAT. Skip tooltips on
self-evident controls (path edits, Browse, About, Run, Cancel).

## Progress + task status pattern (worker-driven)

Embed progress in the SAME dialog (not a second window). The bar lives at a
fixed row near the bottom and stays VISIBLE in all states — idle pre-Run,
advancing during the scan, full at Done. No `NOT WS_VISIBLE` in the `.rc`.

Worker posts WM_APP_* messages back to the dialog:

| Message | wParam | lParam | Purpose |
| --- | --- | --- | --- |
| `WM_APP + 1` (PROGRESS) | permille (0..1000) | — | Bar position |
| `WM_APP + 2` (STATUS) | — | heap `wchar_t*` (dialog frees) | Status label text |
| `WM_APP + 3` (DONE) | success bool | — | Cleanup + re-enable inputs |
| `WM_APP + 4` (MARQUEE) | 1 start / 0 stop | — | Indeterminate animation |

**Per-stage task status.** Don't just post `"N/M scanned"`. Post the
current task each step so the analyst sees what's happening when one item
takes seconds:

```cpp
PostStageStatus(w, idx, total, L"Extracting",              leaf);
ExtractItemToFile(...);
PostStageStatus(w, idx, total, L"Scanning",                leaf);
ScanItem(...);
```

Helper format: `[N/M]  <task>: <leaf>` (trim leaf with `…` prefix if
longer than ~64 chars).

## Default output base = case directory

Don't dump per-X-Tension artifacts under `%TEMP%` or the evidence working
dir by default — analysts want them inside the case. Resolve via:

```cpp
// XWF_GetCaseProp(NULL, 6, ...)  -> case directory
// XWF_GetEvObjProp(hEv, 12, ...) -> evidence "Internally used directory"
// %TEMP%                          -> last-resort
std::wstring ResolveDefaultOutputBase(HANDLE hEvidence,
                                      std::wstring& sourceLabel) {
    std::wstring caseDir = GetCaseDirectory();
    if (!caseDir.empty()) { sourceLabel = L"X-Ways case directory"; return caseDir; }
    std::wstring evDir = GetEvidenceWorkingDir(hEvidence);
    if (!evDir.empty())   { sourceLabel = L"evidence working dir"; return evDir; }
    wchar_t base[MAX_PATH] = {0};
    DWORD n = GetTempPathW(MAX_PATH, base);
    if (n > 0 && n <= MAX_PATH) { sourceLabel = L"%TEMP%"; return base; }
    sourceLabel = L"C:\\Temp\\ (last-resort)";
    return L"C:\\Temp\\";
}
```

Per-run layout: `<outputBase>\<xtension-name>\run-YYYYMMDD-HHMMSS\`. The
X-Tension-name subfolder is critical — without it, multiple X-Tensions
would dump artifacts side-by-side in the case root.

## Button label conventions

- **No trailing ellipsis** (`...`) on `About`, `Cancel`, `Run`, `Save`, or any action button that performs an immediate operation. Reserve `...` for buttons that explicitly prompt the user for more input before the action runs (e.g. `Browse...`, `File...`, `Folder...`). Yes, this differs from Microsoft's HIG which says `...` indicates "opens a dialog" — this convention is tighter: only buttons that *need* the user to type/pick something first earn the dots. `About` opens a dialog but doesn't ask anything → no dots. `Browse` asks the user to pick a file/folder → dots.
- **`&` mnemonic** on every button: `&Run`, `&About`, `&Open output folder`, `Open &cfg`, etc. Pick a non-colliding letter per dialog.
- **Default button** (DEFPUSHBUTTON in the `.rc`) is the primary action (`Run`), so Enter triggers it from any control.
- **Cancel** is always `IDCANCEL` (the ID, not the label) so Esc and the close box route to it automatically.

## Modifier-key state on action buttons

When a button has a "primary + modifier" variant (e.g. Run + Shift-to-save, Copy + Shift-for-with-attachments), make the modifier state **visible** while held. Two complementary signals:

1. **Label flip** — change the button text in the WM_TIMER tick that polls the modifier key. See the `wrapper` template (`templates/x-tensions/wrapper/my_xtension.cpp`) (`&Run` ↔ `&Save`).
2. **Color flip** — paint the button face in the Windows accent blue (`RGB(0, 120, 215)` / pressed `RGB(0, 90, 168)`) with white text so the analyst gets a strong visual cue that "clicking now does something different." Requires switching the button to `BS_OWNERDRAW` style at `WM_INITDIALOG` and handling `WM_DRAWITEM` to paint the alternate state. Force a `InvalidateRect` on the button each time the timer flips the label, so the new paint kicks in even when the mouse isn't over it.

Owner-draw skeleton (drop into your X-Tension):

```cpp
// WM_INITDIALOG:
for (int id : { IDC_BTN_RUN, (int)IDCANCEL }) {
    HWND h = GetDlgItem(hDlg, id);
    if (h) SetWindowLongPtrW(h, GWL_STYLE,
                             GetWindowLongPtrW(h, GWL_STYLE) | BS_OWNERDRAW);
}

// WM_TIMER (label-flip path):
SetDlgItemTextW(hDlg, IDC_BTN_RUN, shiftDown ? L"&Save" : L"&Run");
InvalidateRect(GetDlgItem(hDlg, IDC_BTN_RUN), nullptr, TRUE);
// Cancel button only flips when no worker is running, so the analyst
// doesn't get a confusing "Cancel or save?" affordance mid-scan.
bool cancelSaveMode = shiftDown && (g_workerThread == nullptr);
SetDlgItemTextW(hDlg, IDCANCEL,
                cancelSaveMode ? L"Save copy to..." : L"Cancel");
InvalidateRect(GetDlgItem(hDlg, IDCANCEL), nullptr, TRUE);

// WM_DRAWITEM (one handler for BOTH buttons):
DRAWITEMSTRUCT* dis = (DRAWITEMSTRUCT*)lp;
bool isRunBtn    = (dis->CtlID == IDC_BTN_RUN);
bool isCancelBtn = (dis->CtlID == IDCANCEL);
if (!isRunBtn && !isCancelBtn) break;
bool altMode = (isRunBtn && s_shiftLabelOn) || (isCancelBtn && s_cancelLabelOn);
bool isPressed = (dis->itemState & ODS_SELECTED) != 0;
COLORREF bg = altMode ? (isPressed ? RGB(0,90,168) : RGB(0,120,215))
                      : GetSysColor(COLOR_BTNFACE);
COLORREF fg = altMode ? RGB(255,255,255) : GetSysColor(COLOR_BTNTEXT);
// Fill, frame, focus rect, text via the dialog's WM_GETFONT.
```

### Shift+Cancel = "Save copy to..." (sister of Shift+Run)

When the dialog owns a sidecar cfg, the Cancel button gains a second affordance under Shift: open a folder picker, write a COPY of the cfg there with an auto-numbered filename if a file with the base name already exists. Useful for snapshotting a working configuration before experimenting, or for shipping a cfg to another analyst.

```cpp
if (LOWORD(wp) == IDCANCEL) {
    bool shiftHeld = (GetAsyncKeyState(VK_SHIFT) & 0x8000) != 0;
    if (shiftHeld && g_workerThread == nullptr) {
        if (!ReadDialogToSettings(hDlg, *s)) return TRUE;
        std::wstring folder = BrowseForFolder(hDlg, L"",
            L"Save a copy of <xtension>.cfg to...");
        if (!folder.empty()) {
            std::wstring target = folder + L"\\<xtension>.cfg";
            int n = 1;
            while (FileExists(target)) {
                target = folder + L"\\<xtension>-" + std::to_wstring(++n) + L".cfg";
            }
            SaveSettingsToCfg(target, *s);
        }
        return TRUE;
    }
    // ... existing cancel-worker-or-close logic
}
```

Gate on `g_workerThread == nullptr` — disabling save-copy during an active scan is the right call (the cfg is in a meaningful state and the analyst shouldn't be context-switching mid-run).

## Folder pickers: prefer `IFileOpenDialog` over `SHBrowseForFolderW`

The Vista-era `IFileOpenDialog` (COM, `CLSID_FileOpenDialog`) with `FOS_PICKFOLDERS` is the modern folder-picker on Windows. Compared with the legacy `SHBrowseForFolderW`:

- **"New folder" toolbar button is always visible** at the top of the dialog. The legacy dialog has the same feature via `BIF_NEWDIALOGSTYLE` but the button is much less prominent — analysts often miss it.
- **Modern Explorer-style UI** — matches the rest of the OS.
- **Resizable, with tree + flat-list view + breadcrumb path bar**.
- **Title bar text** is settable, so multiple pickers in the same dialog can have distinct titles ("Select output directory" vs. "Save a copy of the cfg to...").

Skeleton (drop into any X-Tension that needs a folder picker):

```cpp
static std::wstring BrowseForFolder(HWND parent, const std::wstring& current,
                                    const wchar_t* title = L"Select folder") {
    HRESULT hrInit = CoInitializeEx(nullptr,
        COINIT_APARTMENTTHREADED | COINIT_DISABLE_OLE1DDE);
    std::wstring picked = current;

    IFileOpenDialog* dlg = nullptr;
    if (SUCCEEDED(CoCreateInstance(CLSID_FileOpenDialog, nullptr,
                                   CLSCTX_INPROC_SERVER, IID_PPV_ARGS(&dlg))) && dlg) {
        DWORD opts = 0;
        dlg->GetOptions(&opts);
        dlg->SetOptions(opts | FOS_PICKFOLDERS | FOS_FORCEFILESYSTEM | FOS_PATHMUSTEXIST);
        dlg->SetTitle(title);
        if (!current.empty()) {
            IShellItem* psi = nullptr;
            if (SUCCEEDED(SHCreateItemFromParsingName(current.c_str(), nullptr,
                                                     IID_PPV_ARGS(&psi))) && psi) {
                dlg->SetDefaultFolder(psi);
                psi->Release();
            }
        }
        if (SUCCEEDED(dlg->Show(parent))) {
            IShellItem* result = nullptr;
            if (SUCCEEDED(dlg->GetResult(&result)) && result) {
                PWSTR path = nullptr;
                if (SUCCEEDED(result->GetDisplayName(SIGDN_FILESYSPATH, &path)) && path) {
                    picked = path;
                    CoTaskMemFree(path);
                }
                result->Release();
            }
        }
        dlg->Release();
    }
    if (SUCCEEDED(hrInit)) CoUninitialize();
    return picked;
}
```

Required link libs (already in the template `build.bat`): `ole32.lib`, `shell32.lib`. No additional headers beyond `<shobjidl.h>` (pulled in by `<shlobj.h>` which the template already includes).

## Sidecar cfg: one source of truth + Shift-to-save

For any X-Tension that owns a sidecar `.cfg` file (most dialog X-Tensions do), keep ONE serializer that turns the `Settings` struct into cfg text, and use it for both:

1. **Auto-create the cfg on first run** when no `.cfg` exists, by calling `SaveSettingsToCfg(path, Settings{})`. This guarantees the auto-created cfg matches the X-Tension's compiled defaults exactly — no drift between the `Settings` struct, an `.example` reference file, and an embedded fallback string.
2. **Persist on Run.** The Run-button handler calls `SaveSettingsToCfg(path, currentSettings)` BEFORE spawning the worker. The previous cfg is renamed to `<path>.bak` so destructive overwrite is recoverable.

```cpp
// One serializer to rule them all.
static std::wstring SerializeSettings(const Settings& s);
static bool         SaveSettingsToCfg (const std::wstring& path, const Settings& s);
static bool         EnsureCfgExists   (const std::wstring& path) {
    if (FileExists(path)) return true;
    Settings defaults;
    return SaveSettingsToCfg(path, defaults);
}
```

### Shift+Run = save without scanning

Holding **Shift** while clicking the Run button saves the cfg and **skips** the worker. Useful for tuning defaults that the analyst wants to bake in once without immediately running a scan. The button label live-flips between `&Run` and `&Save` while Shift is held, gated on dialog focus so typing Shift+letter in another window doesn't flicker the label.

Implementation skeleton (usable verbatim in your X-Tension):

```cpp
// In SettingsDlgProc:
static bool s_shiftLabelOn = false;
constexpr UINT_PTR kShiftTimerId = 0xC001;
constexpr UINT     kShiftPollMs  = 100;

case WM_INITDIALOG:
    // ... existing setup ...
    s_shiftLabelOn = false;
    SetTimer(hDlg, kShiftTimerId, kShiftPollMs, nullptr);
    return FALSE;

case WM_DESTROY:
    KillTimer(hDlg, kShiftTimerId);
    // ... existing cleanup ...
    return FALSE;

case WM_TIMER:
    if (wp == kShiftTimerId) {
        HWND hFocus = GetFocus();
        HWND hRoot  = hFocus ? GetAncestor(hFocus, GA_ROOT) : nullptr;
        bool inFocus   = (hRoot == hDlg);
        bool shiftDown = inFocus && ((GetAsyncKeyState(VK_SHIFT) & 0x8000) != 0);
        if (shiftDown != s_shiftLabelOn) {
            s_shiftLabelOn = shiftDown;
            SetDlgItemTextW(hDlg, IDC_BTN_RUN, shiftDown ? L"&Save" : L"&Run");
        }
        return TRUE;
    }
    break;

case WM_COMMAND:
    if (LOWORD(wp) == IDC_BTN_RUN) {
        if (!ReadDialogToSettings(hDlg, *s)) return TRUE;
        SaveSettingsToCfg(cfgPath, *s);

        // GetAsyncKeyState at click time -- not s_shiftLabelOn -- is the
        // source of truth (the timer is just a UI hint).
        if ((GetAsyncKeyState(VK_SHIFT) & 0x8000) != 0) {
            // Shift+Run: saved, skip worker.
            SetDlgItemTextW(hDlg, IDC_LABEL_PROGRESS_STATUS,
                            L"Settings saved. (Shift+Run: scan NOT started.)");
            return TRUE;
        }
        // ... spawn worker ...
    }
```

Tooltip the Run button so analysts discover the modifier without reading the README. See the `IDC_BTN_RUN` tooltip in the `wrapper` template (`templates/x-tensions/wrapper/my_xtension.cpp`) for the canonical text.

## Filter-aware item collection (always-collect path)

Don't drive enumeration yourself via `XWF_GetItemCount` + `XWF_OpenItem` —
that ignores the X-Ways active filter and the right-click selection.
Instead, return `0x01` from `XT_Prepare` to request `XT_ProcessItem`
callbacks for BOTH `XT_ACTION_RUN` and `XT_ACTION_DBC`, collect IDs into
a single struct, show the dialog from `XT_Finalize`:

```cpp
LONG __stdcall XT_Prepare(HANDLE hVolume, HANDLE hEvidence, DWORD nOpType, void*) {
    g_collected = Collected{};
    g_collected.ready = true;
    g_collected.hVolume = hVolume; g_collected.hEvidence = hEvidence;
    g_collected.invocationMode = (nOpType == XT_ACTION_DBC)
        ? InvocationMode::Selection : InvocationMode::Run;
    return 0x01;  // request XT_ProcessItem callbacks
}

LONG __stdcall XT_ProcessItem(LONG nItemID, void*) {
    if (g_collected.ready) g_collected.items.push_back(nItemID);
    return 0;
}

LONG __stdcall XT_Finalize(HANDLE, HANDLE, DWORD, void*) {
    if (g_collected.ready) { ShowDialogAndRun(g_collected); g_collected = Collected{}; }
    return 0;
}
```

For `XT_ACTION_RUN` mode X-Ways calls `XT_ProcessItem` only for items
visible under the active filter; for `XT_ACTION_DBC` only for the
right-clicked selection. Same code path either way.

## Template integration

The cpp template at [templates/x-tensions/cpp/](../templates/x-tensions/cpp/)
ships a minimal `XT_Prepare` with no dialog. Promote to a dialog by:

1. Add `xways-<name>.rc` + `resource.h` (copy from the `cpp-xtmgr-compatible`
   template — `templates/x-tensions/cpp-xtmgr-compatible/` — and strip; keep
   only `IDD_SETTINGS` + one GROUPBOX).
2. Update `build.bat`:
   - Add `rc /nologo /fo xways-<name>.res xways-<name>.rc || goto :fail`
     before the cl/link step.
   - Append `xways-<name>.res` to the link line.
3. Add `SettingsDlgProc` + `ShowSettingsDialog` to the `.cpp`.
4. Call `ShowSettingsDialog(g_hMainWnd, settings)` from `XT_Prepare` after
   loading the cfg, before setting up `runDir`.

Scaffold from the `cpp-xtmgr-compatible` template for a fresh example.
