---
source: https://www.x-ways.net/forensics/x-tensions/Image_IO_API.html (doc last updated 2017-10-17); demo source https://www.x-ways.net/forensics/x-tensions/IIO.zip (Delphi, 2017-10-10)
type: api-reference
fetched: 2026-05-13
last_updated: 2026-05-13
author: project notes
---

# X-Ways Image I/O API

A **separate API class** from the [X-Tensions API](xtension-invocation.md). Adds support for additional **physical sector-wise disk image** formats to X-Ways Forensics / Investigator / WinHex Lab Edition. Available since v19.5 (2017-10-11).

Three exported functions, no version handshake, no `XT_*` lifecycle. The DLL stays loaded for the X-Ways session and is invoked whenever X-Ways considers a file as a potential image.

**Local copies:**

- API page: the official Image I/O API page at <https://www.x-ways.net/forensics/x-tensions/Image_IO_API.html>
- Demo zip (Delphi source + 32-bit + 64-bit demo DLL): the official `IIO.zip` from <https://www.x-ways.net/forensics/x-tensions/> (see [getting-the-sdk.md](getting-the-sdk.md))

## When to use it (and when not to)

**Use it** when X-Ways doesn't natively understand the image format you have and you want analysts to be able to add such images to a case the normal way (Tools → Add Image, drag-and-drop, etc.). Candidate applications: an `e01-rs`-backed fallback, or `vmdk-rs`-backed VMware support.

**Don't use it** for logical collections of files — that's what the X-Tensions API is for. Image I/O is strictly for **sector-wise** physical-storage images: take an offset, give back sector bytes. No filesystem awareness.

## Deployment (different from X-Tensions)

- **DLL filename must match the mask `Image*.dll`** — X-Ways scans the install dir for that exact prefix. Suggested form per the docs: `ImageIO XYZ.dll` where XYZ is the extension you handle.
- **64-bit DLLs go in the `\x64\` subdirectory** of the X-Ways install dir — *not* the root, and *not* under `xtensions\`. Empirically confirmed against xwb 21.7 SR-3 (2026-05-14): a 64-bit `Image*.dll` placed in the install root was silently ignored; the same DLL placed in `<install>\x64\` was found and loaded.
- **Up to two `Image*.dll` plugins total** are supported in the install directory.
- The DLL **stays loaded** for the X-Ways session — there is no unload mid-session.
- Sibling DLLs in the same directory are resolved via the "alternate search path" strategy (same as X-Tensions per v20.8 Beta 3).
- **Explicit per-DLL consent prompt** — contrary to the API docs' "implicit consent by file placement" claim, X-Ways actually surfaces a `"The script or DLL "<name>" is about to be executed"` modal the **first time the DLL is consulted in a session**. Includes a "Do not display this message again" checkbox. Empirically confirmed (2026-05-14) that the OK answer is remembered for the rest of that X-Ways session — a second Add-Image gesture in the same session does not re-prompt. Whether the "Do not display" tick persists across X-Ways restarts, and where that allow-list is stored, is still open.

## Three required exports

All three are exported with **undecorated names** (use `extern "C" __declspec(dllexport)` or a `.def` file). All use `__stdcall` under 32-bit; 64-bit has only one calling convention so the keyword is harmless. **All functions must be thread-safe** — the docs treat that as a hard requirement.

### `IIO_Init` — claim or decline an image

```cpp
PVOID __stdcall IIO_Init(
    HANDLE hMainWnd,           // X-Ways main window — parent for any dialog you raise
    LPWSTR lpFilePath,         // UTF-16 path of the file X-Ways is considering
    PVOID  pHeaderBuf,         // first nHeaderBufSize bytes of the file
    DWORD  nHeaderBufSize,     // size of pHeaderBuf
    struct ImageInfo* pImgInfo, // OUT — caller pre-zeroes everything except nSize
    PVOID  pReserved           // unused per the docs & demo
);

