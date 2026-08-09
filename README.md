# X-Ways X-Tension Builder Skill

[![CI](https://github.com/kev365/xways-xtension-builder-skill/actions/workflows/ci.yml/badge.svg)](https://github.com/kev365/xways-xtension-builder-skill/actions/workflows/ci.yml)

A [Claude Code](https://claude.com/claude-code) **skill** and **knowledge base**
for authoring [X-Ways Forensics](https://www.x-ways.net/forensics/)
**X-Tensions** — the `xways-<name>.dll` plugins that extend X-Ways (wrap external
forensic tools, parse artifacts natively, drive the Events Viewer / Directory
Browser).

It gives Claude the X-Ways-specific *how*: pick a template, scaffold + rename +
set identity, wire in the project conventions (helper-exe verification,
Ctrl-to-save, output directory, subprocess stdio), and
verify every `XWF_*` API call against distilled, citable reference notes so
generated code never invents API.

> **Unofficial / community project.** Not affiliated with, endorsed by, or
> supported by X-Ways Software Technology AG. Provided as-is under the MIT
> License. "X-Ways", "X-Ways Forensics", and "WinHex" are trademarks of
> X-Ways AG.

## What's inside

**The repository root *is* the skill root** — `SKILL.md` sits at the top and every
path it references resolves beneath it. That makes the skill self-contained: it
works identically as a plugin, as a clone, as a junction into `~/.claude/skills/`,
or zipped for upload.

| Path | What's there |
| --- | --- |
| [`SKILL.md`](SKILL.md) | The skill — flow router, hard gates, convention index |
| [`references/`](references/) | Per-flow guides (new / wrap / port / audit / guardrail / docs-loop) |
| [`scripts/`](scripts/) | PowerShell scaffold / build / hygiene / backfill tooling |
| [`assets/`](assets/) | `LICENSE` / `README` / `CLAUDE.md.example` file templates |
| [`commands/xtension.md`](commands/xtension.md) | The `/xtension` slash command |
| [`templates/x-tensions/`](templates/x-tensions/) | Starter templates: `cpp`, `python`, and a rich CLI-wrapper `wrapper` template |
| [`docs/`](docs/INDEX.md) | Distilled X-Tension API reference notes + the [convention library](docs/conventions/index.md) |
| [`CHANGELOG.md`](CHANGELOG.md) | Release history + known issues queued for the next release |

## Install (as a Claude Code plugin)

```text
/plugin marketplace add kev365/xways-xtension-builder-skill
/plugin install xways-xtension-authoring@xways-xtension-builder
```

Then ask Claude to "scaffold a new X-Tension", "wrap `<tool>` in an X-Tension",
or run `/xtension new <name>`. The skill also auto-triggers on those phrases.

**Three ways to use it** — all read from one copy of this repo, so nothing can
drift out of sync:

- **Installed as a plugin** (above) — the skill and the `/xtension` command in
  any project. Claude Code copies marketplace plugins into
  `~/.claude/plugins/cache`, so this is a snapshot: run `/plugin update` to pick
  up new releases. **This is the path for using the skill.**
- **Junctioned into your personal skills directory** — the skill is live in
  *every* project, and because the junction points at your clone, any edit you
  make while authoring an X-Tension is an edit to the repo working tree that you
  then commit. **This is the path for improving the skill as you go.** From an
  ordinary (non-elevated) Command Prompt:

  ```bat
  mklink /J "%USERPROFILE%\.claude\skills\xways-xtension-authoring" "C:\path\to\xways-xtension-builder-skill"
  ```

  A directory junction needs no special privileges. To also get the `/xtension`
  slash command, link the one command file — this needs Windows Developer Mode
  (Settings → System → For developers) or an elevated prompt, because *file*
  symlinks are privileged where junctions are not:

  ```powershell
  New-Item -ItemType SymbolicLink `
    -Path   "$env:USERPROFILE\.claude\commands\xtension.md" `
    -Target "C:\path\to\xways-xtension-builder-skill\commands\xtension.md"
  ```

  If that is refused, skip it — the skill still auto-triggers, and you can invoke
  it directly as `/xways-xtension-authoring`. Prefer that over copying the file:
  a copy is the drift this layout exists to prevent.

  To undo either link, remove the link itself — never the target:

  ```bat
  rmdir "%USERPROFILE%\.claude\skills\xways-xtension-authoring"
  del   "%USERPROFILE%\.claude\commands\xtension.md"
  ```

- **Cloned and opened in Claude Code** — the skill auto-loads from the repo root,
  and the scaffold/build scripts run against the clone (they create
  `x-tensions/<name>/` there). Also `claude --plugin-dir .` from the clone to
  exercise the plugin packaging itself for one session.

In every case the scripts write scaffold/build output under the **current
directory** (or `-DestRoot <project>`), never into the skill install — they
refuse to write into a plugin cache.

## Quickstart

After installing, scaffold and build your first X-Tension — conversationally, or
drive the scripts directly:

- **Conversationally:** ask Claude *"scaffold a new X-Tension that wraps `<tool>`"*,
  or run `/xtension new myscanner`.
- **Scripts** (when you've cloned the repo), from the repo root in PowerShell:

  ```powershell
  # Scaffold from the CLI-wrapper template (dry-run first to preview the plan)
  scripts/new-xtension.ps1 -Name myscanner -Template wrapper -DryRun
  scripts/new-xtension.ps1 -Name myscanner -Template wrapper

  # Fill in your tool's command + result parsing (see the // TODO markers in
  # x-tensions/xways-myscanner/), then build + deploy into your X-Ways install:
  scripts/build-xtension.ps1 -Name xways-myscanner -DeployRoot "<your X-Ways install>"
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
scripts/new-xtension.ps1 -Name <name> -Template wrapper -DryRun

# Build (close X-Ways first — the DLL is locked while it runs; no hot reload)
scripts/build-xtension.ps1 -Name xways-<name>
```

See the [knowledge base](docs/INDEX.md), the
[convention library](docs/conventions/index.md), and the
[API guardrail](references/api-guardrail.md).

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
