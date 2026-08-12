<#
.SYNOPSIS
    Repo-relative paths written as inline code must resolve.

.DESCRIPTION
    check-links.ps1 deliberately ignores inline code spans -- that is the
    correct reading of markdown, since `foo/bar.md` in backticks is not a link.
    The side effect is that a path written as code is checked by nothing at all,
    and the knowledge base cites paths that way constantly ("**Source of
    truth:** `assets/LICENSE.tmpl`").

    Three such citations survived the 0.5.0 move of the skill to the repo root,
    still pointing into `.claude/skills/xways-xtension-authoring/...`. They read
    perfectly well and no gate could see them.

    Scope is deliberately narrow to stay high-signal: only backticked strings
    that begin with a known top-level directory of this repo, contain no
    placeholder markers, and look like a path.

.EXAMPLE
    pwsh -File tests/check-cited-paths.ps1
#>
[CmdletBinding()]
param(
    [string]$Root = (Split-Path $PSScriptRoot -Parent)
)

$ErrorActionPreference = 'Stop'

# A changelog records paths that were deliberately deleted; a "Removed" entry
# naming a file that no longer exists is correct, not stale.
$excludedFiles = @('CHANGELOG.md')

# The X-Tension SDK tree lives in the *user's own* project and is never
# committed here (copyright X-Ways AG), so citing it is right even though it
# cannot resolve in this repo.
$allowedMissing = @('references/api/')

$topDirs = 'docs|references|scripts|templates|assets|tests|evals|commands|x-tensions|xwf-configs|\.claude|\.claude-plugin|\.github'
$candidate = [regex]"``($topDirs)/([A-Za-z0-9._/\-]+)``"

function Remove-Fences {
    # Paths inside fenced blocks are usually illustrative (a layout diagram, a
    # shell transcript), so only prose-level citations are checked.
    param([string[]]$Lines)
    $out = [System.Collections.Generic.List[string]]::new()
    $inFence = $false; $fence = $null
    foreach ($l in $Lines) {
        if ($l -match '^[ \t]*(`{3,}|~{3,})') {
            $tok = $Matches[1].Substring(0, 3)
            if (-not $inFence) { $inFence = $true; $fence = $tok }
            elseif ($tok -eq $fence) { $inFence = $false }
            $out.Add(''); continue
        }
        $out.Add($(if ($inFence) { '' } else { $l }))
    }
    return $out
}

$mdFiles = & git -C $Root ls-files '*.md'
if ($LASTEXITCODE -ne 0) { Write-Host 'ERROR: git ls-files failed' -ForegroundColor Red; exit 1 }

$missing = [System.Collections.Generic.List[psobject]]::new()
$checked = 0

foreach ($rel in $mdFiles) {
    if ($excludedFiles -contains $rel) { continue }
    $full = Join-Path $Root $rel
    if (-not (Test-Path $full)) { continue }

    $lines = Remove-Fences -Lines @(Get-Content -LiteralPath $full)
    for ($i = 0; $i -lt $lines.Count; $i++) {
        foreach ($m in $candidate.Matches($lines[$i])) {
            $p = $m.Groups[1].Value + '/' + $m.Groups[2].Value
            if ($p -match '[<>*]') { continue }          # placeholder, not a path
            $skip = $false
            foreach ($a in $allowedMissing) { if ($p.StartsWith($a)) { $skip = $true; break } }
            if ($skip) { continue }

            $checked++
            if (-not (Test-Path (Join-Path $Root $p))) {
                $missing.Add([pscustomobject]@{ File = $rel; Line = $i + 1; Path = $p })
            }
        }
    }
}

Write-Host "Checked $checked backticked repo-relative path citation(s)."

if ($missing.Count -eq 0) {
    Write-Host "RESULT: PASS - every cited path resolves" -ForegroundColor Green
    exit 0
}

Write-Host "`nCITED PATHS THAT DO NOT EXIST ($($missing.Count)):" -ForegroundColor Red
foreach ($m in $missing) {
    Write-Host "  $($m.File):$($m.Line)" -ForegroundColor Red
    Write-Host "    ``$($m.Path)``" -ForegroundColor DarkGray
}
Write-Host "`nRESULT: FAIL" -ForegroundColor Red
exit 1