#pragma pack(push, 2)
struct ImageInfo {
    DWORD nSize;            // preset by caller; you MUST overwrite with sizeof(ImageInfo) you support
    INT64 nSectorCount;
    DWORD nSectorSize;      // 512 / 1024 / 2048 / 4096 / 8192 are the currently supported sizes
    DWORD nFlags;           // IIO_INIT_* bitmask — see below
    LPWSTR lpTextualDescr;  // optional UTF-16 string; caller frees via IIO_Done
};
#pragma pack(pop)
```

**Decision protocol:**

1. Inspect `lpFilePath` (extension, basename) and/or `pHeaderBuf` (signature bytes).
2. **Decline** by returning `NULL`. X-Ways will ignore your `pImgInfo` output and try its own parsers (or any other `Image*.dll`).
3. **Claim** by returning a non-NULL pointer to a private opaque struct of your choosing. X-Ways treats this as a black-box handle and passes it back to `IIO_Work` / `IIO_Done`. Also fill `*pImgInfo` to describe the image.

**Sizes you'll need to set in `pImgInfo`:**

- `nSize` ← **must overwrite** with `sizeof(ImageInfo)` *that you support* — currently `4+8+4+4+8 = 28` bytes on x64 (`4+8+4+4+4 = 24` on x86). X-Ways may extend the struct in future versions; setting `nSize` is how you tell the caller which fields you've populated. The caller only reads up to the size you declare.
- `nSectorCount` × `nSectorSize` = total image size in bytes.
- `nSectorSize` ∈ {512, 1024, 2048, 4096, 8192}.

**`nFlags` bits** (from the doc + demo source):

| Bit | Symbol | Meaning |
| ---: | --- | --- |
| `0x0001` | `IIO_INIT_READ` | You support reads (set this) |
| `0x0002` | `IIO_INIT_WRITE` | You support writes — rare; only for tooling that legitimately edits images |
| `0x0010` | `IIO_INIT_DISK` | Image is a physical storage device, possibly partitioned |
| `0x0020` | `IIO_INIT_VOLUME` | Image is a single volume/partition |
| `0x0100` | `IIO_INIT_THREADSAFE` | Your functions are thread-safe — doc says "currently a must"; demo curiously omits it |
| `0x0200` | `IIO_INIT_UNALIGNED_OK` | You handle sector-unaligned I/O — optional |
| `0x1000` | `IIO_INIT_ERROR_MILD` | Image errors detected but image is still fully readable |
| `0x2000` | `IIO_INIT_ERROR_SEVERE` | Image errors detected; cannot be fully read |
| `0x4000` | `IIO_INIT_ERROR_GIVE_UP` | Type supported but this file is unopenable; `lpTextualDescr` carries the error message; X-Ways will not try other DLLs/parsers for this file |

It's fine to set **neither** `IIO_INIT_DISK` **nor** `IIO_INIT_VOLUME` if you don't know — X-Ways will then make its own determination or prompt the analyst.

**`lpTextualDescr`** is an optional UTF-16 string with metadata about the image (creator, tool, compression, etc.). Allocate it however you like (`HeapAlloc`, `LocalAlloc`, `new wchar_t[N]`, …) — but **the caller frees it via `IIO_Done`**, so use a matching allocator across init+done.

**Side-channel: dialogs.** `hMainWnd` is the parent handle for any UI you want to raise during init (credential prompt, format-variant picker, etc.). Demo source uses `MessageBoxW(hMainWnd, ...)` for this.

**File-handle hygiene:** if you open a `HANDLE` to the underlying file, use a **sharing mode** (e.g., `FILE_SHARE_READ`), not exclusive — the docs are explicit about this.

**Recovery path after a bad-shape return:** if you return non-NULL but the caller can't use what you put in `pImgInfo` (unsupported `nSize`, missing `IIO_INIT_READ`, etc.), X-Ways will still call your `IIO_Done` so you can free resources — but it won't call `IIO_Work`. Always treat `IIO_Done` as a guaranteed counterpart to a non-NULL `IIO_Init` return.

### `IIO_Work` — service one read or write request

```cpp
INT64 __stdcall IIO_Work(
    PVOID lpImage,    // your opaque pointer returned from IIO_Init
    INT64 nOfs,       // offset into the image, in bytes
    INT64 nSize,      // bytes to read or write
    PVOID lpBuffer,   // your buffer to fill (read) or read from (write)
    PBYTE pFlags      // see below; both in and out bits
);
```

**Flag byte (`*pFlags`):**

| Bit | Direction | Symbol | Meaning |
| ---: | --- | --- | --- |
| `0x01` | in | `IIO_WRITE` | This is a write, not a read |
| `0x20` | in | `IIO_CHECK_FOR_SPARSE` | Caller wants you to detect sparse ranges |
| `0x40` | out | `IIO_SPARSE_DETECTED` | You're signalling the requested range is entirely sparse |

Return value: **number of bytes actually transferred**. If you set `IIO_SPARSE_DETECTED` (only legal when `IIO_CHECK_FOR_SPARSE` was set), you don't need to populate `lpBuffer` — but still return the requested byte count, since the caller treats the range as "logically zeroed, skip processing."

If you didn't signal write capability in `IIO_Init`, you can ignore `*pFlags` entirely.

### `IIO_Done` — release everything

```cpp
DWORD __stdcall IIO_Done(
    PVOID  lpImage,         // your opaque pointer from IIO_Init
    LPWSTR lpTextualDescr   // the buffer you allocated for ImageInfo.lpTextualDescr
);
```

Free both pointers (your private struct *and* the textual description). Close any file handles. Return `1`.

Per-image: **always** runs once for every non-NULL `IIO_Init` return — even on the bad-shape path where `IIO_Work` was never called.

## Empirical findings (xwb 21.7 SR-3)

Findings collected via observer-only testing (`IIO_Init` always returns NULL), 2026-05-14 to 2026-05-19, across 10 file formats, two-DLL ordering, and case-reopen behaviour.

### Plugin consultation pipeline

X-Ways routes evidence-add and case-reopen through a **two-track** pipeline:

1. **Internally-claimed extensions skip `Image*.dll` entirely.** Confirmed for `.E01`: never observed in the log on either initial Add Image or case-reopen. Likely also true for `.Ex01`, `.AD1`, `.AFF4`, and any other format X-Ways has a built-in image-container parser for. The internal claim happens *before* plugin consultation runs.
2. **Everything else: `Image*.dll` plugins consulted first, internal raw-disk + filesystem parsing falls back on NULL returns.** Confirmed by `image1.001` and `image9.raw` — both received `IIO_Init` calls (the test DLL returned NULL), then X-Ways successfully parsed them as FAT volumes with 309 enumerated items each. For non-internally-claimed formats, plugins get **first crack** at the file.

Practical implication for a real plugin (e.g. `e01-rs`-backed): you'll still never get called on `.E01` because X-Ways has internal support and the internal claim short-circuits the plugin path. Image*.dll plugins are useful for formats X-Ways doesn't recognise internally — flat VMDK, `.aff` v3, `.dmg`, etc.

### Add gestures that trigger IIO

Mapped empirically across one mixed-evidence case:

| Gesture | Calls IIO? | Notes |
| --- | --- | --- |
| Case Data → File → Add Image (file-backed, non-internally-claimed) | ✓ | The primary path. Confirmed for `.001`, `.img`, `.bin`, `.vmdk`, `.vhdx`, `.vhd`, `.aff`, `.raw`, `.dmg`. |
| Case Data → File → **Add Memory Dump** | **✓ (surprising)** | `.mem` goes through the same plugin-consultation pipeline as raw disk images, despite the API docs scoping IIO to "sector-wise disk images." A misbehaving Image*.dll plugin claiming `.mem` could break Add Memory Dump — defensive extension matching is warranted. |
| Case Data → File → Add Image (`.E01`) | ✗ | Internally claimed — see pipeline section above. |
| Case Data → File → Add File (logical file) | ✗ | Confirmed with a `.pst`. |
| Case Data → File → Add Disk (live `\\.\PhysicalDriveN`) | ✗ | No `lpFilePath` to pass — live disks bypass IIO entirely. |
| Case Data → File → Add Directory | ✗ | Not a file. |
| Tools → Open Disk | ✗ | Opens host physical disks / live volumes, not image files. |
| **Case reopen** | ✓ | **Every IIO-eligible file-backed evidence object is re-consulted when the case is opened.** Internally-claimed extensions (`.E01`) and non-IIO-routed objects (logical files, live disks, directories) are skipped on reopen just like on initial Add. **Performance note**: a real plugin doing heavy parsing in `IIO_Init` will slow case-open proportionally to the number of file-backed objects — keep `IIO_Init` cheap and defer real work to `IIO_Work`. |

### Post-IIO denial

`image10.dmg` was consulted via `IIO_Init` and *then* rejected by X-Ways' GUI with a denial dialog — IIO consultation runs **before** whatever validation produces the GUI denial. Implication: a real `dmg-rs`-backed plugin claiming `.dmg` would presumably succeed where X-Ways' native handling fails, since the rejection path runs downstream of plugin consultation. `.dmg` is therefore a good candidate format for a future Image I/O plugin.

### Plugin loader behaviour

- **The `Image*.dll` filename mask is empirically enforced.** Renaming a test DLL to `AImageIOTest.dll` (no `Image` prefix) caused X-Ways to silently ignore the file — no consent prompt, no log file, not loaded. The mask must match literally; the docs are correct on this.
- **`<install>\x64\` is the correct deployment location for 64-bit DLLs.** The install root is not scanned for 64-bit plugins on this build — confirmed empirically 2026-05-14.
- **Per-DLL consent prompt** on the first session-consultation of each fresh DLL. Two new DLLs in one install → two modal prompts at first Add Image. Q3 below covers persistence.
- **Two-DLL cap may be looser than docs claim.** Earlier observations included three `Image*.dll` files in `x64\` and all loaded anyway. Either the cap is higher than two, or the alphabetically-last DLL silently drops. Worth a deliberate test if it matters for deployment guidance.

### Per-call constants (10 observed Add gestures, plus case-reopen sweeps)

| Field | Value | Notes |
| --- | --- | --- |
| `nHeaderBufSize` | `5120` | **Constant** across 10 extensions (`.001`/`.img`/`.bin`/`.vmdk`/`.vhdx`/`.vhd`/`.aff`/`.raw`/`.dmg`/`.mem`). Not adaptive to format or content. |
| `preset_nSize` | `28` | Matches the doc value exactly for x64. No `ImageInfo` struct extension between 2017 and 21.7 SR-3. |
| `pReserved` | `0x0` | Always null. |
| `hMainWnd` | stable per session | Process-local HWND — changes per X-Ways launch but stable within a session. |
| Thread ID | single thread per gesture | All calls within one Add gesture come from the same thread. Whether `IIO_Work` is multi-threaded is still open. |
| Header bytes | raw file content | Across 10 different formats the bytes are byte-0 onward of the file, not pre-processed. (`.dmg` header is zlib-compressed payload; `.mem` header is the NUL page at the bottom of the dump — both are the literal file bytes.) |

### Two-DLL ordering

When two `Image*.dll` plugins are installed, **X-Ways consults them in filename-alphabetical order, sequentially, on the same thread.** Confirmed by two rename pairs:

- `ImageIOTest.dll` vs `ImageIOTestB.dll` → `ImageIOTest` called first (`.dll` sorts before `B.dll` at position 12).
- `ImageATest.dll` vs `ImageIOTest.dll` → `ImageATest` called first (`A` sorts before `I` at position 5).

Inter-call gap: ~0-14ms (measured at millisecond resolution). The second DLL is invoked only after the first returns — they don't run in parallel. On NTFS we technically can't separate "filename-alphabetical" from "MFT B-tree enumeration order" (the B-tree is keyed by filename, so both predict the same answer), but the practical rule is identical: **filename controls call order**.

### NULL-from-Init protocol

Returning NULL from `IIO_Init` cleanly prevents X-Ways from advancing to `IIO_Work` / `IIO_Done` for that file. Confirmed across multiple sessions with >25 `IIO_Init` calls and zero spurious `IIO_Work` / `IIO_Done` rows in the log. The protocol works as documented.

## Still open

Remaining unknowns:

1. **Consent-prompt persistence (Q3).** When does the "Do not display this message again" allow-list get checked vs reset? Per-session? Per case? Persistent across X-Ways restarts? Where does X-Ways store the allow-list — `WinHex.cfg`, registry, an X-Tensions-specific config file? **Requires a cfg/dlg-snapshot diff test.**
2. **`IIO_Work` access pattern.** Sequential / random? Aligned to `nSectorSize`? `nSize` always a multiple of sector? Multi-threaded under volume-snapshot refinement? **Requires a DLL that claims a sentinel extension.**
3. **Lifetime of `IIO_Done`.** Fires on case-close? Evidence-object remove? X-Ways exit? Per-snapshot or per-process? **Requires a DLL that claims a sentinel extension.**
4. **Failure modes.** Does X-Ways protect itself if the DLL crashes inside `IIO_Work`? SEH wrapper, process-level death, anything? **Requires a deliberately-misbehaving variant.**
5. **Two-DLL cap accuracy.** Docs say "up to two." Earlier observations with three `Image*.dll` present had all three loading — the cap may be higher, or the alphabetically-last DLL silently drops. Worth a deliberate test if it matters for deployment guidance.
6. **Sister-format coverage.** `nHeaderBufSize` is 5120 across 10 formats. Tests against more exotic formats (`.vdi`, `.qcow2`, `.s01`, `.aff4`, segmented `.dmg`, etc.) might still expose variability — though the case for spending time on this is thin given how consistent the 10 samples already are.

## Calling convention + name decoration

- 32-bit: `__stdcall`, undecorated export names.
- 64-bit: only one calling convention on Windows x64 — `__stdcall` keyword is accepted but ignored. Still need undecorated export names.
- The `.def` file is the cleanest way to enforce undecorated names — preferred over `__declspec(dllexport)` because the latter mangles by default. The X-Tension SDK projects already use the same pattern; mirror it.
- **Verify after build:** open your DLL in X-Ways with the viewer component to inspect the actual exported names. (Suggestion straight from the doc.)

## Threading

The doc says `IIO_INIT_THREADSAFE` is "currently a must." Translation: assume X-Ways will hammer your `IIO_Work` from multiple worker threads (snapshot refinement, simultaneous search, item iteration). Synchronise any non-thread-safe resources you hold (e.g., a single file handle being seek+read'd needs a mutex around the seek+read pair, or use `ReadFile` with an `OVERLAPPED` per-call to avoid shared state).

The demo source curiously *omits* the `IIO_INIT_THREADSAFE` flag — possible the requirement is documented but not enforced. Worth checking what happens if you don't set it.

## Cross-references

- Candidate applications of this API: `e01-rs` / `vmdk-rs`-backed image support, or pairing with Dokan/WinFsp for external-tool mount.
- [xways-api-history-19-to-21_4.md](xways-api-history-19-to-21_4.md) v19.5 Preview 3 (2017-10-11) — original announcement.
- The Image I/O demo's `ImageIODemo.dpr` (in the official `IIO.zip`) — canonical Delphi reference implementation, 117 lines, doc-perfect.
