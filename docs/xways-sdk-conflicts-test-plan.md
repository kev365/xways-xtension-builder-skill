---
source: project register — conflicts surfaced by the 2026-08-14 SDK source review, plus carried-over ambiguities
type: research-summary
fetched: 2026-08-14
last_updated: 2026-08-14
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
- **Probe:** read-only. On a volume of known size, log
  `XWF_GetProp(hVolume, 0)`, `XWF_GetProp(hVolume, 1)`,
  `XWF_GetEvObjProp(hEv, 16)` and the size X-Ways shows in the case tree.
  One run settles it.
- **Risk:** none.

## 2. `XWF_SEARCH_CALLPSH` — does your own search reach your hit callback?

- **In tension:** the official prose says `XT_ProcessSearchHit` is not called
  for a search your X-Tension starts; the `XWF_SEARCH_CALLPSH` (`0x01000000`)
  flag name says otherwise; **no code anywhere** — SDK samples, Python bridge,
  C# tree, community bindings — has ever demonstrated `XWF_Search` at all
  ([xways-search-api.md](xways-search-api.md)).
- **Probe:** from `XT_Prepare`, call `XWF_Search` with a term guaranteed to hit
  (a string planted in a test file), once with and once without `CALLPSH`;
  count `XT_ProcessSearchHit` invocations and log every hit's
  `nSearchTermID`/offsets. Also record whether the search's hits appear in the
  GUI hit list afterwards (`DISPLAYHITS` on/off).
- **Risk:** **mutating** — creates search hits and terms in the case (8,191
  search-term cap per case). Throwaway case only.

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
- **Probe:** read-only sweep: for every item (or a large sample), compare
  `XWF_GetItemSize(id)` with `XWF_GetSize(hItem, NULL)` and with
  `XWF_GetProp(hItem, 0/1/2)`; log only mismatch rows with item type,
  deletion state, and whether the item is compressed/resident. NTFS resident
  files, slack semantics and carved files are the likely divergence classes.
- **Risk:** none (open items with `0x0002` suppress-errors).

## 4. `XT_Init` version-word decode

- **In tension:** three vendor models and one community model agree the first
  parameter packs `version(hi16) | SR(8) | language(8)` — but the current
  official header calls it a bare `nVersion` and no live host has confirmed the
  arithmetic ([xtension-invocation.md](xtension-invocation.md)).
- **Probe:** trivial — log the raw DWORD and the decoded triple in `XT_Init`
  on a host whose exact version/SR is known from the About box; run on two
  different SRs if available.
- **Risk:** none. Piggyback on any other probe run.

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
- **Extended 2026-08-14 (cpp template, found by dogfooding a probe scaffold):**
  two more template claims now in tension with the conventions/SDK:
  (a) the cpp template's `XT_Init` **logs before checking
  `XT_INIT_QUICKCHECK`** — it has no `nFlags & 0x20` guard at all, violating
  the invocation page's own rule ("return 1 on QUICKCHECK without doing real
  work"); the mock-host harness verifies the guard, so the template fails that
  test as shipped. (b) the template's banner prints `nVersion / 100.0` as
  "X-Ways build %.2f" — correct only if the parameter is a bare build number;
  if the packed-word decode (entry 4) is confirmed, this prints garbage
  (142868737 / 100 for 21.8 SR-1). Both are template *edits* deferred to the
  post-probe pass.

## 7. `xwf.GetHashValue` overflow on wide hashes

- **Claim (source-read, unconfirmed at runtime):** the bridge hex-encodes into
  `wchar_t[33]` but writes `hashBits/4` characters — 40 for SHA-1, 64 for
  SHA-256 — a stack overflow inside the bridge DLL
  ([xways-python-bridge.md](xways-python-bridge.md)).
- **Probe:** throwaway case with the snapshot hash type set to SHA-256, hashes
  computed; one Python script calling `xwf.GetHashValue(id, 1)` on one item.
  Expected outcomes: crash, silent corruption of the returned string, or —
  if the compiler's stack protector catches it — host termination.
- **Risk:** **crash-risk** by design (that's the hypothesis). Throwaway case,
  nothing else open. An MD5-typed control run first proves the call path.

## 8. `XWF_GetItemName` beyond MAX_PATH

- **Claim (vendor comment, age unknown):** QTest's `// Leads to a crash in
  WinHex for filenames that exceed MAX_PATH`. Possibly fixed since — 21.5
  Beta 6 made "various functions" handle bad IDs more gracefully, but that
  announcement is about IDs, not name length. Our own pointer-lifetime testing
  ([xways-snapshot-mutation.md](xways-snapshot-mutation.md)) never used
  over-long names.
- **Probe:** create an item via `XWF_CreateFile` with a >260-wchar name (or
  add evidence containing one via `\\?\` paths), then call `XWF_GetItemName`
  and concatenate into a `std::wstring` exactly as QTest does.
- **Risk:** **crash-risk + mutating** (item creation). Throwaway case.

## 9. `0x0040` search-hit flag double-listing

- **Carried over** from [xways-search-api.md](xways-search-api.md): the
  official page assigns `0x0040` two meanings back to back ("include in case
  report" / "in slack or uninitialised end portion"). `Luhn.cpp` doesn't touch
  it; no other source weighs in.
- **Probe:** run a search guaranteed to hit both in-file content and slack
  (plant the needle in both), log `nFlags` per hit in `XT_ProcessSearchHit`,
  and separately toggle "include in report" on a hit in the GUI and re-read
  its flags via a second pass. Whichever meaning tracks observation wins.
- **Risk:** search-hit creation — throwaway case.

## Working the list

Cheap and safe first: **4 needs no case at all** (it rides along on any run);
5 was closed the same day this register was written, by exactly the promised
PE-import read.

**Probe status (2026-08-14):** a read-only probe X-Tension covering entries
1, 3 and 4 exists — scaffolded *with the authoring skill* (its first end-to-end
dogfood) and verified under a **mock host**: a console EXE that exports stub
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
