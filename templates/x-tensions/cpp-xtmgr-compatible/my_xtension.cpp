// SPDX-License-Identifier: MIT
// =============================================================================
//  manager-compatible X-Tension template (C++ / Windows x64) for X-Ways 21.7+
//
//  This template's defining feature: the SAME DLL works in two modes.
//
//    * Standalone — X-Ways' Tools → Run X-Tension loads the DLL directly.
//                   The XT_* exports below fire.
//    * Managed   — xways-xt-manager loads the DLL via LoadLibrary, queries
//                   XwaysManagerPluginEntry, and dispatches via the On*
//                   callbacks instead. The plugin's settings dialog (if
//                   any) is hosted as a tab.
//
//  Both modes delegate to the same internal functions (RunPrepare,
//  RunProcessItem, RunFinalize). There's no behavioural drift between
//  them — fix a bug once, both modes get it.
//
//  See manager-plugin.h for the contract, and the README for the
//  step-by-step rename/customize workflow.
// =============================================================================

#include <windows.h>
#include <cstdint>
#include <cstdio>
#include <string>

#include "manager-plugin.h"
#include "resource.h"

// --- Identity ---------------------------------------------------------------
static const wchar_t* NAME         = L"my_xtension";
static const wchar_t* VERSION      = L"0.1.0";
static const wchar_t* DESCRIPTION  = L"Template X-Tension. Replace this text.";

static constexpr bool VERBOSE = true;

// --- nOpType ----------------------------------------------------------------
enum : DWORD {
    XT_ACTION_RUN = 0,
    XT_ACTION_RVS = 1,
    XT_ACTION_LSS = 2,
    XT_ACTION_PSS = 3,
    XT_ACTION_DBC = 4,
    XT_ACTION_SHC = 5,
};

// --- Function-pointer typedefs (trim / extend as needed) --------------------
typedef VOID (__stdcall *pfn_XWF_OutputMessage)(const wchar_t*, DWORD);
typedef const wchar_t* (__stdcall *pfn_XWF_GetItemName)(LONG);
typedef INT64  (__stdcall *pfn_XWF_GetItemSize)(LONG);
typedef VOID   (__stdcall *pfn_XWF_GetVolumeName)(HANDLE, wchar_t*, DWORD);
typedef BOOL   (__stdcall *pfn_XWF_AddToReportTable)(LONG, const wchar_t*, DWORD);

static pfn_XWF_OutputMessage    XWF_OutputMessage    = nullptr;
static pfn_XWF_GetItemName      XWF_GetItemName      = nullptr;
static pfn_XWF_GetItemSize      XWF_GetItemSize      = nullptr;
static pfn_XWF_GetVolumeName    XWF_GetVolumeName    = nullptr;
static pfn_XWF_AddToReportTable XWF_AddToReportTable = nullptr;

static HMODULE g_hSelf    = nullptr;
static HWND    g_hMainWnd = nullptr;

// --- Logging ----------------------------------------------------------------
static void Log(const std::wstring& m) {
    std::wstring s = L"["; s += NAME; s += L"] "; s += m;
    if (XWF_OutputMessage) XWF_OutputMessage(s.c_str(), 0);
}
static void LogVerbose(const std::wstring& m) { if (VERBOSE) Log(m); }

template <typename T>
static T Resolve(HMODULE h, const char* name, int& missing) {
    T p = reinterpret_cast<T>(GetProcAddress(h, name));
    if (!p) ++missing;
    return p;
}

static int ResolveFunctionPointers() {
    HMODULE h = GetModuleHandleW(nullptr);
    int missing = 0;
    XWF_OutputMessage    = Resolve<pfn_XWF_OutputMessage   >(h, "XWF_OutputMessage",    missing);
    XWF_GetItemName      = Resolve<pfn_XWF_GetItemName     >(h, "XWF_GetItemName",      missing);
    XWF_GetItemSize      = Resolve<pfn_XWF_GetItemSize     >(h, "XWF_GetItemSize",      missing);
    XWF_GetVolumeName    = Resolve<pfn_XWF_GetVolumeName   >(h, "XWF_GetVolumeName",    missing);
    XWF_AddToReportTable = Resolve<pfn_XWF_AddToReportTable>(h, "XWF_AddToReportTable", missing);
    return missing;
}

