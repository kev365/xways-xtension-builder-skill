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

If no subcommand is given, ask which flow is wanted (or infer it from the rest of the arguments). Load `SKILL.md` plus the matching reference, consult `docs/exemplars.md` before copying anything, and honor the hard gates — never edit `templates/` or `references/`, never invent `XWF_` calls, and use the bundled `scripts/new-xtension.ps1` / `scripts/build-xtension.ps1` for the scaffold + build gate.
