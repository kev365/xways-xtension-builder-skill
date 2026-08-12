# Trigger-eval baseline

Triggering accuracy for the `xways-xtension-authoring` `description`, measured
against [`trigger-eval.json`](trigger-eval.json).

## Current — 2026-08-09, v0.5.0

- **Description version:** unchanged since v0.4.0. v0.5.0 altered `metadata`,
  the body and the layout, but not the `description` text, so this run
  re-validates the v0.4.0 wording as well — it had never been measured.
- **Method:** automated, [`run-trigger-eval.ps1`](run-trigger-eval.ps1),
  3 runs per query, trigger threshold 0.5, against the skill installed as a
  junction at `~/.claude/skills/xways-xtension-authoring`.
- **Measured twice**, before and after the `cpp-xtmgr-compatible` removal — the
  content change was large enough that re-measuring was cheaper than assuming.
  Both runs are identical in every particular, which is the useful result: the
  removal did not disturb triggering. The stored artifact is the second (final)
  run.

### Result: 20 / 20 (100%), unanimous

| | should-trigger | should-not-trigger |
|---|---|---|
| **correct** | 10 / 10 | 10 / 10 |

60 of 60 runs valid; **zero** harness failures and **zero** `NO DATA` rows.
Every should-trigger query fired 3/3 (rate 1.0) and every should-not-trigger
query fired 0/3 (rate 0.0) — no case landed between the two, so nothing sits
near the threshold.

No under-triggering and no over-triggering. The near-misses were all rejected
correctly: an **Autopsy** plugin, a **Rust/cargo** build, wrapping a **REST API**
in Python, a generic **C++ memory-leak review**, building a **report table via
the GUI**, configuring a **hash database**, *running* a supplied X-Tension DLL,
open-ended "**what should I build**" ideation, a standalone **EVTX python
script**, and **carving JPEGs** from an image.

Both phrasings that never say "X-Tension" still triggered: the C++ **x-ways
plugin** crashing on subprocess **stdio**, and the **DLL adding rows to the
Events Viewer** asking about numeric event-type codes.

### Caveat on what this measures

The measurement is of the **installed** skill, competing against every other
skill present in that environment. That is realistic rather than isolated — the
Autopsy query, for instance, is correctly won by `superpowers:brainstorming`.
A machine with a different skill set could produce different numbers, so record
the environment alongside any future run.

## Historical — 2026-07-04, v0.3.0

- **Method:** independent per-query judgment — each query given, with only the
  skill's name and description, to a fresh evaluator applying a realistic
  triggering bar.
- **Result:** 20 / 20 (100%), 10/10 both ways.

Judgment-based rather than measured, because the automated path did not run on
Windows at the time (see below). The two results agree, which is reassuring, but
they are not the same kind of evidence.

## Windows and the upstream runner

The v0.3.0 note recorded that skill-creator's `run_eval` / `run_loop` cannot
spawn the CLI on Windows: they call Python `subprocess` with a bare
`["claude", …]` argv, and the global `claude` is an npm shim
(`claude.ps1` / `claude.cmd`, no `claude.exe`), which `CreateProcess` will not
launch. That prediction held exactly — re-tested on 2026-08-09, every query
failed with `WinError 2` and the tool reported a meaningless 10/20 that reads
like a severe regression.

There is a second, independent blocker in the same script: it polls the child
pipe with `select.select()`, which on Windows accepts sockets only. Both are
POSIX assumptions rather than bugs.

[`run-trigger-eval.ps1`](run-trigger-eval.ps1) replaces that path on Windows and
mirrors the methodology, so numbers stay comparable. See the eval
[README](README.md) for how it detects triggering and why it reports `NO DATA`
rather than a zero when a run cannot be measured.
