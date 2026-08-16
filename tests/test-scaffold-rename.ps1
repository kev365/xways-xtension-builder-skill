<#
.SYNOPSIS
    Regression test: new-xtension.ps1 renames every file whose leading name
    segment matches the template stem — including multi-dot filenames.

.DESCRIPTION
    Sidecar filenames are load-bearing, not cosmetic:

      wrapper my_xtension.cpp   reads  GetSelfDirectory() + NAME + L".cfg"
      python  xtension.py       reads  f"{NAME}.config.json"

    NAME is patched to xways-<name> during scaffolding, so a sidecar left at its
    template name is one the scaffolded code will never find at runtime.

    The original defect: Get-DestRelPath used
    [Path]::GetFileNameWithoutExtension, which strips only the FINAL extension.
    'my_xtension.cfg.example' therefore yielded base 'my_xtension.cfg', which
    never equalled the stem 'my_xtension', and the rename was skipped in silence.

    Run from anywhere; the skill root is derived from this script's location.

.EXAMPLE
    pwsh -File tests/test-scaffold-rename.ps1
#>
[CmdletBinding()]
param(
    # Skill root (the repo root). Defaults to this script's parent directory.
    [string]$SkillRoot = (Split-Path $PSScriptRoot -Parent)
)

$ErrorActionPreference = 'Stop'
$script:fail = 0
$script:pass = 0

function Assert-File {
    param([string]$Dir, [string]$Expected)
    if (Test-Path (Join-Path $Dir $Expected)) {
        Write-Host "  PASS  $Expected" -ForegroundColor Green
        $script:pass++
    } else {
        Write-Host "  FAIL  $Expected -- stem rename missed this file" -ForegroundColor Red
        Write-Host "        present instead:" -ForegroundColor DarkGray
        Get-ChildItem $Dir -File | ForEach-Object { Write-Host "          $($_.Name)" -ForegroundColor DarkGray }
        $script:fail++
    }
}

function Assert-NoFile {
    param([string]$Dir, [string]$Unexpected)
    if (Test-Path (Join-Path $Dir $Unexpected)) {
        Write-Host "  FAIL  $Unexpected should not exist (template name leaked through)" -ForegroundColor Red
        $script:fail++
    } else {
        Write-Host "  PASS  no leftover $Unexpected" -ForegroundColor Green
        $script:pass++
    }
}

$scaffold = Join-Path $SkillRoot 'scripts\new-xtension.ps1'
if (-not (Test-Path $scaffold)) { throw "new-xtension.ps1 not found at $scaffold" }

$root = Join-Path ([System.IO.Path]::GetTempPath()) ("scaffold-test-" + [guid]::NewGuid().ToString('N').Substring(0, 8))
New-Item -ItemType Directory -Force $root | Out-Null

$cases = @(
    @{ Template = 'wrapper'; Name = 'wraptest'
       Expect = @('xways-wraptest.cpp', 'xways-wraptest.def', 'xways-wraptest.rc',
                  'xways-wraptest.cfg.example')
       Reject = @('my_xtension.cfg.example', 'my_xtension.cpp') }
    @{ Template = 'python';  Name = 'pytest'
       # Underscore stem: the bridge imports by file stem, so hyphens can never
       # load (import xways-pytest = syntax error). Folder keeps the hyphen.
       Expect = @('xways_pytest.py', 'xways_pytest.config.json')
       Reject = @('xways-pytest.py', 'xways-pytest.config.json',
                  'xtension_template.config.json', 'xtension.config.json', 'xtension.py') }
    @{ Template = 'cpp';     Name = 'cpptest'
       Expect = @('xways-cpptest.cpp', 'xways-cpptest.def')
       Reject = @('my_xtension.cpp') }
)

try {
    foreach ($c in $cases) {
        Write-Host "`n=== template: $($c.Template) ===" -ForegroundColor Cyan
        $proj = Join-Path $root $c.Template
        New-Item -ItemType Directory -Force $proj | Out-Null

        & $scaffold -Name $c.Name -Template $c.Template -DestRoot $proj *>$null

        $out = Join-Path $proj "x-tensions\xways-$($c.Name)"
        if (-not (Test-Path $out)) {
            Write-Host "  FAIL  scaffold produced nothing at $out" -ForegroundColor Red
            $script:fail++
            continue
        }
        foreach ($e in $c.Expect) { Assert-File   -Dir $out -Expected   $e }
        foreach ($r in $c.Reject) { Assert-NoFile -Dir $out -Unexpected $r }
    }
} finally {
    if (Test-Path $root) { Remove-Item -Recurse -Force $root -ErrorAction SilentlyContinue }
}

Write-Host "`n--------------------------------" -ForegroundColor Cyan
Write-Host "passed: $script:pass   failed: $script:fail"
if ($script:fail -gt 0) {
    Write-Host "RESULT: FAIL" -ForegroundColor Red
    exit 1
}
Write-Host "RESULT: PASS" -ForegroundColor Green
exit 0
