---
source: project register — full skill review 2026-08-16 (two parallel reviewers + spot verification)
type: research-summary
fetched: 2026-08-16
last_updated: 2026-08-16
author: project
---

# Skill review 2026-08-16 — findings roadmap

Working register for the repair sweep. Every finding from the 2026-08-16 full
review, grouped into phases; each item tracks status so progress survives
session breaks. Checkpoint commit before any repair: `3e64c29`.

Rules for this sweep (kev365, 2026-08-16):

- Update the **skill only** this run. Anything needing a live X-Ways or
  probe run goes to Phase E (empirical queue), not fixed by guesswork.
- Double-check every change against the underlying source (header, probe
  logs, SDK source) while making it — and log any *new* issues found
  mid-fix as new entries here.
- Threading danger box **stays as-is** for now (safe message preferred);
  the nuance question goes to the empirical queue.
- Python scaffold naming fix **approved** (underscore module stem).
- Register policy (P4-D5) **deferred** — kev365 to decide later.

Status vocabulary: `open` → `in-progress` → `done` (or `deferred` /
`moved-to-E`).

## Contents

- Phase 1 — high-severity factual fixes
- Phase 2 — templates, scripts, README/CHANGELOG
- Phase 3 — CI gates
- Phase 4 — de-duplication and structure
- Phase 5 — cosmetics batch
- Phase E — empirical test queue (needs live X-Ways; NOT this run)

## Phase 1 — high-severity factual fixes

