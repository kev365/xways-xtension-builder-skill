<#
.SYNOPSIS
    Run the behaviour scenarios and save raw transcripts for grading.

.DESCRIPTION
    behavior-eval.json asks what happens AFTER the skill loads. There is no
    automated judge and this script does not invent one: it generates evidence
    and leaves the verdict to a human (or to a separate grading pass that has
    not seen the changes under test).

    That split is deliberate. Whoever wrote the skill changes and the
    expected_behavior lists is the worst person to grade the result, so the
    objective half -- did the skill fire, which files were read, what was
    finally said -- is captured mechanically and written to disk, and the
    judgement half is left where it can be done honestly.

    Differences from run-trigger-eval.ps1, which measures something else:
      - Runs to completion. The trigger runner stops the moment the Skill tool
        fires, because that is all it needs; here the final answer IS the
        measurement.
      - One scratch project per scenario. `scaffold-dryrun-and-build-gate` may
        actually run the scaffold, and scenarios must not see each other's
        files.
      - Records the tool-use trace. Several assertions are about which
        reference got consulted ("Points at docs/conventions/..."), which is
        visible in the transcript rather than in the prose.

.PARAMETER TimeoutSec
    Per-scenario ceiling. These do real work -- read references, sometimes run
    the scaffold -- so the default is far larger than the trigger runner's.

.EXAMPLE
    pwsh -File evals/run-behavior-eval.ps1

.EXAMPLE
    pwsh -File evals/run-behavior-eval.ps1 -Filter subprocess -TimeoutSec 420
#>
[CmdletBinding()]
param(
    [string]$EvalSet   = (Join-Path $PSScriptRoot 'behavior-eval.json'),
    [string]$SkillPath = (Split-Path $PSScriptRoot -Parent),
    [string]$OutDir,
    [int]$TimeoutSec   = 420,
    [string]$Filter,
    [string]$Model
)

$ErrorActionPreference = 'Stop'

# --- skill identity ---------------------------------------------------------
$skillMd = Join-Path $SkillPath 'SKILL.md'
if (-not (Test-Path $skillMd)) { throw "No SKILL.md at $SkillPath" }
$lines = Get-Content $skillMd
$end = -1
for ($i = 1; $i -lt $lines.Count; $i++) { if ($lines[$i].Trim() -eq '---') { $end = $i; break } }
if ($end -lt 0) { throw 'SKILL.md frontmatter is not terminated' }
$skillName = ($lines[1..($end - 1)] | Where-Object { $_ -match '^name:\s*(.+)$' } |
              ForEach-Object { $Matches[1].Trim() } | Select-Object -First 1)
if (-not $skillName) { throw 'Could not read name from SKILL.md' }

$scenarios = Get-Content $EvalSet -Raw | ConvertFrom-Json
if ($Filter) { $scenarios = @($scenarios | Where-Object { $_.id -like "*$Filter*" }) }
if (-not $scenarios -or $scenarios.Count -eq 0) { throw 'No scenarios selected' }

if (-not $OutDir) {
    $OutDir = Join-Path $PSScriptRoot ('runs/behavior-' + (Get-Date -Format 'yyyyMMdd-HHmmss'))
}
New-Item -ItemType Directory -Force $OutDir | Out-Null

Write-Host "skill    : $skillName"
Write-Host "scenarios: $($scenarios.Count)"
Write-Host "timeout  : ${TimeoutSec}s each (running in parallel)"
Write-Host "output   : $OutDir"

# Same precondition as the trigger runner: this measures the INSTALLED skill.
if (-not (Test-Path (Join-Path $env:USERPROFILE ".claude\skills\$skillName"))) {
    Write-Host "`nWARNING: ~/.claude/skills/$skillName not found. Without the skill" -ForegroundColor Yellow
    Write-Host "         installed, these scenarios measure baseline Claude, not the skill." -ForegroundColor Yellow
}
Write-Host ""

# `claude -p` refuses to nest inside a Claude Code session unless this is clear.
$hadClaudeCode = Test-Path env:CLAUDECODE
$savedClaudeCode = if ($hadClaudeCode) { $env:CLAUDECODE } else { $null }
Remove-Item env:CLAUDECODE -ErrorAction SilentlyContinue

$jobs = @()
try {
    foreach ($s in $scenarios) {
        $proj = Join-Path $OutDir ("proj-" + $s.id)
        New-Item -ItemType Directory -Force $proj | Out-Null
        $raw = Join-Path $OutDir ($s.id + '.jsonl')

        $cliArgs = @('-p', $s.query, '--output-format', 'stream-json', '--verbose')
        if ($Model) { $cliArgs += @('--model', $Model) }

        $jobs += [pscustomobject]@{
            Id  = $s.id
            Raw = $raw
            Job = Start-Job -ScriptBlock {
                param($cwd, $a, $f)
                Set-Location $cwd
                & claude @a *> $f
            } -ArgumentList $proj, $cliArgs, $raw
        }
        Write-Host "  started $($s.id)"
    }

    Write-Host "`nwaiting..."
    $deadline = (Get-Date).AddSeconds($TimeoutSec)
    while ((Get-Date) -lt $deadline) {
        $running = @($jobs | Where-Object { $_.Job.State -eq 'Running' })
        if ($running.Count -eq 0) { break }
        Start-Sleep -Seconds 5
    }
    foreach ($j in $jobs) {
        if ($j.Job.State -eq 'Running') { Write-Host "  TIMEOUT $($j.Id)" -ForegroundColor Yellow }
        Stop-Job $j.Job -ErrorAction SilentlyContinue
        Remove-Job $j.Job -Force -ErrorAction SilentlyContinue
    }
} finally {
    if ($hadClaudeCode) { $env:CLAUDECODE = $savedClaudeCode }
}

