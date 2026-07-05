// SPDX-License-Identifier: MIT
// =============================================================================
//  X-Tension template for X-Ways Forensics 21.7  (C++ / Windows x64)
//
//  How it works: when X-Ways loads our DLL, GetModuleHandle(NULL) returns the
//  main X-Ways executable. We resolve the XWF_* exports by name with
//  GetProcAddress, then call them through function-pointer typedefs. No
//  dependency on the BG* helper files from the X-Ways SDK — this template is
//  deliberately small and self-contained.
//
//  Official API reference: https://www.x-ways.net/forensics/x-tensions/api.html
//  Authoritative signatures: https://www.x-ways.net/forensics/x-tensions/XWF_functions.html
//  (or a locally-acquired SDK header — see docs/getting-the-sdk.md; not shipped here)
// =============================================================================

#include <windows.h>
#include <cstdint>
#include <cstdio>
#include <string>
#include <mutex>

// --- Identity ---------------------------------------------------------------
static const wchar_t* NAME         = L"my_xtension";
static const wchar_t* VERSION      = L"0.1.0";
static const wchar_t* DESCRIPTION  = L"Template X-Tension. Replace this text.";
static const wchar_t* REPORT_TABLE = L"Template Findings";

// --- Logging verbosity ------------------------------------------------------
// Keep VERBOSE = true during development. Flip to false before sharing or
// running on a large snapshot to keep the Messages window quiet. Do not remove
// the LogVerbose call sites -- the flag toggles them at zero cost.
static constexpr bool VERBOSE = true;

// --- XT_Prepare nOpType — canonical names per X-Tension.h:422-427 -----------
//   See docs/xtension-invocation.md for usage notes per mode.
enum : DWORD {
    XT_ACTION_RUN = 0,  // Tools -> Run X-Tension on Volume Snapshot
    XT_ACTION_RVS = 1,  // Volume Snapshot Refinement
    XT_ACTION_LSS = 2,  // Logical Simultaneous Search
    XT_ACTION_PSS = 3,  // Physical Simultaneous Search
    XT_ACTION_DBC = 4,  // Directory Browser Context menu
    XT_ACTION_SHC = 5,  // Search Hit Context menu
};

// --- AddComment howToAdd flags (official API) -------------------------------
enum : DWORD { COMMENT_REPLACE = 0, COMMENT_APPEND = 1, COMMENT_PREPEND = 2 };

// --- Function-pointer typedefs (trimmed — add more as you need them) --------
typedef VOID   (__stdcall *pfn_XWF_OutputMessage)(const wchar_t* msg, DWORD nFlags);
typedef const wchar_t* (__stdcall *pfn_XWF_GetItemName)(LONG nItemID);
typedef INT64  (__stdcall *pfn_XWF_GetItemSize)(LONG nItemID);
typedef VOID   (__stdcall *pfn_XWF_GetVolumeName)(HANDLE hVolume, wchar_t* lpString, DWORD nType);
typedef BOOL   (__stdcall *pfn_XWF_AddToReportTable)(LONG nItemID, const wchar_t* lpReportTableName, DWORD nFlags);
typedef BOOL   (__stdcall *pfn_XWF_AddComment)(LONG nItemID, const wchar_t* lpComment, DWORD nHowToAdd);
// Evidence-property getter — used to ask X-Ways for the configured working/temp
// directory for an evidence object. See docs/xways-getprop-reference.md for
// the property numbers (12 = Internally used directory, 13 = Output directory).
typedef INT64  (__stdcall *pfn_XWF_GetEvObjProp)(HANDLE hEvidence, DWORD nPropType, PVOID pBuffer);
// Case-property getter — used to find the case root (XWF_CASEPROP_DIR = 6),
// which is the basis for the per-X-Tension output subfolder convention
// (see docs/conventions/output-dir.md).
typedef INT64  (__stdcall *pfn_XWF_GetCaseProp)(LPVOID lpReserved, LONG nPropType, PVOID pBuffer, LONG nBufferSize);

static pfn_XWF_OutputMessage    XWF_OutputMessage    = nullptr;
static pfn_XWF_GetItemName      XWF_GetItemName      = nullptr;
static pfn_XWF_GetItemSize      XWF_GetItemSize      = nullptr;
static pfn_XWF_GetVolumeName    XWF_GetVolumeName    = nullptr;
static pfn_XWF_AddToReportTable XWF_AddToReportTable = nullptr;
static pfn_XWF_AddComment       XWF_AddComment       = nullptr;
static pfn_XWF_GetEvObjProp     XWF_GetEvObjProp     = nullptr;
static pfn_XWF_GetCaseProp      XWF_GetCaseProp      = nullptr;

