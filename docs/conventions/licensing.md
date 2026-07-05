# Licensing

License every X-Tension **MIT**. Consistent licensing across the
repo keeps a public release unambiguous and lets analysts reuse the code
freely.

## What every X-Tension needs

1. **A standalone `LICENSE` file** at the X-Tension root — the verbatim MIT
   text with `Copyright (c) <year> <NAME>`. The scaffold
   (`scripts/new-xtension.ps1`) writes this from
   `.claude/skills/xways-xtension-authoring/assets/LICENSE.tmpl`.
2. **A descriptive header banner** at the top of the main source file — the
   `// ====` block that summarises what the tool does (see the header banner in
   the `wrapper` template `templates/x-tensions/wrapper/my_xtension.cpp` for the
   shape). This is documentation, not the legal text; the `LICENSE` file carries
   the legal text.
3. **Recommended:** an SPDX + copyright line in the header so each source file
   is self-identifying (matters for automated license scanners on a public
   repo):

   ```cpp
   // SPDX-License-Identifier: MIT
   // Copyright (c) 2026 <NAME>
   ```

4. **`.rc` `LegalCopyright`** (X-Tensions with a resource script) reads
   `Copyright (c) <year> <NAME>`.

## Copyright holder + year

- Holder: **<NAME>** (project-wide; pass `-Author` to the scaffold to
  override for a fork).
- Year: the year the X-Tension was first authored (the scaffold stamps the
  current year via `-Year`). Don't churn the year on every edit.

## Third-party / wrapped tools

Wrappers redirect to an upstream tool (e.g. `bulk_extractor`, `yara`)
but **do not commit the tool's binary** — it's downloaded from
the upstream release at install time (see `docs/conventions/repo-hygiene.md`).
Because the wrapper does not redistribute the binary, **link to** the upstream license
rather than vendoring a copy — a link never goes stale when upstream relicenses
or revises terms.

- In the README, attribute the upstream project: link to its repo **and** its
  license, e.g. "Wraps
  [trufflehog](https://github.com/trufflesecurity/trufflehog) —
  [AGPL-3.0](https://github.com/trufflesecurity/trufflehog/blob/main/LICENSE)".
- The wrapper's MIT `LICENSE` covers only the wrapper code in its folder.
- **Exception:** if a wrapper ever *does* ship the upstream binary in-repo, you
  must vendor that tool's license file beside the wrapper's — redistribution requires it.

## Do / Don't

- **Do** ship a standalone MIT `LICENSE` at every X-Tension root.
- **Do** keep upstream tool licenses for wrapped binaries.
- **Don't** invent a new license or change the holder without updating this page.
- **Don't** put credentials, contact details, or names beyond the copyright
  holder into source headers.

**Source of truth:** `.claude/skills/xways-xtension-authoring/assets/LICENSE.tmpl`
(MIT text) + the header banner in the `wrapper` template
(`templates/x-tensions/wrapper/my_xtension.cpp`).
