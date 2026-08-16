# Scripts reference

Full parameters and behavior for the four PowerShell scripts in
[`scripts/`](../scripts/). `SKILL.md` carries only the one-line summaries and the
two always-on rules (`-DryRun` first; the build gate) — everything else is here.

## Contents

- Where output goes (`-DestRoot`) — read this first
- `new-xtension.ps1` — scaffold
- `build-xtension.ps1` — build + deploy
- `prepublish-scan.ps1` — hygiene gate
- `backfill-standards.ps1` — LICENSE / CLAUDE.md.example backfill

## Where output goes (`-DestRoot`)

The scaffold/build scripts read templates and assets **from the installed
skill** and write output **under the current directory**, or under a project
passed via `-DestRoot`. They refuse to write into an installed
plugin/marketplace cache, which Claude Code manages and overwrites on update.
(`backfill-standards.ps1` has no `-DestRoot` — it edits a repo working copy in
place and is meant to be run from a clone, not a plugin install.)

Installed as a plugin, the scripts are at `${CLAUDE_PLUGIN_ROOT}/scripts/`. Run
them with `-DestRoot <the user's project>`, or from that project directory.

**The `-DestRoot` passed to `new-xtension.ps1` must be passed to
`build-xtension.ps1` too** — otherwise the build cannot find what you scaffolded.

## `new-xtension.ps1`

Copies a starter template (or a locally-available exemplar) into
`<DestRoot>/x-tensions/xways-<name>/`, renames the source files to the
`xways-<name>` stem, and sets the identity constants.

**Always run with `-DryRun` first** to review the planned copies, renames, and
edits before committing to them.

| Parameter | Meaning |
| --- | --- |
| `-Name <name>` | the `xways-<name>` stem |
| `-DestRoot <project>` | where output lands. Default: current directory. Pass it in plugin mode |
| `-Template cpp\|python\|wrapper` | which starter template to copy |
| `-Exemplar <local-exemplar>` | copy an exemplar under `<DestRoot>/x-tensions/` instead. None are bundled in this repo |
| `-Version` `-Description` `-ReportTable` | identity constants. Version defaults to `0.1.0-beta` |
| `-Author` `-Year` | stamped into the generated `LICENSE` / `CLAUDE.md.example` |
| `-DryRun` | print the plan, write nothing |
| `-Force` | overwrite an existing destination |

Template names map to [`templates/x-tensions/`](../templates/x-tensions/):
`cpp`, `python`, `wrapper` = the CLI-wrapper template.

Beyond copying and renaming, the script generates three project files from
[`assets/`](../assets/): `LICENSE`, `README.md` (replacing the template's generic
copy), and `CLAUDE.md.example`.

## `build-xtension.ps1`

```powershell
build-xtension.ps1 -Name xways-<name> [-DestRoot <project>] [-DeployRoot <install>] [-NoDeploy]
```

In order, it:

1. Locates the X-Tension under `<DestRoot>/x-tensions/`.
2. Refuses to build while X-Ways is running — the DLL is locked and there is no
   hot reload.
3. Bootstraps the MSVC x64 environment if it is not already active.
4. Runs the X-Tension's `build.bat`.
5. Verifies `xtensions\xways-<name>\xways-<name>.dll` was produced.
6. Deploys the staged folder into the X-Ways install at `xtensions\xways-<name>\`.

**This is the build gate.** Never claim a scaffold "works" without pasting this
script's success output.

### Deploy target

Nothing is hardcoded — the target is the user's own environment. Resolution order:

1. `-DeployRoot '<install-root>'` — the folder holding `xwb64.exe` /
   `xwforensics64.exe`. Remembered thereafter in a git-ignored
   `.xtension-deploy.local`.
2. `$env:XWT_DEPLOY_ROOT`.
3. Neither set — the build still succeeds and stages the DLL locally.

`-NoDeploy` skips deployment outright.

**On a user's first build, ask them for their X-Ways install path** and pass it
via `-DeployRoot`.

The mirror is newer-only, so an analyst-edited sidecar `.cfg` / `.yaml` in the
install survives rebuilds.

## `prepublish-scan.ps1`

```powershell
prepublish-scan.ps1 [-Strict]
```

Read-only hygiene scan over git-tracked files. Flags, as **high-severity**
(non-zero exit): local paths (`C:\Users\…`), tracked binaries, and `case/` data.
Flags credential-ish keywords and email addresses as **review advisories** —
confirm each is safe rather than assuming.

Clear it before any public push. See
[repo-hygiene](../docs/conventions/repo-hygiene.md).

## `backfill-standards.ps1`

```powershell
backfill-standards.ps1 [-DryRun] [-Force]
```

Additively backfills a missing `LICENSE` (MIT) and `CLAUDE.md.example` into every
active X-Tension that lacks them. Idempotent; pulls each tool's name, description,
and version from its source. Does not touch versions or READMEs.

See [licensing](../docs/conventions/licensing.md) and
[xtension-claude-md](../docs/conventions/xtension-claude-md.md).
