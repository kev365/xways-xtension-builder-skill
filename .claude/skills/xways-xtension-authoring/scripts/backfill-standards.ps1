<#
.SYNOPSIS
    Backfill the public-release standard files (LICENSE + CLAUDE.md.example) into
    every active X-Tension that is missing them. Additive and idempotent.

.DESCRIPTION
    For each non-git-ignored folder under x-tensions/, generates a missing
    LICENSE (MIT) and/or CLAUDE.md.example (rendered from the skill's assets/
    templates, with NAME / DESCRIPTION / VERSION pulled from the X-Tension's main
    source where detectable). Never overwrites an existing file unless -Force.

    Intentionally does NOT touch source versions or READMEs — those edit working
    code / prose and are handled per-tool (see docs/conventions/versioning.md and
    readme-roadmap.md). This script only fills the two purely-additive gaps.

.PARAMETER Author  Copyright holder stamped into LICENSE. Default: your
                   `git config user.name`, or "Your Name" if unset.
.PARAMETER Year    Copyright year. Default: current year.
.PARAMETER DryRun  Show planned writes, change nothing.
.PARAMETER Force   Overwrite an existing LICENSE / CLAUDE.md.example.

.EXAMPLE
    .\backfill-standards.ps1 -DryRun
    .\backfill-standards.ps1
#>
[CmdletBinding()]
param(
    [string]$Author,
    [string]$Year,
    [switch]$DryRun,
    [switch]$Force
)
if (-not $Author) {
    $Author = (& git config user.name 2>$null)
    if (-not $Author) { $Author = 'Your Name' }
}

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
if (-not $Year) { $Year = (Get-Date).Year.ToString() }

# scripts/ -> xways-xtension-authoring/ -> skills/ -> .claude/ -> repo root
$repoRoot  = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..\..')).Path
$assetsDir = (Resolve-Path (Join-Path $PSScriptRoot '..\assets')).Path
$xtRoot    = Join-Path $repoRoot 'x-tensions'
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)

function Expand-Template {
    param([string]$TemplatePath, [hashtable]$Tokens)
    $t = [System.IO.File]::ReadAllText($TemplatePath, [System.Text.Encoding]::UTF8)
    foreach ($k in $Tokens.Keys) { $t = $t.Replace('{{' + $k + '}}', [string]$Tokens[$k]) }
    return $t
}

# Pull an identity constant (DESCRIPTION / VERSION) from a folder's main .cpp or .py.
function Get-IdentityConst {
    param([string]$dir, [string]$const)
    foreach ($f in (Get-ChildItem -Path $dir -Filter *.cpp -File -ErrorAction SilentlyContinue)) {
        $m = [System.Text.RegularExpressions.Regex]::Match(
            [System.IO.File]::ReadAllText($f.FullName), $const + '\s*=\s*L?"([^"]*)"')
        if ($m.Success) { return $m.Groups[1].Value }
    }
    foreach ($f in (Get-ChildItem -Path $dir -Filter *.py -File -ErrorAction SilentlyContinue)) {
        $m = [System.Text.RegularExpressions.Regex]::Match(
            [System.IO.File]::ReadAllText($f.FullName), '(?m)^' + $const + '\s*=\s*"([^"]*)"')
        if ($m.Success) { return $m.Groups[1].Value }
    }
    return ''
}

Push-Location $repoRoot
try {
    $written = 0; $skipped = 0
    foreach ($d in (Get-ChildItem -Path $xtRoot -Directory | Sort-Object Name)) {
        $rel = "x-tensions/$($d.Name)"
        git check-ignore -q $rel
        if ($LASTEXITCODE -eq 0) { continue }   # git-ignored folder — skip

        $name = $d.Name
        $desc = Get-IdentityConst $d.FullName 'DESCRIPTION'
        if (-not $desc) { $desc = "$name X-Tension." }
        $ver  = Get-IdentityConst $d.FullName 'VERSION'
        if (-not $ver) { $ver = '0.1.0-beta' }
        $tokens = @{ NAME = $name; DESCRIPTION = $desc; VERSION = $ver; YEAR = $Year; AUTHOR = $Author }

        foreach ($t in @(
            @{ Dest = 'LICENSE';          Tmpl = 'LICENSE.tmpl' },
            @{ Dest = 'CLAUDE.md.example'; Tmpl = 'CLAUDE.md.example.tmpl' }
        )) {
            $dest = Join-Path $d.FullName $t.Dest
            if ((Test-Path -LiteralPath $dest) -and -not $Force) { $skipped++; continue }
            if ($DryRun) {
                Write-Host ("[DRY] WOULD WRITE  {0}\{1}   (ver {2})" -f $name, $t.Dest, $ver) -ForegroundColor Yellow
                continue
            }
            $rendered = Expand-Template (Join-Path $assetsDir $t.Tmpl) $tokens
            [System.IO.File]::WriteAllText($dest, $rendered, $utf8NoBom)
            Write-Host ("WROTE  {0}\{1}   (ver {2})" -f $name, $t.Dest, $ver) -ForegroundColor Green
            $written++
        }
    }
} finally { Pop-Location }

Write-Host ''
if ($DryRun) {
    Write-Host 'Dry run — nothing written. Re-run without -DryRun to apply.' -ForegroundColor Yellow
} else {
    Write-Host ("Done. Written: {0}   Skipped (already present): {1}" -f $written, $skipped) -ForegroundColor Cyan
}
exit 0
