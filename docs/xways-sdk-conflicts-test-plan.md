---
source: project register — conflicts surfaced by the 2026-08-14 SDK source review, plus carried-over ambiguities
type: research-summary
fetched: 2026-08-14
last_updated: 2026-08-16
author: project
---

# Open conflicts — and how to test each one

A register of claims where two sources this knowledge base trusts disagree, or
where a single hazardous claim has never been verified. Each entry names the
sources in tension and a concrete probe design. **Nothing here is resolved** —
when an entry is settled empirically, move the finding into the owning page and
strike the entry.

Probe designs assume the project's standard probe shape: a throwaway C++
X-Tension built from the cpp template, run against a **disposable case** with
the "one-shot snapshot operation" pattern (do everything in `XT_Prepare`, log
via `XWF_OutputMessage`, touch nothing unless the test requires it). Entries
marked **mutating** or **crash-risk** must never run against a real case.

## Contents

- 1\. `XWF_GetProp(hVolume, 0)` — bytes or MB?
- 2\. `XWF_SEARCH_CALLPSH` — does your own search reach your hit callback?
- 3\. `XWF_GetItemSize` vs `XWF_GetSize` — "deviant sizes"
- 4\. `XT_Init` version-word decode
- 5\. Which Python DLL does the shipped bridge bind?
- 6\. Python template README vs SDK statements
- 7\. `xwf.GetHashValue` overflow on wide hashes
- 8\. `XWF_GetItemName` beyond MAX_PATH
- 9\. `0x0040` search-hit flag double-listing
- Working the list

## 1. `XWF_GetProp(hVolume, 0)` — bytes or MB?

- **In tension:** the SDK's `QTest.cpp` prints the raw value of
  `XWF_GetProp(hVolume, 0, nullptr)` labelled `" MB"`, without dividing.
  [xways-getprop-reference.md](xways-getprop-reference.md)'s empirical sweep
  and the Python bridge's `GetPhysicalSize` both treat property 0 as a plain
  size. The 2026-05-03 sweep note says the volume's prop 0 "matches
  `XWF_GetEvObjProp` property 16" (documented as size **in bytes**) — which
  argues the vendor label is just sloppy, but a *volume handle* vs *item
  handle* difference has not been excluded.
- **RESOLVED 2026-08-15** (throwaway probe X-Tension on 21.9 Beta 1, 64 MiB E01):
  `GetProp(hVol,0) = GetProp(hVol,1) = GetSize(hVol,NULL) =
  GetEvObjProp(hEv,16) = 67108864` — exactly the image size. **Bytes.**
  QTest's `" MB"` label is simply wrong. Also observed:
  `GetProp(hVol,2)` (valid data length) returns `-1` on a volume handle.
  Finding recorded in [xways-getprop-reference.md](xways-getprop-reference.md).

## 2. `XWF_SEARCH_CALLPSH` — does your own search reach your hit callback?

- **Documentation answer found 2026-08-15**, in official prose missed by the
  original distillation: *"Only if the XWF_SEARCH_CALLPSH flag is specified,
  X-Ways Forensics will call XT_ProcessSearchHit(), if exported, for each
  hit... Other X-Tensions' XT_ProcessSearchHit() will not be called."* So the
  documented design is: not called by default, **CALLPSH is the opt-in**.
- **Empirical result (21.9 Beta 1, CLI-launched X-Tension, `XT_Prepare`,
  `hVolume=0`, LOGICAL, CodePages supplied): `CALLPSH` delivered ZERO
  `XT_ProcessSearchHit` callbacks** — twice, with two different needles, the
  second (`<?xml version='1.0' enco`) taken verbatim from an in-scope ordinary
  file that the search must hit. Baseline (no CALLPSH) also 0, as documented.
  **Caveat closed 2026-08-15 (GUI read of the saved case): the search found
  2,658 hits** — the term list shows `<?xml version='1.0' enco (2,658)` — and
  `CALLPSH` delivered zero of them. "Hits found, callbacks withheld" is
  confirmed. (The morning's `$Boot` needle shows `(0)` hits — logical search
  genuinely excludes metafile content, validating the ordinary-file needle
  rule.) **GUI retest (same day): identical result** — active volume set,
  snapshot live, `rv=0`, zero callbacks; and the post-search runtime 217
  reproduced in the GUI session too. Both behaviours are
  **context-independent on 21.9 Beta 1**. **CONFIRMED ON A RELEASE BUILD —
  21.8 SR-5, 2026-08-15, text-bearing corpus:** the probe's own `XWF_Search`
  with `CALLPSH` delivered **0 `XT_ProcessSearchHit` callbacks** for a term
  the GUI term list credits with **4 hits** (`WebFetch(domain:r (4)`), and the
  run ended with the same runtime 217 crash. **So neither B9(b) nor B9(c) is a
  beta regression** — both reproduce on shipping 21.8 SR-5. Note the contrast
  that isolates the flaw: the callback mechanism itself is healthy on 21.8
  (an *analyst-driven* search delivers hits per-hit, verified same day) — it
  is specifically the **`XWF_Search` + `CALLPSH`** path that returns hits to
  the GUI but not to the X-Tension.
