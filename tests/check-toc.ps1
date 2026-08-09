<#
.SYNOPSIS
    Every long knowledge-base page must carry an accurate "## Contents" list.

.DESCRIPTION
    Anthropic's skill-authoring guidance asks for a table of contents on any
    reference file over 100 lines, because Claude may preview a file with a
    partial read (head -100) when it arrives via another referenced file rather
    than directly from SKILL.md. A ToC in the first screenful means the whole
    scope of the page is visible even when the body is not.

    That matters most for docs/, where pages are reached through docs/INDEX.md
    and are therefore two hops from SKILL.md.

    A stale ToC is worse than none, so this checks accuracy, not just presence:
      - every H2 (outside fenced code) appears in the Contents list
      - every Contents entry corresponds to a real H2

    Entries may carry a trailing annotation after the heading text -- see
    references/scripts.md, where "`new-xtension.ps1` -- scaffold" documents a
    heading of "`new-xtension.ps1`". The heading must be a prefix of the entry.

    Run with -Fix to write missing or drifted Contents blocks in place,
    preserving any annotations already present.

.EXAMPLE
    pwsh -File tests/check-toc.ps1
    pwsh -File tests/check-toc.ps1 -Fix
#>
[CmdletBinding()]
param(
    [string]$Root = (Split-Path $PSScriptRoot -Parent),
    [switch]$Fix,
    [int]$MinLines = 100,
    # A two-section page gains nothing from a contents list.
    [int]$MinHeadings = 3
)

$ErrorActionPreference = 'Stop'

# Repo furniture: read by humans browsing GitHub, not loaded as skill context.
$excluded = @(
    'README.md', 'CHANGELOG.md', 'CONTRIBUTING.md', 'SECURITY.md', 'NOTICE.md',
    'CLAUDE.md.example', 'SKILL.md'
)
$excludedPrefixes = @('evals/', 'tests/', '.github/')

function Get-Sections {
    <#  Returns H2 headings and their 0-based line indexes, skipping fenced
        code blocks so a "## comment" inside C++ is not mistaken for a heading. #>
    param([string[]]$Lines)
    $result = [System.Collections.Generic.List[psobject]]::new()
    $inFence = $false; $fence = $null
    for ($i = 0; $i -lt $Lines.Count; $i++) {
        $l = $Lines[$i]
        if ($l -match '^[ \t]*(`{3,}|~{3,})') {
            $tok = $Matches[1].Substring(0, 3)
            if (-not $inFence) { $inFence = $true; $fence = $tok }
            elseif ($tok -eq $fence) { $inFence = $false }
            continue
        }
        if ($inFence) { continue }
        if ($l -match '^##\s+(.+?)\s*$') {
            $result.Add([pscustomobject]@{ Text = $Matches[1]; Index = $i })
        }
    }
    return $result
}

function Get-TocBlock {
    <# Locate an existing "## Contents" heading and the entries beneath it. #>
    param([string[]]$Lines)
    for ($i = 0; $i -lt $Lines.Count; $i++) {
        if ($Lines[$i] -match '^##\s+Contents\s*$') {
            $entries = [System.Collections.Generic.List[string]]::new()
            $end = $i + 1
            for ($j = $i + 1; $j -lt $Lines.Count; $j++) {
                if ($Lines[$j] -match '^#{1,6}\s') { break }
                if ($Lines[$j] -match '^\s*[-*]\s+(.+?)\s*$') { $entries.Add($Matches[1]) }
                $end = $j
            }
            return [pscustomobject]@{ Start = $i; End = $end; Entries = $entries }
        }
    }
    return $null
}

function Normalize { param([string]$s) return ($s -replace '[^a-zA-Z0-9]', '').ToLowerInvariant() }

$mdFiles = & git -C $Root ls-files '*.md'
if ($LASTEXITCODE -ne 0) { Write-Host 'ERROR: git ls-files failed' -ForegroundColor Red; exit 1 }

$problems = [System.Collections.Generic.List[psobject]]::new()
$fixed    = [System.Collections.Generic.List[string]]::new()
$checked  = 0

