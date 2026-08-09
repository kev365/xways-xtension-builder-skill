<#
.SYNOPSIS
    The release version is declared in four places; they must agree.

.DESCRIPTION
    SKILL.md frontmatter, .claude-plugin/plugin.json, and two fields in
    .claude-plugin/marketplace.json all carry the version. Nothing checked that
    they matched, so every release was a four-way manual sync -- and a
    marketplace.json that disagrees with plugin.json produces a plugin whose
    advertised version is not the one installed.

    SKILL.md is treated as the source of truth: it is the file a human edits
    when cutting a release, and the only one the skill itself exposes.

    The CHANGELOG is checked too, but only for the presence of a matching
    heading -- an unreleased version legitimately sits under an "unreleased"
    marker, so the date is not validated here.

.EXAMPLE
    pwsh -File tests/check-version-sync.ps1
#>
[CmdletBinding()]
param(
    [string]$Root = (Split-Path $PSScriptRoot -Parent)
)

$ErrorActionPreference = 'Stop'
$errors = [System.Collections.Generic.List[string]]::new()

function Get-Text { param([string]$Rel)
    $p = Join-Path $Root $Rel
    if (-not (Test-Path $p)) { throw "missing file: $Rel" }
    return (Get-Content -LiteralPath $p -Raw)
}

# --- source of truth: SKILL.md frontmatter metadata.version -----------------
$skill = Get-Text 'SKILL.md'
$fm = [regex]::Match($skill, '(?s)\A---\r?\n(.*?)\r?\n---')
if (-not $fm.Success) { Write-Host 'ERROR: SKILL.md has no frontmatter' -ForegroundColor Red; exit 1 }
$m = [regex]::Match($fm.Groups[1].Value, '(?m)^\s+version:\s*(\S+)\s*$')
if (-not $m.Success) { Write-Host 'ERROR: SKILL.md frontmatter has no metadata.version' -ForegroundColor Red; exit 1 }
$expected = $m.Groups[1].Value.Trim().Trim('"', "'")

$found = [ordered]@{ 'SKILL.md (metadata.version)' = $expected }

# --- plugin.json ------------------------------------------------------------
$plugin = Get-Text '.claude-plugin/plugin.json' | ConvertFrom-Json
$found['.claude-plugin/plugin.json (version)'] = $plugin.version

# --- marketplace.json: both the metadata block and each plugin entry --------
$market = Get-Text '.claude-plugin/marketplace.json' | ConvertFrom-Json
$found['.claude-plugin/marketplace.json (metadata.version)'] = $market.metadata.version
foreach ($p in $market.plugins) {
    $found[".claude-plugin/marketplace.json (plugins[$($p.name)].version)"] = $p.version
}

foreach ($k in $found.Keys) {
    if ($found[$k] -ne $expected) {
        $errors.Add("$k = '$($found[$k])' but SKILL.md declares '$expected'")
    }
}

# --- plugin name must match the skill name too ------------------------------
$nameMatch = [regex]::Match($fm.Groups[1].Value, '(?m)^name:\s*(\S+)\s*$')
if ($nameMatch.Success) {
    $skillName = $nameMatch.Groups[1].Value.Trim()
    if ($plugin.name -ne $skillName) {
        $errors.Add("plugin.json name = '$($plugin.name)' but SKILL.md name = '$skillName'")
    }
    foreach ($p in $market.plugins) {
        if ($p.name -ne $skillName) {
            $errors.Add("marketplace.json plugins[].name = '$($p.name)' but SKILL.md name = '$skillName'")
        }
    }
}

# --- CHANGELOG must at least mention this version ---------------------------
$changelog = Get-Text 'CHANGELOG.md'
if ($changelog -notmatch [regex]::Escape("[$expected]")) {
    $errors.Add("CHANGELOG.md has no '[$expected]' heading")
}

Write-Host "Declared version: $expected"
foreach ($k in $found.Keys) {
    $ok = $found[$k] -eq $expected
    $mark = if ($ok) { 'ok  ' } else { 'BAD ' }
    $color = if ($ok) { 'DarkGray' } else { 'Red' }
    Write-Host ("  {0}{1} = {2}" -f $mark, $k, $found[$k]) -ForegroundColor $color
}

if ($errors.Count -gt 0) {
    Write-Host "`nVERSION DRIFT ($($errors.Count)):" -ForegroundColor Red
    $errors | ForEach-Object { Write-Host "  $_" -ForegroundColor Red }
    Write-Host "`nRESULT: FAIL" -ForegroundColor Red
    exit 1
}

Write-Host "`nRESULT: PASS - version and name agree across all manifests" -ForegroundColor Green
exit 0