- **Bonus findings from the same probes** (see
  [xways-search-api.md](xways-search-api.md)): a **NULL `pCPages` access
  violates inside `XWF_Search`** (0xC0000005 — CodePages is mandatory in
  practice); each `XWF_Search` call **re-enters your own `XT_Finalize`**
  (op=2) before returning; and **every run in which `XWF_Search` executed
  ended with Delphi runtime error 217 at the same address during shutdown**,
  even when the searches completed cleanly — a reproducible host bug candidate
  (tracker B9).

## 3. `XWF_GetItemSize` vs `XWF_GetSize` — "deviant sizes"

- **In tension:** `QTest.cpp` ships a disabled checker comparing the two under
  the label `"Deviant sizes for …"` — evidence of vendor suspicion, not a
  documented difference. The official page (re-read 2026-08-14) marks
  `XWF_GetSize` **deprecated** ("call XWF_GetProp() instead" on 19.9 SR-7+) and
  defines its modes precisely: `NULL` = volume size / **physical** file size,
  `(LPVOID)1` = logical size, `(LPVOID)2` = valid data length. So QTest's
  `GetSize(hItem, NULL)` vs `GetItemSize(nItemID)` comparison is
  physical-vs-item-size — deviance is *expected by design* for resident,
  compressed and slack-bearing files; the open question is only whether
  `GetItemSize == GetSize(1) == GetProp(1)` holds universally.
