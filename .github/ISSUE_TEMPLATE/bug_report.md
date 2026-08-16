---
name: Bug report
about: A script, template, gate, or doc in this skill misbehaves or states something wrong
title: ""
labels: bug
assignees: ""
---

## What happened

<!-- What did you run or read, and what went wrong? -->

## Expected

<!-- What should have happened instead? -->

## Where

- [ ] Scaffold/build scripts (`scripts/`)
- [ ] A starter template (`templates/x-tensions/` — which one: cpp / python / wrapper)
- [ ] Knowledge-base docs (`docs/` — which page)
- [ ] CI gates / tests (`tests/`)
- [ ] SKILL.md / references / slash command

## Environment (for script or template issues)

- Skill version (`plugin.json` / SKILL.md frontmatter):
- Install mode: plugin / clone / junction
- PowerShell: 5.1 or 7.x
- X-Ways Forensics version + SR (for template/API issues):

## Repro

```text
Exact command(s) or steps, plus output if available.
```

## API-claim corrections

If you're reporting that a `docs/` page states something the API doesn't
actually do: please include what you observed (X-Ways version, the call, the
result). Empirical evidence versus a live host is this repo's gold standard —
see docs/xways-sdk-conflicts-test-plan.md for how claims get verified.
