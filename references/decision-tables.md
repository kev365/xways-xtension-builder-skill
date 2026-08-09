# decision-tables — Quick-decision matrices

Consult these tables at any point when the flow requires a binary choice.
Scaffolding starts from a template under `templates/x-tensions/`; the
**community** exemplars registered in `docs/exemplars.md` are read-and-port
references (with attribution), not bundled copy-targets. The tables below
capture the decision logic, not a hardcoded inventory.

---

## Table A — Template selection (cpp vs python vs xtmgr)

**Step 1 — language track:**

| Use-case signal | Track |
|---|---|
| Needs Events API (`XWF_AddEvent` / `XWF_GetEvent`) | **C++** — hard gate; `XT_Python.dll` does not expose these. |
| Needs forensic-license-only APIs (most item-mutation APIs) | **C++** |
| Performance-sensitive (RVS over millions of items) | **C++** |
| Rich Python libraries (ML/parsers/RE frameworks), no Events API | **python** |
| Rapid prototyping where C++ iteration cost is high | **python** |

**Step 2 — within the C++ track, pick the template:**

| The C++ X-Tension is… | Template |
|---|---|
| Wraps an external CLI tool | **wrapper** |
| Analyst-facing (dialog/cfg) or a minimal probe / one-shot | **cpp** (bare) |
| The user **explicitly asked** for `xways-xt-manager` tab support | **xtmgr** (manager-compatible) |

Note: `xtmgr` is a **superset of `cpp`** — the same DLL exports `XT_*` (standalone)
**and** `XwaysManagerPluginEntry` (a managed tab in `xways-xt-manager`). But
**manager compatibility is opt-in and deferred**: `xways-xt-manager` is a work in
progress and its contract may still change, so do **not** default to `xtmgr` —
use it only when the user specifically asks. It can also be added to an existing
standalone X-Tension later — see `references/manager-compat.md`. **Python
X-Tensions cannot be manager-compatible** (`XwaysManagerPluginEntry` is a C++
export).

---

## Table B — Which template to scaffold from

| Signal | Recommended starting template |
|---|---|
| Greenfield — no dialog, no cfg, no external tool | Bare **cpp** or **python** template |
| Analyst-facing C++ (dialog/cfg), not a CLI wrapper | Bare **cpp** (add `xtmgr` only if manager support is explicitly requested) |
| Needs a CLI-tool wrapper with dialog + cfg (canonical) | **wrapper** template (`-Template wrapper`) |
| Needs a CLI-tool wrapper, minimal (cfg-only, no dialog) | **wrapper** template, then drop the dialog (manager support stays opt-in — do not reach for `xtmgr` unless requested) |
| Needs full-featured dialog + cfg + helper-exe verification + Ctrl-to-save | **wrapper** template (all four already wired) |
| Pattern needed exists only in a community exemplar | Scaffold from a template, then port the **pattern with attribution** from the exemplar |

Scaffold command:

```powershell
scripts/new-xtension.ps1 -Name xways-<name> -Template wrapper -DryRun
scripts/new-xtension.ps1 -Name xways-<name> -Template wrapper
```

Community exemplars (`docs/exemplars.md`) are read-and-port references, not
bundled copy-targets — port patterns with attribution only. `-Exemplar` applies
only to an exemplar you have locally in your own project.

---

## Table C — Dialog promotion thresholds

| Configuration complexity | Pattern |
|---|---|
| ≤ ~6 cfg keys, analyst-stable (set once, forget) | Sidecar `.cfg` only — no dialog |
| > ~6 cfg keys, OR any interactive per-run choice | Promote to `.rc` + `resource.h` + `DialogBoxParamW` |
| Single ad-hoc value needed at run time | `XWF_GetUserInput` (built-in dialog, no `.rc` needed) |

When a dialog is warranted, the **wrapper** template
(`templates/x-tensions/wrapper/`) ships the canonical CLI-wrapper dialog + cfg
lifecycle — start there and adapt. For more advanced layouts (plugin/rule
grids, rich grouped controls, WSL-detection hints, auto-fit), read patterns
from the relevant **community** exemplars registered in `docs/exemplars.md` and
port them with attribution — none are bundled here.

Dialog convention page: `docs/xtension-dialog-conventions.md`.
Single-field prompt: `docs/xways-user-input-and-dialogs.md` §`XWF_GetUserInput`.

---

## Table D — Subprocess vs XWF_Mount

When an X-Tension needs to feed case items to an external tool, choose between
exporting bytes to a temp dir or using `XWF_Mount`:

| Tool characteristic | Approach |
|---|---|
| Tool accepts a single file or directory path, walks it cleanly | **XWF_Mount** (`XWF_Unmount(NULL)` defensively first; always pair with Unmount) |
| Tool must respect item selection (only analyst-selected items) | **Extract to temp dir** (embed item ID in temp filename: `xwitem_<id>_<leaf>.bin`) |
| Tool scans whole streams or recursive trees without per-file targeting | **Extract to temp dir** |

Only one mount point can exist system-wide at a time. See
`docs/external-tool-integration.md` §`XWF_Mount / XWF_Unmount` for constraints
and open empirical questions.

---

## Table E — Tracking a convention rollout across your wrappers

When porting a convention across several wrappers in **your own project**, track
the pending targets in your project's `CLAUDE.md` (this skill repo ships no
working X-Tensions, so there is no bundled inventory to count). Each convention
has a dedicated section to list its rollout targets:

| Convention | CLAUDE.md section to track it under |
|---|---|
| Helper-exe verification | "Helper-exe identity verification" → Pending rollout |
| Ctrl-to-save gesture | "Ctrl-to-save / Save-as gesture" → Pending rollout |
| SaveCfg helper (prerequisite for Ctrl-to-save where absent) | Same section, noted |

---

## Cross-references

- Scaffold flow (uses Tables A/B) → `references/scaffold-new.md`
- Wrapper flow (uses Tables B/C/D) → `references/wrapper-generator.md`
- Port flow (uses Table E) → `references/port-convention.md`
- Manager-compat flow (uses Table A step 2) → `references/manager-compat.md`
- Audit flow (uses Table E) → `references/audit-modernize.md`
- Community exemplar registry (read-and-port, not bundled) → `docs/exemplars.md`
- Dialog conventions detail → `docs/xtension-dialog-conventions.md`
