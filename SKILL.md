---
name: xways-xtension-authoring
description: This skill should be used when the user asks to "create/scaffold a new X-Tension", "wrap a CLI tool in an X-Tension", "port a convention into an X-Tension" (helper-exe verification, Ctrl-to-save, output-dir), "audit/modernize an X-Tension", "build/compile an X-Tension", "prep an X-Tension for public release", or asks which XWF_* API call, flag, or property number to use, for X-Ways Forensics. Covers template selection, the PowerShell scaffold/build scripts, the convention library, and verifying every XWF_ call against distilled API reference notes. Does NOT handle general X-Ways usage questions or open-ended "what tool should I build" ideation.
license: MIT
compatibility: Authoring flows need Claude Code on Windows (PowerShell scaffold/build scripts; MSVC x64 for C++ builds; X-Ways Forensics 21.x to run the result). Guidance/API-reference flows work anywhere.
metadata:
  version: 0.5.0
  author: Kevin Stokes (kev365)
  category: digital-forensics
  tags: x-ways, x-tension, dfir, windows, forensics
  documentation: https://github.com/kev365/xways-xtension-builder-skill
---

# X-Ways X-Tension Authoring

Author and maintain X-Ways Forensics X-Tensions — the `xways-<name>` DLLs that live in an `x-tensions/` working folder — quickly and correctly. Scaffold new X-Tensions by copying and parameterizing a starter template, port the documented conventions into existing ones, audit untested ones for API validity, and route every API question to the authoritative reference so generated code never invents `XWF_` calls.

This skill owns the X-Ways-specific *how*. For open-ended "what should this new tool do" ideation, brainstorm the tool's purpose first (the `superpowers:brainstorming` skill helps if you have it), then return here for template choice, scaffolding, conventions, and build.

Everything this skill needs is bundled with it — every path below is relative to this file.

## Hard gates (never violate)

