---
source: the community xwf-api-rs binding (ThomasVogl, MIT) + the X-Ways SDK header (see getting-the-sdk.md) + project synthesis from forum announcements + the live XWF_functions.html (fetched 2026-07-03)
type: empirical-finding + community-RE + official
fetched: 2026-05-17
last_updated: 2026-07-03
author: project synthesis
---

# `XWF_OpenItem` flag bits

```c
HANDLE __stdcall XWF_OpenItem(HANDLE hVolume, LONG nItemID, DWORD nFlags);
```

The X-Ways SDK header (see [getting-the-sdk.md](getting-the-sdk.md)) declares the function but doesn't document any of `nFlags`. The live official [XWF_functions.html](https://www.x-ways.net/forensics/x-tensions/XWF_functions.html) documents the flag list (as of 2026-07-03) and is the authoritative source for this table; the community xwf-api-rs binding's `XWF_OpenItem` bitflag enum corroborates it (community reverse-engineering, MIT-licensed).

> **Note:** the EML-with-attachments flag is officially **`0x8000`** ("embed child objects if this file is an e-mail message extracted by X-Ways Forensics in .eml format, otherwise no effect, v21.8 and later"). The `0x2000` value seen in v21.8 Beta 5 forum user code is **not** in the official flag list — treat `0x2000` as unverified/wrong for this purpose.

## Full flag table

