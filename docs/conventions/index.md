# Convention Reference

One page per convention, each with a vetted, copy-pasteable example plus a do/don't. Each
example is extracted from the `wrapper` template and cites the exact symbol.

- [Naming & deployment](naming-deployment.md) — `x-tensions/` (source) vs `xtensions\` (deploy)
- [Item collection](item-collection.md) — `0x01` calls whichever per-item callback you export (both fire if both exported); RVS is multi-threaded — dedup + mutex
- [Threading model](threading-model.md) — run synchronously on X-Ways' thread; never call `XWF_*` from a worker thread you spawn
- [Events emission](events-emission.md) — FILETIME dedup bucketing (`XWF_GetEvent` drifts), `lpDescr` cap
- [Output writers](output-writers.md) — UTF-8/XML sanitising, error propagation, memory bounding, row-count splitting
- [Output directory](output-dir.md) — `<caseRoot>\<NAME>\`
- [VERBOSE logging](verbose-logging.md)
- [Subprocess stdio](subprocess-stdio.md) — the `NUL` + `STARTF_USESTDHANDLES` requirement
- [Helper-exe verification](helper-exe-verification.md) — PE VERSIONINFO + `--version` gates, red-flash UI
- [Ctrl-to-save gesture](ctrl-to-save.md)
- [Wrapper anatomy](wrapper-anatomy.md) — the 6 elements
- [Tool resolution](tool-resolution.md) — the 4-level `ResolveToolPath` order
- [Manager-plugin compatibility](manager-compatibility.md) — `XwaysManagerPluginEntry` contract, ABI versioning, dual-mode delegation, dialog embedding
- [Licensing](licensing.md) — MIT `LICENSE` + source header; third-party attribution for wrapped tools
- [Versioning](versioning.md) — `0.Y.Z-beta` until the first public release
- [README & roadmap](readme-roadmap.md) — README structure + inline `## Roadmap`
- [Per-X-Tension CLAUDE.md](xtension-claude-md.md) — tracked `CLAUDE.md.example` → local git-ignored `CLAUDE.md`
- [Repo hygiene](repo-hygiene.md) — GitHub-readiness: no committed DLLs / creds / paths; `prepublish-scan.ps1`
