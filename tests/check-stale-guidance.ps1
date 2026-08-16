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
    },
    @{
        # The 2026-08-16 review found the same misconception in decimal prose
        # ("4  = call XT_ProcessItemEx" in a docstring) that the hex rule above
        # cannot see. Both spellings of the claim are wrong the same way.
        Name    = 'return 4 taught as the Ex selector (decimal form)'
        Pattern = '4\s*=\s*call XT_ProcessItemEx'
        Canon   = 'docs/conventions/item-collection.md'
        Why     = 'Returning 4 (EXPECTMOREITEMS) does not select XT_ProcessItemEx; X-Ways calls whichever per-item callback(s) you export.'
        AllowIfNegated = $true
        AlsoAllowIf    = 'EXPECTMOREITEMS|creat'
    },
    @{
        # Found by hand after the first three rules went in: a reference page
        # called XWF_Label "the 21.8+ name". Someone targeting 21.7 reads that
        # and correctly concludes they must use the old call -- so a wrong
        # version claim reintroduces the deprecated-call habit by a side door.
        Name    = 'Report-table rename dated 21.8-only'
        Pattern = 'XWF_Label|XWF_GetLabels'
        Canon   = 'docs/xways-api-recency-research.md'
        Why     = 'The rename was backported to 21.4 SR-11 / 21.5 SR-13 / 21.6 SR-8 / 21.7 SR-4. Only label *removal* (nFlags 0x80000000) is 21.8+. A line tying the rename itself to 21.8 must say "backport" or name an SR.'
        # Both must be present: the version *and* a claim about the naming.
        # "Audit my old X-Tension for 21.8" is a target version, not a claim
        # about when the rename shipped, and must not trip this.
        # \bnames?\b deliberately does not match lpLabelName / lpReportTableName.
        RequiresAllOf  = @('21\.8', '\bnames?\b')
        AllowIfNegated = $false
        AlsoAllowIf    = 'backport|SR-|removal|remove'
    },
    @{
        # The xtmgr template and every manager hook were removed in 0.5.0
        # because xways-xt-manager is not public. A rule is cheaper than
        # rediscovering a half-reintroduced contract in a later audit.
        Name    = 'Removed xt-manager support'
        Pattern = 'cpp-xtmgr-compatible|XwaysManagerPluginEntry|manager-plugin\.h|check-manager-sync|-Template\s+xtmgr'
        Canon   = 'CHANGELOG.md (0.5.0, Removed)'
        Why     = 'Manager-compatible scaffolding was removed; xways-xt-manager is not public. Do not reintroduce it in the skill.'
        AllowIfNegated = $false
    }
)

# Prose and code both. The starter templates are the strongest lever on what
# generated X-Tensions look like -- the cpp template teaching only the
# pre-rename call is what kept producing outdated report-table code, and no
# markdown check would ever have seen it.
$mdFiles = & git -C $Root ls-files '*.md' '*.cpp' '*.h' '*.py' '*.rc' '*.ps1'
if ($LASTEXITCODE -ne 0) { Write-Host 'ERROR: git ls-files failed' -ForegroundColor Red; exit 1 }
# This checker names the patterns it hunts for, so it would flag itself.
$mdFiles = $mdFiles | Where-Object { $_ -ne 'tests/check-stale-guidance.ps1' }

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
            # Some rules fire only on a co-occurrence (a symbol *and* a wrong
            # version claim), not on the symbol alone. Every listed pattern
            # must be present on the line.
            if ($rule.RequiresAllOf) {
                $allPresent = $true
                foreach ($req in @($rule.RequiresAllOf)) {
                    if ($line -notmatch $req) { $allPresent = $false; break }
                }
                if (-not $allPresent) { continue }
            }
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
    Write-Host "RESULT: PASS - no superseded guidance found in $($mdFiles.Count) scanned files (md/cpp/h/py/rc/ps1)" -ForegroundColor Green
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
