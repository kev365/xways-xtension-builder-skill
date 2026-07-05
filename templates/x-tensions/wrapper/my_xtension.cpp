// SPDX-License-Identifier: MIT
// =============================================================================
//  my_xtension — CLI-tool-wrapper X-Tension TEMPLATE for X-Ways Forensics 21.7+
//
//  A generic, manager-compatible starting point for an X-Tension that wraps an
//  external command-line tool. For each file in the active volume snapshot (or
//  a Directory-Browser-Context selection) the X-Tension extracts the bytes via
//  XWF_Read to a scratch file, invokes <yourtool>.exe on it, parses the tool's
//  output, and tags items in a Report Table.
//
//  The mechanism is complete; the tool-SPECIFIC parts (output parsing,
//  command-line shape, result writer) are reduced to clearly-marked `// TODO:`
//  stubs so the file COMPILES out of the box and you can fill in your tool's
//  logic incrementally. A production example of this pattern:
//  https://github.com/kev365/xways-trufflehog (see docs/exemplars.md).
//
//  WHAT YOU NEED TO CHANGE (search for "TODO:"):
//    1. Identity constants below (NAME / VERSION / DESCRIPTION / REPORT_TABLE).
//    2. HELPER_NEEDLE — the substring that identifies your tool's exe.
//    3. ResolveDefaultTool() — the conventional bundled exe path(s).
//    4. BuildToolCmd()       — your tool's command-line shape.
//    5. ParseToolOutput()    — turn your tool's output into ScanResult rows.
//    6. WriteResultsCsv()    — adjust the columns to your tool's findings.
//    7. The dialog .rc / resource.h labels (cosmetic).
//
//  GUI architecture:
//    XT_Prepare -> request XT_ProcessItem callbacks to collect item IDs ->
//      XT_Finalize -> ShowDialogAndRun -> user clicks Run -> worker thread
//      iterates items, posts WM_APP_* progress to the dialog, returns ->
//      dialog stays open with the summary -> user closes.
//
//  This template self-declares the XWF_* function-pointer typedefs and resolves
//  them via GetProcAddress — NO X-Tension.h is required to build.
//
//  Conventions wired in (see docs/conventions/):
//    - Helper-exe identity verification (PE VERSIONINFO + --version banner).
//    - Ctrl-to-save / Ctrl-to-save-as gesture on the action buttons.
//    - Per-X-Tension output folder under <caseRoot>\<NAME>.
//    - Subprocess stdio capture (open-NUL + STARTF_USESTDHANDLES).
//    - xways-xt-manager compatibility (XwaysManagerPluginEntry + On* callbacks;
//      the manager host is a separate project, not yet publicly released).
//    - Verbose logging toggle (g_verbose / Log / LogVerbose).
// =============================================================================

#define NOMINMAX
#include <windows.h>
#include <shlobj.h>
#include <commdlg.h>
#include <commctrl.h>
#include <process.h>
#include <cstdint>
#include <cstdio>
#include <cstdarg>
#include <string>
#include <vector>
#include <set>
#include <map>
#include <algorithm>
#include <atomic>

#include "resource.h"

// --- Identity ---------------------------------------------------------------
//   TODO: replace these placeholders (a scaffolder normally does this for you).
static const wchar_t* NAME         = L"my_xtension";
static const wchar_t* VERSION      = L"0.1.0-beta";
static const wchar_t* DESCRIPTION  = L"CLI-tool wrapper X-Tension template.";
static const wchar_t* REPORT_TABLE = L"my_xtension: hits";

// --- Logging ---------------------------------------------------------------
//   Default-on during development; flipped by Settings.verbose (cfg key
//   `xtension_verbose` and the Verbose checkbox in the dialog).
static bool g_verbose = true;

// --- XT_Prepare nOpType ----------------------------------------------------
enum : DWORD {
    XT_ACTION_RUN = 0,
    XT_ACTION_RVS = 1,
    XT_ACTION_LSS = 2,
    XT_ACTION_PSS = 3,
    XT_ACTION_DBC = 4,
    XT_ACTION_SHC = 5,
};

enum : DWORD { COMMENT_REPLACE = 0, COMMENT_APPEND = 1, COMMENT_PREPEND = 2 };

// --- Dialog message IDs (worker -> dialog) ---------------------------------
#define WM_APP_PROGRESS   (WM_APP + 1)  // wp = permille (0..1000)
#define WM_APP_STATUS     (WM_APP + 2)  // lp = heap-allocated wchar_t* (dialog owns + deletes)
#define WM_APP_DONE       (WM_APP + 3)  // wp = success bool
#define WM_APP_MARQUEE    (WM_APP + 4)  // wp = 1 start marquee, 0 stop
#define WM_APP_VERSION    (WM_APP + 5)  // lp = heap-allocated VersionProbeResult* (dialog owns + deletes)

// --- XWF_* typedefs --------------------------------------------------------
typedef VOID   (__stdcall *pfn_XWF_OutputMessage)(const wchar_t*, DWORD);
typedef const wchar_t* (__stdcall *pfn_XWF_GetItemName)(LONG);
typedef INT64  (__stdcall *pfn_XWF_GetItemSize)(LONG);
typedef VOID   (__stdcall *pfn_XWF_GetVolumeName)(HANDLE, wchar_t*, DWORD);
typedef BOOL   (__stdcall *pfn_XWF_AddToReportTable)(LONG, const wchar_t*, DWORD);
typedef BOOL   (__stdcall *pfn_XWF_Label)(LONG, const wchar_t*, DWORD);
typedef BOOL   (__stdcall *pfn_XWF_AddComment)(LONG, const wchar_t*, DWORD);
typedef INT64  (__stdcall *pfn_XWF_GetEvObjProp)(HANDLE, DWORD, PVOID);
typedef DWORD  (__stdcall *pfn_XWF_Read)(HANDLE, INT64, BYTE*, DWORD);
typedef HANDLE (__stdcall *pfn_XWF_OpenItem)(HANDLE, LONG, DWORD);
typedef VOID   (__stdcall *pfn_XWF_Close)(HANDLE);
typedef DWORD  (__stdcall *pfn_XWF_GetItemCount)(LPVOID);
typedef LONG   (__stdcall *pfn_XWF_GetItemInformation)(LONG, LONG, BOOL*);
typedef LONG   (__stdcall *pfn_XWF_GetItemParent)(LONG);
typedef INT64  (__stdcall *pfn_XWF_GetCaseProp)(LPVOID, LONG, PVOID, LONG);
typedef BOOL   (__stdcall *pfn_XWF_ShouldStop)();

static pfn_XWF_OutputMessage      XWF_OutputMessage      = nullptr;
static pfn_XWF_GetItemName        XWF_GetItemName        = nullptr;
static pfn_XWF_GetItemSize        XWF_GetItemSize        = nullptr;
static pfn_XWF_GetVolumeName      XWF_GetVolumeName      = nullptr;
static pfn_XWF_AddToReportTable   XWF_AddToReportTable   = nullptr;
static pfn_XWF_Label              XWF_Label              = nullptr;
static pfn_XWF_AddComment         XWF_AddComment         = nullptr;
static pfn_XWF_GetEvObjProp       XWF_GetEvObjProp       = nullptr;
static pfn_XWF_Read               XWF_Read               = nullptr;
static pfn_XWF_OpenItem           XWF_OpenItem           = nullptr;
static pfn_XWF_Close              XWF_Close              = nullptr;
static pfn_XWF_GetItemCount       XWF_GetItemCount       = nullptr;
static pfn_XWF_GetItemInformation XWF_GetItemInformation = nullptr;
static pfn_XWF_GetItemParent      XWF_GetItemParent      = nullptr;
static pfn_XWF_GetCaseProp        XWF_GetCaseProp        = nullptr;
static pfn_XWF_ShouldStop         XWF_ShouldStop         = nullptr;

// XWF_ITEM_INFO_FLAGS / FLAG_DIRECTORY (empirical; 0x02 is HasChildObjects,
// NOT IsDirectory -- getting these wrong silently neuters the "skip
// directories" check).
static constexpr LONG XWF_ITEM_INFO_FLAGS          = 3;
static constexpr LONG XWF_ITEM_INFO_FLAG_DIRECTORY = 0x00000001;

// --- Module globals --------------------------------------------------------
static HMODULE g_hSelf    = nullptr;
static HWND    g_hMainWnd = nullptr;

// How was the X-Tension launched? Display-only (the worker treats both the
// same way -- it scans the items X-Ways already collected for us).
enum class InvocationMode { Run, Selection };

// --- Settings (round-trip via dialog LPARAM) -------------------------------
//   Minimal generic set: tool path, extra args, output dir, verbose, plus a
//   couple of universally-useful scope knobs. Add tool-specific fields here.
struct Settings {
    // Tool + paths
    std::wstring toolExe;          // resolved absolute path to <yourtool>.exe
    std::wstring toolVersion;      // detected version banner (display-only)
    std::wstring outputBase;       // base dir; runDir = outputBase\run-...

    // Scope (filters applied BEFORE we hand bytes to the tool)
    INT64        minSizeBytes = 1;
    INT64        maxSizeMiB   = 256;   // 256 MiB ceiling

    // Free-form pass-through appended to the tool command line.
    std::wstring extraArgs;

    // Output tagging
    bool         addToReportTable = true;
    bool         addComment       = true;
    int          tagThreshold     = 1;

    // X-Tension diagnostic verbosity (toggles Log vs LogVerbose).
    bool         verbose          = true;
};

// --- Run state passed from XT_Prepare into the dialog ----------------------
struct RunCtx {
    HANDLE             hVolume   = nullptr;
    HANDLE             hEvidence = nullptr;
    InvocationMode     invocationMode = InvocationMode::Run;
    std::vector<LONG>  items;        // filter-respecting list from XT_ProcessItem
    size_t             dirCount = 0; // directory items (shown alongside file count)
};

// --- Item accumulator (XT_ProcessItem -> XT_Finalize) ----------------------
struct Collected {
    bool              ready = false;
    bool              aborted = false;  // user hit Stop/Esc during enumeration
    HANDLE            hVolume = nullptr;
    HANDLE            hEvidence = nullptr;
    InvocationMode    invocationMode = InvocationMode::Run;
    std::vector<LONG> items;
};
static Collected g_collected;

// --- Managed-mode (xways-xt-manager) state ---------------------------------
//   When this DLL is hosted by xways-xt-manager (instead of loaded directly by
//   X-Ways), the manager creates the embedded settings dialog with lParam=0.
//   SettingsDlgProc / PopulateDialog fall back to these module-local objects.
static bool      g_managed_mode = false;
static Settings  g_managed_settings;
static RunCtx    g_managed_runctx;     // fallback for SettingsDlgProc / PopulateDialog
static Collected g_managed_collected;  // item IDs gathered via OnProcessItem(Ex)

// =============================================================================
//  Helpers — logging, encoding, paths, files
// =============================================================================
static void Log(const std::wstring& msg) {
    std::wstring line = L"["; line += NAME; line += L"] "; line += msg;
    if (XWF_OutputMessage) XWF_OutputMessage(line.c_str(), 0);
}
static void LogVerbose(const std::wstring& msg) { if (g_verbose) Log(msg); }

static std::wstring FormatW(const wchar_t* fmt, ...) {
    wchar_t buf[2048];
    va_list ap; va_start(ap, fmt);
    _vsnwprintf_s(buf, _countof(buf), _TRUNCATE, fmt, ap);
    va_end(ap);
    return buf;
}

template <typename T>
static T Resolve(HMODULE h, const char* name, int& missing) {
    T p = reinterpret_cast<T>(GetProcAddress(h, name));
    if (!p) ++missing;
    return p;
}

static int RetrieveFunctionPointers() {
    HMODULE h = GetModuleHandleW(nullptr);
    int missing = 0;
    XWF_OutputMessage      = Resolve<pfn_XWF_OutputMessage     >(h, "XWF_OutputMessage",      missing);
    XWF_GetItemName        = Resolve<pfn_XWF_GetItemName       >(h, "XWF_GetItemName",        missing);
    XWF_GetItemSize        = Resolve<pfn_XWF_GetItemSize       >(h, "XWF_GetItemSize",        missing);
    XWF_GetVolumeName      = Resolve<pfn_XWF_GetVolumeName     >(h, "XWF_GetVolumeName",      missing);
    XWF_AddToReportTable   = Resolve<pfn_XWF_AddToReportTable  >(h, "XWF_AddToReportTable",   missing);
    // XWF_Label is optional (21.7 SR-4+). Do NOT count it as missing -- pre-SR-4
    // hosts simply lack it and the fallback to XWF_AddToReportTable keeps
    // backward compatibility.
    XWF_Label              = reinterpret_cast<pfn_XWF_Label>(GetProcAddress(h, "XWF_Label"));
    XWF_AddComment         = Resolve<pfn_XWF_AddComment        >(h, "XWF_AddComment",         missing);
    XWF_GetEvObjProp       = Resolve<pfn_XWF_GetEvObjProp      >(h, "XWF_GetEvObjProp",       missing);
    XWF_Read               = Resolve<pfn_XWF_Read              >(h, "XWF_Read",               missing);
    XWF_OpenItem           = Resolve<pfn_XWF_OpenItem          >(h, "XWF_OpenItem",           missing);
    XWF_Close              = Resolve<pfn_XWF_Close             >(h, "XWF_Close",              missing);
    XWF_GetItemCount       = Resolve<pfn_XWF_GetItemCount      >(h, "XWF_GetItemCount",       missing);
    XWF_GetItemInformation = Resolve<pfn_XWF_GetItemInformation>(h, "XWF_GetItemInformation", missing);
    XWF_GetItemParent      = Resolve<pfn_XWF_GetItemParent     >(h, "XWF_GetItemParent",      missing);
    XWF_GetCaseProp        = Resolve<pfn_XWF_GetCaseProp       >(h, "XWF_GetCaseProp",        missing);
    // XWF_ShouldStop is optional (older builds may lack it).
    int dummy = 0;
    XWF_ShouldStop         = Resolve<pfn_XWF_ShouldStop        >(h, "XWF_ShouldStop",         dummy);
    return missing;
}

static std::wstring GetSelfDirectory() {
    wchar_t buf[MAX_PATH] = {0};
    DWORD n = GetModuleFileNameW(g_hSelf, buf, MAX_PATH);
    if (n == 0) return {};
    std::wstring p(buf, n);
    size_t slash = p.find_last_of(L"\\/");
    return (slash == std::wstring::npos) ? std::wstring() : p.substr(0, slash);
}

// Walk parent chain via XWF_GetItemParent + XWF_GetItemName to build the
// item's full path inside the volume snapshot. Safety cap at 256 levels.
static std::wstring BuildItemFullPath(LONG itemID) {
    if (!XWF_GetItemName) return {};
    std::vector<std::wstring> parts;
    LONG cur = itemID;
    int safety = 0;
    while (cur >= 0 && safety < 256) {
        const wchar_t* nm = XWF_GetItemName(cur);
        if (nm && *nm) parts.emplace_back(nm);
        cur = XWF_GetItemParent ? XWF_GetItemParent(cur) : -1;
        ++safety;
    }
    std::wstring path;
    for (auto it = parts.rbegin(); it != parts.rend(); ++it) {
        if (!path.empty()) path += L"\\";
        path += *it;
    }
    return path;
}

