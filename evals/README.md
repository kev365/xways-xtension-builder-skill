# Evals

Two eval sets, measuring different things.

| File | Measures | Automated? |
| --- | --- | --- |
| [`trigger-eval.json`](trigger-eval.json) | whether the `description` gets the skill **consulted** | yes — [`run-trigger-eval.ps1`](run-trigger-eval.ps1) |
| [`behavior-eval.json`](behavior-eval.json) | whether the skill produces the **right answer** once consulted | generation yes — [`run-behavior-eval.ps1`](run-behavior-eval.ps1); grading no, on purpose |

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

Each case runs `claude -p` in an empty scratch project and counts the run as
triggered when the `Skill` tool fires for this skill. It measures the
**installed** skill (junction or plugin), which is still a test of the
description: only `name` and `description` are pre-loaded into the system
prompt, and the body is read only after the skill triggers.

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
| `wrap-picks-wrapper-template` | wrapper template chosen over bare cpp; helper-exe verification raised |

```powershell
pwsh -File evals/run-behavior-eval.ps1

# Smoke-test the harness on one scenario before paying for all six
pwsh -File evals/run-behavior-eval.ps1 -Filter subprocess
```

Each scenario runs to completion in its own empty scratch project — separate
because the scaffold scenario writes files, and scenarios must not see each
other's output. Per scenario you get the raw `.jsonl` transcript, plus a
readable `.md` carrying the query, the tool-call trace, the final answer, and
the `expected_behavior` list as an **unticked** checklist.

**Generation is automated; grading deliberately is not.** Whoever wrote the
skill changes and the `expected_behavior` lists is the worst person to grade
the result, so the objective half — did the skill fire, which references were
read, what was finally said — is captured mechanically, and the judgement is
left where it can be made honestly. Read the `.md` files, or hand them to
someone (or something) that has not seen the changes under test.

The tool-call trace earns its place: several assertions are about *which*
reference got consulted ("Points at `docs/conventions/subprocess-stdio.md`"),
which shows up in the trace rather than in the prose. Note that a run's own
account of its tool access is not reliable — transcripts from 2026-08-12 claim
reads were blocked while the trace shows the same files being read
successfully. Trust the trace.

Run output lands in `evals/runs/<timestamp>/` and is git-ignored: it is bulky
and full of absolute local paths that the hygiene scan rejects. The durable
record is [`behavior-baseline.md`](behavior-baseline.md).

`probes` records why each case exists, so a future edit does not weaken it by
accident.

Several are deliberately adversarial: `item-callback-double-count` asserts a
false premise the answer must correct, and `threading-refuses-worker-xwf-calls`
issues a direct instruction the skill must decline. Agreeing with the user is
the failure.

## Baseline

[`baseline.md`](baseline.md) records the last measured triggering run: date,
which description version, method, and result. Update it whenever the
description changes — and record the method used, because a number without one
cannot be compared against the next.

[`behavior-baseline.md`](behavior-baseline.md) does the same for behaviour, and
additionally records which assertions missed and why. Update it after any change
that moves the guidance the scenarios probe — the SKILL.md gates, the convention
pages, or the templates.
