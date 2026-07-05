# Manager-plugin compatibility

!!! warning "Opt-in / work in progress"
    `xways-xt-manager` (a separate project, not yet publicly released) and this
    contract (`manager-plugin.h`, ABI 1) are still
    evolving and **may change**. Treat manager compatibility as **opt-in** — add
    it only when explicitly requested, not by default. New X-Tensions should
    start from a plain `cpp` or `wrapper` template unless manager support is
    specifically asked for.

An X-Tension DLL is **manager-compatible** when it exports `XwaysManagerPluginEntry`
alongside its normal `XT_*` exports. The same binary then works in two modes:

- **Standalone** — X-Ways loads the DLL directly via *Tools → Run X-Tension on Volume
  Snapshot*. The standard `XT_Init` / `XT_Prepare` / `XT_ProcessItem(Ex)` / `XT_Finalize`
  entry points fire normally, including any analyst-facing dialog.
- **Managed** — `xways-xt-manager.dll` loads the DLL via `LoadLibrary`, queries
  `XwaysManagerPluginEntry` for a descriptor, and surfaces the plugin as a tab in its
  own dialog. The plugin's settings dialog is hosted as a child window inside the tab
  page. When the analyst clicks *Run This Plugin* or *Run All Enabled*, the manager
  dispatches through the `on_prepare` / `on_process_item` / `on_finalize` callbacks.

Existing X-Tensions that do **not** export `XwaysManagerPluginEntry` are silently
ignored by the manager scanner — they keep working as standalone X-Tensions without
modification.

**Source of truth:** `templates/x-tensions/cpp-xtmgr-compatible/manager-plugin.h`

---

## The contract

### Entry-point signature

Every manager-compatible DLL exports exactly one function that the manager locates
by name via `GetProcAddress`:

```cpp
extern "C" __declspec(dllexport)
const XwaysManagerPluginDescriptor* __stdcall XwaysManagerPluginEntry(void);
```

The function returns a pointer to a **static, DLL-owned** descriptor. The manager
keeps this pointer for the lifetime of the DLL — the memory must not be freed or
moved.

### Descriptor fields

```cpp
typedef struct {
    // ABI guard — always XWAYS_MANAGER_PLUGIN_ABI_VERSION (currently 1).
    DWORD       abi_version;

    // Total struct size. Manager checks this before reading post-v1 fields.
    DWORD       descriptor_size;

    // Identity (UTF-16; all strings owned by the plugin DLL)
    const wchar_t*  id;             // unique slug, e.g. L"xways-mytool"
    const wchar_t*  display_name;   // tab caption + tools list, e.g. L"My Tool"
    const wchar_t*  description;    // 1-2 sentence summary shown in the Tools tab
    const wchar_t*  version;        // semver string, e.g. L"0.3.0"

    // Tab-UI hosting
    int             tab_dialog_resource_id;           // standalone dialog IDD_; see Dialog embedding
    int             tab_dialog_embedded_resource_id;  // 0 = use Option A retrofit
    DLGPROC         tab_dialog_proc;

    // Lifecycle hooks (any may be NULL; manager skips NULL hooks)
    pfn_ManagerPluginInit          on_init;
    pfn_ManagerPluginPrepare       on_prepare;
    pfn_ManagerPluginProcessItem   on_process_item;
    pfn_ManagerPluginProcessItem   on_process_item_ex;  // separate hook for ProcessItemEx
    pfn_ManagerPluginFinalize      on_finalize;

    // Behavior knob
    bool            default_enabled;  // analyst can toggle; persists in manager cfg

    // Reserved (must be NULL today)
    void*           reserved;

    // -------- Post-v1 additive field --------
    // Manager checks descriptor_size before reading this field.
    pfn_ManagerPluginHarvestSettings  on_harvest_settings;  // NULL = cfg-only runs
} XwaysManagerPluginDescriptor;
```

### Callback signatures

```cpp
// on_init — called once after LoadLibrary. Resolve XWF_* pointers here.
// Return false to refuse load (e.g. required XWF_* exports absent).
typedef bool (__stdcall *pfn_ManagerPluginInit)(
    HMODULE hPluginModule,   // use for resource lookups (FindResource, etc.)
    HWND    hMainWnd,        // X-Ways main window; use as dialog parent
    void*   reserved);       // pass NULL today

// on_prepare — called when analyst clicks Run. Mirror XT_Prepare contract.
// Return false to abort this plugin (manager continues to next enabled plugin).
typedef bool (__stdcall *pfn_ManagerPluginPrepare)(
    HANDLE  hVolume,
    HANDLE  hEvidence,
    DWORD   nOpType,
    void*   reserved);

// on_process_item / on_process_item_ex — called per snapshot item when non-NULL.
// Return 0 to continue; negative to stop. hItem is NULL for on_process_item.
typedef LONG (__stdcall *pfn_ManagerPluginProcessItem)(
    LONG    nItemID,
    HANDLE  hItem,
    void*   reserved);

// on_finalize — called at end of run. Mirror XT_Finalize.
typedef bool (__stdcall *pfn_ManagerPluginFinalize)(
    HANDLE  hVolume,
    HANDLE  hEvidence,
    DWORD   nOpType,
    void*   reserved);

// on_harvest_settings — called immediately BEFORE on_prepare in managed mode.
// Read the embedded dialog's current control state into the plugin's settings
// struct. Do NOT call EndDialog — the embedded dialog stays alive across runs.
// Post-v1 additive; manager checks descriptor_size before calling.
typedef void (__stdcall *pfn_ManagerPluginHarvestSettings)(
    HWND    hEmbeddedDlg,
    void*   reserved);
```