// --- Internal per-run logic (called by BOTH modes) --------------------------
// Replace these stubs with your tool's real work. The XT_* exports and
// the manager On* callbacks both delegate here so behaviour is identical
// across the two modes.

static bool RunInit(HWND hMainWnd) {
    g_hMainWnd = hMainWnd;
    int missing = ResolveFunctionPointers();
    if (missing > 0) {
        Log(L"required XWF_* exports missing — refusing to load");
        return false;
    }
    return true;
}

static bool RunPrepare(HANDLE hVolume, HANDLE /*hEvidence*/, DWORD nOpType) {
    wchar_t volName[260] = {0};
    if (hVolume && XWF_GetVolumeName) XWF_GetVolumeName(hVolume, volName, 0);
    wchar_t buf[320];
    swprintf_s(buf, L"Prepare op=%lu volume=%s",
               (unsigned long)nOpType, volName[0] ? volName : L"(none)");
    Log(buf);
    // Real plugins do their setup work here.
    return true;
}

static LONG RunProcessItem(LONG nItemID) {
    // Real plugins inspect the item here.
    (void)nItemID;
    return 0;
}

static LONG RunProcessItemEx(LONG nItemID, HANDLE hItem) {
    (void)nItemID; (void)hItem;
    return 0;
}

static bool RunFinalize(HANDLE /*hVolume*/, HANDLE /*hEvidence*/, DWORD /*nOpType*/) {
    Log(L"done");
    return true;
}

// =============================================================================
//  Standalone-mode exports (X-Ways calls these when the DLL is loaded
//  directly via Tools → Run X-Tension).
// =============================================================================
extern "C" {

LONG __stdcall XT_Init(DWORD nVersion, DWORD /*nFlags*/, HWND hMainWnd, void*) {
    Log(std::wstring(NAME) + L" " + VERSION +
        L" — standalone mode, X-Ways build " +
        std::to_wstring(nVersion / 100));
    return RunInit(hMainWnd) ? 1 : -1;
}

LONG __stdcall XT_About(HWND, void*) {
    std::wstring msg = NAME; msg += L" "; msg += VERSION; msg += L"\n";
    msg += DESCRIPTION;
    if (XWF_OutputMessage) XWF_OutputMessage(msg.c_str(), 0);
    return 0;
}

LONG __stdcall XT_Prepare(HANDLE hVolume, HANDLE hEvidence, DWORD nOpType, void*) {
    // OPTIONAL: show your settings dialog here (modal). The manager
    // shows it embedded automatically; in standalone mode you decide.
    //
    //   DialogBoxParamW(g_hSelf, MAKEINTRESOURCEW(IDD_SETTINGS),
    //                   g_hMainWnd, MyDlgProc, ...);
    //
    // Or skip the dialog and run from sidecar-cfg defaults — same as
    // many other X-Tensions in this project.
    if (!RunPrepare(hVolume, hEvidence, nOpType)) return 0;
    // Return bitmask: 0x01 (CALLPI) = call your per-item callback(s). X-Ways calls
    //   whichever you export; both XT_ProcessItem AND XT_ProcessItemEx fire per item
    //   if both are exported, so do the work in one (or dedup by item ID). 0x04 is
    //   EXPECTMOREITEMS (you'll create items), NOT a callback selector.
    return 0;
}

LONG __stdcall XT_ProcessItem(LONG nItemID, void*) {
    return RunProcessItem(nItemID);
}

LONG __stdcall XT_ProcessItemEx(LONG nItemID, HANDLE hItem, void*) {
    return RunProcessItemEx(nItemID, hItem);
}

LONG __stdcall XT_ProcessSearchHit(void*) { return 0; }

LONG __stdcall XT_Finalize(HANDLE hVolume, HANDLE hEvidence, DWORD nOpType, void*) {
    RunFinalize(hVolume, hEvidence, nOpType);
    return 0;
}

LONG __stdcall XT_Done(void*) { return 0; }

}  // extern "C" (standalone exports)

// =============================================================================
//  Managed-mode exports (xways-xt-manager calls these when this DLL is
//  loaded as a plugin). They wrap the same RunPrepare / RunProcessItem
//  / RunFinalize functions used by the standalone exports above.
// =============================================================================

