---
source: X-Ways Events Viewer — Empirical Findings
type: empirical-finding
fetched: 2026-04-26
last_updated: 2026-04-26
author: empirical testing + analyst inspection of UI
---

# X-Ways Events Viewer — Empirical Findings (21.7)

What an X-Tension can and can't put into the Events viewer (and adjacent writable surfaces), measured directly against X-Ways Forensics **21.7** (and re-validated on **21.8** — see §11). All claims here override the public SDK docs where they conflict, for the purposes of this skill, since the public docs only commit to range buckets and the API header carries no inline subcode constants.

Authoritative API header: the X-Ways SDK header (see [getting-the-sdk.md](getting-the-sdk.md)).

## TL;DR

- **Complete `nEvtType` → Type label map for all 7 ranges, sweep-confirmed.** Every label increments by 1 from the range base. An X-Tension can pick subcodes that produce semantically correct Type labels in the viewer (e.g. `14005 = Session start`, `14012 = Application resource`).
- **`lpDescr` IS capped — at exactly 254 bytes for the visible Description column.** `XWF_AddEvent` accepts up to at least 64KB and returns `rv=1`, but only the first 254 bytes display.
- **Category column = your friend.** The 7 ranges plus undocumented `Social networks` (12000–13999) and `Other` (30000+) make a 9-bucket map.
- **Out-of-range `nItemID` renders as `？` (U+FF1F)** — empty Name path + zero Size + Type status `not verified`. Detectable.
- **`nOfs = 0` = `nOfs = -1`** — no behavioural difference.
- **Comments / Metadata / Search Terms / Labels (Report Tables) all accept emoji and stick.** `XWF_SetItemType` reaches **5 of 7** Type-status strings via `nTypeStatus ∈ {-1, 0, 1, 2, 3}`; values ≥ 3 all clamp to `mismatch detected`. The two missing strings (`not verified`, `newly identified`) are reserved for X-Ways' internal type detector. **There is no clean-override path** for the Type column from an X-Tension.
- **Use the `Int. ID` directory-browser column** — not the plain `ID` column — to correlate X-Tension `nItemID` to UI rows. Plain `ID` is the MFT entry number and can be duplicated across child streams.
- **Events viewer renders no color** based on any `nFlags` value an X-Tension sets. Visual highlighting requires per-case Conditional Coloring rules.
- **Double-click navigates to the linked file** but **does not seek to `nOfs`**.

## 1. Complete `nEvtType` → Type label map (dense sweep)

Each row below is empirically verified: the X-Tension emitted exactly one event with that `nEvtType`, and the column values are what the Events viewer displays. Labels match X-Ways' internal lookup table 1:1 with the order shown in the Type-column filter dropdown.

### `Category = "File system"` (range 100..)

| Subcode | Type label | Subcode | Type label |
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
| 109 | Unmount | 119+ | `?` (no built-in label) |

### `Category = "Internal file metadata"` (range 1000..)

| Subcode | Type label | Subcode | Type label |
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

### `Category = "Internet"` (range 8000..)

| Subcode | Type label |
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

### `Category = "Messaging"` (range 10000..)

| Subcode | Type label |
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
| 10011..11999 | `?` |
| 12000..13999 | `?` (with **`Category = "Social networks"`** instead of Messaging) |

The `Social networks` category is undocumented in the public API but exists empirically as a sub-bucket inside the Messaging range. No specific Type labels were found for it during the sweep.

### `Category = "Operating system"` (range 14000..)

Bolded rows are typical picks for an Operating-system-category Events-API X-Tension.

| Subcode | Type label |
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
| 15000+ | `?` |

### `Category = "Event log"` (range 15000..) — UAL alternative range

| Subcode | Type label | Subcode | Type label |
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

### `Category = "Registry"` (range 20000..)

| Subcode | Type label |
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

### Outside any documented range

