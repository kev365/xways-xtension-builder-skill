@echo off
REM ============================================================================
REM  Build <name>.dll (x64) with MSVC cl.exe.
REM
REM  Naming convention (do not stray):
REM    - Source folder (in this repo): x-tensions\<name>\
REM    - Source files:                 <name>.cpp / .def / (optional) .rc
REM    - DLL:                          <name>.dll
REM    - Deploy bundle (build output): xtensions\<name>\<name>.dll
REM      (xtensions\ is the deploy-bundle convention — X-Ways has no
REM      auto-load folder; the analyst registers the DLL once via Tools | Run
REM      X-Tensions. Drop the subfolder into <X-Ways install>\xtensions\.)
REM
REM  Auto-bootstraps the VS x64 toolchain if cl.exe isn't on PATH yet, so this
REM  works from a plain cmd.exe / PowerShell window.
REM ============================================================================

setlocal EnableDelayedExpansion

REM Run from the script's own directory so the relative rc/cl/link paths
REM resolve regardless of the caller's working directory.
cd /d "%~dp0"

REM --- Bootstrap VS x64 toolchain if needed ----------------------------------
where cl >nul 2>nul && goto :have_toolchain

set "VCVARS="
for %%V in (
    "%ProgramFiles%\Microsoft Visual Studio\2022\Community\VC\Auxiliary\Build\vcvars64.bat"
    "%ProgramFiles%\Microsoft Visual Studio\2022\Professional\VC\Auxiliary\Build\vcvars64.bat"
    "%ProgramFiles%\Microsoft Visual Studio\2022\Enterprise\VC\Auxiliary\Build\vcvars64.bat"
    "%ProgramFiles%\Microsoft Visual Studio\2022\BuildTools\VC\Auxiliary\Build\vcvars64.bat"
    "%ProgramFiles(x86)%\Microsoft Visual Studio\2022\BuildTools\VC\Auxiliary\Build\vcvars64.bat"
    "%ProgramFiles(x86)%\Microsoft Visual Studio\2019\BuildTools\VC\Auxiliary\Build\vcvars64.bat"
    "%ProgramFiles(x86)%\Microsoft Visual Studio\2019\Community\VC\Auxiliary\Build\vcvars64.bat"
    "%ProgramFiles(x86)%\Microsoft Visual Studio\2019\Professional\VC\Auxiliary\Build\vcvars64.bat"
    "%ProgramFiles(x86)%\Microsoft Visual Studio\2019\Enterprise\VC\Auxiliary\Build\vcvars64.bat"
) do if not defined VCVARS if exist %%V set "VCVARS=%%~V"
if not defined VCVARS (
    echo ERROR: Could not find vcvars64.bat. Install the MSVC C++ build tools, or
    echo run this script from a "x64 Native Tools Command Prompt for VS 2019/2022".
    exit /b 1
)
echo Bootstrapping MSVC x64 environment from:
echo     !VCVARS!
call "!VCVARS!" >nul 2>nul
if errorlevel 1 (
    echo ERROR: vcvars64.bat reported failure.
    exit /b 1
)

:have_toolchain

set NAME=my_xtension
set OUT=%NAME%.dll
set CXXFLAGS=/nologo /std:c++17 /W3 /EHsc /O2 /utf-8 /DUNICODE /D_UNICODE
set LDFLAGS=/DLL /DEF:%NAME%.def /OUT:%OUT% /MACHINE:X64
REM version.lib is for GetFileVersionInfo* / VerQueryValueW (PE VERSIONINFO
REM identity check in PeIdentityContains).
set LIBS=user32.lib shell32.lib ole32.lib comdlg32.lib comctl32.lib gdi32.lib advapi32.lib version.lib

if exist *.obj del /q *.obj
if exist *.res del /q *.res

rc /nologo /fo %NAME%.res %NAME%.rc || goto :fail
cl %CXXFLAGS% /c %NAME%.cpp || goto :fail
link %LDFLAGS% %NAME%.obj %NAME%.res %LIBS% || goto :fail

echo.
echo Built: %OUT%

REM Deployment convention: xtensions\<name>\<name>.dll
REM (Each X-Tension lives in its own subfolder under xtensions\.)
if not exist xtensions\%NAME% mkdir xtensions\%NAME%
copy /Y "%OUT%" "xtensions\%NAME%\%OUT%" >nul || goto :fail
echo Deployed: xtensions\%NAME%\%OUT%

REM Also deploy the .cfg.example reference. EnsureCfgExists() in the cpp
REM copies this to <name>.cfg on first run if no cfg exists yet.
if exist "%NAME%.cfg.example" (
    copy /Y "%NAME%.cfg.example" "xtensions\%NAME%\%NAME%.cfg.example" >nul
    echo Deployed: xtensions\%NAME%\%NAME%.cfg.example
)

REM Title-bar icon -- loaded via LoadImageW (LR_LOADFROMFILE) from the DLL's
REM own directory at WM_INITDIALOG (file name = <name>.ico). Optional.
if exist "%NAME%.ico" (
    copy /Y "%NAME%.ico" "xtensions\%NAME%\%NAME%.ico" >nul
    echo Deployed: xtensions\%NAME%\%NAME%.ico
)

REM Remove the project-root DLL so the only loadable copy is in the deploy
REM bundle (cfg sidecars land next to the loaded DLL).
if exist "%OUT%" del /Q "%OUT%" 2>nul

exit /b 0

:fail
echo.
echo BUILD FAILED
exit /b 1
