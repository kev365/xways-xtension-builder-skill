# Contributing

This is an unofficial, community project, kept intentionally low-process. There's no
long guide or checklist to follow. Feedback, ideas, and bug reports are welcome — open
an issue if something's wrong, missing, or could be clearer.

## Built an X-Tension? Share it with X-Ways

X-Ways welcomes community X-Tensions and maintains the canonical list on their site:

- X-Tension page / API: <https://www.x-ways.net/forensics/x-tensions/api.html>
- Third-party X-Tensions list: <https://www.x-ways.net/forensics/x-tensions.html>

To get yours listed, contact X-Ways with a link to it — their X-Tension page has the
current submission details.

You're also welcome to drop a link to your repo in an issue so it can be added to
[docs/exemplars.md](docs/exemplars.md) and any useful patterns can flow back into the
templates.

## Improving the skill itself

Small, scoped changes are easiest — a template fix, a convention tweak, a doc
correction. Two things matter because this is a public repo:

- **Don't commit copyrighted X-Ways material** (the SDK header, manuals, or forum
  content) or **binaries / secrets / local paths**. The API notes here are distilled,
  paraphrased, or empirical and cite official sources by link. See
  [docs/conventions/repo-hygiene.md](docs/conventions/repo-hygiene.md) and
  [docs/getting-the-sdk.md](docs/getting-the-sdk.md).
- If you change a template, build it once with `build-xtension.ps1` so we know it still
  compiles.

That's it — thanks for helping make X-Tension authoring easier.
