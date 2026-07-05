---
description: Scaffold, wrap, port, audit, or document an X-Ways Forensics X-Tension (routes to the xways-xtension-authoring skill)
argument-hint: <new|wrap|port|audit|docs> [name]
---

Invoke the **xways-xtension-authoring** skill (via the Skill tool) to handle this X-Tension task, then follow its hard gates and the matching flow reference.

Requested subcommand + arguments: `$ARGUMENTS`

Route the subcommand to the skill's flow:

- `new [name]` → scaffold a brand-new X-Tension (`references/scaffold-new.md`); if the tool concept isn't decided yet, brainstorm it first (e.g. the `superpowers:brainstorming` skill, if you have it).
- `wrap [name]` → CLI-tool wrapper generator (`references/wrapper-generator.md`).
- `port [name]` → inject a CLAUDE.md convention into an existing X-Tension (`references/port-convention.md`).
- `audit [name]` → audit / modernize an untested X-Tension (`references/audit-modernize.md`).
- `docs` → close-the-loop docs / CLAUDE.md update (`references/docs-loop.md`).

If no subcommand is given, ask which flow is wanted (or infer it from the rest of the arguments). Load `SKILL.md` plus the matching reference and honor its hard gates.

**Script paths.** When installed as a plugin, the skill's scaffold/build scripts are `${CLAUDE_PLUGIN_ROOT}/.claude/skills/xways-xtension-authoring/scripts/new-xtension.ps1` and `${CLAUDE_PLUGIN_ROOT}/.claude/skills/xways-xtension-authoring/scripts/build-xtension.ps1`; in a clone they are under the repo root at `.claude/skills/xways-xtension-authoring/scripts/`. Run them with `-DestRoot <the user's project>` (default: current directory) so output lands in the user's project, not the plugin cache — the scripts refuse to write into the cache.

**Gates.** Consult `docs/exemplars.md` before copying anything; never invent `XWF_` calls; and don't edit the read-only `templates/x-tensions/` or a user-acquired SDK `references/api/` tree. (That SDK tree is the "never edit `references/`" gate — this skill's own `references/*.md` flow guides are normal files.)
