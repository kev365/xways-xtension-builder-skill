# scaffold-new — New X-Tension flow

Use this reference when the flow router in `SKILL.md` routes to **new**.

## 0. Ideation gate

If the tool concept is still open-ended ("what should I build next?"), decide the
tool's name, purpose, and primary invocation mode (run-once vs RVS per-item vs
CLI wrapper) first — a brainstorming skill like `superpowers:brainstorming` helps
if you have it. Return here once they're decided.

## 1. Pick template or exemplar

Consult `references/decision-tables.md` for the full selection matrix.
Quick rules:

- Events API needed → **C++** template only (`XT_Python.dll` does not expose
  `XWF_AddEvent` / `XWF_GetEvent` — hard gate in `SKILL.md`).
- **New analyst-facing C++ X-Tension → bare `cpp` template** (or the `wrapper`
  template if it wraps a CLI tool). Manager compatibility (`xtmgr`) is **opt-in
  and deferred** — `xways-xt-manager` is a work in progress whose contract may
  still change, so reach for it only when the user **specifically asks**. See
  `references/manager-compat.md`.
- Wrapping an external CLI tool → **wrapper** template (`-Template wrapper`) —
  a manager-compatible CLI-wrapper that already wires helper-exe verification,
  Ctrl-to-save, output-dir, and subprocess stdio. See
  `references/wrapper-generator.md`.
- Needs Python libraries (and not Events API) → **python** bare template
  (cannot be manager-compatible — `XwaysManagerPluginEntry` is a C++ export).
- Want a proven dialog + cfg lifecycle already wired → start from the
  **wrapper** template (it ships the full dialog + cfg lifecycle), then adapt.

`docs/exemplars.md` is a registry of **community** exemplars to read and
port-from with attribution — none are bundled in this repo, so they are not
copy-targets. The `-Exemplar` parameter applies only to an exemplar you have
locally in your own project. Scaffold off a template; port patterns from a
community exemplar with an attribution comment.

## 2. Dry-run first

```powershell
scripts/new-xtension.ps1 -Name <name> -Template cpp -DryRun
```

For a CLI-tool wrapper, use the wrapper template:

```powershell
scripts/new-xtension.ps1 -Name <name> -Template wrapper -DryRun
```

Review the planned copies, renames, and edits the script prints. Only proceed
when the plan looks right.

Full parameter set:

```
scripts/new-xtension.ps1 -Name <name> [-Template cpp|python|xtmgr|wrapper]
                          [-Exemplar <local-exemplar>]
                          [-Version <ver>] [-Description <desc>]
                          [-ReportTable <table>]
                          [-DryRun] [-Force]
```

(`xtmgr` copies `templates/x-tensions/cpp-xtmgr-compatible/`; `wrapper` copies
the CLI-wrapper template at `templates/x-tensions/wrapper/`.)

Use `-Template` **or** `-Exemplar`, not both. `-Exemplar` is for an exemplar you
have locally in your own project — none are bundled in this repo.

## 3. Run for real

```powershell
scripts/new-xtension.ps1 -Name <name> -Template cpp
```

The script copies the template into `x-tensions/xways-<name>/`, renames every
source file to the `xways-<name>` stem, and updates identity constants.

## 4. Post-copy checklist

The script handles the mechanical renames. Verify before calling the scaffold
done:

- [ ] Source folder is `x-tensions/xways-<name>/` (hyphenated source tree).
- [ ] All three source files renamed: `xways-<name>.cpp`, `xways-<name>.def`,
      and (if applicable) `xways-<name>.rc`.
- [ ] `.def` `LIBRARY` directive equals `xways-<name>` (no hyphen workaround —
      the stem must match exactly).
- [ ] `build.bat` `set NAME=xways-<name>` agrees with the stem.
- [ ] Identity constants set in `.cpp`: `NAME`, `VERSION`, `DESCRIPTION`,
      `REPORT_TABLE`.
- [ ] If using the `xtmgr` template: the `XwaysManagerPluginDescriptor` identity
      fields (`id`, `display_name`, `description`, `version`) are set (the scaffold
      script fills these from `-Name`/`-Description`/`-Version`), and
      `XwaysManagerPluginEntry` is in the `.def` EXPORTS. See
      `docs/conventions/manager-compatibility.md`.
- [ ] `VERBOSE = true` is present near the top (ships in all templates;
      see `docs/conventions/verbose-logging.md`).
- [ ] `VERSION` carries the `-beta` suffix (`0.1.0-beta` default) — kept until
      the first public release. See `docs/conventions/versioning.md`.
- [ ] `LICENSE`, `README.md` (with a `## Roadmap` section), and
      `CLAUDE.md.example` were generated at the X-Tension root (the scaffold
      writes these from `assets/`). Fill in the README; tailor
      `CLAUDE.md.example`, then copy it to a local (git-ignored) `CLAUDE.md`.

## 5. Wire additional conventions

The bare templates ship with `VERBOSE` already wired (and the **wrapper**
template ships all five conventions below already wired). Add any convention a
bare template lacks by porting it from the **wrapper** template's source rather
than writing from scratch:

| Convention | Convention page | Symbols (in `templates/x-tensions/wrapper/`) |
|---|---|---|
| Output directory | `docs/conventions/output-dir.md` | `GetCaseRootDir`, `DefaultOutputDir` |
| Helper-exe verification | `docs/conventions/helper-exe-verification.md` | `VerifyHelperIdentity`, `PeIdentityContains` |
| Ctrl-to-save gesture | `docs/conventions/ctrl-to-save.md` | `g_runCtrlDown`, `kCtrlPollTimerId` |
| Subprocess stdio | `docs/conventions/subprocess-stdio.md` | `RunCommand` |
| Manager compatibility | `docs/conventions/manager-compatibility.md` | `XwaysManagerPluginEntry`, `On*` callbacks |

The scaffold also generates the **public-release** standard files (`LICENSE`,
`README.md`, `CLAUDE.md.example`); their conventions live in:

| Convention | Convention page |
|---|---|
| Licensing (MIT `LICENSE` + header) | `docs/conventions/licensing.md` |
| Beta versioning (`0.1.0-beta`) | `docs/conventions/versioning.md` |
| README + roadmap | `docs/conventions/readme-roadmap.md` |
| Per-X-Tension CLAUDE.md | `docs/conventions/xtension-claude-md.md` |
| Repo hygiene (gitignore, no creds/paths/DLLs) | `docs/conventions/repo-hygiene.md` |

For full porting instructions see `references/port-convention.md` (and
`references/manager-compat.md` for manager support specifically).

## 6. Build gate

Pass the build gate before claiming the scaffold works:

```powershell
scripts/build-xtension.ps1 -Name <name>
```

The script: refuses to build while X-Ways is running (DLL is locked — no hot
reload; see `docs/build-and-iteration-gotchas.md`), bootstraps the MSVC x64
environment, runs `build.bat`, and verifies
`xtensions\xways-<name>\xways-<name>.dll` was produced. Paste the success
output as evidence.

## 7. Close the loop

If the scaffolding revealed anything new about the API, build system, or
conventions, record it. See `references/docs-loop.md`.

## Cross-references

- Template selection matrix → `references/decision-tables.md`
- CLI-tool wrapper specifics → `references/wrapper-generator.md`
- Porting an individual convention → `references/port-convention.md`
- API correctness gate → `references/api-guardrail.md`
- Community exemplar registry (read-and-port, not bundled) → `docs/exemplars.md`
- Naming + deployment rules → `docs/conventions/naming-deployment.md`