// --- State ------------------------------------------------------------------
struct State {
    HANDLE hVolume         = nullptr;
    LONG   opType          = -1;
    UINT64 processed       = 0;
    UINT64 flagged         = 0;
    INT64  minItemSizeBytes = 1ULL << 20;   // 1 MiB
    bool   addToReportTable = true;
    bool   addComment       = true;
};
static State g;
static std::mutex g_itemsMx;   // guards g.processed / g.flagged — RVS calls items multi-threaded

// --- Helpers ----------------------------------------------------------------
static void Log(const std::wstring& msg) {
    std::wstring line = L"[";
    line += NAME; line += L"] "; line += msg;
    if (XWF_OutputMessage) XWF_OutputMessage(line.c_str(), 0);
}
static void LogVerbose(const std::wstring& msg) { if (VERBOSE) Log(msg); }

template <typename T>
static T Resolve(HMODULE h, const char* name, int& missing) {
    T p = reinterpret_cast<T>(GetProcAddress(h, name));
    if (!p) ++missing;
    return p;
}

// Resolve every XWF_* pointer we declared above. Returns count of missing exports.
static int RetrieveFunctionPointers() {
    HMODULE h = GetModuleHandleW(nullptr);  // main X-Ways .exe
    int missing = 0;
    XWF_OutputMessage    = Resolve<pfn_XWF_OutputMessage   >(h, "XWF_OutputMessage",    missing);
    XWF_GetItemName      = Resolve<pfn_XWF_GetItemName     >(h, "XWF_GetItemName",      missing);
    XWF_GetItemSize      = Resolve<pfn_XWF_GetItemSize     >(h, "XWF_GetItemSize",      missing);
    XWF_GetVolumeName    = Resolve<pfn_XWF_GetVolumeName   >(h, "XWF_GetVolumeName",    missing);
    XWF_AddToReportTable = Resolve<pfn_XWF_AddToReportTable>(h, "XWF_AddToReportTable", missing);
    XWF_AddComment       = Resolve<pfn_XWF_AddComment      >(h, "XWF_AddComment",       missing);
    XWF_GetEvObjProp     = Resolve<pfn_XWF_GetEvObjProp    >(h, "XWF_GetEvObjProp",     missing);
    XWF_GetCaseProp      = Resolve<pfn_XWF_GetCaseProp     >(h, "XWF_GetCaseProp",      missing);
    return missing;
}

// --- Case-root + per-X-Tension output convention ---------------------------
//   Convention: when an X-Tension writes analyst-facing output, the
//   default output folder is `<caseRoot>\<NAME>\` so reports don't pile up at
//   the case root next to evidence dirs / .xfc files. The folder is created
//   on demand (SHCreateDirectoryExW) when the analyst hits Run. Don't
//   override an existing saved output_dir in cfg — only seed this default
//   when the field is empty.
//   See docs/conventions/output-dir.md.
static std::wstring GetCaseRootDir() {
    if (!XWF_GetCaseProp) return {};
    wchar_t buf[MAX_PATH] = {0};
    INT64 rc = XWF_GetCaseProp(nullptr, /*XWF_CASEPROP_DIR=*/6, buf, MAX_PATH);
    if (rc < 0) return {};
    return buf[0] ? std::wstring(buf) : std::wstring();
}

static std::wstring DefaultOutputDir(const std::wstring& caseRoot) {
    if (caseRoot.empty()) return {};
    return caseRoot + L"\\" + NAME;
}

// --- Temp-folder helper -----------------------------------------------------
//   Returns the X-Ways-configured working directory for this evidence (so
//   forensic-shop policy about temp-data location is honored automatically),
//   falling back to Windows %TEMP% if the call fails.
//
//   Use this — not GetTempPathW directly — when your X-Tension writes scratch
//   files. Property 12 = "Internally used directory" per
//   docs/xways-getprop-reference.md.
static std::wstring GetTempBase(HANDLE hEvidence) {
    if (XWF_GetEvObjProp && hEvidence) {
        wchar_t buf[MAX_PATH] = {0};
        XWF_GetEvObjProp(hEvidence, /*nPropType=*/12, buf);
        if (buf[0]) return buf;
    }
    wchar_t base[MAX_PATH] = {0};
    DWORD n = GetTempPathW(MAX_PATH, base);
    return (n > 0 && n <= MAX_PATH) ? std::wstring(base) : std::wstring(L"C:\\Temp\\");
}

static void RecordHit(LONG nItemID, const std::wstring& reason) {
    if (g.addToReportTable && XWF_AddToReportTable)
        XWF_AddToReportTable(nItemID, REPORT_TABLE, 0);
    if (g.addComment && XWF_AddComment) {
        std::wstring note = L"["; note += NAME; note += L"] "; note += reason;
        XWF_AddComment(nItemID, note.c_str(), COMMENT_APPEND);
    }
}

