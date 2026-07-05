# Trigger-eval baseline

Baseline triggering accuracy for the `xways-xtension-authoring` skill
`description`, measured against [`trigger-eval.json`](trigger-eval.json).

- **Date:** 2026-07-04
- **Description version:** the v0.3.0 SKILL.md description (starts *"This skill
  should be used when the user asks to 'create/scaffold a new X-Tension'…"*).
- **Method:** independent per-query judgment — each query was given, with only the
  skill's name + description, to a fresh evaluator applying the realistic
  triggering bar (consult the skill for substantive matches, not surface-keyword
  near-misses). See the note below on the automated CLI path.

## Result: 20 / 20 (100%)

| | should-trigger | should-not-trigger |
|---|---|---|
| **correct** | 10 / 10 | 10 / 10 |

No under-triggering and no over-triggering. The tricky near-misses were all
handled correctly:

- Rejected (correct): a plugin for **Autopsy** (a different forensic tool), a
  **Rust/cargo** build, wrapping a **REST API** in Python, a generic **C++
  memory-leak review**, making a **report table via the GUI**, and configuring a
  **hash database** — all share keywords with the skill but need something else.
- Triggered (correct) even without the phrase "X-Tension": a C++ **x-ways plugin**
  that crashes on subprocess **stdio**, and a **DLL adding rows to the Events
  Viewer** asking about numeric event-type codes.

## Note on the automated `run_eval` path (Windows)

skill-creator's `run_eval` / `run_loop` spawn the `claude` CLI via Python
`subprocess` with a bare `["claude", …]` argv. On Windows the global `claude` is
an npm shim (`claude` shell-script + `claude.cmd`/`.ps1`, no `claude.exe`), which
`CreateProcess` cannot launch directly — every query fails with `WinError 2` and
reports a false `0/3` trigger rate. Run the CLI path on macOS/Linux (or with a
`claude.cmd` shim resolvable to `subprocess`); on Windows, use the independent
judgment method above.
