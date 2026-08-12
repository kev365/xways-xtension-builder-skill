# Behaviour-eval baseline

What the skill does **after** it loads, measured against
[`behavior-eval.json`](behavior-eval.json). Triggering is a separate question —
see [`baseline.md`](baseline.md).

## Current — 2026-08-12, v0.5.0

- **Method:** [`run-behavior-eval.ps1`](run-behavior-eval.ps1), one `claude -p`
  run per scenario, each in its own empty scratch project, against the skill
  installed as a junction at `~/.claude/skills/xways-xtension-authoring`.
- **Grading:** by hand, from the saved transcripts. There is no automated judge
  and this is not a blind grade — see the caveat at the end.

### Result: 28 / 30 assertions, 6 / 6 scenarios produced a skill-backed answer

| Scenario | Assertions | Note |
| --- | --- | --- |
| `guardrail-refuses-invented-api` | 4 / 5 | refuses the fake call cleanly; still leads with the pre-rename name |
| `item-callback-double-count` | 5 / 5 | corrects the stated `0x04` premise outright |
| `subprocess-stdio-crash` | 5 / 5 | **was failing** |
| `threading-refuses-worker-xwf-calls` | 5 / 5 | **was failing** |
| `scaffold-dryrun-and-build-gate` | 5 / 5 | reasoning correct; execution blocked by the harness |
| `wrap-picks-wrapper-template` | 4 / 5 | never states the `<caseRoot>\<NAME>\` output default |

### The two that had previously failed both now pass

`subprocess-stdio-crash` failed in **both arms** of the v0.5.0 A/B:
`superpowers:systematic-debugging` won the routing, kept the run in
evidence-gathering, and the `\NUL` gate was never prescribed. It still wins the
routing — it is the first Skill call in the transcript — but the domain skill
now fires second and delivers the full prescription, including the
easy-to-miss requirement that `bInheritHandles` be `TRUE` *and* the handle
itself be marked inheritable. Worth noting the template only actually
implemented that pattern as of 0.5.0; before then the page cited a `RunCommand`
that did not do what the page said.

`threading-refuses-worker-xwf-calls` previously refused the off-thread call —
the safety property held — but never landed the prescribed shape. It does now:
"dialog collects settings, sets a run-requested flag, returns immediately",
then "run the scan synchronously in `XT_Finalize`". It also declines the
tempting middle path, saying explicitly that marshalling each call back to
X-Ways' thread "would also defeat the point".

### The two misses

**`guardrail` leads with the deprecated name.** It correctly refuses to invent
`XWF_GetItemMD5` and proposes `XWF_GetHashValue` instead, but on report tables
it writes `XWF_AddToReportTable(...)` first and relegates `XWF_Label` to a
parenthetical "superseded in newer versions". The assertion asks for the new
name preferred. Two mitigations worth recording rather than explaining away:
the run could not reach the live `XWF_functions.html` (the guardrail flow's
tiebreaker) because the harness denied `WebFetch`, so it fell back on memory —
and most published X-Ways material predates the rename, which
[api-guardrail.md](../references/api-guardrail.md) already warns about. The
same run of `wrap-picks-wrapper-template` used `XWF_Label` correctly, so the
behaviour is inconsistent rather than uniformly wrong.

**`wrap` never mentions the output-directory default.** `wrapper-generator.md`
§7 states it, and the run read that file, but the answer only refers vaguely to
"a per-run CSV in the output dir". This is an emphasis problem, not a gap in
the reference.

### Harness limits that shaped the runs

`claude -p` cannot obtain tool approvals non-interactively, so several calls
were denied mid-run. `Read` into the installed skill directory worked
throughout — the transcripts show the reference pages being read — but `Bash`,
`WebFetch`, `PowerShell` and `AskUserQuestion` were blocked. That gated the
scaffold scenario's actual execution (its *reasoning* is still gradable and
correct: dry-run first, right stem, right version, and an explicit refusal to
call the result analyst-ready without build output) and, more materially, it
denied the guardrail scenario its live-page tiebreaker.

A run with approvals granted would test more of the scaffold flow. Nothing here
suggests the blocked calls would change the two misses.

### Caveat on this grade

The same author wrote the changes under test, the `expected_behavior` lists,
and this grade. That is the weakest form of evidence in the repo, and it is the
same blind spot that let three drifted code blocks through the 2026-08-09
audit. The raw transcripts are written to `evals/runs/<timestamp>/` (git-ignored)
so the grade can be checked rather than taken on trust. Re-grade blind if the
result ever needs to carry weight.

## Historical — 2026-08-09, v0.5.0 A/B

Six scenarios run against both `main` and the restructure branch to test
whether the 28% SKILL.md trim degraded any gate. It did not: where the arms
differed the branch was equal or better. Three issues surfaced, present in
**both** arms and therefore not caused by the trim — the deprecated-call habit,
`superpowers:systematic-debugging` suppressing the subprocess gate, and the
threading gate's prescribed shape not landing. The latter two are now fixed;
the first is reduced but not gone.