// =============================================================================
//  X-Tension entry points (exported by name via my_xtension.def)
// =============================================================================
extern "C" {

LONG __stdcall XT_Init(DWORD nVersion, DWORD nFlags, HWND hMainWnd, void* lpReserved) {
    int missing = RetrieveFunctionPointers();
    wchar_t buf[128];
    swprintf_s(buf, L"%s — X-Ways build %.2f (%d missing exports)",
               VERSION, nVersion / 100.0, missing);
    Log(buf);
    return 1;
}

LONG __stdcall XT_About(HWND hParentWnd, void* lpReserved) {
    std::wstring msg = NAME; msg += L" "; msg += VERSION; msg += L"\n"; msg += DESCRIPTION;
    if (XWF_OutputMessage) XWF_OutputMessage(msg.c_str(), 0);
    return 0;
}

LONG __stdcall XT_Prepare(HANDLE hVolume, HANDLE hEvidence, LONG nOpType, void* lpReserved) {
    g.hVolume = hVolume;
    g.opType  = nOpType;
    g.processed = g.flagged = 0;

    wchar_t volName[260] = {0};
    if (hVolume && XWF_GetVolumeName) XWF_GetVolumeName(hVolume, volName, 0);

    wchar_t buf[320];
    swprintf_s(buf, L"XT_Prepare op=%ld volume=%s", nOpType, volName[0] ? volName : L"(none)");
    Log(buf);

    // If your X-Tension writes scratch files, use GetTempBase(hEvidence) — it
    // honors X-Ways' configured working dir (General Options -> Folders),
    // falling back to %TEMP%. See docs/xways-getprop-reference.md for the
    // property numbers behind it.
    //
    //   std::wstring tempBase = GetTempBase(hEvidence);
    //   Log(L"temp base: " + tempBase);

    // 0x01 (CALLPI): X-Ways calls your per-item callback(s) — whichever of
    // XT_ProcessItem / XT_ProcessItemEx you export. We export BOTH, so BOTH fire
    // for every item (RVS delivers each item to both, on a worker pool).
    // We therefore do the work in ONE place (XT_ProcessItemEx — it also gives an
    // hItem) and leave XT_ProcessItem a no-op, so each item is handled once.
    // (0x04 would be EXPECTMOREITEMS — "I'll create items" — not a callback knob.)
    // See docs/conventions/item-collection.md.
    return 0x01;
}

// Non-Ex callback. It DOES fire under 0x01 (X-Ways calls both exported callbacks
// per item) — we keep it a no-op so each item is handled exactly once, in
// XT_ProcessItemEx below. Do the work here instead if you don't need an hItem;
// if you work in BOTH, dedup by item ID or you'll double-count.
LONG __stdcall XT_ProcessItem(LONG nItemID, void* lpReserved) {
    return 0;
}

// Per-item work goes here. IMPORTANT: under Volume Snapshot Refinement (RVS)
// X-Ways calls this from a multi-threaded worker pool, so state shared across
// items (the g.processed / g.flagged counters) must be synchronised. See
// docs/conventions/item-collection.md + threading-model.md.
LONG __stdcall XT_ProcessItemEx(LONG nItemID, HANDLE hItem, void* lpReserved) {
    if (!XWF_GetItemSize) return 0;
    INT64 size = XWF_GetItemSize(nItemID);   // hItem is also open: XWF_Read(hItem, ofs, buf, n)
    bool flag = size > g.minItemSizeBytes;
    if (flag) {
        const wchar_t* name = (XWF_GetItemName ? XWF_GetItemName(nItemID) : L"<unnamed>");
        wchar_t buf[512];
        swprintf_s(buf, L"large item (%lld bytes): %s", (long long)size, name ? name : L"<unnamed>");
        LogVerbose(buf);            // per-hit detail -- verbose-only
        RecordHit(nItemID, buf);    // XWF_AddToReportTable / XWF_AddComment are per-item API
    }
    {   // guard shared counters — a bare ++ is a data race under RVS
        std::lock_guard<std::mutex> lk(g_itemsMx);
        ++g.processed;
        if (flag) ++g.flagged;
    }
    return 0;
}

LONG __stdcall XT_ProcessSearchHit(void* info) {
    return 0;
}

LONG __stdcall XT_Finalize(HANDLE hVolume, HANDLE hEvidence, LONG nOpType, void* lpReserved) {
    wchar_t buf[128];
    swprintf_s(buf, L"done — processed %llu, flagged %llu",
               (unsigned long long)g.processed, (unsigned long long)g.flagged);
    Log(buf);
    return 0;
}

LONG __stdcall XT_Done(void* lpReserved) {
    Log(L"XT_Done");
    return 0;
}

} // extern "C"

BOOL APIENTRY DllMain(HMODULE, DWORD, LPVOID) { return TRUE; }
