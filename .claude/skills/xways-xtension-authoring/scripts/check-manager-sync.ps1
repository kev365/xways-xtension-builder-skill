<#
.SYNOPSIS
    Verify that all manager-plugin.h copies in the repo are in sync with the canonical.

.DESCRIPTION
    The canonical manager-plugin.h lives at:
        templates/x-tensions/cpp-xtmgr-compatible/manager-plugin.h

    Manager-compatible X-Tensions (and the xtmgr-compatible template) each carry
    a COPY of that header. If a copy drifts — especially the
    XWAYS_MANAGER_PLUGIN_ABI_VERSION define or the XwaysManagerPluginDescriptor
    layout — managed loading silently breaks.

    This script compares every copy to the canonical and reports OK or DRIFT.
    Exit code 0 = all in sync; 1 = one or more copies differ.

.PARAMETER Name
    Optional. Check only x-tensions/xways-<name>/manager-plugin.h.
    Accepts 'foo' or 'xways-foo'.

.PARAMETER All
    Scan ALL manager-plugin.h copies in the repo (default when -Name is omitted).

.EXAMPLE
    .\check-manager-sync.ps1                          # scan all copies
    .\check-manager-sync.ps1 -Name my-xtension
#>

[CmdletBinding(DefaultParameterSetName = 'All')]
param(
    [Parameter(ParameterSetName = 'Named', Position = 0)]
    [string]$Name,

    [Parameter(ParameterSetName = 'All')]
    [switch]$All
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# ---------------------------------------------------------------------------
# Helpers  (mirror new-xtension.ps1 / build-xtension.ps1 style)
# ---------------------------------------------------------------------------
function Fail([string]$msg) {
    Write-Error "ERROR: $msg"
    exit 1
}

function Write-Step([string]$label, [string]$detail = '') {
    Write-Host "  $label" -ForegroundColor Cyan -NoNewline
    if ($detail) { Write-Host " $detail" -ForegroundColor White }
    else         { Write-Host '' }
}

# ---------------------------------------------------------------------------
# Resolve repo root: scripts/ -> xways-xtension-authoring/ -> skills/ -> .claude/ -> repo root
# ---------------------------------------------------------------------------
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..\..')).Path

if (-not (Test-Path (Join-Path $repoRoot 'templates\x-tensions'))) {
    Fail "Could not locate templates/x-tensions/ under resolved repo root '$repoRoot'. Check script placement."
}

# ---------------------------------------------------------------------------
# Canonical header
# ---------------------------------------------------------------------------
$canonicalPath = Join-Path $repoRoot 'templates\x-tensions\cpp-xtmgr-compatible\manager-plugin.h'
if (-not (Test-Path $canonicalPath)) {
    Fail "Canonical manager-plugin.h not found: $canonicalPath"
}

# ---------------------------------------------------------------------------
# Normalize file content: strip BOM, normalize CRLF -> LF, trim trailing whitespace per line
# ---------------------------------------------------------------------------
function Get-NormalizedContent([string]$path) {
    $raw = [System.IO.File]::ReadAllBytes($path)
    # Strip UTF-8 BOM (EF BB BF) if present
    if ($raw.Length -ge 3 -and $raw[0] -eq 0xEF -and $raw[1] -eq 0xBB -and $raw[2] -eq 0xBF) {
        $raw = $raw[3..($raw.Length - 1)]
    }
    # Strip UTF-16 LE BOM (FF FE) if present
    if ($raw.Length -ge 2 -and $raw[0] -eq 0xFF -and $raw[1] -eq 0xFE) {
        return [System.Text.Encoding]::Unicode.GetString($raw[2..($raw.Length-1)]) -replace "`r`n", "`n" -replace "`r", "`n"
    }
    $text = [System.Text.Encoding]::UTF8.GetString($raw)
    # Normalize CRLF and bare CR to LF
    $text = $text -replace "`r`n", "`n" -replace "`r", "`n"
    return $text
}

function Get-AbiVersion([string]$content) {
    if ($content -match '(?m)^#define\s+XWAYS_MANAGER_PLUGIN_ABI_VERSION\s+(\S+)') {
        return $Matches[1]
    }
    return $null
}

# ---------------------------------------------------------------------------
# Load canonical
# ---------------------------------------------------------------------------
$canonicalNorm  = Get-NormalizedContent $canonicalPath
$canonicalAbi   = Get-AbiVersion $canonicalNorm
$canonicalLines = $canonicalNorm -split "`n"

Write-Host ""
Write-Host "manager-plugin.h sync check" -ForegroundColor Cyan
Write-Host "  Canonical : $canonicalPath"
Write-Host "  ABI version: $canonicalAbi"
Write-Host ""

# ---------------------------------------------------------------------------
# Resolve which copies to check
# ---------------------------------------------------------------------------
$copiesToCheck = @()

if ($PSBoundParameters.ContainsKey('Name') -and $Name -ne '') {
    # Single-name mode
    $shortName = if ($Name -match '^xways-(.+)$') { $Matches[1] } else { $Name }
    $fullName  = "xways-$shortName"
    $target    = Join-Path $repoRoot "x-tensions\$fullName\manager-plugin.h"
    if (-not (Test-Path $target)) {
        Fail "No manager-plugin.h found at: $target`n  Is '$fullName' a manager-compatible X-Tension?"
    }
    $copiesToCheck = @($target)
} else {
    # All-mode: find every manager-plugin.h in the repo, excluding canonical
    $canonicalNormPath = $canonicalPath.ToLowerInvariant()
    $found = Get-ChildItem -Path $repoRoot -Recurse -Filter 'manager-plugin.h' -ErrorAction SilentlyContinue |
             Where-Object { $_.FullName.ToLowerInvariant() -ne $canonicalNormPath }
    $copiesToCheck = @($found | ForEach-Object { $_.FullName })
}

if ($copiesToCheck.Count -eq 0) {
    Write-Host "  No copies found to check." -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Result: 0 in sync, 0 drifted" -ForegroundColor Green
    exit 0
}

# ---------------------------------------------------------------------------
# Compare each copy to canonical
# ---------------------------------------------------------------------------
$inSync  = 0
$drifted = 0

foreach ($copyPath in $copiesToCheck) {
    $relPath = $copyPath.Substring($repoRoot.Length).TrimStart('\', '/')

    $copyNorm  = Get-NormalizedContent $copyPath
    $copyAbi   = Get-AbiVersion $copyNorm

    # Fast-path: byte-identical after normalization
    $identical = ($copyNorm -eq $canonicalNorm)

    if ($identical) {
        Write-Host "  [OK]    $relPath" -ForegroundColor Green
        $inSync++
    } else {
        Write-Host "  [DRIFT] $relPath" -ForegroundColor Red
        $drifted++

        # ABI version delta — highest severity
        if ($copyAbi -ne $canonicalAbi) {
            Write-Host "          *** ABI VERSION MISMATCH ***" -ForegroundColor Red
            Write-Host "          Canonical ABI : $canonicalAbi" -ForegroundColor Red
            Write-Host "          Copy ABI      : $copyAbi" -ForegroundColor Red
        } elseif ($null -ne $copyAbi) {
            Write-Host "          ABI version matches ($copyAbi) — struct/callback drift only" -ForegroundColor Yellow
        }

        # Line-by-line diff — report first few differing lines
        $copyLines = $copyNorm -split "`n"
        $maxLines  = [Math]::Max($canonicalLines.Count, $copyLines.Count)
        $diffCount = 0
        $maxDiffs  = 6   # show at most this many diff lines

        for ($i = 0; $i -lt $maxLines -and $diffCount -lt $maxDiffs; $i++) {
            $cLine = if ($i -lt $canonicalLines.Count) { $canonicalLines[$i] } else { '<missing>' }
            $pLine = if ($i -lt $copyLines.Count)      { $copyLines[$i]      } else { '<missing>' }
            if ($cLine -ne $pLine) {
                $lineNum = $i + 1
                Write-Host "          Line ${lineNum}:" -ForegroundColor DarkYellow
                Write-Host "            canonical: $cLine" -ForegroundColor Gray
                Write-Host "            copy     : $pLine" -ForegroundColor DarkGray
                $diffCount++
            }
        }
        if ($diffCount -eq $maxDiffs -and $maxLines -gt $maxDiffs) {
            Write-Host "          ... (additional differences not shown; run diff manually)" -ForegroundColor DarkGray
        }
        Write-Host ""
    }
}

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
Write-Host ""
$summaryColor = if ($drifted -gt 0) { 'Red' } else { 'Green' }
Write-Host "Result: $inSync in sync, $drifted drifted" -ForegroundColor $summaryColor

if ($drifted -gt 0) {
    Write-Host ""
    Write-Host "Fix: copy the canonical header over the drifted copy/copies:" -ForegroundColor Yellow
    Write-Host "  Copy-Item '$canonicalPath' '<drifted-copy-path>' -Force" -ForegroundColor Yellow
    exit 1
}

exit 0
