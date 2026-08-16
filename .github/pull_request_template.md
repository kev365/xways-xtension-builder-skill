<!-- Thanks for contributing! A few repo-specific notes. -->

## What this changes

<!-- One or two sentences. Link the issue if there is one. -->

## Checklist

- [ ] **Gates pass locally**: `tests/check-*.ps1` and, if you touched
      templates or scripts, `tests/test-scaffold-*.ps1` (CI runs them all,
      including a scaffold + compile of both C++ templates).
- [ ] **No copyrighted X-Ways material** (SDK headers, manuals, forum text) —
      docs stay distilled/empirical with links to official sources
      (`docs/getting-the-sdk.md`).
- [ ] **No secrets, local paths, machine names, or case data** —
      `scripts/prepublish-scan.ps1` is clean.
- [ ] **API claims cite evidence**: an official page, the SDK header, or an
      empirical observation with the X-Ways version. Never invent `XWF_*`
      calls or flags (`references/api-guardrail.md`).
- [ ] **Convention changes update the owner page** in `docs/conventions/`
      (single source of truth) rather than duplicating text elsewhere.
- [ ] **Template changes applied to all applicable templates** — the
      template-parity gate will catch drift between cpp / wrapper / python.
- [ ] **CHANGELOG.md** Unreleased section updated for user-visible changes.

## Verification

<!-- What you ran and observed: gate output, a scaffold round-trip, or the
     empirical test backing a docs change. -->
