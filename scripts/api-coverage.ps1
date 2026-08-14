<#
.SYNOPSIS
    Measure which officially documented X-Tension API functions this knowledge
    base actually covers.

.DESCRIPTION
    Downloads the two official reference pages, extracts every documented
    function, and classifies each against the tracked files:

      covered    a docs/ page mentions it more than once (an explanation)
      mentioned  it appears, but only in passing -- typically a history row
      absent     nothing in the repository mentions it at all

    Writes the numbers that docs/xways-api-coverage-map.md quotes. Run it when
    the official pages change or after documenting new functions, then update
    that page and its frontmatter date.

    NOT a CI gate. Coverage gaps are expected and this needs network access;
    failing the build over them would be noise.

.PARAMETER Detail
    Also list the functions in each bucket, not just the counts.

.EXAMPLE
    pwsh -File scripts/api-coverage.ps1 -Detail
#>
[CmdletBinding()]
param(
    [string]$Root = (Split-Path $PSScriptRoot -Parent),
    [switch]$Detail
)

$ErrorActionPreference = 'Stop'

# The coverage map names every uncovered function, so counting it as a mention
# would make the map mark them covered -- it would measure itself and report
# zero gaps. Exclude it. The CHANGELOG is excluded for the same reason: it
# describes the gaps in prose.
$excluded = @('docs/xways-api-coverage-map.md', 'CHANGELOG.md')

$pages = @(
    'https://www.x-ways.net/forensics/x-tensions/XT_functions.html',
    'https://www.x-ways.net/forensics/x-tensions/XWF_functions.html'
)

$text = ''
foreach ($u in $pages) {
    Write-Host "fetching $u"
    $html = (Invoke-WebRequest -Uri $u -UseBasicParsing).Content
    $html = [regex]::Replace($html, '(?is)<(script|style)[^>]*>.*?</\1>', ' ')
    $text += ([regex]::Replace($html, '<[^>]+>', ' ')) + "`n"
}

# A function is a symbol immediately followed by "(" in the reference text.
$funcs = [System.Collections.Generic.HashSet[string]]::new()
foreach ($m in [regex]::Matches($text, '\b(XWF_[A-Za-z0-9_]+|XT_[A-Za-z0-9_]+)\s*\(')) {
    $n = $m.Groups[1].Value
    # Flag/constant families are not functions even when they appear in expressions.
    if ($n -notmatch '^(XT_PREPARE_|XT_INIT_|XT_ACTION_|XWF_SEARCH_|XWF_CTR_|XWF_ITEM_INFO_|XWF_VSPROP_|XWF_CASEPROP_)') {
        [void]$funcs.Add($n)
    }
}

# --others --exclude-standard includes new, not-yet-committed files. Without it
# a doc written moments ago is invisible and the map under-reports coverage --
# which is precisely when someone runs this.
$tracked = @(& git -C $Root ls-files --cached --others --exclude-standard) |
           Sort-Object -Unique |
           Where-Object { $excluded -notcontains $_ }
$bodies = @{}
foreach ($rel in $tracked) {
    $p = Join-Path $Root $rel
    if (Test-Path $p) { $bodies[$rel] = (Get-Content -LiteralPath $p -Raw -ErrorAction SilentlyContinue) }
}

$covered = [System.Collections.Generic.List[string]]::new()
$mentioned = [System.Collections.Generic.List[string]]::new()
$absent = [System.Collections.Generic.List[string]]::new()

foreach ($f in ($funcs | Sort-Object)) {
    $rx = [regex]"\b$([regex]::Escape($f))\b"
    $anywhere = $false
    $explained = $false
    foreach ($rel in $bodies.Keys) {
        $body = $bodies[$rel]
        if (-not $body) { continue }
        $hits = $rx.Matches($body).Count
        if ($hits -gt 0) {
            $anywhere = $true
            if ($rel -like 'docs/*' -and $hits -ge 2) { $explained = $true; break }
        }
    }
    if     ($explained) { $covered.Add($f) }
    elseif ($anywhere)  { $mentioned.Add($f) }
    else                { $absent.Add($f) }
}

Write-Host ""
Write-Host "officially documented functions: $($funcs.Count)"
Write-Host ("  covered   {0,3}" -f $covered.Count) -ForegroundColor Green
Write-Host ("  mentioned {0,3}" -f $mentioned.Count) -ForegroundColor Yellow
Write-Host ("  absent    {0,3}" -f $absent.Count) -ForegroundColor Red

if ($Detail) {
    foreach ($pair in @(@('absent', $absent), @('mentioned', $mentioned))) {
        Write-Host "`n=== $($pair[0]) ==="
        $pair[1] | ForEach-Object { Write-Host "  $_" }
    }
}

Write-Host "`nUpdate docs/xways-api-coverage-map.md (and its last_updated) if these differ."
exit 0