| Subcode | Type | Category |
| ---: | --- | --- |
| 0 | `Unknown` | `Unknown` |
| 1..99 | `?` | `Unknown` |
| 30000+ | `?` | `Other` |

## 2. `nFlags` semantics (empirical)

| Bit | Documented meaning | Observed effect |
| ---: | --- | --- |
| `0x00` | (no flags, full UTC precision) | Full date+time, converted to case TZ for display |
| `0x04` | seconds only | No visible textual difference vs `0x00` |
| `0x08` | even seconds only | No visible textual difference vs `0x00` |
| `0x10` | date only | Time portion dropped from display |
| `0x20` | local time, not UTC | No conversion applied — value displayed as-is |
| `0x40` | outdated | No visible color or text marker |
| `0x14` | combo (date-only + local time) | Date only, no conversion |

For an Events-API X-Tension:

- Date-only rows (e.g. a daily bucket at midnight UTC) → set `0x10`.
- Timestamps with full UTC precision → `0x00`.
- Don't expect `0x40` to make outdated rows visually distinct.

## 3. `lpDescr` capacity

| Test | Sent (bytes incl prefix) | XWF_AddEvent rv | Description column shown |
| --- | ---: | ---: | ---: |
| D03 | 112 | 1 | 112 chars |
| D04 | 266 | 1 | 254 chars (truncated) |
| D05 | 267 | 1 | 254 chars |
| D06 | 268 | 1 | 254 chars |
| D07 | 512 | 1 | 254 chars |
| C01 | 524 | 1 | 254 chars |
| C02 | 1036 | 1 | 254 chars |
| C04 | 4108 | 1 | 254 chars |
| C08 | 65547 | 1 | 254 chars |

`XWF_AddEvent` accepts up to at least 65KB and reports success, but X-Ways stores or displays only the first 254 bytes. **For an Events-API X-Tension: budget is 254 bytes.**

Multibyte UTF-8 is byte-counted, not codepoint-counted. D10's 200-byte UTF-8 emoji blob (50 × 4-byte SMP emoji) shows as 212-char description (12 prefix + 200 body) — confirming the count is in bytes, not glyphs.

Newlines (`\n`) and tabs (`\t`) render but are also TSV-export-fragile (split rows).

## 4. Other writable channels

| API | Result | Where it lands in UI | Emoji renders? |
| --- | --- | --- | --- |
| `XWF_AddComment` | returned `-1` (TRUE) | **Comments column** + Details pane | ✓ yes |
| `XWF_AddExtractedMetadata` | returned `-1` (TRUE) | **Metadata column** + Details pane | ✓ yes |
| `XWF_AddToReportTable` | returned `1` for both names | **Labels column** on the item shows `Probe Findings, Probe 🚀 Findings`; both appear in the Labels picker | ✓ yes (UI); ✗ no (HTML report shows `??`) |
| `XWF_AddSearchTerm` | returned `id=0`, `id=1` | **Search Terms list** | ✓ yes |
| `XWF_SetItemType` | void return | See dedicated table below — behaviour depends on `nTypeStatus` | label rendered with fallback glyph for emoji |
| `XWF_SetItemInformation` (FLAGS_SET, notable bit) | TBC | **Categorization column** (separate from Labels) — values `unknown` / `irrelevant` / `notable` / `uncategorized`. Per manual this column "can be set automatically using X-Tensions". | n/a — TBC |

UI naming note: in 21.7 the directory-browser column for this surface is labelled **`Labels`** (not `Categorization`), and it's the same surface as Report Tables. The XWF API name (`XWF_AddToReportTable`) is older terminology; the user-facing label in current UI is `Labels`. Pre-defined labels with no current members show as greyed `Hint` in the picker.

### `XWF_SetItemType` `nTypeStatus` semantics

X-Ways exposes **7 Type Status strings** in the filter dialog.