foreach ($rel in $mdFiles) {
    if ($excluded -contains $rel) { continue }
    $skip = $false
    foreach ($p in $excludedPrefixes) { if ($rel.StartsWith($p)) { $skip = $true; break } }
    if ($skip) { continue }

    $full = Join-Path $Root $rel
    if (-not (Test-Path $full)) { continue }
    $lines = @(Get-Content -LiteralPath $full)
    if ($lines.Count -le $MinLines) { continue }

    $sections = Get-Sections -Lines $lines
    $body = @($sections | Where-Object { $_.Text -notmatch '^Contents$' })
    if ($body.Count -lt $MinHeadings) { continue }
    $checked++

    $toc = Get-TocBlock -Lines $lines
    $entries = if ($toc) { @($toc.Entries) } else { @() }

    # An entry covers a heading when the heading text is a prefix of the entry,
    # which permits "<heading> -- annotation" without permitting drift.
    $uncovered = @()
    foreach ($h in $body) {
        $hn = Normalize $h.Text
        $hit = $false
        foreach ($e in $entries) { if ((Normalize $e).StartsWith($hn)) { $hit = $true; break } }
        if (-not $hit) { $uncovered += $h.Text }
    }
    $orphaned = @()
    foreach ($e in $entries) {
        $en = Normalize $e
        $hit = $false
        foreach ($h in $body) { if ($en.StartsWith((Normalize $h.Text))) { $hit = $true; break } }
        if (-not $hit) { $orphaned += $e }
    }

    if (-not $toc) {
        $problems.Add([pscustomobject]@{ File = $rel; Issue = "no '## Contents' section ($($lines.Count) lines, $($body.Count) sections)" })
    } elseif ($uncovered.Count -or $orphaned.Count) {
        $detail = @()
        if ($uncovered) { $detail += "missing from ToC: $($uncovered -join '; ')" }
        if ($orphaned)  { $detail += "ToC entry has no heading: $($orphaned -join '; ')" }
        $problems.Add([pscustomobject]@{ File = $rel; Issue = ($detail -join ' | ') })
    } else { continue }

    if (-not $Fix) { continue }

    # Rebuild the block, carrying over any annotation already written for a
    # heading that survives.
    $newEntries = foreach ($h in $body) {
        $hn = Normalize $h.Text
        $keep = $null
        foreach ($e in $entries) { if ((Normalize $e).StartsWith($hn)) { $keep = $e; break } }
        $text = if ($keep) { $keep } else { $h.Text }
        # A heading like "## 1. Tool deployment" would otherwise render as
        # "- 1. Tool deployment", which markdown reads as a nested ordered list
        # (and markdownlint flags as MD029). Escaping the dot keeps the visible
        # text identical while leaving it a plain bullet.
        $text = [regex]::Replace($text, '^(\d+)\.\s', '$1\. ')
        "- $text"
    }
    $block = @('## Contents', '') + $newEntries + @('')

    if ($toc) {
        $before = if ($toc.Start -gt 0) { $lines[0..($toc.Start - 1)] } else { @() }
        $after  = if ($toc.End -lt $lines.Count - 1) { $lines[($toc.End + 1)..($lines.Count - 1)] } else { @() }
        $out = @($before) + $block + @($after)
    } else {
        # Insert directly above the first real section, so any intro paragraph
        # under the H1 keeps its position.
        $at = $body[0].Index
        $before = $lines[0..($at - 1)]
        $after  = $lines[$at..($lines.Count - 1)]
        # Collapse a trailing blank so we do not stack two.
        while ($before.Count -and $before[-1].Trim() -eq '') { $before = $before[0..($before.Count - 2)] }
        $out = @($before) + @('') + $block + @($after)
    }

    # Write LF explicitly. Set-Content would use the platform newline and leave
    # CRLF in the working tree; .gitattributes would normalise it on commit, but
    # every untouched line would still show as modified until the next checkout.
    $utf8NoBom = [System.Text.UTF8Encoding]::new($false)
    [System.IO.File]::WriteAllText($full, (($out -join "`n") + "`n"), $utf8NoBom)
    $fixed.Add($rel)
}

if ($Fix) {
    Write-Host "Rewrote Contents in $($fixed.Count) file(s):" -ForegroundColor Cyan
    $fixed | ForEach-Object { Write-Host "  $_" }
    Write-Host "`nRe-run without -Fix to verify." -ForegroundColor Cyan
    exit 0
}

Write-Host "Checked $checked page(s) over $MinLines lines with $MinHeadings+ sections."
if ($problems.Count -eq 0) {
    Write-Host "RESULT: PASS - every long page has an accurate table of contents" -ForegroundColor Green
    exit 0
}
Write-Host "`nMISSING OR STALE CONTENTS ($($problems.Count)):" -ForegroundColor Red
foreach ($p in $problems) {
    Write-Host "  $($p.File)" -ForegroundColor Red
    Write-Host "    $($p.Issue)" -ForegroundColor DarkGray
}
Write-Host "`nFix with: pwsh -File tests/check-toc.ps1 -Fix" -ForegroundColor Yellow
Write-Host "RESULT: FAIL" -ForegroundColor Red
exit 1