// Dialog proc for the embedded settings tab. The same dlgproc would work
// for a standalone modal — see the manager-plugin.h "Dialog embedding"
// section. Replace this with your real handler (settings → controls →
// IDOK readback) when your plugin gets real settings.
static INT_PTR CALLBACK MyDlgProc(HWND hDlg, UINT msg, WPARAM wp, LPARAM /*lp*/) {
    switch (msg) {
    case WM_INITDIALOG:
        return TRUE;
    case WM_COMMAND:
        if (LOWORD(wp) == IDOK || LOWORD(wp) == IDCANCEL) {
            EndDialog(hDlg, LOWORD(wp));
            return TRUE;
        }
        break;
    }
    return FALSE;
}

static bool __stdcall OnInit(HMODULE /*hPluginModule*/, HWND hMainWnd, void*) {
    Log(std::wstring(NAME) + L" " + VERSION + L" — managed mode (xways-xt-manager)");
    return RunInit(hMainWnd);
}

static bool __stdcall OnPrepare(HANDLE hVolume, HANDLE hEvidence, DWORD nOpType, void*) {
    return RunPrepare(hVolume, hEvidence, nOpType);
}

static LONG __stdcall OnProcessItem(LONG nItemID, HANDLE /*hItem*/, void*) {
    return RunProcessItem(nItemID);
}

static LONG __stdcall OnProcessItemEx(LONG nItemID, HANDLE hItem, void*) {
    return RunProcessItemEx(nItemID, hItem);
}

static bool __stdcall OnFinalize(HANDLE hVolume, HANDLE hEvidence, DWORD nOpType, void*) {
    return RunFinalize(hVolume, hEvidence, nOpType);
}

// Optional. Called by the manager immediately before OnPrepare so your
// plugin can read the embedded dialog's current control state into its
// own settings struct. Mirror the IDOK readback you do in standalone
// mode — but DON'T call EndDialog (the embedded dialog stays alive
// across runs). Leave the descriptor's on_harvest_settings = NULL if
// your plugin has no per-run settings or accepts only cfg-driven runs.
//
// Example (uncomment + flesh out):
// static void __stdcall OnHarvestSettings(HWND hEmbeddedDlg, void*) {
//     wchar_t buf[260];
//     GetDlgItemTextW(hEmbeddedDlg, IDC_MY_EDIT, buf, 260);
//     g_my_settings.foo = buf;
//     g_my_settings.flag =
//         IsDlgButtonChecked(hEmbeddedDlg, IDC_MY_CHECK) == BST_CHECKED;
// }

// The single exported descriptor function the manager looks up by name.
// Set NULL on any hooks your plugin doesn't implement — the manager just
// skips. Setting on_process_item / on_process_item_ex to NULL also tells
// the manager you don't want per-item callbacks (it aggregates flags
// based on which pointers are populated).
extern "C" __declspec(dllexport)
const XwaysManagerPluginDescriptor* __stdcall XwaysManagerPluginEntry(void) {
    static const XwaysManagerPluginDescriptor desc = {
        XWAYS_MANAGER_PLUGIN_ABI_VERSION,
        sizeof(XwaysManagerPluginDescriptor),

        L"my_xtension",                     // id
        L"My X-Tension",                    // display_name (tab caption)
        L"Template X-Tension. Replace.",    // description (tools-tab info)
        VERSION,

        IDD_SETTINGS,                       // tab_dialog_resource_id (Option A)
        0,                                  // tab_dialog_embedded_resource_id (Option B; 0 = use Option A retrofit)
        MyDlgProc,

        OnInit,
        OnPrepare,
        nullptr,                            // on_process_item: NULL if not needed
        nullptr,                            // on_process_item_ex
        OnFinalize,

        true,                               // default_enabled
        nullptr,                            // reserved

        // -------- Post-v1 additive fields --------
        // on_harvest_settings: NULL = no embedded-dialog readback (cfg-only).
        // Set to your OnHarvestSettings function if you want analyst tweaks
        // in the embedded tab to apply at run time.
        nullptr
    };
    return &desc;
}

BOOL APIENTRY DllMain(HMODULE hModule, DWORD reason, LPVOID) {
    if (reason == DLL_PROCESS_ATTACH) g_hSelf = hModule;
    return TRUE;
}