- **Never edit [`templates/x-tensions/`](templates/x-tensions/) in place** — it is the pristine source. Scaffold a copy into `<project>/x-tensions/xways-<name>/` first (the script does this). A user-acquired SDK lives in a `references/api/` tree in *their* project: read-only, and **never** committed (copyright). That SDK tree — not this skill's [`references/`](references/) flow guides — is what "never edit `references/`" means. See [getting-the-sdk](docs/getting-the-sdk.md).
- **Never invent `XWF_` functions or flags.** Verify every call against, in order: (1) the distilled notes in [`docs/`](docs/INDEX.md); (2) the live `https://www.x-ways.net/forensics/x-tensions/XWF_functions.html`, which carries post-SDK additions; (3) a locally-downloaded SDK header, if present. Route API questions through [api-guardrail](references/api-guardrail.md).
- **`x-tensions/` (hyphen) is the source tree; `xtensions\` (no hyphen) is the build-output / deploy folder.** The build scripts stage, verify, and mirror the no-hyphen path, so a wrong spelling breaks the tooling. It is a project convention, not an X-Ways discovery mechanism — how X-Ways actually finds a DLL is in [naming-deployment](docs/conventions/naming-deployment.md).
- **Close X-Ways before building.** The DLL is locked while X-Ways is open; there is no hot reload.
- **Events API ⇒ C++ template only.** `XT_Python.dll` does not expose `XWF_AddEvent` / `XWF_GetEvent`.
- **Subprocess ⇒ open `\NUL` + `STARTF_USESTDHANDLES`.** X-Ways is a GUI-subsystem process with no console attached, so a child inherits null std handles and any helper writing to stdout/stderr can hard-crash. Hand the child real handles — `\NUL`, or a pipe if you capture output. See [subprocess-stdio](docs/conventions/subprocess-stdio.md).
- **`0x01` delivers each item to *every* per-item callback you export.** Export both `XT_ProcessItem` and `XT_ProcessItemEx` and each item hits both — the empirically verified "2N" double-count. Do per-item work in **one** callback (`XT_ProcessItemEx` for `hItem`), or route both through one deduping collector. RVS is multi-threaded, so shared state needs a mutex. `0x04` is `EXPECTMOREITEMS`, *not* "call `Ex`". See [item-collection](docs/conventions/item-collection.md).
- **Never call `XWF_*` from a worker thread you spawned** — run synchronously on X-Ways' thread. `XWF_AddEvent` off-thread can corrupt the event store or crash the host. A settings dialog should *request* a run, then run it in `XT_Finalize`. See [threading-model](docs/conventions/threading-model.md).
- **Output writers: sanitise to valid UTF-8/XML, propagate I/O errors, bound memory.** Raw log bytes break an `encoding="UTF-8"` XLSX; a silent write error truncates evidence; buffering every row OOMs. Spill + stream + split. See [output-writers](docs/conventions/output-writers.md).
- **Never commit credentials, live `.cfg`, local paths (`C:\Users\…`), case data, or compiled binaries** — binaries ship via GitHub Releases. Run [prepublish-scan.ps1](scripts/prepublish-scan.ps1) before a public push. See [repo-hygiene](docs/conventions/repo-hygiene.md).

## Choose the flow, then load its reference

| To… | Flow | Load |
|---|---|---|
| scaffold a brand-new X-Tension | new | [scaffold-new](references/scaffold-new.md) |
| wrap an external CLI tool | wrap | [wrapper-generator](references/wrapper-generator.md) |
| inject a convention into an existing X-Tension | port | [port-convention](references/port-convention.md) |
| audit / modernize an untested X-Tension | audit | [audit-modernize](references/audit-modernize.md) |
| answer an X-Ways API/behavior question correctly | guardrail | [api-guardrail](references/api-guardrail.md) |
| record a new finding / mark a rollout item done | docs-loop | [docs-loop](references/docs-loop.md) |
| pick template vs exemplar, or decide on a dialog | (any) | [decision-tables](references/decision-tables.md) |
| debug a build / encoding / DLL-loading failure | (any) | [build-and-iteration-gotchas](docs/build-and-iteration-gotchas.md) |
| look up a script's full parameters or deploy behavior | (any) | [scripts](references/scripts.md) |

The `guardrail` row is an always-on correctness layer applied during every flow.

Scaffold from a starter template under [`templates/x-tensions/`](templates/x-tensions/) (`cpp`, `python`, or the CLI-wrapper `wrapper` template). For a CLI-tool wrapper, prefer the `wrapper` template (`-Template wrapper`) — it already wires helper-exe verification, Ctrl-to-save, output-dir, and subprocess stdio. [exemplars](docs/exemplars.md) is a registry of **community** exemplars (with X-Ways 21+ verdicts and attribution) to **read and port patterns from**; none are bundled here.

## Scripts (the deterministic core)

In [`scripts/`](scripts/), runnable from any working directory. Output lands under the **current directory** by default, or a project passed via `-DestRoot` — never the skill install. Full parameters, deploy-target resolution, and the plugin-mode invocation: [scripts](references/scripts.md).

| Script | Does |
|---|---|
| [new-xtension.ps1](scripts/new-xtension.ps1) | copy a starter template into `<DestRoot>/x-tensions/xways-<name>/`, rename to the `xways-<name>` stem, set identity constants, generate LICENSE / README / CLAUDE.md.example |
| [build-xtension.ps1](scripts/build-xtension.ps1) | run `build.bat`, verify the DLL, deploy into the X-Ways install |
| [prepublish-scan.ps1](scripts/prepublish-scan.ps1) | hygiene scan over git-tracked files before a public push |
| [backfill-standards.ps1](scripts/backfill-standards.ps1) | backfill a missing LICENSE + CLAUDE.md.example |

Two rules that always apply:

- **`-DryRun` first** on `new-xtension.ps1` — review the planned copies, renames, and edits before committing to them.
- **`build-xtension.ps1` is the build gate** — never claim a scaffold "works" without pasting its success output. Close X-Ways first, and pass the same `-DestRoot` used to scaffold. On a user's first build, ask them for their X-Ways install path and pass it via `-DeployRoot`.

## Convention library

The reusable patterns live in [`docs/conventions/`](docs/conventions/index.md) — the single source of truth. The pages cite the `wrapper` template's code ([`templates/x-tensions/wrapper/`](templates/x-tensions/wrapper/)), so nothing drifts. Load the one you need:

- **Correctness** — [item-collection](docs/conventions/item-collection.md) · [threading-model](docs/conventions/threading-model.md) · [output-writers](docs/conventions/output-writers.md) · [subprocess-stdio](docs/conventions/subprocess-stdio.md) · [events-emission](docs/conventions/events-emission.md)
- **Wrapping a CLI tool** — [wrapper-anatomy](docs/conventions/wrapper-anatomy.md) · [tool-resolution](docs/conventions/tool-resolution.md) · [helper-exe-verification](docs/conventions/helper-exe-verification.md) · [ctrl-to-save](docs/conventions/ctrl-to-save.md)
- **Settings dialogs** — [xtension-dialog-conventions](docs/xtension-dialog-conventions.md), the long-form UI companion (`.rc` layout, ID ranges, fonts, validation, cancel safety, progress, pickers). Load it when an X-Tension grows a dialog.
- **Output** — [output-dir](docs/conventions/output-dir.md) · [add-output-to-case](docs/conventions/add-output-to-case.md) · [verbose-logging](docs/conventions/verbose-logging.md)
- **Naming + release** — [naming-deployment](docs/conventions/naming-deployment.md) · [licensing](docs/conventions/licensing.md) · [versioning](docs/conventions/versioning.md) · [readme-roadmap](docs/conventions/readme-roadmap.md) · [xtension-claude-md](docs/conventions/xtension-claude-md.md) · [repo-hygiene](docs/conventions/repo-hygiene.md)

## Close the loop

After learning something new about the API/behavior, record it: update the relevant [`docs/`](docs/INDEX.md) page (and [INDEX](docs/INDEX.md) / [exemplars](docs/exemplars.md) as needed), using absolute dates. See [docs-loop](references/docs-loop.md).

## Examples

- **"Wrap yara in an X-Tension"** → wrap flow: load [wrapper-generator](references/wrapper-generator.md); scaffold with `new-xtension.ps1 -Name yara -Template wrapper -DryRun`, then for real; fill the `// TODO` stubs (the tool's command line + result-to-item mapping); build-gate with `build-xtension.ps1 -Name xways-yara`. Result: a deployable `xtensions\xways-yara\` bundle.
- **"How do I read a file's bytes from an X-Tension?"** → guardrail flow: answer from [xways-reading-events-and-items](docs/xways-reading-events-and-items.md) (`XWF_OpenItem` → `XWF_Read` → `XWF_Close`), citing the `nFlags` table in [xways-openitem-flags](docs/xways-openitem-flags.md); verify anything uncertain against the live `XWF_functions.html`.
- **"Audit my old X-Tension for 21.8"** → audit flow: load [audit-modernize](references/audit-modernize.md); check `XT_Prepare` return flags, deprecated calls (`XWF_AddToReportTable` → `XWF_Label`), action-code constants, and convention gaps; output a prioritized TODO list — do not change code until asked.

## Invocation

Reachable as the slash command **`/xtension <new|wrap|port|audit|docs> [name]`** (namespaced as `/xways-xtension-authoring:xtension` when installed as a plugin), which routes to the same flows. `guardrail` is deliberately absent from that list — it is a correctness layer, not a subcommand.
