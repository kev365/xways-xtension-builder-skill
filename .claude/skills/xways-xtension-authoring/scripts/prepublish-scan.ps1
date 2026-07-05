<#
.SYNOPSIS
    Pre-publish hygiene scan for the X-Ways X-Tensions repo (read-only).

.DESCRIPTION
    Scans git-TRACKED files for things that must not ship in a public repo and
    operationalises docs/conventions/repo-hygiene.md. Read-only — never writes.

    HIGH-severity (drive the exit code):
      * local filesystem paths   (X:\Users\<name>\...)
      * tracked binaries         (*.dll, *.exe, *.obj, *.lib, *.exp, *.pdb)
      * tracked case data        (anything under case/)

    REVIEW advisories (printed, but do not fail unless -Strict):
      * credential-ish assignments   (password=, token:, api_key=, ...)
      * email addresses

    Exit code: 0 = no HIGH findings; 1 = HIGH findings (or any finding with
    -Strict); 2 = not a git repo.

.PARAMETER Strict
    Also fail (exit 1) on REVIEW advisories.

.EXAMPLE
    .\prepublish-scan.ps1
    .\prepublish-scan.ps1 -Strict
#>
[CmdletBinding()]
param([switch]$Strict)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# scripts/ -> xways-xtension-authoring/ -> skills/ -> .claude/ -> repo root
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..\..')).Path

Push-Location $repoRoot
try { $tracked = @(git ls-files) } finally { Pop-Location }
if (-not $tracked -or $tracked.Count -eq 0) {
    Write-Error 'No tracked files found — is this a git repository?'
    exit 2
}

# Extensions worth scanning for content (skip binaries).
$textExt = @('.md','.markdown','.txt','.cpp','.cc','.cxx','.h','.hpp','.rc','.def',
             '.bat','.cmd','.ps1','.psm1','.py','.json','.yml','.yaml','.toml','.ini',
             '.cfg','.example','.tmpl','.c','.rs','.cs','.tpl','.csv','.tsv','.xml','.html')

$high   = [System.Collections.Generic.List[string]]::new()
$review = [System.Collections.Generic.List[string]]::new()

# --- HIGH: tracked binaries
foreach ($b in ($tracked | Where-Object { $_ -match '\.(dll|exe|obj|lib|exp|pdb|pdf)$' })) {
    $high.Add("BINARY    $b")
}
# --- HIGH: tracked case data
foreach ($c in ($tracked | Where-Object { $_ -match '^case/' })) {
    $high.Add("CASEDATA  $c")
}
# --- HIGH: copyrighted X-Ways SDK / manuals (must never ship; acquire your own
#     per docs/getting-the-sdk.md)
$sdkRe = '(?i)(^|/)references/(api|books|templates)/|(^|/)(X-Tension\.h|XT_API\.pas)$'
foreach ($s in ($tracked | Where-Object { $_ -match $sdkRe })) {
    $high.Add("XW-SDK    $s")
}

# --- content scans (text files only)
#   PATH   : real drive-letter user paths (placeholders like C:\Users\<you> won't match)
#   SECRET : keyword followed by an assignment + value (prose won't match)
#   EMAIL  : standard address shape
$pathRe   = '[A-Za-z]:\\Users\\[A-Za-z0-9._-]+'
$secretRe = '(?i)(password|passwd|secret|token|api[_-]?key|apikey)\s*[:=]\s*\S'
$emailRe  = '[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}'

foreach ($rel in $tracked) {
    $ext = [System.IO.Path]::GetExtension($rel).ToLower()
    if ($textExt -notcontains $ext) { continue }
    $full = Join-Path $repoRoot $rel
    if (-not (Test-Path -LiteralPath $full)) { continue }   # staged-deleted
    $lines = @(Get-Content -LiteralPath $full -ErrorAction SilentlyContinue)
    for ($i = 0; $i -lt $lines.Count; $i++) {
        $ln = $lines[$i]
        if ($ln -match $pathRe)   { $high.Add(  ('PATH      {0}:{1}: {2}' -f $rel, ($i+1), $Matches[0])) }
        if ($ln -match $secretRe) { $review.Add(('SECRET    {0}:{1}: {2}' -f $rel, ($i+1), $ln.Trim())) }
        if ($ln -match $emailRe)  { $review.Add(('EMAIL     {0}:{1}: {2}' -f $rel, ($i+1), $Matches[0])) }
    }
}

Write-Host ''
Write-Host 'prepublish-scan — X-Ways X-Tensions repo hygiene' -ForegroundColor Cyan
Write-Host "  repo: $repoRoot" -ForegroundColor Gray
Write-Host ''

if ($high.Count -eq 0) {
    Write-Host 'HIGH-severity: none' -ForegroundColor Green
} else {
    Write-Host "HIGH-severity findings ($($high.Count)):" -ForegroundColor Red
    $high | Sort-Object | ForEach-Object { Write-Host "  $_" -ForegroundColor Red }
}
Write-Host ''
if ($review.Count -eq 0) {
    Write-Host 'REVIEW advisories: none' -ForegroundColor Green
} else {
    Write-Host "REVIEW advisories ($($review.Count)) — confirm each is safe:" -ForegroundColor Yellow
    $review | Sort-Object | ForEach-Object { Write-Host "  $_" -ForegroundColor Yellow }
}
Write-Host ''

if (($high.Count -gt 0) -or ($Strict -and $review.Count -gt 0)) {
    Write-Host 'RESULT: findings present — resolve before publishing.' -ForegroundColor Red
    exit 1
}
Write-Host 'RESULT: clean (no high-severity findings).' -ForegroundColor Green
exit 0
