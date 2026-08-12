<#
.SYNOPSIS
    A "Source of truth" line must cite symbols that actually exist.

.DESCRIPTION
    Convention pages end with a line of the form

        **Source of truth:** the `wrapper` template (`templates/.../x.cpp`) -> `A`, `B`

    which is the strongest claim in the knowledge base: it tells an author the
    named code is real and can be copied. An audit found five such lines citing
    symbols the template does not contain -- including wrapper-anatomy.md's
    entire struct vocabulary (`RunSettings`, `RunState`, `RunStats`), a tool
    resolver with a signature that never existed, and `RunCommand` being named
    as the source of the \NUL stdio pattern it did not implement.

    Nothing could catch those: the pages read perfectly, the paths resolved, and
    the symbols were plausible. Only executing the claim finds it.

    For every such line, each backticked token that is not itself a path must
    appear somewhere in at least one of the files the line names.

.EXAMPLE
    pwsh -File tests/check-cited-symbols.ps1
#>
[CmdletBinding()]
param(
    [string]$Root = (Split-Path $PSScriptRoot -Parent)
)

$ErrorActionPreference = 'Stop'

# Words that appear in a citation as prose, not as code identifiers.
$stopWords = @(
    'wrapper', 'cpp', 'python', 'template', 'handler', 'the', 'and',
    'declaration comment', 'function body'
)

# Both forms promise "this code is real and you can copy it".
#   **Source of truth:** the `wrapper` template (`path`) -> `A`, `B`
#   Extracted from the `wrapper` template (`path`) -> `A`, `B`
$sourceLine = [regex]'(?i)(?:\*\*Source of truth:\*\*|Extracted from)(.*)'
$backticked = [regex]'`([^`]+)`'
# A cited token is a path when it carries a known extension, or is a dotfile
# such as `.gitignore` (cited as a file to read, not as a symbol to find).
$pathLike   = [regex]'(?i)(\.(md|cpp|h|ps1|py|bat|rc|def|json|yml|yaml|tmpl|example)$)|(^\.[a-z]+$)'

$mdFiles = & git -C $Root ls-files '*.md'
if ($LASTEXITCODE -ne 0) { Write-Host 'ERROR: git ls-files failed' -ForegroundColor Red; exit 1 }

$problems = [System.Collections.Generic.List[psobject]]::new()
$claims = 0
$symbolsChecked = 0

foreach ($rel in $mdFiles) {
    $full = Join-Path $Root $rel
    if (-not (Test-Path $full)) { continue }
    $lines = @(Get-Content -LiteralPath $full)

    for ($i = 0; $i -lt $lines.Count; $i++) {
        $m = $sourceLine.Match($lines[$i])
        if (-not $m.Success) { continue }

        # The claim may wrap onto following lines; consume to the blank line.
        $text = $m.Groups[1].Value
        for ($j = $i + 1; $j -lt $lines.Count; $j++) {
            # Stop at a blank line, a heading, or the opening fence of the
            # code block the claim introduces -- the block's own contents are
            # not part of the claim.
            if ($lines[$j].Trim() -eq '' -or $lines[$j] -match '^#{1,6}\s' -or
                $lines[$j] -match '^[ \t]*(`{3,}|~{3,})') { break }
            $text += ' ' + $lines[$j]
        }

        $tokens = @($backticked.Matches($text) | ForEach-Object { $_.Groups[1].Value.Trim() })
        $paths   = @($tokens | Where-Object { $pathLike.IsMatch($_) })
        $symbols = @($tokens | Where-Object {
            -not $pathLike.IsMatch($_) -and ($stopWords -notcontains $_.ToLowerInvariant())
        })

        if ($paths.Count -eq 0 -or $symbols.Count -eq 0) { continue }

        # Load every cited file once.
        $corpus = ''
        $unreadable = @()
        foreach ($p in $paths) {
            $pf = Join-Path $Root $p
            if (Test-Path $pf) { $corpus += (Get-Content -LiteralPath $pf -Raw) }
            else { $unreadable += $p }
        }
        if ($corpus -eq '') { continue }   # cited-path gate covers missing files

        $claims++
        foreach ($s in $symbols) {
            $symbolsChecked++
            if (-not $corpus.Contains($s)) {
                $problems.Add([pscustomobject]@{
                    File = $rel; Line = $i + 1; Symbol = $s
                    Cited = ($paths -join ', ')
                })
            }
        }
    }
}

Write-Host "Checked $symbolsChecked symbol(s) across $claims 'Source of truth' claim(s)."

if ($problems.Count -eq 0) {
    Write-Host "RESULT: PASS - every cited symbol exists in the file it is cited from" -ForegroundColor Green
    exit 0
}

Write-Host "`nCITED SYMBOLS THAT DO NOT EXIST ($($problems.Count)):" -ForegroundColor Red
foreach ($g in ($problems | Group-Object File)) {
    Write-Host "  $($g.Name)" -ForegroundColor Red
    foreach ($p in $g.Group) {
        Write-Host "    line $($p.Line): ``$($p.Symbol)`` not found in $($p.Cited)" -ForegroundColor DarkGray
    }
}
Write-Host "`nRESULT: FAIL" -ForegroundColor Red
exit 1
