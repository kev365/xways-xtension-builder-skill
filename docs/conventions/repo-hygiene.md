# Repo hygiene (GitHub-readiness)

Keep an X-Tension repo tidy and free of secrets, local paths, and large binaries
so it's safe to publish at any time.

## No committed binaries

Compiled DLLs and bundled helper EXEs are **not** committed — they bloat the repo
and aren't needed in source control. Ship them via **GitHub Releases** instead.

- Ignore `*.dll` / `*.exe` globally in `.gitignore`. If you also keep a tracked
  deploy-bundle *structure* (e.g. an `xtensions\<name>\` folder with a
  `.cfg.example`), use a **last-match re-ignore** so the binaries stay out while
  the structure stays tracked:

  ```gitignore
  # if an earlier rule un-ignored a deploy bundle, re-ignore the binaries:
  **/xtensions/**/*.dll
  ```

- If a DLL was already committed, stop tracking it with `git rm --cached <path>`
  (your working copy is kept). Note that git **history** still holds the old
  blob — to publish with a clean history, start a fresh repo from a clean working
  tree, or rewrite history with `git filter-repo` before the first public push.

## Never commit

- **Credentials / secrets** — API keys, tokens, passwords, DPAPI `.cfg` files.
  Track only a sanitised `.cfg.example`; git-ignore the live `.cfg`.
- **Local filesystem paths** — `C:\Users\<you>\…`, test-data dirs, your X-Ways
  install folder. Use placeholders (`<user>`, `<install>`, `<test-data>`) in docs.
- **Personal info** — emails, machine names, usernames in logs / banners.
- **Case data** — evidence, exports, anything from a real case.
- **Copyrighted X-Ways material** — the SDK header, manuals, or user-forum
  content. See [getting-the-sdk.md](../getting-the-sdk.md).

## Pre-publish scrub

Run `scripts/prepublish-scan.ps1` (read-only) and clear every high-severity hit
before a public push. It flags:

- `C:\Users\…` absolute paths
- tracked binaries (`*.dll` / `*.exe` / `*.obj` / `*.pdf` / …)
- tracked copyrighted X-Ways SDK (`references/api|books|templates/`,
  `X-Tension.h`, `XT_API.pas`)
- `case/` data
- email addresses + credential-ish keywords (review-level advisories)

## Do / Don't

- **Do** run `prepublish-scan.ps1` before any public push.
- **Do** keep a sanitised `.cfg.example`; git-ignore the live `.cfg`.
- **Don't** commit DLLs / EXEs — ship them via Releases.
- **Don't** hand-edit deploy bundles into git — let the build script stage them.

**Source of truth:** your repo's `.gitignore` + `scripts/prepublish-scan.ps1`.
