<#
.SYNOPSIS
    Verify every relative markdown link in the repo resolves to a real file.

.DESCRIPTION
    The skill's whole layout depends on relative paths resolving from SKILL.md,
    so a dangling link is a functional defect, not a typo. This has already
    caught four real breaks: two left behind by the .claude/skills -> repo-root
    move, and two in docs/ pointing at the old skill path.

    Code is not prose. Links inside fenced code blocks and inside inline code
    spans are skipped, because they are literal text rather than links. That is
    not an exemption bolted on to silence a false positive — it is the correct
    reading of markdown. It matters here: docs/conventions/readme-roadmap.md
    documents the line a generated X-Tension README should contain, written as

        11. `## License` - `Released under the MIT License. See [LICENSE](LICENSE).`

    That [LICENSE](LICENSE) is sample text for a file that will live in a
    different directory. Treating it as a live link reports a break that does
    not exist.

    External links (http/https/mailto) and pure anchors are not checked.

.EXAMPLE
    pwsh -File tests/check-links.ps1
#>
[CmdletBinding()]
param(
    [string]$Root = (Split-Path $PSScriptRoot -Parent)
)

$ErrorActionPreference = 'Stop'

# Directories that hold no authored markdown.
$skipDirs = @('.git', 'site', 'node_modules')

function Remove-CodeSpans {
    param([string]$Text)
    # Fenced blocks first (``` or ~~~), then inline spans (``…`` and `…`).
    $t = [regex]::Replace($Text, '(?ms)^[ \t]*(`{3,}|~{3,}).*?^[ \t]*\1[ \t]*$', '')
    $t = [regex]::Replace($t, '``[^`]*``', '')
    $t = [regex]::Replace($t, '`[^`\n]*`', '')
    return $t
}

$broken = [System.Collections.Generic.List[string]]::new()
$checked = 0
$files = 0

Get-ChildItem $Root -Recurse -File -Filter '*.md' | Where-Object {
    $rel = $_.FullName.Substring($Root.Length).TrimStart('\', '/')
    $first = ($rel -split '[\\/]')[0]
    $skipDirs -notcontains $first
} | ForEach-Object {
    $files++
    $text = Remove-CodeSpans (Get-Content $_.FullName -Raw)
    $dir  = $_.DirectoryName

    foreach ($m in [regex]::Matches($text, '\[[^\]]*\]\(([^)\s]+)\)')) {
        $target = $m.Groups[1].Value
        if ($target -match '^(https?:|mailto:|#)') { continue }
        $path = ($target -split '#')[0]
        if (-not $path) { continue }
        $checked++

        $resolved = [System.IO.Path]::GetFullPath((Join-Path $dir $path))
        if (-not (Test-Path $resolved)) {
            $rel = $_.FullName.Substring($Root.Length).TrimStart('\', '/')
            $broken.Add("  $rel  ->  $target")
        }
    }
}

Write-Host "scanned $files markdown files, checked $checked relative links"

if ($broken.Count -gt 0) {
    Write-Host "`nBROKEN LINKS ($($broken.Count)):" -ForegroundColor Red
    $broken | ForEach-Object { Write-Host $_ -ForegroundColor Red }
    Write-Host "`nRESULT: FAIL" -ForegroundColor Red
    exit 1
}

Write-Host "RESULT: PASS - every relative link resolves" -ForegroundColor Green
exit 0
