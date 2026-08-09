# Changelog

All notable changes to this project are documented here. Versions follow
[Semantic Versioning](https://semver.org/).

## [0.5.0] — unreleased

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

- **Convention library is a table.** The 19 `docs/conventions/` pages are listed
  with a one-line "covers" summary and a direct link, making each of them one hop
  from `SKILL.md` rather than two (via a flow guide). Costs ~1k on-invoke tokens.

- **`metadata.tags` is a string**, not a YAML list — the Agent Skills spec defines
  `metadata` as a map of string keys to string values.

### Fixed

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
