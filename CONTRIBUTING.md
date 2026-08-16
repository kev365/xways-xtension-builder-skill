# Contributing

Improvements to the templates, scripts, gates, and the knowledge base are
welcome. Two ground rules shape everything here:

- **No copyrighted X-Ways material** (SDK headers, manuals, forum text). The
  `docs/` notes are distilled/empirical only and cite official sources by
  link — see [docs/getting-the-sdk.md](docs/getting-the-sdk.md).
- **API claims need evidence**: an official page, the SDK header, or an
  empirical observation with the X-Ways version it was seen on. Never invent
  `XWF_*` calls or flags ([references/api-guardrail.md](references/api-guardrail.md)).

The PR template's checklist mirrors what CI enforces; run the gates locally
before pushing:

```powershell
Get-ChildItem tests/check-*.ps1 | ForEach-Object { pwsh -NoProfile -File $_ }
pwsh -NoProfile -File tests/test-scaffold-rename.ps1     # if you touched templates/scripts
pwsh -NoProfile -File tests/test-scaffold-identity.ps1
pwsh -NoProfile -File scripts/prepublish-scan.ps1        # hygiene: no secrets/paths/case data
```

## Live-editing the skill while you use it (junction install)

The plugin install (see the README) is a snapshot in Claude Code's plugin
cache. For working *on* the skill, junction your clone into your personal
skills directory instead — the skill is then live in every project, and any
edit you make while authoring an X-Tension is an edit to the repo working
tree that you can commit. From an ordinary (non-elevated) Command Prompt:

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

If that is refused, skip it — the skill still auto-triggers, and you can
invoke it directly as `/xways-xtension-authoring`. Prefer that over copying
the file: a copy is the drift this layout exists to prevent.

To undo either link, remove the link itself — never the target:

```bat
rmdir "%USERPROFILE%\.claude\skills\xways-xtension-authoring"
del   "%USERPROFILE%\.claude\commands\xtension.md"
```

## Where changes go

- **Conventions** have a single owner page under
  [docs/conventions/](docs/conventions/index.md) — update the owner, don't
  duplicate its text elsewhere (a stale second copy is how contradictions
  start).
- **Template changes** apply to every template they're relevant to — the
  template-parity CI gate catches drift between `cpp` / `wrapper` / `python`.
- **User-visible changes** get a line in `CHANGELOG.md`'s Unreleased section.
