<#
.SYNOPSIS
    Build an X-Ways X-Tension DLL from its source directory.

.DESCRIPTION
    Locates <DestRoot>/x-tensions/xways-<name>/build.bat, ensures X-Ways is not
    running (the DLL would be locked), bootstraps the MSVC x64 toolchain if
    needed, runs the build, verifies the output DLL exists, and deploys the
    staged xtensions\<name>\ folder into YOUR X-Ways install. The install path is
    your own environment — pass -DeployRoot '<install-root>' once (it's remembered
    in .xtension-deploy.local, git-ignored), or set $env:XWT_DEPLOY_ROOT. With
    neither set, the build still succeeds and stages locally; -NoDeploy skips
    deploy entirely.

.PARAMETER Name
    The X-Tension identifier — either the short form 'foo' or the full form
    'xways-foo'. Both are accepted; the script always normalises to xways-foo.

.PARAMETER DestRoot
    Project root that holds x-tensions/xways-<name>/ (the source built here).
    Default: the current directory. Pass the same -DestRoot used with
    new-xtension.ps1 when the skill is installed as a plugin; the script refuses
    to build from an installed plugin/marketplace cache.

.PARAMETER Force
    Skip the X-Ways process check and proceed even if X-Ways appears to be open.
    Use with caution — building while X-Ways holds the DLL will fail at link time.

.EXAMPLE
    .\build-xtension.ps1 -Name myscanner
    .\build-xtension.ps1 -Name xways-myscanner
    .\build-xtension.ps1 -Name myscanner -Force
    .\build-xtension.ps1 -Name myscanner -NoDeploy
    .\build-xtension.ps1 -Name myscanner -DeployRoot C:\path\to\xways-install
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$Name,

    [string]$DestRoot,

    [switch]$Force,

    # X-Ways install ROOT to deploy into (the folder containing xwb64.exe /
    # xwforensics64.exe). This is YOUR environment — pass it once and it is
    # remembered (saved to .xtension-deploy.local at the repo root, git-ignored).
    # If omitted, the script uses $env:XWT_DEPLOY_ROOT, then the remembered path.
    # If none is set, the build still succeeds and stages the DLL locally.
    [string]$DeployRoot,

    # Build + verify only; skip copying into the X-Ways install.
    [switch]$NoDeploy
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
function Fail([string]$msg) {
    Write-Error "ERROR: $msg"
    exit 1
}

function Write-Step([string]$label, [string]$detail = '') {
    Write-Host "  $label" -ForegroundColor Cyan -NoNewline
    if ($detail) { Write-Host " $detail" -ForegroundColor White }
    else         { Write-Host '' }
}

# ---------------------------------------------------------------------------
# 1. Normalise name
# ---------------------------------------------------------------------------
if ($Name -match '^xways-(.+)$') {
    $fullName = $Name
} else {
    $fullName = "xways-$Name"
}

# ---------------------------------------------------------------------------
# 2. Resolve the skill install root + the destination root (where the X-Tension
#    source lives). DestRoot defaults to the current directory so a plugin
#    install builds from the user's project, not the plugin cache.
# ---------------------------------------------------------------------------
$skillRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..\..')).Path

if ($DestRoot) {
    if (-not (Test-Path $DestRoot)) { Fail "-DestRoot '$DestRoot' does not exist." }
    $destRootResolved = (Resolve-Path $DestRoot).Path
} else {
    $destRootResolved = (Get-Location).Path
}

