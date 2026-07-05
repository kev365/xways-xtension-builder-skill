# wrapper-generator — CLI-tool wrapper flow

Use this reference when the flow router in `SKILL.md` routes to **wrap**.

## 1. Scaffold from the wrapper template

The CLI-tool wrapper use-case is covered by the **wrapper** template
(`templates/x-tensions/wrapper/`) — a CLI-wrapper that already wires helper-exe
verification, Ctrl-to-save, output-dir, and subprocess stdio. (It also ships a
dormant manager entry point; manager hosting stays opt-in — see
`references/manager-compat.md`.) It is the rich scaffold path for wrapping an
external command-line tool:
the full dialog + cfg-sidecar lifecycle is in place, so you adapt rather than
build from scratch.

Scaffold via `new-xtension.ps1`:

```powershell
scripts/new-xtension.ps1 -Name xways-<name> -Template wrapper -DryRun
scripts/new-xtension.ps1 -Name xways-<name> -Template wrapper
```

Then follow the post-copy checklist in `references/scaffold-new.md` §4.

If the target tool has few settings and sidecar-only config suffices (no
analyst dialog), you can instead start from the bare `xtmgr` template and add
only the wrapper anatomy below — but the `wrapper` template is the default
starting point.

For prior-art patterns beyond what the template wires, `docs/exemplars.md`
registers **community** wrappers to read and port-from with attribution (none
are bundled in this repo).

## 2. The six-element anatomy

Every wrapper must implement the six elements documented in
`docs/conventions/wrapper-anatomy.md`. Summary:

1. **`RunSettings` struct** — sidecar config payload (fields map 1:1 to
   `key = value` cfg lines).
2. **`RunState` global** — per-run transient state: volume/evidence handles,
   resolved exe path, temp dirs, counters.
3. **`LoadCfg` (+ `SaveCfg`)** — tiny `key=value` parser/writer; reads the cfg
   file next to the DLL; initialises `RunSettings` in-place. `SaveCfg` is
   required if the X-Tension has a dialog (Ctrl-to-save writes through it).
4. **`XT_Prepare`** — reset `RunState`, call `LoadCfg`, resolve the helper exe
   via `ResolveToolPath`, create temp/output dirs, return item-callback flags.
5. **`XT_ProcessItem(Ex)`** — MZ/size gate → extract item bytes to temp file →
   spawn subprocess with `\NUL` stdio → parse output → tag via
   `XWF_Label` (the 21.8+ name; `XWF_AddToReportTable` is its deprecated
   pre-21.8 name — see the api-guardrail deprecated-calls table).
6. **`XT_Finalize`** — log per-item stats, clean up temp dirs, reset `RunState`.

See `docs/conventions/wrapper-anatomy.md` for vetted code examples, and the
**wrapper** template (`templates/x-tensions/wrapper/`) for the full anatomy
already assembled.

## 3. Tool resolution

Resolve the helper exe once in `XT_Prepare` via `ResolveToolPath`. The function
searches a prioritised set of directories relative to the DLL's location:

1. `<dll-dir>\..\tools\<subdir>\<exe>` — shared tools tree, exact subdir
2. `<dll-dir>\..\tools\<subdir>\<anysub>\<exe>` — shared + vendor-version subdir
3. `<dll-dir>\tools\<subdir>\<exe>` — self-contained bundle
4. `<dll-dir>\tools\<subdir>\<anysub>\<exe>` — self-contained + vendor-version
5. Deep recursive fallback (depth 4) across the whole tools tree

The `exe` argument is a `FindFirstFileW` glob — use `L"toolname*.exe"` to
match version-suffixed release binaries. See `docs/conventions/tool-resolution.md`
for the full reference and do/don't rules.

A cfg-override path (`toolname_exe = ...`) is resolved by the caller before
`ResolveToolPath` is invoked; if the override exists, skip `ResolveToolPath`.

## 4. Identity verification (mandatory)

After resolving the path, verify it before spawning. Accept on an OR of two
gates: PE VERSIONINFO substring match, or `--version` banner substring match.
Reject hard (empty the path, log the reason verbatim) on failure.

Full convention including the in-dialog flash UI (bold-red Version slot, 250 ms
toggle for ~2 s, Run disabled): `docs/conventions/helper-exe-verification.md`.

Symbols already wired in the **wrapper** template (`templates/x-tensions/wrapper/`):
`VerifyHelperIdentity`, `PeIdentityContains`, `DetectHelperVersionFromFlag`,
`ShowHelperRejection`, `ClearHelperRejection`, `WM_CTLCOLORSTATIC` handler,
`WM_TIMER` flash counter.

The needle string is the tool's own identifier (e.g. `L"yourtool"`,
`L"bulk_extractor"`).

## 5. Subprocess stdio (mandatory)

X-Ways is a GUI process with no console. Open `\NUL` with inheritable
`SECURITY_ATTRIBUTES` and pass all three handles (`hStdInput`, `hStdOutput`,
`hStdError`) via `STARTUPINFOW` with `STARTF_USESTDHANDLES`. Omitting this
hard-crashes any child that touches stdio. See `docs/conventions/subprocess-stdio.md`.

Source of truth: the **wrapper** template (`templates/x-tensions/wrapper/`) →
`RunCommand`. For the capturing variant (read stdout), the same template
provides the pipe helpers (`CreateCapturePipe` / `DrainPipe` / `RunHelper`).

## 6. UI convention for settings dialogs

When a dialog is warranted (cfg > ~6 keys or interactive pickers needed; see
`docs/xtension-dialog-conventions.md` for the promotion threshold):

- Model common parameters as labelled checkboxes and controls.
- Provide a single **"Additional arguments"** passthrough text field (e.g. a
  `<tool>_extra_args` cfg key) for any flag not worth a dedicated control. Do
  NOT model every CLI flag individually.
- The **wrapper** template already provides the shared helpers
  (`GetSelfDirectory`, `ResolveToolPath`, `RunCommand`, etc.) — reuse them
  rather than re-deriving.
- The Ctrl-to-save gesture is already wired in the **wrapper** template
  (symbols: `g_runCtrlDown`, `kCtrlPollTimerId`, `WM_DRAWITEM` IDOK,
  IDOK/IDCANCEL Ctrl branches). Convention page:
  `docs/conventions/ctrl-to-save.md`.

For items-to-disk extraction, ID embedding, and tool output mapping back to
item IDs, see `docs/external-tool-integration.md`. That doc also covers the
`XWF_Mount` / `XWF_Unmount` alternative when the tool accepts a single path.

## 7. Output directory

Default `output_dir` to `<caseRoot>\xways-<name>\` via `DefaultOutputDir`.
Never persist `output_dir` in the cfg sidecar. Convention page:
`docs/conventions/output-dir.md`.

## 8. Build gate

```powershell
scripts/build-xtension.ps1 -Name xways-<name>
```

## Cross-references

- Scaffold mechanics → `references/scaffold-new.md`
- Porting individual conventions → `references/port-convention.md`
- API correctness → `references/api-guardrail.md`
- Wrapper anatomy detail → `docs/conventions/wrapper-anatomy.md`
- Tool resolution detail → `docs/conventions/tool-resolution.md`
- Helper-exe verification detail → `docs/conventions/helper-exe-verification.md`
- Subprocess stdio detail → `docs/conventions/subprocess-stdio.md`
- Ctrl-to-save detail → `docs/conventions/ctrl-to-save.md`
- External tool integration (extraction, mount, ID mapping) →
  `docs/external-tool-integration.md`
- Dialog promotion thresholds → `docs/xtension-dialog-conventions.md`
