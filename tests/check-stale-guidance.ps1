<#
.SYNOPSIS
    Fail the build when the knowledge base teaches something the project has
    already superseded.

.DESCRIPTION
    Three separate audits found the same class of bug: a convention was decided,
    the canonical page was updated, and a second page kept teaching the old
    thing. Prose review does not catch this reliably -- the stale page reads
    perfectly well on its own. Only a cross-file check does.

    Each rule below encodes one superseded prescription. A rule fires only on
    *prescriptive* use; pages that discuss the old form in order to warn against
    it, or that record it as dated history, are allowed to say the words.

    Add a rule here whenever a convention is reversed. That is cheaper than
    re-finding the drift in a later audit.

.EXAMPLE
    pwsh -File tests/check-stale-guidance.ps1
#>
[CmdletBinding()]
param(
    [string]$Root = (Split-Path $PSScriptRoot -Parent)
)

$ErrorActionPreference = 'Stop'
$findings = [System.Collections.Generic.List[psobject]]::new()

# Repo furniture and dated records are not skill payload: a changelog entry
# describing an old behavior is correct precisely because it is historical.
$excludedPaths = @(
    'CHANGELOG.md',
    'evals/baseline.md',
    'docs/xways-api-history-19-to-21_4.md',
    'docs/xways-api-recency-research.md',
    'docs/forum-xtensions-distilled.md',
    'docs/events-viewer-empirical-findings.md',
    # Records what was measured, with the call name used at measurement time.
    # Rewriting the symbol would falsify the experiment, not modernise it.
    'docs/xways-snapshot-mutation.md'
)

# How far to look around a hit for the modern call. A correct fallback branch
# ("if (XWF_Label) ... else XWF_AddToReportTable(...)") names the preferred call
# on an adjacent line, not the same one.
$contextRadius = 2

# A line that argues *against* a pattern must be allowed to name it.
$negationCue = "don't|do not|\bnot\b|never|instead of|rather than|no longer|superseded|deprecated|misconception|wrong|older host|pre-rename|fall ?back"

$rules = @(
    @{
        Name    = 'Shift-to-save gesture'
        Pattern = 'Shift\+Run|Shift\+Cancel|Shift-to-save|Shift-for-'
        Canon   = 'docs/conventions/ctrl-to-save.md'
        Why     = 'The canonical save gesture is Ctrl+Run / Ctrl+Close. Shift was reconciled away.'
        AllowIfNegated = $false   # there is no correct prescriptive use left
    },
    @{
        Name    = 'Deprecated report-table call'
        Pattern = 'XWF_AddToReportTable|XWF_GetReportTableAssocs'
        Canon   = 'references/api-guardrail.md'
        Why     = 'Prefer XWF_Label / XWF_GetLabels. The old name is valid only as an explicit older-host fallback, so the line must also name the new call.'
        AllowIfNegated = $true
        AlsoAllowIf    = 'XWF_Label|XWF_GetLabels'
    },
    @{
        Name    = '0x04 as a callback selector'
        Pattern = '0x01\s*\|\s*0x04'
        Canon   = 'docs/conventions/item-collection.md'
        Why     = '0x04 is EXPECTMOREITEMS, not "also call the Ex variant". Only an item-creating X-Tension returns it.'
        AllowIfNegated = $true
        AlsoAllowIf    = 'EXPECTMOREITEMS|creat'
    }
)

$mdFiles = & git -C $Root ls-files '*.md'
if ($LASTEXITCODE -ne 0) { Write-Host 'ERROR: git ls-files failed' -ForegroundColor Red; exit 1 }

foreach ($rel in $mdFiles) {
    if ($excludedPaths -contains $rel) { continue }
    $full = Join-Path $Root $rel
    if (-not (Test-Path $full)) { continue }

    $all = @(Get-Content -LiteralPath $full)
    for ($i = 0; $i -lt $all.Count; $i++) {
        $line   = $all[$i]
        $lineNo = $i + 1
        $lo     = [Math]::Max(0, $i - $contextRadius)
        $hi     = [Math]::Min($all.Count - 1, $i + $contextRadius)
        $context = ($all[$lo..$hi]) -join "`n"

        foreach ($rule in $rules) {
            if ($line -notmatch $rule.Pattern) { continue }
            if ($rule.AllowIfNegated -and $line -imatch $negationCue) { continue }
            # Look at the neighbourhood, not just the line: a fallback branch
            # names the modern call one line up.
            if ($rule.AlsoAllowIf -and $context -imatch $rule.AlsoAllowIf) { continue }
            $findings.Add([pscustomobject]@{
                File = $rel; Line = $lineNo; Rule = $rule.Name
                Why  = $rule.Why; Canon = $rule.Canon
                Text = $line.Trim()
            })
        }
    }
}

if ($findings.Count -eq 0) {
    Write-Host "RESULT: PASS - no superseded guidance found in $($mdFiles.Count) markdown files" -ForegroundColor Green
    exit 0
}

Write-Host "STALE GUIDANCE ($($findings.Count)):" -ForegroundColor Red
foreach ($g in ($findings | Group-Object Rule)) {
    Write-Host "`n  $($g.Name)" -ForegroundColor Yellow
    Write-Host "    $($g.Group[0].Why)"
    Write-Host "    Canonical: $($g.Group[0].Canon)"
    foreach ($f in $g.Group) {
        Write-Host "      $($f.File):$($f.Line)" -ForegroundColor Red
        $snippet = if ($f.Text.Length -gt 110) { $f.Text.Substring(0, 110) + '...' } else { $f.Text }
        Write-Host "        $snippet" -ForegroundColor DarkGray
    }
}
Write-Host "`nRESULT: FAIL" -ForegroundColor Red
exit 1
