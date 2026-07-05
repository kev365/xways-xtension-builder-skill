# manager-compat — Make an X-Tension manager-compatible

Use this reference when the task is to scaffold a new manager-compatible X-Tension
or to port an existing standalone X-Tension so it also works as a tab inside
`xways-xt-manager`.

The full convention is in `docs/conventions/manager-compatibility.md`.

> **Opt-in / deferred.** `xways-xt-manager` (the tabbed host application) is a
> **separate project that is not yet public**, and its contract
> (`manager-plugin.h`, ABI 1) **may still change**. Do **not** make X-Tensions
> manager-compatible by default — only when the user **specifically asks** for
> `xways-xt-manager` tab support. Otherwise default to a plain `cpp` or
> `wrapper` template. The contract header itself ships in this repo
> (`templates/x-tensions/cpp-xtmgr-compatible/manager-plugin.h`).

---

## When to apply

| Situation | Action |
|---|---|
| User **explicitly asked** for `xways-xt-manager` tab support | Scaffold with `-Template xtmgr` — see Scaffold section below |
| Anything else (the default — manager compat not requested) | Scaffold with `-Template cpp` / `wrapper` — skip manager compat |
| Python X-Tension | Python cannot export `XwaysManagerPluginEntry` — manager compat is not possible; scaffold Python as usual |
| Existing standalone X-Tension being touched | Offer to port it — follow the Port section below |

---

## Scaffold new (only when manager support is requested)

Only when the user has **explicitly asked** for `xways-xt-manager` tab support,
scaffold from the manager-compatible template (otherwise use a plain `cpp` /
`wrapper` template).

```powershell
scripts/new-xtension.ps1 -Name xways-<name> -Template xtmgr
```

The script copies `templates/x-tensions/cpp-xtmgr-compatible/` and renames the
three files (`my_xtension.cpp`, `my_xtension.def`, `my_xtension.rc`) to match
`<name>`. After the copy, follow `references/scaffold-new.md` §4 for the
post-copy rename checklist (identity constants, LIBRARY directive, build.bat
`set NAME=` line).

The template ships with:

- `manager-plugin.h` already present and `#include`d
- A stub `XwaysManagerPluginEntry` returning a static descriptor
  (`abi_version = XWAYS_MANAGER_PLUGIN_ABI_VERSION`,
   `descriptor_size = sizeof(XwaysManagerPluginDescriptor)`)
- `OnInit` / `OnPrepare` / `OnProcessItem` / `OnProcessItemEx` / `OnFinalize`
  stubs delegating to shared `RunInit` / `RunPrepare` / `RunProcessItem` /
  `RunProcessItemEx` / `RunFinalize` internals
- `XwaysManagerPluginEntry` listed in the `.def` EXPORTS section
- A commented-out `OnHarvestSettings` stub to uncomment when the plugin gains
  a real settings dialog

---

## Port into an existing standalone X-Tension

Apply these steps in order when touching an existing X-Tension that lacks
`XwaysManagerPluginEntry`.

### 1. Copy the canonical header

Copy the canonical `templates/x-tensions/cpp-xtmgr-compatible/manager-plugin.h`
into the X-Tension's source folder (e.g.
`x-tensions/xways-<name>/manager-plugin.h` in your own project). Do not
edit the copy — it must stay byte-identical with the canonical. Verify with
`scripts/check-manager-sync.ps1` after the copy.

### 2. Include the header

Add near the top of the X-Tension's `.cpp`, after the existing system includes:

```cpp
#include "manager-plugin.h"
```

### 3. Add a managed-state bridge

If the X-Tension has a settings dialog, add three module-level globals below the
existing `g_hSelf` / `g_hMainWnd` declarations:

```cpp
static bool       g_managed_mode     = false;   // set true in on_init
static Settings   g_managed_settings;           // written by OnHarvestSettings
static DlgState   g_managed_dlg_state;          // fallback when manager passes lParam=0
```

In the dialog proc's `WM_INITDIALOG`, fall back to `&g_managed_dlg_state` when
`lParam == 0` (the manager creates embedded dialogs without a state pointer).

Reference: `g_managed_mode`, `g_managed_settings`, `g_managed_dlg_state` in the
**wrapper** template (`templates/x-tensions/wrapper/`) and the
`cpp-xtmgr-compatible` template.

### 4. Implement the On* callbacks

Add a `// Manager-plugin integration` section at the end of the `.cpp` (before
`DllMain`). Implement five callbacks; all delegate to existing internal
functions — do not duplicate logic:

```cpp
static bool __stdcall MyOnInit(HMODULE, HWND hMainWnd, void*) {
    g_hMainWnd = hMainWnd;
    int missing = RetrieveFunctionPointers();
    if (missing > 0) { Log(L"required XWF_* exports missing — plugin disabled"); return false; }
    g_managed_mode = true;
    LoadCfg(GetSelfDirectory() + L"\\xways-<name>.cfg", g_managed_settings);
    return true;
}

static bool __stdcall MyOnPrepare(HANDLE hVolume, HANDLE hEvidence, DWORD /*nOpType*/, void*) {
    // Force non-interactive: call the existing XT_Prepare body with XT_ACTION_RVS
    // so the standalone dialog does not re-appear inside the manager's dialog.
    XT_Prepare(hVolume, hEvidence, XT_ACTION_RVS, nullptr);
    return true;
}

static bool __stdcall MyOnFinalize(HANDLE hVolume, HANDLE hEvidence, DWORD nOpType, void*) {
    XT_Finalize(hVolume, hEvidence, nOpType, nullptr);
    return true;
}
```