- **RESOLVED for a first corpus, 2026-08-15** (throwaway probe X-Tension, 21.9 Beta 1,
  310-item snapshot of a 64 MiB E01): **309/310 items had all five size views
  identical** (`GetItemSize` = `GetSize(NULL)` = `GetSize(1)` = `GetProp(0)` =
  `GetProp(1)`), and `GetProp(0/1)` matched `GetSize(NULL/1)` on every single
  item — the documented deprecation mapping holds exactly. The one deviant was
  the **virtual "Free space" item**: `GetItemSize = -1` (documented "unknown
  size") while `GetSize` returns `0` — so the two APIs disagree on how to say
  "no size", which is likely all QTest's "deviant sizes" checker ever caught.
  **Residual caveat:** the corpus had no NTFS-resident, compressed or carved
  items; re-run the sweep on a richer image before calling the equality
  universal.

## 4. `XT_Init` version-word decode

- **In tension:** three vendor models and one community model agree the first
  parameter packs `version(hi16) | SR(8) | language(8)` — but the current
  official header calls it a bare `nVersion` and no live host has confirmed the
  arithmetic ([xtension-invocation.md](xtension-invocation.md)).
- **RESOLVED 2026-08-15** (throwaway probe X-Tension on a host banner-identified as
  "X-Ways Forensics BYOD 21.9 Beta 1 x64"): raw `nVersion = 0x088E0001`
  decodes as hi16 `2190` → **v21.9**, byte1 `0` → **SR-0** (a Beta 1 has no
  SR), byte0 `1` → language 1. The packed-word decode is confirmed on a live
  host. Bonus: `nFlags = 0x89` = `XWF | BETA | ALTERED_SEARCH_PATH` — all
  three bits exactly as the flag table predicts for a beta with the
  altered-search-path default on. Recorded in
  [xtension-invocation.md](xtension-invocation.md). Consequence: the cpp
  template's `nVersion / 100.0` banner (entry 6) is now confirmed wrong —
  it prints `1435238.41` on this host.

## 5. Which Python DLL does the shipped bridge bind?

**RESOLVED 2026-08-14** — PE-import read of the shipped `XT_Python.dll`
(hash-verified against the official SourceForge zip): it links
**`python312.dll`**. Both readmes are wrong. The same read surfaced an
unexpected second finding — an undocumented load-time dependency on the
vendor's `ins.dll`, which ships with X-Ways itself, not with the bundle.
Findings recorded in [xways-python-bridge.md](xways-python-bridge.md); this
entry is kept for numbering stability.

## 6. Python template README vs SDK statements

- **In tension:** the template README says load via "Tools → Run X-Tension… →
  select `XT_Python.dll`, then point it at your `.py`"; the SDK readme says add
  the DLL to the X-Tensions list with "+", then "…" to choose scripts — and the
  bridge source shows the script picker is its `XT_About` handler writing
  `Python.cfg`. The README's "3.10 or 3.12" version line inherits conflict 5.
  The template's `COMMENT_*` constants (0/1/2) are attributed to "official API
  docs" but the bridge passes the value through uninspected, so only the C-API
  page backs them.
- **Probe:** UI walk-through on a live install: which gesture actually reaches
  the script picker, and does the "…" path exist in current builds? Then
  `AddComment` with 0/1/2 against a file with an existing comment and read back.
- **Risk:** comment writes are **mutating** — throwaway case.
- **Resolution target:** template README edits (deferred by decision — this
  pass documents, a later pass fixes the README against the probe result).
- **Extended 2026-08-14 (cpp template, found while scaffolding a real probe from it):**
  two more template claims now in tension with the conventions/SDK:
  (a) the cpp template's `XT_Init` **logs before checking
  `XT_INIT_QUICKCHECK`** — it has no `nFlags & 0x20` guard at all, violating
  the invocation page's own rule ("return 1 on QUICKCHECK without doing real
  work"); the mock-host harness verifies the guard, so the template fails that
  test as shipped. (b) the template's banner prints `nVersion / 100.0` as
  "X-Ways build %.2f" — correct only if the parameter is a bare build number;
  if the packed-word decode (entry 4) is confirmed, this prints garbage
  (142868737 / 100 for 21.8 SR-1). **Both fixed 2026-08-15** — after the
  packed-word decode was confirmed live, all three templates (cpp, wrapper,
  python) gained the QUICKCHECK guard and the correct version decode, the
  wrapper's UI init moved behind the guard, and the Python README's version
  claim and script-registration path were corrected against the bridge
  findings. Compile-verified via fresh scaffolds of both C++ templates.

## 7. `xwf.GetHashValue` overflow on wide hashes

- **Claim (source-read, unconfirmed at runtime):** the bridge hex-encodes into
  `wchar_t[33]` but writes `hashBits/4` characters — 40 for SHA-1, 64 for
  SHA-256 — a stack overflow inside the bridge DLL
  ([xways-python-bridge.md](xways-python-bridge.md)).
- **VERIFIED BY SOURCE 2026-08-15 — the overflow is unambiguous in
  `Python.cpp`.** `hashStr` is `wchar_t[33]` (`:1157`) with the author's own
  comment "256/8=32, plus zero-terminator" — that is the bug: 256 **bits** =
  32 **bytes** = **64 hex chars**, so the buffer was sized as if bytes were
  chars. The loop (`:1158`) iterates `i` over *bytes* and writes two chars per
  byte at `hashStr[2i]`/`[2i+1]`; for SHA-256 that reaches index 63 in a
  33-element buffer (a 62-byte stack overflow), and `:1165` reads 64 wchars
  back. **Threshold: any hash type wider than 128 bits overflows** — SHA-1
  (160) by 7 chars, SHA-256 (256) by 31; MD5/MD4/RIPEMD-128 are exactly safe,
  which is why it went unnoticed. No runtime needed to establish the defect;
  the code cannot do otherwise.
- **Runtime confirmation (optional) is gated on a Python 3.12 install.** The
  bundle's `python312.dll` needs a matching 3.12 environment for
  `Py_Initialize`; the test machine had only 3.13/3.14 (2026-08-16). A probe script
  and setup notes are staged (outside this repo) for whenever a 3.12 install
  exists — but the source proof is the stronger artifact for the report.
- **Risk:** the runtime path is **crash-by-design**; throwaway case only.

## 8. `XWF_GetItemName` beyond MAX_PATH

- **Claim (vendor comment, age unknown):** QTest's `// Leads to a crash in
  WinHex for filenames that exceed MAX_PATH`. Possibly fixed since — 21.5
  Beta 6 made "various functions" handle bad IDs more gracefully, but that
  announcement is about IDs, not name length. Our own pointer-lifetime testing
  ([xways-snapshot-mutation.md](xways-snapshot-mutation.md)) never used
  over-long names.
- **RESOLVED 2026-08-15 (probe on 21.8 SR-5): does not reproduce.** Created an
  item with a 304-char name via `XWF_CreateFile` (parent = 0 / root worked),
  then ran QTest's exact crashing pattern — `XWF_GetItemName` returned all 304
  chars into a `std::wstring` with **no crash**. QTest's SDK-era warning is
  stale; the long-name path is safe on 21.8 SR-5. (Retest before relying on it
  for names far beyond 304, or on much older hosts.)
- **Probe (as run):** create an item via `XWF_CreateFile` with a >260-wchar
  name, then call `XWF_GetItemName` and concatenate into a `std::wstring`
  exactly as QTest does.
- **Risk:** **crash-risk + mutating** (item creation). Throwaway case.

## 9. `0x0040` search-hit flag double-listing

- **Carried over** from [xways-search-api.md](xways-search-api.md): the
  official page assigns `0x0040` two meanings back to back ("include in case
  report" / "in slack or uninitialised end portion"). `Luhn.cpp` doesn't touch
  it; no other source weighs in.
- **Partial data (2026-08-15, 21.8 SR-5):** 16 plain in-content hits logged
  via an analyst-driven search all carried `nFlags = 0x0000` — ordinary
  content hits assert neither meaning. Discriminating the bit still needs a
  slack hit and/or a report-flagged hit, per the original probe design below.
- **Probe:** run a search guaranteed to hit both in-file content and slack
  (plant the needle in both), log `nFlags` per hit in `XT_ProcessSearchHit`,
  and separately toggle "include in report" on a hit in the GUI and re-read
  its flags via a second pass. Whichever meaning tracks observation wins.
- **Risk:** search-hit creation — throwaway case.

## Working the list

**Four of nine entries are now closed** (1, 3-first-corpus, 4, 5), all within
a day of the register being written — 5 by a static PE read, the rest by one
13-second X-Ways run. One "settled" claim was then **un-settled by the
operator**: the X-Tension-execution prompt appeared on screen and was clicked
by a human — msglog nonetheless logged `Prompt | … | Override: OK`, so
**msglog's `Override: OK` is not evidence of auto-confirmation**; whether
`Override:1` covers this prompt with nobody at the keyboard remains open (the
dialog's "Do not display this message again" checkbox is the documented
unattended route). A UAC elevation prompt also preceded each launch. Genuinely
settled the same day: `XWF_SelectVolumeSnapshot`
**does** return the item count on a modern host (rv 310 == `GetItemCount` 310,
the v20.9+ community claim). Remaining open: 2, 6 (probe parts), 7, 8, 9 —
the mutating and crash-risk tier.

**Probe status (2026-08-14):** a read-only probe X-Tension covering entries
1, 3 and 4 exists — scaffolded *with the authoring skill* (its first end-to-end
first real-world use) and verified under a **mock host**: a console EXE that exports stub
`XWF_*` functions, exploiting the fact that X-Tensions resolve the API against
the host EXE's export table. All entry points sequence correctly, QUICKCHECK
stays quiet, the mismatch classifier buckets engineered deviances, 0 failures.
The mock proves harness-and-DLL mechanics only — entries 1/3/4 still need a
real X-Ways run (Tier 2) for ground truth. **1 and 3 are read-only** and can share one probe
X-Tension. 2, 6, 7, 8, 9 each mutate or risk crashing and get their own
disposable case. Entries 7 and 8 exist to *confirm a hazard*, not to enable a
feature — a "still crashes" result just hardens the existing warnings.

When building probes, follow the whitelist rule from
[xways-getprop-reference.md](xways-getprop-reference.md): probe exactly the
named calls, no range sweeps — this register exists partly because a blind
sweep once called `XWF_VSPROP_RESET` without knowing what it was.