| Bit | Name | Version | What it does (per source) |
| ---: | --- | --- | --- |
| `0x0001` | `OpenForAccessIncludingFileSlack` | base | Open for read, including the file's slack space. The minimum flag for any read. |
| `0x0002` | `SuppressErrorMessages` | base | Suppresses in-program error popups when the open fails. Useful for X-Tensions that iterate every item and don't want X-Ways throwing modals at the analyst on a few unreadable items. |
| `0x0008` | `PreferAlternativeFileData` | base | If X-Ways has alternative file data for this item (e.g. an X-Ways-generated thumbnail for a picture), open that instead of the original. |
| `0x0010` | `OpenAlternativeFileDataWithFail` | base | Like 0x0008 but fail the open if alternative data isn't available — "open alternative data or fail," the strict-mode variant of 0x0008, per the official page (2026-07-03). (xwf-api-rs's comment text is mis-pasted from 0x0080.) |
| `0x0080` | `OpenCarvedFilesInExt` | v19.8+ | Open carved files in Ext2/3 volumes **without** applying the Ext filesystem's block-layout logic. Use when X-Ways' own carved-item handling is producing wrong bytes on Ext volumes. |
| `0x0200` | `ConvertToPDF` | v19.9+ | On-the-fly conversion of the item to PDF; `XWF_Read` on the returned handle yields PDF bytes. Works for the same set of file types X-Ways' viewer component can convert. |
| `0x0400` | `ExtractPlainTextUtf8` | v20.0+ | On-the-fly plain-text extraction (UTF-8). `XWF_Read` yields the text body. Avoids the OCR path (`XWF_GetText` `nFlags=0x02`) for documents that already carry indexable text. |
| `0x0800` | `ExtractPlainTextUtf16` | v20.0+ | Same as 0x0400 but UTF-16. |
| `0x1000` | `PrependByteOrderMark` | v20.0+ | Combine with `0x0400` or `0x0800` to prepend a BOM. |
| `0x8000` | (embed e-mail child objects) | v21.8+ | Embed child objects if the item is an e-mail message extracted by X-Ways in `.eml` format (otherwise no effect) — mirrors the GUI "Copy/Recovery" behaviour. Official per the live [XWF_functions.html](https://www.x-ways.net/forensics/x-tensions/XWF_functions.html) (2026-07-03); supersedes the `0x2000` value observed in user code on the forum. *Caveat — open issue:* the returned handle's size props may still report the bare-EML size; measure by reading to EOF. |

Bits not listed (`0x04`, `0x20`, `0x40`, `0x100`, `0x2000`, `0x4000`, and everything `0x10000+`) are **undocumented on the official page and untested** — xwf-api-rs doesn't bind them either.

## How to combine

The flags are a bitmask (`DWORD`). Most opens want exactly `0x01`. Read paths that look like documents but you don't want the OCR-flavoured path:

```cpp
// "Give me UTF-16 text of this file, with a BOM, but don't pop an error if it
//  can't produce one. If we don't get a handle, fall back to OCR."
HANDLE h = XWF_OpenItem(hVolume, itemID,
                        OpenForAccessIncludingFileSlack
                      | ExtractPlainTextUtf16
                      | PrependByteOrderMark
                      | SuppressErrorMessages);
if (!h) {
    // OCR path: open for read, then call XWF_GetText with nFlags=0x02
    h = XWF_OpenItem(hVolume, itemID, 0x01);
    // ...
}
```

The `XWF_Read` against the returned handle behaves the same regardless of which extraction flag was set at open — X-Ways already pre-rendered the bytes; you're just reading them out.

## Why this matters for X-Tension design

Two of these — `ConvertToPDF` (0x0200) and `ExtractPlainTextUtf8/16` (0x0400 / 0x0800) — replace expensive analyzer paths most X-Tensions had to roll themselves:

1. **Text extraction without OCR.** Before 20.0, an X-Tension that wanted text from a Word/PDF/etc. item had to call `XWF_PrepareTextAccess` + `XWF_GetText` with `nFlags=0x02` (see [xways-itemtype-metadata-text.md](xways-itemtype-metadata-text.md)). That path **shells out to the viewer component / Tesseract** — slow and external-tool-dependent. `OpenItem(0x401)` skips that machinery entirely: X-Ways uses its built-in text extractor, which is fast and dependency-free for the file types it supports.

2. **PDF representation.** Same logic — instead of "ask X-Ways for the bytes of a `.doc`, then run your own LibreOffice/Word-to-PDF pipeline," just open with `0x201` and read the PDF directly.

Both are particularly useful for ML/NLP pipelines (ML/NLP scanners, classifiers) and for tools that want a uniform input format (PDF or text) regardless of the underlying item type.

## Open questions

- **Why is 0x0040 unbound?** xwf-api-rs's enum is dense up to 0x0020 then jumps to 0x0080, skipping 0x0040. Either inert, reserved, or known-undocumented.
- **0x2000 / 0x4000.** Undocumented on the official page. `0x2000` was once believed to be the EML flag (forum user code) — the official EML flag is `0x8000`; what `0x2000` actually does (if anything) is unknown. Worth testing.
- **Above 0x10000.** Totally untested; expect either nothing or large structural flags (e.g., "open into a memory-mapped view").

A read-only sweep of these specific bits across a curated item list — run on a snapshot containing at least one PDF-convertible doc + one text-extractable doc + one EML — would fill in the table.

## See also

- [xways-itemtype-metadata-text.md](xways-itemtype-metadata-text.md) — `XWF_GetText` `nFlags=0x02` (OCR/viewer-component) vs `XWF_OpenItem(0x0400)` (X-Ways text extractor) — choose the cheaper path
- [forum-xtensions-distilled.md](forum-xtensions-distilled.md) — the v21.8 Beta 5 forum thread where `0x2000` was (incorrectly) observed for EML embedding; official flag is `0x8000`
- [xways-reading-events-and-items.md](xways-reading-events-and-items.md) — `XWF_OpenItem` / `XWF_Read` / `XWF_Close` lifecycle in the analyzer pattern
- [xways-api-recency-research.md](xways-api-recency-research.md) — context for the forum-announcement-derived bits
- The community xwf-api-rs binding's bitflag enum — original Rust binding source ([xwf-api-rs on GitHub](https://github.com/ThomasVogl/xwf-api-rs))