| # | Item | Where | Status |
| --- | --- | --- | --- |
| H1 | `AddComment` mode table still says `2 = PREPEND` (disproved live 2026-08-15; mode 2 = append-with-line-break). Last surviving copy of the invented constant. | `xways-events-api.md:299` | done |
| H2 | op=0 (XT_ACTION_RUN) delivers **no per-item callbacks** — three pages still assert the opposite, incl. one page contradicting its own admonition 14 lines up. Owner: `xtension-invocation.md`; others cite it. | `xtension-dialog-conventions.md:911-912,936`; `xtension-invocation.md:171`; `conventions/wrapper-anatomy.md:24,86`; add mention to `conventions/item-collection.md` | done |
| H3 | `references/api-guardrail.md` refresh: stale 62/20/17 counts (real 73/26/0, no Absent list exists); routing table missing rows for search / Python bridge / snapshot mutation / evidence containers / command line; "register both callbacks" workaround lacks the 2N dedup caveat. | `references/api-guardrail.md:28-34,77-89,133-135` | done |
| H4 | Search page self-contradiction: states CALLPSH-delivers-zero at :225, then :269-290 still says "never demonstrated — test before designing around either reading." Reconcile the warning block with the 2026-08-15 result. | `xways-search-api.md:269-290` | done |
| H5 | Stale version-word section presents the superseded `/100.0` decode as unresolved; its own data (LOWORD 769=0x0301) proves the packed decode. Rewrite §11 to the confirmed decode + cross-ref. | `events-viewer-empirical-findings.md:433-443` | done |
| H6 | Python scaffold produces un-importable module: `xways-<name>.py` (hyphen = syntax error under the bridge's `import <stem>`); scaffold test asserts the broken name; python README still prescribes the subfolder layout proven not to load (2026-08-16) and targets "21.7". Fix: underscore stem `xways_<name>.py` (folder keeps `xways-<name>`), rewrite deploy story to main-folder model, fix test. | `scripts/new-xtension.ps1:242-267`; `tests/test-scaffold-rename.ps1:71`; `templates/x-tensions/python/README.md:3,7,21`; `references/decision-tables.md:29-30` | done |
| H7 | Event-subcode tables duplicated (~200 lines) across two pages AND the copies disagree on the unlabelled-OS-range boundary (`14015+` vs `15000+`). Consolidate into `xways-events-api.md` (owner); empirical page keeps methodology + link. Resolve the boundary from the probe logs while merging; if the logs don't settle it → E2. | `xways-events-api.md:117-262` ⟷ `events-viewer-empirical-findings.md:43-201,131` | open |
| H8 | Stale "unverified / in the test plan" markers pointing at **closed** register entries: GetItemName >MAX_PATH (resolved: does not reproduce, 21.8 SR-5) and "deviant sizes" (resolved: 309/310 identical). Update both pages to the results. | `build-and-iteration-gotchas.md:177-185`; `xways-sdk-source-notes.md:176-181` | done |

## Phase 2 — templates, scripts, README/CHANGELOG

| # | Item | Where | Status |
| --- | --- | --- | --- |
| M1 | Python template docstring still teaches "4 = call XT_ProcessItemEx" — contradicted 27 lines later in the same file (0x04 = EXPECTMOREITEMS). Fix the docstring. | `templates/x-tensions/python/xtension.py:141` | open |
| M2 | QUICKCHECK guard differs: wrapper returns `(missing>0) ? -1 : 1`; cpp + python return unconditional 1 (cpp never re-checks `missing`). Harmonize (cpp checks resolution failures on the quickcheck path too; python has no pointers to check — document that). | `templates/.../wrapper/my_xtension.cpp:2227`; `cpp/my_xtension.cpp:188`; `python/xtension.py:115` | open |
| M3 | `.def` files advise selective exports while shipping the anti-pattern (export ProcessItem+Ex+SearchHit, two of which are stubs). Align shipped exports with implemented callbacks; compile-verify after. | `cpp/my_xtension.def`; `wrapper/my_xtension.def` | open |
| M4 | cpp template's `GetCaseRootDir`/`DefaultOutputDir` are dead code (defined, never called). Wire into the demo or annotate as opt-in helpers. | `cpp/my_xtension.cpp:134-145` | open |
| M5a | `backfill-standards.ps1` has no `-DestRoot` and writes only into the skill install; SKILL.md:56 + references/scripts.md:17-20 claim otherwise. Fix the claims (adding `-DestRoot` optional). | `scripts/backfill-standards.ps1`; `SKILL.md:56`; `references/scripts.md` | open |
| M5b | `build-xtension.ps1` misdiagnoses python scaffolds ("run new-xtension.ps1 first" for a no-build X-Tension). Detect python kind, say so. | `scripts/build-xtension.ps1:121-123` | open |
| M5c | Dead replacement rule (`L"My X-Tension"` descriptor — matches nothing in any template) prints a NO MATCH warning on every wrapper scaffold; the identity test tautologically asserts the string absent. Remove rule + fix test (see G3). | `scripts/new-xtension.ps1:198-202`; `tests/test-scaffold-identity.ps1:120` | open |
| M5d | `SupportsShouldProcess` declared but never used in new-xtension.ps1 — `-WhatIf` half-works then dies on raw .NET I/O. Remove the declaration (`-DryRun` is the real preview). | `scripts/new-xtension.ps1:70` | open |
| M5e | git-missing fallback broken in new-xtension.ps1 (runs `git config` after EAP=Stop, so no git = abort instead of the documented `'Your Name'` default). | `scripts/new-xtension.ps1:468` | open |
| M5f | `Fail()` dead-ends under EAP=Stop in two scripts (Write-Error throws; `exit 1` unreachable; user sees stack trace not the one-liner). | `scripts/new-xtension.ps1:115-118`; `build-xtension.ps1:63-66` | open |
| M6a | README says the SDK header is required "to build C++ X-Tensions" — both templates are GetProcAddress-based and need no header (and say so). Reword: SDK optional (reference/manuals), not a build prerequisite. | `README.md:124-126` | open |
| M6b | README "What's inside" omits `tests/` + `evals/`; scripts row drops api-coverage.ps1. | `README.md:29-38` | open |
| M6c | CHANGELOG Unreleased contradicts itself: Added section says the two cpp defects were "recorded (not fixed)"; Fixed section says fixed in all three templates. Reconcile (they WERE fixed, later). | `CHANGELOG.md:149-152` vs `:252-261` | open |

## Phase 3 — CI gates

| # | Item | Where | Status |
| --- | --- | --- | --- |
| G1 | **Template-parity gate** — greps all three templates for the shared conventions (QUICKCHECK `0x20` guard, packed nVersion decode, op=0 warning, `COMMENT_APPEND_LINEBREAK = 2`, no-prepend comment). The last five template commits were all "fix in all three" — this gate catches the class. | a new template-parity check script under `tests/` + ci.yml | open |
| G2 | **Compile gate** — CI is windows-latest (VS 2022 present); scaffold + `build-xtension.ps1 -NoDeploy` both C++ templates. Compile-verification is currently manual. | ci.yml new job | open |
| G3 | Scaffold tests can't see NO MATCH rules (both counters exclude them by construction). Assert zero `NO MATCH` in dry-run output. | `tests/test-scaffold-identity.ps1:160-163` | open |
| G4 | `check-stale-guidance.ps1` regex misses the decimal "4 = call ProcessItemEx" form (only matches `0x01\s*\|\s*0x04`). Widen. | `tests/check-stale-guidance.ps1:71` | open |
| G5 | Redundant ci.yml JSON-parse step (subsumed by check-version-sync); pass-message understates scan scope in check-stale-guidance. Low value; batch with P5. | `ci.yml:21-26`; `check-stale-guidance.ps1:153` | open |

## Phase 4 — de-duplication and structure

| # | Item | Where | Status |
| --- | --- | --- | --- |
| D1 | Ctrl-to-save exists 4× — three code blocks inside dialog-conventions (the page it was "extracted" from) + the canonical `conventions/ctrl-to-save.md`. Remove the three, link the owner. | `xtension-dialog-conventions.md:641-899` | open |
| D2 | Helper-binary resolution duplicated into the invocation reference (~55 lines). Owner: `conventions/tool-resolution.md`. | `xtension-invocation.md:481-535` | open |
| D3 | Output-dir cascade restated in dialog-conventions. Owner: `conventions/output-dir.md`. | `xtension-dialog-conventions.md:607-632` | open |
| D4 | Coverage-map narrates 4 revisions of its own counts, out of order ("fourth move" before "third"). Trim to current counts + regen instructions; history lives in CHANGELOG. | `xways-api-coverage-map.md:126-159` | open |
| D5 | **Register policy** (kev365 decision pending): the conflicts register's preamble says "nothing here is resolved — move findings to the owning page and strike the entry," but six of nine entries are now RESOLVED in place. Two options: (a) *resolve-in-place* — keep the write-ups in the register, fix the preamble + tallies; (b) *move-and-strike* — relocate each finding to its owning page, leave one-line tombstones. | `xways-sdk-conflicts-test-plan.md:13,236-250` | deferred |
| D6 | QTest hazard list stated twice (gotchas + sdk-source-notes), both copies stale (H8 fixes staleness; this item removes the second copy). | `xways-sdk-source-notes.md:176-181` | done |

## Phase 5 — cosmetics batch

| # | Item | Where | Status |
| --- | --- | --- | --- |
| C1 | Frontmatter normalization: define a small `type` vocabulary (13 free-form values today), one `author` spelling, refresh `last_updated` where content moved (42/49 stale). | repo-wide | open |
| C2 | Dead link `LICENSE` → `../../LICENSE`. | `conventions/readme-roadmap.md:28` | open |
| C3 | "Seven not-implemented functions" lists eight; `XWF_GetDriveInfo` counted nowhere. | `xways-api-coverage-map.md:40-52,82-90` | open |
| C4 | INDEX.md refresh: stale descriptions (search page w/o CALLPSH finding; register described as all-open), `last_updated` 2026-08-12. | `docs/INDEX.md` | open |
| C5 | MkDocs-only admonition syntax (`!!! danger`, `=== "C++"` tabs) in a repo with no mkdocs.yml — renders literal on GitHub. Decide: add mkdocs config, or downgrade to blockquotes. | `conventions/threading-model.md:10`, `naming-deployment.md:15`, `verbose-logging.md:18` | open |
| C6 | Stale section-title cross-ref ("Threading & UI responsiveness" heading no longer exists). | `conventions/threading-model.md:18` | open |
| C7 | Tone/aging: "this machine has 3.13/3.14 only" and similar machine-specific / first-person phrasing in the register. | `xways-sdk-conflicts-test-plan.md` | open |
| C8 | Struct field `nSize` vs `iSize` naming mismatch within the search page (declaration vs prose/code). Verify against the header, align. | `xways-search-api.md:88,116,213` | open |
| C9 | cpp/build.bat lacks `cd /d "%~dp0"` (wrapper has it) — direct invocation from another cwd fails. | `templates/x-tensions/cpp/build.bat` | open |
| C10 | LONG vs DWORD `nOpType` drift between the two C++ templates. Align with the canonical header. | `cpp/my_xtension.cpp:208`; `wrapper/my_xtension.cpp:2257` | open |

## Phase E — empirical test queue (needs live X-Ways; NOT this run)

| # | Question | Origin | Status |
| --- | --- | --- | --- |
| E1 | **Off-thread `XWF_*` semantics**: the wrapper calls `XWF_OpenItem/Read/Close/...` from a worker thread while X-Ways' thread is parked in the progress dialog's message pump — battle-tested in shipping X-Tensions, but the threading danger box forbids it unconditionally. Probe: does off-thread `XWF_*` misbehave when the host thread is (a) blocked in our dialog vs (b) returned to X-Ways? Until then the safe blanket rule stands. | threading contradiction | open |
| E2 | Event-subcode unlabelled-range boundary: do labelled OS subcodes end at 14014 (⇒ unlabelled starts 14015) or do labels exist up to 14999? Only needed if the existing probe logs don't settle it during H7. | H7 | resolved 2026-08-16 from existing sweep data — Event log starts at 15000, so unlabelled OS range = 14015-14999; `14015+` is the correct row (fix lands with H7) |
| E3 | `XT_Init` return value `2` (thread-safe declaration): asserted in threading-model, absent from the invocation page's return table, flagged "unverified" in gotchas. Verify on a live host (does returning 2 change RVS callback concurrency?). | §1.4 | open |
| E4 | `xwf.GetHashValue` >128-bit overflow runtime confirmation — needs a Python 3.12 environment the embedded bridge can actually use (per-user install failed 2026-08-16: bridge can't import any script). Source proof already airtight. | register 7 | open |
| E5 | Search-hit flag `0x0040` double-listing (register 9 remainder): needs a slack hit and a report-flagged hit to disambiguate. | register 9 | open |
