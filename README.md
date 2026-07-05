# X-Ways X-Tension Builder Skill

[![CI](https://github.com/kev365/xways-xtension-builder-skill/actions/workflows/ci.yml/badge.svg)](https://github.com/kev365/xways-xtension-builder-skill/actions/workflows/ci.yml)

A [Claude Code](https://claude.com/claude-code) **skill** and **knowledge base**
for authoring [X-Ways Forensics](https://www.x-ways.net/forensics/)
**X-Tensions** — the `xways-<name>.dll` plugins that extend X-Ways (wrap external
forensic tools, parse artifacts natively, drive the Events Viewer / Directory
Browser).

It gives Claude the X-Ways-specific *how*: pick a template, scaffold + rename +
set identity, wire in the project conventions (helper-exe verification,
Ctrl-to-save, output directory, subprocess stdio, manager compatibility), and
verify every `XWF_*` API call against distilled, citable reference notes so
generated code never invents API.

> **Unofficial / community project.** Not affiliated with, endorsed by, or
> supported by X-Ways Software Technology AG. Provided as-is under the MIT
> License. "X-Ways", "X-Ways Forensics", and "WinHex" are trademarks of
> X-Ways AG.

## What's inside

| Path | What's there |
| --- | --- |
| [`.claude/skills/xways-xtension-authoring/`](.claude/skills/xways-xtension-authoring/) | The skill — `SKILL.md` flow router, reference guides, and PowerShell scaffold/build/hygiene scripts |
| `.claude/commands/xtension.md` | The `/xtension` slash command |
| [`templates/x-tensions/`](templates/x-tensions/) | Starter templates: `cpp`, `cpp-xtmgr-compatible`, `python`, and a rich CLI-wrapper `wrapper` template |
| [`docs/`](docs/INDEX.md) | Distilled X-Tension API reference notes + the [convention library](docs/conventions/index.md) |
| [`CHANGELOG.md`](CHANGELOG.md) | Release history + known issues queued for the next release |

## Install (as a Claude Code plugin)

```text
/plugin marketplace add kev365/xways-xtension-builder-skill
/plugin install xways-xtension-authoring@xways-xtension-builder
```

Then ask Claude to "scaffold a new X-Tension", "wrap `<tool>` in an X-Tension",
or run `/xtension new <name>`. The skill also auto-triggers on those phrases.

**Two ways to use it:**

- **Installed as a plugin** (above) — you get the skill's *guidance* and the
  `/xtension` command in any project. Best for "wrap this tool" / "audit my
  X-Tension" conversations.
- **Cloned and opened in Claude Code** — the skill auto-loads from
  `.claude/skills/`, and the **scaffold/build scripts run against the cloned
  working copy** (they create `x-tensions/<name>/` in the clone and build there).
  This is the path for actually *authoring* an X-Tension with the bundled scripts
  and templates.

## Quickstart

After installing, scaffold and build your first X-Tension — conversationally, or
drive the scripts directly:

- **Conversationally:** ask Claude *"scaffold a new X-Tension that wraps `<tool>`"*,
  or run `/xtension new myscanner`.
- **Scripts** (when you've cloned the repo), from the repo root in PowerShell:

  ```powershell
  # Scaffold from the CLI-wrapper template (dry-run first to preview the plan)
  .claude/skills/xways-xtension-authoring/scripts/new-xtension.ps1 -Name myscanner -Template wrapper -DryRun
  .claude/skills/xways-xtension-authoring/scripts/new-xtension.ps1 -Name myscanner -Template wrapper

  # Fill in your tool's command + result parsing (see the // TODO markers in
  # x-tensions/xways-myscanner/), then build + deploy into your X-Ways install:
  .claude/skills/xways-xtension-authoring/scripts/build-xtension.ps1 -Name xways-myscanner -DeployRoot "<your X-Ways install>"
  ```

See [Prerequisites](#prerequisites) for the build toolchain and SDK.

## Prerequisites

- **X-Ways Forensics 21.x+** (Windows x64) to run the X-Tensions you build.
- **MSVC (x64)** — the "x64 Native Tools Command Prompt for VS 2022" (VS 2019
  Build Tools also work; `build.bat` auto-bootstraps either) — to compile.
- **The X-Ways X-Tension SDK** (the `X-Tension.h` header) to build C++
  X-Tensions. This repo does **not** ship the SDK — it is copyright X-Ways AG.
  See [docs/getting-the-sdk.md](docs/getting-the-sdk.md) to acquire your own copy.

## Usage

```powershell
# Scaffold (dry-run first to review the planned copies / renames / edits)
.claude/skills/xways-xtension-authoring/scripts/new-xtension.ps1 -Name <name> -Template wrapper -DryRun

# Build (close X-Ways first — the DLL is locked while it runs; no hot reload)
.claude/skills/xways-xtension-authoring/scripts/build-xtension.ps1 -Name xways-<name>
```

See the [knowledge base](docs/INDEX.md), the
[convention library](docs/conventions/index.md), and the
[API guardrail](.claude/skills/xways-xtension-authoring/references/api-guardrail.md).

## Contributing, sharing & feedback

This is a community project and **feedback is genuinely wanted**:

- **Built an X-Tension with this skill? Share it.** The canonical home for
  community X-Tensions is X-Ways' own
  [third-party X-Tensions list](https://www.x-ways.net/forensics/x-tensions.html) —
  contact X-Ways to get yours listed (their
  [X-Tension page](https://www.x-ways.net/forensics/x-tensions/api.html) has the
  submission details). You're also welcome to link your repo in an issue so it can
  join [docs/exemplars.md](docs/exemplars.md) and feed patterns back into the templates.
- **Ideas to improve the skill, templates, or docs?** Open an issue. Corrections
  to the API notes are especially valuable.

See [CONTRIBUTING.md](CONTRIBUTING.md) and [SECURITY.md](SECURITY.md).

## License & attribution

MIT — see [LICENSE](LICENSE). The API reference notes are distilled, paraphrased,
or empirically derived; the X-Ways SDK, manuals, and user-forum content are
**not** redistributed here. Credits to X-Ways AG, `xwf-api-rs`, and community
X-Tension authors are in [NOTICE](NOTICE).

## A note on how this was made

This skill and knowledge base were **generated with the help of an AI agent
(Claude)**, drawn from notes, experiments, and conventions collected while
building X-Tensions for X-Ways Forensics. The material has been reviewed, but
mistakes and out-of-date details are inevitable — **corrections, clarifications,
and better information are very welcome.** Please open an issue or PR.
