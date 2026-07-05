---
name: xways-xtension-authoring
description: This skill should be used when the user asks to "create/scaffold a new X-Tension", "wrap a CLI tool in an X-Tension", "port a convention into an X-Tension" (helper-exe verification, Ctrl-to-save, output-dir), "audit/modernize an X-Tension", "build/compile an X-Tension", "prep an X-Tension for public release", or asks which XWF_* API call, flag, or property number to use, for X-Ways Forensics. Covers template selection, the PowerShell scaffold/build scripts, the convention library, and verifying every XWF_ call against distilled API reference notes. Does NOT handle general X-Ways usage questions or open-ended "what tool should I build" ideation.
license: MIT
compatibility: Authoring flows need Claude Code on Windows (PowerShell scaffold/build scripts; MSVC x64 for C++ builds; X-Ways Forensics 21.x to run the result). Guidance/API-reference flows work anywhere.
metadata:
  version: 0.4.0
  author: Kevin Stokes (kev365)
  category: digital-forensics
  tags: [x-ways, x-tension, dfir, windows, forensics]
  documentation: https://github.com/kev365/xways-xtension-builder-skill
---

# X-Ways X-Tension Authoring

Author and maintain X-Ways Forensics X-Tensions — the `xways-<name>` DLLs that live in an `x-tensions/` working folder — quickly and correctly. This repo ships the starter templates (`templates/x-tensions/`), a distilled `docs/` knowledge base, and this skill; the scaffold scripts read templates from the installed skill and copy one into `<project>/x-tensions/xways-<name>/` — output goes to the **current directory** by default, or a project you name with `-DestRoot`. This works the same from a clone or a plugin install (the scripts refuse to write into the plugin cache). Scaffold new X-Tensions by copying and parameterizing a starter template, port the documented conventions into existing ones, audit untested ones for API validity, and route every API question to the authoritative reference so generated code never invents `XWF_` calls.

This skill owns the X-Ways-specific *how*. For open-ended "what should this new tool do" ideation, brainstorm the tool's purpose first (the `superpowers:brainstorming` skill helps if you have it), then return here for template choice, scaffolding, conventions, and build.

**Path anchors.** `references/*.md` (this skill's flow guides) and `scripts/*.ps1` resolve from the skill's own directory; `docs/...` and `templates/...` resolve from the skill root, three levels up (`${CLAUDE_SKILL_DIR}/../../..`) — the repo root in a clone, the plugin's cached root in a plugin install. The scripts read templates from that skill root but write scaffold/build output under the **current directory** (or `-DestRoot`), never the skill install. Note: a user-acquired **SDK tree** (`references/api/...` under the user's own project, per `docs/getting-the-sdk.md`) is a *different* `references/` from this skill's flow guides — see the first hard gate.

## Hard gates (never violate)

