# check-template-parity.ps1 — the shared conventions must exist in ALL templates.
#
# Why this gate exists: five consecutive template commits in 2026-08 were each
# "apply the same fix to all three templates", and the 2026-08-16 review still
# found four drifts (a guard present in one template and absent in another, a
# constant fixed in two of three). Convention parity is exactly the class of
# regression a grep gate catches for free.
#
# Each check names a regex per template kind. A template missing its marker
# fails the gate. Checks that legitimately apply to a subset (e.g. C++-only
# resolution guards) list only those templates.

$ErrorActionPreference = 'Stop'
$Root = Split-Path $PSScriptRoot -Parent

$templates = @{
    cpp     = Join-Path $Root 'templates\x-tensions\cpp\my_xtension.cpp'
    wrapper = Join-Path $Root 'templates\x-tensions\wrapper\my_xtension.cpp'
    python  = Join-Path $Root 'templates\x-tensions\python\xtension.py'
}

$checks = @(
    @{
        Name    = 'XT_INIT_QUICKCHECK guard (0x20) answers before any side effect'
        Pattern = @{
            cpp     = 'if \(nFlags & 0x20\) return \(missing > 0\) \? -1 : 1;'
            wrapper = 'if \(nFlags & 0x20\) return \(missing > 0\) \? -1 : 1;'
            python  = 'if nFlags & 0x20:'
        }
    }
    @{
        Name    = 'packed nVersion decode (version*10 hi16 / SR byte1)'
        Pattern = @{
            cpp     = '\(nVersion >> 16\) & 0xFFFF'
            wrapper = '\(nVersion >> 16\) & 0xFFFF'
            python  = '\(nVersion >> 16\) & 0xFFFF'
        }
    }
    @{
        Name    = 'op=0 delivers no per-item callbacks — warning present'
        Pattern = @{
            cpp     = '(?i)no per-item callbacks'
            wrapper = '(?i)no per-item callbacks'
            python  = '(?i)no per-item callbacks'
        }
    }
    @{
        Name    = 'AddComment mode constants (2 = append-with-line-break)'
        Pattern = @{
            cpp     = 'COMMENT_APPEND_LINEBREAK'
            wrapper = 'COMMENT_APPEND_LINEBREAK'
            python  = 'COMMENT_APPEND_LINEBREAK'
        }
    }
    @{
        Name    = 'no-prepend-mode note on the AddComment constants'
        Pattern = @{
            cpp     = 'NO prepend mode'
            wrapper = 'NO prepend mode'
            python  = 'NO prepend mode'
        }
    }
)

$failures = @()
foreach ($check in $checks) {
    foreach ($kind in $check.Pattern.Keys) {
        $path = $templates[$kind]
        if (-not (Test-Path $path)) {
            $failures += "MISSING TEMPLATE FILE: $path"
            continue
        }
        $text = [System.IO.File]::ReadAllText($path)
        if ($text -notmatch $check.Pattern[$kind]) {
            $failures += "[$kind] missing: $($check.Name)"
        }
    }
}

if ($failures.Count -eq 0) {
    Write-Host "RESULT: PASS - all $($checks.Count) shared conventions present in all templates" -ForegroundColor Green
    exit 0
}
Write-Host "TEMPLATE PARITY FAILURES ($($failures.Count)):" -ForegroundColor Red
$failures | ForEach-Object { Write-Host "  $_" -ForegroundColor Red }
Write-Host "RESULT: FAIL" -ForegroundColor Red
exit 1
