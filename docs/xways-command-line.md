---
source: X-Ways 21.6 manual §3.10 + https://www.x-ways.net/forensics/x-tensions/api.html + empirical
type: official-doc + empirical-finding
last_updated: 2026-06-06
author: project notes
---

# X-Ways Forensics — Command-Line Parameters

Synthesised reference for what `xwforensics64.exe` / `xwb64.exe` / `winhex64.exe` accept on the command line. Combines:

- **Manual § 3.10 "Command Line Parameters"** — the X-Ways manual (X-Ways 21.6, Feb 2026), the authoritative source.
- **Polito Inc. blog series + Hash Exporter X-Tension** — the only public end-to-end automation recipe.
- **Empirical strings from a 21.7 SR-3 X-Ways binary** (May 2026) — uncovered one v21.7 token (`XTParam:`) that isn't in the 21.6 manual yet.
- **X-Tensions API page** — <https://www.x-ways.net/forensics/x-tensions/api.html> documents `XTParam:` (added v19.4 SR-6, predates its appearance in the manual). Format: `XTParam:<id>:<value>` where `<id>` identifies the target X-Tension.
- **The X-Ways SDK header** (see [getting-the-sdk.md](getting-the-sdk.md)) — silent on CLI; the SDK is for in-process X-Tensions only, not external invocation.

## TL;DR — there is no `--help`

`xwforensics64.exe` does **not** print a usage screen. The supported parameters all take the shape `Verb:Argument` (case-sensitive verb, colon, no space) or are positional file paths. There's no `/?`, no `--version`, no help screen — the manual section is the canonical list. Ordering matters except for `Cfg:`, which always sorts first.

## Documented parameters (21.6 manual § 3.10)

