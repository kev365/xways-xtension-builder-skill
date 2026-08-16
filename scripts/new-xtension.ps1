<#
.SYNOPSIS
    Scaffold a new X-Ways X-Tension from a template or a local exemplar.

.DESCRIPTION
    Copies a template (cpp / python / wrapper) or a locally available
    exemplar directory into <DestRoot>/x-tensions/xways-<name>/, renames source
    files to the xways-<name> stem, and patches identity constants (NAME,
    VERSION, DESCRIPTION, REPORT_TABLE). Templates are always read from the
    installed skill; only the OUTPUT is written under -DestRoot.
    Use -DryRun to preview every planned operation without touching the filesystem.

.PARAMETER Name
    The short identifier for the X-Tension — the '<name>' in 'xways-<name>'.
    A leading 'xways-' prefix will be stripped with a warning.

.PARAMETER DestRoot
    Project root the new X-Tension is scaffolded into — output lands in
    <DestRoot>/x-tensions/xways-<name>/. Default: the current directory. Pass
    this when the skill is installed as a Claude Code plugin so output goes into
    your own project instead of the plugin cache; the script refuses to write
    into an installed plugin/marketplace cache. In a clone, run from the repo
    root (the default) to keep output in the working copy.

.PARAMETER Template
    Which template to copy: cpp | python | wrapper.  Default: cpp.
    (wrapper = the CLI-tool-wrapper template with helper-exe
    verification, Ctrl-to-save, output-dir, and subprocess stdio already wired.)
    Ignored when -Exemplar is set.

.PARAMETER Exemplar
    Copy from a local exemplar instead of a bare template. The value is the
    folder name of an X-Tension present in this working copy's x-tensions\
    directory (e.g. one you built earlier) — none are bundled in this repo;
    see docs/exemplars.md for the community registry.

.PARAMETER Version
    Initial version string written into the identity constants.
    Default: 0.1.0-beta (the '-beta' suffix is dropped at first public release;
    see docs/conventions/versioning.md).

.PARAMETER Author
    Copyright holder stamped into the generated LICENSE / CLAUDE.md.example.
    Default: your `git config user.name`, or "Your Name" if git is not
    configured — pass -Author explicitly to override.

.PARAMETER Year
    Copyright year stamped into the generated LICENSE.  Default: current year.

.PARAMETER Description
    One-line description written into the identity constants.
    Default: "<name> X-Tension".

.PARAMETER ReportTable
    Report-table label written into the identity constants.
    Default: "<Name> Findings" (title-cased name).

.PARAMETER DryRun
    Print every planned operation and exit WITHOUT touching the filesystem.

.PARAMETER Force
    Allow overwriting an existing x-tensions/xways-<name> directory.

.EXAMPLE
    .\new-xtension.ps1 -Name myscanner -DryRun
    .\new-xtension.ps1 -Name myscanner -Template cpp -Version 0.2.0
    .\new-xtension.ps1 -Name myscanner -Exemplar xways-yourtool -DryRun
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$Name,

    [string]$DestRoot,

    [ValidateSet('cpp', 'python', 'wrapper')]
    [string]$Template = 'cpp',

    [string]$Exemplar,

    [string]$Version = '0.1.0-beta',

    [string]$Description,

    [string]$ReportTable,

    [string]$Author,

    [string]$Year,

    [switch]$DryRun,

    [switch]$Force
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
function Write-Step([string]$label, [string]$detail) {
    Write-Host "  $label" -ForegroundColor Cyan -NoNewline
    if ($detail) { Write-Host " $detail" -ForegroundColor White }
    else         { Write-Host '' }
}

function Write-DryOp([string]$tag, [string]$msg) {
    Write-Host "  [DRY] " -ForegroundColor Yellow -NoNewline
    Write-Host "$tag" -ForegroundColor Magenta -NoNewline
    Write-Host " $msg"
}

function Fail([string]$msg) {
    # Write-Host, not Write-Error: under EAP=Stop, Write-Error throws and the
    # exit below never runs - the user gets a stack trace instead of this line.
    Write-Host "ERROR: $msg" -ForegroundColor Red
    exit 1
}

# Render a {{TOKEN}} template file to text using a hashtable of replacements.
function Expand-Template {
    param([string]$TemplatePath, [hashtable]$Tokens)
    $text = [System.IO.File]::ReadAllText($TemplatePath, [System.Text.Encoding]::UTF8)
    foreach ($k in $Tokens.Keys) {
        $text = $text.Replace('{{' + $k + '}}', [string]$Tokens[$k])
    }
    return $text
}