static std::wstring TrimW(const std::wstring& s) {
    size_t b = 0, e = s.size();
    while (b < e && iswspace(s[b])) ++b;
    while (e > b && iswspace(s[e - 1])) --e;
    return s.substr(b, e - b);
}

static std::wstring ToLowerW(const std::wstring& s) {
    std::wstring out = s; for (auto& c : out) c = (wchar_t)towlower(c); return out;
}

static std::wstring Utf8ToWide(const std::string& s) {
    if (s.empty()) return {};
    int n = MultiByteToWideChar(CP_UTF8, 0, s.c_str(), (int)s.size(), nullptr, 0);
    std::wstring out(n, L'\0');
    MultiByteToWideChar(CP_UTF8, 0, s.c_str(), (int)s.size(), &out[0], n);
    return out;
}

static std::string WideToUtf8(const std::wstring& w) {
    if (w.empty()) return {};
    int n = WideCharToMultiByte(CP_UTF8, 0, w.c_str(), (int)w.size(), nullptr, 0, nullptr, nullptr);
    std::string out(n, '\0');
    WideCharToMultiByte(CP_UTF8, 0, w.c_str(), (int)w.size(), &out[0], n, nullptr, nullptr);
    return out;
}

static bool FileExists(const std::wstring& p) {
    DWORD a = GetFileAttributesW(p.c_str());
    return a != INVALID_FILE_ATTRIBUTES && !(a & FILE_ATTRIBUTE_DIRECTORY);
}

static bool DirExists(const std::wstring& p) {
    DWORD a = GetFileAttributesW(p.c_str());
    return a != INVALID_FILE_ATTRIBUTES && (a & FILE_ATTRIBUTE_DIRECTORY);
}

static bool EnsureDirectoryExists(const std::wstring& path) {
    if (DirExists(path)) return true;
    if (CreateDirectoryW(path.c_str(), nullptr)) return true;
    return GetLastError() == ERROR_ALREADY_EXISTS;
}

static std::wstring SafeLeaf(const std::wstring& leaf) {
    std::wstring out; out.reserve(leaf.size());
    for (wchar_t c : leaf) {
        if (c == L'\\' || c == L'/' || c == L':' || c == L'*' || c == L'?' ||
            c == L'"'  || c == L'<' || c == L'>' || c == L'|') out.push_back(L'_');
        else out.push_back(c);
    }
    if (out.size() > 96) out.resize(96);
    return out;
}

static std::wstring CreateUniqueRunDir(const std::wstring& base) {
    SYSTEMTIME st; GetLocalTime(&st);
    for (int i = 0; i < 50; ++i) {
        wchar_t buf[64];
        if (i == 0) swprintf_s(buf, L"run-%04u%02u%02u-%02u%02u%02u",
                               st.wYear, st.wMonth, st.wDay, st.wHour, st.wMinute, st.wSecond);
        else        swprintf_s(buf, L"run-%04u%02u%02u-%02u%02u%02u-%d",
                               st.wYear, st.wMonth, st.wDay, st.wHour, st.wMinute, st.wSecond, i);
        std::wstring p = base + L"\\" + buf;
        if (CreateDirectoryW(p.c_str(), nullptr)) return p;
        if (GetLastError() != ERROR_ALREADY_EXISTS) return {};
    }
    return {};
}

// --- Output-dir convention (see docs/conventions/output-dir.md) ------------
// XWF_CASEPROP_DIR (nPropType = 6) returns the case's working directory --
// where X-Ways drops .xfc, evidence subfolders, report output, etc. The
// property number is documented on the live X-Ways API page (not the SDK
// header). Buffer must be MAX_PATH wchars.
static std::wstring GetCaseRootDir() {
    if (!XWF_GetCaseProp) return {};
    wchar_t buf[MAX_PATH] = {0};
    INT64 rc = XWF_GetCaseProp(nullptr, /*XWF_CASEPROP_DIR=*/6, buf, MAX_PATH);
    if (rc < 0) return {};
    return buf[0] ? std::wstring(buf) : std::wstring();
}

// Per-X-Tension output folder convention: keep artifacts out of the case root
// itself (where they'd mix with evidence subfolders + X-Ways .xfc files) by
// nesting them inside a folder named after this X-Tension. Empty caseRoot
// (no case open / property unavailable) returns empty so callers fall back to
// whatever default they had before.
static std::wstring DefaultOutputDir(const std::wstring& caseRoot) {
    if (caseRoot.empty()) return {};
    return caseRoot + L"\\" + NAME;
}

static std::wstring GetEvidenceWorkingDir(HANDLE hEvidence) {
    if (XWF_GetEvObjProp && hEvidence) {
        wchar_t buf[MAX_PATH] = {0};
        XWF_GetEvObjProp(hEvidence, /*nPropType=*/12, buf);
        if (buf[0]) return buf;
    }
    return {};
}

// Default output base for a run -- ALREADY includes the X-Tension subfolder so
// the dialog edit field shows the actual destination. Prefer the case dir
// (via DefaultOutputDir), then evidence working dir, then %TEMP%.
// sourceLabel reports which step won (for the run log line).
static std::wstring ResolveDefaultOutputBase(HANDLE hEvidence,
                                             std::wstring& sourceLabel) {
    std::wstring caseOut = DefaultOutputDir(GetCaseRootDir());
    if (!caseOut.empty()) {
        sourceLabel = L"X-Ways case directory";
        return caseOut;
    }
    std::wstring evDir = GetEvidenceWorkingDir(hEvidence);
    if (!evDir.empty()) {
        sourceLabel = L"evidence working dir";
        return evDir + L"\\" + NAME;
    }
    wchar_t base[MAX_PATH] = {0};
    DWORD n = GetTempPathW(MAX_PATH, base);
    if (n > 0 && n <= MAX_PATH) {
        sourceLabel = L"%TEMP%";
        return std::wstring(base) + NAME;
    }
    sourceLabel = L"C:\\Temp\\ (last-resort)";
    return std::wstring(L"C:\\Temp\\") + NAME;
}

static bool ReadWholeFile(const std::wstring& path, std::string& out) {
    FILE* fp = nullptr;
    if (_wfopen_s(&fp, path.c_str(), L"rb") != 0 || !fp) return false;
    char buf[8192];
    while (size_t n = fread(buf, 1, sizeof(buf), fp)) out.append(buf, n);
    fclose(fp);
    return true;
}

// =============================================================================
//  Cfg loader / writer (sidecar my_xtension.cfg next to the DLL)
// =============================================================================
static bool ParseBool(const std::wstring& v) {
    std::wstring lo = ToLowerW(TrimW(v));
    return lo == L"1" || lo == L"true" || lo == L"yes" || lo == L"on";
}
static INT64 ParseInt64(const std::wstring& v, INT64 fb) {
    if (v.empty()) return fb;
    try { return std::stoll(v); } catch (...) { return fb; }
}
static int ParseInt(const std::wstring& v, int fb) {
    if (v.empty()) return fb;
    try { return std::stoi(v); } catch (...) { return fb; }
}

// Serialize a Settings struct to cfg text. SINGLE SOURCE OF TRUTH for both the
// auto-created cfg AND for Run / Ctrl+Run saves -- guarantees the cfg values
// never drift from the Settings struct's compiled defaults.
static std::wstring SerializeSettings(const Settings& s) {
    auto bs = [](bool b) -> const wchar_t* { return b ? L"true" : L"false"; };

    SYSTEMTIME st; GetLocalTime(&st);
    wchar_t ts[64];
    swprintf_s(ts, L"%04u-%02u-%02u %02u:%02u:%02u",
               st.wYear, st.wMonth, st.wDay, st.wHour, st.wMinute, st.wSecond);

    std::wstring o;
    o += L"# "; o += NAME; o += L".cfg\r\n";
    o += L"# Auto-managed by the X-Tension. Values reflect compiled defaults\r\n";
    o += L"# on first run, then the dialog state on each Run / Ctrl+Run.\r\n";
    o += L"# Last written: "; o += ts; o += L"\r\n\r\n";

    o += L"# ----- Tool binary -----\r\n";
    o += L"tool_exe=";    o += s.toolExe;    o += L"\r\n";
    o += L"output_base="; o += s.outputBase; o += L"\r\n\r\n";

    o += L"# ----- Input filters -----\r\n";
    o += L"min_size_bytes=" + std::to_wstring(s.minSizeBytes) + L"\r\n";
    o += L"max_size_mib="   + std::to_wstring(s.maxSizeMiB)   + L"\r\n\r\n";

    o += L"# ----- Tool tuning -----\r\n";
    o += L"# extra_args: free-form pass-through appended to the tool command line.\r\n";
    o += L"extra_args="; o += s.extraArgs; o += L"\r\n\r\n";

    o += L"# ----- Output tagging -----\r\n";
    o += L"tag_threshold="       + std::to_wstring(s.tagThreshold) + L"\r\n";
    o += L"add_to_report_table="; o += bs(s.addToReportTable);     o += L"\r\n";
    o += L"add_comment=";         o += bs(s.addComment);           o += L"\r\n\r\n";

    o += L"# ----- X-Tension verbosity -----\r\n";
    o += L"xtension_verbose="; o += bs(s.verbose); o += L"\r\n";
    return o;
}

// Atomic-ish cfg write: back up any existing cfg to <path>.bak, then overwrite.
// UTF-8 BOM + CRLF body so Notepad opens it cleanly on Windows.
static bool SaveSettingsToCfg(const std::wstring& path, const Settings& s) {
    if (FileExists(path)) {
        std::wstring bak = path + L".bak";
        DeleteFileW(bak.c_str());
        MoveFileW(path.c_str(), bak.c_str());
    }
    FILE* fp = nullptr;
    if (_wfopen_s(&fp, path.c_str(), L"wb") != 0 || !fp) return false;
    const unsigned char bom[] = {0xEF, 0xBB, 0xBF};
    fwrite(bom, 1, 3, fp);
    std::string utf8 = WideToUtf8(SerializeSettings(s));
    fwrite(utf8.data(), 1, utf8.size(), fp);
    fclose(fp);
    return true;
}

// Ensure the cfg file exists at the resolved path. If absent, write a fresh cfg
// from the default Settings via the same serializer used by Run / Save.
static bool EnsureCfgExists(const std::wstring& cfgPath) {
    if (FileExists(cfgPath)) return true;
    Settings defaults;
    if (SaveSettingsToCfg(cfgPath, defaults)) {
        Log(L"created default cfg: " + cfgPath);
        return true;
    }
    Log(L"failed to create default cfg at: " + cfgPath);
    return false;
}

static void LoadCfg(const std::wstring& path, Settings& s) {
    FILE* fp = nullptr;
    if (_wfopen_s(&fp, path.c_str(), L"rb") != 0 || !fp) {
        LogVerbose(L"cfg not found (using defaults): " + path);
        return;
    }
    Log(L"loading cfg: " + path);
    char buf[4096]; std::string acc;
    while (size_t n = fread(buf, 1, sizeof(buf), fp)) acc.append(buf, n);
    fclose(fp);
    if (acc.size() >= 3 &&
        (unsigned char)acc[0] == 0xEF && (unsigned char)acc[1] == 0xBB && (unsigned char)acc[2] == 0xBF) acc.erase(0, 3);
    std::wstring all = Utf8ToWide(acc);
    size_t lineStart = 0;
    for (size_t i = 0; i <= all.size(); ++i) {
        if (i != all.size() && all[i] != L'\n' && all[i] != L'\r') continue;
        std::wstring line = TrimW(all.substr(lineStart, i - lineStart));
        lineStart = i + 1;
        if (line.empty() || line[0] == L'#' || line[0] == L';') continue;
        size_t eq = line.find(L'=');
        if (eq == std::wstring::npos) continue;
        std::wstring key = TrimW(line.substr(0, eq));
        std::wstring val = TrimW(line.substr(eq + 1));
        if      (key == L"tool_exe")            s.toolExe          = val;
        else if (key == L"output_base")         s.outputBase       = val;
        else if (key == L"min_size_bytes")      s.minSizeBytes     = ParseInt64(val, s.minSizeBytes);
        else if (key == L"max_size_mib")        s.maxSizeMiB       = ParseInt64(val, s.maxSizeMiB);
        else if (key == L"extra_args")          s.extraArgs        = val;
        else if (key == L"tag_threshold")       s.tagThreshold     = ParseInt(val, s.tagThreshold);
        else if (key == L"add_to_report_table") s.addToReportTable = ParseBool(val);
        else if (key == L"add_comment")         s.addComment       = ParseBool(val);
        else if (key == L"xtension_verbose"
              || key == L"verbose")             s.verbose          = ParseBool(val);
    }
}

// =============================================================================
//  Subprocess invocation
// =============================================================================
//   RunCommand:       launch a command line (typically wrapped in cmd.exe /C
//                     with > / 2> redirection), wait for exit.
//   RunCaptureStdout: pipe child stdout+stderr into a string (for --version).
static bool RunCommand(const std::wstring& cmdline, const std::wstring& workingDir,
                       DWORD& exitCodeOut) {
    std::vector<wchar_t> mut(cmdline.begin(), cmdline.end());
    mut.push_back(L'\0');
    STARTUPINFOW si = {}; si.cb = sizeof(si);
    PROCESS_INFORMATION pi = {};
    BOOL ok = CreateProcessW(nullptr, mut.data(), nullptr, nullptr, FALSE,
                             CREATE_NO_WINDOW, nullptr,
                             workingDir.empty() ? nullptr : workingDir.c_str(),
                             &si, &pi);
    if (!ok) { exitCodeOut = (DWORD)-1; return false; }
    WaitForSingleObject(pi.hProcess, INFINITE);
    GetExitCodeProcess(pi.hProcess, &exitCodeOut);
    CloseHandle(pi.hProcess);
    CloseHandle(pi.hThread);
    return true;
}

static DWORD RunCaptureStdout(const std::wstring& cmd, std::string& out, DWORD timeoutMs = 5000) {
    SECURITY_ATTRIBUTES sa = {sizeof(sa), nullptr, TRUE};
    HANDLE hRead = nullptr, hWrite = nullptr;
    if (!CreatePipe(&hRead, &hWrite, &sa, 0)) return (DWORD)-1;
    SetHandleInformation(hRead, HANDLE_FLAG_INHERIT, 0);
    STARTUPINFOW si = {}; si.cb = sizeof(si);
    si.dwFlags    = STARTF_USESTDHANDLES;
    si.hStdOutput = hWrite;
    si.hStdError  = hWrite;
    si.hStdInput  = GetStdHandle(STD_INPUT_HANDLE);
    PROCESS_INFORMATION pi = {};
    std::vector<wchar_t> cmdline(cmd.begin(), cmd.end()); cmdline.push_back(L'\0');
    BOOL ok = CreateProcessW(nullptr, cmdline.data(), nullptr, nullptr, TRUE,
                             CREATE_NO_WINDOW, nullptr, nullptr, &si, &pi);
    CloseHandle(hWrite);
    if (!ok) { CloseHandle(hRead); return (DWORD)-1; }
    out.clear();
    char buf[1024];
    DWORD readBytes;
    DWORD deadline = GetTickCount() + timeoutMs;
    for (;;) {
        DWORD avail = 0;
        if (!PeekNamedPipe(hRead, nullptr, 0, nullptr, &avail, nullptr)) break;
        if (avail == 0) {
            DWORD wait = WaitForSingleObject(pi.hProcess, 50);
            if (wait == WAIT_OBJECT_0) break;
            if ((LONG)(deadline - GetTickCount()) <= 0) {
                TerminateProcess(pi.hProcess, 1);
                break;
            }
            continue;
        }
        if (!ReadFile(hRead, buf, sizeof(buf), &readBytes, nullptr) || readBytes == 0) break;
        out.append(buf, readBytes);
        if (out.size() > 65536) break;
    }
    // Drain any remaining stdout after the process exits.
    while (ReadFile(hRead, buf, sizeof(buf), &readBytes, nullptr) && readBytes > 0) {
        out.append(buf, readBytes);
        if (out.size() > 65536) break;
    }
    WaitForSingleObject(pi.hProcess, 1000);
    DWORD exitCode = 0;
    GetExitCodeProcess(pi.hProcess, &exitCode);
    CloseHandle(hRead);
    CloseHandle(pi.hProcess);
    CloseHandle(pi.hThread);
    return exitCode;
}

