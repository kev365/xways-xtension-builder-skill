---
source: synthesized from working CLI-wrapper X-Tension implementations (see exemplars.md)
type: project-pattern
fetched: 2026-05-02
last_updated: 2026-05-02
author: project notes
---

# Wrapping External CLI Tools as X-Tensions

Pattern guide for X-Tensions that wrap a third-party command-line tool (e.g. `yara`, `bulk_extractor`). Captures the design decisions and hard constraints every wrapper hits.

Reference implementation: the `wrapper` template (`templates/x-tensions/wrapper/`) — subprocess spawn + Win32 settings dialog + report-table tagging, with the CLI-wrapper anatomy already wired in. See [Wrapper anatomy](conventions/wrapper-anatomy.md).

## 1. Getting bytes to the tool — extraction is required

**The fundamental constraint:** X-Tension APIs and external CLI tools live in separate worlds and don't share file handles.

- `XWF_OpenItem(hVolume, itemID, ...)` returns an X-Ways HANDLE that's only readable via `XWF_Read(hItem, offset, buf, len)`. It's **not a Win32 file handle** — `ReadFile` against it will fail. The HANDLE means nothing outside the X-Ways process.
- External CLI tools want a real on-disk path. `bulk_extractor`, `yara` — all expect filesystem paths.
- Even tools that accept stdin (rare) typically can't seek, which most forensic tools require for non-trivial parsing.

**Therefore:** if the X-Tension wants to feed in-snapshot items to an external tool, it must **export each item to disk first** (via `XWF_OpenItem` + `XWF_Read` → `WriteFile`), then pass the temp dir to the tool. There is no clever workaround.

### Alternatives that don't work (and why)

| Alternative | Why it doesn't work |
| --- | --- |
| Pass `XWF_OpenItem` HANDLE to the child process | It's an X-Ways internal handle, not a Win32 handle |
| Pipe item bytes via stdin | Most tools don't support stdin; pipes can't seek |
| Loop-mount the source image | Loses carved/recovered/slack items that X-Ways' parsing surfaces but the OS mount can't see |
| Userspace FUSE-like filesystem (Dokan/WinFsp) | Driver dependency, complex install, performance hit, not transparent — overkill for the value |
| Have the tool read directly from the image | Works if the tool understands the image format AND you want to scan the whole image (loses per-item semantics) |

The "scan the whole image" alternative is genuinely useful for tools that natively understand `.E01`/`.dd` (which `bulk_extractor` does) — that's why bulk_extractor has an "Active EO source image" mode. But for *selected items*, extraction is the only option.

### `XWF_Mount` / `XWF_Unmount` — viable for some wrappers, not all

X-Ways added `XWF_Mount` / `XWF_Unmount` in v21.1 Beta 2 (2024-03-15) specifically for this problem. X-Ways's guidance: when an X-Tension needs to give external programs read access to many or large files in a volume snapshot, mounting the volume snapshot as a drive letter can be faster than copying those files to a path that is accessible to those external programs. Verify the signatures and constraints against the live API HTML / your locally-acquired SDK header (see getting-the-sdk.md).

**When it's a clean win** — wrappers around tools that accept **a single file/directory path** and walk it. The whole ExtractSelected → WriteFile → ingest → cleanup machinery collapses into "Mount → run tool on the resolved snapshot path → Unmount." Candidates: tools that take a single profile/source directory, `yara` per-file, or a tool that runs on a memory artifact at a known path.

**When extraction still wins** — wrappers around tools that scan whole streams or whole directory trees without per-file targeting:

- `bulk_extractor` is the canonical "weak fit" case. BE's `-R` (recursive) scans every file under the mount point — pointing it at a mounted whole snapshot scans everything, including items the analyst did *not* select. To restore selection semantics you'd have to invoke BE per-file (loses BE's parallel scanning) or filter post-hoc by path (loses the `xwitem_<itemID>_` ID-embedding convention because BE's output references mount paths, not item IDs). Net: the export pattern's selection fidelity + ID-mapping outweighs the WriteFile cost.

**Hard constraint to plan around** — currently **only one mount point can exist at a time** system-wide. Any Mount-using X-Tension should defensively `XWF_Unmount(NULL)` first to clear leftovers, and must always pair its own Mount with an Unmount (try/finally-equivalent) so a crash doesn't strand a drive letter.

