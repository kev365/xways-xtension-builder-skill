---
source: https://www.x-ways.net/forensics/x-tensions/XWF_functions.html (official) + empirical testing against X-Ways 21.7–21.8
type: official-doc + empirical-finding
fetched: 2026-04-19
last_updated: 2026-06-05
author: X-Ways Software Technology AG; empirical updates from testing against X-Ways 21.7 and 21.8
---

# X-Ways Events API (`XWF_AddEvent` / `XWF_GetEvent`)

Reference for adding rows to X-Ways' **Events** viewer and enumerating existing events. Combines the official SDK documentation with empirical findings from direct testing — primarily concrete behaviour of the public API beyond what the docs commit to (full subcode → Type-label tables, `nFlags` actual effects, `lpDescr` real ceiling, etc.).

Authoritative SDK declarations: the X-Ways SDK header (see [getting-the-sdk.md](getting-the-sdk.md)). Empirical methodology and per-channel writeups: [events-viewer-empirical-findings.md](events-viewer-empirical-findings.md).

## The `EventInfo` struct

```c
#pragma pack(2)
struct EventInfo {
    LONG     iSize;       // sizeof(EventInfo) — initialize before every call
    HANDLE   hEvidence;   // target evidence object
    DWORD    nEvtType;    // event category + Type label (see below)
    DWORD    nFlags;      // precision/timezone flags (see below)
    FILETIME TimeStamp;   // unadjusted FILETIME from the source artefact
    LONG     nItemID;     // linked volume-snapshot item, or -1 if not applicable
    INT64    nOfs;        // byte offset where the timestamp was found, or -1
    LPSTR    lpDescr;     // description — ANSI / UTF-8, NULL allowed
};
```

Two doc inconsistencies worth noting:

- The header field name is `LONG iSize`; the public docs page calls it `DWORD nSize`. Same width on x64 (4 bytes), same role (struct size in bytes, used for forward compatibility), but use the header name in code.
- `lpDescr` is **`LPSTR` (ANSI/UTF-8), not wide** — inconsistent with most other XWF_ APIs that take `wchar_t*`.

## `XWF_AddEvent`

```c
LONG XWF_AddEvent(struct EventInfo* pEvt);
```

Returns:

- `1` — event added.
- `2` — event deliberately ignored (e.g. duplicate / filtered by X-Ways).
- `0` — failure; **stop adding further events on this evidence**.

Evidence must be **open** for the write to land. Empirically, calls under any other condition silently drop.

**FILETIME round-trip is lossy.** The internal store converts the 64-bit FILETIME through a double, so `XWF_GetEvent` returns a value drifted by tens of µs to ~few ms from what was sent. Don't dedup on the raw FILETIME quad — bucket to seconds (or another window wider than the double-ulp at your timestamps) before keying. See [events-viewer-empirical-findings.md §7a](events-viewer-empirical-findings.md#7a-xwf_addevent--xwf_getevent-filetime-round-trip-drift-2026-05-12).

## `XWF_GetEvent`

```c
DWORD XWF_GetEvent(DWORD nEventNo, struct EventInfo* pEvt);
```

Returns `MAXDWORD` on failure; otherwise the byte-length of the description copied (0 is also success, just means no description). Available since **v18.1**.

**Total-count trick:** set `iSize = sizeof(LONG) + sizeof(HANDLE)` so the struct appears to cover only the size + evidence-handle fields — the function then ignores `nEventNo` and returns the total event count for that evidence object (even when the evidence is closed). Useful for pre/post-flight bracketing.

## `nEvtType` — full lookup map (empirical)

The public docs commit only to range buckets. Empirically, each range packs a sequential lookup table where every label is `base + N` for `N = 0, 1, 2, ...`, until X-Ways runs out of internal labels and shows `?` for unrecognised subcodes.

There are **9 distinct Category strings** the viewer uses (only 7 ranges are documented; `Social networks` and `Other` are undocumented but present in the build).

