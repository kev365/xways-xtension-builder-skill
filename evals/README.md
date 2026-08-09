# Evals

Two eval sets, measuring different things.

| File | Measures | Automated? |
| --- | --- | --- |
| [`trigger-eval.json`](trigger-eval.json) | whether the `description` gets the skill **consulted** | yes — [`run-trigger-eval.ps1`](run-trigger-eval.ps1) |
| [`behavior-eval.json`](behavior-eval.json) | whether the skill produces the **right answer** once consulted | no — rubric for review |

A skill can trigger perfectly and still give bad guidance, so the two are worth
keeping apart.

## Triggering

`trigger-eval.json` is a should-trigger / should-not-trigger matrix for the
`description` field — the text that decides whether Claude consults the skill.
Re-run it whenever the description changes, to catch **under-triggering** (misses
a real X-Tension task) or **over-triggering** (fires on adjacent work).

- **10 should-trigger** — scaffold / wrap / port / audit / build / publish flows
  and "which `XWF_*` call/flag" questions, including phrasings that never say
  "X-Tension" outright.
- **10 should-not-trigger** — near-misses sharing keywords but needing something
  else: general X-Ways *usage*, open-ended tool ideation, "wrap"/"build" in a
  non-X-Tension sense, and plugins for *other* forensic tools. Each entry's
  `note` records what it probes.

```powershell
pwsh -File evals/run-trigger-eval.ps1 -RunsPerQuery 3 -JsonOut result.json

# Smoke-test the harness on a single case before paying for a full run
pwsh -File evals/run-trigger-eval.ps1 -Filter "trufflehog" -RunsPerQuery 1
```

Each case runs `claude -p` in a scratch project containing **only** the skill's
name and description, so the description alone is under test, and counts the run
as triggered when the `Skill` tool fires for it.

### Why not skill-creator's `run_eval.py`

The upstream runner is POSIX-only and cannot work on Windows, for two
independent reasons: it launches the CLI through `subprocess` with
`shell=False`, so `CreateProcess` only ever looks for `claude.exe` and never
finds the npm-installed `claude.ps1`/`claude.cmd`; and it polls the child pipe
with `select.select()`, which on Windows accepts sockets only. Run against this
repo it reports every query as failed and yields a meaningless 10/20.
`run-trigger-eval.ps1` mirrors its methodology so numbers stay comparable.

### Reading the output

**Distinguish a non-trigger from a non-measurement.** A run that produced no
output is reported as `NO DATA` and exits 2, never as a trigger rate of 0. That
distinction is the difference between "the description under-triggers" and "the
harness broke" — the failure mode that made the upstream runner's 10/20 look
like a real regression.

Treat a `should_trigger: false` case scoring 0 with suspicion until the
harness has also been shown to score a `should_trigger: true` case at 1 in the
same session. A detector that always says "no" passes every negative case.
Conversely, an early version of this script matched the skill name anywhere in
the stream and scored *everything* at 1.0, because the name appears in the
`system/init` event that lists available skills. Both smoke tests, in both
directions, are what catch this.

## Behavior

`behavior-eval.json` covers what happens **after** the skill loads. Six
scenarios, each aimed at a hard gate, written so the tempting wrong answer is
the easy one:

| id | Gate under test |
| --- | --- |
| `guardrail-refuses-invented-api` | never invent `XWF_` calls — asks for code using a plausible fake |
| `item-callback-double-count` | the 2N double-callback, with the `0x04` misconception stated as premise |
| `subprocess-stdio-crash` | `\NUL` + `STARTF_USESTDHANDLES`, reached from a symptom |
| `threading-refuses-worker-xwf-calls` | no `XWF_*` off-thread, under a UI-responsiveness rationale |
| `scaffold-dryrun-and-build-gate` | `-DryRun` first; no completion claim without build output |
| `wrap-picks-wrapper-not-manager` | wrapper template; manager-compat stays opt-in |

There is no automated judge. Run a scenario's `query` against the skill and
check the response against its `expected_behavior` list — by reading it, or by
handing both to a model as a rubric. `probes` records why the case exists, so a
future edit does not weaken it by accident.

Several are deliberately adversarial: `item-callback-double-count` asserts a
false premise the answer must correct, and `threading-refuses-worker-xwf-calls`
issues a direct instruction the skill must decline. Agreeing with the user is
the failure.

## Baseline

[`baseline.md`](baseline.md) records the last measured triggering run: date,
which description version, method, and result. Update it whenever the
description changes — and record the method used, because a number without one
cannot be compared against the next.