# --- extract evidence from each transcript ----------------------------------
function Read-Transcript {
    param([string]$Path)
    $text = @(); $tools = @(); $skillFired = $false; $final = $null
    if (-not (Test-Path $Path)) { return $null }
    foreach ($line in (Get-Content $Path)) {
        $l = $line.Trim()
        if (-not $l.StartsWith('{')) { continue }
        try { $d = $l | ConvertFrom-Json } catch { continue }
        if ($d.type -eq 'result' -and $d.result) { $final = [string]$d.result }
        if ($d.type -ne 'assistant') { continue }
        foreach ($b in @($d.message.content)) {
            if ($b.type -eq 'text' -and $b.text) { $text += [string]$b.text }
            elseif ($b.type -eq 'tool_use') {
                $detail = $b.name
                if ($b.name -eq 'Skill') {
                    $n = [string]$b.input.skill; if (-not $n) { $n = [string]$b.input.command }
                    $detail = "Skill($n)"
                    if (($n -eq $skillName) -or ($n -like "*:$skillName")) { $skillFired = $true }
                } elseif ($b.input.file_path) {
                    $detail = "$($b.name)($($b.input.file_path))"
                } elseif ($b.input.command) {
                    $c = [string]$b.input.command
                    $detail = "$($b.name)($($c.Substring(0,[Math]::Min(70,$c.Length))))"
                }
                $tools += $detail
            }
        }
    }
    if (-not $final -and $text.Count) { $final = ($text -join "`n") }
    return [pscustomobject]@{ Final = $final; Tools = $tools; SkillFired = $skillFired }
}

Write-Host "`n---------------------------------------------------------------"
$summary = @()
foreach ($s in $scenarios) {
    $raw = Join-Path $OutDir ($s.id + '.jsonl')
    $t = Read-Transcript -Path $raw

    $status = if (-not $t -or -not $t.Final) { 'NO OUTPUT' }
              elseif (-not $t.SkillFired)    { 'no skill'  }
              else                           { 'ok'        }
    $col = switch ($status) { 'ok' { 'Green' } 'no skill' { 'Yellow' } default { 'Red' } }
    Write-Host ("  [{0,-9}] {1,-38} {2} tool call(s)" -f $status, $s.id, @($t.Tools).Count) -ForegroundColor $col

    # One readable file per scenario: the question asked, what the run did,
    # what it answered, and the checklist -- ungraded, on purpose.
    $md = @()
    $md += "# $($s.id)"
    $md += ""
    $md += "**Skill fired:** $(if ($t.SkillFired) {'yes'} else {'NO'})"
    $md += ""
    $md += "## Query"; $md += ""; $md += '```'; $md += $s.query; $md += '```'; $md += ""
    $md += "## Probes"; $md += ""; $md += $s.probes; $md += ""
    $md += "## Expected behaviour (ungraded)"; $md += ""
    foreach ($e in $s.expected_behavior) { $md += "- [ ] $e" }
    $md += ""
    $md += "## Tool calls"; $md += ""; $md += '```'
    if (@($t.Tools).Count) { $md += $t.Tools } else { $md += '(none)' }
    $md += '```'; $md += ""
    $md += "## Final answer"; $md += ""
    $md += $(if ($t -and $t.Final) { $t.Final } else { '_(no output captured)_' })
    $utf8 = [System.Text.UTF8Encoding]::new($false)
    [System.IO.File]::WriteAllText((Join-Path $OutDir ($s.id + '.md')), (($md -join "`n") + "`n"), $utf8)

    $summary += [pscustomobject]@{
        id = $s.id; skill_fired = $t.SkillFired; status = $status
        tool_calls = @($t.Tools).Count
    }
}

$summary | ConvertTo-Json -Depth 4 | Set-Content (Join-Path $OutDir 'summary.json') -Encoding utf8

$bad = @($summary | Where-Object { $_.status -ne 'ok' }).Count
Write-Host "`n$($scenarios.Count) scenario(s); $bad did not produce a usable skill-backed answer."
Write-Host "Transcripts + ungraded checklists: $OutDir"
Write-Host "Grading is deliberately NOT automated -- read the .md files." -ForegroundColor Cyan
if ($bad -gt 0) { exit 1 }
exit 0
