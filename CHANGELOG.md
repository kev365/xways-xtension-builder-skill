# Changelog

All notable changes to this project are documented here. Versions follow
[Semantic Versioning](https://semver.org/).

## [Unreleased]

Quality items on the backlog (not install blockers):

- **Plugin-mode scaffolding**: add a destination-root option (default
  `Get-Location`) to `new-xtension.ps1` / `build-xtension.ps1` so a
  marketplace-installed plugin can scaffold into the user's project instead of
  the plugin cache, with a guard refusing to write into the cache. Until then,
  authoring end to end is done in a clone (SKILL.md says so explicitly).
- **`.claude/commands/xtension.md`**: use `${CLAUDE_PLUGIN_ROOT}` for script
  paths.
- **Disambiguate `references/`**: the skill's own `references/` (flow guides)
  vs a user-acquired SDK tree (`<project>\references\api\...`) — qualify every
  SDK mention so "never edit references/" can't be misread.
- **Add `docs/conventions/add-output-to-case.md`** (evidence-object add-back via
  `XWF_CreateEvObj` / `XWF_CreateFile`).
- **Trigger-test suite**: a should-trigger / shouldn't-trigger / edge-case
  phrase matrix plus a `skill-creator` eval run, tracking under- and
  over-triggering across description changes.

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