// =============================================================================
//  Item extraction (XWF_Read on opened hItem -> CreateFile)
// =============================================================================
static bool ExtractItemToFile(HANDLE hItem, INT64 size, const std::wstring& destPath) {
    if (!XWF_Read || size < 0) return false;
    HANDLE hFile = CreateFileW(destPath.c_str(), GENERIC_WRITE, 0, nullptr,
                               CREATE_ALWAYS, FILE_ATTRIBUTE_NORMAL, nullptr);
    if (hFile == INVALID_HANDLE_VALUE) return false;
    constexpr DWORD kChunk = 64 * 1024;
    std::vector<BYTE> buf(kChunk);
    INT64 offset = 0;
    bool ok = true;
    while (offset < size) {
        DWORD want = (DWORD)std::min<INT64>(kChunk, size - offset);
        DWORD got = XWF_Read(hItem, offset, buf.data(), want);
        if (got == 0) { ok = false; break; }
        DWORD written = 0;
        if (!WriteFile(hFile, buf.data(), got, &written, nullptr) || written != got) {
            ok = false; break;
        }
        offset += got;
    }
    CloseHandle(hFile);
    return ok;
}

// =============================================================================
//  Tool-output parsing  (TODO: replace with your tool's format)
// =============================================================================
//   A "scan result" is whatever your tool reports about one item: a label, an
//   optional location, and an optional detail string. The worker tags items
//   that produce at least `tag_threshold` results.
struct ScanResult {
    std::wstring label;    // short classification (becomes the Report Table suffix)
    std::wstring detail;   // free-form description for the Comments column / CSV
    INT64        line = -1;
};

struct ScanResults {
    std::vector<ScanResult> rows;
    std::set<std::wstring>  labels;  // unique label set, built alongside rows
    size_t total() const { return rows.size(); }
};

// Parse the bytes your tool wrote (stdout capture, JSON/JSONL file, CSV, ...)
// into ScanResults. This stub returns an empty set so the template compiles
// and runs end-to-end without finding anything.
//
// TODO: parse your tool's output here. Examples of the shape:
//   - JSONL: split on '\n', pull fields per line (see the trufflehog exemplar
//     for a dependency-free string scanner).
//   - CSV:   split lines, split columns.
//   - text:  regex / substring scan.
static void ParseToolOutput(const std::string& toolOutput, ScanResults& out) {
    (void)toolOutput;
    // TODO: populate out.rows / out.labels from toolOutput.
    // Example skeleton (left commented so the template finds nothing by default):
    //
    //   ScanResult r;
    //   r.label  = L"example";
    //   r.detail = L"matched something";
    //   out.labels.insert(r.label);
    //   out.rows.push_back(std::move(r));
}

// =============================================================================
//  Helper-exe identity verification (canonical pattern —
//  docs/conventions/helper-exe-verification.md)
// =============================================================================
//   TODO: set HELPER_NEEDLE to a lowercase substring that uniquely identifies
//   your tool in its PE VERSIONINFO and/or its `--version` banner.
static const char*    HELPER_NEEDLE          = "yourtool";
static const wchar_t* kHelperIdentityNeedle  = L"yourtool";

// PE VERSIONINFO substring check on InternalName / OriginalFilename /
// ProductName / FileDescription. Returns true on first hit. Works for native
// Win32 binaries and PyInstaller exes that ship a populated VERSIONINFO. Some
// toolchains (e.g. plain `go build`) do NOT embed VERSIONINFO, in which case
// this always returns false and the --version banner check carries the load.
static bool PeIdentityContains(const std::wstring& exePath,
                               const wchar_t* needleLower) {
    DWORD handle = 0;
    DWORD size = GetFileVersionInfoSizeW(exePath.c_str(), &handle);
    if (size == 0) return false;
    std::vector<BYTE> buf(size);
    if (!GetFileVersionInfoW(exePath.c_str(), handle, size, buf.data())) return false;

    struct LCP { WORD wLanguage; WORD wCodePage; };
    LCP* lcp = nullptr;
    UINT lcpLen = 0;
    if (!VerQueryValueW(buf.data(), L"\\VarFileInfo\\Translation",
                        (LPVOID*)&lcp, &lcpLen) || !lcp || lcpLen < sizeof(LCP))
        return false;

    const size_t nLangs = lcpLen / sizeof(LCP);
    const wchar_t* fields[] = {
        L"InternalName", L"OriginalFilename", L"ProductName", L"FileDescription"
    };
    for (size_t li = 0; li < nLangs; ++li) {
        for (const wchar_t* f : fields) {
            wchar_t sub[100];
            swprintf_s(sub, L"\\StringFileInfo\\%04x%04x\\%s",
                       lcp[li].wLanguage, lcp[li].wCodePage, f);
            wchar_t* val = nullptr;
            UINT vlen = 0;
            if (VerQueryValueW(buf.data(), sub, (LPVOID*)&val, &vlen) && val) {
                std::wstring s = ToLowerW(val);
                if (s.find(needleLower) != std::wstring::npos) return true;
            }
        }
    }
    return false;
}

// Run `<exe> --version` and return the first non-empty output line, or "" if
// the probe failed or the output looked like an argparse fallback ("usage:",
// "error:", "unrecognized arguments") rather than a real version banner. The
// banner-filter is load-bearing: an exe that doesn't recognize --version often
// prints one of those banners, and we must NOT treat that as a passing banner.
//
// TODO: if your tool's version flag is not `--version` (e.g. `-V`, `version`),
// change it here.
static std::wstring DetectToolVersion(const std::wstring& exe) {
    if (exe.empty() || !FileExists(exe)) return {};
    std::wstring cmd = L"\""; cmd += exe; cmd += L"\" --version";
    std::string out;
    DWORD ec = RunCaptureStdout(cmd, out, 5000);
    (void)ec;  // many tools' --version exit code varies; trust the output.
    std::wstring w = TrimW(Utf8ToWide(out));
    size_t nl = w.find_first_of(L"\r\n");
    if (nl != std::wstring::npos) w.resize(nl);
    std::wstring lowered = ToLowerW(w);
    if (lowered.rfind(L"usage:", 0) == 0)                              return {};
    if (lowered.find(L"error:") != std::wstring::npos)                 return {};
    if (lowered.find(L"unrecognized arguments") != std::wstring::npos) return {};
    return w;
}

// VerifyHelperIdentity composes the PE check and the --version banner check.
// Returns true if EITHER passes (the convention's OR-of-two-checks rule; see
// docs/conventions/helper-exe-verification.md). Populates outDetail
// with a human-readable explanation of which check(s) passed.
static bool VerifyHelperIdentity(const std::wstring& exePath,
                                 const wchar_t* needle,
                                 std::wstring& outVersionLine,
                                 std::wstring& outDetail) {
    std::wstring needleLower = ToLowerW(needle);

    bool pe   = PeIdentityContains(exePath, needleLower.c_str());
    bool flag = false;
    outVersionLine = DetectToolVersion(exePath);
    if (!outVersionLine.empty()) {
        std::wstring lower = ToLowerW(outVersionLine);
        if (lower.find(needleLower) != std::wstring::npos) flag = true;
    }

    if (pe && flag)  outDetail = L"PE VERSIONINFO + --version banner match";
    else if (pe)     outDetail = L"PE VERSIONINFO match";
    else if (flag)   outDetail = L"--version banner match";
    else             outDetail = L"no \"" + std::wstring(needle) +
                                  L"\" marker in PE VERSIONINFO or --version output";
    return pe || flag;
}

// Bounded breadth-first scan for a partnered binary anywhere under `root`.
// Returns the shallowest match (so a copy directly next to the DLL beats one
// nested under tools\). Bounded by maxDepth + a directory-visit budget. Skips
// well-known nuisance dirs and hidden directories.
static std::wstring FindSiblingFile(const std::wstring& root,
                                    const wchar_t* targetName,
                                    int maxDepth = 4,
                                    int maxDirsVisited = 256) {
    if (root.empty() || !targetName || !*targetName) return {};
    struct Entry { std::wstring dir; int depth; };
    std::vector<Entry> queue;
    queue.push_back({ root, 0 });

    int visited = 0;
    for (size_t i = 0; i < queue.size() && visited < maxDirsVisited; ++i) {
        const Entry e = queue[i];
        ++visited;

        std::wstring candidate = e.dir + L"\\" + targetName;
        if (FileExists(candidate)) return candidate;
        if (e.depth >= maxDepth) continue;

        WIN32_FIND_DATAW fd = {};
        std::wstring pattern = e.dir + L"\\*";
        HANDLE h = FindFirstFileW(pattern.c_str(), &fd);
        if (h == INVALID_HANDLE_VALUE) continue;
        do {
            if (!(fd.dwFileAttributes & FILE_ATTRIBUTE_DIRECTORY)) continue;
            if (fd.cFileName[0] == L'.') continue;  // skip . / .. / hidden dotdirs
            if (fd.dwFileAttributes & FILE_ATTRIBUTE_HIDDEN) continue;
            const wchar_t* nm = fd.cFileName;
            if (!_wcsicmp(nm, L".git") || !_wcsicmp(nm, L".vs") ||
                !_wcsicmp(nm, L"node_modules") || !_wcsicmp(nm, L"__pycache__")) continue;
            queue.push_back({ e.dir + L"\\" + nm, e.depth + 1 });
        } while (FindNextFileW(h, &fd));
        FindClose(h);
    }
    return {};
}

// Locate <yourtool>.exe alongside the DLL. Tries conventional bundled paths
// first (cheap stat calls), then falls back to a bounded recursive search.
//
// TODO: change "yourtool.exe" / the bundled-path list to match your tool.
static std::wstring ResolveDefaultTool() {
    std::wstring dllDir = GetSelfDirectory();
    if (dllDir.empty()) return {};
    for (const wchar_t* sub : {
            L"\\tools\\yourtool\\yourtool.exe",
            L"\\tools\\yourtool.exe",
            L"\\yourtool.exe",
         }) {
        std::wstring guess = dllDir + sub;
        if (FileExists(guess)) return guess;
    }
    return FindSiblingFile(dllDir, L"yourtool.exe");
}

// Async version + identity probe. DetectToolVersion spawns a subprocess and
// waits up to 5s; PeIdentityContains reads PE VERSIONINFO synchronously. Doing
// both on the UI thread before DialogBoxParamW stacks onto the X-Ways
// enumeration freeze and pushes the "Not Responding" window long enough that
// the analyst may kill X-Ways. The dialog opens with "(detecting...)" and
// updates via WM_APP_VERSION when the probe completes.
struct VersionProbeArgs {
    HWND         hDlg;
    std::wstring exe;
    unsigned     token;
};

struct VersionProbeResult {
    std::wstring exe;          // the path that was probed (for the rejection label)
    std::wstring versionLine;  // first non-empty line of --version output (may be empty)
    std::wstring detail;       // human-readable explanation: which check(s) passed
    bool         valid = false; // PE check OR banner check matched the needle
    bool         fileExists = false;
    unsigned     token = 0;    // matches the g_probeToken value at probe-start
};

// Monotonically-increasing probe sequence. Incremented on every new probe;
// WM_APP_VERSION discards results whose token doesn't match the current value,
// closing the rapid-Browse race where an OLD (slow) probe's "valid" result
// could arrive AFTER a NEW (fast) probe's rejection and re-enable Run for the
// WRONG exe.
static std::atomic<unsigned> g_probeToken{0};

static unsigned __stdcall VersionProbeThread(void* arg) {
    auto* a = static_cast<VersionProbeArgs*>(arg);
    auto* res = new VersionProbeResult{};
    res->exe        = a->exe;
    res->token      = a->token;
    res->fileExists = FileExists(a->exe);
    if (res->fileExists) {
        res->valid = VerifyHelperIdentity(a->exe, kHelperIdentityNeedle,
                                          res->versionLine, res->detail);
    } else {
        res->valid  = false;
        res->detail = L"file not found at picked path";
    }
    if (!PostMessageW(a->hDlg, WM_APP_VERSION, 0, (LPARAM)res)) {
        delete res;
    }
    delete a;
    return 0;
}

static void StartAsyncVersionProbe(HWND hDlg, const std::wstring& exe) {
    if (exe.empty() || !hDlg) return;
    unsigned token = ++g_probeToken;   // stamp this probe; older posts get discarded
    auto* a = new VersionProbeArgs{hDlg, exe, token};
    HANDLE h = (HANDLE)_beginthreadex(nullptr, 0, VersionProbeThread, a, 0, nullptr);
    if (!h) { delete a; return; }
    CloseHandle(h);  // detached -- result delivered via PostMessage
}

// =============================================================================
//  Browse helpers
// =============================================================================
static std::wstring BrowseForFile(HWND parent, const std::wstring& current) {
    wchar_t buf[MAX_PATH] = {0};
    if (!current.empty() && current.size() < MAX_PATH) wcscpy_s(buf, current.c_str());

    // Anchor the picker to the current path's dir, else our own DLL folder.
    // OFN_NOCHANGEDIR keeps the dialog from mutating the process CWD.
    std::wstring initDir;
    if (!current.empty()) {
        size_t slash = current.find_last_of(L"\\/");
        if (slash != std::wstring::npos) initDir = current.substr(0, slash);
    }
    if (initDir.empty()) initDir = GetSelfDirectory();

    OPENFILENAMEW ofn = {};
    ofn.lStructSize     = sizeof(ofn);
    ofn.hwndOwner       = parent;
    ofn.lpstrFilter     = L"Executable (*.exe)\0*.exe\0All files (*.*)\0*.*\0";
    ofn.lpstrFile       = buf;
    ofn.nMaxFile        = MAX_PATH;
    ofn.lpstrTitle      = L"Select tool executable";
    ofn.lpstrInitialDir = initDir.empty() ? nullptr : initDir.c_str();
    ofn.Flags           = OFN_PATHMUSTEXIST | OFN_FILEMUSTEXIST | OFN_HIDEREADONLY |
                          OFN_NOCHANGEDIR;
    if (!GetOpenFileNameW(&ofn)) return current;
    return buf;
}