# Refuse to build from inside the installed skill/plugin cache (a managed dir).
$skillRootIsPlugin = ($skillRoot -match '[\\/]\.claude[\\/]plugins[\\/]') `
                  -or ($skillRoot -match '[\\/]plugins[\\/](cache|marketplaces)[\\/]')
if (-not $skillRootIsPlugin -and $env:CLAUDE_PLUGIN_ROOT) {
    try {
        $pr = (Resolve-Path $env:CLAUDE_PLUGIN_ROOT -ErrorAction Stop).Path.TrimEnd('\')
        if ($skillRoot.TrimEnd('\').StartsWith($pr, [System.StringComparison]::OrdinalIgnoreCase)) { $skillRootIsPlugin = $true }
    } catch { }
}
$destUnderSkill = $destRootResolved.TrimEnd('\').StartsWith($skillRoot.TrimEnd('\'), [System.StringComparison]::OrdinalIgnoreCase)
if ($skillRootIsPlugin -and $destUnderSkill) {
    Fail "Refusing to build from the installed plugin at '$skillRoot'. Run from your project directory, or pass -DestRoot '<your project path>' (the same one used with new-xtension.ps1)."
}

if (-not (Test-Path (Join-Path $destRootResolved 'x-tensions'))) {
    Fail "Could not locate x-tensions/ under '$destRootResolved'. Scaffold first with new-xtension.ps1 (pass the same -DestRoot), or cd into your project."
}

$xtDir    = Join-Path $destRootResolved "x-tensions\$fullName"
$buildBat = Join-Path $xtDir 'build.bat'

# ---------------------------------------------------------------------------
# 3. Verify build.bat exists
# ---------------------------------------------------------------------------
if (-not (Test-Path $buildBat)) {
    Fail "build.bat not found: $buildBat`n  Does the X-Tension exist? Run new-xtension.ps1 first."
}

# ---------------------------------------------------------------------------
# 4. X-Ways process guard
# ---------------------------------------------------------------------------
$xwaysProcNames = @('xwforensics64','xwforensics','xwb64','xwbforensics')
$running = Get-Process -ErrorAction SilentlyContinue | Where-Object { $_.Name -in $xwaysProcNames }

if ($running) {
    $procList = ($running | ForEach-Object { "$($_.Name) (PID $($_.Id))" }) -join ', '
    if (-not $Force) {
        Fail "X-Ways is currently running: $procList`n  Close X-Ways before building (the DLL is locked while it is open).`n  Use -Force to skip this check and attempt the build anyway."
    }
    Write-Warning "X-Ways appears to be running ($procList). Proceeding because -Force was specified."
}

# ---------------------------------------------------------------------------
# 5. MSVC x64 toolchain check
# ---------------------------------------------------------------------------
$clOnPath = $null
try { $clOnPath = (Get-Command 'cl.exe' -ErrorAction Stop).Source } catch {}

