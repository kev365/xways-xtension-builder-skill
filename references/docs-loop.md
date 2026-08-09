# docs-loop — Close the loop

Use this reference when the flow router in `SKILL.md` routes to **docs-loop**,
or at the end of any other flow when new information was discovered or a
convention was ported to an X-Tension.

## When to write back

Write back whenever:

- A new API call, flag bit, property number, or behavior is confirmed
  empirically (a live X-Ways test, or the official API docs).
- A convention is ported to an X-Tension (build gate passed).
- An exemplar is vetted and its verdict should be upgraded in `docs/exemplars.md`.
- A new community exemplar you want to track (cloned locally in your own project).
- A new public source (an API page section, a public blog post, a changelog)
  was read and should be summarized so future sessions do not re-fetch it.

## Consider sharing it upstream

This skill + knowledge base ships as a public repo. If you confirm a new API
fact, flag, property number, behavior quirk, or a genuinely useful convention,
consider whether it's worth contributing back to the **source repo**
([`kev365/xways-xtension-builder-skill`](https://github.com/kev365/xways-xtension-builder-skill))
via an issue or PR — include how you verified it. It helps every future user and
keeps the shared notes current. (Worth checking there first, too: someone may
already have documented it.)

## Where to write

| What changed | Write to |
|---|---|
| New empirical API/behavior finding | The relevant `docs/` topic page (e.g. `docs/xways-events-api.md`, `docs/xways-openitem-flags.md`) AND `docs/events-viewer-empirical-findings.md` if the finding came from a probe run |
| New external source distilled | New `docs/<source-slug>.md` (one file per source), PLUS an entry in `docs/INDEX.md` |
| Exemplar verdict changed | `docs/exemplars.md` — update the verdict cell and the vetting summary line |
| Convention ported to an X-Tension | Wherever the project tracks rollout — the X-Tension's README roadmap, or a project `CLAUDE.md` if it keeps one |
| X-Tension README updated | The X-Tension's own `README.md` (update its roadmap / TODO list) |

## Rules for doc entries

- **Absolute dates** — write `2026-05-31`, never "today" or "last week".
- **Never invent** — only record what was directly observed, tested, or cited
  from an authoritative source. Note the source inline.
- **Cite the source** — include the URL (for public pages), commit hash, or
  file path.
- **One source per file** — each `docs/<slug>.md` covers one upstream source
  (a specific public API page, a public blog post, a book section).
  Do not mix multiple independent sources in one file.
- **Index entry required** — every new `docs/` file must have a corresponding
  entry in `docs/INDEX.md` (title, slug, one-line description).

## How to record a completed rollout

If the project keeps a `CLAUDE.md` (or a README roadmap) that tracks which
conventions have been ported to which X-Tensions, mark the item done there —
remove or annotate the entry, with an absolute date if noting when it was
completed.

Do not promote a pattern to a project-wide convention without confirming it is
tested and wired into at least one shipping template (or a vetted exemplar).

## How to update docs/exemplars.md

`docs/exemplars.md` is a basic list of community X-Tensions
(`Project | Lang | License`). To add one, append a row — link the project name
to its public repo URL (if known) and record its license. Before citing an older
X-Tension as a pattern source, sanity-check its `XWF_*` calls still exist on 21+
(see `references/api-guardrail.md`).

## Running mkdocs after doc edits

If the project builds its docs with MkDocs (a `mkdocs.yml` is present — this
repo does not ship one), verify the build after editing `docs/` files:

```powershell
mkdocs build --strict
```

A strict build treats broken internal links as errors. Without MkDocs, verify
that each edited page's relative links resolve (every linked file exists)
before committing.

## Example entry format (new external source)

```markdown
---
source: https://www.x-ways.net/forensics/x-tensions/XWF_functions.html
type: official-doc
fetched: 2026-05-31
last_updated: 2026-05-31
author: project notes
---

# XWF_Label / XWF_GetLabels (21.8 Beta 5)

...
```

## Cross-references

- After completing a port → `references/port-convention.md`
- After completing an audit → `references/audit-modernize.md`
- After a new API find → `references/api-guardrail.md`
- docs/INDEX.md → `docs/INDEX.md`
- Exemplar registry → `docs/exemplars.md`
