# README & roadmap

Every X-Tension ships a `README.md` modelled on the scaffold skeleton
(`assets/README.md.tmpl`) — concise, analyst-facing, no emojis. The scaffold
writes the skeleton; fill it in.

## Section order

1. `# <name>` — title.
2. **Intro** — one or two sentences on what it is (optional screenshot `<img>`).
3. `Status: <version>` — the beta / version line (see
   `docs/conventions/versioning.md`).
4. `## What it does` — bullets, behavior-focused.
5. `## Requirements` — OS, X-Ways version, helper binaries, license needs.
6. `## Authentication` — **only** if the tool handles credentials (e.g. a tool
   that stores API credentials in a DPAPI-encrypted `.cfg`).
7. `## Install` — the `xtensions\<name>\` deploy-layout code block.
8. `## Run` — how to invoke from X-Ways (`Tools → Run X-Tensions…`).
9. `## Roadmap` — planned work / known limitations (see below).
10. `## Disclaimer` — community tool, not affiliated with X-Ways AG.
11. `## License` — `Released under the MIT License. See [LICENSE](LICENSE).`

Add tool-specific sections (dialog walkthrough, output format, caveats) between
Run and Roadmap as needed.

## Roadmap convention

- Default: an inline **`## Roadmap`** section — a checkbox / bullet list of
  planned features and known gaps. Standardise on the `## Roadmap` heading.
- Promote to a separate **`ROADMAP.md`** only when it grows large or tracks
  milestones. Link to it from the README.
- Keep roadmap items honest — they're public. No internal paths, customer
  names, or dates you can't commit to.

## Don't leak

The README is public. No `C:\Users\…` paths, no real case data, no creds. See
`docs/conventions/repo-hygiene.md`.

**Source of truth:** `.claude/skills/xways-xtension-authoring/assets/README.md.tmpl`
(the scaffold skeleton — section shape).