- **Read-only template source + SDK tree.** `templates/x-tensions/` is the pristine template source — never edit, move, or delete it in place; scaffold a copy into `<project>/x-tensions/xways-<name>/` first (the scaffold script does this). Separately, a user-acquired X-Ways SDK lives in an **SDK `references/api/` tree** under the user's own project (per `docs/getting-the-sdk.md`) — that tree is read-only and must **never** be committed (copyright). "Never edit `references/`" means that SDK tree — it is *not* this skill's own `references/*.md` flow guides, which are normal skill files.
- **Never invent `XWF_` functions or flags.** Verify every call, in this priority order: (1) the distilled notes in `docs/` (the routing-table targets — primary); (2) the live official API page `https://www.x-ways.net/forensics/x-tensions/XWF_functions.html` (authoritative for additions made after the SDK snapshot); (3) an optional locally-downloaded SDK header (`references/api/.../X-Tension.h`) if you acquired it per `docs/getting-the-sdk.md` (fallback — may be absent). Route any API question through `references/api-guardrail.md`.
- **`x-tensions/` (hyphen) is the source tree; `xtensions\` (no hyphen) is the build-output / deploy folder** — a **project convention**, not an X-Ways discovery mechanism (X-Ways loads X-Tensions only from paths the analyst registers via *Tools | Run X-Tensions*, persisted in `X-Tensions.txt`, or via the `XT:<path>` command line — the DLL can live anywhere). Never confuse the two spellings: the build scripts stage, verify, and mirror the no-hyphen path, so a wrong spelling breaks the build/deploy tooling. See `docs/conventions/naming-deployment.md`.
- **Close X-Ways before building.** The DLL is locked while X-Ways is open; there is no hot reload.
- **Events API ⇒ C++ template only.** `XT_Python.dll` does not expose `XWF_AddEvent` / `XWF_GetEvent`.
- **Subprocess ⇒ open `\NUL` + `STARTF_USESTDHANDLES`.** X-Ways runs as a GUI-subsystem process — it accepts command-line *parameters*, but has no console window attached, so a child you spawn inherits null std handles and any helper that writes to stdout/stderr can hard-crash. Always hand the child real handles (open `\NUL`, or a pipe if you capture output) with `STARTF_USESTDHANDLES`. See `docs/conventions/subprocess-stdio.md`.
- **`0x01` calls whichever per-item callback you export — export both and BOTH fire; synchronise shared state.** `XT_Prepare` returning `0x01` delivers each item to *whichever* of `XT_ProcessItem`/`XT_ProcessItemEx` you export — export both and each item hits both (empirically verified: RVS delivers each item to both callbacks from a multi-threaded worker pool — the "2N" double-count). Do per-item work in **one** callback (use `XT_ProcessItemEx` for `hItem`) or route both through one deduping collector; RVS is multi-threaded, so shared state needs a mutex. `0x04` is `EXPECTMOREITEMS`, *not* "call `Ex`". See `docs/conventions/item-collection.md`.
- **Run synchronously on X-Ways' thread — never call `XWF_*` from a worker thread you spawned.** `XWF_AddEvent` off-thread can corrupt the event store / crash the host. A settings dialog should *request* a run, then run it in `XT_Finalize`. See `docs/conventions/threading-model.md`.
- **Output writers: sanitise to valid UTF-8/XML, propagate I/O errors, bound memory.** Raw log bytes break an `encoding="UTF-8"` XLSX (Excel rejects it); a silent write error truncates evidence; buffering every row OOMs. Spill + stream + split. See `docs/conventions/output-writers.md`.
- **Public-repo hygiene.** Never commit credentials, live `.cfg`, local paths (`C:\Users\…`), case data, or compiled DLLs/EXEs — binaries ship via GitHub Releases once the repo is public. Run `scripts/prepublish-scan.ps1` before a public push. See `docs/conventions/repo-hygiene.md`.

## Choose the flow, then load its reference

| To… | Flow | Load |
|---|---|---|
| scaffold a brand-new X-Tension | new | `references/scaffold-new.md` |
| wrap an external CLI tool | wrap | `references/wrapper-generator.md` |
| inject a convention into an existing X-Tension | port | `references/port-convention.md` |
| make an X-Tension manager-compatible (an `xways-xt-manager` tab) | manager | `references/manager-compat.md` |
| audit / modernize an untested X-Tension | audit | `references/audit-modernize.md` |
| answer an X-Ways API/behavior question correctly | guardrail | `references/api-guardrail.md` |
| record a new finding / mark a rollout item done | docs-loop | `references/docs-loop.md` |
| pick template vs exemplar, or decide on a dialog | (any) | `references/decision-tables.md` |
| debug a build / encoding / DLL-loading failure | (any) | `docs/build-and-iteration-gotchas.md` |

The `guardrail` row is an always-on correctness layer applied during every flow — not a `/xtension` subcommand.

Scaffold from a starter template under `templates/x-tensions/` (`cpp`, `cpp-xtmgr-compatible`, `python`, or the CLI-wrapper `wrapper` template). For a CLI-tool wrapper, prefer the `wrapper` template (`-Template wrapper`) — it already wires helper-exe verification, Ctrl-to-save, output-dir, and subprocess stdio. `docs/exemplars.md` is a registry of **community** exemplars (with X-Ways 21+ verdicts and attribution) to **read and port patterns from** — not bundled copy-targets; none are shipped in this repo. The `-Exemplar` script parameter applies only to exemplars you have locally in your own project.

## Scripts (the deterministic core)

The scripts live in this skill's `scripts/` directory (`.claude/skills/xways-xtension-authoring/scripts/`). They read templates/assets from the installed skill and can be run from any working directory; **scaffold/build output goes under the current directory by default, or a project passed via `-DestRoot`** — never the plugin cache (the scripts refuse to write there). Installed as a plugin, the scripts are at `${CLAUDE_PLUGIN_ROOT}/.claude/skills/xways-xtension-authoring/scripts/`; run them with `-DestRoot <the user's project>` (or from that project directory) so output lands in the user's project. The `-DestRoot` passed to `new-xtension.ps1` must be passed to `build-xtension.ps1` too.

- **`scripts/new-xtension.ps1`** — copy a starter template (or a locally-available exemplar) into `<DestRoot>/x-tensions/xways-<name>/`, rename the source files to the `xways-<name>` stem, and set the identity constants. Always run with `-DryRun` first to review the planned copies / renames / edits before committing to them.
  - Parameters: `-Name <name>` (the `xways-<name>` stem), `-DestRoot <project>` (where output lands — default: current directory; pass it in plugin mode), `-Template cpp|python|xtmgr|wrapper` **or** `-Exemplar <local-exemplar>` (only for an exemplar under `<DestRoot>/x-tensions/` — none are bundled here), optional `-Version -Description -ReportTable`, `-DryRun`, `-Force`. (`xtmgr` = `templates/x-tensions/cpp-xtmgr-compatible/`; `wrapper` = the CLI-wrapper template at `templates/x-tensions/wrapper/` — it ships a dormant manager entry point, but manager hosting stays opt-in.)