---

## ABI versioning

`XWAYS_MANAGER_PLUGIN_ABI_VERSION` is `1`. The manager refuses to load any plugin
whose `abi_version` field does not match. Rules:

- **Adding a field at the end of the struct** — safe without an ABI bump. The manager
  checks `descriptor_size` (set to `sizeof(XwaysManagerPluginDescriptor)` at compile
  time) before reading any field past `reserved`. Older plugins compiled against the
  older header have a smaller `descriptor_size`; the manager treats missing trailing
  fields as NULL.
- **Breaking changes** — any change to existing field types, reordering, or callback
  signature changes requires incrementing `XWAYS_MANAGER_PLUGIN_ABI_VERSION`. All
  plugins must then recompile against the new header.

`on_harvest_settings` is the first post-v1 additive field. Plugins compiled before it
was added (smaller `descriptor_size`) are treated as if `on_harvest_settings = NULL` —
they still load cleanly, they just receive no pre-prepare harvest call.

---

## Dual-mode delegation

The dual-mode pattern keeps behavioral parity between standalone and managed runs by
routing both through the same internal functions (`RunPrepare` / `WorkerEntry` / etc.):

```
Standalone                         Managed
----------                         -------
X-Ways → XT_Init()                 manager → on_init()          (same XWF_* resolve)
X-Ways → XT_Prepare()              manager → on_harvest_settings()
  └─ shows modal dialog              └─ reads embedded tab dialog controls
  └─ calls WorkerEntry()           manager → on_prepare()
                                     └─ forces XT_ACTION_RVS (non-interactive)
                                     └─ calls WorkerEntry()
X-Ways → XT_Finalize()             manager → on_finalize()      (same cleanup)
```

**Managed mode forces non-interactive.** `on_prepare` must not show a dialog. The
conventional way is to call the existing `XT_Prepare` body with `nOpType` forced to
`XT_ACTION_RVS` — standalone code already skips the settings dialog on RVS. The
manager's embedded tab dialog handles settings in its place.

**`on_init` is the XWF_* resolution point.** The manager calls `on_init` in place of
`XT_Init`. Plugins must not assume `XT_Init` has run when executing under the manager.

**Reference implementation by symbol:**

- The `cpp-xtmgr-compatible` template (`templates/x-tensions/cpp-xtmgr-compatible/my_xtension.cpp`)
  — `OnInit`, `OnPrepare` (calls the `XT_Prepare` body with `nOpType` forced to
  `XT_ACTION_RVS`), `OnFinalize`, `OnHarvestSettings`, `XwaysManagerPluginEntry`.
- The `wrapper` template (`templates/x-tensions/wrapper/my_xtension.cpp`) — the same
  hooks wired around the CLI-wrapper worker (`OnPrepare` calls the shared worker
  directly), plus `XwaysManagerPluginEntry`.

---

## Managed-state bridge (g_managed_state pattern)

When a plugin has a settings dialog, it uses a small set of module-level globals to
bridge dialog state into the managed run path:

```cpp
static bool       g_managed_mode     = false;   // set true in on_init
static Settings   g_managed_settings;           // written by on_harvest_settings
static DlgState   g_managed_dlg_state;          // fallback for the embedded dialog
                                                //  when manager creates it with lParam=0
```

The embedded dialog's `WM_INITDIALOG` handler receives `lParam = 0` from the manager
(the manager has no `DlgState*` to pass). The dialog proc falls back to
`&g_managed_dlg_state` so its initialisation code runs unchanged. `OnHarvestSettings`
writes the analyst's tweaks into `g_managed_settings`; `on_prepare` reads from
`g_managed_settings` to drive the same worker the standalone path uses.

**Source:** the `wrapper` template (`templates/x-tensions/wrapper/my_xtension.cpp`) —
`g_managed_mode`, `g_managed_settings`, `g_managed_dlg_state`;
`OnHarvestSettings` → `CollectSettingsFromDlg` → `SaveSettings` pattern.

---