**Unverified behaviors — confirm before relying on Mount**: do carved / recovered / slack items appear in the mount? What is the mount lifetime (case-scoped, process-scoped)? Is it read-only?

### Mapping output back to source item IDs

Once you've extracted N items into a temp dir, the tool's output references the temp file paths. To map findings back to X-Ways item IDs:

1. **Embed the item ID in the temp filename.** Convention used by bulk_extractor: `xwitem_<itemID>_<sanitized_leaf>.bin`. Pick a token unlikely to collide with real content (`xwitem_` is good).
2. **Walk the tool's output.** Search every output line for the token, parse the digits after it, look up in a `unordered_map<LONG, ...>` you built at export time.
3. **Tag matched items** via `XWF_AddToReportTable(itemID, table_name, 0)`.

A wrapper around a tool with structured output can do the equivalent with a `source_file` column lookup in the tool's SQLite/CSV output. bulk_extractor does it with text-grep through `*.txt` feature files.

## 2. Tool binary deployment

X-Tensions ship the wrapped tool's binary alongside the DLL so analysts get a drop-in experience.

### Layout convention

```text
xtensions\                                  <- copied verbatim into <X-Ways install>\xtensions\
├── <xtension>.dll
├── <xtension>.cfg                          (optional sidecar — not committed; see .gitignore)
└── <xtension>\                             (subdir for bundled binaries; only used by big bundles)
    └── <tool>.exe
```

For X-Tensions bundling one helper, drop both files into the same per-tension subfolder under `xtensions\` — e.g. `xways-mytool` shipping `mytool.exe` next to `xways-mytool.dll`. For X-Tensions whose binary is large or has accompanying files, the same per-tension subfolder layout applies — see `xways-bulk_extractor` shipping `bulk_extractor64.exe` in `xtensions\xways-bulk_extractor\`.

### Path resolution chain (highest wins)

1. **Dialog field** — analyst overrides the path per-run.
2. **Sidecar `.cfg`** — `tool_binary=...` for persistent overrides (e.g., the analyst keeps a newer version somewhere else).
3. **Bundled default** — `<dll_dir>\<tool_subdir>\<tool>.exe` discovered via `GetModuleFileNameW(g_hSelf)` + relative path.

Fall back if a layer is empty/non-existent. Always log the chosen path so the analyst can debug.

### Why bundled, not "install separately"

Forensic shops have many analysts on many workstations. "Drop these files in xtensions\" is a much lower friction install than "first install Tool X, then point at it." It also pins the version — reruns 6 months later produce comparable output.

### Future-proofing

Make a newer tool version a drop-in replacement: same filename, same expected CLI flags. If flags change (e.g., bulk_extractor 1.x → 2.x had renames), version-check the binary in `XT_Init` and refuse to run on incompatible versions.

## 3. Subprocess invocation

Three flavors with different ergonomics:

### a) `CREATE_NEW_CONSOLE` (simplest; used by xways-bulk_extractor)

```cpp
CreateProcessW(nullptr, cmdline.data(), nullptr, nullptr, FALSE,
               CREATE_NEW_CONSOLE, nullptr, working_dir, &si, &pi);