- **`scripts/build-xtension.ps1 -Name <name>`** — locate the X-Tension under `<DestRoot>/x-tensions/` (`-DestRoot` default: current directory — pass the same one used to scaffold), refuse to build while X-Ways is running, bootstrap the MSVC x64 environment if needed, run the X-Tension's `build.bat`, verify `xtensions\xways-<name>\xways-<name>.dll` was produced, then **deploy** the staged folder into your X-Ways install at `xtensions\xways-<name>\`. The deploy target is **the user's own environment** — nothing is hardcoded: pass `-DeployRoot '<install-root>'` once (the folder holding `xwb64.exe` / `xwforensics64.exe`; it's remembered in a git-ignored `.xtension-deploy.local`), or set `$env:XWT_DEPLOY_ROOT`. With neither set, the build still succeeds and stages the DLL locally; `-NoDeploy` skips deploy outright. **On a user's first build, ask them for their X-Ways install path** and pass it via `-DeployRoot` (remembered thereafter). The mirror is newer-only so an analyst-edited sidecar `.cfg`/`.yaml` in the install survives rebuilds. This is the **build gate** — never claim a scaffold "works" without pasting this script's success output.
- **`scripts/check-manager-sync.ps1 [-Name <name>]`** — verify each manager-compatible X-Tension's `manager-plugin.h` copy matches the canonical `templates/x-tensions/cpp-xtmgr-compatible/manager-plugin.h` (catches ABI drift that silently breaks managed loading). `build-xtension.ps1` runs it automatically for manager-compatible X-Tensions.
- **`scripts/prepublish-scan.ps1 [-Strict]`** — read-only pre-publish hygiene scan over git-tracked files: flags local paths (`C:\Users\…`), tracked binaries, and `case/` data (high-severity, non-zero exit), plus credential-ish keywords / emails (review advisories). Clear it before any public push. See `docs/conventions/repo-hygiene.md`.
- **`scripts/backfill-standards.ps1 [-DryRun] [-Force]`** — additively backfill a missing `LICENSE` (MIT) + `CLAUDE.md.example` into every active X-Tension that lacks them (idempotent; pulls each tool's name/description/version from source). Does not touch versions or READMEs. See `docs/conventions/licensing.md` + `xtension-claude-md.md`.

## Convention library

The reusable patterns live in `docs/conventions/` — the single source of truth. The references cite these pages by symbol; the pages cite the `wrapper` template's code (`templates/x-tensions/wrapper/`), so nothing drifts. Key pages: `naming-deployment`, `item-collection`, `threading-model`, `events-emission`, `output-writers`, `output-dir`, `add-output-to-case`, `verbose-logging`, `subprocess-stdio`, `helper-exe-verification`, `ctrl-to-save`, `wrapper-anatomy`, `tool-resolution`, `manager-compatibility`, `licensing`, `versioning`, `readme-roadmap`, `xtension-claude-md`, `repo-hygiene`.

**Manager compatibility (opt-in — do not default to it).** `xways-xt-manager` (the tabbed host that loads manager-compatible X-Tensions) is a **separate project that is not yet public, and its contract may still change**, so do **not** make X-Tensions manager-compatible by default. Use a plain template (`cpp`, `python`, or `wrapper`) unless the user **specifically asks** for manager support — only then scaffold with `-Template xtmgr` or port it in. The contract (`manager-plugin.h`, ABI 1) and how to add it are documented in `references/manager-compat.md`.

## Close the loop

After learning something new about the API/behavior, record it: update the relevant `docs/` page (and `docs/INDEX.md` / `docs/exemplars.md` as needed), using absolute dates. See `references/docs-loop.md`.

## Examples

- **"Wrap yara in an X-Tension"** → wrap flow: load `references/wrapper-generator.md`; scaffold with `new-xtension.ps1 -Name yara -Template wrapper -DryRun`, then for real; fill the `// TODO` stubs (the tool's command line + result-to-item mapping); build-gate with `build-xtension.ps1 -Name xways-yara`. Result: a deployable `xtensions\xways-yara\` bundle.
- **"How do I read a file's bytes from an X-Tension?"** → guardrail flow: answer from `docs/xways-reading-events-and-items.md` (`XWF_OpenItem` → `XWF_Read` → `XWF_Close`), citing the `nFlags` table in `docs/xways-openitem-flags.md`; verify anything uncertain against the live `XWF_functions.html`.
- **"Audit my old X-Tension for 21.8"** → audit flow: load `references/audit-modernize.md`; check `XT_Prepare` return flags, deprecated calls (`XWF_AddToReportTable` → `XWF_Label`), action-code constants, and convention gaps; output a prioritized TODO list — do not change code until asked.

## Invocation

This skill auto-triggers on the phrases in its description. It is also reachable as the slash command **`/xtension <new|wrap|port|audit|docs> [name]`** (namespaced as `/xways-xtension-authoring:xtension` when installed as a plugin), which routes to the same flows.
