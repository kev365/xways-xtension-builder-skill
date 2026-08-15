# Changelog

All notable changes to this project are documented here. Versions follow
[Semantic Versioning](https://semver.org/).

## [Unreleased]

### Added

- **Forum sweep of the 21.8 and 21.9 announcement threads** (read in full
  2026-08-12), which surfaced three API facts the knowledge base did not have:
  - **`XWF_GetCellText` return codes and its multi-threading restriction.**
    21.8 SR-5 added a new return code `-3` (exception, now caught by the
    function rather than reaching the X-Tension) and, on the official page,
    a restriction we had never recorded: the **Metadata** column and the columns
    depending on it (generator signature, device type) may be inaccessible
    during multi-threaded refinement, with X-Ways advising the call be made from
    `XT_Finalize`. That is independent vendor corroboration of the shape
    `item-collection` and `threading-model` already prescribe.
  - **`XWF_OpenItem()` could fail from `XT_ProcessItem()` for files in nested
    archives** under multi-threaded refinement — fixed in 21.8 SR-4, and absent
    from the official page, so forum-only.
  - **The host watchdogs refinement threads** since 21.8 Preview 5, terminating
    and resuming ones unresponsive for ~15 minutes. Recorded with its scope
    flagged unverified, and carried into `subprocess-stdio` as a caution about
    the template's `WaitForSingleObject(..., INFINITE)`.

  Also recorded that 21.9 Previews 2–6 and Beta 1 were read and contain nothing
  API-facing, so the next sweep need not re-read them.

- **Second forum sweep — the 21.5, 21.6 and 21.7 announcement threads**, none of
  which had ever been read (the knowledge base cited every thread from 19.0 to
  21.4, then jumped to 21.8). Four more facts:
  - **Hash-type IDs changed in 21.5 Preview 3** — three changed value, six were
    deprecated, with the current list in the `XWF_GetVSProp()` documentation.
    Bears directly on the open `nParam` question in `xways-snapshot-mutation.md`:
    a hash-type number taken from older material may now name a different
    algorithm.
  - **X-Ways prompts before loading an X-Tension since 21.5 Beta 5**, explicitly
    including command-line-triggered runs — so an unattended script cannot assume
    it starts unattended. Recorded against `XT:` in `xways-command-line.md`.
  - **The `[XT]` log prefix could be separated from its message** when an
    X-Tension logged from multiple threads, fixed in 21.6 Beta 4. A display
    artefact on older hosts, not lost data.
  - **The 21.7 SR-4 announcement lists the label-API rename pairs in a
    misleading order**, which reads as a positional mapping and is not one. The
    correct role-based pairing was already documented; the announcement is now
    cited as the source of the trap.

- **The forum's structure and access limits are recorded.** Of five boards only
  Public Announcements is readable without credentials; the other four return
  401, access being limited to users with active update maintenance. One of them
  is the **X-Tension programming section** (announced 2021-03-26) — so the
  forum's most directly relevant board has never been mined, and everything
  distilled here comes from the public announcement threads alone.

- **Review of two community bindings** — the `v2-develop` branch of
  [xwf-api-rs](https://github.com/ThomasVogl/xwf-api-rs) (Rust, LGPL-3.0, read at
  `4f14ef9`, 2026-07-14) and the vendored `XT_API.pas` inside
  [XT_ExtractDocsMail](https://github.com/gaiacalamari/XT_ExtractDocsMail-)
  (Free Pascal, Apache-2.0). Both are working code rather than documentation,
  and between them they closed gaps the official pages had left open:
  - **The `XWF_SEARCH_*` family** (23 flags) and the **`XWF_CTR_*` container
    flags** (10) — the two constant groups the coverage map named as genuinely
    unexplored. The container values were confirmed against the official page;
    the search values are recorded as a lead, since the Pascal binding is a
    v18-era snapshot.
  - **`XWF_ITEM_INFO_FLAGS_SET` / `_REMOVE` are 64 / 65**, confirmed
    independently by both bindings.
  - **`XWF_GetItemName(nItemID | 0x80000000)` returns the alternative name**
    (v19.9+), and `XWF_GetItemCount((LPVOID)1)` returns the selected-item count.
  - **`ItemInfoFlags` extended from 14 bits to 33**, including the three above
    bit 31 that a `DWORD` would silently drop.
  - **Hash-type codes and their byte sizes** (1..19), needed to size every
    buffer that receives a hash value — recorded as provisional, since 21.5
    Preview 3 renumbered part of the list.
  - **`XWF_SelectVolumeSnapshot` returns the item count from v20.9**, where it
    previously returned nothing.
  - **`XT_Init`'s first parameter is a packed version word**, not an opaque
    token — major / minor / service release / GUI language.

- **`docs/xways-evidence-containers.md`** — new page covering
  `XWF_CreateContainer` / `XWF_CopyToContainer` / `XWF_CloseContainer`: the
  `XWF_CTR_*` flags, the copy modes, the rule that creating a second container
  silently closes the first, and the opposite success polarity of copy (`0`) and
  close (`1`).

- **Unattended BitLocker, in `xways-command-line.md`** — the `Passwords.txt`
  requirements behind `Override:4` / `Override:5` (UTF-16 encoding, general vs
  case-specific collection, one entry per line) and the ordering constraint that
  `RVS:~` must precede `XT:`, because an X-Tension reading refinement output
  cannot distinguish "no matches" from "nothing computed yet". Sourced from the
  XT_ExtractDocsMail README.

- **A parent-walk termination guard** in `build-and-iteration-gotchas.md`:
  `XWF_GetItemParent` can return the item's own ID, so the documented
  walk-until-`-1` loop needs a self-parent check and an iteration cap.

- **Full review of the vendor SDK source drops** (the 2024-05-31 zip, git HEAD
  `c46a1bd2`, and the XT_Python binary bundle) — the last unreviewed authority.
  Three new pages:
  - **`docs/xways-python-bridge.md`** — the `xwf` module's real surface,
    distilled from reading the bridge's `Python.cpp` in full: the 46-method
    table (only ~27 distinct `XWF_*` calls behind it), the 8 forwarded entry
    points, the generated-source dispatch mechanism (handles as decimal ints,
    ASCII-only call boundary, every configured script gets every callback), and
    a verified bug table — `GetHashValue` stack overflow for hashes over
    128 bits, `GetHashSetAssocs` ~1600-wchar cap plus a per-call leak,
    silent short reads in `xwf.Read`, mangled UTF-16 search-hit text, and the
    fixed `XT_Prepare → 1` that makes script return values unpropagatable.
    Also: `XT_ProcessSearchHit` **is** bridged to Python (the vendor's own
    spreadsheet says otherwise), and the readme's `import XWF` never worked —
    the module is lowercase `xwf`.
  - **`docs/xways-sdk-source-notes.md`** — the vendor's per-function status
    spreadsheets (binary vocabulary: 24 functions `tested`, 52 merely
    `provided` — the vendor's samples never exercised three quarters of the
    API), the drop divergence (git HEAD's XT_Python project cannot compile —
    `Python.cpp` still uses the `CallerInfo` struct the same drop's header
    deleted), three inconsistent vendor models of `XT_Init`'s first parameter,
    a vendor-sample bug catalog, the C# facts (the official binding wraps
    exactly 3 functions; "C# Search Test" never calls `XWF_Search`), and the
    file-system-ID table from `Sample.py`.
  - **`docs/xways-sdk-conflicts-test-plan.md`** — a 9-entry register of claims
    where trusted sources disagree, each with a probe design and risk class:
    `GetProp(hVolume, 0)` bytes-vs-MB, `XWF_SEARCH_CALLPSH` (no code anywhere
    has ever called `XWF_Search`), `GetItemSize` vs `GetSize` "deviant sizes",
    the version-word decode, the Python-DLL version contradiction, template
    README tensions, the `GetHashValue` overflow, the `MAX_PATH` name crash,
    and the carried-over `0x0040` flag ambiguity.

- **First register entry closed the same day — and a new binary-only finding.**
  A PE-import read of the shipped `XT_Python.dll` (hash-verified against the
  official SourceForge zip) settled the Python-version contradiction: it links
  **`python312.dll`**; both readmes are wrong. The same read found an
  **undocumented load-time dependency on `ins.dll`** — the vendor's private
  instrumentation library, absent from the bundle but shipped with X-Ways
  itself — which is why the DLL only loads from the XWF main folder and fails
  with `ERROR_MOD_NOT_FOUND` anywhere else, and why an out-of-process bridge
  harness needs an `ins.dll` beside the host EXE. The binary's export table
  was also verified: exactly the 8 entry points, `XT_ProcessSearchHit`
  included.

- **First end-to-end dogfood of the skill, via a probe X-Tension and a mock
  host.** `new-xtension.ps1` and `build-xtension.ps1` ran clean end to end
  (scaffold → identity → build gate, `-NoDeploy`). The probe covers register
  entries 1/3/4 and was verified under a **mock host** — a console EXE that
  exports stub `XWF_*` functions, which works because X-Tensions resolve the
  API against the host EXE's export table. 0 failures. The dogfood surfaced
  two cpp-template defects, recorded (not fixed) per the conflicts-register
  decision: `XT_Init` logs before checking `XT_INIT_QUICKCHECK` (no `0x20`
  guard, violating the skill's own convention), and the version banner's
  `nVersion / 100.0` arithmetic is wrong if the packed-word decode is
  confirmed. Also re-read from the official page: `XWF_GetSize` is
  **deprecated**, with `NULL` = physical / `1` = logical / `2` = valid data
  length — reframing QTest's "deviant sizes" as physical-vs-logical by design.

- **First live X-Ways runs — headless, on 21.9 Beta 1 — close four register
  entries and two adjacent unknowns.** Two 13-second command-line runs
  (`NewCase: AddImage: Override:1 XT:… auto`) against a 64 MiB E01:
  - **Register 1:** `XWF_GetProp(hVolume, 0)` returns **bytes** (equal to the
    exact image size and to `GetEvObjProp(hEv,16)`); QTest's `" MB"` label is
    wrong. `GetProp(hVol, 2)` returns `-1` on a volume handle.
  - **Register 3 (first corpus):** across 310 items, all five size views were
    identical on 309; the sole deviant is the virtual "Free space" item, where
    `GetItemSize` says `-1` (unknown) and `GetSize` says `0` — the two APIs
    disagree only on how to spell "no size". Resident/compressed corpora still
    untested.
  - **Register 4:** the version word decodes exactly as predicted —
    `0x088E0001` → v21.9 SR-0 lang 1 on a host banner-identified as 21.9
    Beta 1 — and `nFlags = 0x89` matched `XWF | BETA | ALTERED_SEARCH_PATH`.
    The cpp template's `nVersion / 100.0` banner is therefore confirmed wrong.
  - **Corrected the same day:** the X-Tension-execution prompt was in fact
    clicked by the operator, yet msglog recorded `Prompt | … | Override: OK` —
    so that msglog line is **not** evidence of auto-confirmation, and whether
    `Override:1` covers the prompt unattended remains open. A UAC elevation
    prompt also precedes each launch on this host. The runs were
    operator-assisted, not fully unattended.
  - **`XT_ACTION_RUN` (op 0) delivers no per-item callbacks under `0x01`** —
    confirmed live; the probe grew a self-driving enumeration
    (`SelectVolumeSnapshot` → `GetItemCount` → `OpenItem`/`Close`) for
    command-line use, which also **confirmed the v20.9+ claim that
    `XWF_SelectVolumeSnapshot` returns the item count** (310 == 310).
  - Also recorded: `RVS:~` fails on a fresh install (`Error #9 Cannot load "?"`
    — the `~` needs stored refinement settings).

- **Vendor-sample findings folded into existing pages:** `Luhn.cpp`'s hit-
  mutation idioms (the `0x0008` discard flag confirmed in vendor code, in-place
  `nLength` rewrite, the `iSize` version gate, and the `nCodePage == 1200` ⇒
  UTF-16LE byte-count convention) into the search page; the
  `#pragma pack(2)`-without-push/pop hazard, QTest's crash/perf warnings, and
  the vendor's NULL-probe version-compat pattern into the gotchas page; the
  selective-`.def`-export idiom and SDK corroboration of the version-word
  decode into the invocation page.

### Fixed

- **`XWF_VSPROP_RESET` is property 90 — and the 2026-05-03 sweep called it
  blind.** It forces a new volume snapshot and discards the previous one without
  the usual warning about losing tags, search hits and refinement results. The
  sweep had recorded it as *"live, returns 1 zero byte, identity unknown,
  probably status flag"*. Now documented with the danger it carries, and the
  whitelist-not-range lesson stated where the sweep lives.

- **`XWF_GetItemType`'s return value was documented with the wrong legend.**
  The page listed the four write-side `XWF_SetItemType` status values against a
  read-side call whose official legend has seven — read-side `2` is *totally
  unknown* where write-side `2` is *confirmed*, so the old table inverted the
  meaning of the field. Also corrected: the buffer length lives in the lower
  **word**, not the low 24 bits.

- **`rv = 256` under `XWF_GetItemType`'s `0x80000000` flag was misread** as
  "matches the `nBufferLen` we passed". It decodes as consistency `1` (OK) and
  status `0` (not verified) — the flag packs file-format consistency into the
  second-lowest byte. The two values collided because the test buffer happened
  to be 256 characters.

- **The `XWF_SetHashValue` / `XWF_GetHashValue` round-trip that "did not work"
  was two malformed calls.** `nParam` is a slot selector (`1` primary, `2`
  secondary), never a hash type, and `0` is undefined; `XWF_GetHashValue`'s
  buffer is an in/out parameter that must open with a `DWORD` naming what you
  want. The v21.5 hash-renumbering lead cited for months was unrelated. Both
  calls now documented, with the general point that a zeroed buffer is not a
  neutral input to this API.

- **`XWF_GetEvObjProp` 30 / 31 were recorded as "(TBC) likely time-zone
  related".** They are the reference and display time-zone biases, in minutes,
  in the low 16 bits, with three sentinel values and an optional
  `DaylightSavingsDefinition` struct. Noted that `xwf-api-rs` maps the two the
  wrong way round.

- **`xwf-api-rs` was attributed as MIT in two pages.** It is **LGPL-3.0**.

- **Two resolved leads closed out** in `xways-api-recency-research.md`: the
  proposed `XWF_AddToReportTable` flag-bit sweep is unnecessary (`0x0100` and
  `0x1000` are documented as GUI-application defaults, and the sweep would have
  mutated report-table state to learn something already written down), and the
  `EvObjPropType` / `GetItemType` cross-references are done.

- **Two more citations to a document that doesn't say it.** The claims that the
  Python bridge lacks `AddEvent`/`GetEvent` and `XWF_GetUserInput` were
  attributed to "the XT_Python readme shipped with the SDK"; the readme is a
  positive list and never addresses either. Both conclusions are true and now
  cite the bridge's actual method table. The user-input page also gains the two
  file dialogs the bridge *does* ship (`xwf.GetOpenFileName` /
  `xwf.GetSaveFileName`), which the tkinter advice had overlooked.
- **The threading page never mentioned Python.** It now states that a Python
  X-Tension is single-threaded by construction — the bridge hard-returns `1`
  from `XT_Init` with the vendor's own "not thread-safe" comment, and the
  script's return value is not propagated.
- The external-tool page's "just embed Python via the XT_Python bridge" is now
  qualified with the bridge's install requirements and API gaps.
- Coverage map regenerated: **72/27/0 → 73/26/0**, plus a pointer to the
  per-language exposure dimension the map deliberately does not carry.

## [0.5.0] — 2026-08-12

### Changed

- **The repository root is now the skill root.** `SKILL.md`, `references/`,
  `scripts/`, `assets/`, and `commands/` moved up out of
  `.claude/skills/xways-xtension-authoring/` to the top of the repo. `docs/` and
  `templates/` did not move — they are now *inside* the skill root instead of
  three levels above it.

  **Why:** the skill previously resolved `docs/` and `templates/` via
  `${CLAUDE_SKILL_DIR}/../../..`, reaching outside its own directory. That works
  for a clone and a plugin install, but silently breaks the other supported
  install paths (a copy or junction under `~/.claude/skills/`, or a zip upload)
  — every `docs/…` citation dangles and `new-xtension.ps1` fails to find
  `templates/x-tensions`. The skill is now self-contained: every path in
  `SKILL.md` resolves beneath `SKILL.md`.

  **Migration:** nothing to do for plugin users — `/plugin update` picks it up.
  If you had the skill copied into a project's `.claude/skills/`, delete that
  copy and junction your clone into `~/.claude/skills/` instead (see the README)
  so there is only ever one copy to keep in sync.

- **Path fixes that follow from the move** — script anchors (`$PSScriptRoot/..`
  instead of four levels up), `plugin.json` (`commands` repointed; the `skills`
  key dropped so the root `SKILL.md` auto-loads as a single-skill plugin), the CI
  hygiene-scan path, README/`/xtension`/template-README/eval paths, and
  `.gitignore` (now ignores `/references/api/` — the SDK subtree — instead of
  `/references/`, which is the skill's own flow guides at the root).

- **`SKILL.md` paths are markdown links.** Every `references/`, `scripts/`,
  `docs/`, and `templates/` citation is now a real relative link rather than a
  bare backticked path, so file resolution is mechanical. The "Path anchors"
  paragraph that existed to explain which base directory each prefix resolved
  against is deleted — there is one root now.

- **`SKILL.md` trimmed to ~4.1k on-invoke tokens** (from ~5.5k on 0.4.0), under
  the 5k the Agent Skills spec recommends. Four cuts, no rules dropped:
  - Script parameters, deploy-target resolution, and plugin-mode invocation moved
    to a new `references/scripts.md`; `SKILL.md` keeps a five-row summary table
    plus the two always-on rules (`-DryRun` first, and the build gate).
  - Hard-gate wording compressed to rule + consequence + pointer. All ten gates
    and every consequence clause are intact — only explanatory prose already
    duplicated in `docs/conventions/` was cut.
  - The convention pages are a grouped link list (correctness / wrapping /
    output / naming+release) rather than a described table. Still one
    hop from `SKILL.md`, and the grouping aids selection more than the one-line
    summaries did.
  - The bundled-paths paragraph in the intro reduced to a single sentence; the
    README covers the layout.

- **`metadata.tags` is a string**, not a YAML list — the Agent Skills spec defines
  `metadata` as a map of string keys to string values.

- **`docs/xtension-dialog-conventions.md` is reachable from `SKILL.md`** and from
  the convention index. It declares itself a convention in its own frontmatter
  and is cited by four `references/` pages, yet appeared in neither index —
  reachable only through `docs/INDEX.md`. Linked rather than moved: it is a
  29-section compendium and the library is one-pattern pages of 32–198 lines.

- **`docs/conventions/*.md` carry the same frontmatter as `docs/*.md`.** All 23
  of the latter had `source` / `type` / `last_updated`; none of the 19
  conventions did — so `last_updated` was absent from exactly the pages the
  docs-loop is meant to maintain. Dates derive from each file's last commit
  rather than from the day they were added, so the field states a fact.

- **Three duplicated clarifications cut from `SKILL.md`** — how X-Ways discovers
  a DLL (already in `naming-deployment.md`, near-verbatim), the scope of
  `-Exemplar` (already in `scripts.md` and `scaffold-new.md`), and one fact
  negated twice in a single sentence. The "guardrail is not a `/xtension`
  subcommand" note moved down to `Invocation`, where the subcommand list lives;
  the half of that sentence which is a real instruction stayed with the flow
  table.

### Removed

- **The `cpp-xtmgr-compatible` template and all `xways-xt-manager` support.**
  Gone: the template itself, `references/manager-compat.md`,
  `docs/conventions/manager-compatibility.md`, `scripts/check-manager-sync.ps1`,
  the `-Template xtmgr` option, the manager row in the flow router, and every
  doc/reference/test mention.

  `xways-xt-manager` is not public and the skill was offering to scaffold
  against a contract nobody can use. Nothing is lost: the ABI contract stays
  documented where the manager work actually happens, and the X-Tensions that
  already carry manager support are untouched — this only removes the skill's
  ability to generate *new* manager-compatible scaffolds.

  The `wrapper` template's dormant manager entry point and `manager-plugin.h`
  are gone too — 211 lines out of `my_xtension.cpp`, the
  `XwaysManagerPluginEntry` export out of the `.def`, and the header deleted.
  Compile-verified: the template built cleanly before the edit (284,160 bytes)
  and after (271,360), and `dumpbin` confirms the rebuilt DLL exports exactly
  the eight `XT_*` entry points with no manager entry.

- **The report-table rename gate, from `SKILL.md`.** Added earlier in this
  release, then removed: it is reference detail that belongs in
  `references/api-guardrail.md`, it cost ~300 on-invoke tokens on every
  invocation, and a behavioural test showed prose in `SKILL.md` did not change
  the outcome anyway — the skill read the file and still emitted only the old
  name. `api-guardrail.md` now carries the accurate prefer-with-fallback rule.

### Known and accepted deviation

The spec asks that a skill's `name` match its parent directory. It does not
here: the repository root *is* the skill root, and the repository is called
`xways-xtension-builder-skill` while the skill is `xways-xtension-authoring`.
Both `tests/check-skill-spec.ps1` and the upstream `skills-ref` validator flag
this, independently.

**This is deliberate.** Claude Code resolves the skill by its frontmatter
`name`, `claude plugin validate` passes, and a personal install junctioned as
`~/.claude/skills/xways-xtension-authoring` does match. The alternatives both
cost more than the deviation: renaming the repository breaks the marketplace
URL and every existing link, and nesting the skill under
`skills/xways-xtension-authoring/` reintroduces the escaping-relative-paths
problem this release exists to fix — unless `docs/` and `templates/` move too,
which buries the human-browsable knowledge base.

Recorded as a warning rather than an error so it stays visible without failing
the build.

### Added

- **CI gates for the things this release changed.** `tests/check-links.ps1`
  verifies every relative markdown link resolves — the layout depends on
  relative paths, so a dangling link is a functional defect, and this already
  caught four real breaks. `tests/check-skill-spec.ps1` validates `SKILL.md`
  against the Agent Skills specification (name grammar and reserved words,
  description and compatibility limits, `metadata` as a string→string map, body
  length). Both are hard gates in the hygiene job, alongside the two scaffold
  regression suites.

  The upstream reference validator, `skills-ref`, runs as a separate **advisory**
  job: it has no PyPI release and its authors describe it as being for
  demonstration purposes only, so it is worth a second opinion but not worth a
  hard dependency.

  The link checker ignores links inside fenced blocks and inline code spans.
  That is the correct reading of markdown rather than an exemption to silence a
  false positive — `docs/conventions/readme-roadmap.md` documents a
  `[LICENSE](LICENSE)` line that a *generated* X-Tension README should contain,
  where it resolves in a different directory.

- **`references/scripts.md`** — the script reference split out of `SKILL.md`.
- **A `## Contents` table of contents in every `references/*.md`.** All are over
  100 lines, and the authoring guidance calls for a ToC above that length so a
  partial read still shows the file's full scope.

- **Three more CI gates**, from a second, deeper conformance audit. Each was
  verified to fail before it was trusted:
  - `tests/check-stale-guidance.ps1` — encodes each reversed convention as a
    rule, so a page that keeps teaching a superseded one fails the build. Rules
    match within a two-line window, because a correct fallback branch names the
    preferred call one line above the old one; a same-line check produced false
    positives on `api-guardrail.md`, whose job is to document the rename.
  - `tests/check-toc.ps1` — extends the ToC rule from `references/` to the whole
    knowledge base. Twenty pages over 100 lines had none; the largest were 896,
    446 and 430 lines. It checks accuracy rather than presence, since a drifted
    ToC is worse than none: every H2 must be listed and every entry must map to
    a real H2. `-Fix` writes them.
  - `tests/check-version-sync.ps1` — the release version was declared in four
    places (SKILL.md, `plugin.json`, and two fields in `marketplace.json`) with
    nothing checking they agreed.

  The advisory markdownlint job now reports zero issues across all 55 payload
  files, which it did not before.

### Fixed

- **The knowledge base taught three superseded things.** In every case the
  canonical page was correct and a second page had drifted — which is why prose
  review never caught it: each stale page reads perfectly well on its own.
  - `docs/xtension-dialog-conventions.md` taught **Shift**-to-save across six
    sites, including a skeleton labelled "usable verbatim", against the
    canonical **Ctrl**-to-save. Rewritten from the wrapper template's actual
    implementation: `GetKeyState(VK_CONTROL)` rather than
    `GetAsyncKeyState(VK_SHIFT)` — which is why the old dialog-focus gate is
    gone, since `GetKeyState` is already scoped to our message pump — plus
    `GetSaveFileNameW` for Ctrl+Close instead of a folder browse with
    auto-numbering, and the real timer id and label strings.
  - Four pages prescribed `XWF_AddToReportTable` without naming `XWF_Label`.
    Historical and empirical records deliberately keep the old name: rewriting
    the symbol in a measurement table would falsify what was tested.
  - `docs/conventions/wrapper-anatomy.md` returned `0x01 | 0x04` under the
    comment "XT_ProcessItem + XT_ProcessItemEx" — the exact misconception
    `item-collection.md` forbids by name, and one a behaviour eval tests for.
    The RVS diagram in `xtension-invocation.md` implied the same association.

- **`wrapper-anatomy.md` misdescribed the template it quotes.** Found while
  verifying the above: the work runs in `XT_Finalize` on X-Ways' thread rather
  than in the per-item callback, `XT_ProcessItemEx` is a deliberate no-op stub
  so the 2N double-count cannot happen, and `XT_Prepare` returns `0x01` alone.

- **The `cpp` template only resolved the pre-rename report-table call.** It
  declared and called `XWF_AddToReportTable` and never mentioned `XWF_Label`, so
  the skill's own starter code taught the outdated name — which is the most
  likely reason generated report-table code kept reaching for it. It now mirrors
  the `wrapper` template: resolve both, prefer `XWF_Label`, fall back to
  `XWF_AddToReportTable` for hosts predating the rename, and never count the new
  name as a missing export. Compile-verified before and after.

  This is the deterministic half of the fix that prose could not achieve — the
  gate text was removed from `SKILL.md` precisely because a behavioural test
  showed it did not change the outcome.

- **Scaffolding silently skipped multi-dot sidecar files.**
  `new-xtension.ps1` derived a file's stem with
  `[Path]::GetFileNameWithoutExtension`, which strips only the *final*
  extension — so `my_xtension.cfg.example` yielded base `my_xtension.cfg`, never
  matched the stem `my_xtension`, and was copied through unrenamed.

  This was a functional break, not a cosmetic one. The sidecar names are
  load-bearing: the wrapper reads `GetSelfDirectory() + NAME + L".cfg"` and the
  python entry point reads `f"{NAME}.config.json"`, and `NAME` *is* patched to
  `xways-<name>` during scaffolding. Every scaffolded wrapper therefore shipped a
  `my_xtension.cfg.example` that the scaffolded DLL would never look for.

  The stem is now taken from the first dot-separated segment. Single-extension
  and extensionless filenames are unaffected.

- **Sidecar file *contents* were never patched, only their names.** Nothing in
  `Get-Replacements` could address a multi-dot filename, because it derived the
  base with `[Path]::GetFileNameWithoutExtension` too — so no rule could be
  written for `.cfg.example` or `.config.json` in the first place.

  The wrapper's cfg sample documents two things the analyst acts on: the cfg
  file the DLL actually reads (`GetSelfDirectory() + NAME + L".cfg"`) and the
  `<NAME>` output subfolder under the case root. Left at the template stem it
  named a file that is never read and a directory that is never created —
  `<case dir>\my_xtension\` instead of `<case dir>\xways-<name>\`. The python
  sidecar's `_comment` told the analyst to rename the file by hand to match
  `NAME`, which the scaffold now does for them.

  Both are patched. `yourtool` in the cfg sample is deliberately left alone — it
  is the helper-exe placeholder paired with `kHelperIdentityNeedle`, an author
  TODO rather than an identity string.

- **Scaffolded wrappers shipped the template's dialog titles.** The `.rc` rule
  matched the *literal* `CAPTION "My X-Tension - Settings"` — which is what the
  `xtmgr` template contains. The `wrapper` template reads
  `CAPTION "my_xtension - Settings"`, so the rule never matched and every
  scaffolded wrapper opened a settings dialog titled **"my_xtension - Settings"**
  with an about box titled **"About my_xtension"** (the second caption and the
  about-title `LTEXT` were not handled at all). The rules now match the caption's
  shape rather than a fixed string, and the wrapper's about dialog is covered.

- **`REPORT_TABLE` was never patched for the wrapper template.** It was only
  registered for the plain `cpp` template, so scaffolded wrappers advertised
  `my_xtension: hits` to the analyst as the report-table name.

- **`-DryRun` promised replacements that could not happen.** The plan listed
  every generated rule without testing its pattern against the source, reporting
  9 replacements for a wrapper where 5 applied. Both the preview and the execute
  pass now test each pattern and print a red **NO MATCH** line plus a summary
  warning when a rule is dead — most valuable when scaffolding from an exemplar
  whose identity constants do not follow the template shape, which previously
  produced a silently mis-named X-Tension. Relatedly, a rule that matches but
  rewrites to an identical string (e.g. `VERSION` already `0.1.0-beta`) now
  counts as applied instead of being indistinguishable from a dead pattern.

  The `xtmgr` and `wrapper` rule sets are also split apart: the two templates
  fill the manager descriptor differently (`xtmgr` uses string literals, the
  wrapper references the already-patched `NAME` / `DESCRIPTION` constants), so
  sharing one rule set guaranteed dead rules on one side or the other.

- **The python template's config sidecar could never be renamed.** It shipped as
  `xtension_template.config.json`, but the python template's source stem is
  `xtension` — so even with multi-dot handling fixed, the names could not match.
  Renamed to `xtension.config.json`, which the generic stem rule now resolves to
  `xways-<name>.config.json` — the filename `xtension.py` actually reads.

- Broken relative links in `docs/exemplars.md` and `docs/getting-the-sdk.md`
  (they pointed into the old `.claude/skills/…` path).
- `references/api-guardrail.md` used Windows backslashes in its grep snippets and
  an ambiguous `references\api\…` path; both now use forward slashes and the SDK
  path is explicitly marked as living in the user's own project.

## [0.4.0] — 2026-07-05

### Added

- **Plugin-mode scaffolding.** `new-xtension.ps1` and `build-xtension.ps1` take a
  new `-DestRoot` (default: the current directory) so a marketplace-installed
  plugin scaffolds/builds into the user's own project, not the plugin cache — and
  both **refuse to write into an installed plugin/marketplace cache**. Templates
  and assets are still read from the installed skill. This removes the
  "authoring requires a clone" limitation; SKILL.md and the `/xtension` command
  are updated to match (scripts referenced via `${CLAUDE_PLUGIN_ROOT}`, run with
  `-DestRoot <project>`). Verified end-to-end: scaffold + build into a temp
  project succeeds with the skill install untouched.
- **`docs/conventions/add-output-to-case.md`** — new convention page for
  registering an X-Tension's output back into the case: a new evidence object
  (`XWF_CreateEvObj`) or items in the snapshot (`XWF_CreateFile`), with the
  parent / read-only / persistence gotchas and the zip-nesting trap. Signatures
  confirmed against the SDK header; indexed in `conventions/index.md`,
  `docs/INDEX.md`, and SKILL.md.
- **Triggering evals** (`evals/`) — a 20-query should-trigger / should-not-trigger
  matrix (`trigger-eval.json`, edge-case-heavy near-misses) to catch under- and
  over-triggering as the description changes, a recorded baseline
  (`baseline.md` — 20/20 on the v0.3.0 description), and a README on re-running it.

### Changed

- **Disambiguated `references/`.** The skill's own `references/*.md` flow guides
  vs a user-acquired SDK tree (`references/api/...`) are now called out
  explicitly: the "never edit `references/`" hard gate means the **SDK tree**, in
  SKILL.md and the `/xtension` command, so it can't be misread as the flow guides.
- **`${CLAUDE_PLUGIN_ROOT}` for command script paths** — `/xtension` now points at
  the scaffold/build scripts under `${CLAUDE_PLUGIN_ROOT}` (plugin) or the repo
  root (clone).

## [0.3.0] — 2026-07-04

X-Ways Forensics X-Tension authoring skill and knowledge base for Claude Code:
starter templates, a distilled X-Tension API reference, a reusable convention
library, and deterministic PowerShell scaffold/build scripts.

### Skill

- **`xways-xtension-authoring` skill** — a `SKILL.md` flow router (new / wrap /
  port / audit / guardrail / docs-loop) with per-flow reference guides, worked
  examples, hard gates for the highest-severity mistakes, and the `/xtension`
  slash command.
- **Hard gates** baked into the skill: never invent `XWF_*` calls or flags;
  item-callback semantics (`0x01` calls whichever per-item callback you export —
  both fire if both exported); run synchronously on X-Ways' thread (never call
  `XWF_*` from a spawned worker); subprocess stdio via `\NUL` +
  `STARTF_USESTDHANDLES`; output-writer hygiene.

### Templates

- Starter templates under `templates/x-tensions/`: `cpp`, `cpp-xtmgr-compatible`,
  `python`, and a full-featured CLI-wrapper (`wrapper`) with helper-exe identity
  verification, a settings dialog, Ctrl-to-save, output-dir handling, and safe
  subprocess I/O already wired.

### Knowledge base

- Distilled, citable X-Tension API reference under `docs/` — entry points and
  action codes, the Events API, item I/O, dialogs, the command line, and
  empirical findings verified against X-Ways 21.7–21.9.
- A **convention library** (`docs/conventions/`) — the single source of truth
  the skill cites by symbol. Notable pages:
  - **item-collection** — `0x01` delivers each item to *both* exported per-item
    callbacks (RVS is multi-threaded); do the work in one callback or route both
    through a deduping, mutex-guarded collector. `0x04` is `EXPECTMOREITEMS`, not
    a callback selector.
  - **threading-model** — run synchronously on X-Ways' thread; a dialog should
    request-then-run in `XT_Finalize`, never call `XWF_AddEvent` off a spawned
    thread.
  - **events-emission** — cross-run event dedup must bucket the FILETIME to whole
    seconds (`XWF_GetEvent` round-trips it through a double); `lpDescr` ~254-byte
    cap.
  - **output-writers** — sanitise to valid UTF-8/XML, propagate I/O errors,
    spill+stream to bound memory, split on a row count.
- API-recency reference tracking additions past the packaged SDK header through
  X-Ways 21.9, verified against the live official functions page: the `XT_Init`
  `LicenseInfo*` signature; `XWF_OpenItem`'s `0x8000` EML-embed flag (v21.8+);
  `XWF_Label` / `XWF_GetLabels` (renames of `XWF_AddToReportTable` /
  `XWF_GetReportTableAssocs`, with label removal via `nFlags` `0x80000000`); and
  v21.9 Preview 1 custom numeric `nEvtType` filtering (`>=25000` → "Other",
  `<=65535`).
- `docs/exemplars.md` — a registry of community X-Tensions to read and port
  patterns from, plus a "Related tooling & research" section (e.g.
  [Donovoi/X-Ways-MCP](https://github.com/Donovoi/X-Ways-MCP)).

### Scripts

- `new-xtension.ps1` (scaffold + rename + identity), `build-xtension.ps1` (X-Ways
  running-check, MSVC bootstrap, build-gate, deploy), `check-manager-sync.ps1`,
  `prepublish-scan.ps1`, and `backfill-standards.ps1`. Copyright holder for
  generated `LICENSE` files defaults to `git config user.name`.

### Packaging

- Installable as a Claude Code plugin (`.claude-plugin/plugin.json` +
  single-plugin `.claude-plugin/marketplace.json`), or clone-and-open for
  end-to-end authoring. Does not redistribute the X-Ways SDK or manuals
  (copyright X-Ways AG) — `docs/getting-the-sdk.md` points to where to acquire
  them.
