<#
.SYNOPSIS
    Measure how often the skill's description causes the skill to be consulted.

.DESCRIPTION
    A Windows-native re-implementation of the methodology in skill-creator's
    scripts/run_eval.py, which cannot run here: it launches the CLI with
    subprocess and shell=False, so CreateProcess only ever looks for claude.exe
    and never finds the npm-installed claude.ps1 / claude.cmd, and it polls the
    child pipe with select.select(), which on Windows accepts sockets only.
    Both are POSIX assumptions rather than bugs.

    Method, mirroring the original so numbers stay comparable:

      1. Write a throwaway command file carrying ONLY the skill's name and
         description into a scratch project, so the description is what Claude
         sees when deciding whether this capability is relevant. The skill body
         is deliberately not present — the description alone is under test.
      2. Run `claude -p "<query>"` in that project with stream-json output.
      3. Count the query as triggered if the Skill tool fires for that name.
      4. Repeat -RunsPerQuery times; a query passes when its trigger rate lands
         on the correct side of -TriggerThreshold for its should_trigger flag.

.PARAMETER Filter
    Substring match on the query text. Use it to smoke-test the harness on one
    or two cases before paying for a full run.

.EXAMPLE
    pwsh -File evals/run-trigger-eval.ps1 -RunsPerQuery 3

.EXAMPLE
    pwsh -File evals/run-trigger-eval.ps1 -Filter "trufflehog" -RunsPerQuery 1 -Verbose
#>
[CmdletBinding()]
param(
    [string]$EvalSet        = (Join-Path $PSScriptRoot 'trigger-eval.json'),
    [string]$SkillPath      = (Split-Path $PSScriptRoot -Parent),
    [int]$RunsPerQuery      = 3,
    [double]$TriggerThreshold = 0.5,
    [string]$Model,
    [string]$Filter,
    [int]$TimeoutSec        = 120,
    [string]$JsonOut
)

$ErrorActionPreference = 'Stop'

# --- read the skill's identity from its frontmatter -------------------------
$skillMd = Join-Path $SkillPath 'SKILL.md'
if (-not (Test-Path $skillMd)) { throw "No SKILL.md at $SkillPath" }

$lines = Get-Content $skillMd
$end = -1
for ($i = 1; $i -lt $lines.Count; $i++) { if ($lines[$i].Trim() -eq '---') { $end = $i; break } }
if ($end -lt 0) { throw 'SKILL.md frontmatter is not terminated' }

$skillName = $null; $skillDesc = $null
foreach ($l in $lines[1..($end - 1)]) {
    if ($l -match '^name:\s*(.+)$')        { $skillName = $Matches[1].Trim() }
    elseif ($l -match '^description:\s*(.+)$') { $skillDesc = $Matches[1].Trim() }
}
if (-not $skillName -or -not $skillDesc) { throw 'Could not read name/description from SKILL.md' }

$cases = Get-Content $EvalSet -Raw | ConvertFrom-Json
if ($Filter) { $cases = @($cases | Where-Object { $_.query -like "*$Filter*" }) }
if (-not $cases -or $cases.Count -eq 0) { throw 'No eval cases selected' }

Write-Host "skill      : $skillName"
Write-Host "description: $($skillDesc.Length) chars"
Write-Host "cases      : $($cases.Count) x $RunsPerQuery run(s)"

# Precondition: the skill must be visible to `claude -p`, or every case scores
# 0 and the run looks like catastrophic under-triggering rather than a setup
# error. This is the failure that made the upstream runner report 10/20.
if (-not (Test-Path (Join-Path $env:USERPROFILE ".claude\skills\$skillName"))) {
    Write-Host ""
    Write-Host "WARNING: ~/.claude/skills/$skillName not found." -ForegroundColor Yellow
    Write-Host "         This measures the INSTALLED skill. If it is not installed (junction" -ForegroundColor Yellow
    Write-Host "         or plugin), every case will score 0 and the result is meaningless." -ForegroundColor Yellow
}
Write-Host ""

# --- scratch project --------------------------------------------------------
# Empty on purpose. The skill must be INSTALLED for this to measure anything —
# junctioned into ~/.claude/skills/<name>, or installed as a plugin.
#
# The upstream runner instead writes a throwaway command file carrying just the
# description, to stand in for an uninstalled skill. That indirection does not
# work here: with the skill installed, the probe never registers (it is absent
# from the system/init skills list) while the real skill is in scope for every
# run, so the probe measures nothing and the real skill answers the query.
#
# Measuring the installed skill is sound, and is what the description is
# actually judged on: only `name` and `description` are pre-loaded into the
# system prompt, and the body is read only after the skill triggers. Competing
# skills in the environment are part of the measurement, which is realistic —
# the Autopsy near-miss correctly loses to superpowers:brainstorming.
$proj = Join-Path ([System.IO.Path]::GetTempPath()) ("trigeval-" + [guid]::NewGuid().ToString('N').Substring(0, 8))
New-Item -ItemType Directory -Force $proj | Out-Null

# `claude -p` refuses to nest inside a Claude Code session unless this is clear.
$hadClaudeCode = Test-Path env:CLAUDECODE
$savedClaudeCode = if ($hadClaudeCode) { $env:CLAUDECODE } else { $null }
Remove-Item env:CLAUDECODE -ErrorAction SilentlyContinue

