// =============================================================================
//  manager-plugin.h
//
//  Plugin contract for xways-xt-manager (a separate project, not yet
//  publicly released).
//
//  A "manager-compatible X-Tension" is an X-Tension DLL that exports
//  XwaysManagerPluginEntry alongside the usual XT_Init / XT_Prepare / etc.
//  exports. The same DLL works in two modes:
//
//    * Standalone — X-Ways' "Tools → Run X-Tension on Volume Snapshot"
//                   loads the DLL directly. The standard XT_* entry points
//                   fire. The plugin's own dialog (if any) is shown as a
//                   top-level modal as normal.
//    * Managed   — xways-xt-manager loads the DLL via LoadLibrary, queries
//                   XwaysManagerPluginEntry for a descriptor, then
//                   surfaces the plugin as a tab in its own dialog. The
//                   plugin's dialog template is hosted as a child window
//                   inside the manager's tab page. When the analyst clicks
//                   "Run" inside the tab, the manager dispatches via the
//                   plugin's on_prepare / on_process_item / on_finalize
//                   callbacks.
//
//  TO MAKE AN EXISTING X-TENSION MANAGER-COMPATIBLE
//
//    1. #include "manager-plugin.h" in your .cpp.
//    2. Implement XwaysManagerPluginEntry() returning a pointer to a
//       static XwaysManagerPluginDescriptor describing your plugin.
//    3. Add `XwaysManagerPluginEntry` to your .def's EXPORTS section.
//    4. (Optional, for dialog embedding via Option A) Ensure your
//       settings dialog template has the styles WS_CHILD-compatible —
//       see "Dialog embedding" below.
//
//  See templates/x-tensions/cpp-xtmgr-compatible/ for a fork-able example.
//
//  DIALOG EMBEDDING
//
//    The manager hosts your plugin's dialog as a CHILD WINDOW inside one
//    of its tab pages. Win32 dialog templates need style flags compatible
//    with that role.
//
//    Option A — Single dialog, retrofitted at embed time (RECOMMENDED).
//      Ship the same dialog template you use standalone. The manager
//      strips WS_POPUP / WS_CAPTION / DS_MODALFRAME and adds WS_CHILD +
//      DS_CONTROL at runtime via SetWindowLongPtr before showing.
//      Tradeoff: your standalone dialog's caption shows at the top in
//      standalone mode but disappears when embedded — usually desirable.
//      The manager handles the styling; your .rc needs no changes.
//
//    Option B — Second dialog template, native-styled for embedding.
//      Define a second IDD_* in your .rc with WS_CHILD | DS_CONTROL
//      already set (no caption, no border). Set
//      `tab_dialog_embedded_resource_id` in your descriptor to that ID.
//      The manager uses the embedded version when available; falls back
//      to retrofitting the standalone version otherwise.
//
//    Use A unless your dialog is layout-complex enough that the
//    runtime retrofit doesn't look right. The embedded variant is also
//    a good place to drop the standalone version's "Run" / "Cancel"
//    bottom-row buttons — the manager provides its own Run controls.
//
//  ABI / VERSIONING
//
//    Every descriptor carries XWAYS_MANAGER_PLUGIN_ABI_VERSION. The
//    manager refuses to load plugins whose ABI version it doesn't
//    understand. Bumping the ABI is reserved for changes that aren't
//    backwards-compatible (adding fields at the END of the struct is
//    backwards-compatible and doesn't require an ABI bump as long as
//    the manager checks `descriptor_size` before reading new fields).
// =============================================================================

#pragma once

#include <windows.h>