> **Verified on 21.8 (2026-06-05).** A full contiguous `0..30100` subcode sweep confirmed every subcode→Category/Type mapping below is **identical in X-Ways 21.8** — no new or renamed labels, no moved boundaries, no new categories. There is still no API to define custom *textual* Event Types.
>
> **v21.9 Preview 1 — custom numeric Event Types now usable for filtering (developer reply, 2026-06-09).** In a forum-thread reply to a direct question about whether the API can add custom Event Types/Categories, X-Ways stated:
>
> - There is **no API to add custom *textual* Event Type designations** ("maybe some other time").
> - But you can **define your own numeric event types**, and from **v21.9 Preview 1** those numeric values are **listed in the Events filter dialog even when X-Ways does not recognise them** — so they become usable filter facets.
> - **Pick values ≥ 25000** and the **Category column shows "Other"**. (Note: this differs from the empirical 21.8 map below, where `20000..29999` = `Registry` and `Other` starts at `30000`; treat ≥25000→"Other" as the new/forward behaviour for *unknown* custom types — re-validate when 21.9 ships.)
> - Values **must be ≤ 65535** (X-Ways handles them as a 16-bit value internally).
> - More event-related changes are coming in the next preview — watch the forum thread: <https://www.x-ways.net/winhex/forum/messages/1/5547.html?1781004984>
>
> **Implication:** an X-Tension with many event classes (e.g. a Linux-log parser with per-`SYSLOG_IDENTIFIER` facets) can assign custom numeric `nEvtType`s (≥25000, ≤65535) per class so analysts can filter by them in 21.9+, instead of collapsing everything into the built-in types. Hold implementations until 21.9 ships (Preview-only today) and the boundary behaviour is re-validated.

### Category map

| `nEvtType` range | `Category` column shown |
| --- | --- |
| `0` | `Unknown` (special — only this exact value) |
| `1` .. `99` | `Unknown` |
| `100` .. `999` | `File system` |
| `1000` .. `7999` | `Internal file metadata` |
| `8000` .. `9999` | `Internet` |
| `10000` .. `11999` | `Messaging` |
| **`12000` .. `13999`** | **`Social networks`** (undocumented sub-bucket inside the messaging range) |
| `14000` .. `14999` | `Operating system` |
| `15000` .. `19999` | `Event log` |
| `20000` .. `29999` | `Registry` |
| **`30000+`** | **`Other`** (undocumented) |

### `Type` column lookup tables

For each category, the labelled subcodes are listed below. Subcodes past the last labelled one display `?` in the Type column (the row is still added, with the correct Category, but with no specific Type label).

#### File system (range `100..`)

| Subcode | Type | Subcode | Type |
| ---: | --- | ---: | --- |
| 100 | Creation | 110 | Permission change |
| 101 | Modification | 111 | Ext attr modification |
| 102 | Access | 112 | Ext attr deletion |
| 103 | Record change | 113 | Document revision |
| 104 | Deletion | 114 | Exchange |
| 105 | Recycle bin | 115 | Metadata modification |
| 106 | Added | 116 | Hard link |
| 107 | Rename | 117 | Symbolic link |
| 108 | Mount | 118 | End of transaction |
| 109 | Unmount | 119+ | `?` |

#### Internal file metadata (range `1000..`)

| Subcode | Type | Subcode | Type |
| ---: | --- | ---: | --- |
| 1000 | Other | 1008 | Restore point |
| 1001 | Creation | 1009 | Start indexing |
| 1002 | Modification | 1010 | OLE2 creation |
| 1003 | Access | 1011 | OLE2 modification |
| 1004 | Record change | 1012 | Last saved |
| 1005 | Deletion | 1013 | Attached |
| 1006 | Printed | 1014 | Content created (Exif) |
| 1007 | GPS datum | 1015 | BPList Date Type |
| — | — | 1016+ | `?` |

#### Internet (range `8000..`)

| Subcode | Type |
| ---: | --- |
| 8000 | Other |
| 8001 | Visited |
| 8002 | Cookie |
| 8003 | Remote |
| 8004 | Fetch |
| 8005 | Sign-on created |
| 8006 | Sign-on last used |
| 8007 | Modified |
| 8008+ | `?` |

#### Messaging (range `10000..`) and Social networks (range `12000..13999`)

| Subcode | Type |
| ---: | --- |
| 10000 | Sent |
| 10001 | Received |
| 10002 | Created |
| 10003 | Record change |
| 10004 | Account created |
| 10005 | Last online |
| 10006 | Last activity |
| 10007 | File transfer |
| 10008 | VoIP call |
| 10009 | Chat |
| 10010 | Instant message |
| 10011..11999 | `?` (Category = `Messaging`) |
| 12000..13999 | `?` (Category = `Social networks`) |

#### Operating system (range `14000..`)