# Build a list of replacement specs for a given file.
# Returns [System.Collections.Generic.List[hashtable]] (always a list, never null).
function Get-Replacements {
    param(
        [string]$Kind,        # 'cpp' | 'python' | 'wrapper'
        [string]$SrcStem,     # source stem being replaced (e.g. 'my_xtension')
        [string]$DestStem,    # target stem (e.g. 'xways-skilltest')
        [string]$Ver,
        [string]$Desc,
        [string]$RepTable,
        [string]$FileName     # leaf filename (with extension, e.g. 'xways-skilltest.cpp')
    )

    $reps = [System.Collections.Generic.List[hashtable]]::new()
    # Split on the FIRST dot, matching Get-DestRelPath. Multi-dot sidecars
    # ('xways-foo.cfg.example', 'xways-foo.config.json') otherwise yield a base
    # of 'xways-foo.cfg' / 'xways-foo.config', which never equals the stem, so
    # no rule can ever be written for them.
    $dotIdx = $FileName.IndexOf('.')
    $base   = if ($dotIdx -gt 0) { $FileName.Substring(0, $dotIdx) } else { $FileName }
    $ext    = if ($dotIdx -gt 0) { $FileName.Substring($dotIdx).ToLower() } else { '' }

    # --- .def: always patch LIBRARY directive regardless of kind
    if ($ext -eq '.def') {
        $reps.Add(@{
            Pattern     = '(?m)^LIBRARY\s+\S+'
            Replacement = "LIBRARY $DestStem"
            Description = "LIBRARY -> $DestStem"
        })
        return ,$reps
    }

    # --- build.bat: always patch NAME variable
    if ($FileName -ieq 'build.bat') {
        $reps.Add(@{
            Pattern     = '(?m)^set NAME=\S+'
            Replacement = "set NAME=$DestStem"
            Description = "set NAME -> $DestStem"
        })
        return ,$reps
    }

    # --- .cpp source file (only for the renamed stem file)
    if ($ext -eq '.cpp' -and $base -eq $DestStem) {
        if ($Kind -eq 'python') {
            # Should not happen — python has no .cpp — but guard anyway
        } elseif ($Kind -eq 'wrapper') {
            # Same identity constants as cpp template
            $reps.Add(@{
                Pattern     = '(?m)^static const wchar_t\* NAME\s*=\s*L"[^"]*";'
                Replacement = "static const wchar_t* NAME         = L`"$DestStem`";"
                Description = "NAME -> L`"$DestStem`""
            })
            $reps.Add(@{
                Pattern     = '(?m)^static const wchar_t\* VERSION\s*=\s*L"[^"]*";'
                Replacement = "static const wchar_t* VERSION      = L`"$Ver`";"
                Description = "VERSION -> L`"$Ver`""
            })
            $reps.Add(@{
                Pattern     = '(?m)^static const wchar_t\* DESCRIPTION\s*=\s*L"[^"]*";'
                Replacement = "static const wchar_t* DESCRIPTION  = L`"$Desc`";"
                Description = "DESCRIPTION -> L`"$Desc`""
            })
            # (A display_name descriptor rule lived here until 2026-08-16; the
            # L"My X-Tension" literal it targeted exists in no template, so it
            # printed a NO MATCH on every wrapper scaffold. Removed.)

            # The wrapper's descriptor references the already-patched NAME and
            # DESCRIPTION constants rather than string literals, so no separate
            # id/description rules are needed here — registering literal rules
            # for it produced replacements that could never match, which is what
            # made -DryRun over-promise.
            $reps.Add(@{
                Pattern     = '(?m)^static const wchar_t\* REPORT_TABLE\s*=\s*L"[^"]*";'
                Replacement = "static const wchar_t* REPORT_TABLE = L`"$RepTable`";"
                Description = "REPORT_TABLE -> L`"$RepTable`""
            })
        } else {
            # cpp (plain template or exemplar)
            $reps.Add(@{
                Pattern     = '(?m)^static const wchar_t\* NAME\s*=\s*L"[^"]*";'
                Replacement = "static const wchar_t* NAME         = L`"$DestStem`";"
                Description = "NAME -> L`"$DestStem`""
            })
            $reps.Add(@{
                Pattern     = '(?m)^static const wchar_t\* VERSION\s*=\s*L"[^"]*";'
                Replacement = "static const wchar_t* VERSION      = L`"$Ver`";"
                Description = "VERSION -> L`"$Ver`""
            })
            $reps.Add(@{
                Pattern     = '(?m)^static const wchar_t\* DESCRIPTION\s*=\s*L"[^"]*";'
                Replacement = "static const wchar_t* DESCRIPTION  = L`"$Desc`";"
                Description = "DESCRIPTION -> L`"$Desc`""
            })
            $reps.Add(@{
                Pattern     = '(?m)^static const wchar_t\* REPORT_TABLE\s*=\s*L"[^"]*";'
                Replacement = "static const wchar_t* REPORT_TABLE = L`"$RepTable`";"
                Description = "REPORT_TABLE -> L`"$RepTable`""
            })
        }
        return ,$reps
    }

    # --- Python: xtension.py (renamed to xways-<name>.py, but python uses different stem)
    # Python source file stem = 'xtension' (template) or same as renamed
    if ($ext -eq '.py' -and $Kind -eq 'python') {
        # Only patch the main entry-point file, never helpers.py. The template
        # ships it as xtension.py and the rename makes it xways_<name>.py
        # (underscores - the bridge imports by file stem, so hyphens are
        # illegal), so by the time replacements run the stem equals $DestStem.
        if ($base -eq $DestStem) {
            $reps.Add(@{
                Pattern     = '(?m)^NAME\s*=\s*"[^"]*"'
                Replacement = "NAME = `"$DestStem`""
                Description = "NAME -> `"$DestStem`""
            })
            $reps.Add(@{
                Pattern     = '(?m)^VERSION\s*=\s*"[^"]*"'
                Replacement = "VERSION = `"$Ver`""
                Description = "VERSION -> `"$Ver`""
            })
            $reps.Add(@{
                Pattern     = '(?m)^DESCRIPTION\s*=\s*"[^"]*"'
                Replacement = "DESCRIPTION = `"$Desc`""
                Description = "DESCRIPTION -> `"$Desc`""
            })
            $reps.Add(@{
                Pattern     = '(?m)^REPORT_TABLE\s*=\s*"[^"]*"'
                Replacement = "REPORT_TABLE = `"$RepTable`""
                Description = "REPORT_TABLE -> `"$RepTable`""
            })
        }
        return ,$reps
    }

    # --- .rc: patch analyst-visible dialog text
    if ($ext -eq '.rc' -and $Kind -eq 'wrapper' -and $base -eq $DestStem) {
        $displayName2 = (($DestStem -replace '^xways-', '') -replace '[-_]', ' ')
        $displayNameTitle2 = ($displayName2 -split ' ' | ForEach-Object {
            if ($_.Length -gt 0) { $_.Substring(0,1).ToUpper() + $_.Substring(1) } else { $_ }
        }) -join ' '

        # Match the CAPTION's SHAPE, not a literal. An earlier rule looked for
        # an exact caption string that this template does not contain, so it
        # never matched and every scaffolded wrapper shipped a dialog titled
        # "my_xtension - Settings".
        $reps.Add(@{
            Pattern     = '(?m)^CAPTION\s+"[^"]*\s+-\s+Settings"'
            Replacement = "CAPTION `"$displayNameTitle2 - Settings`""
            Description = "CAPTION -> `"$displayNameTitle2 - Settings`""
        })

        # The About dialog's caption.
        $reps.Add(@{
            Pattern     = '(?m)^CAPTION\s+"About\s+[^"]*"'
            Replacement = "CAPTION `"About $displayNameTitle2`""
            Description = "CAPTION -> `"About $displayNameTitle2`""
        })
        # The About box's title LTEXT, keyed off its control id so the rule
        # does not depend on the placeholder text.
        $reps.Add(@{
            Pattern     = '(?m)(LTEXT\s+)"[^"]*"(,\s*IDC_ABOUT_TITLE)'
            Replacement = "`${1}`"$displayNameTitle2`"`$2"
            Description = "About title -> `"$displayNameTitle2`""
        })
        return ,$reps
    }

    # --- .cfg.example: the wrapper's documented cfg sample.
    # Its prose names two things the analyst acts on: the cfg file the DLL
    # actually reads (GetSelfDirectory() + NAME + L".cfg") and the <NAME>
    # output subfolder under the case root. Left at the template stem, the
    # sample points at a filename that is never read and a directory that is
    # never created. 'yourtool' is deliberately untouched — that is the
    # helper-exe placeholder paired with kHelperIdentityNeedle, an author TODO.
    if ($ext -eq '.cfg.example' -and $base -eq $DestStem) {
        $reps.Add(@{
            Pattern     = [System.Text.RegularExpressions.Regex]::Escape($SrcStem)
            Replacement = $DestStem.Replace('$', '$$')
            Description = "cfg sample text: $SrcStem -> $DestStem"
        })
        return ,$reps
    }

    # --- .config.json: the python sidecar.
    # Its _comment told the analyst to rename the file by hand to match NAME.
    # The scaffold does that now, so the instruction is not just stale but
    # actively misleading.
    if ($ext -eq '.config.json' -and $Kind -eq 'python' -and $base -eq $DestStem) {
        $note = "Optional sidecar config for $DestStem, read automatically from the X-Tension directory. Delete if not needed - the X-Tension falls back to DEFAULT_CONFIG."
        $reps.Add(@{
            Pattern     = '"_comment"\s*:\s*"[^"]*"'
            Replacement = '"_comment": "' + $note.Replace('$', '$$') + '"'
            Description = "_comment -> sidecar note for $DestStem"
        })
        return ,$reps
    }

    # Exemplar .rc files: patch CAPTION if it contains the exemplar name
    # (this is best-effort — exemplar .rc files have tool-specific captions we don't know)
    # We deliberately skip arbitrary exemplar .rc patches to avoid breaking them.

    return ,$reps
}

# ---------------------------------------------------------------------------
# 0. Normalise -Name (strip leading 'xways-' with warning)
# ---------------------------------------------------------------------------
if ($Name -match '^xways-(.+)$') {
    Write-Warning "Name '$Name' starts with 'xways-' — stripping prefix. Using '$($Matches[1])'."
    $Name = $Matches[1]
}
if ($Name -notmatch '^[A-Za-z0-9][A-Za-z0-9_-]*$') {
    Fail "Name '$Name' contains invalid characters. Use letters, digits, hyphens, underscores only (must start with letter/digit)."
}
$fullName = "xways-$Name"

# ---------------------------------------------------------------------------
# 1. Resolve the SKILL install root (source of templates/ + assets/).
#    scripts/ -> skill root (= the repo root; SKILL.md lives there)
# ---------------------------------------------------------------------------
$skillRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path

if (-not (Test-Path (Join-Path $skillRoot 'templates\x-tensions'))) {
    Fail "Could not locate templates\x-tensions under resolved skill root '$skillRoot'. Check script placement."
}

# ---------------------------------------------------------------------------
# 1b. Resolve the DESTINATION root (where x-tensions/<name>/ is written).
#     Defaults to the current directory so a plugin install scaffolds into the
#     user's project, not the plugin cache. In a clone, run from the repo root.
# ---------------------------------------------------------------------------
if ($DestRoot) {
    if (-not (Test-Path $DestRoot)) { Fail "-DestRoot '$DestRoot' does not exist. Pass an existing project directory." }
    $destRootResolved = (Resolve-Path $DestRoot).Path
} else {
    $destRootResolved = (Get-Location).Path
}

# Refuse to scaffold into the installed skill/plugin — especially a marketplace
# plugin cache, which Claude Code manages and overwrites on update. This fires
# only when THIS script is running from a plugin-cache location AND the chosen
# destination is inside it; a dev clone (skill root is a normal repo) is allowed.
$skillRootIsPlugin = ($skillRoot -match '[\\/]\.claude[\\/]plugins[\\/]') `
                  -or ($skillRoot -match '[\\/]plugins[\\/](cache|marketplaces)[\\/]')
if (-not $skillRootIsPlugin -and $env:CLAUDE_PLUGIN_ROOT) {
    try {
        $pr = (Resolve-Path $env:CLAUDE_PLUGIN_ROOT -ErrorAction Stop).Path.TrimEnd('\')
        if ($skillRoot.TrimEnd('\').StartsWith($pr, [System.StringComparison]::OrdinalIgnoreCase)) { $skillRootIsPlugin = $true }
    } catch { }
}
$destUnderSkill = $destRootResolved.TrimEnd('\').StartsWith($skillRoot.TrimEnd('\'), [System.StringComparison]::OrdinalIgnoreCase)
if ($skillRootIsPlugin -and $destUnderSkill) {
    Fail @"
Refusing to scaffold into the installed plugin at:
  $skillRoot
That directory is managed by Claude Code and is overwritten on plugin update.
Run this from your project directory, or pass -DestRoot '<your project path>'.
End-to-end authoring writes into your own project (see SKILL.md).
"@
}

# ---------------------------------------------------------------------------
# 2. Resolve source directory + source stem
# ---------------------------------------------------------------------------
if ($Exemplar) {
    # An exemplar is any X-Tension folder you have locally under
    # <DestRoot>/x-tensions/ (none are bundled in this repo — see docs/exemplars.md).
    $srcDir = Join-Path $destRootResolved "x-tensions\$Exemplar"
    if (-not (Test-Path $srcDir)) {
        Fail "Exemplar '$Exemplar' not found at $srcDir. Exemplars are X-Tensions you already have under <DestRoot>/x-tensions/; none are bundled — scaffold from a template instead, or clone an exemplar first (docs/exemplars.md)."
    }
    $srcStem  = $Exemplar           # e.g. 'xways-yourtool'
    $srcKind  = "exemplar:$Exemplar"
} else {
    $templateDirMap = @{
        'cpp'     = 'cpp'
        'python'  = 'python'
        'wrapper' = 'wrapper'
    }
    $srcDir = Join-Path $skillRoot "templates\x-tensions\$($templateDirMap[$Template])"
    # Python template uses 'xtension' as the main file stem; cpp templates use 'my_xtension'
    $srcStem = if ($Template -eq 'python') { 'xtension' } else { 'my_xtension' }
    $srcKind  = "template:$Template"
}

if (-not (Test-Path $srcDir)) {
    Fail "Source directory not found: $srcDir"
}

# ---------------------------------------------------------------------------
# 3. HARD GATE — write only under <DestRoot>/x-tensions/, never into the skill's
#    read-only templates/ or an SDK references/ tree.
# ---------------------------------------------------------------------------
$destDir = Join-Path $destRootResolved "x-tensions\$fullName"

foreach ($protected in @('templates','references')) {
    $protectedAbs = (Join-Path $skillRoot $protected).TrimEnd('\')
    if ($destDir.TrimEnd('\').StartsWith($protectedAbs, [System.StringComparison]::OrdinalIgnoreCase)) {
        Fail "Destination '$destDir' falls inside the skill's protected '$protected' directory. Aborting."
    }
}
$xtensionsDir = (Join-Path $destRootResolved 'x-tensions').TrimEnd('\')
if (-not $destDir.TrimEnd('\').StartsWith($xtensionsDir, [System.StringComparison]::OrdinalIgnoreCase)) {
    Fail "Destination '$destDir' is not inside <DestRoot>/x-tensions/. Aborting."
}

# ---------------------------------------------------------------------------
# 4. Guard against existing destination
# ---------------------------------------------------------------------------
if (Test-Path $destDir) {
    if (-not $Force) {
        Fail "Destination already exists: $destDir`nUse -Force to overwrite."
    }
    if ($DryRun) {
        Write-Warning "[DRY] Destination exists — would overwrite because -Force was specified."
    }
}

# ---------------------------------------------------------------------------
# 5. Resolve defaults for -Description and -ReportTable
# ---------------------------------------------------------------------------
if (-not $Description) {
    $Description = "$Name X-Tension"
}
if (-not $ReportTable) {
    $titleName = ($Name -split '[-_]' | ForEach-Object {
        if ($_.Length -gt 0) { $_.Substring(0,1).ToUpper() + $_.Substring(1) } else { $_ }
    }) -join '-'
    $ReportTable = "$titleName Findings"
}
if (-not $Author) {
    # try/catch: under $ErrorActionPreference='Stop' a missing git binary is a
    # terminating CommandNotFoundException - the documented 'Your Name'
    # fallback must survive that, not abort the scaffold.
    try { $Author = (& git config user.name 2>$null) } catch { $Author = $null }
    if (-not $Author) { $Author = 'Your Name' }
}
if (-not $Year)   { $Year   = (Get-Date).Year.ToString() }

# ---------------------------------------------------------------------------
# 6. Effective template kind (for replacement dispatch)
# ---------------------------------------------------------------------------
$effectiveKind = if ($Exemplar) { 'cpp' } else { $Template }

# Python module names cannot contain hyphens: the XT_Python bridge loads the
# script via `import <filestem>` and then executes `<filestem>.XT_Init(...)`,
# so a file named xways-foo.py can NEVER load (`import xways-foo` is a syntax
# error — verified live 2026-08-16, "Failed to execute import ..." for every
# entry point). The FOLDER keeps the naming convention's hyphens; only the
# python file stem (and therefore NAME / the sidecar name) uses underscores.
$fileStem = if ($effectiveKind -eq 'python') { $fullName -replace '-', '_' } else { $fullName }

# ---------------------------------------------------------------------------
# 7. Enumerate source files and build copy/rename plan
# ---------------------------------------------------------------------------
function Get-DestRelPath([string]$srcFilePath, [string]$srcRootPath, [string]$stem, [string]$newStem, [string]$newLeafStem = '') {
    if (-not $newLeafStem) { $newLeafStem = $newStem }
    $rel  = $srcFilePath.Substring($srcRootPath.Length).TrimStart('\','/')
    $dir  = Split-Path $rel -Parent
    $leaf = Split-Path $rel -Leaf
    # Split on the FIRST dot, not the last. [Path]::GetFileNameWithoutExtension
    # strips only the final extension, so a multi-dot sidecar like
    # 'my_xtension.cfg.example' yields base 'my_xtension.cfg', which never
    # matches the stem and silently escapes the rename. Those sidecar names are
    # load-bearing — the wrapper .cpp reads NAME + L".cfg" and the python
    # entry point reads f"{NAME}.config.json" — so a missed rename ships a
    # sidecar the scaffolded code will never find.
    $dot  = $leaf.IndexOf('.')
    $base = if ($dot -gt 0) { $leaf.Substring(0, $dot) } else { $leaf }
    $ext  = if ($dot -gt 0) { $leaf.Substring($dot) }    else { '' }
    $newLeaf = if ($base -eq $stem) { "$newLeafStem$ext" } else { $leaf }
    # Also rename directory path components that exactly match the source stem
    # (e.g. xtensions\xways-bulk_extractor\ -> xtensions\xways-skilltest\)
    $newDir = if ($dir) {
        ($dir -split '\\' | ForEach-Object {
            if ($_ -eq $stem) { $newStem } else { $_ }
        }) -join '\'
    } else { '' }
    if ($newDir) { return "$newDir\$newLeaf" } else { return $newLeaf }
}

$srcFiles = Get-ChildItem -Path $srcDir -File -Recurse

$plan = [System.Collections.Generic.List[hashtable]]::new()
foreach ($f in $srcFiles) {
    $destRel  = Get-DestRelPath $f.FullName $srcDir $srcStem $fullName $fileStem
    $destPath = Join-Path $destDir $destRel
    $plan.Add(@{ SrcPath = $f.FullName; DestRel = $destRel; DestPath = $destPath })
}

# ---------------------------------------------------------------------------
# 7b. Standard project files to generate (LICENSE / README / CLAUDE.md.example)
#     Rendered from the skill-local assets/ dir — keeps templates/ read-only.
#       Overwrite=$true  -> write even if the source brought a copy (bare
#                           templates ship a generic README we want to replace)
#       Overwrite=$false -> write only if missing (keep an exemplar's own file)
# ---------------------------------------------------------------------------
$assetsDir = (Resolve-Path (Join-Path $PSScriptRoot '..\assets')).Path
$genTokens = @{
    NAME        = $fullName
    DESCRIPTION = $Description
    VERSION     = $Version
    YEAR        = $Year
    AUTHOR      = $Author
}
$scaffoldFiles = @(
    @{ Template = 'LICENSE.tmpl';           Dest = 'LICENSE';          Overwrite = $false }
    @{ Template = 'CLAUDE.md.example.tmpl'; Dest = 'CLAUDE.md.example'; Overwrite = $false }
    @{ Template = 'README.md.tmpl';         Dest = 'README.md';        Overwrite = (-not $Exemplar) }
)
$plannedLeaves = @($plan | ForEach-Object { Split-Path $_.DestRel -Leaf })

# ---------------------------------------------------------------------------
# 8. Print header
# ---------------------------------------------------------------------------
Write-Host ''
Write-Host "new-xtension.ps1 — $(if ($DryRun) { 'DRY RUN (no changes)' } else { 'EXECUTE' })" `
    -ForegroundColor $(if ($DryRun) { 'Yellow' } else { 'Green' })
Write-Host "  Source : $srcKind  ($srcDir)" -ForegroundColor Gray
Write-Host "  Dest   : $destDir" -ForegroundColor Gray
Write-Host "  Name   : $fullName   Version: $Version   Template: $effectiveKind" -ForegroundColor Gray
Write-Host "  Desc   : $Description" -ForegroundColor Gray
Write-Host "  Report : $ReportTable" -ForegroundColor Gray
Write-Host "  Author : $Author   Year: $Year" -ForegroundColor Gray
Write-Host ''

# ---------------------------------------------------------------------------
# 9. DryRun: print plan and exit without touching the filesystem
# ---------------------------------------------------------------------------
if ($DryRun) {
    Write-Host '--- Planned operations ---' -ForegroundColor Cyan
    Write-Host ''

    Write-Host 'DIRECTORY' -ForegroundColor Magenta
    Write-DryOp 'CREATE' $destDir

    Write-Host ''
    Write-Host 'FILES TO COPY + RENAME' -ForegroundColor Magenta
    foreach ($op in $plan) {
        $srcLeaf  = Split-Path $op.SrcPath -Leaf
        $destLeaf = Split-Path $op.DestRel -Leaf
        $tag = if ($srcLeaf -ne $destLeaf) { 'COPY+RENAME' } else { 'COPY' }
        Write-DryOp $tag "$srcLeaf  ->  $($op.DestRel)"
    }

    Write-Host ''
    Write-Host 'IDENTITY REPLACEMENTS' -ForegroundColor Magenta
    $anyReplacement = $false
    $noMatchCount   = 0
    foreach ($op in $plan) {
        $fName = Split-Path $op.DestRel -Leaf
        $reps  = Get-Replacements -Kind $effectiveKind -SrcStem $srcStem -DestStem $fileStem `
                     -Ver $Version -Desc $Description -RepTable $ReportTable -FileName $fName
        if ($reps.Count -gt 0) {
            $anyReplacement = $true
            Write-Host "  File: $($op.DestRel)" -ForegroundColor DarkCyan

            # Test each pattern against the real source text. Previously the plan
            # printed every generated rule without checking whether it could
            # match, so -DryRun promised 9 replacements where execute applied 5.
            # -DryRun is a hard gate in the skill; a preview that overstates is
            # worse than no preview.
            $srcText = ''
            try   { $srcText = [System.IO.File]::ReadAllText($op.SrcPath, [System.Text.Encoding]::UTF8) }
            catch { $srcText = '' }

            foreach ($r in $reps) {
                $hit = [System.Text.RegularExpressions.Regex]::IsMatch(
                           $srcText, $r.Pattern,
                           [System.Text.RegularExpressions.RegexOptions]::Multiline)
                if ($hit) {
                    Write-DryOp '  REPLACE' $r.Description
                } else {
                    $noMatchCount++
                    Write-Host '  [DRY] ' -ForegroundColor Yellow -NoNewline
                    Write-Host '  NO MATCH' -ForegroundColor Red -NoNewline
                    Write-Host " $($r.Description)  -- pattern not present in $fName" -ForegroundColor Yellow
                }
            }
        }
    }
    if ($noMatchCount -gt 0) {
        Write-Host ''
        Write-Host "  WARNING: $noMatchCount replacement rule(s) do not match this template." -ForegroundColor Red
        Write-Host '           Those identity strings will be left at their template values.' -ForegroundColor Red
    }
    if (-not $anyReplacement) {
        Write-Host '  (none — no known identity constants for this file set)' -ForegroundColor DarkGray
    }

    Write-Host ''
    Write-Host 'STANDARD FILES (generated from assets/)' -ForegroundColor Magenta
    foreach ($sf in $scaffoldFiles) {
        $srcHasIt = $plannedLeaves -contains $sf.Dest
        if ($sf.Overwrite) {
            $note = if ($srcHasIt) { 'OVERWRITE (replaces template copy)' } else { 'CREATE' }
            Write-DryOp 'GENERATE' "$($sf.Dest)   [$note]"
        } elseif (-not $srcHasIt) {
            Write-DryOp 'GENERATE' "$($sf.Dest)   [CREATE]"
        } else {
            Write-DryOp 'SKIP' "$($sf.Dest)   [keep existing from source]"
        }
    }

    Write-Host ''
    Write-Host 'Nothing written (dry run). Re-run without -DryRun to apply.' -ForegroundColor Yellow
    exit 0
}

# ---------------------------------------------------------------------------
# 10. Execute: create dir, copy files, apply renames + replacements
# ---------------------------------------------------------------------------

# Binary extensions — skip text replacement for these
$binaryExts = @('.dll','.exe','.res','.obj','.lib','.exp','.7z','.ico','.png','.jpg','.zip','.bak')

Write-Step 'Creating' $destDir
if (Test-Path $destDir) {
    Remove-Item $destDir -Recurse -Force
}
$null = New-Item -ItemType Directory -Path $destDir -Force

# Create subdirectories
foreach ($subDir in (Get-ChildItem -Path $srcDir -Directory -Recurse)) {
    $relSub  = $subDir.FullName.Substring($srcDir.Length).TrimStart('\','/')
    $destSub = Join-Path $destDir $relSub
    if (-not (Test-Path $destSub)) {
        $null = New-Item -ItemType Directory -Path $destSub -Force
    }
}

$copiedCount   = 0
$renamedCount  = 0
$replacedCount = 0

foreach ($op in $plan) {
    $destPath   = $op.DestPath
    $destParent = Split-Path $destPath -Parent
    if (-not (Test-Path $destParent)) {
        $null = New-Item -ItemType Directory -Path $destParent -Force
    }

    Copy-Item -LiteralPath $op.SrcPath -Destination $destPath -Force
    $copiedCount++

    $srcLeaf  = Split-Path $op.SrcPath  -Leaf
    $destLeaf = Split-Path $op.DestPath -Leaf
    if ($srcLeaf -ne $destLeaf) {
        $renamedCount++
        Write-Step '  Renamed' "$srcLeaf -> $destLeaf"
    }

    $fName = Split-Path $op.DestRel -Leaf
    $ext   = [System.IO.Path]::GetExtension($fName).ToLower()

    if ($ext -notin $binaryExts) {
        $reps = Get-Replacements -Kind $effectiveKind -SrcStem $srcStem -DestStem $fileStem `
                    -Ver $Version -Desc $Description -RepTable $ReportTable -FileName $fName

        if ($reps.Count -gt 0) {
            $content  = [System.IO.File]::ReadAllText($destPath, [System.Text.Encoding]::UTF8)
            $modified = $false
            foreach ($r in $reps) {
                # Decide "did the rule apply?" by whether the pattern MATCHED,
                # not by whether the text changed. A rule can legitimately match
                # and rewrite to the identical string (e.g. VERSION is already
                # 0.1.0-beta); treating that as a miss under-reported the count
                # and made it indistinguishable from a genuinely dead pattern.
                $hit = [System.Text.RegularExpressions.Regex]::IsMatch(
                           $content, $r.Pattern,
                           [System.Text.RegularExpressions.RegexOptions]::Multiline)
                if (-not $hit) {
                    Write-Host '    NO MATCH' -ForegroundColor Red -NoNewline
                    Write-Host " [$fName] $($r.Description)  -- left at the template value" -ForegroundColor Yellow
                    continue
                }
                $newContent = [System.Text.RegularExpressions.Regex]::Replace(
                    $content, $r.Pattern, $r.Replacement,
                    [System.Text.RegularExpressions.RegexOptions]::Multiline
                )
                if ($newContent -ne $content) {
                    $content  = $newContent
                    $modified = $true
                }
                $replacedCount++
                Write-Step '    Replace' "[$fName] $($r.Description)"
            }
            if ($modified) {
                # No BOM: rc.exe rejects a UTF-8 BOM on .rc files (RC2135); cl/link
                # are fine either way, and build.bat passes /utf-8 to cl.
                [System.IO.File]::WriteAllText($destPath, $content, (New-Object System.Text.UTF8Encoding($false)))
            }
        }
    }
}

# ---------------------------------------------------------------------------
# 10b. Generate standard project files from assets/ (LICENSE / README / CLAUDE.md.example)
# ---------------------------------------------------------------------------
$generatedCount = 0
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
foreach ($sf in $scaffoldFiles) {
    $tmplPath = Join-Path $assetsDir $sf.Template
    if (-not (Test-Path -LiteralPath $tmplPath)) {
        Write-Warning "Asset template missing: $tmplPath (skipping $($sf.Dest))"
        continue
    }
    $destFile = Join-Path $destDir $sf.Dest
    if ((Test-Path -LiteralPath $destFile) -and -not $sf.Overwrite) {
        Write-Step '  Keep' "$($sf.Dest) (already provided by source)"
        continue
    }
    $rendered = Expand-Template -TemplatePath $tmplPath -Tokens $genTokens
    [System.IO.File]::WriteAllText($destFile, $rendered, $utf8NoBom)
    $generatedCount++
    Write-Step '  Generated' $sf.Dest
}

# ---------------------------------------------------------------------------
# 11. Summary
# ---------------------------------------------------------------------------
Write-Host ''
Write-Host 'Done.' -ForegroundColor Green
Write-Host "  Copied   : $copiedCount files"
Write-Host "  Renamed  : $renamedCount files"
Write-Host "  Patched  : $replacedCount identity lines"
Write-Host "  Generated: $generatedCount project files (LICENSE / README / CLAUDE.md.example)"
Write-Host "  Location : $destDir"
Write-Host ''
Write-Host 'Next: close X-Ways, then run:' -ForegroundColor Cyan
$buildHint = "  build-xtension.ps1 -Name $fullName"
if ($DestRoot) { $buildHint += " -DestRoot `"$destRootResolved`"" }
Write-Host $buildHint -ForegroundColor White
Write-Host '(from an x64 Native Tools Command Prompt for VS 2022, or let the script bootstrap MSVC for you)'