#ifdef __cplusplus
extern "C" {
#endif

// Bump only on breaking changes to the descriptor or callback signatures.
// Additive field changes at the end of the struct use descriptor_size
// instead — see the comment on that field below.
#define XWAYS_MANAGER_PLUGIN_ABI_VERSION 1

// --- Callback signatures ---------------------------------------------------
//   Lifecycle callbacks. The manager invokes these when running an enabled
//   plugin. Each plugin's callbacks run in the manager's address space, so
//   the manager and the plugin share the X-Ways process and its XWF_*
//   resolved function pointers.
//
//   NB: the plugin must NOT assume its own XT_Init has run. The manager
//   calls on_init at the right time. on_init is the plugin's chance to
//   call RetrieveFunctionPointers (or its equivalent) so the plugin's
//   XWF_* globals are populated.

// Called once after the plugin DLL is loaded by the manager. Use this for
// XWF_* pointer resolution + any per-DLL setup. Return false to refuse to
// load (e.g. required XWF_* exports missing on this X-Ways build).
typedef bool (__stdcall *pfn_ManagerPluginInit)(
    HMODULE hPluginModule,   // your own HMODULE (use for resource lookups)
    HWND    hMainWnd,        // X-Ways main window (use as dialog parent)
    void*   reserved);       // future use; pass NULL today

// Called when the analyst clicks "Run" on the plugin's tab (or "Run All
// Enabled" for the whole manager). Mirror XT_Prepare's contract:
// inspect / set up state, return false to abort.
typedef bool (__stdcall *pfn_ManagerPluginPrepare)(
    HANDLE  hVolume,
    HANDLE  hEvidence,
    DWORD   nOpType,
    void*   reserved);

// Called per snapshot item AFTER on_prepare returned true. Return value
// follows XT_ProcessItem's convention (0 normal continue; negative stop).
// The manager invokes this only when the plugin's on_prepare returned a
// shape requesting per-item callbacks.
typedef LONG (__stdcall *pfn_ManagerPluginProcessItem)(
    LONG    nItemID,
    HANDLE  hItem,           // valid only for ProcessItemEx variant; NULL for plain ProcessItem
    void*   reserved);

// Called at the end of the run. Mirror XT_Finalize.
typedef bool (__stdcall *pfn_ManagerPluginFinalize)(
    HANDLE  hVolume,
    HANDLE  hEvidence,
    DWORD   nOpType,
    void*   reserved);

// Called by the manager IMMEDIATELY BEFORE on_prepare when running in
// managed mode and the analyst's tweaks in the embedded tab dialog need
// to take effect. The plugin reads the embedded dialog's control state
// into its own settings struct (analogous to the IDOK handler in
// standalone mode — but WITHOUT calling EndDialog, since the embedded
// dialog stays alive as a tab page across runs).
//
// Optional. Leave the descriptor's on_harvest_settings = NULL if your
// plugin doesn't accept managed-mode runtime tweaks — settings then
// come only from the sidecar cfg + the dialog is display-only inside
// the manager.
//
// ABI: this field is post-v1 additive. Plugins compiled against an
// older header don't include it; the manager checks descriptor_size
// before reading.
typedef void (__stdcall *pfn_ManagerPluginHarvestSettings)(
    HWND    hEmbeddedDlg,
    void*   reserved);

// --- Descriptor ------------------------------------------------------------
typedef struct {
    // ABI guard — set to XWAYS_MANAGER_PLUGIN_ABI_VERSION at compile time.
    DWORD       abi_version;

    // Total struct size (sizeof of the descriptor). The manager uses this
    // to detect plugins compiled against a newer header (with more fields)
    // and to ignore fields it doesn't know about. Set to
    // sizeof(XwaysManagerPluginDescriptor).
    DWORD       descriptor_size;

    // --- Identity (UTF-16; all strings owned by the plugin DLL) ----------
    const wchar_t*  id;             // unique slug, e.g. L"xways-mytool"
    const wchar_t*  display_name;   // tab caption + tools list, e.g. L"My Tool"
    const wchar_t*  description;    // 1–2 sentence summary for the tools tab
    const wchar_t*  version;        // semver, e.g. L"0.3.0"

    // --- Tab-UI hosting --------------------------------------------------
    // Dialog template resource ID to embed in the plugin's tab page. The
    // manager looks this up in hPluginModule via FindResource. The dlgproc
    // pointer must match the standard DLGPROC signature.
    //
    // Two ways to populate:
    //   * Option A (recommended): set tab_dialog_resource_id to your
    //     existing standalone settings dialog ID. The manager retrofits
    //     it for embedding at runtime (strips WS_POPUP / WS_CAPTION /
    //     DS_MODALFRAME; adds WS_CHILD + DS_CONTROL via SetWindowLongPtr
    //     after CreateDialogIndirectParam).
    //   * Option B: define a second dialog template explicitly styled
    //     for embedding (WS_CHILD | DS_CONTROL, no caption, no Run/Cancel
    //     buttons). Set tab_dialog_embedded_resource_id to that ID;
    //     manager uses it directly when non-zero.
    //
    // If both are 0, the manager renders a minimal placeholder tab
    // (name + description + Run button) — useful for tool-only plugins
    // with no per-tab knobs.
    int             tab_dialog_resource_id;
    int             tab_dialog_embedded_resource_id;   // 0 = use Option A path
    DLGPROC         tab_dialog_proc;

    // --- Lifecycle hooks --------------------------------------------------
    // Any can be NULL — the manager just skips. Most plugins implement at
    // minimum on_init + on_prepare; per-item callbacks only if the work
    // shape requires them.
    pfn_ManagerPluginInit          on_init;
    pfn_ManagerPluginPrepare       on_prepare;
    pfn_ManagerPluginProcessItem   on_process_item;
    pfn_ManagerPluginProcessItem   on_process_item_ex;   // separate hook for ItemEx
    pfn_ManagerPluginFinalize      on_finalize;

    // --- Behavior knobs --------------------------------------------------
    // Initial enabled state for this plugin. The analyst can toggle via
    // the Tools tab; the choice persists in the manager's cfg.
    bool            default_enabled;

    // Reserved for future fields. Must be NULL today. The manager checks
    // descriptor_size before reading any field past this point — older
    // plugins compiled against an older header are still loadable.
    void*           reserved;

    // -------- Post-v1 additive fields --------
    // The manager checks descriptor_size against offsetof(field) +
    // sizeof(field) before reading. Older plugins (whose descriptor_size
    // doesn't cover the field) are treated as if the field were NULL.

    // Optional: harvest embedded-dialog settings before on_prepare.
    // See pfn_ManagerPluginHarvestSettings above for semantics.
    pfn_ManagerPluginHarvestSettings  on_harvest_settings;
} XwaysManagerPluginDescriptor;

// --- Entry point -----------------------------------------------------------
// The single export every manager-compatible X-Tension DLL provides. Called
// by xways-xt-manager immediately after LoadLibrary. Returns a pointer to a
// static (DLL-owned) descriptor; the manager keeps the pointer for the
// lifetime of the DLL.
//
// Plugin authors: implement this function. Example:
//
//   const XwaysManagerPluginDescriptor* __stdcall XwaysManagerPluginEntry(void) {
//       static const XwaysManagerPluginDescriptor desc = {
//           XWAYS_MANAGER_PLUGIN_ABI_VERSION,
//           sizeof(XwaysManagerPluginDescriptor),
//           L"xways-myname", L"My Plugin", L"What I do.", L"0.1.0",
//           IDD_SETTINGS, 0, MyDlgProc,
//           MyInit, MyPrepare, MyProcessItem, NULL, MyFinalize,
//           true, NULL
//       };
//       return &desc;
//   }
//
// And add `XwaysManagerPluginEntry` to your .def file's EXPORTS section so
// the manager can find the export by name.
typedef const XwaysManagerPluginDescriptor* (__stdcall *pfn_XwaysManagerPluginEntry)(void);

__declspec(dllexport)
const XwaysManagerPluginDescriptor* __stdcall XwaysManagerPluginEntry(void);

#ifdef __cplusplus
}  // extern "C"
#endif
