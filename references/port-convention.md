# port-convention — Inject a convention into an existing X-Tension

Use this reference when the flow router in `SKILL.md` routes to **port**.

The reference source for every symbol below is the **wrapper** template
(`templates/x-tensions/wrapper/`), which ships all of these conventions wired
unless another source is specified. (Community exemplars in `docs/exemplars.md`
are additional read-and-port references — none are bundled in this repo.)

## General approach

1. Identify which convention is missing (from the user's request, or the audit
   output of `references/audit-modernize.md`).
2. Load the convention page (listed per-convention below) and read the
   do/don't rules.
3. Grep the wrapper template (or your chosen exemplar) for the named symbols;
   extract only what the target X-Tension needs.
4. Adapt symbol names (e.g. `IDC_*` control IDs) to the target's `resource.h`.
5. Build-gate via `scripts/build-xtension.ps1 -Name xways-<name>`.
6. Record the completed port wherever the project tracks rollout (e.g. the
   X-Tension's README roadmap) — see `references/docs-loop.md`.

## Convention: output directory

**Convention page:** `docs/conventions/output-dir.md`

**Symbols (in the wrapper template):**
`GetCaseRootDir`, `DefaultOutputDir`

**Porting steps:**

- Add `GetCaseRootDir()` (calls `XWF_GetCaseProp` with `nPropType = 6`).
- Add `DefaultOutputDir(caseRoot)` returning `caseRoot + L"\\" + NAME`.
- Call `DefaultOutputDir(GetCaseRootDir())` in `WM_INITDIALOG` to seed the
  output path field (only when the field is empty — do not override an
  analyst-entered value).
- Call it again at the start of the run path if no value was saved.
- Remove any existing `output_dir` key from the `LoadCfg` / `SaveCfg` block —
  the convention prohibits persisting this value across cases.

## Convention: helper-exe verification

**Convention page:** `docs/conventions/helper-exe-verification.md`

**Symbols (in the wrapper template):**
`VerifyHelperIdentity`, `PeIdentityContains`, `DetectHelperVersionFromFlag`,
`ShowHelperRejection`, `ClearHelperRejection`,
plus the `WM_CTLCOLORSTATIC` handler (recolour Version label while rejected)
and the `WM_TIMER` flash counter (`helperFlashTicks`, `kHelperFlashTimerId`).

**Pending-rollout targets:** track these in your own project's CLAUDE.md (this
skill repo ships no working X-Tensions). The needle string is the wrapped tool's
own identifier (e.g. `bulk_extractor`, or your tool's name).
See the Needles section of `docs/conventions/helper-exe-verification.md`.

**Porting steps:**

- Copy the four verification functions verbatim; adjust only the needle string.
- Add `helperRejected` and `helperFlashTicks` fields to the dialog state struct
  (or as statics, matching the target's existing pattern).
- Add `kHelperFlashTimerId` timer constant; start the timer in `WM_INITDIALOG`
  alongside any existing timers.
- In `WM_INITDIALOG` and at every resolution site (Browse button handler, cfg
  load, PATH probe): call `VerifyHelperIdentity`; on failure call
  `ShowHelperRejection` and disable IDOK.
- Add the `WM_CTLCOLORSTATIC` recolouring block (adapting the control ID for
  the Version label to the target's `IDC_*` constant).
- Add the `WM_TIMER` flash decrement block; kill the timer in `WM_DESTROY`.
- Headless paths (RVS silent-mode): call `VerifyHelperIdentity`, log rejection
  reason, and bail — no flash UI.

## Convention: Ctrl-to-save gesture

**Convention page:** `docs/conventions/ctrl-to-save.md`

**Symbols (in the wrapper template):**
`g_runCtrlDown`, `kCtrlPollTimerId`,
`WM_TIMER` label-swap block,
`WM_DRAWITEM` IDOK blue-tint block,
IDOK Ctrl branch (save-to-sidecar, skip run-only validation),
IDCANCEL Ctrl branch (GetSaveFileNameW picker, export).

**Pending-rollout targets:** track these in your own project's CLAUDE.md. Any
wrapper with a settings dialog + cfg sidecar is a candidate; a wrapper that
lacks a `SaveCfg` helper needs one added first (a `key = value` writer mirroring
`LoadCfg`) before the Ctrl gesture can save through it.

**Porting steps:**

- Add `static constexpr UINT_PTR kCtrlPollTimerId` and `static bool g_runCtrlDown`.
- Change IDOK button style to `BS_OWNERDRAW` in the `.rc` or at `WM_INITDIALOG`.
- Send `DM_SETDEFID` to keep Enter triggering Run despite `BS_OWNERDRAW`.
- Set the 100 ms timer in `WM_INITDIALOG`; kill it in `WM_DESTROY`; reset
  `g_runCtrlDown = false` in `WM_DESTROY`.
- Add the `WM_TIMER` label-swap block (Ctrl state → swap "Run"/"Save" and
  "Close"/"Save as...").
- Add the `WM_DRAWITEM` handler that fills IDOK blue when `g_runCtrlDown`.
- In the IDOK handler: branch on `g_runCtrlDown && !workerActive`; save to
  sidecar via `SaveCfg`, return without launching the worker.
- In the IDCANCEL handler: branch on `g_runCtrlDown && !workerActive`; open
  `GetSaveFileNameW` picker, save to chosen path.
- Both Ctrl branches are inert while a worker is active.

## Convention: VERBOSE logging

**Convention page:** `docs/conventions/verbose-logging.md`

Add `static constexpr bool VERBOSE = true;` near the top of the `.cpp`. Add
`LogVerbose` as a no-op wrapper around `Log` when `VERBOSE` is false. Replace
any per-item or per-row `Log` calls that would flood the Messages window with
`LogVerbose`. Do not remove the call sites — the flag alone quiets them.

## Convention: subprocess stdio

**Convention page:** `docs/conventions/subprocess-stdio.md`

Copy `RunCommand` from the **wrapper** template
(`templates/x-tensions/wrapper/`). Open `\NUL` with inheritable
`SECURITY_ATTRIBUTES` and pass all three handles via `STARTUPINFOW` +
`STARTF_USESTDHANDLES`. For the capturing variant (`CreateCapturePipe` /
`DrainPipe` / `RunHelper`), the same template provides the pipe helpers.

## After porting

Run the build gate, then record completion in CLAUDE.md and `docs/exemplars.md`
per `references/docs-loop.md`.

## Cross-references

- Audit for all gaps before porting → `references/audit-modernize.md`
- Build gate → `scripts/build-xtension.ps1`
- Recording completion → `references/docs-loop.md`
