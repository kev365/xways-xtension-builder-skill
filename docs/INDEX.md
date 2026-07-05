---
type: index
last_updated: 2026-07-03
author: project
---

# Knowledge Base Index

Distilled, citable notes on the X-Ways Forensics X-Tension API — paraphrased from
the official docs, derived empirically by probing X-Ways, or synthesized into
reusable conventions. The `xways-xtension-authoring` skill routes API questions
to these pages so generated code never invents `XWF_*` calls.

> These notes do **not** reproduce the X-Ways SDK header, manuals, or user-forum
> content (copyright X-Ways AG). To build, acquire the SDK yourself —
> [getting-the-sdk.md](getting-the-sdk.md).

## Getting started

- [getting-the-sdk.md](getting-the-sdk.md) — where to download the X-Ways
  X-Tension SDK + manuals (not shipped here), and where the build expects the
  optional local `X-Tension.h`.

## API reference

- [xtension-invocation.md](xtension-invocation.md) — entry points, action codes
  (`XT_ACTION_*`), threading model, invocation modes, return values; the
  `MsgWaitForMultipleObjects` UI-pump pattern for long blocking work.
- [xways-events-api.md](xways-events-api.md) — `XWF_AddEvent` / `XWF_GetEvent` /
  `EventInfo`; adding rows to the Events Viewer (C++ only — no Python exposure).
- [xways-reading-events-and-items.md](xways-reading-events-and-items.md) —
  consuming the Events Viewer and Directory Browser
  (`XWF_GetEvent`, `XWF_GetItemCount` / `XWF_OpenItem` / `XWF_Read`).
- [xways-getprop-reference.md](xways-getprop-reference.md) — `XWF_GetCaseProp` /
  `XWF_GetEvObjProp` property numbers (live-API-only) + temp-base resolution.
- [xways-openitem-flags.md](xways-openitem-flags.md) — complete `XWF_OpenItem`
  `nFlags` bitflag table; the "skip the OCR path with 0x0400" pattern.
- [xways-itemtype-metadata-text.md](xways-itemtype-metadata-text.md) — empirical
  decoding of `XWF_GetItemType`, `XWF_GetMetadataEx`, and `XWF_GetText` flags.
- [xways-snapshot-mutation.md](xways-snapshot-mutation.md) — item-creation /
  snapshot-mutation findings (`XWF_CreateFile`, `XWF_SetItemSize`,
  `XWF_FindItem1`, `XWF_GetItemName`).
- [xways-evobj-source-resolution.md](xways-evobj-source-resolution.md) —
  `XWF_GetEvObjProp` property map across evidence-object contexts + a
  source-resolution algorithm.
- [xways-image-io-api.md](xways-image-io-api.md) — the Image I/O API
  (`IIO_Init` / `IIO_Work` / `IIO_Done`, `ImageInfo`) — a separate plugin class
  from the X-Tension API.
- [xways-disk-io-xtension.md](xways-disk-io-xtension.md) — the Disk I/O X-Tension
  class (`XT_SectorIOInit` / `XT_SectorIO` / `XT_FileIO` / `XT_SectorIODone`).
- [xways-user-input-and-dialogs.md](xways-user-input-and-dialogs.md) —
  `XWF_GetUserInput`, `XWF_OutputMessage`, `XWF_GetWindow`; Win32 dialogs
  parented to `hMainWnd`; the sidecar-config pattern.
- [xtension-dialog-conventions.md](xtension-dialog-conventions.md) —
  cross-X-Tension dialog UX patterns (`.rc DIALOGEX` vs in-memory `DLGTEMPLATE`,
  section order, font hierarchy, validation, cancel safety).

## Empirical findings & API recency

- [events-viewer-empirical-findings.md](events-viewer-empirical-findings.md) —
  measured `nEvtType` → Type/Category lookup, `nFlags` semantics, `lpDescr`
  capacity, and the X-Ways internal Type catalog.
- [xways-api-recency-research.md](xways-api-recency-research.md) — which API
  additions appear in the SDK zip vs git HEAD vs the live HTML, and the
  `XT_Init` `LicenseInfo*` change.
- [xways-api-history-19-to-21_4.md](xways-api-history-19-to-21_4.md) — dated,
  sourced table of API additions / flags / behavior changes from v19.0–v21.4.
- [forum-xtensions-distilled.md](forum-xtensions-distilled.md) — X-Tension
  runtime behavior notes for X-Ways 21.7–21.8 (which items get delivered, EML
  attachments, disk-I/O vs ordinary API surface).