WaitForSingleObject(pi.hProcess, INFINITE);
```

Pros: zero plumbing, analyst sees real-time tool output in a console window. Cons: extra window, no in-DLL cancel (analyst has to kill the console or the process).

### b) `CREATE_NO_WINDOW` + redirect stderr to a log file

```cpp
HANDLE hLog = CreateFileW(logPath, GENERIC_WRITE, ...);
si.hStdError = hLog;
si.hStdOutput = hLog;
si.dwFlags = STARTF_USESTDHANDLES;
CreateProcessW(..., CREATE_NO_WINDOW, ...);
```

Pros: no popup. Cons: silent during run; analyst has to tail the log to see progress.

### c) `CREATE_NO_WINDOW` + pipe stderr to worker thread + modeless progress dialog

The "real" answer for long-running tools. Worker thread reads pipe, drops latest progress line into a thread-safe queue, main thread pumps it into a Win32 progress dialog. Cancel button calls `TerminateProcess`. ~150 lines of correct Win32 code. Worth doing for any X-Tension where the tool runs > a few minutes.

## 4. Output integration

Three patterns, often combined.

### Add the output as a Directory-typed evidence object

```cpp
HANDLE h = XWF_CreateEvObj(/*nType=*/3, 0, outputDir.data(), nullptr);
```

`nType` values (per the live API page, not in the header):

- `0` = single file
- `1` = image
- `2` = memory dump
- `3` = directory  ← what you usually want for tool output
- `4` = physical disk

This lets X-Ways index the output files (text-format feature files, CSVs, JSONs) so the analyst can search them with the same UI they use for the rest of the case.

### Open the output folder in Explorer

```cpp
ShellExecuteW(nullptr, L"open", outputDir.c_str(), nullptr, nullptr, SW_SHOWNORMAL);
```

Trivial. Useful when the tool produces files that aren't worth indexing (binaries, huge SQLite DBs).

### Tag source items via Report Tables

Two flavors:

- **"Scanned" tag** — apply at export time to every item successfully fed to the tool. Audit trail of what was run. Free (one `XWF_AddToReportTable` call per export).
- **"Hits" tag** — applied post-run, only to items the tool found something in. Walk output files for the embedded `xwitem_<itemID>_` tokens, dedupe IDs, tag. The actionable subset.

bulk_extractor does both as separate report tables (`bulk_extractor scanned`, `bulk_extractor hits`). A wrapper around a tool that always produces output for valid input might only do "scanned" — there's no "hit" / "miss" distinction.

## 5. Default conventions for new wrappers

Recommended defaults for every new wrapper — start with all of them and adjust as needed:

| Pattern | Where it lives | Why |
| --- | --- | --- |
| `static constexpr bool VERBOSE = true;` + `Log` / `LogVerbose` helpers | Top of `.cpp` | Debug-friendly during development; flip to `false` before sharing |
| Capture `g_hSelf` in `DllMain` on `DLL_PROCESS_ATTACH` | `.cpp` bottom | Resolves sidecar/binary paths via `GetModuleFileNameW(g_hSelf)` |
| Capture `g_hMainWnd` in `XT_Init` | `.cpp` entry points | Parent for any Win32 dialogs |
| Honor `XT_INIT_QUICKCHECK` (return 1) | `XT_Init` | Required by X-Ways probing protocol |
| Refuse to load if required exports missing | `XT_Init` | Returns -1 — better than silently failing later |
| Temp dir under `XWF_GetEvObjProp(hEvidence, 12, ...)` | helper | Honors analyst's General Options → Folders setting |
| Sidecar `.cfg` parsing (key=value, `#` comments) | helper | Config persistence without re-prompting |
| Path resolution chain (dialog > cfg > bundled) | helper | Drop-in deployment with per-shop overrides |
| Item ID embedding in temp filenames | helper | Maps tool output back to X-Ways items |
| Programmatic checkbox creation in `WM_INITDIALOG` for variable-length lists | dialog proc | Avoids 35-line `.rc` bloat; trivial to add/remove items |
| `XWF_AddToReportTable(id, table_name, 0)` for tagging | post-processing | Standard X-Ways UI affordance for marking findings |
| `XWF_CreateEvObj(3, 0, dir, nullptr)` to add output as directory | post-processing | Lets X-Ways index tool output |
| `.gitignore` un-ignore for the X-Tension's `xtensions/` bundle dir | repo root | Bundle is committed by convention; `*.dll` is gitignored globally |

## 6. When NOT to use this pattern

- **The tool is a Python library.** Just embed Python via the `XT_Python` bridge — no subprocess, no extraction, no temp files.
- **The tool is a small algorithm.** Port it to C++ in the X-Tension. CrowdStrike's YARA scanner does this — runs YARA in-process against `XWF_Read` bytes, no extraction needed.
- **Bytes flow X-Ways → Tool → X-Ways with no other side effects.** Consider whether `XT_ProcessItemEx` + an in-process call is cleaner.

The "wrap an external CLI" pattern shines when the tool is mature, third-party, written in something other than C++, and produces structured output worth ingesting. That's a lot of useful tools.

## See also

- [xtension-invocation.md](xtension-invocation.md) — entry points, action codes, threading.
- [xways-getprop-reference.md](xways-getprop-reference.md) — property numbers (12 = working dir, 9 = source notation).
- [xways-user-input-and-dialogs.md](xways-user-input-and-dialogs.md) — Win32 dialog patterns.
- [build-and-iteration-gotchas.md](build-and-iteration-gotchas.md) — encoding traps, DLL locking, build env.
