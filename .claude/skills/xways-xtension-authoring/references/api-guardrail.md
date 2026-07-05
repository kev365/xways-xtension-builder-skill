# api-guardrail — API correctness gate

Use this reference for any flow that requires verifying an `XWF_*` call, a
flag bit, a property number, or an X-Ways behavior. It is also the always-on
correctness layer — route every API question through it before writing code.

## The rule

Never emit an `XWF_*` function call or flag/property constant that cannot be
verified in one of, **in this priority order**:

1. The distilled notes in `docs/` (the routing-table targets below) — the
   **primary** check. These pages carry the project's vetted API surface,
   property numbers, flag bits, and behavior findings, and they ship in this
   repo.
2. The live API HTML at
   `https://www.x-ways.net/forensics/x-tensions/XWF_functions.html` — the
   authoritative source for additions made after the SDK snapshot (21.5–21.8+),
   and the tiebreaker when a `docs/` page is silent or ambiguous.
3. An **optional** locally-downloaded SDK header
   (`references/api/xwf-api-code-c46a1bd2/src/X-Tension.h`, git HEAD commit
   `c46a1bd2`, 2024-07-26) — a fallback **only if you acquired it yourself** per
   `docs/getting-the-sdk.md`. It is **not shipped in this repo** (copyright) and
   may be absent; never rely on it being present.

The 2024-05-31 SDK zip is **stale** — prefer the git HEAD header if you have it
locally. The live HTML is rolling and is authoritative for 21.5–21.8+
additions. See `docs/xways-api-recency-research.md` for the full SDK-recency
analysis and the specific delta between the zip, git HEAD, and the live HTML,
and `docs/getting-the-sdk.md` for how to obtain your own SDK copy.

## Grep by symbol, not by line number

When grepping a source — a `docs/` page or, **if you have the SDK locally**,
the header — search by symbol, not line number: line numbers shift across
edits, symbols do not. Search by function-pointer typedef name (e.g.
`XWF_GetCaseProp_t`) or by the `XWF_` prefix.

Grep the distilled notes (always available in this repo):

```powershell
Select-String "XWF_GetCaseProp" docs\*.md
```

If — and only if — you downloaded the SDK header yourself (per
`docs/getting-the-sdk.md`), you can also grep it as a fallback:

```powershell
# Only when the header is present locally — it is NOT shipped in this repo.
Select-String "XWF_GetCaseProp" `
  "references\api\xwf-api-code-c46a1bd2\src\X-Tension.h"
```

## Routing table — question type → authoritative doc

| Question about | Route to |
|---|---|
| Entry point lifecycle, threading model, return values, `nOpType` constants | `docs/xtension-invocation.md` |
| `XT_Init` signature (note: fourth param is now `LicenseInfo*`) | `docs/xways-api-recency-research.md` §"TL;DR" + `docs/xtension-invocation.md` |
| Events API (`XWF_AddEvent` / `XWF_GetEvent`, `EventInfo` struct, subcode tables) | `docs/xways-events-api.md` |
| Empirical event behavior (subcode→Type-label tables, `nFlags` effects, lpDescr ceiling) | `docs/events-viewer-empirical-findings.md` |
| `XWF_GetCaseProp` / `XWF_GetEvObjProp` / `XWF_GetVSProp` property numbers | `docs/xways-getprop-reference.md` |
| `XWF_OpenItem` flag bits | `docs/xways-openitem-flags.md` |
| Reading existing events and directory-browser items | `docs/xways-reading-events-and-items.md` |
| Dialog hosting, `XWF_GetUserInput`, Win32 dialog patterns | `docs/xtension-dialog-conventions.md` + `docs/xways-user-input-and-dialogs.md` |
| Wrapping external tools (extraction, subprocess, ID mapping, mount) | `docs/external-tool-integration.md` |
| Build errors, DLL locking, rc.exe code-page mangling | `docs/build-and-iteration-gotchas.md` |
| Win32 API calls (`GetFileVersionInfoW`, `VerQueryValueW`, `CreateProcessW`, etc.) | the official Microsoft Learn docs (learn.microsoft.com) — or the `microsoft-docs` skill / Microsoft Learn MCP if you have it |

## Known post-HEAD additions to check against live HTML

These items exist in 21.5–21.9 but are **not** in the git HEAD header. Verify
against the live HTML or `docs/xways-api-recency-research.md` before use:

- `XWF_GetItemInformation` / `XWF_SetItemInformation` Relevance column
  (21.5 Preview 6)
- `XWF_GetEvObjProp` `nPropType = 100` (21.5 SR-5)
- `XT_PREPARE_DONTOMIT` + `XT_PREPARE_TARGETFILESWITHUNKNOWNDATA` combo (21.6 SR-6)
- `XWF_OpenItem` flag `0x8000` (embed EML child objects, v21.8+; documented on
  the official API page as of 2026-07-03 — the `0x2000` value seen in forum
  user code is **not** documented — see `docs/xways-openitem-flags.md`)
- `XWF_Label` / `XWF_GetLabels` rename from `XWF_AddToReportTable` /
  `XWF_GetReportTableAssocs` (backported to 21.4 SR-11 / 21.5 SR-13 /
  21.6 SR-8 / 21.7 SR-4; label *removal* via `nFlags` `0x80000000` is v21.8+)
- Custom numeric `nEvtType`s (≥25000, ≤65535) listed in the Events filter
  dialog (21.9 Preview 1 — see `docs/xways-events-api.md`)

## Deprecated / renamed calls (do not use)

| Old name | Replacement | Since |
|---|---|---|
| `XWF_AddToReportTable` | `XWF_Label` (also removes a label when called with `nFlags` `0x80000000`, v21.8+) | rename backported to 21.4 SR-11 / 21.5 SR-13 / 21.6 SR-8 / 21.7 SR-4 |
| `XWF_GetReportTableAssocs` | `XWF_GetLabels` | rename backported to 21.4 SR-11 / 21.5 SR-13 / 21.6 SR-8 / 21.7 SR-4 |

Source: `docs/xways-reading-events-and-items.md`.

## Known behavior quirks

- `XT_PREPARE_TARGETZEROBYTEFILES` has no effect on `XT_ProcessItemEx`
  (zero-byte files only delivered to `XT_ProcessItem`). Acknowledged by X-Ways;
  a fix is pending. Workaround: register both callbacks.
  Source: `docs/forum-xtensions-distilled.md` +
  `docs/xways-api-recency-research.md` §"Bugs / doc-vs-reality discrepancies".
- Files in corrupt/incomplete archives deliver a size-0 (useless) handle to
  `XT_ProcessItemEx` since 21.7 Beta 4. Always check size before reading.
- Under RVS, `XT_ProcessItem(Ex)` runs multi-threaded. Any shared state requires
  synchronization. Source: `docs/xtension-invocation.md`.

## Quick self-check before writing an XWF_ call

1. Is the symbol documented in a `docs/` page (via the routing table)? →
   Proceed.
2. Not in `docs/` but described on the live API HTML? → Document the finding
   per `references/docs-loop.md`, then proceed.
3. (Optional, only if you have the SDK locally) Confirm against
   `references/api/xwf-api-code-c46a1bd2/src/X-Tension.h` — a reassuring
   fallback, but the absence of a local header is **not** a blocker when
   steps 1–2 verify the symbol.
4. Verified by none of the above? → Do not emit the call. State the
   uncertainty and propose an alternative from the verified surface.

## Cross-references

- Discovering new API additions → `references/docs-loop.md`
- Audit flow that applies this gate systematically → `references/audit-modernize.md`
- SDK recency analysis → `docs/xways-api-recency-research.md`