// Modern folder picker using IFileOpenDialog (Vista+). Returns the picked
// path, or `current` on Cancel.
static std::wstring BrowseForFolder(HWND parent, const std::wstring& current,
                                    const wchar_t* title = L"Select folder") {
    HRESULT hrInit = CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED | COINIT_DISABLE_OLE1DDE);
    std::wstring picked = current;

    IFileOpenDialog* dlg = nullptr;
    HRESULT hr = CoCreateInstance(CLSID_FileOpenDialog, nullptr, CLSCTX_INPROC_SERVER,
                                  IID_PPV_ARGS(&dlg));
    if (SUCCEEDED(hr) && dlg) {
        DWORD opts = 0;
        dlg->GetOptions(&opts);
        dlg->SetOptions(opts | FOS_PICKFOLDERS | FOS_FORCEFILESYSTEM | FOS_PATHMUSTEXIST);
        dlg->SetTitle(title);
        if (!current.empty()) {
            IShellItem* psi = nullptr;
            if (SUCCEEDED(SHCreateItemFromParsingName(current.c_str(), nullptr, IID_PPV_ARGS(&psi))) && psi) {
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

// =============================================================================
//  Worker-thread state — owned by the dialog while a scan runs
// =============================================================================
struct WorkerCtx {
    Settings*       s   = nullptr;
    RunCtx*         ctx = nullptr;
    HWND            hDlg = nullptr;

    // Resolved at run start.
    std::wstring    runDir;
    std::wstring    inDir;
    std::wstring    outDir;

    // Live progress.
    std::atomic<bool> cancelRequested {false};

    // Final stats (written by worker, read by dialog on DONE).
    size_t          itemsSeen      = 0;
    size_t          itemsScanned   = 0;
    size_t          itemsTagged    = 0;
    size_t          itemsSkipped   = 0;
    size_t          totalResults   = 0;
    size_t          failures       = 0;

    // Consolidated result rows, written to <runDir>\results.csv at end of run.
    struct ResultRow {
        LONG         itemID = -1;
        std::wstring name;
        std::wstring path;
        std::wstring label;
        std::wstring detail;
        INT64        line = -1;
    };
    std::vector<ResultRow> allResults;
};
static WorkerCtx*   g_worker      = nullptr;
static HANDLE       g_workerThread = nullptr;
static std::wstring g_lastRunDir;  // set on DONE, used by "Open output folder" button
// True only when the async version probe has confirmed the configured exe
// actually identifies as the tool. Gates the Run button.
static bool         g_exeValid     = false;
// Helper-rejection flash state. When g_helperRejected is true, the Version
// readout is painted bold red via WM_CTLCOLORSTATIC. While g_helperFlashTicks
// > 0, the colour alternates bright/dark every 250 ms via WM_TIMER, then
// settles solid bright red. Cleared on every Browse / WM_INITDIALOG.
static bool         g_helperRejected   = false;
static int          g_helperFlashTicks = 0;
constexpr UINT_PTR  kHelperFlashTimerId   = 0xC004;
constexpr UINT      kHelperFlashPeriodMs  = 250;
constexpr int       kHelperFlashTickCount = 8;        // 8 * 250 ms = ~2 s
static HFONT        g_boldFont     = nullptr;
static const wchar_t* kHelperRejectionMessage = L"Not a valid tool executable";
static const wchar_t* kHelperMissingMessage   = L"File not found";

static HFONT EnsureBoldFont(HWND hDlg) {
    if (g_boldFont) return g_boldFont;
    HDC hdc = GetDC(hDlg);
    int dpiY = hdc ? GetDeviceCaps(hdc, LOGPIXELSY) : 96;
    if (hdc) ReleaseDC(hDlg, hdc);
    LOGFONTW lf = {};
    wcscpy_s(lf.lfFaceName, LF_FACESIZE, L"MS Shell Dlg");
    lf.lfHeight = -MulDiv(10, dpiY, 72);
    lf.lfWeight = FW_BOLD;
    g_boldFont = CreateFontIndirectW(&lf);
    return g_boldFont;
}

// Title-bar icon, loaded via LoadImageW (LR_LOADFROMFILE) from <NAME>.ico next
// to the DLL so the .ico doesn't need to be RC-embedded.
static HICON g_titleIconSmall = nullptr;
static HICON g_titleIconBig   = nullptr;

static void ApplyTitleIcon(HWND hDlg) {
    if (!g_titleIconSmall && !g_titleIconBig) {
        std::wstring iconPath = GetSelfDirectory() + L"\\" + NAME + L".ico";
        if (FileExists(iconPath)) {
            g_titleIconSmall = (HICON)LoadImageW(nullptr, iconPath.c_str(),
                IMAGE_ICON, 16, 16, LR_LOADFROMFILE);
            g_titleIconBig   = (HICON)LoadImageW(nullptr, iconPath.c_str(),
                IMAGE_ICON, 32, 32, LR_LOADFROMFILE);
        }
    }
    if (g_titleIconSmall) SendMessageW(hDlg, WM_SETICON, ICON_SMALL, (LPARAM)g_titleIconSmall);
    if (g_titleIconBig)   SendMessageW(hDlg, WM_SETICON, ICON_BIG,   (LPARAM)g_titleIconBig);
}

// Activate the in-dialog rejection display: bold red label, flashing for ~2 s
// then solid bright red, Run disabled, and the rejected path echoed into the
// path edit so the analyst sees what was rejected.
static void ShowHelperRejection(HWND hDlg, const std::wstring& rejectedPath,
                                const std::wstring& detail,
                                const wchar_t* labelText) {
    g_helperRejected   = true;
    g_helperFlashTicks = kHelperFlashTickCount;
    g_exeValid         = false;

    EnsureBoldFont(hDlg);
    HWND hVer = GetDlgItem(hDlg, IDC_LABEL_TOOL_VERSION);
    HWND hRun = GetDlgItem(hDlg, IDC_BTN_RUN);

    SetDlgItemTextW(hDlg, IDC_EDIT_TOOL_BIN, rejectedPath.c_str());
    SetDlgItemTextW(hDlg, IDC_LABEL_TOOL_VERSION, labelText);
    if (hVer && g_boldFont) SendMessageW(hVer, WM_SETFONT, (WPARAM)g_boldFont, TRUE);

    SetTimer(hDlg, kHelperFlashTimerId, kHelperFlashPeriodMs, nullptr);
    if (hVer) InvalidateRect(hVer, nullptr, TRUE);
    if (hRun) EnableWindow(hRun, FALSE);

    Log(L"helper-exe REJECTED (" + rejectedPath + L") -- " + detail);
}

// Clear the rejection display and restore the Version label to the dialog's
// default font/colour. Idempotent.
static void ClearHelperRejection(HWND hDlg) {
    if (g_helperRejected) {
        g_helperRejected   = false;
        g_helperFlashTicks = 0;
        KillTimer(hDlg, kHelperFlashTimerId);
    }
    HWND hVer = GetDlgItem(hDlg, IDC_LABEL_TOOL_VERSION);
    if (hVer) {
        HFONT base = (HFONT)SendMessageW(hDlg, WM_GETFONT, 0, 0);
        SendMessageW(hVer, WM_SETFONT, (WPARAM)base, TRUE);
        InvalidateRect(hVer, nullptr, TRUE);
    }
}

static void PostStatus(HWND hDlg, const std::wstring& s) {
    if (!hDlg) return;
    size_t bytes = (s.size() + 1) * sizeof(wchar_t);
    wchar_t* buf = (wchar_t*)malloc(bytes);
    if (!buf) return;
    memcpy(buf, s.c_str(), bytes);
    if (!PostMessageW(hDlg, WM_APP_STATUS, 0, (LPARAM)buf)) free(buf);
}

static void PostProgress(HWND hDlg, int permille) {
    if (hDlg) PostMessageW(hDlg, WM_APP_PROGRESS, (WPARAM)permille, 0);
}

static void PostMarquee(HWND hDlg, bool on) {
    if (hDlg) PostMessageW(hDlg, WM_APP_MARQUEE, (WPARAM)(on ? 1 : 0), 0);
}

// =============================================================================
//  Tagging + command builder + per-item flow
// =============================================================================
static void RecordHit(LONG nItemID, const std::wstring& fullPath,
                      const ScanResults& fx, const Settings& s) {
    // One report-table entry per label class. Prefer XWF_Label (21.7 SR-4+)
    // for the dedup-call API; fall back to XWF_AddToReportTable on older hosts.
    if (s.addToReportTable && (XWF_Label || XWF_AddToReportTable)) {
        if (fx.labels.empty()) {
            if (XWF_Label) XWF_Label(nItemID, REPORT_TABLE, 0);
            else           XWF_AddToReportTable(nItemID, REPORT_TABLE, 0);
        } else {
            for (const auto& lbl : fx.labels) {
                std::wstring tbl = std::wstring(NAME) + L": " + lbl;
                if (XWF_Label) XWF_Label(nItemID, tbl.c_str(), 0);
                else           XWF_AddToReportTable(nItemID, tbl.c_str(), 0);
            }
        }
    }
    if (s.addComment && XWF_AddComment) {
        std::wstring labelList; bool first = true;
        for (const auto& l : fx.labels) {
            if (!first) labelList += L", ";
            labelList += l; first = false;
        }
        std::wstring note = L"["; note += NAME; note += L"] ";
        note += FormatW(L"%zu result(s)", fx.total());
        if (!labelList.empty()) { note += L" \x2014 "; note += labelList; }
        if (!fullPath.empty())  { note += L" @ "; note += fullPath; }
        XWF_AddComment(nItemID, note.c_str(), COMMENT_APPEND);
    }
}

// Build the tool command line for a given target path. Wrapped in cmd.exe /C
// with stdout/stderr redirected to files the worker reads afterward.
//
// TODO: build your tool's command line. Most CLI tools take the form
//   <exe> <subcommand> <flags> <inputFile>
// and emit results to stdout (captured here into outFile).
static std::wstring BuildToolCmd(const Settings& s,
                                 const std::wstring& target,
                                 const std::wstring& outFile,
                                 const std::wstring& errLog) {
    std::wstring flags;
    // TODO: add your tool's built-in flags here, e.g.:
    //   flags += L" --json";
    if (!s.extraArgs.empty()) { flags += L" "; flags += s.extraArgs; }

    return L"cmd.exe /C \""
         + std::wstring(L"\"") + s.toolExe + L"\""
         + flags
         + L" \"" + target + L"\""
         + L" > \"" + outFile + L"\""
         + L" 2> \"" + errLog + L"\""
         + L"\"";
}

static std::wstring LeafExtensionLower(const std::wstring& leaf) {
    size_t dot = leaf.find_last_of(L'.');
    if (dot == std::wstring::npos || dot + 1 >= leaf.size()) return {};
    return ToLowerW(leaf.substr(dot + 1));
}

static bool ShouldScan(LONG nItemID, INT64 size, const Settings& s) {
    if (XWF_GetItemInformation) {
        BOOL valid = FALSE;
        LONG flags = (LONG)XWF_GetItemInformation(nItemID, XWF_ITEM_INFO_FLAGS, &valid);
        if (valid && (flags & XWF_ITEM_INFO_FLAG_DIRECTORY)) return false;
    }
    INT64 maxBytes = s.maxSizeMiB > 0 ? s.maxSizeMiB * 1024LL * 1024LL : INT64_MAX;
    if (size < s.minSizeBytes || size > maxBytes) return false;
    // TODO: add any tool-specific scope checks here (e.g. extension prefilter).
    return true;
}

static void PostStageStatus(WorkerCtx* w, size_t idx, size_t total,
                            const wchar_t* task, const std::wstring& leaf) {
    std::wstring trimmed = leaf;
    if (trimmed.size() > 64) trimmed = L"\x2026" + trimmed.substr(trimmed.size() - 60);
    PostStatus(w->hDlg, FormatW(L"[%zu/%zu]  %s: %s",
                                idx, total, task,
                                trimmed.empty() ? L"item" : trimmed.c_str()));
}

// Tag one item with its accumulated results + push CSV rows + bump counters.
static void TagItemFromResults(WorkerCtx* w, LONG itemID, ScanResults& fx) {
    if (fx.rows.empty()) return;
    const wchar_t* nm = XWF_GetItemName ? XWF_GetItemName(itemID) : nullptr;
    std::wstring leaf     = (nm && *nm) ? std::wstring(nm) : std::wstring();
    std::wstring fullPath = BuildItemFullPath(itemID);
    const std::wstring& shown = fullPath.empty() ? leaf : fullPath;
    LogVerbose(FormatW(L"results=%zu: %s", fx.total(), shown.c_str()));

    w->totalResults += fx.total();
    if ((int)fx.total() < w->s->tagThreshold) return;
    for (const auto& f : fx.rows) {
        WorkerCtx::ResultRow r;
        r.itemID = itemID;
        r.name   = leaf;
        r.path   = fullPath;
        r.label  = f.label;
        r.detail = f.detail;
        r.line   = f.line;
        w->allResults.push_back(std::move(r));
    }
    RecordHit(itemID, fullPath, fx, *w->s);
    ++w->itemsTagged;
}

// Build "<full path>" or fall back to the leaf for log lines.
static std::wstring fullPathOr(LONG id, const std::wstring& leaf);

// Process one item end-to-end: extract -> run the tool -> parse -> tag.
static void ProcessOneItem(WorkerCtx* w, LONG id, size_t idx, size_t total) {
    ++w->itemsSeen;

    INT64 size = XWF_GetItemSize ? XWF_GetItemSize(id) : 0;
    if (!ShouldScan(id, size, *w->s)) {
        ++w->itemsSkipped;
        return;
    }

    const wchar_t* nm = XWF_GetItemName ? XWF_GetItemName(id) : nullptr;
    std::wstring leaf = (nm && *nm) ? std::wstring(nm) : L"item";
    PostStageStatus(w, idx, total, L"Extracting", leaf);

    HANDLE hItem = XWF_OpenItem ? XWF_OpenItem(w->ctx->hVolume, id, 0) : nullptr;
    if (!hItem || hItem == INVALID_HANDLE_VALUE) { ++w->failures; return; }

    wchar_t idBuf[32]; swprintf_s(idBuf, L"%ld_", id);
    std::wstring destPath = w->inDir + L"\\" + std::wstring(idBuf) + SafeLeaf(leaf);
    if (!ExtractItemToFile(hItem, size, destPath)) {
        if (XWF_Close) XWF_Close(hItem);
        LogVerbose(L"extract failed: " + (fullPathOr(id, leaf)));
        ++w->failures;
        return;
    }
    if (XWF_Close) XWF_Close(hItem);
    ++w->itemsScanned;

    // Run the tool on the extracted bytes.
    PostStageStatus(w, idx, total, L"Scanning", leaf);
    std::wstring outFile = w->outDir + L"\\" + std::wstring(idBuf) + L"out.txt";
    std::wstring errLog  = w->outDir + L"\\" + std::wstring(idBuf) + L"err.txt";
    std::wstring cmd = BuildToolCmd(*w->s, destPath, outFile, errLog);
    DWORD exitCode = 0;
    if (!RunCommand(cmd, w->runDir, exitCode)) {
        Log(L"tool subprocess failed for item " + std::to_wstring(id));
        ++w->failures;
        return;
    }

    // Parse the tool's output + tag.
    PostStageStatus(w, idx, total, L"Parsing", leaf);
    std::string toolOut;
    ReadWholeFile(outFile, toolOut);            // empty output is fine
    ScanResults fx;
    ParseToolOutput(toolOut, fx);               // TODO: real parsing fills fx
    TagItemFromResults(w, id, fx);
}

// =============================================================================
//  Consolidated results CSV at end of run  (TODO: adjust columns)
// =============================================================================
//   A SIMPLE dependency-free CSV writer. The trufflehog exemplar ships a full
//   store-only XLSX writer instead; swap this out if you need a spreadsheet.
static std::string CsvEscape(const std::wstring& w) {
    std::string s = WideToUtf8(w);
    bool needQuote = s.find_first_of(",\"\r\n") != std::string::npos;
    if (!needQuote) return s;
    std::string out = "\"";
    for (char c : s) { if (c == '"') out += "\"\""; else out += c; }
    out += "\"";
    return out;
}

static void WriteResultsCsv(WorkerCtx* w) {
    if (w->allResults.empty()) {
        LogVerbose(L"results CSV: nothing to write -- skipping file");
        return;
    }
    std::wstring path = w->runDir + L"\\results.csv";
    FILE* fp = nullptr;
    if (_wfopen_s(&fp, path.c_str(), L"wb") != 0 || !fp) {
        Log(L"failed to write results CSV: " + path);
        return;
    }
    const unsigned char bom[] = {0xEF, 0xBB, 0xBF};
    fwrite(bom, 1, 3, fp);
    // TODO: adjust these columns to match your tool's findings.
    std::string header = "ItemID,Name,FullPath,Label,Line,Detail\r\n";
    fwrite(header.data(), 1, header.size(), fp);
    char numbuf[64];
    for (const auto& r : w->allResults) {
        sprintf_s(numbuf, "%ld", r.itemID);
        std::string row = numbuf;
        row += ","; row += CsvEscape(r.name);
        row += ","; row += CsvEscape(r.path);
        row += ","; row += CsvEscape(r.label);
        row += ",";
        if (r.line > 0) { sprintf_s(numbuf, "%lld", (long long)r.line); row += numbuf; }
        row += ","; row += CsvEscape(r.detail);
        row += "\r\n";
        fwrite(row.data(), 1, row.size(), fp);
    }
    fclose(fp);
    Log(FormatW(L"results CSV: %zu rows -> %s", w->allResults.size(), path.c_str()));
}

// =============================================================================
//  Worker thread
// =============================================================================
static unsigned __stdcall WorkerThread(void* arg) {
    auto* w = (WorkerCtx*)arg;
    HWND  hDlg = w->hDlg;

    g_verbose = w->s->verbose;

    // ---- Set up the run-dir tree. outputBase already includes the X-Tension
    //      subfolder (set by ResolveDefaultOutputBase or by the user).
    std::wstring xtRoot = w->s->outputBase;
    if (xtRoot.empty()) {
        std::wstring src;
        xtRoot = ResolveDefaultOutputBase(w->ctx->hEvidence, src);
        Log(L"output base: " + xtRoot + L"  (" + src + L")");
    }
    if (!EnsureDirectoryExists(xtRoot)) {
        PostStatus(hDlg, L"Failed to create output root: " + xtRoot);
        PostMessageW(hDlg, WM_APP_DONE, 0, 0);
        return 1;
    }
    w->runDir = CreateUniqueRunDir(xtRoot);
    if (w->runDir.empty()) {
        PostStatus(hDlg, L"Failed to create run dir under: " + xtRoot);
        PostMessageW(hDlg, WM_APP_DONE, 0, 0);
        return 1;
    }
    w->inDir  = w->runDir + L"\\in";
    w->outDir = w->runDir + L"\\out";
    if (!EnsureDirectoryExists(w->inDir) || !EnsureDirectoryExists(w->outDir)) {
        PostStatus(hDlg, L"Failed to create in/out subdirs under: " + w->runDir);
        PostMessageW(hDlg, WM_APP_DONE, 0, 0);
        return 1;
    }
    g_lastRunDir = w->runDir;
    Log(L"run dir: " + w->runDir);

    const std::vector<LONG>& ids = w->ctx->items;
    if (ids.empty()) {
        PostStatus(hDlg, L"No items to scan.");
        PostMessageW(hDlg, WM_APP_DONE, 1, 0);
        return 0;
    }

    PostMarquee(hDlg, false);
    SendMessageW(GetDlgItem(hDlg, IDC_PROGRESS_RUN), PBM_SETRANGE32, 0, 1000);
    PostStatus(hDlg, FormatW(L"Scanning %zu item(s)...", ids.size()));

    const size_t total = ids.size();
    for (size_t i = 0; i < total; ++i) {
        if (w->cancelRequested.load()) break;
        if (XWF_ShouldStop && XWF_ShouldStop()) { w->cancelRequested.store(true); break; }
        ProcessOneItem(w, ids[i], i + 1, total);
        int permille = (int)((double)(i + 1) * 1000.0 / (double)total);
        PostProgress(hDlg, permille);
    }

    bool cancelled = w->cancelRequested.load();

    // Emit consolidated results before posting DONE.
    WriteResultsCsv(w);

    PostStatus(hDlg, FormatW(L"%s: scanned=%zu tagged=%zu skipped=%zu results=%zu failures=%zu",
                             cancelled ? L"Cancelled" : L"Done",
                             w->itemsScanned, w->itemsTagged, w->itemsSkipped,
                             w->totalResults, w->failures));
    Log(FormatW(L"summary: seen=%zu scanned=%zu tagged=%zu skipped=%zu results=%zu failures=%zu",
                w->itemsSeen, w->itemsScanned, w->itemsTagged, w->itemsSkipped,
                w->totalResults, w->failures));
    Log(L"outputs: " + w->runDir);
    PostMessageW(hDlg, WM_APP_DONE, (WPARAM)(cancelled ? 0 : 1), 0);
    return 0;
}

// Late-defined helper used by ProcessOneItem (forward-declared above).
static std::wstring fullPathOr(LONG id, const std::wstring& leaf) {
    std::wstring p = BuildItemFullPath(id);
    return p.empty() ? leaf : p;
}

// =============================================================================
//  Dialog plumbing
// =============================================================================
static const int kInputCtlIds[] = {
    IDC_EDIT_TOOL_BIN, IDC_BTN_BROWSE_TOOL,
    IDC_EDIT_MIN_SIZE, IDC_EDIT_MAX_SIZE,
    IDC_EDIT_EXTRA_ARGS,
    IDC_EDIT_OUTPUT_DIR, IDC_BTN_BROWSE_OUTPUT,
    IDC_CHK_ADD_REPORT_TABLE, IDC_EDIT_TAG_THRESHOLD, IDC_CHK_VERBOSE,
    IDC_BTN_RUN, IDCANCEL,
};

static void SetDialogBusy(HWND hDlg, bool busy) {
    HWND hProg = GetDlgItem(hDlg, IDC_PROGRESS_RUN);
    if (busy) {
        SendMessageW(hProg, PBM_SETMARQUEE, FALSE, 0);
        LONG_PTR style = GetWindowLongPtrW(hProg, GWL_STYLE);
        SetWindowLongPtrW(hProg, GWL_STYLE, style & ~PBS_MARQUEE);
        SendMessageW(hProg, PBM_SETRANGE32, 0, 1000);
        SendMessageW(hProg, PBM_SETPOS, 0, 0);
        EnableWindow(GetDlgItem(hDlg, IDCANCEL), TRUE);
    }
    for (int id : kInputCtlIds) {
        HWND h = GetDlgItem(hDlg, id);
        if (h && id != IDCANCEL) EnableWindow(h, busy ? FALSE : TRUE);
    }
    EnableWindow(GetDlgItem(hDlg, IDC_BTN_ABOUT), TRUE);
    EnableWindow(GetDlgItem(hDlg, IDC_BTN_OPEN_OUTPUT), TRUE);
    // Run is gated on exe-validity (the async --version probe must have
    // confirmed the binary). When busy, Run is force-disabled.
    EnableWindow(GetDlgItem(hDlg, IDC_BTN_RUN),
                 (!busy && g_exeValid) ? TRUE : FALSE);
}

// Read controls -> Settings struct on Run.
static bool ReadDialogToSettings(HWND hDlg, Settings& s) {
    wchar_t buf[1024];

    GetDlgItemTextW(hDlg, IDC_EDIT_TOOL_BIN, buf, _countof(buf));
    s.toolExe = TrimW(buf);
    if (s.toolExe.empty() || !FileExists(s.toolExe)) {
        MessageBoxW(hDlg, L"The tool executable path is empty or does not exist.\n\n"
                          L"Point this field at your CLI tool's .exe.",
                    NAME, MB_OK | MB_ICONWARNING);
        SetFocus(GetDlgItem(hDlg, IDC_EDIT_TOOL_BIN));
        return false;
    }

    GetDlgItemTextW(hDlg, IDC_EDIT_OUTPUT_DIR, buf, _countof(buf));
    s.outputBase = TrimW(buf);

    GetDlgItemTextW(hDlg, IDC_EDIT_MIN_SIZE, buf, _countof(buf));
    s.minSizeBytes = ParseInt64(buf, 1);
    if (s.minSizeBytes < 0) s.minSizeBytes = 0;

    GetDlgItemTextW(hDlg, IDC_EDIT_MAX_SIZE, buf, _countof(buf));
    s.maxSizeMiB = ParseInt64(buf, 256);
    if (s.maxSizeMiB < 0) s.maxSizeMiB = 0;

    GetDlgItemTextW(hDlg, IDC_EDIT_EXTRA_ARGS, buf, _countof(buf));
    s.extraArgs = TrimW(buf);

    // "Add findings" tri-state (BS_AUTO3STATE on IDC_CHK_ADD_REPORT_TABLE):
    //   BST_UNCHECKED     -> neither Report Table nor Comments
    //   BST_INDETERMINATE -> Report Table only
    //   BST_CHECKED       -> Report Table + Comments (default)
    UINT addTri = IsDlgButtonChecked(hDlg, IDC_CHK_ADD_REPORT_TABLE);
    s.addToReportTable = (addTri != BST_UNCHECKED);
    s.addComment       = (addTri == BST_CHECKED);

    GetDlgItemTextW(hDlg, IDC_EDIT_TAG_THRESHOLD, buf, _countof(buf));
    s.tagThreshold = ParseInt(buf, 1);
    if (s.tagThreshold < 1) s.tagThreshold = 1;

    s.verbose = IsDlgButtonChecked(hDlg, IDC_CHK_VERBOSE) == BST_CHECKED;
    return true;
}

// Bold the GROUPBOX section titles at WM_INITDIALOG.
static void ApplyGroupTitleFont(HWND hDlg) {
    static HFONT s_groupTitleFont = nullptr;
    if (!s_groupTitleFont) {
        HDC hdc = GetDC(hDlg);
        int dpiY = hdc ? GetDeviceCaps(hdc, LOGPIXELSY) : 96;
        if (hdc) ReleaseDC(hDlg, hdc);
        LOGFONTW lf = {};
        lf.lfWeight  = FW_BOLD;
        lf.lfCharSet = DEFAULT_CHARSET;
        wcscpy_s(lf.lfFaceName, LF_FACESIZE, L"MS Shell Dlg");
        lf.lfHeight  = -MulDiv(11, dpiY, 72);
        s_groupTitleFont = CreateFontIndirectW(&lf);
    }
    if (!s_groupTitleFont) return;
    static const int kGroupIds[] = {
        IDC_GROUP_TOOL, IDC_GROUP_INPUT, IDC_GROUP_OUTPUT, IDC_GROUP_STATUS,
    };
    for (int id : kGroupIds) {
        HWND grp = GetDlgItem(hDlg, id);
        if (grp) SendMessageW(grp, WM_SETFONT, (WPARAM)s_groupTitleFont, TRUE);
    }
}

// Cue-banner placeholder hints (shown when the edit is empty).
static void ApplyCueBanners(HWND hDlg, const Settings* s) {
    auto cue = [&](int id, const wchar_t* text) {
        SendDlgItemMessageW(hDlg, id, EM_SETCUEBANNER, TRUE, (LPARAM)text);
    };
    cue(IDC_EDIT_TOOL_BIN,      L"Path to your tool's .exe");
    cue(IDC_EDIT_EXTRA_ARGS,    L"Hint: extra flags appended to the tool command line");
    cue(IDC_EDIT_TAG_THRESHOLD, L"1 = any hit");
    if (!s->outputBase.empty())
        cue(IDC_EDIT_OUTPUT_DIR, s->outputBase.c_str());
}

// Set dialog state from Settings on WM_INITDIALOG.
static void PopulateDialog(HWND hDlg, Settings* s, RunCtx* ctx) {
    wchar_t cap[256]; GetWindowTextW(hDlg, cap, _countof(cap));
    std::wstring aug = cap; aug += L"  (v"; aug += VERSION; aug += L")";
    SetWindowTextW(hDlg, aug.c_str());

    ApplyGroupTitleFont(hDlg);

    SetDlgItemTextW(hDlg, IDC_EDIT_TOOL_BIN, s->toolExe.c_str());
    if (s->toolVersion.empty()) {
        SetDlgItemTextW(hDlg, IDC_LABEL_TOOL_VERSION, L"Version: (not detected)");
    } else {
        std::wstring v = L"Version: "; v += s->toolVersion;
        SetDlgItemTextW(hDlg, IDC_LABEL_TOOL_VERSION, v.c_str());
    }

    // Items-to-scan count (file/dir split mirrors the X-Ways status line).
    const size_t totalItems = ctx->items.size();
    const size_t fileCount  = (totalItems > ctx->dirCount) ? totalItems - ctx->dirCount : totalItems;
    std::wstring countStr = (ctx->dirCount > 0)
        ? FormatW(L"%zu files", fileCount)
        : FormatW(L"%zu", totalItems);
    SetDlgItemTextW(hDlg, IDC_LABEL_SELECTED_COUNT,     L"Items to scan:");
    SetDlgItemTextW(hDlg, IDC_LABEL_SELECTED_COUNT_NUM, countStr.c_str());
    HFONT hBold = EnsureBoldFont(hDlg);
    if (hBold)
        SendDlgItemMessageW(hDlg, IDC_LABEL_SELECTED_COUNT_NUM, WM_SETFONT, (WPARAM)hBold, TRUE);

    SetDlgItemTextW(hDlg, IDC_EDIT_MIN_SIZE, FormatW(L"%lld", (long long)s->minSizeBytes).c_str());
    SetDlgItemTextW(hDlg, IDC_EDIT_MAX_SIZE, FormatW(L"%lld", (long long)s->maxSizeMiB).c_str());
    SetDlgItemTextW(hDlg, IDC_EDIT_EXTRA_ARGS, s->extraArgs.c_str());

    SetDlgItemTextW(hDlg, IDC_EDIT_OUTPUT_DIR, s->outputBase.c_str());
    UINT addTri = BST_UNCHECKED;
    if (s->addToReportTable && s->addComment) addTri = BST_CHECKED;
    else if (s->addToReportTable)              addTri = BST_INDETERMINATE;
    else if (s->addComment)                    addTri = BST_CHECKED;
    CheckDlgButton(hDlg, IDC_CHK_ADD_REPORT_TABLE, addTri);
    SetDlgItemTextW(hDlg, IDC_EDIT_TAG_THRESHOLD, FormatW(L"%d", s->tagThreshold).c_str());
    CheckDlgButton(hDlg, IDC_CHK_VERBOSE, s->verbose ? BST_CHECKED : BST_UNCHECKED);

    ApplyCueBanners(hDlg, s);

    HWND hProg = GetDlgItem(hDlg, IDC_PROGRESS_RUN);
    SendMessageW(hProg, PBM_SETRANGE32, 0, 1000);
    SendMessageW(hProg, PBM_SETPOS, 0, 0);
    SetDlgItemTextW(hDlg, IDC_LABEL_PROGRESS_STATUS, L"Ready.");
}

// =============================================================================
//  Tooltip popups for non-obvious controls
// =============================================================================
struct TipDef { int id; const wchar_t* text; };

static const TipDef kTooltips[] = {
    { IDC_EDIT_MIN_SIZE,
      L"Items smaller than this (in bytes) are skipped before extraction.\r\n"
      L"Default 1 = skip zero-byte items only." },
    { IDC_EDIT_MAX_SIZE,
      L"Items larger than this (in MiB) are skipped before extraction." },
    { IDC_EDIT_EXTRA_ARGS,
      L"Free-form pass-through to the tool command line, spliced after the "
      L"built-in flags." },
    { IDC_CHK_ADD_REPORT_TABLE,
      L"Combined Add-findings control. Cycles through three states:\r\n"
      L"  [ ] unchecked     - DO NOT tag findings\r\n"
      L"  [-] indeterminate - Report Table only\r\n"
      L"  [v] checked       - Report Table + Comments summary (DEFAULT)" },
    { IDC_EDIT_TAG_THRESHOLD,
      L"Minimum number of results on a single item before that item is tagged.\r\n"
      L"1 = tag any hit (default)." },
    { IDC_CHK_VERBOSE,
      L"Print per-item diagnostic lines to the X-Ways Messages window." },
    { IDC_BTN_RUN,
      L"Run the scan with the current dialog settings.\r\n\r\n"
      L"Disabled until the tool .exe path has been validated -- the X-Tension "
      L"runs `<exe> --version` asynchronously and only enables Run when the "
      L"output identifies the binary as the expected tool.\r\n\r\n"
      L"Hold Ctrl while clicking to SAVE the cfg WITHOUT starting the scan. "
      L"While Ctrl is held, the button label flips to 'Save' and turns blue." },
    { IDCANCEL,
      L"Close the dialog (or, during a scan, stop the worker).\r\n\r\n"
      L"Hold Ctrl to turn this into 'Save as...' -- opens a file picker to "
      L"save the current settings to a chosen .cfg path." },
};

static HWND CreateAndAttachTooltips(HWND hDlg) {
    HWND hTip = CreateWindowExW(WS_EX_TOPMOST, TOOLTIPS_CLASSW, nullptr,
                                WS_POPUP | TTS_ALWAYSTIP | TTS_NOPREFIX,
                                CW_USEDEFAULT, CW_USEDEFAULT,
                                CW_USEDEFAULT, CW_USEDEFAULT,
                                hDlg, nullptr, g_hSelf, nullptr);
    if (!hTip) return nullptr;
    SendMessageW(hTip, TTM_SETMAXTIPWIDTH, 0, 360);
    SendMessageW(hTip, TTM_SETDELAYTIME, TTDT_AUTOPOP, MAKELPARAM(60000, 0));
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
    return hTip;
}

static INT_PTR CALLBACK AboutDlgProc(HWND hDlg, UINT msg, WPARAM wp, LPARAM lp);

// Subclass for IDC_PROGRESS_RUN to paint "Completed" over the filled bar once
// a scan finishes. dwRefData == 1 -> overlay enabled.
static LRESULT CALLBACK ProgressOverlayProc(HWND hWnd, UINT msg, WPARAM wp, LPARAM lp,
                                            UINT_PTR uIdSubclass, DWORD_PTR dwRefData) {
    if (msg == WM_NCDESTROY) {
        RemoveWindowSubclass(hWnd, ProgressOverlayProc, uIdSubclass);
        return DefSubclassProc(hWnd, msg, wp, lp);
    }
    if (msg == WM_PAINT && dwRefData) {
        LRESULT r = DefSubclassProc(hWnd, msg, wp, lp);
        HDC hDC = GetDC(hWnd);
        if (hDC) {
            RECT rc; GetClientRect(hWnd, &rc);
            LOGFONTW lf = {};
            lf.lfHeight = -MulDiv(11, GetDeviceCaps(hDC, LOGPIXELSY), 72);
            lf.lfWeight = FW_BOLD;
            wcscpy_s(lf.lfFaceName, L"Segoe UI");
            HFONT hFont = CreateFontIndirectW(&lf);
            HFONT old   = hFont ? (HFONT)SelectObject(hDC, hFont) : nullptr;
            SetBkMode(hDC, TRANSPARENT);
            SetTextColor(hDC, RGB(255, 255, 255));
            DrawTextW(hDC, L"Completed", -1, &rc, DT_CENTER | DT_VCENTER | DT_SINGLELINE);
            if (old) SelectObject(hDC, old);
            if (hFont) DeleteObject(hFont);
            ReleaseDC(hWnd, hDC);
        }
        return r;
    }
    return DefSubclassProc(hWnd, msg, wp, lp);
}

static INT_PTR CALLBACK SettingsDlgProc(HWND hDlg, UINT msg, WPARAM wp, LPARAM lp) {
    static Settings* s = nullptr;
    static RunCtx*   ctx = nullptr;
    static HWND      s_hTooltip = nullptr;
    // Ctrl-to-save: a low-frequency timer polls VK_CONTROL and flips the Run
    // button label between "Run" and "Save" when our dialog has focus.
    static bool      g_runCtrlDown = false;
    static bool      g_closeCtrlDown = false;
    constexpr UINT_PTR kCtrlPollTimerId = 0xAB10;
    constexpr UINT    kCtrlPollMs   = 100;
    static int        s_openOutputFlashTicks = 0;
    constexpr UINT_PTR kFlashTimerId = 0xC002;
    constexpr UINT    kFlashPeriodMs = 180;
    constexpr UINT_PTR kProgressSubclassId = 0xC003;

    switch (msg) {
    case WM_INITDIALOG: {
        // Standalone mode passes a std::pair<Settings*, RunCtx*>* via lParam.
        // Managed mode (xways-xt-manager) creates the embedded dialog with
        // lParam=0 -- fall back to the module-local managed objects.
        if (lp) {
            auto* pair = reinterpret_cast<std::pair<Settings*, RunCtx*>*>(lp);
            s   = pair->first;
            ctx = pair->second;
        } else {
            s   = &g_managed_settings;
            ctx = &g_managed_runctx;
        }
        ApplyTitleIcon(hDlg);
        PopulateDialog(hDlg, s, ctx);
        KillTimer(hDlg, kHelperFlashTimerId);
        g_exeValid         = false;
        g_helperRejected   = false;
        g_helperFlashTicks = 0;
        EnableWindow(GetDlgItem(hDlg, IDC_BTN_RUN), FALSE);
        if (s && !s->toolExe.empty()) {
            SetDlgItemTextW(hDlg, IDC_LABEL_TOOL_VERSION, L"Version: (detecting...)");
            StartAsyncVersionProbe(hDlg, s->toolExe);
        }
        s_hTooltip = CreateAndAttachTooltips(hDlg);
        g_runCtrlDown   = false;
        g_closeCtrlDown = false;
        // Ctrl-to-save: DM_SETDEFID so Enter still triggers Run even with
        // BS_OWNERDRAW (which suppresses the DEFPUSHBUTTON ring).
        SendMessageW(hDlg, DM_SETDEFID, IDC_BTN_RUN, 0);
        SetDlgItemTextW(hDlg, IDC_BTN_RUN, L"Run");
        SetDlgItemTextW(hDlg, IDCANCEL, L"Close");
        for (int id : { IDC_BTN_RUN, (int)IDCANCEL, IDC_BTN_OPEN_OUTPUT,
                        IDC_BTN_ABOUT, IDC_BTN_OPEN_CFG }) {
            HWND h = GetDlgItem(hDlg, id);
            if (h) {
                LONG_PTR style = GetWindowLongPtrW(h, GWL_STYLE);
                SetWindowLongPtrW(h, GWL_STYLE, style | BS_OWNERDRAW);
            }
        }
        HWND hProgInit = GetDlgItem(hDlg, IDC_PROGRESS_RUN);
        if (hProgInit) SetWindowSubclass(hProgInit, ProgressOverlayProc,
                                         kProgressSubclassId, 0);
        s_openOutputFlashTicks = 0;
        SetTimer(hDlg, kCtrlPollTimerId, kCtrlPollMs, nullptr);
        SetFocus(GetDlgItem(hDlg, IDC_BTN_RUN));
        return FALSE;
    }

    case WM_DESTROY: {
        KillTimer(hDlg, kCtrlPollTimerId);
        KillTimer(hDlg, kFlashTimerId);
        KillTimer(hDlg, kHelperFlashTimerId);
        // Drain queued WM_APP_* messages whose payloads we own on the heap.
        ++g_probeToken;
        MSG drainMsg;
        while (PeekMessageW(&drainMsg, hDlg, WM_APP_STATUS, WM_APP_STATUS, PM_REMOVE)) {
            if (drainMsg.lParam) free(reinterpret_cast<wchar_t*>(drainMsg.lParam));
        }
        while (PeekMessageW(&drainMsg, hDlg, WM_APP_VERSION, WM_APP_VERSION, PM_REMOVE)) {
            if (drainMsg.lParam)
                delete reinterpret_cast<VersionProbeResult*>(drainMsg.lParam);
        }
        if (s_hTooltip) { DestroyWindow(s_hTooltip); s_hTooltip = nullptr; }
        return FALSE;
    }

    case WM_CTLCOLORSTATIC: {
        // Recolour ONLY the Version readout when a helper-exe rejection is
        // active. Bright red on even ticks (or settled), dark red on odd ticks.
        if (g_helperRejected) {
            HWND hCtl = (HWND)lp;
            if (hCtl && hCtl == GetDlgItem(hDlg, IDC_LABEL_TOOL_VERSION)) {
                HDC hdc = (HDC)wp;
                bool brightPhase = (g_helperFlashTicks == 0) ||
                                   ((g_helperFlashTicks & 1) == 0);
                SetTextColor(hdc, brightPhase ? RGB(220, 0, 0) : RGB(140, 0, 0));
                SetBkMode(hdc, TRANSPARENT);
                return (INT_PTR)GetSysColorBrush(COLOR_BTNFACE);
            }
        }
        break;
    }

    case WM_TIMER:
        if (wp == kHelperFlashTimerId) {
            if (!g_helperRejected) {
                KillTimer(hDlg, kHelperFlashTimerId);
                return TRUE;
            }
            if (g_helperFlashTicks > 0) {
                --g_helperFlashTicks;
                HWND hVer = GetDlgItem(hDlg, IDC_LABEL_TOOL_VERSION);
                if (hVer) InvalidateRect(hVer, nullptr, TRUE);
                if (g_helperFlashTicks == 0)
                    KillTimer(hDlg, kHelperFlashTimerId);
            }
            return TRUE;
        }
        if (wp == kFlashTimerId) {
            if (s_openOutputFlashTicks > 0) {
                --s_openOutputFlashTicks;
                InvalidateRect(GetDlgItem(hDlg, IDC_BTN_OPEN_OUTPUT), nullptr, TRUE);
                if (s_openOutputFlashTicks == 0) KillTimer(hDlg, kFlashTimerId);
            } else {
                KillTimer(hDlg, kFlashTimerId);
            }
            return TRUE;
        }
        if (wp == kCtrlPollTimerId) {
            bool ctrlDown = (GetKeyState(VK_CONTROL) & 0x8000) != 0;
            if (ctrlDown != g_runCtrlDown) {
                g_runCtrlDown = ctrlDown;
                SetDlgItemTextW(hDlg, IDC_BTN_RUN, ctrlDown ? L"Save" : L"Run");
                InvalidateRect(GetDlgItem(hDlg, IDC_BTN_RUN), nullptr, TRUE);
            }
            // Close flips to "Save as..." only when Ctrl held AND no worker.
            bool closeSaveMode = ctrlDown && (g_workerThread == nullptr);
            if (closeSaveMode != g_closeCtrlDown) {
                g_closeCtrlDown = closeSaveMode;
                SetDlgItemTextW(hDlg, IDCANCEL,
                                closeSaveMode ? L"Save as..." : L"Close");
                InvalidateRect(GetDlgItem(hDlg, IDCANCEL), nullptr, TRUE);
            }
            return TRUE;
        }
        break;

    case WM_DRAWITEM: {
        // Owner-draw for the action buttons. Run/Cancel paint blue in their
        // Ctrl "alternate action" (Save / Save as...) mode; Open output flashes
        // green after a successful scan; About / Open cfg stay plain grey.
        DRAWITEMSTRUCT* dis = (DRAWITEMSTRUCT*)lp;
        const bool isRunBtn        = (dis->CtlID == IDC_BTN_RUN);
        const bool isCancelBtn     = (dis->CtlID == IDCANCEL);
        const bool isOpenOutputBtn = (dis->CtlID == IDC_BTN_OPEN_OUTPUT);
        const bool isAboutBtn      = (dis->CtlID == IDC_BTN_ABOUT);
        const bool isOpenCfgBtn    = (dis->CtlID == IDC_BTN_OPEN_CFG);
        if (!isRunBtn && !isCancelBtn && !isOpenOutputBtn &&
            !isAboutBtn && !isOpenCfgBtn) break;

        bool altMode = (isRunBtn && g_runCtrlDown) ||
                       (isCancelBtn && g_closeCtrlDown);
        bool flashOn = isOpenOutputBtn && (s_openOutputFlashTicks > 0) &&
                       ((s_openOutputFlashTicks & 1) != 0);
        const bool isPressed = (dis->itemState & ODS_SELECTED) != 0;
        const bool isFocus   = (dis->itemState & ODS_FOCUS)    != 0;
        const bool isDisabled= (dis->itemState & ODS_DISABLED) != 0;
        const bool isSave    = altMode;

        COLORREF bg = flashOn ? (isPressed ? RGB(20, 120, 45) : RGB(30, 160, 60))
                  : isSave    ? (isPressed ? RGB(0, 90, 168)  : RGB(0, 120, 215))
                              : GetSysColor(COLOR_BTNFACE);
        COLORREF fg = (flashOn || isSave) ? RGB(255, 255, 255)
                             : (isDisabled ? GetSysColor(COLOR_GRAYTEXT)
                                           : GetSysColor(COLOR_BTNTEXT));

        HBRUSH hbr = CreateSolidBrush(bg);
        FillRect(dis->hDC, &dis->rcItem, hbr);
        DeleteObject(hbr);

        HBRUSH frameBr = CreateSolidBrush(flashOn ? RGB(20, 100, 35)
                                       :  isSave  ? RGB(0, 70, 140)
                                                  : GetSysColor(COLOR_3DSHADOW));
        FrameRect(dis->hDC, &dis->rcItem, frameBr);
        DeleteObject(frameBr);

        if (isFocus) {
            RECT focus = dis->rcItem;
            InflateRect(&focus, -3, -3);
            DrawFocusRect(dis->hDC, &focus);
        }

        wchar_t txt[64] = {0};
        GetWindowTextW(dis->hwndItem, txt, _countof(txt));
        HFONT hFont = (HFONT)SendMessageW(dis->hwndItem, WM_GETFONT, 0, 0);
        HFONT old = hFont ? (HFONT)SelectObject(dis->hDC, hFont) : nullptr;
        SetBkMode(dis->hDC, TRANSPARENT);
        SetTextColor(dis->hDC, fg);
        DrawTextW(dis->hDC, txt, -1, &dis->rcItem,
                  DT_CENTER | DT_VCENTER | DT_SINGLELINE);
        if (old) SelectObject(dis->hDC, old);
        return TRUE;
    }

    case WM_COMMAND: {
        const WORD id = LOWORD(wp);
        if (id == IDC_BTN_BROWSE_TOOL) {
            wchar_t cur[MAX_PATH] = {0};
            GetDlgItemTextW(hDlg, IDC_EDIT_TOOL_BIN, cur, MAX_PATH);
            std::wstring picked = BrowseForFile(hDlg, cur);
            if (!picked.empty()) {
                SetDlgItemTextW(hDlg, IDC_EDIT_TOOL_BIN, picked.c_str());
                if (s) {
                    s->toolExe = picked;
                    s->toolVersion.clear();  // overwritten by WM_APP_VERSION
                }
                ClearHelperRejection(hDlg);
                g_exeValid = false;
                EnableWindow(GetDlgItem(hDlg, IDC_BTN_RUN), FALSE);
                SetDlgItemTextW(hDlg, IDC_LABEL_TOOL_VERSION, L"Version: (detecting...)");
                StartAsyncVersionProbe(hDlg, picked);
            }
            return TRUE;
        }
        if (id == IDC_BTN_BROWSE_OUTPUT) {
            wchar_t cur[MAX_PATH] = {0};
            GetDlgItemTextW(hDlg, IDC_EDIT_OUTPUT_DIR, cur, MAX_PATH);
            std::wstring picked = BrowseForFolder(hDlg, cur, L"Select output directory");
            if (!picked.empty()) SetDlgItemTextW(hDlg, IDC_EDIT_OUTPUT_DIR, picked.c_str());
            return TRUE;
        }
        if (id == IDC_BTN_ABOUT) {
            DialogBoxParamW(g_hSelf, MAKEINTRESOURCEW(IDD_ABOUT), hDlg, AboutDlgProc, 0);
            return TRUE;
        }
        if (id == IDC_BTN_OPEN_OUTPUT) {
            std::wstring target = g_lastRunDir;
            if (target.empty()) {
                wchar_t buf[MAX_PATH] = {0};
                GetDlgItemTextW(hDlg, IDC_EDIT_OUTPUT_DIR, buf, MAX_PATH);
                target = buf;
            }
            if (!target.empty() && DirExists(target))
                ShellExecuteW(hDlg, L"open", target.c_str(), nullptr, nullptr, SW_SHOWNORMAL);
            else
                MessageBoxW(hDlg, L"No output folder yet -- run a scan first, or set the output directory.",
                            NAME, MB_OK | MB_ICONINFORMATION);
            return TRUE;
        }
        if (id == IDC_BTN_OPEN_CFG) {
            std::wstring cfgPath = GetSelfDirectory() + L"\\" + NAME + L".cfg";
            EnsureCfgExists(cfgPath);
            if (FileExists(cfgPath))
                ShellExecuteW(hDlg, L"open", cfgPath.c_str(), nullptr, nullptr, SW_SHOWNORMAL);
            else
                MessageBoxW(hDlg, L"Could not locate or create the .cfg next to the DLL.",
                            NAME, MB_OK | MB_ICONWARNING);
            return TRUE;
        }
        if (id == IDC_BTN_RUN) {
            if (g_workerThread) return TRUE;  // already running
            if (!s || !ctx) return TRUE;
            if (!ReadDialogToSettings(hDlg, *s)) return TRUE;

            // Save the dialog state to the cfg every click (Run AND Ctrl+Run).
            // EXCEPT: refuse to save when helper-exe is in the rejected state --
            // ShowHelperRejection echoed the rejected path into IDC_EDIT_TOOL_BIN,
            // and persisting THAT path to cfg would poison every later open.
            if (g_helperRejected) {
                Log(L"skipping cfg-save: helper-exe rejected -- pick a valid tool .exe via Browse before saving");
            } else {
                std::wstring cfgPath = GetSelfDirectory() + L"\\" + NAME + L".cfg";
                if (SaveSettingsToCfg(cfgPath, *s)) LogVerbose(L"saved cfg: " + cfgPath);
                else                                Log(L"warning: could not save cfg to " + cfgPath);
            }

            // Ctrl held at click time = "save only, don't run". Read GetKeyState
            // (source of truth), NOT the cached timer state.
            bool ctrlHeld = (GetKeyState(VK_CONTROL) & 0x8000) != 0;
            if (ctrlHeld) {
                SetDlgItemTextW(hDlg, IDC_LABEL_PROGRESS_STATUS,
                                L"Settings saved to cfg. (Ctrl+Run: scan NOT started.)");
                return TRUE;
            }

            s_openOutputFlashTicks = 0;
            KillTimer(hDlg, kFlashTimerId);
            HWND hProgClear = GetDlgItem(hDlg, IDC_PROGRESS_RUN);
            if (hProgClear) {
                SetWindowSubclass(hProgClear, ProgressOverlayProc, kProgressSubclassId, 0);
                InvalidateRect(hProgClear, nullptr, TRUE);
            }
            InvalidateRect(GetDlgItem(hDlg, IDC_BTN_OPEN_OUTPUT), nullptr, TRUE);

            g_worker = new WorkerCtx{};
            g_worker->s    = s;
            g_worker->ctx  = ctx;
            g_worker->hDlg = hDlg;
            SetDialogBusy(hDlg, true);
            SetDlgItemTextW(hDlg, IDC_LABEL_PROGRESS_STATUS, L"Starting...");
            g_workerThread = (HANDLE)_beginthreadex(nullptr, 0, WorkerThread, g_worker, 0, nullptr);
            if (!g_workerThread) {
                MessageBoxW(hDlg, L"Failed to start the scan worker thread.",
                            NAME, MB_OK | MB_ICONERROR);
                delete g_worker; g_worker = nullptr;
                SetDialogBusy(hDlg, false);
            }
            return TRUE;
        }
        if (id == IDCANCEL) {
            // Ctrl+Close = "Save as..." file picker (only when no worker).
            bool ctrlHeld = (GetKeyState(VK_CONTROL) & 0x8000) != 0;
            if (ctrlHeld && !g_workerThread && s && ctx) {
                if (g_helperRejected) {
                    Log(L"Save-as refused: helper-exe rejected -- pick a valid tool .exe via Browse before saving");
                    SetDlgItemTextW(hDlg, IDC_LABEL_PROGRESS_STATUS,
                        L"Save-as refused: pick a valid tool .exe first.");
                    return TRUE;
                }
                if (!ReadDialogToSettings(hDlg, *s)) return TRUE;
                wchar_t fileBuf[MAX_PATH];
                swprintf_s(fileBuf, L"%s.cfg", NAME);
                OPENFILENAMEW ofn = {};
                ofn.lStructSize  = sizeof(ofn);
                ofn.hwndOwner    = hDlg;
                ofn.lpstrFilter  = L"Config Files (*.cfg)\0*.cfg\0All files (*.*)\0*.*\0";
                ofn.nFilterIndex = 1;
                ofn.lpstrFile    = fileBuf;
                ofn.nMaxFile     = MAX_PATH;
                ofn.lpstrTitle   = L"Save settings to...";
                ofn.Flags        = OFN_OVERWRITEPROMPT | OFN_PATHMUSTEXIST | OFN_NOCHANGEDIR;
                ofn.lpstrDefExt  = L"cfg";
                if (!GetSaveFileNameW(&ofn)) return TRUE;  // user cancelled
                bool ok = SaveSettingsToCfg(fileBuf, *s);
                Log(ok ? (L"settings saved via Ctrl+Close (Save as) to: " + std::wstring(fileBuf))
                       : (L"settings save FAILED via Ctrl+Close to: "      + std::wstring(fileBuf)));
                SetDlgItemTextW(hDlg, IDC_LABEL_PROGRESS_STATUS,
                    ok ? L"Settings saved to selected file."
                       : L"Failed to save settings to selected file (see Messages).");
                if (ok) EndDialog(hDlg, IDCANCEL);
                return TRUE;
            }

            if (g_workerThread && g_worker) {
                if (!g_worker->cancelRequested.load()) {
                    g_worker->cancelRequested.store(true);
                    SetDlgItemTextW(hDlg, IDC_LABEL_PROGRESS_STATUS, L"Cancelling...");
                    return TRUE;
                }
            }
            EndDialog(hDlg, IDCANCEL);
            return TRUE;
        }
        return FALSE;
    }

    case WM_APP_PROGRESS: {
        HWND hProg = GetDlgItem(hDlg, IDC_PROGRESS_RUN);
        SendMessageW(hProg, PBM_SETPOS, (WPARAM)(int)wp, 0);
        return TRUE;
    }
    case WM_APP_STATUS: {
        auto* txt = (wchar_t*)lp;
        if (txt) {
            SetDlgItemTextW(hDlg, IDC_LABEL_PROGRESS_STATUS, txt);
            free(txt);
        }
        return TRUE;
    }
    case WM_APP_MARQUEE: {
        HWND hProg = GetDlgItem(hDlg, IDC_PROGRESS_RUN);
        LONG_PTR style = GetWindowLongPtrW(hProg, GWL_STYLE);
        if (wp) {
            SetWindowLongPtrW(hProg, GWL_STYLE, style | PBS_MARQUEE);
            SendMessageW(hProg, PBM_SETMARQUEE, TRUE, 30);
        } else {
            SendMessageW(hProg, PBM_SETMARQUEE, FALSE, 0);
            SetWindowLongPtrW(hProg, GWL_STYLE, style & ~PBS_MARQUEE);
        }
        return TRUE;
    }
    case WM_APP_DONE: {
        if (g_workerThread) {
            WaitForSingleObject(g_workerThread, INFINITE);
            CloseHandle(g_workerThread);
            g_workerThread = nullptr;
        }
        delete g_worker; g_worker = nullptr;
        SetDialogBusy(hDlg, false);
        HWND hOpenOutput = GetDlgItem(hDlg, IDC_BTN_OPEN_OUTPUT);
        EnableWindow(hOpenOutput, TRUE);
        if (wp == 1) {
            s_openOutputFlashTicks = 8;  // ~1.4s at 180ms/tick
            SetTimer(hDlg, kFlashTimerId, kFlashPeriodMs, nullptr);
            InvalidateRect(hOpenOutput, nullptr, TRUE);
            HWND hProg = GetDlgItem(hDlg, IDC_PROGRESS_RUN);
            if (hProg) {
                SetWindowSubclass(hProg, ProgressOverlayProc, kProgressSubclassId, 1);
                InvalidateRect(hProg, nullptr, TRUE);
            }
        }
        return TRUE;
    }
    case WM_APP_VERSION: {
        VersionProbeResult* result = reinterpret_cast<VersionProbeResult*>(lp);
        if (!result) return TRUE;
        // Discard stale results (rapid-Browse race).
        if (result->token != g_probeToken.load()) {
            delete result;
            return TRUE;
        }
        if (s) s->toolVersion = result->versionLine;
        if (result->valid) {
            ClearHelperRejection(hDlg);
            std::wstring label = L"Version: " + (result->versionLine.empty()
                                                  ? std::wstring(L"(detected)")
                                                  : result->versionLine);
            SetDlgItemTextW(hDlg, IDC_LABEL_TOOL_VERSION, label.c_str());
            g_exeValid = true;
            Log(L"helper-exe accepted (" + result->exe + L") -- " + result->detail);
            EnableWindow(GetDlgItem(hDlg, IDC_BTN_RUN), g_workerThread ? FALSE : TRUE);
        } else {
            const wchar_t* label = result->fileExists
                ? kHelperRejectionMessage
                : kHelperMissingMessage;
            ShowHelperRejection(hDlg, result->exe, result->detail, label);
        }
        delete result;
        return TRUE;
    }
    case WM_CLOSE:
        if (g_workerThread && g_worker && !g_worker->cancelRequested.load()) {
            g_worker->cancelRequested.store(true);
            SetDlgItemTextW(hDlg, IDC_LABEL_PROGRESS_STATUS, L"Cancelling...");
            return TRUE;
        }
        EndDialog(hDlg, IDCANCEL);
        return TRUE;
    }
    return FALSE;
}

static INT_PTR CALLBACK AboutDlgProc(HWND hDlg, UINT msg, WPARAM wp, LPARAM) {
    switch (msg) {
    case WM_INITDIALOG: {
        ApplyTitleIcon(hDlg);
        std::wstring title = NAME; title += L"  "; title += VERSION;
        SetDlgItemTextW(hDlg, IDC_ABOUT_TITLE, title.c_str());
        SetDlgItemTextW(hDlg, IDC_ABOUT_AUTHOR, L"Your Name");
        HFONT hBold = EnsureBoldFont(hDlg);
        if (hBold) {
            SendDlgItemMessageW(hDlg, IDC_ABOUT_TITLE,
                                WM_SETFONT, (WPARAM)hBold, TRUE);
            SendDlgItemMessageW(hDlg, IDC_ABOUT_LABEL_AUTHOR_PREFIX,
                                WM_SETFONT, (WPARAM)hBold, TRUE);
        }
        return TRUE;
    }
    case WM_COMMAND: {
        WORD id = LOWORD(wp);
        if (id == IDOK || id == IDCANCEL) {
            EndDialog(hDlg, IDOK);
            return TRUE;
        }
        if (id == IDC_ABOUT_LINK_GITHUB) {
            // TODO: point this at your repo.
            ShellExecuteW(hDlg, L"open",
                L"https://github.com/youruser/my_xtension",
                nullptr, nullptr, SW_SHOWNORMAL);
            return TRUE;
        }
        return FALSE;
    }
    case WM_CLOSE:
        EndDialog(hDlg, IDOK);
        return TRUE;
    }
    return FALSE;
}

// =============================================================================
//  ShowDialogAndRun — top-level entry from XT_Finalize
// =============================================================================
static void ShowDialogAndRun(const Collected& c) {
    Settings s;
    std::wstring cfgPath = GetSelfDirectory() + L"\\" + NAME + L".cfg";
    EnsureCfgExists(cfgPath);
    LoadCfg(cfgPath, s);
    if (s.toolExe.empty()) s.toolExe = ResolveDefaultTool();

    // Output base: default to the current case's <case>\<NAME>. Re-resolve at
    // every dialog open so a cfg-persisted path from a prior case doesn't pin
    // output to the wrong folder when the analyst switches cases. An in-case
    // customization is preserved -- we only override when the cfg value points
    // outside the current case directory.
    {
        std::wstring caseDir = GetCaseRootDir();
        bool cfgForDifferentCase = !caseDir.empty() && !s.outputBase.empty() &&
            (s.outputBase.size() < caseDir.size() ||
             _wcsnicmp(s.outputBase.c_str(), caseDir.c_str(), caseDir.size()) != 0);
        if (s.outputBase.empty() || cfgForDifferentCase) {
            std::wstring src;
            s.outputBase = ResolveDefaultOutputBase(c.hEvidence, src);
        }
    }

    RunCtx ctx;
    ctx.hVolume        = c.hVolume;
    ctx.hEvidence      = c.hEvidence;
    ctx.invocationMode = c.invocationMode;
    ctx.items          = c.items;
    // Pre-classify items so the dialog count matches what we'll actually scan.
    if (XWF_GetItemInformation) {
        for (LONG id : ctx.items) {
            BOOL valid = FALSE;
            LONG flags = (LONG)XWF_GetItemInformation(id, XWF_ITEM_INFO_FLAGS, &valid);
            if (valid && (flags & XWF_ITEM_INFO_FLAG_DIRECTORY)) ++ctx.dirCount;
        }
    }

    if (!ctx.hVolume) {
        MessageBoxW(g_hMainWnd,
            L"This X-Tension needs a volume handle to read item bytes, but X-Ways "
            L"did not provide one. Run it from inside a partition or image "
            L"Directory Browser instead of the Case Root window.",
            NAME, MB_OK | MB_ICONWARNING);
        return;
    }
    if (ctx.items.empty()) {
        MessageBoxW(g_hMainWnd,
            L"No items in scope.\n\nEither nothing was selected, or the active "
            L"X-Ways filter excluded every item in this view.",
            NAME, MB_OK | MB_ICONINFORMATION);
        return;
    }

    std::pair<Settings*, RunCtx*> lp(&s, &ctx);
    DialogBoxParamW(g_hSelf, MAKEINTRESOURCEW(IDD_SETTINGS),
                    g_hMainWnd ? g_hMainWnd : GetActiveWindow(),
                    SettingsDlgProc, (LPARAM)&lp);
}

// =============================================================================
//  Entry points
// =============================================================================
extern "C" {

LONG __stdcall XT_Init(DWORD nVersion, DWORD /*nFlags*/, HWND hMainWnd, void*) {
    g_hMainWnd = hMainWnd;
    INITCOMMONCONTROLSEX icc = {};
    icc.dwSize = sizeof(icc);
    icc.dwICC  = ICC_PROGRESS_CLASS | ICC_STANDARD_CLASSES | ICC_BAR_CLASSES;
    InitCommonControlsEx(&icc);

    int missing = RetrieveFunctionPointers();
    Log(FormatW(L"%s %s \x2014 X-Ways build %.2f, %d missing exports",
                NAME, VERSION, nVersion / 100.0, missing));
    if (missing > 0) {
        Log(L"required XWF_* exports are missing \x2014 refusing to load");
        return -1;
    }
    return 1;
}

LONG __stdcall XT_About(HWND hParentWnd, void*) {
    std::wstring m = NAME; m += L" "; m += VERSION; m += L" \x2014 "; m += DESCRIPTION;
    if (XWF_OutputMessage) XWF_OutputMessage(m.c_str(), 0);
    DialogBoxParamW(g_hSelf, MAKEINTRESOURCEW(IDD_ABOUT),
                    hParentWnd ? hParentWnd : g_hMainWnd, AboutDlgProc, 0);
    return 0;
}

LONG __stdcall XT_Prepare(HANDLE hVolume, HANDLE hEvidence, DWORD nOpType, void*) {
    wchar_t volName[260] = {0};
    if (hVolume && XWF_GetVolumeName) XWF_GetVolumeName(hVolume, volName, 0);
    Log(FormatW(L"XT_Prepare op=%lu volume=%s", (unsigned long)nOpType,
                volName[0] ? volName : L"(none)"));

    g_collected = Collected{};
    g_collected.ready          = true;
    g_collected.hVolume        = hVolume;
    g_collected.hEvidence      = hEvidence;
    g_collected.invocationMode = (nOpType == XT_ACTION_DBC)
        ? InvocationMode::Selection : InvocationMode::Run;
    return 0x01;  // request XT_ProcessItem callbacks
}

LONG __stdcall XT_ProcessItem(LONG nItemID, void*) {
    if (!g_collected.ready) return 0;
    g_collected.items.push_back(nItemID);

    // Every 1024 items, reset Windows' "Not Responding" timer (PeekMessage
    // PM_NOREMOVE) and check XWF_ShouldStop so a long enumeration stays
    // survivable + cancellable. Returning negative tells X-Ways to stop calling
    // us; XT_Finalize still fires but skips the dialog when aborted.
    if ((g_collected.items.size() & 0x3FF) == 0) {
        MSG msg;
        PeekMessageW(&msg, nullptr, 0, 0, PM_NOREMOVE);
        if (XWF_ShouldStop && XWF_ShouldStop()) {
            g_collected.aborted = true;
            Log(FormatW(L"enumeration aborted by user after %zu item(s)",
                        g_collected.items.size()));
            return -1;
        }
    }
    return 0;
}

LONG __stdcall XT_ProcessItemEx(LONG, HANDLE, void*) { return 0; }
LONG __stdcall XT_ProcessSearchHit(void*) { return 0; }

LONG __stdcall XT_Finalize(HANDLE, HANDLE, DWORD, void*) {
    if (g_collected.ready) {
        if (g_collected.aborted) {
            Log(L"skipping dialog: enumeration was aborted before completion");
        } else {
            ShowDialogAndRun(g_collected);
        }
        g_collected = Collected{};
    }
    return 0;
}

LONG __stdcall XT_Done(void*) { Log(L"XT_Done"); return 0; }

} // extern "C"

// =============================================================================
//  Manager-plugin integration (xways-xt-manager)
// =============================================================================
//   Lets the SAME DLL load as a plugin under xways-xt-manager. The manager
//   finds us via the XwaysManagerPluginEntry export below. The On* callbacks
//   delegate to the EXISTING standalone internals -- managed mode never shows
//   the modal settings dialog; the embedded tab the manager hosts handles
//   settings, and WrapperHarvestSettings reads them back.
//
//   on_finalize (not on_prepare) runs the scan because the filter-respected
//   item set only exists after every on_process_item completes. The scan runs
//   SYNCHRONOUSLY on the manager's thread with hDlg=NULL (every Post*() is a
//   guarded no-op when hDlg is NULL; logs stream to the Messages window).

#include "manager-plugin.h"

static bool __stdcall WrapperOnInit(HMODULE, HWND hMainWnd, void*) {
    g_hMainWnd = hMainWnd;

    INITCOMMONCONTROLSEX icc = {};
    icc.dwSize = sizeof(icc);
    icc.dwICC  = ICC_PROGRESS_CLASS | ICC_STANDARD_CLASSES | ICC_BAR_CLASSES;
    InitCommonControlsEx(&icc);

    int missing = RetrieveFunctionPointers();
    Log(FormatW(L"%s %s \x2014 managed mode via xways-xt-manager (%d missing exports)",
                NAME, VERSION, missing));
    if (missing > 0) {
        Log(L"required XWF_* exports missing \x2014 plugin disabled");
        return false;
    }

    g_managed_mode = true;
    std::wstring cfgPath = GetSelfDirectory() + L"\\" + NAME + L".cfg";
    EnsureCfgExists(cfgPath);
    LoadCfg(cfgPath, g_managed_settings);
    if (g_managed_settings.toolExe.empty())
        g_managed_settings.toolExe = ResolveDefaultTool();
    g_managed_runctx = RunCtx{};
    return true;
}

static void __stdcall WrapperHarvestSettings(HWND hEmbeddedDlg, void*) {
    if (!hEmbeddedDlg) return;
    wchar_t buf[1024] = {0};
    GetDlgItemTextW(hEmbeddedDlg, IDC_EDIT_TOOL_BIN, buf, _countof(buf));
    g_managed_settings.toolExe = TrimW(buf);

    // ReadDialogToSettings's only early-out is the exe-existence gate. When the
    // exe IS valid it reads every field; when it's not, avoid the modal by
    // reading the non-exe fields directly.
    if (!g_managed_settings.toolExe.empty() && FileExists(g_managed_settings.toolExe)) {
        ReadDialogToSettings(hEmbeddedDlg, g_managed_settings);
    } else {
        GetDlgItemTextW(hEmbeddedDlg, IDC_EDIT_OUTPUT_DIR, buf, _countof(buf));
        g_managed_settings.outputBase = TrimW(buf);
        GetDlgItemTextW(hEmbeddedDlg, IDC_EDIT_MIN_SIZE, buf, _countof(buf));
        g_managed_settings.minSizeBytes = ParseInt64(buf, 1);
        if (g_managed_settings.minSizeBytes < 0) g_managed_settings.minSizeBytes = 0;
        GetDlgItemTextW(hEmbeddedDlg, IDC_EDIT_MAX_SIZE, buf, _countof(buf));
        g_managed_settings.maxSizeMiB = ParseInt64(buf, 256);
        if (g_managed_settings.maxSizeMiB < 0) g_managed_settings.maxSizeMiB = 0;
        GetDlgItemTextW(hEmbeddedDlg, IDC_EDIT_EXTRA_ARGS, buf, _countof(buf));
        g_managed_settings.extraArgs = TrimW(buf);
        g_managed_settings.verbose =
            IsDlgButtonChecked(hEmbeddedDlg, IDC_CHK_VERBOSE) == BST_CHECKED;
    }

    std::wstring cfgPath = GetSelfDirectory() + L"\\" + NAME + L".cfg";
    if (!SaveSettingsToCfg(cfgPath, g_managed_settings))
        Log(L"warning: could not save cfg from managed harvest to " + cfgPath);
}

static bool __stdcall WrapperOnPrepare(HANDLE hVolume, HANDLE hEvidence,
                                       DWORD nOpType, void*) {
    g_managed_collected = Collected{};
    g_managed_collected.ready          = true;
    g_managed_collected.hVolume        = hVolume;
    g_managed_collected.hEvidence      = hEvidence;
    g_managed_collected.invocationMode = (nOpType == XT_ACTION_DBC)
        ? InvocationMode::Selection : InvocationMode::Run;
    wchar_t volName[260] = {0};
    if (hVolume && XWF_GetVolumeName) XWF_GetVolumeName(hVolume, volName, 0);
    Log(FormatW(L"managed OnPrepare op=%lu volume=%s", (unsigned long)nOpType,
                volName[0] ? volName : L"(none)"));
    return true;
}

static LONG __stdcall WrapperOnProcessItem(LONG nItemID, HANDLE, void*) {
    if (!g_managed_collected.ready) return 0;
    g_managed_collected.items.push_back(nItemID);
    return 0;
}

static bool __stdcall WrapperOnFinalize(HANDLE hVolume, HANDLE hEvidence,
                                        DWORD /*nOpType*/, void*) {
    if (!g_managed_collected.ready) return true;

    Settings s = g_managed_settings;
    if (s.toolExe.empty()) s.toolExe = ResolveDefaultTool();
    if (s.toolExe.empty() || !FileExists(s.toolExe)) {
        Log(L"tool .exe not found \x2014 set 'tool_exe' in the cfg or the tab, "
            L"or drop the .exe next to the DLL");
        g_managed_collected = Collected{};
        return false;
    }
    // Helper-exe identity gate (no dialog to flash in managed mode).
    {
        std::wstring versionLine, detail;
        bool ok = VerifyHelperIdentity(s.toolExe, kHelperIdentityNeedle,
                                       versionLine, detail);
        if (!ok) {
            Log(L"helper-exe REJECTED (" + s.toolExe + L") -- " + detail +
                L" -- refusing to run");
            g_managed_collected = Collected{};
            return false;
        }
        Log(L"helper-exe accepted (" + s.toolExe + L") -- " + detail);
        s.toolVersion = versionLine;
    }

    // Output base: default to <case>\<NAME> (same logic as ShowDialogAndRun).
    {
        std::wstring caseDir = GetCaseRootDir();
        bool cfgForDifferentCase = !caseDir.empty() && !s.outputBase.empty() &&
            (s.outputBase.size() < caseDir.size() ||
             _wcsnicmp(s.outputBase.c_str(), caseDir.c_str(), caseDir.size()) != 0);
        if (s.outputBase.empty() || cfgForDifferentCase) {
            std::wstring src;
            s.outputBase = ResolveDefaultOutputBase(hEvidence, src);
        }
    }

    RunCtx ctx;
    ctx.hVolume        = hVolume ? hVolume : g_managed_collected.hVolume;
    ctx.hEvidence      = hEvidence ? hEvidence : g_managed_collected.hEvidence;
    ctx.invocationMode = g_managed_collected.invocationMode;
    ctx.items          = g_managed_collected.items;

    if (!ctx.hVolume) {
        Log(L"managed run needs a volume handle to read item bytes (Case Root "
            L"window?). Run inside a partition / image instead.");
        g_managed_collected = Collected{};
        return false;
    }
    if (ctx.items.empty()) {
        Log(L"managed run: no items in scope");
        g_managed_collected = Collected{};
        return true;
    }

    Log(FormatW(L"managed run: scanning %zu item(s)", ctx.items.size()));

    // Run the worker SYNCHRONOUSLY on this (manager) thread. hDlg=NULL routes
    // every Post*/PostMessageW to a no-op; WorkerThread does not self-join or
    // touch g_worker/g_workerThread, so a local WorkerCtx is self-contained.
    WorkerCtx w;
    w.s    = &s;
    w.ctx  = &ctx;
    w.hDlg = nullptr;
    WorkerThread(&w);

    g_managed_collected = Collected{};
    return true;
}

extern "C" __declspec(dllexport)
const XwaysManagerPluginDescriptor* __stdcall XwaysManagerPluginEntry(void) {
    static const XwaysManagerPluginDescriptor desc = {
        XWAYS_MANAGER_PLUGIN_ABI_VERSION,
        sizeof(XwaysManagerPluginDescriptor),

        NAME,                       // id
        L"My X-Tension",            // display_name (TODO: friendly tab caption)
        DESCRIPTION,                // description
        VERSION,

        IDD_SETTINGS,   // tab_dialog_resource_id (Option A — manager retrofits styles)
        0,              // tab_dialog_embedded_resource_id (Option B; 0 = Option A)
        SettingsDlgProc,

        WrapperOnInit,
        WrapperOnPrepare,
        WrapperOnProcessItem,    // on_process_item: collect item IDs
        nullptr,                 // on_process_item_ex: not used
        WrapperOnFinalize,       // batch scan runs here

        true,           // default_enabled
        nullptr,        // reserved

        // -------- Post-v1 additive fields --------
        WrapperHarvestSettings
    };
    return &desc;
}

BOOL APIENTRY DllMain(HMODULE hModule, DWORD reason, LPVOID) {
    if (reason == DLL_PROCESS_ATTACH) g_hSelf = hModule;
    return TRUE;
}