| Parameter | Effect |
| --- | --- |
| `<path>` (positional) | Open file or .xfc case file. First-position `.xfc` opens the case; later-position `.xfc` *imports* its evidence objects into the active case. |
| `:N` (positional) | Open physical disk N (e.g. `:0` = hard disk 0). Combine with the `\|fmt\|path\|...` second arg below to image automatically. |
| `<file>.whs` | Run the WinHex script instead of opening it. |
| `XT:<path>` | Load the named X-Tension DLL (full path). |
| `XTParam:<id>:<value>` | **v19.4 SR-6+** (per the [X-Tensions API page](https://www.x-ways.net/forensics/x-tensions/api.html), even though the 21.6 manual doesn't list it). X-Ways itself **ignores** any parameter starting with `XTParam:` — no "file not found" error pops. The X-Tension fetches the full command line via `GetCommandLine`, parses it, and pulls out tokens whose `<id>` matches its own short identifier (a per-X-Tension string the X-Tension's docs declare). The `<value>` may contain colons. If `<id>` or `<value>` contains spaces, quote the entire `XTParam:...` token. Multiple `XTParam:` tokens may target different X-Tensions in the same launch. A common convention is to layer a `<key>=<value>` micro-format inside `<value>` (the X-Tension parses it after stripping the `<id>:` prefix). |
| `NewCase:<path>` | Create a new case at the given path. **Overwrites** any existing case at that path *without prompt*. Supports relative paths and `%ENVVARS%`. |
| `NewCase;<path>` | Same as above but **semicolon** = if the .xfc already exists, generate a unique filename instead of overwriting. |
| `AddImage:<path>` | Add an image. Supports wildcards (`*.e01`). Optional sub-flags `#P#` (physical/partitioned), `#V#` (volume), or `#P,4096#` to force a sector size: `AddImage:#P,4096#Z:\Images\*.dd`. |
| `AddDir:<path>` | Add a directory tree to the case (single file path also accepted). `AddDir:*` adds the root of every available drive letter (network drives optional, gated by Volume Snapshot option). |
| `AddDrive:<letter>` | Add a drive letter for **sector-level** access, e.g. `AddDrive:C` (admin required). `AddDrive:*` adds all letters. Without admin rights, `AddDrive:*` silently degrades to `AddDir:*`. |
| `RVS:~` | Refine Volume Snapshot on **all** evidence objects in the case. Uses the most-recently-applied virgin-snapshot RVS settings from `WinHex.cfg`. The active settings dialog is screenshotted into the case activity log. |
| `RVS:~+` | RVS on **only newly added** evidence objects. |
| `LST:<file>` | Load a list of search terms (one per line). Must precede an RVS that triggers a simultaneous search; the listed terms get fed into that search. |
| `Cfg:<name>` | Use an alternative `WinHex.cfg`-shaped config file. Name only (≤31 ASCII chars), not path. **Always processed first**, regardless of position. |
| `Dlg:<path>` | Load a `.dlg` file (saved dialog selections) — overrides specific config bits at the moment the parameter is processed. v20.2+ `.dlg` files only. |
| `Override:0` | Default. Show all message/dialog boxes normally. Outputs the full command line to the Messages window. |
| `Override:1` | Auto-click **OK** on every message/dialog box; redirect text to Messages window. Skips BitLocker password prompts. |
| `Override:2` | Auto-click **Cancel** instead. |
| `Override:4` | Try internal password collection (`Passwords.txt`) for BitLocker prompts. Combine with `1`. |
| `Override:5` | `1 + 4` — auto-OK plus internal password collection. **Requires v21.6+**. |
| `\|e01\|<path>\|<desc>\|<name>` | (Second positional, paired with `:N` first) — automatic imaging recipe. Format = `e01` or `raw`. Two output copies allowed by separating paths with `/`: `\|e01\|Z:\First.e01/V:\Second.e01`. |
| `GetLicID:[path]` | Print the license/dongle hash (`nLicID`) and exit. First 4 bytes returned as exit code; full 16 bytes + 8-byte FILETIME UTC written to the optional output path. Used by third-party tools that license against an X-Ways install. If first 4 bytes are `0x00`, install is unlocked or the file write failed. |
| `auto` (positional, last) | Exit X-Ways automatically when finished. |

## End-to-end recipe (Polito blog)

```cmd
xwb64.exe ^
  "NewCase:D:\Cases\My case" ^
  "AddImage:Z:\Images\*.e01" ^
  "AddImage:Z:\Images\My image.dd" ^
  RVS:~ ^
  auto
```

With an X-Tension:

```cmd
xwb64.exe ^
  "NewCase:D:\XWAYS\test" ^
  "AddImage:d:\XWAYS\testdisk.img" ^
  "XT:D:\XWAYS\XT_HashExporter.dll" ^
  RVS:~ auto
```

For unattended automation also pin a config file and suppress dialogs:

```cmd
xwb64.exe ^
  "Cfg:Automation.cfg" ^
  "Override:1" ^
  "NewCase:D:\Cases\Job-1234" ^
  "AddImage:Z:\Job-1234\evidence.e01" ^
  "XT:D:\X-Tensions\my_pipeline.dll" ^
  RVS:~ auto
```

## Getting the version (no `--version`, but `GetLicID:` + msglog works)

`xwforensics64.exe` has no `--version` switch. Three workable paths from outside the GUI, in increasing authoritativeness:

1. **PE VERSIONINFO** — fast, no side effects. `FileVersion` gives only `21.7` (no SR) on current builds. Use `GetFileVersionInfoW` + `VerQueryValueW`.
2. **Binary string scan** — read the .exe (it's ~25 MB) and search for `<major>.<minor> SR-N` in both ASCII and UTF-16LE. The Help → About text is baked in as a literal. Heuristic but reliable.
3. **`GetLicID:` + msglog.txt** — definitive. **Every X-Ways session writes a startup banner line** to `msglog.txt` in the install directory:

   ```text
   05/06/2026, 07:16:21  X-Ways Forensics BYOD 21.7 SR-3 x64, User: <username>
   ```

   Format: `MM/DD/YYYY, HH:MM:SS  X-Ways Forensics [BYOD] <major>.<minor> SR-N x64, User: <username>` (the `BYOD` token appears only on BYOD builds; analogous prefixes for Investigator / Imager). The banner is part of session startup, so it gets written even when `GetLicID:` is the *only* parameter — meaning `xwforensics64.exe GetLicID:%TEMP%\nlicid.bin` runs for ~1–3 s, exits cleanly, and leaves a fresh banner line you can `tail` and parse.

   Side effects: writes a line to `msglog.txt`, plus the `nlicid.bin` output file. No volume snapshot work, no case open. Works even on unlicensed installs (`GetLicID:` returns `0x00000000` exit code in that case, but the banner still gets written).

   This is the most authoritative because **X-Ways itself is reporting its own version string** — same string that appears in the title bar and About box.

The SDK's `nVersion` parameter to `XT_Init` is in-process only — no external query API exists.

## Things to keep in mind

- **Quote anything containing spaces** (`"NewCase:D:\Cases\My case"`). Embedded `:` inside paths after the verb's `:` is fine.
- **Order matters**. Parameters are processed left-to-right. `Cfg:` is the only auto-promoted parameter — it always processes first regardless of position.
- **`Override:` outputs the entire command line to the Messages window** — useful for forensic-trail logging of automated runs (it goes to `msglog.txt` unless disabled).
- **`Override:5` is v21.6+**. Earlier versions reject it.
- **Imager mode**. The `:N |fmt|path|...` recipe also works in **X-Ways Imager** (not just Forensics).
- **Investigator can't drive case automation** — manual is explicit that command-line case creation/RVS is X-Ways Forensics only, not Investigator.

## Empirical findings (X-Ways 21.7, 2026-05)

These are not in the manual; they were found empirically.

### `Override:N` and `GetLicID:<path>` cannot be combined

Combining the two on the same command line produces a Win32 error popup, **not** an X-Ways error:

```text
Error #1
Cannot open "GetLicID:C:\Users\<user>\AppData\Local\Temp\..."
The filename, directory name, or volume label syntax is incorrect.
```

Mechanism: X-Ways consumes `Override:N` as the action verb and treats `GetLicID:<path>` as a positional file argument. The literal string `GetLicID:C:\...` contains two colons (after `GetLicID` and after the drive letter), which Win32 file APIs reject as `ERROR_INVALID_NAME (123)` *before* X-Ways' control flow runs. The popup is generated by Win32, not by X-Ways. There is no documented escape, ordering trick, or alternate quoting that gets around it. Confirmed via search across the X-Ways forums, the Polito automation blog, and the X-Tensions API page; Polito's published multi-arg recipes deliberately don't combine `Override:` with `GetLicID:`.

**Fix:** drop one of the two. Use `Override:N` or `GetLicID:<path>`, never both.

### `Override:1` redirects dialog text into msglog.txt alongside the session banner

When launched with `Override:1` and no other action verb, X-Ways writes msglog.txt with **two** kinds of `X-Ways Forensics` lines:

```text
05/08/2026, 22:32:09  X-Ways Forensics 21.7 SR-3 x64, User: <username>        <- real session banner
05/08/2026, 22:32:09  Inst. 2 *** X-Ways Forensics ***                    <- redirected dialog title
◎ Start another instance
◯ Analyze previous instance
◯ Recover previous instance if hanging
◯ Immediately terminate previous instance
```

A parser that needs the version+SR triple should iterate **all** `X-Ways Forensics` occurrences and accept the first one that yields a `\d+\.\d+ SR-\d+` triple — `find`/`rfind` of a single match isn't enough since the dialog-title line is a false positive.

`Inst. 2` is X-Ways' marker for the second running instance (when the host X-Ways was already running). It prefixes lines from the second instance.

### `Override:1` is required to programmatically capture the banner from a fresh-launch

Without `Override:N`, when X-Ways is *already running* and the analyst's "Allow multiple program instances" setting is **half-checked** (the default tri-state), launching the executable a second time pops the multi-instance prompt:

```text
[ X-Ways Forensics ]
( ) Start another instance      <- default radio
(*) Analyze previous instance
( ) Recover previous instance if hanging
( ) Immediately terminate previous instance
[ OK ] [ Cancel ]
```

The session-start banner (and msglog write generally) is gated on this prompt. `SW_HIDE` / `CREATE_NO_WINDOW` make the prompt invisible but it still blocks the process. Without dismissal, the banner is never written.

`Override:1` auto-OKs the prompt with the default radio ("Start another instance"), the second instance starts, and the banner lands in msglog within ~1s. The process self-exits with `exitCode=0x0000042B` (`ERROR_PROCESS_ABORTED`, 1067) within ~6s.

**Empirical timing observed on xwforensics64.exe 21.7 SR-3:**

- Banner written: ~1s after process start
- Dongle prompt fires: ~85s after process start (irrelevant if you kill before then)
- `Override:1` self-exit: ~6s after process start

### `auto` flag interacts dangerously with a crashed second instance

Adding `auto` to a second-instance launch (`Override:1 GetLicID: auto` or similar) was observed to take down the host X-Ways process when the second instance crashed (e.g. via the `Continue anyway? Yes → exception 216` path). Avoid `auto` when launching a second instance for side-effects only — `Override:1` alone exits cleanly enough.

### msglog.txt path

X-Ways writes msglog.txt in **the directory containing the executable**, not the current working directory of the launching process and not `%TEMP%`. `GetModuleFileNameW(NULL)` resolves the parent dir; that's where msglog goes. Confirmed by setting different cwds and observing the file always lands next to xwforensics64.exe.

### Banner format (session-start line in msglog.txt)

```text
MM/DD/YYYY, HH:MM:SS  [Inst. N ]X-Ways Forensics [BYOD ]<maj>.<min> SR-<n> x64, User: <username>
```

- `Inst. N` — present only when this is the Nth concurrent instance (N >= 2).
- `BYOD` — present only on the BYOD build; the dongle build omits it.
- A regex like `X-Ways Forensics[^\d]*(\d+)\.(\d+)\s+SR-(\d+)` matches both flavors.

## Open / unverified

- **`XTParam:`** — syntax documented on the X-Tensions API page since v19.4 SR-6, but the 21.7 manual still omits the description (a manual-coverage gap). The plumbing inside X-Ways: parameters with the `XTParam:` prefix are *ignored* by X-Ways' own argv handling (no file-not-found errors) and surface to the X-Tension via `GetCommandLine`/`CommandLineToArgvW`, **not** via `XT_Init`'s `lpReserved`.
- **Exit codes other than `GetLicID:`** — manual doesn't document a general-purpose exit-code contract for automation runs. Untested (likely 0 = clean exit, non-zero = abort/error, but unconfirmed).
- **Imager `|raw` format details** — manual says "raw" works as alternative to "e01" but doesn't enumerate options like compression, segment size, hash flavors. Probably driven by current `WinHex.cfg`/`Dlg:` settings.
- **`Dlg:` precedence vs `Cfg:`** — manual says `Cfg:` is processed first, then "later parameters override specific parts." Concrete merge rules undocumented.
- **Whether a single invocation can drive multiple `RVS:~` passes with different `Dlg:` selections** — untested.

## Source pointers

- The X-Ways manual § 3.10 "Command Line Parameters". Also worth scanning § Appendix B "Script Commands" for the in-process scripting language — distinct from CLI but sometimes confused.
- Polito Inc.'s Hash Exporter X-Tension writeup — minimal CLI X-Tension example.
- Polito Inc.'s X-Ways extensions blog series — overview of all Polito public docs on CLI invocation.
- [external-tool-integration.md](external-tool-integration.md) — broader patterns for chaining X-Ways with other CLI tools (note: about *X-Tensions calling out*, not about driving X-Ways from outside).
