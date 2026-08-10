---
type: index
last_updated: 2026-08-09
author: project
---

# Convention Reference

One page per convention, each with a vetted, copy-pasteable example plus a do/don't. Each
example is extracted from the `wrapper` template and cites the exact symbol.

- [Naming & deployment](naming-deployment.md) — `x-tensions/` (source) vs `xtensions\` (deploy)
- [Item collection](item-collection.md) — `0x01` calls whichever per-item callback you export (both fire if both exported); RVS is multi-threaded — dedup + mutex
- [Threading model](threading-model.md) — run synchronously on X-Ways' thread; never call `XWF_*` from a worker thread you spawn
- [Events emission](events-emission.md) — FILETIME dedup bucketing (`XWF_GetEvent` drifts), `lpDescr` cap
- [Output writers](output-writers.md) — UTF-8/XML sanitising, error propagation, memory bounding, row-count splitting
- [Output directory](output-dir.md) — `<caseRoot>\<NAME>\`
- [Add output to the case](add-output-to-case.md) — register output as an evidence object (`XWF_CreateEvObj`) or snapshot items (`XWF_CreateFile`)
- [VERBOSE logging](verbose-logging.md)
- [Subprocess stdio](subprocess-stdio.md) — the `NUL` + `STARTF_USESTDHANDLES` requirement
- [Helper-exe verification](helper-exe-verification.md) — PE VERSIONINFO + `--version` gates, red-flash UI
- [Ctrl-to-save gesture](ctrl-to-save.md)
- [Wrapper anatomy](wrapper-anatomy.md) — the 6 elements
- [Tool resolution](tool-resolution.md) — `ResolveDefaultTool` in the template, plus the richer shared-tools-tree form
- [Licensing](licensing.md) — MIT `LICENSE` + source header; third-party attribution for wrapped tools
- [Versioning](versioning.md) — `0.Y.Z-beta` until the first public release
- [README & roadmap](readme-roadmap.md) — README structure + inline `## Roadmap`
- [Per-X-Tension CLAUDE.md](xtension-claude-md.md) — tracked `CLAUDE.md.example` → local git-ignored `CLAUDE.md`
- [Repo hygiene](repo-hygiene.md) — GitHub-readiness: no committed DLLs / creds / paths; `prepublish-scan.ps1`

## Long-form companion

[Dialog conventions](../xtension-dialog-conventions.md) is the settings-UI
counterpart to this library — 29 sections covering `.rc` layout, ID ranges,
font hierarchy, validation, cancel safety, progress reporting, and the pickers.
It lives outside `conventions/` because it is a compendium rather than a
one-pattern page, but it is the same kind of source of truth: load it whenever
an X-Tension grows a dialog. [Ctrl-to-save](ctrl-to-save.md) is the one gesture
extracted from it into its own page, because wrappers wire it without needing
the rest.