if (-not $clOnPath) {
    Write-Step "cl.exe not on PATH — searching for vcvars64.bat..."

    $vcvarsSearchPaths = @(
        "${env:ProgramFiles}\Microsoft Visual Studio\2022\Community\VC\Auxiliary\Build\vcvars64.bat"
        "${env:ProgramFiles}\Microsoft Visual Studio\2022\Professional\VC\Auxiliary\Build\vcvars64.bat"
        "${env:ProgramFiles}\Microsoft Visual Studio\2022\Enterprise\VC\Auxiliary\Build\vcvars64.bat"
        "${env:ProgramFiles}\Microsoft Visual Studio\2022\BuildTools\VC\Auxiliary\Build\vcvars64.bat"
        "${env:ProgramFiles(x86)}\Microsoft Visual Studio\2022\BuildTools\VC\Auxiliary\Build\vcvars64.bat"
        "${env:ProgramFiles(x86)}\Microsoft Visual Studio\2019\BuildTools\VC\Auxiliary\Build\vcvars64.bat"
        "${env:ProgramFiles(x86)}\Microsoft Visual Studio\2019\Community\VC\Auxiliary\Build\vcvars64.bat"
        "${env:ProgramFiles(x86)}\Microsoft Visual Studio\2019\Professional\VC\Auxiliary\Build\vcvars64.bat"
        "${env:ProgramFiles(x86)}\Microsoft Visual Studio\2019\Enterprise\VC\Auxiliary\Build\vcvars64.bat"
    )

    $vcvarsPath = $vcvarsSearchPaths | Where-Object { Test-Path $_ } | Select-Object -First 1

    if (-not $vcvarsPath) {
        Fail @"
Could not find vcvars64.bat in any standard VS 2019/2022 location.
Options:
  1. Install the MSVC C++ build tools (VS 2022 Community or BuildTools workload
     "Desktop development with C++").
  2. Open this script from an "x64 Native Tools Command Prompt for VS 2022"
     where cl.exe is already on PATH.
"@
    }

    Write-Step "Bootstrapping MSVC x64 from" $vcvarsPath

    # Run vcvars64 inside cmd and capture the resulting environment, then apply
    # it to the current PowerShell session so subsequent cmd /c build.bat picks it up.
    $envDump = & cmd /c "`"$vcvarsPath`" >nul 2>nul && set" 2>$null
    if ($LASTEXITCODE -ne 0 -or -not $envDump) {
        Fail "vcvars64.bat reported failure or produced no output."
    }
    foreach ($line in $envDump) {
        if ($line -match '^([^=]+)=(.*)$') {
            [System.Environment]::SetEnvironmentVariable($Matches[1], $Matches[2], 'Process')
        }
    }

    # Verify cl.exe is now resolvable
    try { $clOnPath = (Get-Command 'cl.exe' -ErrorAction Stop).Source }
    catch { Fail "vcvars64 ran but cl.exe is still not on PATH. Check the VS installation." }

    Write-Step "Toolchain ready" $clOnPath
} else {
    Write-Step "Toolchain" $clOnPath
}

# ---------------------------------------------------------------------------
# 6. Run build.bat
# ---------------------------------------------------------------------------
Write-Host ""
Write-Host "Building $fullName..." -ForegroundColor Cyan
Write-Host "  Directory: $xtDir" -ForegroundColor Gray
Write-Host ""

# Run via cmd /c with an EXPLICIT 'cd /d' to the X-Tension dir and build.bat
# referenced by its FULL PATH. PowerShell's Set-Location does not update the
# process current directory for child processes, and a bare 'build.bat' name is
# not resolved when NoDefaultCurrentDirectoryInExePath is set — so set the cwd in
# cmd itself and call the BAT by full path. build.bat's internal relative paths
# (mkdir xtensions\%NAME%, copy) then resolve against the X-Tension dir.
& cmd /c "cd /d `"$xtDir`" && call `"$buildBat`""
$buildExit = $LASTEXITCODE

if ($buildExit -ne 0) {
    Write-Host ""
    Write-Host "BUILD FAILED (exit $buildExit)" -ForegroundColor Red
    exit $buildExit
}

# ---------------------------------------------------------------------------
# 7. Verify output DLL
# ---------------------------------------------------------------------------
$expectedDll = Join-Path $xtDir "xtensions\$fullName\$fullName.dll"

if (-not (Test-Path $expectedDll)) {
    Fail "Build exited 0 but expected DLL not found: $expectedDll`n  Check build.bat output above for copy errors."
}

$dllItem = Get-Item $expectedDll
$sizeKb  = [math]::Round($dllItem.Length / 1KB, 1)

Write-Host ""
Write-Host "Build succeeded." -ForegroundColor Green
Write-Host "  DLL  : $expectedDll"
Write-Host "  Size : $sizeKb KB ($($dllItem.Length) bytes)"

# ---------------------------------------------------------------------------
# 8. Manager-compatibility sync check
# ---------------------------------------------------------------------------
# Detect if this X-Tension is manager-compatible: either it carries a local
# manager-plugin.h copy OR its .def exports XwaysManagerPluginEntry.
$managerHeader = Join-Path $xtDir 'manager-plugin.h'
$defFile       = Join-Path $xtDir "$fullName.def"
$isManagerCompat = (Test-Path $managerHeader)
if (-not $isManagerCompat -and (Test-Path $defFile)) {
    $defContent = Get-Content $defFile -Raw -ErrorAction SilentlyContinue
    $isManagerCompat = ($defContent -match 'XwaysManagerPluginEntry')
}

if ($isManagerCompat) {
    Write-Step "Manager-compat check" "(verifying manager-plugin.h is in sync with canonical)"
    $syncScript = Join-Path $PSScriptRoot 'check-manager-sync.ps1'
    if (Test-Path $syncScript) {
        & pwsh -File $syncScript -Name $fullName
        if ($LASTEXITCODE -ne 0) {
            Write-Host ""
            Write-Host "  WARNING: manager-plugin.h in $fullName has drifted from the canonical." -ForegroundColor Yellow
            Write-Host "           Managed loading may silently break. Sync the header before deploying." -ForegroundColor Yellow
            Write-Host "           Canonical: $skillRoot\templates\x-tensions\cpp-xtmgr-compatible\manager-plugin.h" -ForegroundColor Yellow
        }
    } else {
        Write-Warning "check-manager-sync.ps1 not found at '$syncScript' — skipping manager-plugin.h check."
    }
}

# ---------------------------------------------------------------------------
# 9. Deploy into the X-Ways install (consistent xtensions\<name>\ layout)
# ---------------------------------------------------------------------------
# build.bat stages a ready-to-copy folder at x-tensions\<name>\xtensions\<name>\.
# Mirror it into <install>\xtensions\<name>\ — a stable path the analyst
# registers once via Tools | Run X-Tensions and rebuilds never invalidate.
# (An X-Tension's own build.bat may also deploy; the mirror below is
# idempotent, so a double-deploy is harmless.)
$stagedDir = Join-Path $xtDir "xtensions\$fullName"

if ($NoDeploy) {
    Write-Host ""
    Write-Host "Skipping deploy (-NoDeploy). Copy this folder into <X-Ways install>\xtensions\ manually:" -ForegroundColor Cyan
    Write-Host "  $stagedDir" -ForegroundColor White
    exit 0
}

# Resolve the X-Ways install ROOT to deploy into. Precedence:
#   1. -DeployRoot  (and remember it for next time)
#   2. $env:XWT_DEPLOY_ROOT
#   3. a remembered path in .xtension-deploy.local at the repo root
# A candidate counts as an install only if it holds xwb64.exe (BYOD) or
# xwforensics64.exe (licensed). Nothing is hardcoded — the install path is the
# user's own environment, asked for once and remembered.
$deployMemo = Join-Path $destRootResolved '.xtension-deploy.local'

function Test-XWaysRoot([string]$p) {
    if (-not $p) { return $false }
    return (Test-Path (Join-Path $p 'xwb64.exe')) -or (Test-Path (Join-Path $p 'xwforensics64.exe'))
}

function Resolve-XWaysRoot {
    param([string]$explicit)
    $candidates = @()
    if ($explicit)            { $candidates += $explicit }
    if ($env:XWT_DEPLOY_ROOT) { $candidates += $env:XWT_DEPLOY_ROOT }
    if (Test-Path $deployMemo) {
        $remembered = (Get-Content -LiteralPath $deployMemo -Raw -ErrorAction SilentlyContinue)
        if ($remembered) { $candidates += $remembered.Trim() }
    }
    foreach ($c in $candidates) {
        if (Test-XWaysRoot $c) { return (Resolve-Path $c).Path }
    }
    return $null
}

$xwRoot = Resolve-XWaysRoot -explicit $DeployRoot

# Remember an explicitly-provided, valid root for next time (git-ignored).
if ($DeployRoot -and $xwRoot) {
    Set-Content -LiteralPath $deployMemo -Value $xwRoot -NoNewline -ErrorAction SilentlyContinue
}

if (-not $xwRoot) {
    Write-Host ""
    Write-Host "No X-Ways install configured for deploy — the DLL is built and staged locally:" -ForegroundColor Yellow
    Write-Host "  $stagedDir" -ForegroundColor White
    Write-Host "To deploy into YOUR X-Ways install (the folder holding xwb64.exe / xwforensics64.exe):" -ForegroundColor Yellow
    Write-Host "  - re-run with -DeployRoot '<your-install-root>'  (remembered in .xtension-deploy.local), or" -ForegroundColor White
    Write-Host "  - set `$env:XWT_DEPLOY_ROOT, or" -ForegroundColor White
    Write-Host "  - copy the staged folder into <install>\xtensions\$fullName yourself." -ForegroundColor White
    Write-Host "  (Use -NoDeploy to silence this.)" -ForegroundColor DarkGray
    exit 0
}

$destParent = Join-Path $xwRoot 'xtensions'
$destDir    = Join-Path $destParent $fullName
Write-Step "Deploying to" $destDir

if (-not (Test-Path $destParent)) {
    New-Item -ItemType Directory -Force -Path $destParent | Out-Null
}

# Mirror staged -> install, newer-only (/D) so an analyst-edited sidecar
# .cfg/.yaml in the install is preserved across rebuilds. /E recurse subdirs,
# /I treat dest as a directory, /Y overwrite without prompt, /Q quiet.
& xcopy "$stagedDir" "$destDir\" /E /I /Y /D /Q | Out-Null
if ($LASTEXITCODE -ne 0) {
    Fail "Deploy failed: xcopy '$stagedDir' -> '$destDir' returned exit $LASTEXITCODE."
}

Write-Host ""
Write-Host "Deployed to X-Ways install." -ForegroundColor Green
Write-Host "  $destDir\$fullName.dll" -ForegroundColor White
Write-Host "  In X-Ways: Tools > Run X-Tension on Volume Snapshot > that DLL." -ForegroundColor Gray