| Subcode | Type |
| ---: | --- |
| 14000 | Other |
| 14001 | Program started |
| 14002 | Program ended |
| 14003 | OS shutdown |
| 14004 | OS startup |
| 14005 | Session start |
| 14006 | OS update |
| 14007 | Encrypted volume creation |
| 14008 | Encryption key modification |
| 14009 | Network connection |
| 14010 | Network data |
| 14011 | Windows network data |
| 14012 | Application resource |
| 14013 | Energy usage |
| 14014 | Quarantine |
| 14015+ | `?` |

#### Event log (range `15000..`)

| Subcode | Type | Subcode | Type |
| ---: | --- | ---: | --- |
| 15000 | Interactive log-on | 15018 | Audit success |
| 15001 | Log-off | 15019 | Audit failure |
| 15002 | Failed log-on | 15020 | Log-on |
| 15003 | User account created | 15021 | Start |
| 15004 | User account deleted | 15022 | Stopped |
| 15005 | System time changed | 15023 | Boot |
| 15006 | User account enabled | 15024 | System standby |
| 15007 | User account disabled | 15025 | System reactivated |
| 15008 | User account changed | 15026 | Eventlog deleted |
| 15009 | Password change attempt | 15027 | Resources exhausted |
| 15010 | Password reset attempt | 15028 | Windows event |
| 15011 | Workstation locked | 15029 | Linux/Unix system |
| 15012 | Workstation unlocked | 15030 | An account logged off |
| 15013 | Application error | 15031 | Terminal service connection |
| 15014 | Application hang | 15032 | Timezone changed |
| 15015 | Information | 15033 | MSI Windows installer |
| 15016 | Warning | 15034 | Windows Powershell |
| 15017 | Error | 15035+ | `?` |

#### Registry (range `20000..`)

| Subcode | Type |
| ---: | --- |
| 20000 | Key changed |
| 20001 | Value changed |
| 20002 | Other |
| 20003 | Clean-up |
| 20004 | StartMenu start |
| 20005 | Timestamp |
| 20006 | Default |
| 20007 | Log-on |
| 20008 | Failed log-on |
| 20009 | MRU list |
| 20010 | Profile loaded |
| 20011 | SlowInfoCache |
| 20012 | AppCompatCache |
| 20013 | Device attached |
| 20014+ | `?` |

### Picking a subcode

When designing an X-Tension that emits events from a custom data source, choose the subcode whose label matches the *semantic* meaning of the event, even if the data source isn't strictly the type X-Ways expects in that range. The Category bucket comes along for free. If no built-in label fits, use the first subcode in the right range (the "Other" entry) — `?` rows are still useful and remain Category-filterable.

## `nFlags` — empirical semantics

| Bit | Documented meaning | Observed effect (case TZ = local) |
| --- | --- | --- |
| `0x00` | (no flags) | Full date+time, FILETIME interpreted as UTC and converted to case TZ for display |
| `0x04` | seconds only | No visible textual difference from `0x00` |
| `0x08` | even seconds only | No visible textual difference from `0x00` |
| `0x10` | date only | **Time portion dropped from display** |
| `0x20` | local time, not UTC | **No conversion applied** — value displayed verbatim |
| `0x40` | outdated | **No visible color or text marker** |
| `0x01` | (read-side only) | Set by `XWF_GetEvent` to indicate the event has been internally deleted |

`0x10` and `0x20` are the load-bearing bits in practice — set `0x10` when ingesting date-granularity events (e.g., daily aggregates) and `0x20` when the source FILETIME is already in the analyst's local time and shouldn't be re-converted.

## `lpDescr` — 254-byte display ceiling

`XWF_AddEvent` accepts and returns `rv = 1` (success) for descriptions up to **at least 64 KB**, but **only the first 254 bytes are stored or displayed in the Description column**. Anything beyond that is silently dropped.

The cap is byte-counted, not codepoint-counted: a 200-byte UTF-8 emoji blob (50 × 4-byte glyphs) renders as 50 emoji and consumes 200 bytes of the 254-byte budget. ZWJ sequences and BMP chars work the same way (counted by their UTF-8 byte length).

Newlines (`\n`) and tabs (`\t`) in the description render visually but split rows in TSV exports — avoid if the timeline will be exported.

The public docs say `≤ 255 bytes` — the actual ceiling is 254. Plan for 254 bytes total descriptive content.

## Item linkage (`nItemID`, `nOfs`)

Empirical behaviour:

- `nItemID = -1` (or any value not present in the snapshot): event has no Name / Path columns populated. Can't double-click to a file.
- `nItemID = <valid X-Tension item ID>`: event's Name, Path, and item-property columns populate from that item. Double-click navigates to the file.
- `nItemID = <out-of-range item ID>` (e.g. greater than `XWF_GetItemCount() - 1`): the row appears with `Name = ？` (full-width Q-mark, U+FF1F), zero size, `Type status = "not verified"`. Detectable as "anchoring failed" in TSV export.
- `nOfs = -1`: standard "no offset known".
- `nOfs = 0`: empirically identical to `-1` — no semantic difference.
- `nOfs = <byte offset>`: cosmetic only. **Double-click navigates to the linked file's *start*, not to byte `nOfs`**. Use for the `Offset` column display, but don't expect navigation behaviour.

The X-Tension `nItemID` corresponds to the directory browser's **`Int. ID`** column, *not* the plain `ID` column. (`ID` is the filesystem-level entry number — e.g., NTFS MFT entry — and can be duplicated across child streams; `Int. ID` is unique per snapshot item.) Enable the `Int. ID` column in the directory browser when correlating X-Tension actions to UI rows.

## Writable channels adjacent to events

When events are anchored to an item via `nItemID`, several other XWF_ APIs surface useful per-item info next to those events in the viewer (the events list inherits item-level columns). All of these accept emoji and Unicode in their string parameters.

| API | Where it lands | Width / format | Emoji renders? |
| --- | --- | --- | --- |
| `XWF_AddComment(item, str, how)` | **Comments column** of the directory browser + Details pane (also visible next to anchored events) | wide string | ✓ |
| `XWF_AddExtractedMetadata(item, str, how)` | **Metadata column** + Details pane | wide string | ✓ |
| `XWF_AddToReportTable(item, name, 0)` | **Labels column** (formerly "Categorization"); same surface as Report Tables | wide string | ✓ in UI; ✗ in HTML report |
| `XWF_AddSearchTerm(name, 0)` | **Search Terms** list (case-level, not per-item) | wide string | ✓ |
| `XWF_SetItemType(item, label, status)` | **Type** column conditionally; **Type status** column always | wide string | renders with fallback glyph for SMP chars |

`XWF_AddComment` and `XWF_AddExtractedMetadata` use a `nFlagsHowToAdd` parameter: `0 = REPLACE`, `1 = APPEND`, `2 = PREPEND`.

## `XWF_SetItemType` and `nTypeStatus`

The viewer exposes 7 distinct Type-status strings; 5 of them are reachable via the API's `nTypeStatus` integer.

| `nTypeStatus` | `Type status` shown | Label appears in Type column? |
| ---: | --- | :---: |
| `-1` | `insignificant` | No |
| `0` | `not in list` | No |
| `1` | `not confirmed` | No |
| `2` | `confirmed` | No |
| `3` | `mismatch detected` | **Yes** |
| `≥ 4` (4, 5, 255 verified) | `mismatch detected` | **Yes** (clamps to status 3 behaviour) |

Two strings are **not reachable** via `nTypeStatus`:

- `not verified` — implicit default for any item where `XWF_SetItemType` was never called.
- `newly identified` — reserved for X-Ways' internal type-detector when it identifies a file type from signature alone (no extension match). The manual hints this would also surface "if a more standardized type designation is set", but no `nTypeStatus` value triggers it from the API.

Net result: there is **no clean-override path** for the Type column. Any value that displays the supplied label also displays the `mismatch detected` warning to the analyst. If you need a custom Type label without a warning, ship a `File Type Categories User.txt` snippet with X-Ways instead — that route is config-driven and triggers the type detector to display your label cleanly.

## Color rendering and Conditional Coloring

The Events viewer **does not render color** based on any `nFlags` value. The manual's reference to "displayed in gray" applies to NTFS 0x30 anomaly events surfaced by the built-in extractor, *not* events emitted by an X-Tension.

For row highlighting on rules (e.g., "highlight all events from a particular X-Tension in red"), the supported path is per-case **Conditional Coloring** — a UI feature configured via the directory browser settings, with a sample in your X-Ways install root (`Conditional Coloring.cfg`) and a readme. Conditional Coloring rules apply to both the directory browser and the Events viewer rows.

An X-Tension cannot directly set row colour. The closest it can do is ensure events have distinct fields (Category, Type, Description prefix, anchored-item Labels) so a Conditional Coloring rule can match.

## Default timezone behavior

The case TZ controls the Events viewer's display. Sending UTC FILETIMEs without `0x20` set causes values to display as `(UTC) - case-TZ-offset`.

This is **not** a default — purely case-configured. Send UTC FILETIMEs (no `0x20`) and trust the case to convert for display. Set `0x20` only when the source data is genuinely in local time and shouldn't be re-converted.

