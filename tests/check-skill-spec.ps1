<#
.SYNOPSIS
    Validate SKILL.md against the Agent Skills specification.

.DESCRIPTION
    Encodes the rules from https://agentskills.io/specification so that spec
    conformance cannot silently regress. The upstream reference validator
    (agentskills/agentskills "skills-ref") is installed from source and is
    labelled by its authors as being for demonstration purposes only, so it runs
    in CI as an advisory job while this script is the actual gate.

    Errors fail the build. Warnings are printed and do not.

.EXAMPLE
    pwsh -File tests/check-skill-spec.ps1
#>
[CmdletBinding()]
param(
    [string]$Root = (Split-Path $PSScriptRoot -Parent)
)

$ErrorActionPreference = 'Stop'
$errors   = [System.Collections.Generic.List[string]]::new()
$warnings = [System.Collections.Generic.List[string]]::new()

$skillPath = Join-Path $Root 'SKILL.md'
if (-not (Test-Path $skillPath)) { Write-Host "ERROR: no SKILL.md at $Root" -ForegroundColor Red; exit 1 }

$lines = Get-Content $skillPath
if ($lines[0].Trim() -ne '---') { $errors.Add('SKILL.md does not begin with a YAML frontmatter delimiter (---)') }

$end = -1
for ($i = 1; $i -lt $lines.Count; $i++) { if ($lines[$i].Trim() -eq '---') { $end = $i; break } }
if ($end -lt 0) { Write-Host 'ERROR: frontmatter is not terminated' -ForegroundColor Red; exit 1 }

$fmLines   = $lines[1..($end - 1)]
$bodyLines = $lines[($end + 1)..($lines.Count - 1)]

# Flat parse: top-level "key: value", plus one level of nested mapping.
$fields = @{}
$nested = @{}
$currentParent = $null
foreach ($l in $fmLines) {
    if ($l -match '^\s*$' -or $l -match '^\s*#') { continue }
    if ($l -match '^([A-Za-z][A-Za-z0-9_-]*):\s*(.*)$') {
        $currentParent = $Matches[1]
        $val = $Matches[2].Trim()
        $fields[$currentParent] = $val
        if ($val -eq '') { $nested[$currentParent] = @{} }
    } elseif ($l -match '^\s+([A-Za-z][A-Za-z0-9_-]*):\s*(.*)$' -and $currentParent) {
        if (-not $nested.ContainsKey($currentParent)) { $nested[$currentParent] = @{} }
        $nested[$currentParent][$Matches[1]] = $Matches[2].Trim()
    }
}

# --- name -----------------------------------------------------------------
$name = $fields['name']
if (-not $name) {
    $errors.Add('name: required field is missing')
} else {
    if ($name.Length -gt 64)                { $errors.Add("name: $($name.Length) chars, max is 64") }
    if ($name -cnotmatch '^[a-z0-9-]+$')    { $errors.Add("name: '$name' may contain only lowercase letters, digits and hyphens") }
    if ($name -match '^-|-$')               { $errors.Add("name: '$name' must not start or end with a hyphen") }
    if ($name -match '--')                  { $errors.Add("name: '$name' must not contain consecutive hyphens") }
    foreach ($w in @('anthropic', 'claude')) {
        if ($name -match $w)                { $errors.Add("name: '$name' contains the reserved word '$w'") }
    }
    # The spec asks that name match the parent directory. This repo is itself
    # the skill root, so the clone directory name governs -- and it differs.
    # Not an error: Claude Code keys off the frontmatter name, and a personal
    # install junctioned as ~/.claude/skills/<name> does match.
    $dirName = Split-Path $Root -Leaf
    if ($dirName -ne $name) {
        $warnings.Add("name: '$name' does not match the skill-root directory '$dirName' (spec prefers a match; harmless for a plugin or a junction named '$name')")
    }
}

# --- description ----------------------------------------------------------
$desc = $fields['description']
if (-not $desc)                      { $errors.Add('description: required field is missing or empty') }
else {
    if ($desc.Length -gt 1024)       { $errors.Add("description: $($desc.Length) chars, max is 1024") }
    if ($desc -match '<[^>]+>')      { $errors.Add('description: must not contain XML tags') }
}

# --- compatibility --------------------------------------------------------
if ($fields.ContainsKey('compatibility')) {
    $c = $fields['compatibility']
    if ($c.Length -gt 500) { $errors.Add("compatibility: $($c.Length) chars, max is 500") }
}

# --- metadata: must be a map of string -> string --------------------------
if ($fields.ContainsKey('metadata')) {
    if ($fields['metadata'] -ne '') {
        $errors.Add('metadata: must be a mapping, not an inline scalar')
    } elseif ($nested.ContainsKey('metadata')) {
        foreach ($k in $nested['metadata'].Keys) {
            $v = $nested['metadata'][$k]
            if ($v -match '^\[.*\]$') { $errors.Add("metadata.${k}: is a list; the spec defines metadata as a map of string keys to string VALUES") }
            if ($v -eq '')            { $errors.Add("metadata.${k}: is empty or a nested mapping; only string values are allowed") }
        }
    }
}

# --- unknown top-level fields --------------------------------------------
$known = @('name', 'description', 'license', 'compatibility', 'metadata', 'allowed-tools')
foreach ($k in $fields.Keys) {
    if ($known -notcontains $k) { $warnings.Add("frontmatter: '$k' is not a field defined by the spec") }
}

# --- body length ----------------------------------------------------------
if ($bodyLines.Count -gt 500) {
    $warnings.Add("body: $($bodyLines.Count) lines; the spec recommends keeping SKILL.md under 500")
}

# --- report ---------------------------------------------------------------
Write-Host "SKILL.md: name='$name'  description=$($desc.Length) chars  body=$($bodyLines.Count) lines"

if ($warnings.Count -gt 0) {
    Write-Host "`nWARNINGS ($($warnings.Count)):" -ForegroundColor Yellow
    $warnings | ForEach-Object { Write-Host "  $_" -ForegroundColor Yellow }
}
if ($errors.Count -gt 0) {
    Write-Host "`nERRORS ($($errors.Count)):" -ForegroundColor Red
    $errors | ForEach-Object { Write-Host "  $_" -ForegroundColor Red }
    Write-Host "`nRESULT: FAIL" -ForegroundColor Red
    exit 1
}

Write-Host "`nRESULT: PASS - SKILL.md conforms to the Agent Skills spec" -ForegroundColor Green
exit 0