Set `on_process_item` / `on_process_item_ex` to `nullptr` if the plugin does
all its work inside `on_prepare` (a common pattern for self-contained wrappers).
Populate them only if the plugin genuinely needs per-item callbacks in managed
mode.

Reference symbols: the `On*` callback stubs (`OnInit`, `OnPrepare`,
`OnFinalize`) delegating to shared `Run*` internals in the
`cpp-xtmgr-compatible` and **wrapper** templates
(`templates/x-tensions/wrapper/`).

### 5. Implement OnHarvestSettings (if the plugin has a dialog)

Add a harvest callback that reads the embedded dialog's controls into
`g_managed_settings` — mirror the `IDOK` readback in standalone mode, but do
**not** call `EndDialog` (the embedded dialog stays alive across runs):

```cpp
static void __stdcall MyOnHarvestSettings(HWND hEmbeddedDlg, void*) {
    if (!hEmbeddedDlg) return;
    wchar_t buf[MAX_PATH] = {0};
    GetDlgItemTextW(hEmbeddedDlg, IDC_EDIT_MY_PATH, buf, MAX_PATH);
    g_managed_settings.my_path = buf;
    g_managed_settings.my_flag =
        IsDlgButtonChecked(hEmbeddedDlg, IDC_CHK_MY_FLAG) == BST_CHECKED;
    // Persist immediately so the next session inherits the analyst's choices.
    SaveCfg(GetSelfDirectory() + L"\\xways-<name>.cfg", g_managed_settings);
}
```

If the X-Tension currently has no `SaveCfg` helper, write one first — a simple
`key = value` writer mirroring the `LoadCfg` shape.

### 6. Implement XwaysManagerPluginEntry

Add the descriptor and entry point at the end of the manager-plugin section:

```cpp
extern "C" __declspec(dllexport)
const XwaysManagerPluginDescriptor* __stdcall XwaysManagerPluginEntry(void) {
    static const XwaysManagerPluginDescriptor desc = {
        XWAYS_MANAGER_PLUGIN_ABI_VERSION,
        sizeof(XwaysManagerPluginDescriptor),

        L"xways-<name>",          // id — matches DLL filename stem
        L"<Display Name>",        // display_name — tab caption
        L"<One sentence summary>",// description — shown in Tools tab
        VERSION,

        IDD_SETTINGS,             // tab_dialog_resource_id (Option A)
        0,                        // tab_dialog_embedded_resource_id (0 = use Option A)
        SettingsDlgProc,

        MyOnInit,
        MyOnPrepare,
        nullptr,                  // on_process_item
        nullptr,                  // on_process_item_ex
        MyOnFinalize,

        true,                     // default_enabled
        nullptr,                  // reserved

        MyOnHarvestSettings       // NULL if no dialog settings to harvest
    };
    return &desc;
}
```

Use `tab_dialog_embedded_resource_id = 0` (Option A retrofit) unless the
standalone dialog's layout requires a bespoke embedded variant. See
`docs/conventions/manager-compatibility.md` — "Dialog embedding" section.

### 7. Add XwaysManagerPluginEntry to the .def EXPORTS

```
LIBRARY xways-<name>
EXPORTS
    XT_Init
    XT_About
    XT_Prepare
    XT_ProcessItem
    XT_ProcessItemEx
    XT_ProcessSearchHit
    XT_Finalize
    XT_Done
    XwaysManagerPluginEntry
```

Without this line, `GetProcAddress("XwaysManagerPluginEntry")` returns NULL and
the manager's scanner silently skips the DLL.

### 8. Link dependencies

Ensure the linker pulls in `User32.lib`, `Shell32.lib`, `ComCtl32.lib`, and
`Ole32.lib` (the template's `build.bat` already lists them; check the target's
`build.bat` if it was written before manager compat was adopted).

### 9. Build-gate

```powershell
scripts/build-xtension.ps1 -Name xways-<name>
```

Confirm the DLL exports `XwaysManagerPluginEntry`:

```powershell
dumpbin /exports xtensions\xways-<name>\xways-<name>.dll | Select-String "XwaysManager"
```

---

## Maintenance and sync

After any edit to the canonical
`templates/x-tensions/cpp-xtmgr-compatible/manager-plugin.h` (and the wrapper
template's copy):

1. Re-copy the updated header into every X-Tension folder that carries a copy.
2. Run `scripts/check-manager-sync.ps1` — the script exits non-zero if any
   tracked copy differs from the canonical.
3. Rebuild every plugin that has a copy — even if no API changed, the
   `descriptor_size` value embeds `sizeof(XwaysManagerPluginDescriptor)` which
   must match what the running manager expects.

**Additive field (no ABI bump required):** add the new field at the end of
`XwaysManagerPluginDescriptor` after `on_harvest_settings`. Older plugins whose
`descriptor_size` doesn't cover the new field are treated as if the field is
NULL — they load without recompile. New plugins compiled with the updated header
get the field automatically.

**Breaking change (ABI bump required):** increment
`XWAYS_MANAGER_PLUGIN_ABI_VERSION` in the canonical header. The manager refuses
to load plugins whose `abi_version` doesn't match. Every plugin must be
recompiled and re-deployed.

---

## Cross-references

- Full contract details → `docs/conventions/manager-compatibility.md`
- Porting other conventions (output-dir, helper-exe-verification, Ctrl-to-save)
  when touching an X-Tension → `references/port-convention.md`
- Template / language decision matrix → `references/decision-tables.md`
- Auditing existing X-Tensions for gaps → `references/audit-modernize.md`
- Sync verification → `scripts/check-manager-sync.ps1`