## Relationship to `Event Log Events.txt`

The `Event Log Events.txt` file in the X-Ways install folder is a **config-only** feature of X-Ways' built-in EVTX parser. It tells the parser which additional `Data Name` fields (e.g. `TargetUserName`, `IpAddress`, `LogonType`) to splice into each Windows event-log event's description when the event is added internally. It is **not** exposed via the X-Tension API — you cannot influence the EVTX parser's field selection from an X-Tension.

The *pattern* — "for event types I care about, attach a curated set of enriched fields" — is exactly what an X-Tension can do for **other** event sources (browser SQLite DBs, chat apps, filesystem artefacts, IIS logs, application-specific logs) by calling `XWF_AddEvent` with a well-crafted `lpDescr`.

## Modifying existing events

The docs do **not** describe any in-place modification primitive. The enrichment pattern is:

1. Enumerate existing events with `XWF_GetEvent`.
2. For events matching a rule (e.g. EventID 4624 at a specific `nItemID`), compute an enrichment string by reading the item content (`XWF_Read` on the item handle or parsing external data).
3. Call `XWF_AddEvent` with a **new** event anchored to the same `(hEvidence, nItemID, nOfs, TimeStamp)` and the enriched description. The result is a sibling row in the Events viewer; the original stays as-is.

If you want de-duplication, compare `(nEvtType, TimeStamp, nItemID, nOfs)` tuples during enumeration and skip when a matching enriched sibling already exists (you control the `lpDescr` format so you can detect your own signature).

## Python exposure

`XT_Python.dll`'s embedded `xwf` module (per the XT_Python readme shipped with the SDK) does **not** expose `AddEvent`/`GetEvent`. Event-emitting X-Tensions must be written in **C++** (or Delphi/C#), not Python with the stock bridge.

## Threading

Thread-safety of `XWF_AddEvent` is undocumented. RVS (`XT_ProcessItemEx` under volume-snapshot refinement) is multi-threaded. If you're adding events from per-item callbacks under RVS, treat the call as potentially racy — either wrap with a mutex, or batch events into a one-shot pass during `XT_Prepare` / `XT_Finalize`.

Running the ingest single-threaded inside `XT_Prepare` side-steps the question entirely.

## Practical usage shape (C++)

- Resolve pointers in `XT_Init`: `GetProcAddress(GetModuleHandleW(NULL), "XWF_AddEvent")`, etc. Resolve against the main X-Ways executable (the X-Tension DLL is loaded into its address space).
- In `XT_Prepare`, capture `hEvidence` from the parameter list. Pre-flight the event count with the total-count trick on `XWF_GetEvent` if you want a delta to verify ingestion.
- Build an `EventInfo` per event:
  - Set `iSize = sizeof(EventInfo)`.
  - Pick `nEvtType` for both the right Category bucket and the desired Type label (see tables above).
  - Fill `nFlags` based on timestamp precision/timezone.
  - Convert source timestamps to UTC FILETIME (100ns ticks since 1601-01-01).
  - Set `nItemID` to the X-Tension item ID of the source artefact when possible (for double-click navigation), `-1` otherwise.
  - Encode `lpDescr` as UTF-8, ≤ 254 bytes. Truncate carefully on multi-byte boundaries if you might exceed.
- Call `XWF_AddEvent`. Stop the loop if `rv == 0`.
- Return `0` from `XT_Prepare` to skip per-item iteration if all the work is done.

## Caveats

- Evidence must be **open**. Otherwise `XWF_AddEvent` writes drop silently.
- `lpDescr` is **ANSI/UTF-8 (not wide)** and capped at **254 bytes display** despite the docs' claim of "≤ 255". Plan for 254 bytes.
- `nItemID` is **`Int. ID`** in the directory browser, not the plain `ID`.
- `nOfs` is metadata only — does not navigate the hex view.
- `XWF_AddEvent` is not exposed to Python; C++ only.
- Threading not documented — single-threaded inside `XT_Prepare` is the safe default.
- The Events viewer does not render colours from `nFlags` — use Conditional Coloring for visual differentiation.
- Avoid `\n`/`\t` in `lpDescr` if the timeline will be TSV-exported.

## See also

- [events-viewer-empirical-findings.md](events-viewer-empirical-findings.md) — full empirical methodology, per-channel writeups, and worked-example design context.
- The X-Ways SDK header (see [getting-the-sdk.md](getting-the-sdk.md)) — authoritative SDK declarations (struct layout, function signatures).
