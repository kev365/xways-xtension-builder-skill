<#
.SYNOPSIS
    Scaffold a new X-Ways X-Tension from a template or a local exemplar.

.DESCRIPTION
    Copies a template (cpp / python / xtmgr / wrapper) or a locally available
    exemplar directory into x-tensions/xways-<name>/, renames source files to
    the xways-<name> stem, and patches identity constants (NAME, VERSION,
    DESCRIPTION, REPORT_TABLE).
    Use -DryRun to preview every planned operation without touching the filesystem.

.PARAMETER Name
    The short identifier for the X-Tension — the '<name>' in 'xways-<name>'.
    A leading 'xways-' prefix will be stripped with a warning.

.PARAMETER Template
    Which template to copy: cpp | python | xtmgr | wrapper.  Default: cpp.
    (wrapper = the manager-compatible CLI-tool-wrapper template with helper-exe
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

[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory)]
    [string]$Name,

    [ValidateSet('cpp', 'python', 'xtmgr', 'wrapper')]
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
    Write-Error "ERROR: $msg"
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
        [string]$Kind,        # 'cpp' | 'python' | 'xtmgr' | 'wrapper'
        [string]$SrcStem,     # source stem being replaced (e.g. 'my_xtension')
        [string]$DestStem,    # target stem (e.g. 'xways-skilltest')
        [string]$Ver,
        [string]$Desc,
        [string]$RepTable,
        [string]$FileName     # leaf filename (with extension, e.g. 'xways-skilltest.cpp')
    )

    $reps = [System.Collections.Generic.List[hashtable]]::new()
    $base = [System.IO.Path]::GetFileNameWithoutExtension($FileName)
    $ext  = [System.IO.Path]::GetExtension($FileName).ToLower()

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
        } elseif ($Kind -eq 'xtmgr' -or $Kind -eq 'wrapper') {
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
            # XwaysManagerPluginDescriptor id field — matched by proximity to ABI version line
            # Pattern: the id L"..." is the FIRST string literal after the sizeof line
            # Actual template layout (lines 251-255):
            #   XWAYS_MANAGER_PLUGIN_ABI_VERSION,
            #   sizeof(XwaysManagerPluginDescriptor),
            #   L"my_xtension",                     // id
            $reps.Add(@{
                Pattern     = '(?m)(sizeof\(XwaysManagerPluginDescriptor\),\s*\r?\n\s*)L"[^"]*",([ \t]*//[ \t]*id)'
                Replacement = "`${1}L`"$DestStem`",`$2"
                Description = "descriptor id -> L`"$DestStem`""
            })
            # descriptor display_name  L"My X-Tension",
            $displayName = (($DestStem -replace '^xways-', '') -replace '[-_]', ' ')
            $displayNameTitle = ($displayName -split ' ' | ForEach-Object {
                if ($_.Length -gt 0) { $_.Substring(0,1).ToUpper() + $_.Substring(1) } else { $_ }
            }) -join ' '
            $reps.Add(@{
                Pattern     = '(?m)L"My X-Tension",([ \t]*//[ \t]*display_name)'
                Replacement = "L`"$displayNameTitle`",`$1"
                Description = "descriptor display_name -> L`"$displayNameTitle`""
            })
            # descriptor description  L"Template X-Tension. Replace.",
            $reps.Add(@{
                Pattern     = '(?m)L"Template X-Tension\. Replace\.",([ \t]*//[ \t]*description)'
                Replacement = "L`"$Desc`",`$1"
                Description = "descriptor description -> L`"$Desc`""
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
        # Only patch the main entry-point file (xtension.py / renamed), not helpers.py
        $isPyMain = ($base -eq $DestStem) -or ($base -eq 'xtension')
        # Be conservative: only patch if this is the file whose NAME constant we know
        # The template file is named 'xtension.py' → renamed to 'xways-<name>.py'
        # so after rename $base == $DestStem
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

    # --- .rc: patch CAPTION for xtmgr template
    if ($ext -eq '.rc' -and ($Kind -eq 'xtmgr' -or $Kind -eq 'wrapper') -and $base -eq $DestStem) {
        $displayName2 = (($DestStem -replace '^xways-', '') -replace '[-_]', ' ')
        $displayNameTitle2 = ($displayName2 -split ' ' | ForEach-Object {
            if ($_.Length -gt 0) { $_.Substring(0,1).ToUpper() + $_.Substring(1) } else { $_ }
        }) -join ' '
        $reps.Add(@{
            Pattern     = 'CAPTION "My X-Tension - Settings"'
            Replacement = "CAPTION `"$displayNameTitle2 - Settings`""
            Description = "CAPTION -> `"$displayNameTitle2 - Settings`""
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
# 1. Resolve repo root (scripts/ -> xways-xtension-authoring/ -> skills/ -> .claude/ -> repo root)
# ---------------------------------------------------------------------------
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..\..')).Path

# Confirm this looks like the xways repo
if (-not (Test-Path (Join-Path $repoRoot 'templates\x-tensions'))) {
    Fail "Could not locate templates\x-tensions under resolved repo root '$repoRoot'. Check script placement."
}

# ---------------------------------------------------------------------------
# 2. Resolve source directory + source stem
# ---------------------------------------------------------------------------
if ($Exemplar) {
    # An exemplar is any X-Tension folder present locally under x-tensions\
    # (none are bundled in this repo — see docs/exemplars.md).
    $srcDir = Join-Path $repoRoot "x-tensions\$Exemplar"
    if (-not (Test-Path $srcDir)) {
        Fail "Exemplar '$Exemplar' not found at x-tensions\$Exemplar. Exemplars are X-Tensions you have locally in this working copy; none are bundled — scaffold from a template instead, or clone an exemplar first (docs/exemplars.md)."
    }
    $srcStem  = $Exemplar           # e.g. 'xways-yourtool'
    $srcKind  = "exemplar:$Exemplar"
} else {
    $templateDirMap = @{
        'cpp'     = 'cpp'
        'python'  = 'python'
        'xtmgr'   = 'cpp-xtmgr-compatible'
        'wrapper' = 'wrapper'
    }
    $srcDir = Join-Path $repoRoot "templates\x-tensions\$($templateDirMap[$Template])"
    # Python template uses 'xtension' as the main file stem; cpp templates use 'my_xtension'
    $srcStem = if ($Template -eq 'python') { 'xtension' } else { 'my_xtension' }
    $srcKind  = "template:$Template"
}

if (-not (Test-Path $srcDir)) {
    Fail "Source directory not found: $srcDir"
}

# ---------------------------------------------------------------------------
# 3. HARD GATE — never write under templates/ or references/
# ---------------------------------------------------------------------------
$destDir = Join-Path $repoRoot "x-tensions\$fullName"

foreach ($protected in @('templates','references')) {
    $protectedAbs = (Join-Path $repoRoot $protected).TrimEnd('\')
    if ($destDir.TrimEnd('\').StartsWith($protectedAbs, [System.StringComparison]::OrdinalIgnoreCase)) {
        Fail "Destination '$destDir' falls inside protected directory '$protected'. Aborting."
    }
}
$xtensionsDir = Join-Path $repoRoot 'x-tensions'
if (-not $destDir.StartsWith($xtensionsDir, [System.StringComparison]::OrdinalIgnoreCase)) {
    Fail "Destination '$destDir' is not inside x-tensions/. Aborting."
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
    $Author = (& git config user.name 2>$null)
    if (-not $Author) { $Author = 'Your Name' }
}
if (-not $Year)   { $Year   = (Get-Date).Year.ToString() }

# ---------------------------------------------------------------------------
# 6. Effective template kind (for replacement dispatch)
# ---------------------------------------------------------------------------
$effectiveKind = if ($Exemplar) { 'cpp' } else { $Template }

# ---------------------------------------------------------------------------
# 7. Enumerate source files and build copy/rename plan
# ---------------------------------------------------------------------------
function Get-DestRelPath([string]$srcFilePath, [string]$srcRootPath, [string]$stem, [string]$newStem) {
    $rel  = $srcFilePath.Substring($srcRootPath.Length).TrimStart('\','/')
    $dir  = Split-Path $rel -Parent
    $leaf = Split-Path $rel -Leaf
    $base = [System.IO.Path]::GetFileNameWithoutExtension($leaf)
    $ext  = [System.IO.Path]::GetExtension($leaf)
    $newLeaf = if ($base -eq $stem) { "$newStem$ext" } else { $leaf }
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
    $destRel  = Get-DestRelPath $f.FullName $srcDir $srcStem $fullName
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
    foreach ($op in $plan) {
        $fName = Split-Path $op.DestRel -Leaf
        $reps  = Get-Replacements -Kind $effectiveKind -SrcStem $srcStem -DestStem $fullName `
                     -Ver $Version -Desc $Description -RepTable $ReportTable -FileName $fName
        if ($reps.Count -gt 0) {
            $anyReplacement = $true
            Write-Host "  File: $($op.DestRel)" -ForegroundColor DarkCyan
            foreach ($r in $reps) {
                Write-DryOp '  REPLACE' $r.Description
            }
        }
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
        $reps = Get-Replacements -Kind $effectiveKind -SrcStem $srcStem -DestStem $fullName `
                    -Ver $Version -Desc $Description -RepTable $ReportTable -FileName $fName

        if ($reps.Count -gt 0) {
            $content  = [System.IO.File]::ReadAllText($destPath, [System.Text.Encoding]::UTF8)
            $modified = $false
            foreach ($r in $reps) {
                $newContent = [System.Text.RegularExpressions.Regex]::Replace(
                    $content, $r.Pattern, $r.Replacement,
                    [System.Text.RegularExpressions.RegexOptions]::Multiline
                )
                if ($newContent -ne $content) {
                    $content  = $newContent
                    $modified = $true
                    $replacedCount++
                    Write-Step '    Replace' "[$fName] $($r.Description)"
                }
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
Write-Host "  build-xtension.ps1 -Name $fullName" -ForegroundColor White
Write-Host '(from an x64 Native Tools Command Prompt for VS 2022, or let the script bootstrap MSVC for you)'