## Dialog embedding

The manager hosts each plugin's settings dialog as a child window inside its tab page.
Two options:

**Option A — retrofit the standalone dialog (recommended).** Set
`tab_dialog_resource_id` to the existing standalone `IDD_*` and `tab_dialog_embedded_resource_id`
to `0`. The manager strips `WS_POPUP | WS_CAPTION | WS_SYSMENU | DS_MODALFRAME` and adds
`WS_CHILD | DS_CONTROL` at runtime via a patched in-memory copy of the template before
`CreateDialogIndirectParam`. The plugin's `.rc` needs no changes. Tradeoff: the standalone
dialog's bottom-row *Run* / *Cancel* buttons render inside the tab (cosmetic only; the
manager's own buttons drive the lifecycle).

**Option B — second dialog template, native-styled for embedding.** Define a second
`IDD_*` in the `.rc` with `WS_CHILD | DS_CONTROL` already set (no caption, no border,
no Run/Cancel buttons). Set `tab_dialog_embedded_resource_id` to that ID; the manager
uses it directly when non-zero, skipping the Option A retrofit. Use B when the standalone
dialog's layout does not adapt cleanly or when removing the duplicate bottom row matters.

Both bundled templates use **Option A** (`tab_dialog_embedded_resource_id = 0`). See
`OnInit` and `XwaysManagerPluginEntry` in the `cpp-xtmgr-compatible` template
(`templates/x-tensions/cpp-xtmgr-compatible/my_xtension.cpp`) and the `wrapper` template
(`templates/x-tensions/wrapper/my_xtension.cpp`).

---

## Header sync rule

`manager-plugin.h` is **copied** into:

- `templates/x-tensions/cpp-xtmgr-compatible/` (the fork-able template — the
  canonical copy that ships here)
- the `wrapper` template (`templates/x-tensions/wrapper/`)
- every manager-compatible X-Tension folder you fork from these templates

All copies **must stay byte-identical** with the canonical
`templates/x-tensions/cpp-xtmgr-compatible/manager-plugin.h`. Drift — especially in
`XWAYS_MANAGER_PLUGIN_ABI_VERSION` or field order — silently breaks managed loading:
the manager loads the DLL but reads garbage from the descriptor. Run the
manager-sync check script (`.claude/skills/xways-xtension-authoring/scripts/check-manager-sync.ps1`)
after any edit to verify no copy has drifted. The script compares each tracked copy
against the canonical and exits non-zero on any difference.

---

## .def file requirement

`XwaysManagerPluginEntry` must appear in the EXPORTS section of the `.def` file so the
linker emits an undecorated name that `GetProcAddress("XwaysManagerPluginEntry")` can
find at runtime. Without the `.def` entry the manager's scanner silently skips the DLL.

```
LIBRARY xways-myname
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

**Source of truth:** `templates/x-tensions/cpp-xtmgr-compatible/my_xtension.def`

---

## Do / Don't

- **Do** return a pointer to a `static` descriptor — the manager holds the pointer for
  the DLL's lifetime.
- **Do** set `descriptor_size = sizeof(XwaysManagerPluginDescriptor)` — this is the
  forward-compat key that lets older managers skip fields they don't know about.
- **Do** resolve XWF_* function pointers inside `on_init`, not in `XT_Init` — the
  manager does not call `XT_Init`.
- **Do** force `nOpType = XT_ACTION_RVS` (or equivalent non-interactive shape) in
  `on_prepare` to prevent the standalone dialog from re-appearing inside the manager.
- **Do** implement `on_harvest_settings` when the plugin has a settings dialog — without
  it, analyst tweaks in the embedded tab are ignored.
- **Do** keep all copies of `manager-plugin.h` byte-identical with the canonical; run
  `scripts/check-manager-sync.ps1` after any header edit.
- **Don't** call `EndDialog` inside `on_harvest_settings` — the embedded dialog stays
  alive as a tab page across multiple runs.
- **Don't** show a `MessageBox` or modal dialog inside `on_prepare` — the manager's
  dialog is already on screen; nested modals deadlock or produce confusing UX.
- **Don't** set `abi_version` to anything other than `XWAYS_MANAGER_PLUGIN_ABI_VERSION`
  — hard-coding a literal integer bypasses the compile-time guard.
- **Don't** add new fields in the middle of the struct — additive fields only at the
  struct END (after `reserved`), guarded by `descriptor_size`.

---

## See also

- [Wrapper anatomy](wrapper-anatomy.md) — six-element structure for CLI wrappers
- [Helper-exe verification](helper-exe-verification.md) — identity-check pattern for
  tools that wrap external binaries
- [Ctrl-to-save gesture](ctrl-to-save.md) — Ctrl+Run saves without launching
- `templates/x-tensions/cpp-xtmgr-compatible/` — fork-able skeleton for new plugins
