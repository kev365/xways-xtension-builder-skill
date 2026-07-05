# Per-X-Tension CLAUDE.md

Each X-Tension carries Claude Code guidance specific to that tool, following the
same pattern as the repo-root policy doc: a **tracked `CLAUDE.md.example`** that
collaborators copy to a **git-ignored local `CLAUDE.md`**.

## Why a `.example`, not a committed `CLAUDE.md`

- `.gitignore` ignores `CLAUDE.md` at every level, so each analyst's local
  `CLAUDE.md` — which may hold local paths / deploy targets — stays private.
- `CLAUDE.md.example` does **not** match that ignore, so the *template* is
  version-controlled and shared.
- Collaborators run `copy CLAUDE.md.example CLAUDE.md` in the folder and tailor
  it. Mirrors the repo-root `CLAUDE.md.example` → `CLAUDE.md` convention.

The scaffold writes `CLAUDE.md.example` from `assets/CLAUDE.md.example.tmpl`.

## What goes in it (extension-specific only)

Do **not** duplicate the repo-root `CLAUDE.md` / authoring skill — link to them.
Capture only what's specific to this X-Tension:

- One-line purpose + the `<name>` / DLL stem.
- Version + the beta note.
- Identity-constant locations (`NAME`, `VERSION`, `DESCRIPTION`, `REPORT_TABLE`).
- Build one-liner (the `build-xtension.ps1` invocation).
- The **wrapped tool** (if any): its `--version` identity needle and exact CLI
  argument shape.
- Config / sidecar files and cfg keys (live `.cfg` is git-ignored).
- Gotchas, test-data notes, quirks.
- Which conventions are wired (links to `docs/conventions/*`).
- A "don't commit" reminder (DLL, live `.cfg`, local paths, case data).

## No PII in the committed `.example`

The `.example` is public — keep it generic. **No** `C:\Users\…` paths, real case
data, machine names, or credentials. Local specifics go only in the git-ignored
`CLAUDE.md` copy. See `docs/conventions/repo-hygiene.md`.

## Do / Don't

- **Do** keep the `.example` generic and the local `CLAUDE.md` for your
  environment.
- **Do** link to root policy / convention pages instead of copying them.
- **Don't** commit a real `CLAUDE.md` (it's git-ignored for a reason).
- **Don't** put local paths or case data in the `.example`.

**Source of truth:** repo-root `CLAUDE.md.example` (the pattern) +
`assets/CLAUDE.md.example.tmpl` (the scaffold skeleton).