| Type status string | Reachable via `nTypeStatus` integer? | Notes |
| --- | --- | --- |
| `not verified` | **No (implicit default)** | What untouched items show; not directly settable |
| `insignificant` | **`-1`** | Label not visible. X-Ways uses this internally for files < 8 bytes |
| `not in list` | **`0`** | Label not visible |
| `not confirmed` | **`1`** | Label not visible |
| `confirmed` | **`2`** | Label not visible |
| `newly identified` | **No** | Per manual, triggered only by X-Ways' internal type detection ("file type identified, filename has no useful extension"). **Not reachable from `XWF_SetItemType`.** |
| `mismatch detected` | **`3`, `4`, `5`, `255`** (all clamp here) | Label visible. `Type category` may be inferred from the override label string |

(`nTypeStatus = 6` landed on the volume root during testing, which the screenshot didn't include — but given that 4, 5, and 255 all clamp to `mismatch detected`, 6 almost certainly does too.)

**Behavioral summary:**

- Five integer values give five distinct status strings: `-1, 0, 1, 2, 3`.
- Values `≥ 3` all produce `mismatch detected` with the override label visible.
- Values `0..2` set the status text but **do not display the supplied label** — the call effectively only writes the `Type status` field.
- The two missing strings (`not verified`, `newly identified`) are reserved for X-Ways' internal use and cannot be set from an X-Tension.

**Implication for X-Tensions that want to set a custom type label:**

There is **no clean-override path**. Any `nTypeStatus` value that displays the supplied label also displays the `mismatch detected` warning to the analyst. If a clean custom label matters, the path is `File Type Categories User.txt` (see §10), not `XWF_SetItemType`.

**Discrepancy (observed 2026-05-03, cross-check vs xwf-api-rs):** the community xwf-api-rs binding's `FileTypeStatus` enum defines the status integers as `0=NotVerified, 1=TooSmall, 2=TotallyUnknown, 3=Confirmed, 4=NotConfirmed, 5=NewlyIdentified, 6=MismatchDetected` — i.e., a **7-value scheme on the read side** (`XWF_GetItemType` return value). A sweep observed `XWF_GetItemType` returning 1, 2, 3 on NTFS metafiles, which is consistent with that scheme (`$MFT` → 3 = Confirmed, `$Volume` → 1 = TooSmall, `$Bitmap` → 2 = TotallyUnknown — all plausible). So **`XWF_GetItemType` and `XWF_SetItemType` appear to use different status conventions**: the read side uses the 0..6 scheme above; the write side accepts 0..2 = "not in list / not confirmed / confirmed", `-1` = "insignificant", and `≥ 3` clamps to "mismatch detected". The asymmetry is unverified — re-test with the full `nTypeStatus` range before relying on it.

### Other Type Status facets (not API-settable)

The same filter dialog exposes three other facets that are NOT directly controllable from `XWF_SetItemType`:

- **File format consistency**: `unknown` / `OK` / `irregular` / `corrupt`. Set by metadata extraction or carving for some file types (e.g., JPEG without footer = `irregular`).
- **Rank** (`#0`–`#5`): from `File Type Categories.txt`. Affects relevance scoring.
- **Group** (e.g. "Certain potentially relevant types"): also from `File Type Categories.txt`.

These derive from the `File Type Categories.txt` config plus internal metadata extraction logic. An X-Tension does not set them directly via the public API. Worth knowing they exist so an X-Tension author doesn't accidentally try to set them.

### `nItemID` correlation to directory browser — use the `Int. ID` column

The directory browser has *two* numeric ID columns and **only one of them corresponds to X-Tension `nItemID`**:

| Column | What it is | Use for |
| --- | --- | --- |
| `ID` | NTFS MFT entry number (or equivalent for other filesystems). Multiple items can share an ID — child streams display the parent's MFT entry. | Filesystem-level reasoning, MFT entry navigation. |
| **`Int. ID`** | **X-Tension `nItemID`.** Sequential, unique per snapshot item. | Correlating X-Tension actions to UI rows. |

Empirical confirmation: `XWF_SetItemType(nItemID=3, ...)` landed on the row whose `Int. ID = 3` (which was `$LogFile`, MFT-`ID = 2`). If you're correlating X-Tension behavior to what the analyst sees, **enable the `Int. ID` column in the directory browser** (right-click any column header → check `Int. ID`). The plain `ID` column will mislead you for any item with child streams or alternate data streams.

The browser also exposes `Int. parent`, which is the parent item's `nItemID` — useful for X-Tensions that want their categorisation to mirror the snapshot tree the analyst navigates.

## 5. Item linkage (`nItemID` / `nOfs`)

| Variant | Result |
| --- | --- |
| `nItemID = -1`, `nOfs = -1` | Event has no Name / Path columns populated. Can't double-click to file. |
| `nItemID = 0`, `nOfs = -1` | Event linked to item 0 (`$MFT`). All file-property columns populate. Double-click opens the file. |
| `nItemID = 0`, `nOfs = 0` | **Identical to `nOfs = -1`** — no semantic difference. |
| `nItemID = 0`, `nOfs = 1234` | Same linkage as above; **`nOfs` does not seek the hex view** when double-clicked. View opens at byte 0 of the file. |
| `nItemID = snapshot_count + 100` (truly out-of-range) | **Name column shows `？` (U+FF1F)**, ID = 0, Size = 0, Type status = `not verified`, Type descr. empty. Detectable as "this item ID didn't resolve." |

Implication for UAL: anchoring events to the source `.mdb` item via `nItemID` gives one-click navigation. `nOfs` is metadata only — leave it `-1`. For programmatic detection of broken anchoring, check `Type status == "not verified"` or `Name == "？"`.

## 6. Color / highlighting

- **The Events viewer does not use color** for any `nFlags` value tested (verified visually for `0x40` outdated).
- The manual's "displayed in gray" reference applies to NTFS 0x30 anomaly events surfaced by X-Ways' built-in extractor, **not** events emitted by an X-Tension via `XWF_AddEvent`.
- For row highlighting based on rules, use **Conditional Coloring** — a per-case UI feature configured via the directory browser settings. Sample in your X-Ways install root (`Conditional Coloring.cfg`) with a readme. Conditional Coloring rules apply to both directory browser and Events viewer rows.
- An X-Tension cannot directly set row colour; it ensures events have distinct fields (Category, Type, Description prefix, Labels) so a Conditional Coloring rule can match on them.

## 7. Default timezone

The case TZ controls Events viewer display. The test events sent UTC FILETIMEs; test case 1 was set to UTC-6, so values shifted accordingly. Test case 2 (a clean UTC-0 case) displayed values verbatim. **Not a default — purely case-configured.** An Events-API X-Tension should send UTC FILETIMEs unless `0x20` is set.

## 7a. `XWF_AddEvent` / `XWF_GetEvent` FILETIME round-trip drift (2026-05-12)

X-Ways' internal event store **does not preserve the full 64-bit FILETIME** that `XWF_AddEvent` is given. Empirically, `XWF_GetEvent` returns a value that differs from what was stored by tens of microseconds to a few milliseconds, suggesting an internal `double` conversion (FILETIME → double seconds → FILETIME, or similar).

Verified on a UAL ingest, build 21.0 SR-4 (1422138.89):

| Direction | FILETIME quad |
| --- | --- |
| Sent to `XWF_AddEvent` (UAL-derived UTC) | `132281143137720000` |
| Read back from `XWF_GetEvent` for the same event | `132281143137720832` |
| Drift | `+832 ticks` ≈ +83 µs |

At this magnitude (~1.3 × 10¹⁷ ticks), one double-precision ulp ≈ 30 000 ticks ≈ **3 ms**. So per-event drift up to a few milliseconds is the worst case, even though typical drift is sub-100µs. Drift sign is not constant (positive in this sample; negative is possible too at other magnitudes).

### Source vs. display precision

| Layer | Resolution | Notes |
| --- | --- | --- |
| Source data (e.g. UAL `Current.mdb` timestamps) | **100 ns** | Windows FILETIME ticks; commonly called "nanosecond" precision colloquially. |
| `EventInfo.TimeStamp` (struct field) | 100 ns | Lossless on the wire — what you write is what `XWF_AddEvent` receives. |
| Internal event store (this finding) | **~ms** (double-precision ulp) | Drift bounded by the ulp at the magnitude of the stored ticks. |
| Events viewer display cap | **4 decimal digits** (`.####`, 100 µs) | Hard ceiling configured via *Options → General → Date/time delimiter → Seconds: digits after decimal*. Even if storage were lossless, 100 ns ticks couldn't be rendered fully. |

So the analyst-visible precision is bounded by the smaller of (a) the storage ulp at the timestamp magnitude (~ms worst case) and (b) the viewer's 4-decimal display cap (100 µs).

### Implications for X-Tension authors

- **Don't dedup on the raw FILETIME quad** read back from `XWF_GetEvent` — it won't match what was stored. Use a **bucketed key** (e.g. `ft / 10_000_000` for whole seconds) on both the pre-flight and inline sides. Seconds-level buckets stay clear of the worst-case ulp; finer-grained buckets (10 ms, 100 ms) work if your data needs them but you must verify they exceed the ulp at the target FILETIME magnitude.
- **Equality comparisons of FILETIME between sent and stored events will always fail.** Bracket with a tolerance window if you must compare directly.
- The Events viewer **display** of sub-second precision (e.g. `21:47:26.2077`) is real to 100 µs but is the formatted double-store value, not the original FILETIME tick — so the last visible digit may differ from your source by up to the storage ulp.

An events-dedup key of `(nEvtType, ft/10_000_000, lpDescr)` — truncating the FILETIME to whole seconds — is the practical way to dedupe events for exactly this reason (sub-second jitter must not split otherwise-identical events).

## 8. Worked example — subcode picks for a UAL-ingesting X-Tension

Based on the dense sweep, here are concrete `nEvtType` values for an example Events-API X-Tension that ingests UAL (Unified Audit Logs) rows. Each gets a friendly Type label that semantically matches the UAL row type, with `Category = "Operating system"` on every row.

| UAL source_table | UAL timestamp_desc | Picked `nEvtType` | Resulting Type label | nFlags |
| --- | --- | ---: | --- | --- |
| CLIENTS | InsertDate (first time user/IP appeared) | **14005** | `Session start` | 0 |
| CLIENTS | LastAccess (most recent access) | **14010** | `Network data` | 0 |
| CLIENTS | Day### (daily access aggregation) | **14010** | `Network data` | `0x10` (date-only) |
| DNS | FirstSeen | **14011** | `Windows network data` | 0 |
| DNS | LastSeen | **14011** | `Windows network data` | 0 |
| ROLE_ACCESS | FirstSeen | **14012** | `Application resource` | 0 |
| ROLE_ACCESS | LastSeen | **14012** | `Application resource` | 0 |
| ROLE_ACCESS | InsertDate | **14012** | `Application resource` | 0 |

Description format (≤ 254 bytes ASCII; uppercase keys; empty/null fields skipped; role last):

```text
[CLIENTS:InsertDate] USER=lab\dc-1$ IP=10.0.0.10 HOST=dc-1 COUNT=1 ROLE="File Server"
[CLIENTS:InsertDate] USER=administrator IP=10.65.50.103 COUNT=5 ROLE="Active Directory Domain Services"
[CLIENTS:LastAccess] USER=lab\dc-1$ IP=10.0.0.10 HOST=dc-1 COUNT=1284 ROLE="File Server"
[CLIENTS:Day163] USER=lab\administrator IP=10.0.0.10 COUNT=1 ROLE="File Server"
[DNS:FirstSeen] IP=10.0.0.123 HOST=Laptop-Bob
[ROLE_ACCESS:FirstSeen] ROLE="Active Directory Domain Services"
```

Rules:

- Lead with `[source_table:timestamp_desc]` so the analyst can sort/filter by Description prefix even though all UAL rows share `Category = "Operating system"`.
- **Empty/null fields are dropped entirely** — see the second `CLIENTS:InsertDate` example, where the empty host produces no `HOST=` placeholder.
- `COUNT=` on every `CLIENTS` row (InsertDate, LastAccess, Day###). For InsertDate / LastAccess it's the cumulative `total_accesses` for the `(user, ip, host, role)` tuple — same value across both rows of the same tuple, but those rows can be far apart in the sorted timeline, so the redundancy saves the analyst a cross-reference.
- **`ROLE=` is always last.** When a row's full description would exceed 254 bytes, the formatter shortens just the role value to an acronym rather than hard-truncating earlier fields. Acronym rules:
  - Parens content used directly when present: `Web Server (IIS)` → `ROLE="IIS"`.
  - Single-token roles kept as-is: `DNS` → `ROLE="DNS"`.
  - First-word-already-an-acronym (all uppercase, ≥2 chars): `DHCP Server` → `ROLE="DHCP"`, `DNS Server` → `ROLE="DNS"` (avoids the `DS` collapse).
  - Otherwise first letters of each word, uppercased: `Active Directory Domain Services` → `ROLE="ADDS"`.

  The acronym only kicks in when the full description exceeds the cap (rare with realistic UAL data), so most rows display the full role.

The 254-byte budget is now mostly defensive — typical formatted rows are 50–130 bytes after these rules.

**Channels NOT used by this example X-Tension:**

- `XWF_SetItemType` — no clean-override path exists (see §5). All `nTypeStatus` values that display a custom label also produce a `mismatch detected` warning. To give UAL DBs a custom Type, ship a `File Type Categories User.txt` snippet (see §10) — that route is config-driven and clean.
- `XWF_SetItemInformation` for Categorization — not exercised by this probe.

**Channels used by this example X-Tension:**

- `XWF_AddEvent` — emit one event per UAL row, with the subcode/flags/description from the table above and `nItemID` set to the source `.mdb` item.
- `XWF_AddComment` — per-DB summary line on each `.mdb` item (e.g. `"UAL: 12,453 client accesses, 47 users, 2021-06-12 → 2024-03-15"`).
- `XWF_AddExtractedMetadata` — structured stats dump on each `.mdb` (top users, top IPs, role breakdown).
- `XWF_AddToReportTable` — one Label/Report Table named `UAL Source Databases`, with each `.mdb` item as a member, so the analyst can filter the directory browser to UAL sources with one click.

## 9. Open questions (residual, low priority)

Two minor items remain unanswered; neither blocks an Events-API X-Tension design:

- **Events viewer description-cell tooltip / details pane** — does the full > 254-byte content appear anywhere when the analyst clicks on the row, or is it truly lost? Worth a one-row spot check if curiosity strikes.
- **`nOfs` exhaustive test** — `nOfs = -2`, `nOfs = file_size + 100` — confirms whether the field is purely cosmetic or has any edge-case behavior. An Events-API X-Tension can leave it `-1` regardless.

### Out of scope (deliberately)

- **`XWF_SetItemInformation` for Categorization** — the manual notes X-Tensions can set the `Categorization` column (`unknown` / `irrelevant` / `notable` / `uncategorized`), but this example X-Tension does not use it and the probe did not exercise it.

## 10. Config-driven custom file typing — `File Type Categories User.txt`

Since `newly identified` is unreachable from `XWF_SetItemType` (§4), X-Ways' **purely config-driven** path is the way to label custom file types: the `File Type Categories User.txt` file in the install directory. Per the manual:

> *"You may store additional custom definitions of file types and categories in a separate file named 'File Type Categories User.txt', which will be read and maintained in addition to the standard definitions in 'File Type Categories.txt' and has the same structure and is not overwritten by updates of the software if contained in the installation directory."*

Format (from the manual + the reference `File Type Categories.txt` in the X-Ways install root):

- Categories begin with `***` then a space, followed by a category name.
- File-type lines are `+/-` then `<extension> <description>`, or `;<filename>;` for whole-filename matches.
- Optional `<TAB><rank><group>` suffix (e.g. `2P` = rank 2, group P).

For UAL, a snippet like this in an X-Ways `File Type Categories User.txt` config would let X-Ways' built-in detector recognise UAL DBs without any X-Tension code:

```text
*** Windows OS Internals
-;Current.mdb; Windows User Access Logging — current
-;SystemIdentity.mdb; Windows UAL — system identity
```

(Specific filename match because `.mdb` alone is too broad — Access DB extensions collide.) This approach is fully decoupled from the X-Tension and survives X-Ways upgrades. Use it whenever a clean custom type label is needed (no clean-override status integer exists — see §4), or as a complement (deploy the config + emit events).

## 11. X-Ways 21.8 re-validation (2026-06-05)

Verified against **X-Ways Forensics 21.8 (BYOD `xwb64.exe`)** on a logs snapshot (2026-06-05): the Event-Type taxonomy is unchanged between 21.7 and 21.8, as detailed below.

### `nVersion` decoding

The `XT_Init` `nVersion` argument is **`HIWORD = version × 100`, `LOWORD = service-release/build word`** — *not* a single number to divide by 100. Decoded correctly:

| X-Ways | `nVersion` (dec) | `HIWORD` | `HIWORD/100` | `LOWORD` |
| --- | ---: | ---: | ---: | ---: |
| 21.7 | 142213889 | 2170 | **21.70** | 769 |
| 21.8 | 142868737 | 2180 | **21.80** | 257 |

The `nVersion` DWORD decodes as `X-Ways v%.2f (…)` via `HIWORD(nVersion)/100.0`. (The `LOWORD` semantics — SR number vs. internal build — are not pinned down; both observed values are recorded above for future reference.)

### Event-Type taxonomy — unchanged from 21.7 (interim)

**Known-label + 20-codes-per-range sweep (2026-06-05):** zero mismatches. Every labeled subcode rendered exactly its 21.7 Type label, and the last-labeled subcode of every range was identical to 21.7:

| Category | Last labeled (21.7 = 21.8) |
| --- | ---: |
| File system | 118 (End of transaction) |
| Internal file metadata | 1015 (BPList Date Type) |
| Internet | 8007 (Modified) |
| Messaging | 10010 (Instant message) |
| Operating system | 14014 (Quarantine) |
| Event log | 15034 (Windows Powershell) |
| Registry | 20013 (Device attached) |

`Social networks` (12000–13999) and `Other` (30000+) still render the Category with **no** Type label, exactly as in 21.7.

**Full contiguous `0..30100` sweep (no gaps + high spots 40000/50000/99999) — CONFIRMED 2026-06-05:** swept all 30,104 subcodes; diffed rendered Category **and** Type against the 21.7 baseline. **Every subcode matches 21.7** — no new/renamed Type labels, no moved category boundaries, no new categories anywhere in the space. 21.7 §1 records `0 → Unknown`, `1..99 → ?`, `30000+ → ?`, and 21.8 renders identically.

**Bottom line:** there is **no API to define custom Event Types/Categories** in 21.8, and the built-in `nEvtType → Category/Type` table is **byte-for-byte identical to 21.7** across the entire documented space. The complete maps in §1 and in [xways-events-api.md](xways-events-api.md) apply unchanged to 21.8; the "pick the closest semantic subcode" guidance there stands.
