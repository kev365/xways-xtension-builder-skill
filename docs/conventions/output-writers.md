# Output writers (CSV / XLSX / large exports)

!!! warning "Forensic data is hostile to naive writers — four rules"
    Log/artifact bytes are arbitrary, exports can be enormous, and a corrupt output is worse than
    none. Any X-Tension that writes CSV/XLSX must:

    1. **Sanitise to valid UTF-8 / XML.** Raw bytes (binary payloads, Latin-1 logs) are routinely not
       valid UTF-8; dropping them into an `encoding="UTF-8"` XLSX makes Excel reject the **whole**
       workbook ("unreadable content"). Validate per codepoint and replace bad/overlong/surrogate
       sequences and XML-illegal control chars with U+FFFD.
    2. **Propagate I/O errors.** A writer that always returns "ok" turns a disk-full into a silently
       truncated CSV — an evidence-integrity hole. Thread the `WriteFile` status out.
    3. **Bound memory.** Don't buffer every row (or assemble the whole XLSX/ZIP) in RAM — large or
       numerous inputs exhaust memory and lock up the machine. Spill rows to a temp file and stream.
    4. **Split / respect limits.** XLSX caps at 1,048,576 rows/sheet; a store-only ZIP's uint32
       size/offset fields cap the archive at 4 GB. Split into multiple files on a row count.

**Reference implementation:**
[xways-linux-logs](https://github.com/kev365/xways-linux-logs) (`output_writer.cpp` —
`EscapeXmlText` (UTF-8 validation), `OutputSink` (row spill + single-pass streaming), `ZipWriter`
(streaming store-only ZIP), `WriteCsv`/`Close` (error propagation), `rowsPerFile` splitting).

## Pattern

The UTF-8/XML sanitiser — the highest-frequency bug, since one bad byte invalidates the file:

```cpp
std::string EscapeXmlText(const std::string& s) {            // also escapes & < >, C0 controls → space
    std::string o; const unsigned char* p = (const unsigned char*)s.data(); size_t n = s.size(), i = 0;
    while (i < n) {
        unsigned char c = p[i];
        if (c < 0x80) { /* ASCII: escape &<>, replace illegal C0 controls, else copy */ ++i; continue; }
        int len; unsigned cp, minCp;                         // decode the multi-byte sequence
        if      ((c & 0xE0) == 0xC0) { len = 2; cp = c & 0x1F; minCp = 0x80; }
        else if ((c & 0xF0) == 0xE0) { len = 3; cp = c & 0x0F; minCp = 0x800; }
        else if ((c & 0xF8) == 0xF0) { len = 4; cp = c & 0x07; minCp = 0x10000; }
        else { o += "\xEF\xBF\xBD"; ++i; continue; }          // bad lead byte → U+FFFD
        /* validate continuations + reject overlong / surrogate / >0x10FFFF / U+FFFE/FFFF → U+FFFD,
           else append the bytes verbatim */
    }
    return o;
}
```

Memory-bounding + splitting (the shape, not the whole file): `Add()` serialises each row to a temp
**spill file** (length-prefixed) and keeps only the *field-name union* in RAM; `Close()` makes one
streaming pass, writing the CSV incrementally and emitting XLSX files of `rowsPerFile` rows each via a
ZIP writer that streams members straight to the file handle. Peak RAM ≈ one output file's rows,
independent of total input.

## Do / Don't

- **Do** validate UTF-8 and strip XML-1.0-illegal chars before writing any XML/XLSX cell.
- **Do** return the real write status from every writer and surface it (Messages window + `Close()` err).
- **Do** spill to disk / stream for unbounded exports; make the split size configurable (cfg + dialog).
- **Do** keep the column set's dynamic union small in RAM; spill the *row data*, not the rows.
- **Don't** pass raw log bytes into a UTF-8 XML document.
- **Don't** assemble the whole workbook/ZIP in a `std::string` — bound it by the split size.
- **Don't** ignore Excel's row limit or the uint32 ZIP ceiling (splitting keeps each file well under both).

See also: [Output directory](output-dir.md), [VERBOSE logging](verbose-logging.md),
[Wrapper anatomy](wrapper-anatomy.md) (the wrapped tool's output can be unbounded — measure it).
