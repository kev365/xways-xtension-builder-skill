<#
.SYNOPSIS
    Regression test: scaffolding must patch every user-visible identity string,
    and -DryRun must not promise replacements that cannot happen.

.DESCRIPTION
    Scope is runtime-visible strings only — dialog captions, the About title,
    the report-table name, and the manager tab caption. Author-facing TODO
    placeholders are deliberately NOT asserted on:

      - the header-banner comment at the top of the .cpp
      - the PUSHBUTTON URL https://github.com/youruser/my_xtension

    Both are placeholders the author is expected to rewrite, and neither affects
    what an analyst sees at runtime.

    Three defects this covers:
      1. .rc CAPTION was matched with the literal
         'CAPTION "My X-Tension - Settings"'. The wrapper template actually
         reads 'CAPTION "my_xtension - Settings"', so it never matched and every
         scaffolded wrapper shipped a dialog titled "my_xtension - Settings".
         The About caption and About title were not handled at all.
      2. REPORT_TABLE was only patched for the plain cpp template. The wrapper
         has the constant too, so scaffolded wrappers kept
         L"my_xtension: hits" as the analyst-visible report-table name.
      3. -DryRun listed every generated rule without testing whether its pattern
         matched the source, so it reported 9 replacements where 5 applied.
         A preview that overstates is worse than none, because -DryRun is a
         hard gate in the skill.

.EXAMPLE
    pwsh -File tests/test-scaffold-identity.ps1
#>
[CmdletBinding()]
param(
    [string]$SkillRoot = (Split-Path $PSScriptRoot -Parent)
)

$ErrorActionPreference = 'Stop'
$script:fail = 0
$script:pass = 0

function Assert-NotInTree {
    param([string]$Dir, [string]$Needle, [string]$Why)
    $hits = Get-ChildItem $Dir -File -Recurse |
            Select-String -Pattern $Needle -SimpleMatch -ErrorAction SilentlyContinue
    if ($hits) {
        Write-Host "  FAIL  leftover '$Needle' -- $Why" -ForegroundColor Red
        $hits | ForEach-Object { Write-Host "          $($_.Filename):$($_.LineNumber)" -ForegroundColor DarkGray }
        $script:fail++
    } else {
        Write-Host "  PASS  no leftover '$Needle'" -ForegroundColor Green
        $script:pass++
    }
}

function Assert-InTree {
    param([string]$Dir, [string]$Needle)
    $hits = Get-ChildItem $Dir -File -Recurse |
            Select-String -Pattern $Needle -SimpleMatch -ErrorAction SilentlyContinue
    if ($hits) {
        Write-Host "  PASS  patched in: '$Needle'" -ForegroundColor Green
        $script:pass++
    } else {
        Write-Host "  FAIL  expected '$Needle' somewhere in the scaffold" -ForegroundColor Red
        $script:fail++
    }
}

$scaffold = Join-Path $SkillRoot 'scripts\new-xtension.ps1'
if (-not (Test-Path $scaffold)) { throw "new-xtension.ps1 not found at $scaffold" }

$root = Join-Path ([System.IO.Path]::GetTempPath()) ("identity-test-" + [guid]::NewGuid().ToString('N').Substring(0, 8))
New-Item -ItemType Directory -Force $root | Out-Null

# Template-identity strings that must never survive scaffolding, per template.
$cases = @(
    @{ Template = 'wrapper'; Name = 'idwrap'; Title = 'Idwrap'
       Reject = @(
         @{ S = 'my_xtension - Settings';  W = '.rc settings-dialog CAPTION' }
         @{ S = 'About my_xtension';       W = '.rc about-dialog CAPTION' }
         @{ S = 'my_xtension: hits';       W = 'REPORT_TABLE constant' }
         @{ S = 'L"My X-Tension"';         W = 'descriptor display_name' }
       )
       Expect = @('CAPTION "Idwrap - Settings"', 'CAPTION "About Idwrap"') }

    @{ Template = 'xtmgr';   Name = 'idmgr';  Title = 'Idmgr'
       Reject = @(
         @{ S = 'My X-Tension - Settings';        W = '.rc settings-dialog CAPTION' }
         @{ S = 'L"my_xtension"';                 W = 'descriptor id' }
         @{ S = 'L"My X-Tension"';                W = 'descriptor display_name' }
         @{ S = 'L"Template X-Tension. Replace."'; W = 'descriptor description' }
       )
       Expect = @('CAPTION "Idmgr - Settings"') }

    @{ Template = 'cpp';     Name = 'idcpp';  Title = 'Idcpp'
       Reject = @(
         @{ S = 'L"Template Findings"'; W = 'REPORT_TABLE constant' }
       )
       Expect = @() }
)

try {
    foreach ($c in $cases) {
        Write-Host "`n=== template: $($c.Template) ===" -ForegroundColor Cyan
        $proj = Join-Path $root $c.Template
        New-Item -ItemType Directory -Force $proj | Out-Null

        # (3) -DryRun must promise exactly what execute applies. Counting both
        #     sides catches an over-promising preview, which is the actual
        #     defect: the plan listed rules without testing their patterns.
        $dry = (& $scaffold -Name $c.Name -Template $c.Template -DestRoot $proj -DryRun *>&1 |
                Out-String)
        $promised = ([regex]::Matches($dry, '(?m)^\s*\[DRY\]\s+REPLACE\s')).Count

        $exec = (& $scaffold -Name $c.Name -Template $c.Template -DestRoot $proj *>&1 | Out-String)
        $applied = ([regex]::Matches($exec, '(?m)^\s*Replace\s+\[')).Count

        if ($promised -eq $applied) {
            Write-Host "  PASS  -DryRun promised $promised, execute applied $applied" -ForegroundColor Green
            $script:pass++
        } else {
            Write-Host "  FAIL  -DryRun promised $promised but execute applied $applied" -ForegroundColor Red
            $script:fail++
        }
        $out = Join-Path $proj "x-tensions\xways-$($c.Name)"
        if (-not (Test-Path $out)) {
            Write-Host "  FAIL  scaffold produced nothing at $out" -ForegroundColor Red
            $script:fail++
            continue
        }

        foreach ($r in $c.Reject) { Assert-NotInTree -Dir $out -Needle $r.S -Why $r.W }
        foreach ($e in $c.Expect) { Assert-InTree    -Dir $out -Needle $e }
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