function Test-SkillFired {
    param([string]$Text, [string]$Name)
    foreach ($line in ($Text -split "`n")) {
        $l = $line.Trim()
        if (-not $l.StartsWith('{')) { continue }
        try { $d = $l | ConvertFrom-Json } catch { continue }
        if ($d.type -ne 'assistant') { continue }
        foreach ($b in @($d.message.content)) {
            if ($b.type -eq 'tool_use' -and $b.name -eq 'Skill') {
                $named = [string]$b.input.skill
                if (-not $named) { $named = [string]$b.input.command }
                # Tolerate a plugin namespace prefix ("plugin:skill").
                if (($named -eq $Name) -or ($named -like "*:$Name")) { return $true }
            }
        }
    }
    return $false
}

function Invoke-One {
    param([string]$Query)
    # Not $args — that is a PowerShell automatic variable.
    $cliArgs = @('-p', $Query, '--output-format', 'stream-json', '--verbose')
    if ($Model) { $cliArgs += @('--model', $Model) }

    # Stream to a file and stop as soon as the skill fires. Waiting for the run
    # to finish is both slow and unreliable: a query that DOES trigger goes on
    # to read reference files and can reach AskUserQuestion, so it may outlive
    # any sane timeout — and a timeout would then be scored as "did not
    # trigger", inverting the result for exactly the cases that pass.
    $tmp = Join-Path $proj ("run-" + [guid]::NewGuid().ToString('N').Substring(0, 8) + '.jsonl')
    $job = Start-Job -ScriptBlock {
        param($cwd, $a, $f)
        Set-Location $cwd
        & claude @a *> $f
    } -ArgumentList $proj, $cliArgs, $tmp

    $fired = $false
    $deadline = (Get-Date).AddSeconds($TimeoutSec)
    while ((Get-Date) -lt $deadline) {
        if (Test-Path $tmp) {
            $txt = Get-Content $tmp -Raw -ErrorAction SilentlyContinue
            if ($txt -and (Test-SkillFired -Text $txt -Name $skillName)) { $fired = $true; break }
        }
        if ($job.State -ne 'Running') { break }
        Start-Sleep -Milliseconds 400
    }

    $ranToCompletion = ($job.State -ne 'Running')
    Stop-Job $job -ErrorAction SilentlyContinue
    Remove-Job $job -Force -ErrorAction SilentlyContinue

    $final = if (Test-Path $tmp) { Get-Content $tmp -Raw -ErrorAction SilentlyContinue } else { $null }
    Remove-Item $tmp -Force -ErrorAction SilentlyContinue

    if ($fired) { return $true }
    # Only a completed run that never fired counts as a genuine non-trigger.
    # Anything else is unmeasured.
    if ($ranToCompletion -and $final) { return (Test-SkillFired -Text $final -Name $skillName) }
    return $null
}

$results = @()
$harnessFailures = 0
try {
    foreach ($c in $cases) {
        $trig = 0; $valid = 0
        for ($r = 0; $r -lt $RunsPerQuery; $r++) {
            $t = Invoke-One -Query $c.query
            if ($null -eq $t) { $harnessFailures++; continue }
            $valid++
            if ($t) { $trig++ }
        }
        $rate = if ($valid -gt 0) { [math]::Round($trig / $valid, 3) } else { [double]::NaN }
        $pass = if ($valid -eq 0) { $false }
                elseif ($c.should_trigger) { $rate -ge $TriggerThreshold }
                else { $rate -lt $TriggerThreshold }

        $tag = if ($valid -eq 0) { 'NO DATA' } elseif ($pass) { 'pass' } else { 'FAIL' }
        $col = if ($valid -eq 0) { 'Yellow' } elseif ($pass) { 'Green' } else { 'Red' }
        Write-Host ("  [{0,-7}] rate={1,-5} want={2,-5}  {3}" -f $tag, $rate, $c.should_trigger, $c.query.Substring(0, [Math]::Min(58, $c.query.Length))) -ForegroundColor $col

        $results += [pscustomobject]@{
            query = $c.query; should_trigger = $c.should_trigger
            trigger_rate = $rate; triggers = $trig; valid_runs = $valid; pass = $pass
            note = $c.note
        }
    }
} finally {
    if ($hadClaudeCode) { $env:CLAUDECODE = $savedClaudeCode }
    Remove-Item -Recurse -Force $proj -ErrorAction SilentlyContinue
}

$passed = @($results | Where-Object pass).Count
$noData = @($results | Where-Object { $_.valid_runs -eq 0 }).Count

Write-Host "`n--------------------------------"
Write-Host "passed $passed / $($results.Count)"
if ($harnessFailures -gt 0) {
    Write-Host "harness failures: $harnessFailures run(s) produced no output — treat any NO DATA row as unmeasured, NOT as a non-trigger." -ForegroundColor Yellow
}

if ($JsonOut) {
    [pscustomobject]@{
        skill = $skillName; description = $skillDesc
        runs_per_query = $RunsPerQuery; threshold = $TriggerThreshold
        harness_failures = $harnessFailures
        results = $results
        summary = @{ total = $results.Count; passed = $passed; no_data = $noData }
    } | ConvertTo-Json -Depth 6 | Set-Content $JsonOut -Encoding utf8
    Write-Host "wrote $JsonOut"
}

if ($noData -gt 0) { exit 2 }
if ($passed -lt $results.Count) { exit 1 }
exit 0
