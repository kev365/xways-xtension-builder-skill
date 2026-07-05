# audit-modernize — Audit and modernize an untested X-Tension

Use this reference when the flow router in `SKILL.md` routes to **audit** — run
it against an X-Tension in your own project (this skill repo ships no working
X-Tensions to audit). The two passes below confirm conformance to the
conventions and validity of every `XWF_*` call, surfacing gaps to fix.

`docs/exemplars.md` registers **community** exemplars and their 21+ compat
verdicts as prior-art references; it is not a backlog of bundled tools.

The two passes below are independent — run them one X-Tension at a time, or in
parallel if you have a fan-out helper such as `superpowers:dispatching-parallel-agents`.

---

## Pass 1 — Conformance audit

Check each item; record gaps in a TODO comment or task list; optionally fix
inline.

### 1a. Naming and deployment

- Source folder is `x-tensions/xways-<name>/` (hyphenated source tree).
- DLL filename, source filenames, `.def` `LIBRARY`, and `build.bat` `set NAME=`
  all share the same `xways-<name>` stem.
- Build output lands in `xtensions\xways-<name>\xways-<name>.dll` (no hyphen
  in the deploy path — the project's deploy-bundle spelling; the build scripts
  stage and verify this exact path).

Convention page: `docs/conventions/naming-deployment.md`.

### 1b. VERBOSE logging

- `static constexpr bool VERBOSE = true;` (C++) or `VERBOSE = True` (Python)
  present near the top of the main source file.
- `LogVerbose` / `_log_verbose` helper present and used for per-item
  diagnostics.

Convention page: `docs/conventions/verbose-logging.md`.

### 1c. Output directory

- `output_dir` is **not** persisted in the cfg sidecar.
- Output defaults to `<caseRoot>\<NAME>\` via `GetCaseRootDir` /
  `DefaultOutputDir`.

Convention page: `docs/conventions/output-dir.md`.

### 1d. Helper-exe verification (wrappers only)

- `VerifyHelperIdentity` (or equivalent) called at every resolution site before
  spawning the helper.
- In-dialog rejection surfaces as a bold-red flash UI on the Version label;
  headless paths log and bail.

Convention page: `docs/conventions/helper-exe-verification.md` (see its Needles
section).

### 1e. Ctrl-to-save (dialog + cfg wrappers only)

- `g_runCtrlDown` / `kCtrlPollTimerId` wired in the dialog proc.
- IDOK is `BS_OWNERDRAW`; `DM_SETDEFID` sent so Enter still triggers Run.
- Both Ctrl branches inert while a worker is active.

Convention page: `docs/conventions/ctrl-to-save.md`. A wrapper lacking a
`SaveCfg` helper needs one added first.

### 1f. Subprocess stdio (spawning subprocesses)

- `\NUL` opened with inheritable `SECURITY_ATTRIBUTES`; all three handles
  passed via `STARTUPINFOW` + `STARTF_USESTDHANDLES`.

Convention page: `docs/conventions/subprocess-stdio.md`.

### 1g. Manager compatibility (analyst-facing C++ X-Tensions)

- If the X-Tension exports `XwaysManagerPluginEntry` (grep the `.def` / `.cpp`),
  it is manager-aware: verify its local `manager-plugin.h` matches canonical —
  run `scripts/check-manager-sync.ps1 -Name <name>` and flag any ABI drift.
- If it does **not** export it, that is **not a gap** — manager compatibility
  is strictly opt-in (see `references/manager-compat.md`). Offer to port it
  only if the user has asked for manager support. Python X-Tensions are n/a.

Convention page: `docs/conventions/manager-compatibility.md`. Port flow:
`references/manager-compat.md`.

---

## Pass 2 — API validity audit

Route every `XWF_*` call through `references/api-guardrail.md`.

### 2a. Verify all XWF_* calls against the authoritative sources

Verify in priority order (per `references/api-guardrail.md`): (1) the distilled
`docs/` notes, (2) the live API HTML at
`https://www.x-ways.net/forensics/x-tensions/XWF_functions.html`, and — only if
you downloaded it yourself per `docs/getting-the-sdk.md` — (3) the optional
local SDK header `references/api/xwf-api-code-c46a1bd2/src/X-Tension.h` (commit
`c46a1bd2`, 2024-07-26; not shipped in this repo).

Never emit a call that none of these sources verifies — see the hard gate in
`SKILL.md`.

### 2b. Check XT_Init signature

Current signature (from git HEAD):

```c
LONG __stdcall XT_Init(DWORD nVersion, DWORD nFlags, HANDLE hMainWnd, LicenseInfo* license);
```

The fourth parameter changed from `void*` to `LicenseInfo*` at git HEAD
(commit `c46a1bd2`). Old X-Tensions compiled with `void*` are binary-compatible
(no source change required to keep loading), but update the signature if
touching the file. Source: `docs/xways-api-recency-research.md`.

### 2c. Check for removed / renamed calls

Two calls are deprecated (renames backported to the 21.4–21.7 service
releases):

- `XWF_AddToReportTable` → renamed `XWF_Label`; from v21.8 it also removes a
  label when called with `nFlags` `0x80000000`.
- `XWF_GetReportTableAssocs` → renamed `XWF_GetLabels`.

Source: `docs/xways-reading-events-and-items.md`.

### 2d. Check flag bits and property numbers

Flag bits are a frequent drift point. Verify against:

- `XWF_OpenItem` flags → `docs/xways-openitem-flags.md`
- `XWF_GetCaseProp` / `XWF_GetEvObjProp` / `XWF_GetVSProp` property numbers →
  `docs/xways-getprop-reference.md`
- Invocation mode constants (`XT_ACTION_RVS` = 1, `XT_ACTION_DBC` = 4,
  `XT_ACTION_SHC` = 5 — a frequent off-by-one drift point in older code) →
  `docs/xtension-invocation.md`

---

## Output: gap TODO

After both passes, produce a gap list of the form:

```
xways-<name> audit (2026-MM-DD):
  CONFORMANCE
    [x] VERBOSE present
    [ ] output_dir not persisted — add DefaultOutputDir
    [ ] helper-exe verification missing — needle: <tool>
    [ ] Ctrl-to-save missing
  API
    [x] XT_Init signature: old void* fourth param — binary-compatible, update when touched
    [ ] XWF_GetReportTableAssocs used — replace with XWF_GetLabels
```

Fix items in-place if the scope is small; otherwise create a follow-up task.
Build-gate each fix via `scripts/build-xtension.ps1 -Name <name>`.

Record any findings in `docs/` per `references/docs-loop.md`. If you maintain a
local verdict for the audited X-Tension (in your own project's notes or in a
community `docs/exemplars.md` entry you contribute), update it to reflect what
was fixed ("Verified" if all pass, "Likely" if minor gaps remain).

---

## Cross-references

- API routing table → `references/api-guardrail.md`
- Convention porting instructions → `references/port-convention.md`
- Recording findings and updating verdicts → `references/docs-loop.md`
- Community exemplar registry → `docs/exemplars.md`