## Command line

- [xways-command-line.md](xways-command-line.md) — `xwforensics64.exe` /
  `xwb64.exe` CLI parameters, including the `XTParam:<id>:<value>` token.
- [xways-x-tensions-txt-format.md](xways-x-tensions-txt-format.md) —
  `<install>\X-Tensions.txt` format and the leading bit-flag mapping.

## Conventions

The reusable authoring patterns — the single source of truth the skill cites by
symbol. See the [convention library index](conventions/index.md). Key pages:

- [naming-deployment.md](conventions/naming-deployment.md) — `xways-<name>` stem;
  `xtensions\` (no hyphen) deploy path; deploy-target resolution.
- [item-collection.md](conventions/item-collection.md) — `0x01` calls whichever
  per-item callback you export (export both → **both fire per item**); RVS is
  multi-threaded, so dedup + mutex; `0x04` is `EXPECTMOREITEMS`, not a callback
  selector.
- [threading-model.md](conventions/threading-model.md) — run synchronously on
  X-Ways' thread; never call `XWF_*` (esp. `XWF_AddEvent`) from a worker thread
  you spawn; dialogs request-then-run in `XT_Finalize`.
- [events-emission.md](conventions/events-emission.md) — cross-run event dedup
  must bucket the FILETIME to whole seconds (`XWF_GetEvent` drifts it through a
  double); `lpDescr` ~254-byte cap.
- [output-writers.md](conventions/output-writers.md) — sanitise to valid
  UTF-8/XML, propagate I/O errors, spill+stream to bound memory, split on a row
  count (Excel / store-only-ZIP limits).
- [output-dir.md](conventions/output-dir.md) — default output to
  `<caseRoot>\<NAME>\` (`GetCaseRootDir` / `DefaultOutputDir`).
- [add-output-to-case.md](conventions/add-output-to-case.md) — register output
  back into the case: a new evidence object (`XWF_CreateEvObj`) or items in the
  snapshot (`XWF_CreateFile`), with the parent/read-only/persistence gotchas.
- [verbose-logging.md](conventions/verbose-logging.md) — `VERBOSE` flag +
  `LogVerbose` no-op wrapper.
- [subprocess-stdio.md](conventions/subprocess-stdio.md) — open `\NUL` +
  `STARTF_USESTDHANDLES` so a child doesn't crash the GUI host (`RunCommand`).
- [helper-exe-verification.md](conventions/helper-exe-verification.md) — verify a
  wrapped exe identifies as itself before spawning; in-dialog rejection flash.
- [ctrl-to-save.md](conventions/ctrl-to-save.md) — Ctrl+Run = Save cfg,
  Ctrl+Close = Save-as.
- [wrapper-anatomy.md](conventions/wrapper-anatomy.md) — anatomy of a CLI-wrapper
  X-Tension (resolve → verify → stage → run → map results).
- [tool-resolution.md](conventions/tool-resolution.md) — helper-exe path
  precedence (cfg / bundled / PATH / Browse).
- [manager-compatibility.md](conventions/manager-compatibility.md) —
  `xways-xt-manager` tab support (`XwaysManagerPluginEntry`, ABI 1,
  `manager-plugin.h`).
- [licensing.md](conventions/licensing.md) — MIT `LICENSE` + source-header block;
  third-party attribution for wrapped tools.
- [versioning.md](conventions/versioning.md) — `0.Y.Z-beta` until first public
  release.
- [readme-roadmap.md](conventions/readme-roadmap.md) — README section order +
  the inline `## Roadmap` convention.
- [xtension-claude-md.md](conventions/xtension-claude-md.md) — per-X-Tension
  tracked `CLAUDE.md.example` → local git-ignored `CLAUDE.md`.
- [repo-hygiene.md](conventions/repo-hygiene.md) — no committed DLLs / creds /
  local paths; `prepublish-scan.ps1`.

## Patterns & integration

- [exemplars.md](exemplars.md) — vetted registry of X-Tensions to read and port
  patterns from (none bundled here; the `wrapper` template implements the same
  conventions those exemplars demonstrate).
- [external-tool-integration.md](external-tool-integration.md) — how to wrap a
  third-party CLI tool as an X-Tension (extraction constraint, deployment,
  item-ID mapping).
- [build-and-iteration-gotchas.md](build-and-iteration-gotchas.md) — `rc.exe`
  code-page mangling, DLL locking (no hot reload), vcvars setup, encoding across
  the API surface.
