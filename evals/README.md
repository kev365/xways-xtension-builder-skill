# Triggering evals

`trigger-eval.json` is a **should-trigger / should-not-trigger matrix** for the
`xways-xtension-authoring` skill's `description` field — the text that decides
whether Claude consults the skill for a given request. Re-run it whenever the
description changes to catch **under-triggering** (misses a real X-Tension task)
or **over-triggering** (fires on adjacent work that belongs elsewhere).

Each entry is a realistic user prompt with the expected outcome:

- **10 should-trigger** — scaffold / wrap / port / audit / build / publish flows
  and "which `XWF_*` call/flag" questions, including phrasings that never say
  "X-Tension" outright.
- **10 should-not-trigger** — tricky near-misses that share keywords but need
  something else: general X-Ways *usage*, open-ended tool ideation, "wrap"/"build"
  in a non-X-Tension sense, and plugins for *other* forensic tools. (`note` on each
  entry records what it probes.)

## Re-run the baseline

Uses the [skill-creator](https://github.com/anthropics/skills) `run_eval` tool,
which runs each query through `claude -p` a few times and reports the measured
trigger rate against the current `SKILL.md` description.

```bash
# from the skill-creator skill directory
python -m scripts.run_eval \
  --eval-set  <this-repo>/evals/trigger-eval.json \
  --skill-path <this-repo>/.claude/skills/xways-xtension-authoring \
  --runs-per-query 3 --verbose
```

To have it also propose description improvements (train/held-out split, up to 5
iterations), use `run_loop` instead of `run_eval` — but treat the current
description as the baseline and only adopt a change that improves the held-out
score.
